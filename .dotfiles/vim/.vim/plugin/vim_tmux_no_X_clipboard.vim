" Share clipboards between vim and tmux without xsel or xclip (which require X and
" X forwarding with SSH) and without changing tmux shortcuts. Requires only tail.
" 
" Great for an ssh session to you linode or droplet.
" 
" Uses z buffer in vim and writes output to ~/.vim-tmux-clipboard and then to tmux's paste
" buffer, and reads it back in cleanly for putting (puddin').
"
" NOTE: tmux has an undocumented command limit! https://github.com/tmux/tmux/issues/254
"       this means if you mean to copy larger bits of code (entire functions) tmux will
"       not copy the data into its buffer. In those cases, it's better to read from the
"       ~/.vim-tmux-clipboard file.
"       IE: Python interactive shell: def put(): exec(open('~/.vim-tmux-clipboard').read());

" Example vimrc mappings
" Visual mode yank selected area to tmux paste buffer (clipboard)
vnoremap <leader>tmuxy "zy:silent! call SendZBufferToHomeDotClipboard()<cr>
" Put from tmux clipboard
map <leader>tmuxp :silent! call HomeDotClipboardPut()<cr>

function! SendZBufferToHomeDotClipboard()
    " Yank the contents buffer z to file ~/.vim-tmux-clipboard and tmux paste buffer
    " For use with HomeDotClipboardPut()
    silent! redir! > ~/.vim-tmux-clipboard
    silent! echo @z
    silent! redir END 
    " the redir has a newline in front, so tail -n+2 skips first line
    silent! !tail -n+2 ~/.vim-tmux-clipboard > ~/.vim-tmux-clipboard.1;mv ~/.vim-tmux-clipboard.1 ~/.vim-tmux-clipboard
    silent! !tmux load-buffer ~/.vim-tmux-clipboard
    silent! redraw!
endfunction
function! HomeDotClipboardPut()
    " Paste/Put the contents of file ~/.vim-tmux-clipboard
    " For use with SendZBufferToHomeDotClipboard()
    silent! !tmux save-buffer ~/.vim-tmux-clipboard
    silent! redraw!
    silent! let @z = system("cat ~/.vim-tmux-clipboard")
    " put the z buffer on the line below
    silent! exe "norm o\<ESC>\"zp"
endfunction
