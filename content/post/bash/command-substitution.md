---
title: "Bash 命令替换"
author: "Simon Wei"
tags: ["bash"]
date: 2019-09-12T15:32:23+08:00
---

做灰度系统的时候，用到了nginx。在创建docker镜像的时候需要根据参数去渲染nginx配置。
简单的使用sed去达到这个目的，不幸的遇到了bash命令替换的问题。

bash中有两种命令替换的格式 `` `...` `` 和 `$(...)`

<!--more-->

#### backtick format `` `...` ``

例子：

```bash
bash$ PWD=`pwd`
bash$ echo ${PWD}
```

#### parentheses format `$(...)`

这种格式是用来替代`` `...` ``格式的。有以下不同点

- 执行命令后不会转义结果中的`\`。  
- 支持嵌套命令替换(command substition)。  

例子：

```bash
bash$ echo `echo \\`


bash$ echo $(echo \\)
\
```

```bash
word_count=$( wc -w $(echo * | awk '{print $8}') )
```

#### 遇到的问题

使用sed将传入string变量中的`/`替换为`\/`,使用`` `...` ``方案时容易出错，阅读性差。示例代码:

```bash
log="/var/log/ngx.access.log upstream buffer=32k"
echo "origin: ${log}"
outp1=$(sed 's/[&/\]/\\&/g' <<< "${log}")
echo "use parentheses: ${outp1}"
outp2=`sed 's/[&/\]/\\&/g' <<< "${log}"`
echo "use backtick: ${outp2}"
outp3=`sed 's/[&/\]/\\\\&/g' <<< "${log}"`
echo "use backtick(wanted): ${outp3}"
```

输出如下：

```
origin: /var/log/ngx.access.log upstream buffer=32k
use parentheses: \/var\/log\/ngx.access.log upstream buffer=32k
use backtick: &var&log&ngx.access.log upstream buffer=32k
use backtick(wanted): \/var\/log\/ngx.access.log upstream buffer=32k
```

这时使用`$(...)`的方式就感觉清晰多了

参考文章:

[advace bash scripting guid](https://www.tldp.org/LDP/abs/html/commandsub.html#BACKQUOTESREF)
The remaining content of your post.
