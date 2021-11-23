---
title: Change color schemes on pkg.go.dev
layout: page
permalink: /pkg.go.dev-color-schemes/
---

The [pkg.go.dev](https://pkg.go.dev) site currently picks either a light color
scheme or a dark color scheme based on the user agent-provided
`prefers-color-scheme` setting (typically this is based on your
operating system color scheme). It does not allow you to
manually toggle the color scheme on the page UI.

But there's a workaround. With a pkg.go.dev page open, you can run the
<!-- NOTE: keep on same line. the '+' becomes a bullet otherwise -->
following in the browser's JavaScript console (in Safari <kbd>cmd</kbd> + <kbd>alt</kbd> + <kbd>c</kbd>)
to switch the site's color scheme.
Reload the page after.

```
document.cookie = "prefers-color-scheme=light" // for light scheme
```
or
```
document.cookie = "prefers-color-scheme=dark" // for dark scheme
```

I much like the light scheme on the site, though my operating system
color scheme is dark.

The cookies were once being used to let users toggle the color
scheme, but the feature was [rolled back][1] due to an issue. But the
cookies still work partially.

[1]: https://github.com/golang/pkgsite/commit/a0af5929e0f9b881e04e37c80ce9dfb1d2dc36f2
