---
title: "rt-acrh17"
author: "Simon Wei"
tags: ["rt-acrh17", "router", "hardware"]
date: 2019-09-17T17:48:48+08:00
---

rt-achrh17是我买的第一台昂贵的路由器。之前200rmb多的tp link 5G莫名其妙消失了，终于种草又买了一个。折腾过梅林固件，使用酸酸乳发现没有自定义规则功能，以及使用samba发现usb速度没上过40m，最终还是让它安心的做路由器就好了。毕竟我还有个nanopi，做bt下载和samba服务器，性能要好，对硬盘消耗也少。这里简单记录一下它的一些硬件信息。

<!--more-->

cpu: [IPQ4019](https://www.qualcomm.com/products/ipq4019)  

![ipq4019](/media/posts/ipq4019-info.png)

wifi: [QCA9984](https://www.qualcomm.com/products/qca9984)

![QCA9984](/media/posts/qca9984-info.png)

2.4G 增益芯片: QFE1922  
5G 增益芯片: QFE1952, 功率:14dBm@MCS9 (VHT80)  

参考文章:

- [华硕ACRH17拆机，5G为什么只有两路功放？](https://www.acwifi.net/7577.html)  
- [华硕（ASUS）RT-ACRH17 无线路由器评测](https://www.acwifi.net/3473.html)  
- [可怜的ACRH17，它的USB3.0速度被华硕压制了！](https://www.acwifi.net/7796.html)  
