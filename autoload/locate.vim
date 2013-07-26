" locate.vim

" dictionary of previous searches (used when an empty pattern is provided)
let s:searches = {}

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

function! s:get_full_pattern(pattern)
  " if pattern starts with non-ID character, return it
  " otherwise append user settings
  let char = a:pattern[0]
  if !s:is_identifier(char)
    return a:pattern
  else
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
    if match(prefixes, '[cC]') <# 0 && g:locate_smart_case
      if &ignorecase && match(a:pattern, '[A-Z]') >=# 0
        let prefix .= '\C'
      endif
    endif
    if match(prefixes, '[vVmM]') <# 0 && g:locate_very_magic
      let prefix .= '\v'
    endif
    return wrapper . prefix . a:pattern . wrapper . flags
  endif
endfunction

function! s:go_to_window(close)
  " goes to the first of the following windows (otherwise error out)
  " * the current window if its buftype is empty
  " * if the current window is a location list, the window associated with it
  " * if the current window isn't a location list, the previous window if its
  "   buftype is empty
  " if successful, closes any open location list in the target window
  if strlen(&buftype)
    if exists('b:locate_window_number')
      " we are in a location list
      execute b:locate_window_number . 'wincmd w'
    else
      execute 'wincmd p'
      if strlen(&buftype)
        " previous window is special too, go back and error out
        execute 'wincmd p'
        throw 'Unable to locate from strange windows!'
      endif
    endif
  endif
  if a:close
    execute 'lclose'
  endif
endfunction

function! s:highlight_pattern(pattern)
  " highlight pattern in location list and current window
  " must be called from a location list
  if exists('b:locate_window_number')
    call matchadd(g:locate_highlight, '\c' . a:pattern)
  else
    throw 'Unable to highlight from non locate window'
  endif
endfunction

function! s:open_location_list(full_pattern)
  let [nothing, empty_pattern, flags] = split(a:full_pattern, a:full_pattern[0], 1)
  if match(flags, 'j') <=# 0
    execute 'normal zz'
  endif
  execute 'lopen'
  let b:locate_window_number = winnr('#')
  if strlen(g:locate_highlight)
    call s:highlight_pattern(empty_pattern)
  endif
endfunction

function! s:on_close_location_list()
  " TODO: clear location list
endfunction

function! locate#locate_pattern(pattern, ...)
  " load matches to location list and open it
  call s:go_to_window(1)
  if strlen(g:locate_initial_mark)
    execute 'normal! m' . g:locate_initial_mark
  endif
  if strlen(a:pattern)
    let full_pattern = s:get_full_pattern(a:pattern)
    let s:searches[winnr()] = full_pattern
  elseif has_key(s:searches, winnr() . '')
    let full_pattern = s:searches[winnr() . '']
  else
    echoerr 'No previous pattern found.'
    return
  endif
  try
    execute 'lvimgrep ' . full_pattern . ' %'
    call s:open_location_list(full_pattern)
  catch /^Vim\%((\a\+)\)\=:E480/
    echo 'No matches found.'
  finally
    if !g:locate_focus && !(a:0 > 0 && a:1)
      call s:go_to_window(0)
    endif
  endtry
endfunction

function! locate#locate_cword()
  " wrapper for mappings
  if strlen(&buftype)
    echoerr 'Cannot locate from special buffers.'
  else
    call locate#locate_pattern(expand('<cword>'))
  endif
endfunction

function! locate#locate_selection()
  " wrapper for mappings
  if strlen(&buftype)
    echoerr 'Cannot locate from special buffers.'
  else
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]
    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]
    let pattern = join(lines, "\n")
    call locate#locate_pattern(pattern)
  endif
endfunction
