-- Keep Neovim configuration independent from Vim. Vim owns ~/.vim, while
-- Neovim sources copied Vimscript settings from ~/.config/nvim so each editor
-- can evolve without sharing config files.
vim.env.DDPATH = vim.fn.expand('~/.config/nvim')

-- Store ShaDa outside ~/.config/nvim so user-id remapping only needs to chown
-- the writable Neovim state tree created by bin/user-mapping.sh.
local shada_dir = vim.fn.expand('~/.ride/state/nvim/shada')
vim.fn.mkdir(shada_dir, 'p')
vim.o.shadafile = shada_dir .. '/main.shada'

-- Neovim falls back to tmux as a clipboard provider when $TMUX is set. If tmux
-- has no paste buffers yet, `tmux save-buffer -` prints "no buffers" during
-- clipboard probes. Route the tmux provider through a shell command that treats
-- an empty tmux buffer list as an empty clipboard instead of a startup warning.
if vim.env.TMUX ~= nil then
  vim.g.clipboard = {
    name = 'tmux-no-warning',
    copy = {
      ['+'] = { 'sh', '-c', 'tmux load-buffer -' },
      ['*'] = { 'sh', '-c', 'tmux load-buffer -' },
    },
    paste = {
      ['+'] = { 'sh', '-c', 'tmux save-buffer - 2>/dev/null || true' },
      ['*'] = { 'sh', '-c', 'tmux save-buffer - 2>/dev/null || true' },
    },
    cache_enabled = 1,
  }
end

vim.opt.runtimepath:prepend('~/.config/nvim')
vim.opt.runtimepath:append('~/.config/nvim/after')
vim.opt.packpath:prepend('~/.config/nvim')

vim.cmd('source ~/.config/nvim/vimrc')
