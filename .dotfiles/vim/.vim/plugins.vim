"##############################################################"
" vim: set foldmarker={,} foldlevel=0 foldmethod=marker :
"
" Install: :PluginInstall
"
"##############################################################"

    " Set DD Vim Configuration path (duplicated because it is need for calling
    " this file along)
    let $DDPATH=$HOME."/.vim"

    " Setup Vundle Support {
    "
    " Brief help
    " :PluginList       - lists configured plugins
    " :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
    " :PluginSearch foo - searches for foo; append `!` to refresh local cache
    " :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
    "
    " see :h vundle for more details or wiki for FAQ

        set nocompatible
        filetype off            " Required by Vundle
        "  set the runtime path to include Vundle and initialize
        set rtp+=$DDPATH/bundle/Vundle.vim
        call vundle#begin()

        " Let Vundle manage Vundle, this is required
        Plugin 'gmarik/Vundle.vim'

    " }


" Plugins {
    " abolish: easily search for, substitute, and abbreviate multiple variants of a word {
        Plugin 'tpope/vim-abolish'
    " }

    " ack: Perl module / CLI script 'ack' {
        Plugin 'mileszs/ack.vim'

        nnoremap <Leader>a :Ack -i 
        let g:ackhighlight = 1
    " }

    " addon-mw-utils: interpret a file by function and cache file automatically {
        Plugin 'MarcWeber/vim-addon-mw-utils'
    " }

    " armasm: Syntax highlighting for ARM assembler {
        Plugin 'nviennot/vim-armasm'
    " }

    " auto-pairs: insert or delete brackets, parens, quotes in pair {
        Plugin 'jiangmiao/auto-pairs'
    " }

    " bufsurf: enables surfing through buffers based on viewing history per window {
        Plugin 'ton/vim-bufsurf'
        nnoremap <Leader>b :BufSurfBack<cr>
        nnoremap <Leader>f :BufSurfForward<cr>
    " }

    " coffee-script: CoffeeScript support for vim {
        Plugin 'kchmck/vim-coffee-script'
    " }

    " css3-syntax: CSS3 syntax support to vim's built-in `syntax/css.vim` {
        Plugin 'hail2u/vim-css3-syntax'
    " }

    " ctrlp: Fuzzy file, buffer, mru, tag, etc finder {
        Plugin 'kien/ctrlp.vim'

        let g:ctrlp_prompt_mappings = {
            \ 'AcceptSelection("e")': ['<c-t>'],
            \ 'AcceptSelection("t")': ['<cr>', '<2-LeftMouse>'],
            \ }

        let g:ctrlp_map = '<Leader>.'
        let g:ctrlp_cmd = 'CtrlPMixed'
        let g:ctrlp_custom_ignore = {
                \ 'dir':  '\v[\/](tmp|vendor)|(\.(git|hg|svn))$',
                \ 'file': '/\.\|\.o\|\.so'
                \ }
        let g:ctrlp_follow_symlinks = 1
        let g:ctrlp_user_command = ['.git/', 'cd %s && git ls-files']
        let g:ctrlp_working_path_mode = 'rw' " change CWD to work with NerdTree
    " }

    " cucumber: Cucumber runtime files {
        Plugin 'tpope/vim-cucumber'
    " }

    " dockerfile: syntax file & snippets for Docker's Dockerfile {
        Plugin 'ekalinin/Dockerfile.vim'
    " }

    " editorconfig: EditorConfig plugin for Vim {
        Plugin 'editorconfig/editorconfig-vim'
    " }

    " elixir: configuration files for Elixir {
        Plugin 'elixir-lang/vim-elixir'
    " }

    " endwise: wisely add "end" in ruby, endfunction/endif/more in vim script, etc {
        Plugin 'tpope/vim-endwise'
    " }

    " fubitive: Add Bitbucket URL support to fugitive.vim's :Gbrowse command {
        Plugin 'tommcdo/vim-fubitive'
    " }

    " fugitive: a Git wrapper so awesome, it should be illegal {
        Plugin 'tpope/vim-fugitive'

        nnoremap <silent> <Leader>gd :Gdiff<CR>
        nnoremap <silent> <Leader>gb :Gblame<CR>
        nnoremap <silent> <Leader>gs :Gstatus<CR>:resize 30<CR>
    " }

    " Gist: vimscript for gist {
        Plugin 'mattn/webapi-vim'
        Plugin 'mattn/vim-gist'
    " }

    " gundo: Graph your Vim undo tree in style. {
        Plugin 'sjl/gundo.vim'
        nnoremap <S-u> :GundoToggle<CR>
        let g:gundo_close_on_revert=1
    " }

    " halfmove: Move the cursor half way up or down the screen {
        Plugin 'vim-scripts/halfmove'
    " }

    " haml: runtime files for Haml, Sass, and SCSS {
        Plugin 'tpope/vim-haml'
    " }

    " javascript: Vastly improved Javascript indentation and syntax support in Vim {
        Plugin 'pangloss/vim-javascript'
    " }

    " json: A better JSON for Vim: distinct highlighting of keywords vs values, JSON-specific (non-JS) warnings, quote concealing. Pathogen-friendly{
        Plugin 'elzr/vim-json'
    " }

    " jsx: React JSX syntax highlighting and indenting for vim. {
        Plugin 'mxw/vim-jsx'
    " }

    " L9:  Vim-script library, which provides some utility functions and commands for programming in Vim{
        Plugin 'vim-scripts/L9'
    " }

    " less: syntax for LESS {
        Plugin 'groenewege/vim-less'
    " }

    " markdown: Markdown Vim Mode {
        Plugin 'plasticboy/vim-markdown'
    " }

    " matchit: extended % matching for HTML, LaTeX, and many other languages {
        Plugin 'vim-scripts/matchit.zip'
    " }

    " molokai: A port of the monokai scheme for TextMate {
        Plugin 'nviennot/molokai'
    " }

    " nerdcommenter: intensely orgasmic commenting {
        Plugin 'scrooloose/nerdcommenter'
    " }

    " nerdtree: A tree explorer  {
        Plugin 'scrooloose/nerdtree'

        " TODO Merge the NERDTreeFind with Toggle inteilligently.
        nnoremap <C-g> :NERDTreeToggle<cr>

        let NERDTreeIgnore=[ '\.pyc$', '\.pyo$', '\.py\$class$', '\.obj$', '\.o$',
                           \ '\.so$', '\.egg$', '^\.git$', '\.cmi', '\.cmo' ]
        let NERDTreeHighlightCursorline=1
        let NERDTreeShowBookmarks=1
        let NERDTreeShowFiles=1
        let g:NERDTreeChDirMode = 2 "change CWD to work with ctrlp to
        let g:NERDTreeQuitOnOpen = 0 "do not close after a file has been open
        let g:NERDSpaceDelims = 1 " Put a space around comment markers
    " }

    " numbertoggle: Toggles between hybrid and absolute line numbers automatically {
        Plugin 'jeffkreeftmeijer/vim-numbertoggle'
    " }

    " python-syntax: Python syntax highlighting for Vim. {
        Plugin 'vim-python/python-syntax'
    " }

    " powerline: The ultimate vim statusline utility. {
        Plugin 'nviennot/vim-powerline'

        let g:Powerline_symbols = 'unicode'
    " }

    " quickfixsigns: Mark quickfix & location list items with signs {
        Plugin 'tomtom/quickfixsigns_vim'

        let g:quickfixsigns_classes=['qfl', 'vcsdiff', 'breakpoints']
    " }

    " rails: Ruby on Rails power tools {
        Plugin 'tpope/vim-rails'
    " }

    " rainbow: rainbow parentheses improved, shorter code, no level limit, smooth and fast, powerful configuration. {
        Plugin 'luochen1990/rainbow'
    " }

    " raml: syntax and language settings for RAML {
        Plugin 'IN3D/vim-raml'
    " }

    " repeat: enable repeating supported plugin maps with "." {
        Plugin 'tpope/vim-repeat'
    " }

    " rhubarb: GitHub extension for fugitive.vim {
        Plugin 'tpope/vim-rhubarb'
    " }

    " ruby: Ruby Configuration Files {
        Plugin 'vim-ruby/vim-ruby'
    " }

    " scala: {
        Plugin 'sidnair/scala-vim'
    " }

    " SimpylFold: No-BS Python code folding for Vim {
        Plugin 'tmhedberg/SimpylFold'
    " }

    " slim: Slim syntax highlighting for VIM {
        Plugin 'slim-template/vim-slim'
    " }

    " slimux: SLIME inspired tmux integration plugin for Vim {
    " https://github.com/esamattis/slimux/pull/80
        Plugin 'esamattis/slimux'

        let g:slimux_select_from_current_window = 1
        map <Leader>s :SlimuxREPLSendLine<CR>
        " from begin to last non whitespace character
        map <Leader>l ^vg_:SlimuxREPLSendSelection<CR>
        vmap <Leader>s :SlimuxREPLSendSelection<CR>
        map <Leader>r :SlimuxGlobalConfigure<CR>
    " }

    " snipmate: aims to be a concise vim script that implements some of TextMate's snippets features in Vim {
        Plugin 'nviennot/snipmate.vim'
    " }

    " solidity: syntax file for solidity {
        Plugin 'tomlion/vim-solidity'
    " }

    " speeddating: use CTRL-A/CTRL-X to increment dates, times, and more {
        Plugin 'tpope/vim-speeddating'
    " }

    " supertab: Perform all your vim insert mode completions with Tab {
        Plugin 'ervandew/supertab'
    " }

    " surround: quoting/parenthesizing made simple {
        Plugin 'tpope/vim-surround'
    " }

    " syntastic: Syntax checking hacks for vim {
        Plugin 'scrooloose/syntastic'
        let g:syntastic_enable_signs=1
        let g:syntastic_loc_list_height=3
        let g:syntastic_mode_map = { 'mode': 'active',
                                   \ 'active_filetypes': [],
                                   \ 'passive_filetypes': ['c', 'scss', 'html', 'scala'] }
        " let g:syntastic_debug=1 "use :messages command to show the command run after saving the file
    " }

    " tabular: text filtering and alignment {
        Plugin 'godlygeek/tabular'

        noremap \= :Tabularize /=<CR>
        noremap \: :Tabularize /^[^:]*:\zs/l0l1<CR>
        noremap \> :Tabularize /=><CR>
        noremap \, :Tabularize /,\zs/l0l1<CR>
        noremap \{ :Tabularize /{<CR>
        noremap \\| :Tabularize /\|<CR>
        noremap \& :Tabularize /\(&\\|\\\\\)<CR>
    " }

    " tagbar: displays tags in a window, ordered by scope {
        Plugin 'majutsushi/tagbar'

        nnoremap <Leader>t :TagbarOpen fjc<CR>
    " }

    " tlib: Some utility functions for VIM {
        Plugin 'tomtom/tlib_vim'
    " }

    " unimpaired: pairs of handy bracket mappings {
        Plugin 'tpope/vim-unimpaired'
    " }

    " unimpaired: pairs of handy bracket mappings {
        Plugin 'posva/vim-vue'
    " }

    " xmledit: A filetype plugin for VIM to help edit XML files {
        Plugin 'sukima/xmledit'
    " }

    " YankRing: Maintains a history of previous yanks, changes and deletes {
        Plugin 'vim-scripts/YankRing.vim'

        nnoremap <C-y> :YRShow<cr>
        let g:yankring_history_dir = '$HOME/.vim'
        let g:yankring_manual_clipboard_check = 0

        " Make Y consistent with D and C
        function! YRRunAfterMaps()
          nnoremap <silent> Y :<C-U>YRYankCount 'y$'<CR>
        endfunction
    " }

" }

    " All of your Plugins must be added before the following line
    call vundle#end()            " required
" End of plugins.vim
