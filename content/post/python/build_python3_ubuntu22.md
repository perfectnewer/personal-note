---
title: "ubuntu 22.04 build python 3.x missing openssl solution"
author: "Simon Wei"
# cover: "/images/cover.jpg"
tags: ["build python", "ubuntu"]
date: 2022-06-29T17:28:25+08:00
---

ERROR: The Python ssl extension was not compiled. Missing the OpenSSL lib?

<!--more-->


### ERROR: The Python ssl extension was not compiled. Missing the OpenSSL lib?

ubuntu 22.04 build python 3.x error:

```bash
ERROR: The Python ssl extension was not compiled. Missing the OpenSSL lib?

Please consult to the Wiki page to fix the problem.
https://github.com/pyenv/pyenv/wiki/Common-build-problems


BUILD FAILED (Ubuntu 22.04 using python-build 20180424)

Inspect or clean up the working tree at /tmp/python-build.20220629172729.3400406
Results logged to /tmp/python-build.20220629172729.3400406.log
```

1. 使用自己下载编译的openssl库

```bash
LDFLAGS="-L/opt/openssl/lib -Wl,-rpath,/opt/openssl/lib" CONFIGURE_OPTS="--with-openssl=/opt/openssl --enable-optimizations" pyenv install 3.10.4
```

2. 使用brew安装的openssl库

```bash
LDFLAGS="-Wl,-rpath,=$(brew --prefix openssl@1.1)/lib" CONFIGURE_OPTS="--with-openssl=$(brew --prefix openssl@1.1) --enable-optimizations" pyenv install 3.10.0
```

<hr style=" border:solid; width:100px; height:1px;" color=#000000 size=1">