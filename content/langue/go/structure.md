---
title: "Structure your binary from your application"
date: 2019-02-27T12:14:58+08:00
draft: true
---

## reason

- so application can use as library
- can have multi application binary

## structure example

```json
├── cmd
│   ├── firstb
│   │   └── firstbinary.go
│   └── secondb
│       └── secondbinary.go
└── logic
│    └── logic.go
└── other.go
```

## install command

```bash
$ go get xxxxx/xxx/yourpackage/...
```

