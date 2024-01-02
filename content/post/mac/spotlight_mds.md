---
title: "Spotlight, mds"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["mac", "osx"]
date: 2022-08-21T16:26:00+08:00
---

spotlight & mds 排除目录

<!--more-->

[TOC]

spotlight & mds

### 排除目录

##### via system

System Preferences > Spotlight

##### via commandline

sudo defaults write /.Spotlight-V100/Store-V1/Exclusions Exclusions -array-add path/to/exclude


1）在终端中键入命令 `sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist`
2）完成后重启电脑
3）确认您的电脑未开启 Time Machine，功能的情况下，执行以下重建命令：

```bash
sudo mdutil -i off // <press [return]>
sudo mdutil -E // <press [return]>
sudo mdutil -i on // <press [return]>
```



<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">