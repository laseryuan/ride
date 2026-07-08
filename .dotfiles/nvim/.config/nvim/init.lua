-- Keep Neovim on the same configuration path as Vim.
--
-- Neovim prefers init.lua over init.vim when both files exist.  Source the
-- checked-in Vimscript entrypoint explicitly so installs that expect a Lua
-- entrypoint do not try to load a missing lazy.nvim `plugins` module.
vim.cmd('source ~/.config/nvim/init.vim')
