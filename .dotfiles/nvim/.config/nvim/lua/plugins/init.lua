-- Compatibility module for Lua-based Neovim plugin managers.
--
-- The Ride image installs plugins through the shared Vim/Vundle config in
-- ~/.vim/plugins.vim.  Some Neovim bootstraps call `require("plugins")` or
-- lazy.nvim with `{ import = "plugins" }`; keeping a non-empty spec list here
-- avoids startup failures while leaving plugin ownership with Vimscript.
return {
  -- A harmless compatibility spec for lazy.nvim-style loaders.  The full
  -- plugin set remains defined in ~/.vim/plugins.vim for Vundle.
  { "VundleVim/Vundle.vim", lazy = true },
}
