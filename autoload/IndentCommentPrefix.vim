" IndentCommentPrefix.vim: Keep comment prefix in column 1 when indenting. 
"
" DEPENDENCIES:
"   - vimscript #2136 repeat.vim autoload script (optional). 
"
" Copyright: (C) 2008-2011 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"   1.10.012	30-Mar-2011	Split off separate documentation and autoload
"				script. 
"   1.10.011	29-Mar-2011	BUG: Only report changes if more than 'report'
"				lines where indented; I got the meaning of
"				'report' wrong the first time. 
"				BUG: Could not use 999>> to indent all remaining
"				lines. Fix by explicitly passing v:count1 to
"				s:IndentKeepCommentPrefixRange() from normal
"				mode mappings and calculating the last line with
"				a cap, instead of using the implicit
"				:call-range. 
"				BUG: Normal-mode mapping didn't necessarily put
"				the cursor on the first non-blank character
"				after the comment prefix if 'nostartofline' is
"				set. 
"				ENH: In normal and visual mode, set the change
"				marks '[ and ]' similar to what Vim does. 
"   1.02.010	06-Oct-2009	Do not define mappings for select mode;
"				printable characters should start insert mode. 
"   1.01.009	03-Jul-2009	BF: When 'report' is less than the default 2,
"				the :substitute and << / >> commands created
"				additional messages, causing a hit-enter prompt. 
"				Now also reporting a single-line change when
"				'report' is 0 (to be consistent with the
"				built-in indent commands). 
"   1.00.008	23-Feb-2009	BF: Fixed "E61: Nested *" that occurred when
"				shifting a line with a comment prefix containing
"				multiple asterisks in a row (e.g. '**'). This
"				was caused by a mixed up argument escaping in
"				s:IsMatchInComments() and one missed escaping
"				elsewhere. 
"				BF: Info message (given when indenting multiple
"				lines) always printed "1 time" even when a
"				[count] was specified in visual mode. 
"   1.00.007	29-Jan-2009	BF: Test whether prefix is a comment was too
"				primitive and failed to distinguish between ':'
"				(label) and '::' (comment) in dosbatch filetype.
"				Now using exact regexp factored out into a
"				function, also for the blank-required check. 
"	006	22-Jan-2009	Added visual mode mappings. 
"				Enhanced implementation to deal with the
"				optional [count] 'shiftwidth's that can be
"				specified in visual mode. 
"	005	04-Jan-2009	BF: Fixed changes of vertical window position by
"				saving and restoring window view. 
"				ENH: The >> and << (range) commands now position
"				the cursor on the first non-blank character
"				after the comment prefix; this makes more sense. 
"				Now avoiding superfluous cursor positioning when
"				indenting ranges. (Side effect from the changes
"				due to restore of window position.) 
"	004	21-Aug-2008	BF: Didn't consider that removing the comment
"				prefix could cause changes in folding (e.g. in
"				vimscript if the line ends with "if"), which
"				then affects all indent operations, which now
"				work on the closed fold instead of the current
"				line. Now temporarily disabling folding. 
"				BF: The looping over the passed range in
"				s:IndentKeepCommentPrefixRange() didn't consider
"				closed folds, so those (except for a last-line
"				fold) would be processed multiple times. Now
"				that folding is temporarily disabling, need to
"				account for the net end of the range. 
"				Added echo message when operating on more than
"				one line, like the original >> commands. 
"	003	19-Aug-2008	BF: Indenting/detenting at the first shiftwidth
"				caused cursor to move to column 1; now adjusting
"				for the net reduction caused by the prefix. 
"	002	12-Aug-2008	Do not clobber search history with :s command. 
"				If a blank is required after the comment prefix,
"				make sure it still exists when dedenting. 
"	001	11-Aug-2008	file creation

