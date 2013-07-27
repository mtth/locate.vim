" locate.vim

" dictionary of previous searches, indexed by buffer number (used when an
" empty pattern is provided)
let s:searches = {}
" dictionary of match ids, indexed by location list buffer number
let s:match_ids = {}
" dictionary of buffer numbers, indexed by location list buffer number
let s:buffer_nrs = {}

" Pattern operations

function! s:is_identifier(char)
  " returns 1 if character is in 'isident' and not backslash
  let identifiers = split(&isident, ',')
  let nums = [92] + range(65, 90) + range(97,122)
  let chars = []
  for part in identifiers
    if match(part[0], '\d') >=# 0
      let [small, large] = split(part, '-')
      let nums += range(small, large)
    else
      call add(chars, part)
    endif
  endfor
  for elem in nums
    if char2nr(a:char) ==# elem
      return 1
    endif
  endfor
  return match(chars, a:char) >=# 0
endfunction

function! s:get_unused_non_identifier(pattern)
  " returns a non-ID character that is not in pattern
  for elem in range(35, 126)
    let char = nr2char(elem)
    if !s:is_identifier(char) && match(a:pattern, char) <# 0
      return char
    endif
  endfor
  throw 'All the non-ID characters are used!'
endfunction

function! s:get_prefixes(pattern)
  " returns a list of prefix characters from pattern (e.g. c, V)
  let prefixes = []
  let pattern = a:pattern
  while pattern[0] ==# '\'
    call add(prefixes, pattern[1])
    let pattern = pattern[2:]
  endwhile
  return prefixes
endfunction

function! s:is_wrapped(pattern)
  " check if pattern is validly wrapped
  let char = a:pattern[0]
  if !s:is_identifier(char)
    let parts = split(a:pattern, char, 1)
    return len(parts) ==# 3 && match(parts[2], '[^gj]') <# 0
  endif
  return 0
endfunction

function! s:wrap(pattern)
  " wrap pattern and add user setting
  let wrapper = s:get_unused_non_identifier(a:pattern)
  let flags = ''
  if g:locate_global
    let flags .= 'g'
  endif
  if !g:locate_jump
    let flags .= 'j'
  endif
  let prefix = ''
  let prefixes = s:get_prefixes(a:pattern)
  if match(prefixes, '[cC]') <# 0 && &ignorecase
    if g:locate_smart_case && match(a:pattern, '\C[A-Z]') >=# 0
      let prefix .= '\C'
    else
      let prefix .= '\c'
    endif
  endif
  if match(prefixes, '[vVmM]') <# 0 && g:locate_very_magic
    let prefix .= '\v'
  endif
  return wrapper . prefix . a:pattern . wrapper . flags
endfunction

" Searching

function! s:locate(pattern)
  " runs lvimgrep for pattern in current window (also adds a mark at initial position)
  " returns wrapped pattern (empty string if no pattern found for window)
  if strlen(g:locate_initial_mark)
    execute 'normal! m' . g:locate_initial_mark
  endif
  if strlen(a:pattern)
    if s:is_wrapped(a:pattern)
      let wrapped_pattern = a:pattern
    else
      let wrapped_pattern = s:wrap(a:pattern)
    endif
    echo 'Locating: ' . wrapped_pattern
    let s:searches[bufnr('%')] = wrapped_pattern
  elseif has_key(s:searches, bufnr('%') . '')
    let wrapped_pattern = s:searches[bufnr('%') . '']
  else
    return ''
  endif
  try
    execute 'lvimgrep ' . wrapped_pattern . ' %'
  catch /^Vim\%((\a\+)\)\=:E480/
  finally
    return wrapped_pattern
  endtry
endfunction

" Window handling

function! s:close_location_lists(buf_nr)
  " close hidden location lists and list associated with buffer number buf_nr
  " if buf_nr = -1, close all location lists
  for [loc_nr, buf_nr] in items(s:buffer_nrs)
    if bufwinnr(buf_nr) ==# -1 || a:buf_nr ==# -1 || a:buf_nr ==# buf_nr
      execute 'bdelete ' . loc_nr
    endif
  endfor
endfunction

