---
title: "mount qemu/kvm virtual disk: qcow2, raw"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: []
date: 2023-01-19T17:20:13+08:00
draft: true
---

how to mount qcow2 raw or iso in linux

<!--more-->

[TOC]

## libguestfs

 all kinds of disk images 


### install

#### 
libguestfs-tools

### usage

guestmount -a /path/to/qcow2/image -m <device> /path/to/mount/point

guestmount -a /var/lib/libvirt/images/xenserver.qcow2 -m /dev/sda1 /mnt

guestmount -a /var/lib/libvirt/images/xenserver.qcow2 -m /dev/sda1 --ro /mnt

guestunmount /mnt

## qemu-nbd

qcow, raw

pve default

### install

sudo apt-get install qemu-utils

sudo yum install qemu-img

sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 /path/to/qcow2/image
sudo qemu-nbd --connect=/dev/nbd0 /var/lib/libvirt/images/xenserver.qcow2
sudo fdisk /dev/nbd0 -l
sudo mount /dev/nbd0p1 /mnt
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0

<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">