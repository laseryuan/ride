-- Compatibility module for Lua-based Neovim plugin managers.
--
-- The Ride image installs plugins through the shared Vim/Vundle config in
-- ~/.vim/plugins.vim.  Keep this module for direct `require("plugins")` callers;
-- lazy.nvim `{ import = "plugins" }` callers load child specs such as
-- lua/plugins/vundle.lua.
return {
  { "VundleVim/Vundle.vim", lazy = true },
}
