"##############################################################"
" vim: set foldmethod=marker foldlevel=0 :
"
" DD Vim Configuration
"
" Danilo Dellaquila K-Gigas Computers S.L.
"
" This is the personal Vim configuration of Danilo Dellaquila.
"
" File: mappings.vim
"
"##############################################################"

" Key Reference Table {{{

    "<BS>           Backspace
    "<Tab>          Tab
    "<CR>           Enter
    "<Enter>        Enter
    "<Return>       Enter
    "<Esc>          Escape
    "<Space>        Space
    "<Up>           Up arrow
    "<Down>         Down arrow
    "<Left>         Left arrow
    "<Right>        Right arrow
    "<F1> - <F12>   Function keys 1 to 12
    "#1, #2..#9,#0  Function keys F1 to F9, F10
    "<Insert>       Insert
    "<Del>          Delete
    "<Home>         Home
    "<End>          End
    "<PageUp>       page-up
    "<PageDown>     page-down

" }}}

"Move {{{
    " up/down on displayed lines, not real lines. More useful than painful.
    " noremap k gk
    " noremap j gj

    " TODO Do also cnext and cprev as a fallback
    map <PageDown> :lnext<CR>
    map <PageUp>   :lprev<CR>
" }}}

" Find and replace {{{
    nmap <Leader>fr :%s//
    vmap <Leader>fr :s//
    " remap space to clear highlight
    nmap <SPACE> <SPACE>:nohlsearch<CR>

    """"""""""""""""""""""""""""""""""""
    " Find/Replace in projects using ack
    " http://www.isaacsloan.com/posts/3-vim-find-replace-in-projects-using-ack
    " Usage: typing /search/replace/ into whatever file I'm in on a new line and
    " then hitting <Leader>fr to remove the line and use it to find and replace in
    " files
    " The find and replace pattern is accessable from register b
    """"""""""""""""""""""""""""""""""""
    " Finds and replaces in files based on the the current line.
    " ^l : move to the first character after /
    " "a : register a
    " yt/ : yank the find pattern
    " ^v$h : select find and replace
    " "b : yank to register b
    " dd:w<CR> delete current line and save current file
    " :sp<CR> : split window
    " <C-R>a : paste from register a
    " <C-R>b : paste from register b
    " map <Leader>fr ^l"ayt/^v$h"bydd:w<CR>:sp<CR>:args `ack -l <C-R>a`<CR>:argdo %s<C-R>bge \| update<CR>

    " Find All and Replace: asks before all the changes.
    map <Leader>far ^l"ayt/^v$h"bydd:w<CR>:sp<CR>:args `ack -l <C-R>a`<CR>:argdo %s<C-R>bgce \| update<CR>
" }}}

" Window & Tabs {{{
    " Window
    nnoremap <Up>    3<C-w>-
    nnoremap <Down>  3<C-w>+
    nnoremap <Left>  3<C-w><
    nnoremap <Right> 3<C-w>>

    nnoremap _ :split<cr>
    nnoremap \| :vsplit<cr>

    " Tab
    nnoremap th  :tabfirst<CR>
    nnoremap tj  :tabnext<CR>
    nnoremap tk  :tabprev<CR>
    nnoremap tl  :tablast<CR>
    nnoremap tt  :tabedit<Space>
    nnoremap tn  :tabnext<Space>
    nnoremap tmj :tabmove +1<cr>
    nnoremap tmk :tabmove -1<cr>
    nnoremap td  :tabclose<CR>
" }}}

" Sort {{{
    vmap s :!sort<CR>
    vmap u :!sort -u<CR>

    " Write file when you forget to use sudo
    cmap w!! w !sudo tee % >/dev/null
" }}}

" Repeat {{{
    vnoremap . :normal .<CR>
    vnoremap @ :normal! @
" }}}

" Mistype  {{{
    " Disable K for manpages - not used often and easy to accidentally hit
    noremap K k

    " Avoid open command-line window accidentally
    nnoremap q: :q
" }}}

" Exit  {{{
    " Quick exit vim
    :map <Right><C-d> <Esc><Esc>:wqa<CR>
    :map! <Right><C-d> <Esc><Esc>:wqa<CR>
" }}}

" End of mappings.vim
