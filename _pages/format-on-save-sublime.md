---
title: Run a language-specific formatter on save in Sublime
layout: page
permalink: /format-on-save-sublime/
---

_Update_: I've seen a better working alternative. Use this [custom
command][4]. It's a stand-in replacement for `exec`, except that it
expands variables.

_Update 2_: For Haskell specifically, you may be better
off using LSP for formatting in Sublime.

The [Hooks](https://github.com/twolfson/sublime-hooks) package for
Sublime Text provides a hook called `on_post_save_async_language`, which
you can use to run a Sublime Text command (mind, not directly a binary
on the computer) after a file is saved.

So, for example, to run the `hindent` formatter for Haskell code, you
could put this in the "Settings - Syntax Specific" file for Haskell.
Note the `$file` variable, which is intended to indicate the current
file.

    "on_post_save_async_language": [
        {
            "command": "exec",
            "args": { "cmd": ["hindent", "$file"] },
            "scope": "window",
        },
    ],

Unfortunately, this doesn't work with Sublime Text build 4121, the
latest version right now. The `$file` variable isn't expanded by the
Sublime Text command `exec`, though it is [documented][2] as being
supported (_update_: I've since learned that `exec` will not expand
variables; Sublime's build system process does the expansion before
calling `exec`).

A working alternative is to write a custom command that can run
`hindent` with the current view's file. Place the following in a .py
file in Sublime's `Packages/User` directory.

```py
import sublime
import sublime_plugin

class HindentCommand(sublime_plugin.WindowCommand):
    def run(self):
        filename = self.window.active_view().file_name()
        if not filename:
            print("hindent: no usable file_name(); not running")
            return
        self.window.run_command("exec", {
            "cmd": ["hindent", filename],
            "quiet": True
        })
```

It sets up a Sublime Text command named "hindent", which calls the
`hindent` binary, still using exec like in the earlier code block. But
here, we can obtain the filename programmatically with the
[`file_name()` API][3], instead of relying on the `$file` variable
expansion.


Now all that's left is to call this custom command on save:

    "on_post_save_async_language": [
        {
            "command": "hindent",
            "scope": "window",
        },
    ],

[2]: https://www.sublimetext.com/docs/build_systems.html#variables
[3]: https://www.sublimetext.com/docs/api_reference.html#sublime.View
[4]: https://github.com/STealthy-and-haSTy/SublimeScraps/blob/e534d359c3317e234d728782c1b841cbe175ac70/plugins/menu_exec.py
