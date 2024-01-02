---
title: "pve 内部网络：添加hostonly网络"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["pve", "net"]
date: 2024-01-02T17:09:28+08:00
draft: false
---

pve nat network, host only, and set metric for lxc

<!--more-->

[TOC]

### 起因

起初在pve添加了个container，用来跑qbittorrent和samba，用win10解压大文件的时候感觉奇慢。我的win10也是显卡直通后的虚拟机。
突发奇想，之前网络都是桥接后经由路由器的，我的路由器只有千兆，太影响了，也影响其它设备，要是弄个主机的内部网络，不经由路由器岂不美哉。

### 1. 添加nat bridge

因为之前搞过wifi nat，这一步很轻松就搞定了。
在 `/etc/network/interfaces` 中添加
```bash
auto vmbr2
iface vmbr2 inet static
        address 10.0.1.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0
        post-up bash /root/scripts/vmbr2.iptables.config.sh up
        post-down bash /root/scripts/vmbr2.iptables.config.sh down
```
文件`scripts/vmbr2.iptables.config.sh`，主要是不想主路由表太乱，以及删除默认vmbr2的默认路由，因为这里是内部网络不需要访问外网：
```bash
function add() {
        ip route del default via 10.0.1.0 dev vmbr2
        ip route del 10.0.1.0/24 dev vmbr2 proto kernel scope link src 10.0.1.1
        ip route add default via 10.0.1.0 dev vmbr2 table 102
        ip route add 10.0.1.0/24 dev vmbr2 proto kernel scope link src 10.0.1.1 table 102
        ip route flush cache

        ip rule add iif vmbr2 lookup 102
        ip rule add to 10.0.1.0/24 lookup 102
}

function del() {
        ip rule del iif vmbr2 lookup 102
        ip rule del to 10.0.1.0/24 lookup 102

        ip route del default via 10.0.1.0 dev vmbr2 table 102
        ip route del 10.0.1.0/24 dev vmbr2 table 102
        ip route flush cache
}

if [ "$@"y == "y" -o "$@"y == "upy" ]; then
        echo "add ip config"
        add
else
        echo "del ip config"
        del
fi
```
### 2.添加内网网卡

一切都很丝滑，给win10添加VirtIO类型的网卡，这可是10G级别的。打上驱动。同样lxc也弄上。

连上samba，爽。

咦，不对，不能上网了，好说。给网卡加上优先级（接口跃点数），数值越小，优先级越高

设置路径：
```
网络和internet->高级网络设置->(找到自己的网卡)->更多适配器设置->属性->internet协议版本4(TCP/IPv4)-> 高级->接口跃点数
```

好了，可以正常上网了。顺带把所有ssh一并换成了内网。

### 3. lxc interface metric

此时天坑来了。我的lxc还扮演了代理服务器的角色，正常vm设置跃点数metric的方法，它都不管用。。。比如：

1. init.d中加启动脚本
2. systemd中加服务
3. lxc container配置文件中加配置

经过几天搜索，各种尝试。终于找到了方法。主要来源于以下两点：

1. 网络设置：pve是通过向 /etc/systemd/network/  中添加配置来设置的

2. 通过添加 `/etc/systemd/network/.pve-ignore.eth0.network` 文件，可以禁止修改的配置文件被pve覆盖。其中eth0换成自己的网卡名称

上成品：
`/etc/systemd/network/internal.network`:
```bash
internal.network  
[Match]  
Name = internal

[Network]  
Description = Interface internal autoconfigured by PVE  
DHCP = ipv6  
IPv6AcceptRA = false

[Route]  
Gateway = 10.0.1.1  
Metric = 2048

[Address]  
Address = 10.0.1.10/24  
RouteMetric = 2048
```

对于dhcp方式获取ip的，只需要额外添加以下内容：

```ini
[DHCPv4]
RouteMetric=100
```


具体可以参考配置文档。因为我的是静态ip，各种尝试后，添加了route和address，可以完美符合预期。为啥用2048呢，因为他会给我的dhcp的eth0弄成1024，我又希望eth0由pve接管，只好这样了

### 参考链接

- [routing-inside-lxc-container-ubuntu](https://forum.proxmox.com/threads/routing-inside-lxc-container-ubuntu-18.54873/)
- [systemd.network (www.freedesktop.org)](https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html)
- [systemd-networkd - ArchWiki (archlinux.org)](https://wiki.archlinux.org/title/systemd-networkd)

<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">