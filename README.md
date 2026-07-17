# NVim Cmd-Pipe

## 🚀 Quick Start

### Setup

```lua
vim.pack.add({ 'https://github.com/Yurand2000/cmd-pipe.nvim' })
require("cmd-pipe").setup({})
```

### Available Commands

- `:Pipe <cmd/args>` \
  Take the current buffer's contents and feed it to STDIN to the given command. Its output is put in a new buffer and the current view is switched to that.
- `:PipeA <cmd/args>` \
  Async version of `:Pipe`. The command is started in background and notifies the user when a new buffer with the STDOUT contents is created.

- `:PipeBuf <buf number?>` \
  Take the current buffer's content and feed it to STDIN to the command written in the given buffer (or the current buffer if not specified).
  (If unspecified, runs the command with itself as the content!)
- `:PipeBufA <buf number?>` \
  Same as `:PipeBuf` but Async, like `:PipeA`.

### Extra Syntax

- `$$<number?>` \
  In the `<cmd/args>` for `:Pipe` and `:PipeA`, or in the command buffer for `:PipeBuf` and `:PipeBufA`, any string of the form `$$<number>` is substituted with the name of a temporary file containing the data from the specified `<number>` buffer. Useful to pass multiple buffers to a command. If the buffer number is unspecified, it behaves like you selected the currently active buffer.

### Examples

Create a new buffer containing the current directory contents, using `ls`. Note how the input of the currently open buffer is unused by `ls`.
```vim
:Pipe ls
```

Using `csvlook` from `csvkit`, create a human-readable table from the csv data in the currently open buffer. Since `my_file.csv` is big and `csvlook` takes a second, run it with `:PipeA` so I can keep working while it is rendered in background.
```vim
:view /path/to/my_file.csv
:PipeA csvlook
```

Assume you have two csv tables in buffers 1 and 2, join them using `csvjoin` on the key `Key`, then display with `csvlook`.
```vim
:Pipe csvjoin -c Key $$1 $$2 | csvlook
```

Assume you have a long, maybe multi-line command in buffer 1:
```vim
:b1
```
```sh
csvcut -c Key,Value |
csvgrep -c Value -m 'myValue' |
csvlook
```

Assume you have a csv document in buffer 2, run this complex command on that data:
```vim
:b2
:PipeBuf 1
```

## 📄 License

This project is licensed under the MIT license - see the [LICENSE](LICENSE) file for details.

## 👤 Author

This software was developed by:

- **Yuri Andriaccio** [yurand2000@gmail.com](mailto:yurand2000@gmail.com), [GitHub](https://github.com/Yurand2000).

---

**NVim Cmd-Pipe**
