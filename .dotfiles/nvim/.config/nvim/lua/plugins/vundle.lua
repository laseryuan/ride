-- Minimal lazy.nvim spec so `import = "plugins"` has at least one child spec.
-- Ride's real plugin list is still managed by Vundle in ~/.vim/plugins.vim;
-- this compatibility spec prevents lazy.nvim from aborting startup when an
-- image or host-mounted init.lua imports the `plugins` module.
return {
  { "VundleVim/Vundle.vim", lazy = true },
}
