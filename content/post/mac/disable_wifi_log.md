---
title: "Disable wifi log"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["mac", "osx"]
date: 2022-08-21T16:30:28+08:00
---

disable wifi log
<!--more-->

```bash
cd /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources
```

Then figure out which log settings are currently enabled by invoking:

```bash
$ sudo ./airport debug
DriverWPA
```

In this case only the DriverWPA setting is active. To disable that you just need to prefix it with a dash sign:
`$ sudo ./airport debug -DriverWPA`

Last but not least, double check and confirm that the log setting is not active anymore:
`sudo ./airport debug`

turn all off

`/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport debug -AllUserland -AllDriver -AllVendor`

<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">