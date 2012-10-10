" Run tidyall on the current buffer. If an error occurs, show it and leave it
" in tidyall.ERR, and undo any changes.

command! TidyAll :call TidyAll()
function! TidyAll()
    let cur_pos = getpos( '.' )
    let cmdline = ':1,$!tidyall --mode editor --pipe %:p 2> tidyall.ERR'
    execute( cmdline )
    if v:shell_error
        echo "\nContents of tidyall.ERR:\n\n" . system( 'cat tidyall.ERR' )
        silent undo
    else
        call system( 'rm tidyall.ERR' )
    endif
    call setpos( '.', cur_pos )
endfunction

" Uncomment to set leader to ,
" let mapleader = ','

" Bind to ,t (or leader+t)
map <leader>t :TidyAll<cr>