function! s:go_to_window()
  " goes to the first of the following windows
  " * the current window if its buftype is empty
  " * if the current window is a location list, the window associated with it
  " returns 0 if success, 1 if error
  if strlen(&buftype)
    let cur_bufnr = bufnr('%')
    if has_key(s:buffer_nrs, cur_bufnr)
      " we are in a location list
      execute bufwinnr(s:buffer_nrs[cur_bufnr]) . 'wincmd w'
    else
      return 1
    endif
  endif
  call s:close_location_lists(bufnr('%'))
  return 0
endfunction

function! s:preserve_history_command()
  " returns commands to go back to current window, preserving previous window as well
  return winnr('#') . 'wincmd w | ' . winnr() . 'wincmd w'
endfunction

function! s:open_location_list(wrapped_pattern, height, focus)
  " open location list (also does formatting and highlighting)
  let [nothing, empty_pattern, flags] = split(a:wrapped_pattern, a:wrapped_pattern[0], 1)
  let cur_bufnr = bufnr('%')
  let preserve_cmd = s:preserve_history_command()
  let match_id = matchadd(g:locate_highlight, empty_pattern)
  execute 'lopen ' . a:height
  let loclist_bufnr = bufnr('%')
  let s:buffer_nrs[loclist_bufnr] = cur_bufnr
  let s:match_ids[loclist_bufnr] = match_id
  call matchadd(g:locate_highlight, empty_pattern)
  setlocal modifiable
  silent execute '%s/^[^|]\+|\(\d\+\) col \(\d\+\)/\1|\2/'
  setlocal nomodified
  setlocal nomodifiable
  setlocal foldcolumn=0
  silent execute 'normal! gg'
  autocmd! BufWinLeave <buffer> call <SID>on_close_location_list()
  if !a:focus
    execute preserve_cmd
  endif
endfunction

function! s:on_close_location_list()
  " clear location list and remove highlighting from associated window
  let closed_bufnr = expand('<abuf>') . ''
  if has_key(s:match_ids, closed_bufnr) && has_key(s:buffer_nrs, closed_bufnr)
    let match_id = remove(s:match_ids, closed_bufnr)
    let buffer_nr = remove(s:buffer_nrs, closed_bufnr)
    let window_nr = bufwinnr(buffer_nr)
    if winbufnr(window_nr) >=# 0
      " if the window is still there, remove highlighting
      let preserve_cmd = s:preserve_history_command()
      execute window_nr . 'wincmd w'
      call matchdelete(match_id)
      execute preserve_cmd
    endif
  else
    throw 'Something has gone wrong!'
  endif
endfunction

" Public functions

augroup locate
  autocmd!
  autocmd BufEnter * nested call <SID>close_location_lists(0)
augroup END

function! locate#pattern(pattern, switch_focus)
  " main public function
  " finds matches of pattern
  " opens location list
  let status = s:go_to_window()
  if !s:go_to_window()
    let wrapped_pattern = s:locate(a:pattern)
    redraw!
    if strlen(wrapped_pattern)
      let total_matches = len(getloclist(0))
      echo total_matches . ' match(es) found.'
      if total_matches
        let height = min([total_matches, g:locate_max_height])
        let focus = a:switch_focus ? !g:locate_focus : g:locate_focus
        call s:open_location_list(wrapped_pattern, height, focus)
      endif
    else
      echoerr 'No previous pattern found.'
    endif
  else
    echoerr 'Invalid buffer.'
  endif
endfunction

function! locate#cword()
  " run locate on <cword>
  call locate#pattern(expand('<cword>'), 0)
endfunction

function! locate#selection() range
  " run locate on selection
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  if lnum1 ==# lnum2
    let line = getline(lnum1)
    let line = line[: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let line = line[col1 - 1:]
    let line = substitute(line, '\n', '', 'g')
    call locate#pattern(line, 0)
    execute 'normal `<'
  else
    echoerr 'Can only locate selection from inside a single line.'
  endif
endfunction

function! locate#refresh()
  " refresh last locate search
  call locate#pattern('', 0)
endfunction

function! locate#purge(all)
  " close location lists associated with current or all buffers
  if a:all
    call s:close_location_lists(-1)
  else
    call s:close_location_lists(bufnr('%'))
  endif
endfunction
