" Use the shared Vim configuration for Neovim as well.
" Plugins, including slimux, are installed under ~/.vim/bundle by Vundle.
" Neovim data lives in ~/.local/share/nvim, which is stowed from
" .dotfiles/nvim so image-installed plugin managers can persist there.
let $DDPATH = $HOME . '/.vim'
set runtimepath^=~/.vim runtimepath+=~/.vim/after
set packpath^=~/.vim
source ~/.vim/vimrc
