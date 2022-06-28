---
title: "Python2 pandas import error on ubuntu22"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["python3", "pandas"]
date: 2022-06-28T22:35:50+08:00
draft: false
---

pandas/lib.so: undefined symbol: is_complex_object

<!--more-->


先啰嗦两句，起因是最近更新到了ubuntu22，然后我司的python2项目安装了python2后无法启动。报错如下

```bash
/home/wxp/.config/pyenv/versions/wj/lib/python2.7/site-packages/pandas/lib.so: undefined symbol: is_complex_object
Traceback (most recent call last):
  File "main.py", line 10, in <module>
    import urls
  File "/home/wxp/dev/idiaoyan/wenjuan/urls.py", line 5, in <module>
    import auth.views
  File "/home/wxp/dev/idiaoyan/wenjuan/auth/views.py", line 18, in <module>
    from admin.admin_utils import CommerceEmailContactsDao
  File "/home/wxp/dev/idiaoyan/wenjuan/admin/admin_utils.py", line 19, in <module>
    from mailtask.utils import _base_get_model_data as base_get_model_data
  File "/home/wxp/dev/idiaoyan/wenjuan/mailtask/utils.py", line 19, in <module>
    from wj_tasks.tasks import send_wx_audit_msg
  File "/home/wxp/dev/idiaoyan/wenjuan/wj_tasks/tasks.py", line 8, in <module>
    from wj_tasks.all_tasks.cron_tasks import *
  File "/home/wxp/dev/idiaoyan/wenjuan/wj_tasks/all_tasks/cron_tasks.py", line 7, in <module>
    from tools.notify_new_member_rspd_count import main as notify_new_member_rspd_count_script
  File "/home/wxp/dev/idiaoyan/wenjuan/tools/notify_new_member_rspd_count.py", line 12, in <module>
    from report import report_utils
  File "/home/wxp/dev/idiaoyan/wenjuan/report/report_utils.py", line 17, in <module>
    import pandas as pd
  File "/home/wxp/.config/pyenv/versions/wj/lib/python2.7/site-packages/pandas/__init__.py", line 6, in <module>
    from . import hashtable, tslib, lib
ImportError: /home/wxp/.config/pyenv/versions/wj/lib/python2.7/site-packages/pandas/lib.so: undefined symbol: is_complex_object
```

各种重装，重新build from source都无法解决。最后终于在相似的问题中找到了解决方案。主要原因是ubuntu 22中gcc默认使用新的标准，导致pands中inline函数编译不正确。

```bash
CFLAGS=-fgnu89-inline pip install --force-reinstall --no-cache --only-binary :all: --global-option=build_ext pandas==0.11.0
```


<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">

<font color=#999AAA >我的github pages: [perfectnewer.gitub.io](https://perfectnewer.github.io "perfectnewer")  
<font color=#999AAA >我的gitee pages: [perfectnewer.gitub.io](https://perfectnewer.gitee.io "perfectnewer")  
<font color=#999AAA >我的csdn: [https://blog.csdn.net/perfectnewer](https://blog.csdn.net/perfectnewer "perfectnewer")  