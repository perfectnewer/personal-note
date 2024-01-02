---
title: "pve系列: amd显卡直通"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["pve", "pci passthrough"]
keywords:
- promox pci passthrough
- pve pci passthfough
- amd reset bug
- BAR 1: can't reserve mem
date: 2024-01-02T18:15:39+08:00
draft: true
---

记录了一下pci passthrough的基本操作，遇到的问题和一些经验

<!--more-->

[TOC]

## 主要参考文章

正常情况下参考以下文章可以顺利直通成功

- [promox wiki](https://pve.proxmox.com/wiki/Pci_passthrough)
- [archwiki pci_passthrough_via_ovmf](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)

## 这里说几个注意点

1. 在不同IOMMU groups内的设备直通是互不1影响的，可以在直通页面选择all functions，否则千万不要选all functions。不然相关设备在主机上都无法使用。
2. pci直通页面rombar选项的作用是把vbios暴露给虚拟机，相当于自己放了romfile。不过对于核显，貌似得自己去主板bios文件中提取vbios，用romfile参数传递
3. 部分amd有reset bug，需要使用第三方补丁：[vender_reset](https://github.com/gnif/vendor-reset)
4. 部分amd核显也有reset bug，不过上面的补丁不行，得用其他办法，后面再讲
5. kernel command line中的参数，多余的不会有影响，只要没有错误的就行

## tested

- cpu：5700x，5900，5700g
- mother board：asus b550xe，asus b550i
- graphics card：5700g，rx580，arc a770
- system：pve7.3，pve8.1
- machine type：q35， 7.1-8.1

## pci passthrough

### enable iommu

bios 开启iommu和虚拟化，对于amd用户

enable IOMMU, SVM; disable CSM

##### add kernel parameter

在 `/etc/default/grub` 的`GRUB_CMDLINE_LINUX_DEFAULT` 添加 `amd_iommu=on iommu=pt`  
如果没有核显额外添加 `initcall_blacklist=sysfb_init`，主要作用是禁止framebuffer加载显卡驱动，占用显卡，造成直通失败。不加也可以在启动虚拟机前，卸载掉framebuffer驱动。这样没有核显的情况下，显示器会没有后续日志输出，也不能使用键盘输入。目前可以先不加，先做直通前的准备工作，文件例子：
```
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="iommu=pt amd_iommu=on amdgpu.noretry=0 pcie_acs_override=downstream,multifunction"
GRUB_CMDLINE_LINUX=""

# If your computer has multiple operating systems installed, then you
# probably want to run os-prober. However, if your computer is a host
# for guest OSes installed via LVM or raw disk devices, running
# os-prober can cause damage to those guest OSes as it mounts
# filesystems to look for things.
#GRUB_DISABLE_OS_PROBER=false

# Uncomment to enable BadRAM filtering, modify to suit your needs
# This works with Linux (no patch required) and with any kernel that obtains
# the memory map information from GRUB (GNU Mach, kernel of FreeBSD ...)
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"

# Uncomment to disable graphical terminal
#GRUB_TERMINAL=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command `vbeinfo'
#GRUB_GFXMODE=640x480

# Uncomment if you don't want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY="true"

# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
```

然后更新grub.cfg,重启：
```bash
sudo update-grub
sudo reboot
```

#### 开机后检查iommu状态：

```bash
# dmesg | grep -e DMAR -e IOMMU
[    0.000000] Warning: PCIe ACS overrides enabled; This may allow non-IOMMU protected peer-to-peer DMA
[    0.507259] pci 0000:00:00.2: AMD-Vi: IOMMU performance counters supported
[    0.508883] pci 0000:00:00.2: AMD-Vi: Found IOMMU cap 0x40
[    0.528883] perf/amd_iommu: Detected AMD IOMMU #0 (2 banks, 4 counters/bank).
[   10.196349] AMD-Vi: AMD IOMMUv2 loaded and initialized
```

输出中有 "DMAR: IOMMU enabled" 或者 "AMD-Vi: AMD IOMMUv2 loaded and initialized" 表示开启成功，如果没有那么需要查一下资料确认已经开启成功了

#### 确认  IOMMU interrupt remapping

```bash
dmesg | grep 'remapping'
```

如果有下面任一输出，说明支持remapping
```
AMD-Vi: Interrupt remapping enabled
DMAR-IR: Enabled IRQ remapping in x2apic mode ('x2apic' can be different on old CPUs, but should still work)
then remapping is supported.
```

否则要加入以下配置
```bash
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
```

### prepare vfio

#### 让系统加载vfio驱动

```bash
cat << EOF >> /etc/modules 
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

update-initramfs -u

```

#### 用vfio代替原驱动

这里有两个方案，一个是系统启动时直接替换。一种是启动虚拟机时按需替换，如果有核显可用或者不需要显示物理机画面，可以直接配置成启动时替换

###### 配置vfio加载优先

查看需要直通的设备使用了什么驱动 根据驱动情况调整

```bash
root@pve:~# lspci -nnk -s 0b:00
0b:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Cezanne [Radeon Vega Series / Radeon Vega Mobile Series] [1002:1638] (rev c8)
	Subsystem: ASUSTeK Computer Inc. Cezanne [Radeon Vega Series / Radeon Vega Mobile Series] [1043:8809]
	Kernel driver in use: amdgpu
	Kernel modules: amdgpu
0b:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Renoir Radeon High Definition Audio Controller [1002:1637]
	Subsystem: ASUSTeK Computer Inc. Renoir Radeon High Definition Audio Controller [1043:8809]
	Kernel driver in use: snd_hda_intel
	Kernel modules: snd_hda_intel
0b:00.2 Encryption controller [1080]: Advanced Micro Devices, Inc. [AMD] Family 17h (Models 10h-1fh) Platform Security Processor [1022:15df]
	Subsystem: ASUSTeK Computer Inc. Family 17h (Models 10h-1fh) Platform Security Processor [1043:8809]
	Kernel driver in use: ccp
	Kernel modules: ccp
0b:00.3 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne USB 3.1 [1022:1639]
	Subsystem: ASUSTeK Computer Inc. Renoir/Cezanne USB 3.1 [1043:87e1]
	Kernel driver in use: xhci_hcd
	Kernel modules: xhci_pci
0b:00.4 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] Renoir/Cezanne USB 3.1 [1022:1639]
	Subsystem: ASUSTeK Computer Inc. Renoir/Cezanne USB 3.1 [1043:87e1]
	Kernel driver in use: xhci_hcd
	Kernel modules: xhci_pci
0b:00.6 Audio device [0403]: Advanced Micro Devices, Inc. [AMD] Family 17h/19h HD Audio Controller [1022:15e3]
	Subsystem: ASUSTeK Computer Inc. Family 17h/19h HD Audio Controller [1043:87d3]
	Kernel driver in use: snd_hda_intel
	Kernel modules: snd_hda_intel
```

比如上面的vega核显，看Kernel driver inuse那张，表明使用的是amdgopu，然后配置vfio优先加载，这个加载文件并不影响驱动使用，就是说，如果你打算虚拟机启动的时候才直通，不启动的时候物理机仍然可以使用，也能加

```bash
cat << EOF >> /etc/modprobe.d/01-vfio-pci.conf
# amd
softdep radeon pre: vfio-pci
softdep nouveau pre: vfio-pci
softdep amdgpu pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF
```

###### 配置vfio直通的设备id

找到要直通的设备标识 vender_id:device_id

```bash
# find vga pci
lspci -k | grep -A10 VGA

lspci -n -s <VGAID:eg 07:00> | awk '{print $3}'
```

加入到vfio的配置中
方法1：
```bash
echo "options vfio-pci ids=1002:67df,1002:aaf0 disable_vga=1" >> /etc/modprobe.d/vfio.conf

update-initramfs -u

reboot
```

方法2：也可以使用kernel command line，我比较喜欢这种方式。因为如果出问题了，可以在grub界面删掉，正常进系统补救。不然就只能ssh登录进行补救了

修改/etc/default/grub在GRUB_CMDLINE_LINUX_DEFAULT中加上`vfio-pci.ids=8086:56a0,8086:4f90 vfio-pci.disable_vga=1`, l例如：
```bash
GRUB_CMDLINE_LINUX_DEFAULT="iommu=pt amd_iommu=on amdgpu.noretry=0 pcie_acs_override=downstream,multifunction vfio-pci.ids=8086:56a0,8086:4f90 vfio-pci.disable_vga=1"
```

然后更新grub，重启
```
update-grub
reboot
```

###### 单显卡直通

另开单写

##### check vfio

重启后，确认vfio正常加载，想要直通的设备已经使用vfio-pci

```bash
使用vfio替代驱动。通过lspci -nnk 查看要直通的设备使用了哪些驱动

# dmesg | grep -i vfio
[    0.329224] VFIO - User Level meta-driver version: 0.3
[    0.341372] vfio_pci: add [10de:13c2[ffff:ffff]] class 0x000000/00000000
[    0.354704] vfio_pci: add [10de:0fbb[ffff:ffff]] class 0x000000/00000000
[    2.061326] vfio-pci 0000:06:00.0: enabling device (0100 -> 0103)

$ lspci -nnk -s 07:00
07:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere [Radeon RX 470/480/570/570X/580/580X/590] [1002:67df] (rev e7)
    Subsystem: Tul Corporation / PowerColor Radeon RX 580 [148c:2378]
    Kernel driver in use: vfio-pci
    Kernel modules: amdgpu
07:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590] [1002:aaf0]
    Subsystem: Tul Corporation / PowerColor Ellesmere HDMI Audio [Radeon RX 470/480 / 570/580/590] [148c:aaf0]
    Kernel driver in use: vfio-pci
    Kernel modules: snd_hda_intel
