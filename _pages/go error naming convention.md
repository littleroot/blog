---
title: "Go error naming conventions"
layout: page
permalink: /go-error-naming/
---

Go programmers—those who work on the Go programming language itself and
those who write programs using Go—have developed a few not-oft-spoken
conventions for naming error variables and error types.

There are 7 naming scenarios.

  1. <a class="no-underline" href="#1-declared-error-variables">Declared error variables</a>
  1. <a class="no-underline" href="#2-declared-error-types">Declared error types</a>
  1. <a class="no-underline" href="#3-assigned-error-variables-regular">Assigned error variables (regular)</a>
  1. <a class="no-underline" href="#4-assigned-error-variables-avoid-shadowing">Assigned error variables (avoid shadowing)</a>
  1. <a class="no-underline" href="#5-assigned-error-variables-file-scope">Assigned error variables (file scope)</a>
  1. <a class="no-underline" href="#6-errorsas-variables">`errors.As` variables</a>
  1. <a class="no-underline" href="#7-method-receivers">Method receivers</a>

In addition to these guidelines, never shadow the predeclared
identifier `error`. Use a linter such as [predeclared][3] to catch
these.

## 1. Declared error variables

The first two scenarios are described in [Uber's Go style guide][1]. To
summarize the first scenario, use the prefixes `Err` or `err` for
declared error variables, as in:

```go
var ErrFormat = errors.New("zip: not a valid zip file")
var errLongName = errors.New("zip: FileHeader.Name too long")
```

## 2. Declared error types

Use the name `Error` or the suffix `Error` for declared error types, as
in:

```go
package url // import "net/url"

type Error struct {
    Op  string
    URL string
    Err error
}

func (e *Error) Error() string
func (e *Error) Temporary() bool
/* ... more declarations elided ... */
```

Or as in:

```go
package os // import "os"

type LinkError struct {
    Op  string
    Old string
    New string
    Err error
}

func (e *LinkError) Error() string
func (e *LinkError) Unwrap() error
```

Now for the rest of the scenarios.

## 3. Assigned error variables (regular)

An assigned error variable, for the purpose of this post, is a variable
that holds a returned error. For example, `err` is an assigned error
variable below.

```go
n, err := w.Write(p)
```

For assigned error variables in function scope, name the error variable
`err`. And not anything more specific such as `writeErr`.

## 4. Assigned error variables (avoid shadowing)

Sometimes you want to avoid shadowing of an existing error variable
inside your function. In such scenarios, name the second error variable
`err1`, so that it doesn't shadow the previous error variable.

If you use more error variables, name them `err2`, `err3`, and so on.
Keep in mind, this *only* applies if you have a reason for a previous
error variable (`err` in the example above) to not be lost due to
shadowing.

For example, consider this function that caches the given data by
writing it to a `io.WriteCloser`. The function wants to close the writer
regardless of whether the Write succeeds. Additionally, the function
wants to return any error, either from the Write or the Close, with a
Write error taking precedence over a Close error.

```go
func Cache(w io.WriteCloser, data []byte) error {
    _, err := w.Write(data)
    _, err1 := w.Close()
    if err != nil {
        return err
    }
    return err1
}
```

See the [gofmt source code][2] for another example that uses similar
naming.

Names such as `werr` or `cerr` are also appropriate here, if the
assigned variables are far apart or in a longer function.

## 5. Assigned error variables (file scope)

If the assigned error variable is in the file-scope it is
appropriate and improves readability to use a more specific name
such as `setupErr`. For example:

```go
package pax

var (
    once     sync.Once
    setupErr error
)

func setup() error { /* body elided */ }

func Create() error {
    once.Do(func() { setupErr = setup() })
    if setupErr != nil {
        return setupErr
    }
    // ... more code ...
}

func Read() error {
    once.Do(func() { setupErr = setup() })
    if setupErr != nil {
        return setupErr
    }
    // ... more code ...
}
```

Note that we do *not* want the names `setupErr` or `setupError`; these
names conflict with scenarios 1 and 2, respectively.

## 6. `errors.As` variables

When using [`errors.As`](https://pkg.go.dev/errors), name
the target error variable `[c]err` where `[c]` is the lowercased first
character of the target error type.

For example, `perr` for `PathError`, as in:

```go
var perr *fs.PathError
if errors.As(err, &perr) {
    log.Fatal(perr.Path)
}
```

As a special case, consider avoiding the name `eerr`.

Single character names such as `e` are okay in this scenario, as in:

```go
func main() {
    if err := run(); err != nil {
        var e exitCodeError
        if errors.As(err, &e) {
            os.Exit(e.code)
        } else {
            os.Exit(1)
        }
    }
}
```

## 7. Method receivers

Use one or two character-long variable names, as you typically would
for a receiver name.

```go
type MyError struct {}
func (m *MyError) Error() string { /* body elided */ }
```

The names `e` or `me` are also appropriate for this example, but avoid
names such as `merr`, `err`, or `myErr`.

[1]: https://github.com/uber-go/guide/blob/master/style.md#error-naming
[2]: https://cs.opensource.google/go/go/+/master:src/cmd/gofmt/gofmt.go;l=493-495;drc=1ce6fd03b8a72fd8346fb23a975124edf977d25e
[3]: https://github.com/nishanths/predeclared
