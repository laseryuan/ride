"##############################################################"
" vim: set foldmarker={,} foldlevel=0 foldmethod=marker :
"
" DD Vim Configuration
"
" Danilo Dellaquila K-Gigas Computers S.L.
"
" This is the personal Vim configuration of Danilo Dellaquila.
"
" File: filetype.vim
"
"##############################################################"

augroup filetypedetect
  au! BufRead,BufNewFile *.zcml     set filetype=xml
  au! BufRead,BufNewFile *.rst      setfiletype rst
  au! BufRead,BufNewFile *.txt      setfiletype rst
  au! BufRead,BufNewFile *.md       setfiletype markdown
  au! BufRead,BufNewFile *.wiki     setfiletype moin
  "au! BufNewFile,BufRead *.wiki     setfiletype Wikipedia
augroup END

" to_html settings
let html_number_lines = 1
let html_ignore_folding = 1
let html_use_css = 1
let xml_use_xhtml = 1
