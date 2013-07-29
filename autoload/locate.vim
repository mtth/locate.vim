" locate.vim

if exists('s:loaded')
  finish
else
  let s:loaded = 1
endif

" id counter
let s:locate_index = 0
" dictionary of locate ids indexed by location list buffer id
let s:locate_ids = {}
" dictionary of match ids indexed by locate id
let s:match_ids = {}
" dictionary of list of searches index by locate id
let s:searches = {}

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

function s:generate_id()
  " return unique id used per window
   let s:locate_index += 1
   return s:locate_index
endfunction

function! s:locate(pattern, add)
  " runs lvimgrep for pattern in current window (also adds a mark at initial position)
  if !exists('w:locate_id')
    let w:locate_id = s:generate_id()
  endif
  if strlen(g:locate_initial_mark) && !a:add
    execute 'normal! m' . g:locate_initial_mark
  endif
  if s:is_wrapped(a:pattern)
    let wrapped_pattern = a:pattern
  else
    let wrapped_pattern = s:wrap(a:pattern)
  endif
  if a:add
    let cmd = 'lvimgrepadd '
  else
    let cmd = 'lvimgrep '
  endif
  echo 'Locating: ' . wrapped_pattern
  try
    execute cmd . wrapped_pattern . ' %'
  catch /^Vim\%((\a\+)\)\=:E480/
  finally
    return [w:locate_id, wrapped_pattern]
  endtry
endfunction

" Highlighting managing

function! s:create_highlight_group(base_group)
  " create highlight group Locate copied from base_group
  let base_highlight = ''
  redir => base_highlight
  silent! execute 'highlight ' . a:base_group
  redir END
  let locate_highlight = split(base_highlight, '\n')[0]
  let locate_highlight = substitute(locate_highlight, '^' . a:base_group . '\s\+xxx', '', '')
  silent execute 'highlight Locate ' . locate_highlight
endfunction

function! s:remove_highlight(locate_id)
  " remove highlight corresponding to locate id
  let preserve_cmd = s:preserve_history_command()
  let match_ids = remove(s:match_ids, a:locate_id) 
  for win_nr in range(1, winnr('$'))
    let locate_id = getwinvar(win_nr, 'locate_id')
    if locate_id ==# a:locate_id
      execute win_nr . 'wincmd w'
      for match_id in match_ids
        if match_id ># 0
          call matchdelete(match_id)
        endif
      endfor
    endif
  endfor
  execute preserve_cmd
endfunction

" Window handling

function! s:get_window_nr(locate_id)
  " goes to the window with locate id
  for win_nr in range(1, winnr('$'))
    let locate_id = getwinvar(win_nr, 'locate_id')
    if locate_id ==# a:locate_id
      return win_nr
    endif
  endfor
endfunction

function! s:preserve_history_command()
  " returns commands to go back to current window, preserving previous window as well
  return winnr('#') . 'wincmd w | ' . winnr() . 'wincmd w'
endfunction

function! s:purge(locate_id)
  " close location list associated to this id
  for [buf_nr, locate_id] in items(s:locate_ids)
    if locate_id ==# a:locate_id && bufwinnr(str2nr(buf_nr)) !=# -1
      execute 'bdelete ' . buf_nr
    endif
  endfor
endfunction

function! s:purge_hidden()
  " close location lists where the associated window is not present
  let open_locate_ids = []
  for win_nr in range(1, winnr('$'))
    let locate_id = getwinvar(win_nr, 'locate_id')
    if locate_id
      call add(open_locate_ids, locate_id)
    endif
  endfor
  for [buf_nr, locate_id] in items(s:locate_ids)
    if match(open_locate_ids, locate_id) ==# -1
      if winnr('$') ==# 1 && tabpagenr('$') ==# 1
        " only one window left and we are in only tab
        quit
      elseif bufwinnr(str2nr(buf_nr)) !=# -1
        " the location list is open in current tab
        execute 'bdelete ' . buf_nr
      endif
    endif
  endfor
endfunction

