---
title: "Cgo: convert <code>[]string</code> to <code>char**</code>"
layout: page
permalink: /cgo-convert-go-string-slice-c-string-array/
---

When using [cgo](https://pkg.go.dev/cmd/cgo#hdr-Passing_pointers) you
can convert a Go `string` to a C `char*` using `C.Cstring`. To not leak
memory, you must `C.free` the C string after use.

```go
s := "a Go string"
cstr := C.CString(s)
// ... do something with cstr ...
C.free(unsafe.Pointer(cstr))
```

It's a little more tricky to convert a Go `[]string` to a C `char**`
and get the memory management right. Here is one approach:

```go
// cStrings converts []string to char**.
// The caller is responsible for freeing the returned char* elements
// using the returned free function.
func cStrings(elems []string) (result **C.char, free func()) {
    var ret []*C.char
    var frees []func()

    for _, e := range elems {
        cstr := C.CString(e)
        ret = append(ret, cstr)
        frees = append(frees, func() { C.free(unsafe.Pointer(cstr)) })
    }

    freeAll := func() {
        for _, f := range frees {
            f()
        }
    }
    return (**C.char)(unsafe.Pointer(&ret[0])), freeAll
}
```

And usage looks like:

```go
// extern void some_func(int count, char** v);
import "C"

func someFunc(a []string) {
    cstrs, free := cStrings(a)
    defer free()

    C.some_func(len(a), cstrs)
}
```
