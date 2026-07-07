" Use the shared Vim configuration for Neovim as well.
" Plugins, including slimux, are installed under ~/.vim/bundle by Vundle.
let $DDPATH = $HOME . '/.vim'
set runtimepath^=~/.vim runtimepath+=~/.vim/after
set packpath^=~/.vim
source ~/.vim/vimrc