function! s:purge_tab() 
  for buf_nr in keys(s:locate_ids)
    if bufwinnr(str2nr(buf_nr)) !=# -1
      execute 'bdelete ' . buf_nr
    endif
  endfor
endfunction

function! s:open_location_list(height, patterns)
  " open location list (also does formatting and highlighting)
  let locate_id = w:locate_id
  let preserve_cmd = s:preserve_history_command()
  let s:match_ids[locate_id] = []
  let empty_patterns = []
  for pattern in a:patterns
    let [nothing, empty_pattern, flags] = split(pattern, pattern[0], 1)
    call add(s:match_ids[locate_id], matchadd(g:locate_highlight, empty_pattern))
    call add(empty_patterns, empty_pattern)
  endfor
  execute 'lopen ' . a:height
  let s:locate_ids[bufnr('%')] = locate_id
  for empty_pattern in empty_patterns
    call matchadd(g:locate_highlight, empty_pattern)
  endfor
  setlocal modifiable
  silent execute '%s/^[^|]\+|\(\d\+\) col \(\d\+\)/\1|\2/'
  setlocal nomodified
  setlocal nomodifiable
  setlocal foldcolumn=0
  silent execute 'normal! gg'
  autocmd! BufWinLeave <buffer> call <SID>remove_highlight(remove(s:locate_ids, expand('<abuf>')))
  if !g:locate_focus
    execute preserve_cmd
  endif
endfunction

" Public functions

function! locate#pattern(pattern, add)
  " main public function
  " finds matches of pattern
  " opens location list
  if !strlen(&buftype)
    execute 'lclose'
    let [locate_id, wrapped_pattern] = s:locate(a:pattern, a:add)
    let total_matches = len(getloclist(0))
    if !a:add || !has_key(s:searches, locate_id)
      let s:searches[locate_id] = [wrapped_pattern]
    else
      call add(s:searches[locate_id], wrapped_pattern)
    endif
    redraw!
    echo total_matches . ' match(es) found.'
    if total_matches
      let height = min([total_matches, g:locate_max_height])
      call s:open_location_list(height, s:searches[locate_id])
    endif
  else
    echoerr 'Invalid buffer.'
  endif
endfunction

function! locate#cword(add)
  " run locate on <cword>
  call locate#pattern(expand('<cword>'), a:add)
endfunction

function! locate#selection(add) range
  " run locate on selection
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  if lnum1 ==# lnum2
    let line = getline(lnum1)
    let line = line[: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let line = line[col1 - 1:]
    let line = substitute(line, '\n', '', 'g')
    call locate#pattern(line, a:add)
    execute 'normal `<'
  else
    echoerr 'Can only locate selection from inside a single line.'
  endif
endfunction

function! locate#purge(all)
  " close location list(s) associated with current or all buffers in tab
  if a:all
    call s:purge_tab()
  else
    if exists('w:locate_id')
      call s:purge(w:locate_id)
    endif
  endif
endfunction

function! locate#refresh(silent)
  " refresh location list(s) associated with current buffer
  if !exists('w:locate_id') || !has_key(s:searches, w:locate_id)
    if !a:silent
      echoerr 'No searches to refresh.'
    endif
  elseif !a:silent || match(values(s:locate_ids), w:locate_id) ># -1
    let view = winsaveview()
    execute 'lclose'
    let searches = s:searches[w:locate_id]
    let search_index = 0
    for search in searches
      call s:locate(search, search_index ># 0)
      let search_index += 1
    endfor
    let total_matches = len(getloclist(0))
    if total_matches
      let height = min([total_matches, g:locate_max_height])
      call s:open_location_list(height, searches)
    endif
    call winrestview(view)
    redraw!
    echo total_matches . ' match(es) found.'
  endif
endfunction

" Setup

if strlen(g:locate_highlight)
  call s:create_highlight_group(g:locate_highlight)
endif

augroup locate_private
  autocmd!
  autocmd BufEnter * nested call <SID>purge_hidden()
  if g:locate_refresh
    autocmd BufWrite * nested call locate#refresh(1)
  endif
augroup END
