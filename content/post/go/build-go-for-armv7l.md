---
title: "Build Go for Armv7l"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["go"]
date: 2019-09-19T11:49:22+08:00
---

go1.13发布了，看module管理也更方便，准备转战go1.13。对于我的nanopi是armv7l的，官方只有armv6l,想着编译一个armv7l的自用。

<!--more-->

无论是跨平台编译，还是在目标机器（我这里就是nanopi）编译go，都需要首先安装go compiler（编译程序）。官方文档给出了四种安装方式：  
  1. 使用官方发布的预编译版本  
  2. 使用go1.4的源码编译  
  3. 跨平台编译  
  4. 使用gccgo编译  

#### 跨平台编译go

我的编译机器是linux amd64，是有官方的预编译版本的go（同时也是编译程序，现在的go是可以编译go的），所以只需安装go，然后编译armv7版本的go就可以了。  

优点就是速度快，编译方便，缺点是生成的二进制文件被放到了特殊目标，pkg和tool目录会有两份（一份目标架构的，一份本机的）。

假设下载好的go源码解压在了`/tmp/go`, 如果内存够大，放在tmpfs（虚拟磁盘）编译会快一些。

```bash
cd /tmp/go/src
GOROOT_FINAL=/opt/goarm GOOS=linux GOARCH=arm GOARM=7 GOBIN="\$HOME/go/bin" ./make.bash
# output
# Building Go bootstrap cmd/go (go_bootstrap) using Go toolchain1.
# Building Go toolchain2 using go_bootstrap and Go toolchain1.
# Building Go toolchain3 using go_bootstrap and Go toolchain2.
# Building packages and commands for host, linux/amd64.
# Building packages and commands for target, linux/arm.
# ---
# Installed Go for linux/arm in /tmp/go
# Installed commands in /tmp/go/bin
# 
# The binaries expect /tmp/go to be copied or moved to /opt/goarm
cd /tmp/go
# 删除编译机的版本，将arm版本的放好位置
mv bin/linux_arm/* bin/
rmdir bin/linux_arm/
# 下面是为了减少体积, 大约减少230m
rm -fr pkg/linux_amd64/ pkg/tool/linux_amd64/
# 最后将生成的go目录拷贝到目标机器上，按照安装预编译版本的方式安装就好了
# 将go运行目录加入PATH，设置GOPATH等等。
```

#### 跨平台编译go compile(编译程序)，在目标机器编译go

##### 首先在编译机器编译go compiler

假设下载好的go源码解压在了`/tmp/go`

```bash
cd /tmp/go/src
GOOS=linux GOARCH=arm GOARM=7 ./bootstrap.bash
# output
##### Copying to ../../go-linux-arm-bootstrap
#
##### Cleaning ../../go-linux-arm-bootstrap
#
##### Building ../../go-linux-arm-bootstrap
#
#Building Go cmd/dist using /usr/local/go.
#Building Go toolchain1 using /usr/local/go.
#Building Go bootstrap cmd/go (go_bootstrap) using Go toolchain1.
#Building Go toolchain2 using go_bootstrap and Go toolchain1.
#Building Go toolchain3 using go_bootstrap and Go toolchain2.
#Building packages and commands for host, linux/amd64.
#Building packages and commands for target, linux/arm.
#----
#Bootstrap toolchain for linux/arm installed in /tmp/go-linux-arm-bootstrap.
#Building tbz.
#-rw-rw-r-- 1 simon simon 110936506 Sep 19 14:21 /tmp/go-linux-arm-bootstrap.tbz
```

###### 在目标机器编译go

将上一步中的编译好的go compiler`go-linux-arm-bootstrap.tbz`拷贝到目标机器并解压，假设解压在了`/tmp/go-linux-arm-bootstrap`, 同样假设go源码解压在了`/tmp/go`

```bash
cd /tmp/go/src
export GOROOT_BOOTSTRAP=/tmp/go-linux-arm-bootstrap/
GOROOT_FINAL=/opt/go GOOS=linux GOARCH=arm GOARM=7 GOBIN="\$HOME/go/bin" ./make.bash
# 需要编译好后跑测试的可以用下面的命令，相当慢
# GOROOT_FINAL=/opt/go GOOS=linux GOARCH=arm GOARM=7 GOBIN="\$HOME/go/bin" ./all.bash
# output
# Building Go cmd/dist using /tmp/go-linux-arm-bootstrap/.
# Building Go toolchain1 using /tmp/go-linux-arm-bootstrap/.
# Building Go bootstrap cmd/go (go_bootstrap) using Go toolchain1.
# Building Go toolchain2 using go_bootstrap and Go toolchain1.
# Building Go toolchain3 using go_bootstrap and Go toolchain2.
# Building packages and commands for linux/arm.
# 
# ##### Testing packages.
# ok  	archive/tar	0.333s
# ok  	archive/zip	0.491s
# ok  	bufio	0.378s
# ok  	bytes	1.737s
# ok  	compress/bzip2	0.380s
# Building Go toolchain2 using go_bootstrap and Go toolchain1.
# Building Go toolchain3 using go_bootstrap and Go toolchain2.
# Building packages and commands for linux/arm.ok  	compress/flate	4.111s
# ok  	compress/gzip	0.200s
# ok  	compress/lzw	0.071s
# ...
# ...
###### API check
#Go version is "go1.13", ignoring -next /tmp/go/api/next.txt
#
#ALL TESTS PASSED
#---
#Installed Go for linux/arm in /tmp/go
#Installed commands in /tmp/go/bin
#
#The binaries expect /tmp/go to be copied or moved to /opt/go

# 清除编译过程中的cache文件
rm -fr pkg/obj/go-build/
sudo mv /tmp/go /opt/go
# 如果不需要bootstrap了可以删除掉，留着已经没用了
rm -fr /tmp/go-linux-arm-bootstrap
# go编译过程中产生的文件，还有些测试文件
rm -fr go-* web-TestGetFileURL* 
# 添加环境go/bin到变量
# echo 'export PATH=${PATH}:/opt/go/bin' >> ~/.bashrc
```

跑测试的时候很可能会因为内存不足而导致失败，提前设置个2G大小的swap还是很有必要的。如果swap并没怎么使用还是oomkill了，那么就需要临时调整swapness的参数

```bash
# 切换到root用户执行，编译成功后再改回去
cat /proc/sys/vm/swappiness
echo 100 > /proc/sys/vm/swappiness
```

---

ok，至此编译部分已经完成了。

参考资料：

- https://golang.org/doc/install/source  
- https://github.com/golang/go/wiki/GoArm  

