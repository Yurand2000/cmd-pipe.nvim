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

## 📄 License

This project is licensed under the MIT license - see the [LICENSE](LICENSE) file for details.

## 👤 Author

This software was developed by:

- **Yuri Andriaccio** [yurand2000@gmail.com](mailto:yurand2000@gmail.com), [GitHub](https://github.com/Yurand2000).

---

**NVim Cmd-Pipe**
