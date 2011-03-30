" IndentCommentPrefix.vim: Keep comment prefix in column 1 when indenting. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - IndentCommentPrefix.vim autoload script. 
"
" Copyright: (C) 2008-2011 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.10.001	30-Mar-2011	Split off separate documentation and autoload
"				script. 
"				file creation. 

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_IndentCommentPrefix') || (v:version < 700)
    finish
endif
let g:loaded_IndentCommentPrefix = 1

"- configuration --------------------------------------------------------------
if ! exists('g:IndentCommentPrefix_alternativeOriginalCommands')
    let g:IndentCommentPrefix_alternativeOriginalCommands = 1
endif

inoremap <silent> <C-t> <C-o>:call IndentCommentPrefix#InsertMode(0)<CR>
inoremap <silent> <C-d> <C-o>:call IndentCommentPrefix#InsertMode(1)<CR>

nnoremap <silent> <Plug>IndentCommentPrefix0 :<C-u>call IndentCommentPrefix#Range(0,1,v:count1)<CR>
vnoremap <silent> <Plug>IndentCommentPrefix0      :call IndentCommentPrefix#Range(0,v:count1,1)<CR>
nnoremap <silent> <Plug>IndentCommentPrefix1 :<C-u>call IndentCommentPrefix#Range(1,1,v:count1)<CR>
vnoremap <silent> <Plug>IndentCommentPrefix1      :call IndentCommentPrefix#Range(1,v:count1,1)<CR>
if ! hasmapto('<Plug>IndentCommentPrefix0', 'n')
    nmap <silent> >> <Plug>IndentCommentPrefix0
endif
if ! hasmapto('<Plug>IndentCommentPrefix0', 'x')
    xmap <silent> > <Plug>IndentCommentPrefix0
endif
if ! hasmapto('<Plug>IndentCommentPrefix1', 'n')
    nmap <silent> << <Plug>IndentCommentPrefix1
endif
if ! hasmapto('<Plug>IndentCommentPrefix1', 'x')
    xmap <silent> < <Plug>IndentCommentPrefix1
endif

if g:IndentCommentPrefix_alternativeOriginalCommands
    nnoremap g>> >>
    xnoremap g> >
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
