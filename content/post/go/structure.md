---
title: "一种合理组织go项目结构的方案"
date: 2019-02-27T12:14:58+08:00
tags: ["go", "structure"]
---

之前有看到一种感觉比较合理的组织go项目结构的方案，现在重新整理记录一下。


### 为什么要遵循一定的结构呢

总的来讲，小的项目或者说自己的一些玩具项目确实没有必要。但是当项目越来越大，功能越来越多，依赖和被依赖的情况也越来越多的时候，合理的组织项目结构在维护和使用上会有很多好处。

<!--more-->

比如说，对于同一个项目:  
1. go get可以安装多个不同的binary。  
2. 你的项目可以作为库方方便的被别人使用。  

### 项目结构示例

这里我只截取了一些自己感兴趣的目录，此处有更详细的分类和说明[golang-standards/project-layout][std layout]。

```
├── cmd
│   ├── agent
│   │   └── app
│   ├── builder
│   ├── collector
│   └── standalone
├── examples
│   └── hotrod
├── pkg
│ 
├── internal
│
├── third_party
│
├── vendor
│
├── scripts
...
```

#### `/cmd`

这个目录用来存放执行程序入口，对于不同名字的执行应该方案不同的二级目录。(e.g. `/cmd/agent`)。这里不应该有过多的业务逻辑，或者说是程序的功能逻辑，对于可重用的代码应该放在`/pkg`目录，对于不想被外部使用的代码应该放在`/internal`目录。

例子：[k8s cmd](https://github.com/kubernetes/kubernetes/tree/master/cmd)

#### `/internal/`

私有的不希望被其他地方使用的代码放在这里，或者import路径中包含`/internal/的包中`。为何说是不同的地方的呢，因为go的设计中，internal中的包只能被和它有相同父级的包import。例如 `.../a/b/c/internal/d/e/f` 可以被`.../a/b/c`中的包使用，不能被`.../a/b/g`以及其他项目使用。详见 [go doc](https://golang.org/doc/go1.4#internalpackages)

关于打破internal的限制的文章:[突破限制,访问其它Go package中的私有函数
](https://colobu.com/2017/05/12/call-private-functions-in-other-packages/)


#### `/pkg`

可有作为单独库复用的代码可以放在这里，其它项目也可以使用。

#### `/vendor`

不多说，go modules出现之前的常规做法。存放第三方依赖项。

#### `/third_party`

也是第三方包存放的目录，不同于`vendor`之处是，你可能对这些包做了一些修改。以及一些第三方工具链也可以放这里。

#### `/scripts`

存放一些脚本。比如一些复杂的build操作，web本地测试启动脚本等等。

---

[std layout]: https://github.com/golang-standards/project-layout
参考文章：  
- [golang-standards/project-layout][std layout]  
- [Structuring Applications in Go](https://medium.com/@benbjohnson/structuring-applications-in-go-3b04be4ff091)  
- [Go Project Layout](https://medium.com/golang-learn/go-project-layout-e5213cdcfaa2)  

