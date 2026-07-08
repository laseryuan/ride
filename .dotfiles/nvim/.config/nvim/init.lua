-- Keep Neovim on the same shared configuration as Vim without shipping a
-- second init.vim entrypoint. Recent Neovim versions reject configs that have
-- both init.lua and init.vim in the same directory.
vim.env.DDPATH = vim.fn.expand('~/.vim')

-- Store ShaDa outside ~/.vim so user-id remapping only needs to chown the
-- writable Neovim state tree created by bin/user-mapping.sh.
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

vim.opt.runtimepath:prepend('~/.vim')
vim.opt.runtimepath:append('~/.vim/after')
vim.opt.packpath:prepend('~/.vim')

vim.cmd('source ~/.vim/vimrc')
