---
title: "Web Tail"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: []
date: 2020-06-08T12:49:01+08:00
draft: true
---

tornado web tail like handler

### 背景

需要一个简单能用的发布服务，这个服务发布的时候能看到发布进度。以下比较啰嗦，[问题与解决方案传送门](#遇到与解决方案)

以前发布服务接收来看发布请求后，直接用`subprocess.Popen`新开进程处理，然后就返回了响应，发布者
看不到发布过程，看不到中间是否出现了问题。刚好有个新服务需要发布，流程和以前的不一样，需要加个
新的发布逻辑。ok，那么这次我就想把发布过程也显示出来。想法就是`pipe`进程的输入输出到web stream，
所有的以前都是如此顺利，直到chrome里不能实时看到发布过程，虽然我已经是`chunked`编码了。以下详细
记录。

### tornado 代码

### 遇到与解决方案

<!--more-->

The remaining content of your post.
