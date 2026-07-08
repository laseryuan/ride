-- Keep Neovim on the same shared configuration as Vim without shipping a
-- second init.vim entrypoint. Recent Neovim versions reject configs that have
-- both init.lua and init.vim in the same directory.
vim.env.DDPATH = vim.fn.expand('~/.vim')

-- Store ShaDa outside ~/.vim so user-id remapping only needs to chown the
-- writable Neovim state tree created by bin/user-mapping.sh.
local shada_dir = vim.fn.expand('~/.ride/state/nvim/shada')
vim.fn.mkdir(shada_dir, 'p')
vim.o.shadafile = shada_dir .. '/main.shada'

vim.opt.runtimepath:prepend('~/.vim')
vim.opt.runtimepath:append('~/.vim/after')
vim.opt.packpath:prepend('~/.vim')

vim.cmd('source ~/.vim/vimrc')
