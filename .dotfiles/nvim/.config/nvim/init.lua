-- Keep Neovim configuration independent from Vim. Vim owns ~/.vim, while
-- Neovim sources copied Vimscript settings from ~/.config/nvim so each editor
-- can evolve without sharing config files.
vim.env.DDPATH = vim.fn.expand('~/.config/nvim')

-- Store ShaDa outside ~/.config/nvim so user-id remapping only needs to chown
-- the writable Neovim state tree created by bin/user-mapping.sh.
local shada_dir = vim.fn.expand('~/.ride/state/nvim/shada')
vim.fn.mkdir(shada_dir, 'p')
vim.o.shadafile = shada_dir .. '/main.shada'

-- Neovim falls back to tmux as a clipboard provider when $TMUX is set, but
-- `tmux load-buffer`/`save-buffer` only reach tmux's own paste buffer -- they
-- never leave the pty, so they can't reach the host clipboard (e.g. macOS via
-- iTerm2) the way tmux's own copy-mode does. Use OSC 52 instead: it's the
-- same escape-sequence relay copy-mode already uses, so it reaches the real
-- host clipboard through tmux (set-clipboard on in .tmux.conf), SSH, and
-- docker alike. Requires the terminal to allow OSC 52 (e.g. iTerm2:
-- Preferences > General > Selection > "Applications in terminal may access
-- clipboard").
if vim.env.TMUX ~= nil then
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
      ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
    },
    paste = {
      ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
      ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
    },
  }

  -- Make the unnamed register an alias for "+ so plain yy/dd/p transparently
  -- share with the host clipboard, instead of requiring "+y / "+p every time.
  vim.opt.clipboard = 'unnamedplus'
end

vim.opt.runtimepath:prepend('~/.config/nvim')
vim.opt.runtimepath:append('~/.config/nvim/after')
vim.opt.packpath:prepend('~/.config/nvim')

vim.cmd('source ~/.config/nvim/vimrc')