function! s:Literal( string )
" Helper: Make a:string a literal search expression. 
    return '\V' . escape(a:string, '\') . '\m'
endfunction

function! s:IsMatchInComments( flag, prefix )
    return &l:comments =~# '\%(^\|,\)[^:]*' . a:flag . '[^:]*:' . s:Literal(a:prefix) . '\%(,\|$\)'
endfunction
function! s:IsComment( prefix )
    return s:IsMatchInComments('', a:prefix)
endfunction
function! s:IsBlankRequiredAfterPrefix( prefix )
    return s:IsMatchInComments('b', a:prefix)
endfunction

"------------------------------------------------------------------------------
function! s:DoIndent( isDedent, isInsertMode, count )
    if a:isInsertMode
	call feedkeys( repeat((a:isDedent ? "\<C-d>" : "\<C-t>"), a:count), 'n' )
    else
	" Use :silent to suppress reporting of changed line (when 'report' is
	" 0). 
	execute 'silent normal!' repeat((a:isDedent ? '<<' : '>>'), a:count)
    endif
endfunction
function! s:SubstituteHere( substituitionCmd )
    " Use :silent! to suppress any error messages or reporting of changed line
    " (when 'report' is 0). 
    " Use :keepjumps to avoid modification of jump list. 
    execute 'silent! keepjumps s' . a:substituitionCmd
    call histdel('search', -1)
endfunction
function! s:IndentCommentPrefix( isDedent, isInsertMode, count )
"*******************************************************************************
"* PURPOSE:
"   Enhanced indent / dedent replacement for >>, <<, i_CTRL-D, i_CTRL-T
"   commands. 
"* ASSUMPTIONS / PRECONDITIONS:
"   "Normal" prefix characters (i.e. they have screen width of 1 and are encoded
"   by one byte); as we're using len(l:prefix) to calculate screen width. 
"   Folding should be turned off (:setlocal nofoldenable); otherwise, the
"   modifications of the line (i.e. removing and re-adding the comment prefix)
"   may result in creation / removal of folds, and suddenly the function
"   operates on multiple lines!
"* EFFECTS / POSTCONDITIONS:
"   Modifies current line. 
"* INPUTS:
"   a:isDedent	    Flag whether indenting or dedenting. 
"   a:isInsertMode  Flag whether normal mode or insert mode replacement. 
"   a:count	    Number of 'shiftwidth' that should be indented (i.e. number
"		    of repetitions of the indent command). 
"* RETURN VALUES: 
"   New virtual cursor column, taking into account a single (a:count == 1)
"   indent operation. 
"   Multiple repetitions are not supported here, because the virtual cursor
"   column is only consumed by the insert mode operation, which is always a
"   single indent. The (possibly multi-indent) visual mode operation discards
"   this return value, anyway. 
"*******************************************************************************
    let l:line = line('.')
    let l:matches = matchlist( getline(l:line), '\(^\S\+\)\(\s*\)' )
    let l:prefix = get(l:matches, 1, '')
    let l:indent = get(l:matches, 2, '')
    let l:isSpaceIndent = (l:indent =~# '^ ')

    if empty(l:prefix) || ! s:IsComment(l:prefix)
	" No prefix in this line or the prefix is not registered as a comment. 
	call s:DoIndent( a:isDedent, a:isInsertMode, a:count )
	" The built-in indent commands automatically adjust the cursor column. 
	return virtcol('.')
    endif



"****D echomsg l:isSpaceIndent ? 'spaces' : 'tab'
    let l:virtCol = virtcol('.')

    " If the actual indent is a <Tab>, remove the prefix. If it is <Space>,
    " replace prefix with spaces so that the overall indentation remains fixed. 
    " Note: We have to decide based on the actual indent, because with the
    " softtabstop setting, there may be spaces though the overall indenting is
    " done with <Tab>. 
    call s:SubstituteHere('/^\C\V' . escape(l:prefix, '/\') . '/' . (l:isSpaceIndent ? repeat(' ', len(l:prefix)) : '') . '/')

    call s:DoIndent( a:isDedent, 0, a:count )

    " If the first indent is a <Tab>, re-insert the prefix. If it is <Space>,
    " replace spaces with prefix so that the overall indentation remains fixed. 
    " Note: We have to re-evaluate because the softtabstop setting may have
    " changed <Tab> into spaces and vice versa. 
    let l:newIndent = matchstr( getline(l:line), '^\s' )
    " Dedenting may have eaten up all indent spaces. In that case, just
    " re-insert the comment prefix as is done with <Tab> indenting. 
    call s:SubstituteHere('/^' . (l:newIndent == ' ' ? '\%( \{' . len(l:prefix) . '}\)\?' : '') . '/' . escape(l:prefix, '/\&~') . '/')

    " If a blank is required after the comment prefix, make sure it still exists
    " when dedenting. 
    if s:IsBlankRequiredAfterPrefix(l:prefix) && a:isDedent
	call s:SubstituteHere('/^' . escape(l:prefix, '/\') . '\ze\S/\0 /e')
    endif
    

    " Adjust cursor column based on the _virtual_ column. (Important since we're
    " dealing with <Tab> characters here!) 
    " Note: This calculation ignores a:count, see note in function
    " documentation. 
    let l:newVirtCol = l:virtCol
    if ! a:isDedent && l:isSpaceIndent && len(l:prefix . l:indent) < &l:sw
	" If the former indent was less than one shiftwidth and indenting was
	" done via spaces, this reduces the net change of cursor position. 
	let l:newVirtCol -= len(l:prefix . l:indent)
    elseif a:isDedent && l:isSpaceIndent && len(l:prefix . l:indent) <= &l:sw
	" Also, on the last possible dedent, the prefix (and one <Space> if blank
	" required) will reduce the net change of cursor position. 
	let l:newVirtCol += len(l:prefix) + (s:IsBlankRequiredAfterPrefix(l:prefix) ? 1 : 0)
    endif
    " Calculate new cursor position based on indent/dedent of shiftwidth,
    " considering the adjustments made before. 
    let l:newVirtCol += (a:isDedent ? -1 : 1) * &l:sw

"****D echomsg '****' l:virtCol l:newVirtCol len(l:prefix . l:indent)
    return l:newVirtCol

    " Note: The cursor column isn't updated here anymore, because the window
    " view had to be saved and restored by the caller of this function, anyway. 
    " (Due to the temporary disabling of folding.) As the window position
    " restore also restores the old cursor position, the setting here would be
    " overwritten, anyway.
    " Plus, the IndentCommentPrefix#Range() functionality sets the cursor
    " position in a different way, anyway, and only for the first line in the
    " range, so the cursor movement here would be superfluous, too. 
    "call cursor(l:line, 1)
    "if l:newVirtCol > 1
    "	call search('\%>' . (l:newVirtCol - 1) . 'v', 'c', l:line)
    "endif
endfunction

function! IndentCommentPrefix#InsertMode( isDedent )
    " The temporary disabling of folding below may result in a change of the
    " viewed lines, which would be irritating for a command that only modified
    " the current line. Thus, save and restore the view, but afterwards take
    " into account that the indenting changes the cursor column. 
    let l:save_view = winsaveview()

    " Temporarily turn off folding while indenting the line. 
    let l:save_foldenable = &l:foldenable
    setlocal nofoldenable

    let l:newVirtCol = s:IndentCommentPrefix(a:isDedent, 1, 1)

    let &l:foldenable = l:save_foldenable
    call winrestview(l:save_view)

    " Set new cursor position after indenting; the saved view has reset the
    " position to before indent. 
    call cursor('.', 1)
    if l:newVirtCol > 1
	call search('\%>' . (l:newVirtCol - 1) . 'v', 'c', line('.'))
    endif
endfunction

function! IndentCommentPrefix#Range( isDedent, count, lineNum ) range
    " The temporary disabling of folding below may result in a change of the
    " viewed lines, which would be irritating for a command that only modified
    " the current line. Thus, save and restore the view. 
    let l:save_view = winsaveview()

    " From a normal mode mapping, the count in a:lineNum may address more lines
    " than actually existing (e.g. when using 999>> to indent all remaining
    " lines); the calculated last line needs to be capped to avoid errors. 
    let l:lastLine = (a:lastline == a:firstline ? min([a:firstline + a:lineNum - 1, line('$')]) : a:lastline)

    " Determine the net last line (different if last line is folded). 
    let l:netLastLine = (foldclosedend(l:lastLine) == -1 ? l:lastLine : foldclosedend(l:lastLine))

    " Temporarily turn off folding while indenting the lines. 
    let l:save_foldenable = &l:foldenable
    setlocal nofoldenable

    for l in range(a:firstline, l:netLastLine)
	execute l . 'call s:IndentCommentPrefix(' . a:isDedent . ', 0'. ', ' . a:count . ')'
    endfor

    let &l:foldenable = l:save_foldenable
    call winrestview(l:save_view)

    " Go back to first line, like the default >> indent commands. 
    execute 'normal!' a:firstline . 'G^'
    let l:startChangePosition = getpos('.')

    " Go back to first line, ...
    " But put the cursor on the first non-blank character after the comment
    " prefix, not on first overall non-blank character, as the default >> indent
    " commands would do. This makes more sense, since we're essentially ignoring
    " the comment prefix during indenting. 
    let l:matches = matchlist( getline(a:firstline), '\(^\S\+\)\s*' )
    let l:prefix = get(l:matches, 1, '')
    if ! empty(l:prefix) && &l:comments =~# s:Literal(l:prefix)
	" Yes, the first line was a special comment prefix indent, not a normal
	" one. 
	call search('^\S\+\s*\%(\S\|$\)', 'ce', a:firstline)
    endif

    " Integration into repeat.vim. 
    let l:netIndentedLines = l:netLastLine - a:firstline + 1
    " Passing the net number of indented lines is necessary to correctly repeat
    " (in normal mode) indenting of a visual selection. Otherwise, only the
    " current line would be indented because v:count was 1 during the visual
    " indent operation. 
    silent! call repeat#set("\<Plug>IndentCommentPrefix" . a:isDedent, l:netIndentedLines)

    " Set the change marks similar to what Vim does. (I don't grasp the logic
    " for '[, but using the first non-blank character seems reasonable to me.) 
    " This must somehow be done after the call to repeat.vim. 
    call setpos("'[", l:startChangePosition)
    call setpos("']", [0, l:netLastLine, strlen(getline(l:netLastLine)), 0])

    let l:lineNum = l:netLastLine - a:firstline + 1
    if l:lineNum > &report
	echo printf('%d line%s %sed %d time%s', l:lineNum, (l:lineNum == 1 ? '' : 's'), (a:isDedent ? '<' : '>'), a:count, (a:count == 1 ? '' : 's'))
    endif
endfunction

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
