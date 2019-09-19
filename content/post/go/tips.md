---
title: "Tips"
tags: ["go tips"]
date: 2019-09-10T11:01:04+08:00
draft: true
---

记录一些go使用过程中的一些小技巧。

- context  

<!--more-->

## context

> context的使用也有一定负面影响，比如会创建过多的对象。

- 不要把Context放在结构体中，要以参数的方式传递，parent Context一般为context.Background  
- 应该要把Context作为第一个参数传递给入口请求和出口请求链路上的每一个函数，放在第一位，变量名建议都统一，如ctx。  
- 给一个函数方法传递Context的时候，不要传递nil，否则在tarce追踪的时候，trace链路就会断开。  
- Context不应该作为扩展参数的途径，不能为了方便把上下文链路无关的参数放进Context，其Value的相关方法只能传递必须的参数。  
- Context是线程安全的，可以放心的在多个goroutine中传递  
- 可以把一个 Context 对象传递给任意个数的 gorotuine，对它执行 取消 操作时，所有 goroutine 都会接收到取消信号。  

## struct with sync.Mutex

如果你的结构体包含`sync.Mutex`属性，或者内嵌了`sync.Mutex`，那么这个struct的函数receiver应该定义为指针类型，以防函数调用复制了`sync.Mutex`发送非预期的影响。

```golang
package main

import "fmt"
import "sync"
import "time"

type tMutext struct {
	sync.Mutex
}

func (t tMutext) LOne() {
	t.Lock()
	defer t.Unlock()
	time.Sleep(time.Second)
}

func (t tMutext) LTwo() {
	t.Lock()
	defer t.Unlock()
	time.Sleep(time.Second)
}

func main() {
	m := tMutext{}
	m.Lock()
	m.LOne()
	fmt.Println("vim-go")
}
```

## 简化函数名称

当一个package的函数返回值是pkg.Pkg,*pkg.Pkg，函数名可以省略类型名而不会让用户困惑。
