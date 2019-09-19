---
title: "简便删除git submodule的方法"
date: 2019-09-09T14:02:50+08:00
tags: ["git", "submodule"]
---

简单的删除: 新的版本使用`git rm`就可以删除submodule了。

```bash
# 这样删除的submodule会附带删除.gitmodules里面的相关section，但是不会删除
# .git/config 中的配置和 .git/modules 中的文件
git rm <path_to_submodule>
git commit -m "xxxxxxx"
```

<!--more-->

完全清理干净

```bash
git submodule deinit <path_to_submodule>
git rm <path_to_submodule>
rm -rf .git/modules/<path_to_submodule>
git commit -m "xxxxxxx"
```

>注: git rm 删除submodule需要git version 1.7.8 or newer

---

参考文章：  
- [git-submodule](https://git-scm.com/docs/gitsubmodules#_forms)  
- [git-rm](https://git-scm.com/docs/git-rm#_submodules)  

