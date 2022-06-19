---
title: "pve multi bridge: nat for Wlan and bridge for ethernet"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["pve", "nat"]
date: 2022-06-19T18:40:29+08:00
draft: false
---

本文主要介绍了pve在两个外部网络的情况下，使用两个bridge网络的方案。有线网络使用桥接模式，无线网络使用nat模式。

<!--more-->

## 前言

网上有很多pve使用nat和桥接网络上网的设置。但是呢，我是有一个有线网外加一个无线网。一个长城一个移动，期望一些虚拟机走无线网，一些走有线网。几乎没有找到一个完整的可以配置一个桥接网络和一个nat网络使用wifi的方案。还好有耐心最终成功了。
目前这篇只将怎么操作，后续再开篇理理里面的相关知识点。

> 插个题外话，为何不桥接无线网呢。最开始没成功，后来看一些文章说，linux下面无线桥接会有问题。这个时候啥都不会，网络还没弄好，就先不去踩坑了

## 系统环境

proxmox-ve: 7.2-1 (running kernel: 5.15.35-2-pve)

## 连接无线

debian连接无线的工具有很多，可以参考官方wiki: [debian wifi](https://wiki.debian.org/WiFi/HowToUse)

这里我使用connman

### 安装

```bash
# apt install connman
```

### 修改配置。不然connman自带的dns server会合dnsmasq冲突

```bash
# mkdir -p /etc/systemd/system/connman.service.d/
# cat << EOF >> /etc/systemd/system/connman.service.d/disable_dns_proxy.conf
[Service]
ExecStart=
ExecStart=/usr/sbin/connmand -n --nodnsproxy
EOF
# systemctl daemon-reload
# systemctl restart connman
```

### 连接无线

```bash
$ connmanctl 
connmanctl> enable wifi
connmanctl> scan wifi 
Scan completed for wifi

connmanctl> services 
$SSID    wifi_f8d111090ed6_6d617269636f6e5f64655f6d6965726461_managed_psk
...      ...

connmanctl> agent on
Agent registered

connmanctl> connect wifi_f8d111090ed6_6d617269636f6e5f64655f6d6965726461_managed_psk 
Agent RequestInput wifi_f8d111090ed6_6d617269636f6e5f64655f6d6965726461_managed_psk
Passphrase = [ Type=psk, Requirement=mandatory, Alternates=[ WPS ] ]
WPS = [ Type=wpspin, Requirement=alternate ]
Passphrase? $PASS
Connected wifi_f8d111090ed6_6d617269636f6e5f64655f6d6965726461_managed_psk

connmanctl> quit
```

## bridge 配置

在`/etc/network/interfaces`中添加

```bash
auto vmbr1
iface vmbr1 inet static
    address 192.168.10.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
	  post-up bash /root/scripts/iptables.config.sh
```

vmbr1是虚拟bridge的名字，也可以使用其他的。配置的网络是192.168.10.1/24，这里也可以使用其他网段。文件`/root/scripts/iptables.config.sh`中存放了iptables和route相关的配置，也可以直接写在上面的配置文件里

## 配置iptables和路由规则

文件`/root/scripts/iptables.config.sh`内容
```bash
iptables -t nat -A POSTROUTING -s '192.168.10.0/24' -o wlp5s0  -j MASQUERADE
iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1  # 参考https://pve.proxmox.com/wiki/Network_Configuration
ip route add default via 192.168.1.1 dev wlp5s0 table 101
ip route add 192.168.10.0/24 dev vmbr1 table 101
ip rule add iif wlp5s0 to 192.168.10.0/24 lookup 101
ip rule add from 192.168.10.0/24 lookup 101
ip rule add iif vmbr1 lookup 101
ip route flush cache
```

这里面网络地址(192.168.10.0/24), 无线网卡(wlp5s0),虚拟bridge(vmbr1)和routing table(101) 可以根据情况进行替换

到了这一步，手动配置好虚拟机的网络ip就可以正常上网了。但是我还是比较喜欢不用配置的，那么下一步就是dnsmasq的任务了。

## 配置dnsmasq

dnsmasq是pve自带的，只要稍微配置就可以了

编辑`/etc/dnsmasq.conf`替换以下两行配置。这里的vmbr1根据实际情况修改。其中192.168.10.50为ip池起始地址,192.168.10.200为ip池结束地址,255.255.255.0为网络掩码,72h为dhcp租约有效期
```bash
interface=vmbr1
dhcp-range=192.168.10.50,192.168.10.200,255.255.255.0,72h
```