---
title: "Validate <code>Writes</code> and <code>Reads</code> to underlying <code>io.Writers</code> and <code>io.Readers</code>"
layout: page
permalink: /validate-io-writer-writes/
---

In Go it's common to have an `io.Writer` wrapping another `io.Writer`.
The `gzip.Writer` type in the standard library is a good example. Writes
to the `gzip.Writer` eventually result in Writes to the wrapped
`io.Writer` (the one given to `gzip.NewWriter`).


```go
package gzip // import "compress/gzip"

type Writer struct { ... }

func NewWriter(w io.Writer) *Writer
func (z *Writer) Write(p []byte) (int, error)
```

## Misbehaving Writers

If you implement an `io.Writer` that wraps another `io.Writer` it helps
to check for misbehaving Writers. An incorrect `io.Writer`, for example,
is one that returns a `nil` error along with `n < len(p)`[^1] either
accidentally or because of a true bug in its implementation.

If you propagate `(n, err)` return values from an incorrect
underlying Writer in your own Writer without checking, as in:

```go
package me

type Writer struct{ w io.Writer }

func (w *Writer) Write(p []byte) (int, error) {
    // NOTE: w.w is the underlying io.Writer
    return w.w.Write(p)
}
```

it makes it harder for users to detect and debug the underlying
misbehaving Writer, because the bug is propagated instead of being
detected at the earliest. Additionally your `Write` method too now
violates the `io.Writer` interface.

So it helps to validate the return value of Write calls to the underlying
Writer.

## Validating a Write

Validating an Write involves checking two requirements from the
`io.Writer` interface.

> Write returns the number of bytes written from p (0 <= n <= len(p)) and
> any error encountered that caused the write to stop early.

and

> Write must return a non-nil error if it returns n < len(p).

```go
func (w *Writer) Write(p []byte) (int, error) {
    return validatedWrite(p, w.w)
}
```

```go
func validatedWrite(p []byte, w io.Writer) (int, error) {
    m, err := w.Write(p)
    if m < 0 || m > len(p) {
        panic("invalid Write count")
    }
    if m < len(p) && err == nil {
        return m, io.ErrShortWrite
    }
    return m, nil
}
```

## Reads

Same goes for `io.Reader`s and `Read` calls too!

```go
func validatedRead(p []byte, r io.Reader) (int, error) {
    n, err := r.Read(p)
    if n < 0 || n > len(p) {
        panic("invalid Read count")
    }
    return n, err
}
```

[^1]: This violates the `io.Writer` interface, whose documentation says: "Write must return a non-nil error if it returns n < len(p)."