```


#### iommu group

查看要直通设备的iommu group，要直通的设备最好是在单独的iommu group中。这样虚拟机的pci属性页面可以选择all functions如果内核开启了`pcie_acs_override=downstream,multifunction`就不要选all functions。除非开启前就是单独的iommu group

##### 查看方法1：

```bash
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

##### 查看方法2：

```bash
# 其中nodename换成节点机器名，单节点就是当前机器名
pvesh get /nodes/<nodename>/hardware/pci --pci-class-blacklist ""
```

##### 查看方法3：

```bash
find /sys/kernel/iommu_groups/ -type l
```

##### 如果想要直通的设备没有在单独的iommu group中，可以添加内核参数

`pcie_acs_override=downstream,multifunction`

### 对于部分amd gpu

- AMD	Polaris 10	RX 470, 480, 570, 580, 590
- AMD	Polaris 11	RX 460, 560
- AMD	Polaris 12	RX 540, 550
- AMD	Vega 10	Vega 56/64/FE
- AMD	Vega 20	Radeon VII
- AMD	Navi 10	5600XT, 5700, 5700XT
- AMD	Navi 12	Pro 5600M
- AMD	Navi 14	Pro 5300, RX 5300, 5500XT

使用第三方补丁，修复reset bug
[vender_reset](https://github.com/gnif/vendor-reset)

对于amd 5000系带核显的cpu，要直通的话。
1. 不要重启虚拟机，不然除非重启物理机，不然核显无法再次被虚拟机识别
2. 虚拟机关机前在设备管理器中卸载核显
3. windows虚拟机中使用：[RadeonResetBugFix](https://github.com/inga-lovinde/RadeonResetBugFix) 

##### amd核显直通

后续单开文章

## 问题

#### vfio-pci ... can't reserve \[mem

```
[ 764.499088] vfio-pci 0000:07:00.0: BAR 1: can't reserve [mem 0x7ff0000000-0x7ff7ffffff 64bit pref]
```

添加内核参数`video=efifb:off` 或者 `initcall_blacklist=sysfb_init`

---
<font color=#999AAA >我的github pages: [perfectnewer.gitub.io](	https://perfectnewer.github.io)
<font color=#999AAA >我的gitee pages: [perfectnewer.gitee.io](	https://perfectnewer.gitee.io)