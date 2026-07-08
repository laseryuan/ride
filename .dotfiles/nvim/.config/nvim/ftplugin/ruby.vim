map <buffer> <Leader>pry obinding.pry<ESC>:w<CR>
map <Leader>source :w<CR> :call SlimuxSendCode("source(\"" .@% . "\")\n")<CR>
