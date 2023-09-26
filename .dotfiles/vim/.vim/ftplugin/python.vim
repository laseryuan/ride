map <buffer> <Leader>pry ofrom IPython import embed; embed(colors="neutral")<ESC>:w<CR>
map <buffer> <Leader>tra oimport ipdb; ipdb.set_trace()<CR>from IPython import embed; embed(colors="neutral")<ESC>:w<CR>

" https://www.reddit.com/r/vim/comments/zfvxps/python_folding/
function UpdateFolds()
    call SimpylFold#Recache()
    FastFoldUpdate!   " replace with `normal! zx` if you don't have FastFold
endfunction
autocmd BufWritePre <buffer> call UpdateFolds()
