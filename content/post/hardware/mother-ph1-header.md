---
title: "主板ph接口介绍"
author: "Simon Wei"
tags: ["motherboard", "ph header"]
date: 2019-09-10T12:33:08+08:00
---

现在的主板bios芯片基本都是焊死的，不过大都有ph1的接口用来修复bios。

文章内容来源于爬贴整理，如有侵权可以联系我。

<!--more-->

![ph header](/media/posts/ph1-1.png)

![ph header](/media/posts/ph1-2.png)

---

```
| 7 | 8 | x | 6 | 5 |
| - |---|---|---|---|
| 3 | 1 | 2 | n | 4 |
```

1-8 - spi flash pins like in chip datasheet
x - empty pin
n - dont know, doesnt ring

[univeral spi pin header](/media/posts/files/Universal_SPI_Pin_Header.pdf.html)
