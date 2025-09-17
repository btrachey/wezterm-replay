# WezTerm Replay
Parse the output of commands and extract useful information you may want to have
pasted into your next command prompt. A common example is the output of
`git push`. If your remote forge sends back a URL for opening a pull request,
this plugin will parse that URL, automatically prepend `open`, and paste the
full result into your next command line, e.g. 
``` bash
$ git push
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 10 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 302 bytes | 43.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
remote:
remote: Create a pull request for 'branch-name' on GitHub by visiting:
remote:      https://github.com/org/repo/pull/new/branch-name
remote:
To https://github.com/org/repo.git
 * [new branch]          branch-name -> branch-name
branch 'branch-name' set up to track 'origin/branch-name'.

$ <trigger plugin here>
$ open https://github.com/org/repo/pull/new/branch-name
```

By default, the plugin will be bound to <LEADER-r> for "replay".

## Requirement
This plugin relies on shell integration escape sequences to capture the previous
command's output. If you do not already have this set up, you can reference the
[WezTerm documentation](https://wezterm.org/shell-integration.html) to do so.

## Setup
Functions like a standard WezTerm plugin; add to your `wezterm.lua`:
```
local wezterm_replay = wezterm.plugin.require("https://github.com/btrachey/wezterm-replay")
wezterm_replay.apply_to_config(config)
```
## Customizing 
If you want to change the default trigger key on the right-hand side of the 
binding, you can add `replay_key = ...` to your config options when setting up
the plugin.
```
local config = wezterm.config_builder()
...
local wezterm_replay = wezterm.plugin.require("https://github.com/btrachey/wezterm-replay")
local opts = {
  replay_key = "l"
}
wezterm_replay.apply_to_config(config, opts)
```
### Custom Extractors
The following extractors are built-in:
* Text in backticks
* URLs via Lua patterns

If you'd like to add your own, they take the format of
```
{
  label = 'my_custom_extractor',
  prefix = 'prefix_string',
  postfix = 'postfix_string',
  func = function(s)
    logic here to extract useful things from `s`
    must return an array of strings
  end
  pattern = '`(.*)`'
}
```
`label: string` purely for descriptions; will be used some places in the plugin logs

`prefix: string|nil` a string to prepend to the parsed result, e.g. `open` for
prepending parsed URLs

`postfix: string|nil` a string to append to the parsed result

`extractor: fun(s: string): string[]` cannot be used with `pattern`; the logic
which extracts useful things from the previous output; must return `string[]`

`pattern: string` cannot be used with `extractor`; a Lua pattern that will be
applied to the previous command's output with `string.gmatch()` and all matches
returned as results.

Add them to your config opts table under `extractors =` e.g.
```
local config = wezterm.config_builder()
...
local wezterm_replay = wezterm.plugin.require("https://github.com/btrachey/wezterm-replay")
local opts = {
  extractors = {
    {
      label = "numbers_only",
      prefix = nil,
      postfix = nil,
      extractor = function(s)
        local matches = {}
        for match in string:gmatch(s, '%d') do
          table.insert(matches, match)
        end
        return matches
      end
    }
  }
}
wezterm_replay.apply_to_config(config, opts)
```
If you do not need the full power of a function and just want to define a Lua
pattern to extract matches, use the `pattern` field instead of `extractor`.

## Recall
If the extractors match multiple text segments, you will be dropped into a
standard WezTerm picker to choose the one you'd like to be inserted into your
next prompt. The plugin will also cache that list, allowing you to paste other
matches by using the recall command (default `LEADER-q`). The list will remain
cached until the next trigger of the "replay" functionality. Similarly to the
replay command, the key can be remapped:
```
local config = wezterm.config_builder()
...
local wezterm_replay = wezterm.plugin.require("https://github.com/btrachey/wezterm-replay")
local opts = {
  recall_key = "u"
}
wezterm_replay.apply_to_config(config, opts)
```

## Full Customization
If you'd like to control 100% of when the replay/recall functionality gets
triggered, you can use the functions directly from the plugin:
```
wezterm_replay.replay()
wezterm_replay.recall()
```
You should also then pass `skip_keybinds = true` in your custom config options in
order to prevent the plugin from auto-setting the defaults.
```
local config = wezterm.config_builder()
...
local wezterm_replay = wezterm.plugin.require("https://github.com/btrachey/wezterm-replay")
local opts = {
  skip_keybinds = true
}
wezterm_replay.apply_to_config(config, opts)
```

## WIP
The list of built-in extractors is far from complete, if you'd like to add some,
I'll be more than happy to review/merge PRs!
