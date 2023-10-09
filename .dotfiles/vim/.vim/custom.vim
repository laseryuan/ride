"##############################################################"
" vim: set foldmarker={,} foldlevel=0 foldmethod=marker :
"
" DD Vim Configuration
"
" Danilo Dellaquila K-Gigas Computers S.L.
"
" This is the personal Vim configuration of Danilo Dellaquila.
"
" File: custom.vim
"
"##############################################################"

" viminfo: remember certain things when we exit
" (http://vimdoc.sourceforge.net/htmldoc/usr_21.html)
"   %    : saves and restores the buffer list
"   '100 : marks will be remembered for up to 30 previously edited files
"   /100 : save 100 lines from search history
"   h    : disable hlsearch on start
"   "500 : save up to 500 lines for each register
"   :1000 : up to 1000 lines of command-line history will be remembered
"   n... : where to save the viminfo files
set viminfo=%100,'100,/100,h,\"500,:1000,n~/.vim/viminfo

" ctags: recurse up to home to find tags. See
" http://stackoverflow.com/questions/563616/vim-and-ctags-tips-and-tricks
" for an explanation and other ctags tips/tricks
set tags+=tags;$HOME

" Undo file {
    set undolevels=10000
    if has("persistent_undo")
      " set undodir=~/.vim/undo       " Allow undoes to persist even after a file is closed
      " set undofile

        " define a path to store persistent undo files.
        let target_path = expand('~/.ride/vim/undo')
        " create the directory and any parent directories
        " if the location does not exist.
        if !isdirectory(target_path)
            call system('mkdir -p ' . target_path)
        endif
        " point Vim to the defined undo directory.
        let &undodir = target_path
        " finally, enable undo persistence.
        set undofile
    endif
" }

" Copy & Paste {{{
    set pastetoggle=<F2>
" }}}

" VimDiff {{{
    " vertical: vertical display
    " filler: try fill empty line to align same codes
    " iwhite: ignore difference with white space
    set diffopt=vertical,filler,iwhite
" }}}

" Local config {
    " add 10 spaces to auto wrapped line
    let &showbreak=repeat(' ', 10)

    " ignore these files when completing names and in Ex
    set wildignore+=log/**
    set wildignore+=.svn,CVS,.git,*.o,*.a,*.class,*.mo,*.la,*.so,*.obj,*.swp,*.jpg,*.png,*.xpm,*.gif,*.pdf,*.bak,*.beam
    " set of file name suffixes that will be given a lower priority when it comes to matching wildcards
    set suffixes+=.old
" }

" Search options {
    set ignorecase
    set smartcase
    set hlsearch
    set incsearch
    set showmatch
" }

" folding {
    set formatoptions-=t formatoptions+=croql
    set foldmethod=syntax
    set foldlevelstart=20 "open all folder when start
    let ruby_fold=1
    let r_syntax_folding=1
    let sh_fold_enabled=1         " sh"
" }

" Formatting {
    " Formatting, indentation and tabbing
    " Set maximum width of text line
    set textwidth=80

    " Tabs settings
    set smarttab                    " Make <tab> and <backspace> smarter
    set expandtab
    set tabstop=4

    " Automatic Indentation
    set autoindent smartindent
    set shiftwidth=4

    " Misc
    set hidden                      " Don't abandon buffers moved to the background
    set wildmenu                    " Enhanced completion hints in command line
    set wildmode=list:longest,full  " Complete longest common match and show possible matches and wildmenu
    set complete=.,w,b,u,U,t,i,d    " Do lots of scanning on tab completion
" }

" Swap file {
    set updatecount=100             " Write swap file to disk every 100 chars

    " define a path to store persistent swap files.
    let target_path = expand('~/.ride/vim/swap')
    " create the directory and any parent directories
    " if the location does not exist.
    if !isdirectory(target_path)
        call system('mkdir -p ' . target_path)
    endif
    set directory=~/.ride/vim/swap       " Directory to use for the swap file
    set history=1000                " Remember 1000 commands
    set scrolloff=3                 " Start scrolling 3 lines before the horizontal window border
    set visualbell t_vb=            " Disable error bells
    " set shortmess+=A                " Always edit file, even when swap file is found
" }

" Programming Settings {

    " Set backspace key working properly
    set backspace=eol,start,indent  " Allow backspacing over indent, eol, & start

    " Enconding text
    set encoding=utf8

    " Syntax
    syntax on

    " C++
    let g:syntastic_cpp_include_dirs = [ 'include', 'include/eigen', '/usr/local/include/gsl', '/usr/lib/llvm-3.5/include' ]
    let g:syntastic_cpp_compiler = 'clang++'
    let g:syntastic_cpp_compiler_options = ' -std=c++11'

" }

" Vim UI {

    " Statusline
    set laststatus=2

    " Line numbers
    set number

    set cursorline
    set list!                       " Display unprintable characters
    set listchars=tab:▸\ ,trail:•,extends:»,precedes:«
    if $TERM =~ '256color'
      set t_Co=256
    elseif $TERM =~ '^xterm$'
      set t_Co=256
    endif

    " Color Scheme and Background
    colorscheme molokai
    hi CursorLine  cterm=underline
" }

" Cscope {{{
  if has("cscope")
    " Use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
    set cscopetag

    " Check cscope for definition of a symbol before checking ctags. Set to 1 if
    " you want the reverse search order.
    set csto=0

    " Add any cscope database in current directory
    if filereadable("cscope.out")
      cs add cscope.out
    endif

    " Show msg when any other cscope db is added
    set cscopeverbose
  end
" }}}

" When opening a file, always jump to the last cursor position
autocmd BufReadPost *
    \ if line("'\"") > 0 && line ("'\"") <= line("$") |
    \     exe "normal g'\"zz" |
    \ endif |

" After 4s of inactivity, check for external file modifications on next keyrpress
au CursorHold * if &buftype != 'nofile' | checktime | endif
