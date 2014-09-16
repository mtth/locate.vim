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
let s:patterns = {}

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

function! s:wrap(pattern, global)
  " wrap single pattern and add lvimgrep user setting
  let wrapper = s:get_unused_non_identifier(a:pattern)
  let vimgrep_flags = 'j'
  if a:global
    let vimgrep_flags .= 'g'
  endif
  return  wrapper . a:pattern . wrapper . vimgrep_flags
endfunction

" Searching

function s:generate_id()
  " return unique id used per window
   let s:locate_index += 1
   return s:locate_index
endfunction

function! s:location_list_sorter(first, second)
  " sort location list by line and column number
  if a:first.lnum ># a:second.lnum
    return 1
  elseif a:first.lnum <# a:second.lnum
    return -1
  else
    if a:first.col ># a:second.col
      return 1
    elseif a:first.col <# a:second.col
      return -1
    else
      return 0
    endif
  endif
endfunction

function! s:locate(pattern, global, add)
  " runs lvimgrep for single pattern in current window
  if !exists('w:locate_id')
    let w:locate_id = s:generate_id()
  endif
  let w:locate_bufnr = bufnr('%')
  if !strlen(a:pattern)
    let wrapped_pattern = s:wrap(getreg('/'), a:global)
  else
    let wrapped_pattern = s:wrap(a:pattern, a:global)
  endif
  if a:add
    let cmd = 'lvimgrepadd '
  else
    let cmd = 'lvimgrep '
  endif
  try
    execute cmd . wrapped_pattern . ' %'
  catch /^Vim\%((\a\+)\)\=:E480/
  finally
    return w:locate_id
  endtry
endfunction

function! s:locate_multiple(patterns, global, add)
  " locate several patterns and sort location list if necessary
  let locate_id = s:locate(a:patterns[0], a:global, a:add)
  for pattern in a:patterns[1:]
    call s:locate(pattern, a:global, 1)
  endfor
  let loclist = getloclist(0)
  if len(loclist) && g:locate_sort
    call setloclist(0, sort(loclist, 's:location_list_sorter'))
  endif
  return locate_id
endfunction

" Jumps

function! s:get_next(cursor)
  " get line number of next location list match after cursor position
  let elem_index = 1
  for elem in getloclist(0)
    if elem['lnum'] <# a:cursor[1]
      let elem_index += 1
    elseif elem['lnum'] ==# a:cursor[1] && elem['col'] <=# a:cursor[2]
      let elem_index += 1
    else
      return elem_index
    endif
  endfor
  return 1
endfunction

function! s:get_closest(cursor)
  " get line number of next location list match after cursor position
  let elem_index = 0
  let min_line_distance = 1 / 0
  for elem in getloclist(0)
    let elem_line_distance = abs(elem['lnum'] - a:cursor[1])
    let elem_col_distance = abs(elem['col'] - a:cursor[2])
    if elem_line_distance <# min_line_distance
      let min_line_distance = elem_line_distance
      let min_col_distance = elem_col_distance
    elseif elem_line_distance ==# min_line_distance
      if elem_col_distance <# min_col_distance
        let min_col_distance = elem_col_distance
      elseif elem_line_distance ==# 0
        return elem_index
      endif
    else
      return elem_index
    endif
    let elem_index += 1
  endfor
  return elem_index
endfunction

function! s:jump(cursor, position)
  " jump to match depending on g:locate_jump_to
  if a:position ==# 'f'
    execute '1ll'
  elseif a:position ==# 'n'
    execute s:get_next(a:cursor) . 'll'
  elseif a:position ==# 'c'
    execute s:get_closest(a:cursor) . 'll'
  elseif a:position !=# 's'
    echoerr 'Invalid g:locate_jump_to option: ' . g:locate_jump_to
  endif
endfunction

" Highlighting

function! s:highlight_exists()
  " check if Locate highlighting exists
  try
    silent execute 'highlight Locate'
  catch /^Vim\%((\a\+)\)\=:E411/
    return 0
  endtry
  return 1
endfunction

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
  " get the window number associated with locate id
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
  " also close location lists where associated buffer has changed
  let open_locate_ids = []
  for win_nr in range(1, winnr('$'))
    let locate_id = getwinvar(win_nr, 'locate_id')
    if locate_id && winbufnr(win_nr) ==# getwinvar(win_nr, 'locate_bufnr')
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

function! s:open_location_list(height, patterns, position, silent)
  " open location list (also does formatting and highlighting)
  let locate_id = w:locate_id
  let preserve_cmd = s:preserve_history_command()
  let cursor = getpos('.')
  let s:match_ids[locate_id] = []
  if s:highlight_exists()
    for pattern in a:patterns
      call add(s:match_ids[locate_id], matchadd('Locate', pattern))
    endfor
  endif
  execute 'lopen ' . a:height
  let list_bufnr = bufnr('%')
  let list_winnr = winnr()
  let s:locate_ids[list_bufnr] = locate_id
  if s:highlight_exists()
    for pattern in a:patterns
      call matchadd('Locate', pattern)
    endfor
  endif
  setlocal modifiable
  silent execute '%s/^[^|]\+|\(\d\+\) col \(\d\+\)/%|\1,\2/'
  setlocal nomodified
  setlocal nomodifiable
  silent execute 'normal! gg'
  autocmd! BufWinLeave <buffer> call <SID>remove_highlight(remove(s:locate_ids, expand('<abuf>')))
  call s:jump(cursor, a:position)
  if g:locate_focus && !a:silent
    execute list_winnr . 'wincmd w'
  else
    execute preserve_cmd
  endif
endfunction

" Input parsing

function! s:get_option(flags, values, default)
  " return last specified flag among values
  for flag in reverse(split(a:flags, '.\zs'))
    if match(a:values, '\C' . flag) >=# 0
      return flag
    endif
  endfor
  return a:default
endfunction

function! s:get_case_mode(pattern)
  " returns any pattern specified case mode
  " note that any case insensitive flag will override others
  if match(a:pattern, '\C\\c') >=# 0
    return 'c'
  elseif match(a:pattern, '\C\\C') >=# 0
    return 'C'
  else
    return ''
  endif
endfunction

function! s:get_magic_mode(pattern)
  " return any pattern specified initial magic mode
  " any magic mode toggles within the pattern are not detected
  let matches = matchlist(a:pattern, '\C^\\\([mMvV]\)')
  if len(matches)
    return matches[1]
  else
    return ''
  endif
endfunction

function! s:parse(input)
  " parse user input and return patterns and flags
  let char = a:input[0]
  let flags = ''
  if !s:is_identifier(char)
    let parts = split(a:input, char, 1)
    if match(parts[-1], '\C^[glfncs]*$') <# 0
      " doesn't seem like flags at the end, consider pattern as raw
      let raw_patterns = [a:input]
    else
      let raw_patterns = parts[1:-2]
      let flags .= parts[-1]
    endif
  else
    let raw_patterns = [a:input]
  endif
  let patterns = []
  for pattern in raw_patterns
    let prefix = ''
    if !strlen(s:get_case_mode(pattern)) && &ignorecase
      if g:locate_smartcase && match(pattern, '\C[A-Z]') >=# 0
        let prefix .= '\C'
      else
        let prefix .= '\c'
      endif
    endif
    if !strlen(s:get_magic_mode(pattern)) && g:locate_very_magic
      let prefix .= '\v'
    endif
    call add(patterns, prefix . pattern)
  endfor
  return {'patterns': patterns,
         \'global': s:get_option(flags, 'gl', g:locate_global ? 'g' : 'l'),
         \'position': s:get_option(flags, 'fncs', g:locate_jump_to[0])}
endfunction

" Public functions

function! locate#input(input, add)
  " main public function
  " jump to window if in locate list for that window
  " finds matches of pattern
  " opens location list
  " jumps to match as determined by g:locate_jump_to
  if has_key(s:locate_ids, bufnr('%'))
    execute 'll'
  endif
  if !strlen(&buftype)
    if strlen(g:locate_initial_mark)
      execute 'normal! m' . g:locate_initial_mark
    endif
    execute 'lclose'
    let inputs = s:parse(a:input)
    let locate_id = s:locate_multiple(inputs.patterns, inputs.global ==# 'g', a:add)
    if !a:add || !has_key(s:patterns, locate_id)
      let s:patterns[locate_id] = inputs.patterns
    else
      call extend(s:patterns[locate_id], inputs.patterns)
    endif
    redraw!
    let total_matches = len(getloclist(0))
    echo total_matches . ' match(es) found.'
    if total_matches
      let height = min([total_matches, g:locate_max_height])
      call s:open_location_list(height, s:patterns[locate_id], inputs.position, 0)
    endif
  else
    echoerr 'Invalid buffer.'
  endif
endfunction

function! locate#cword(add)
  " run locate on <cword>
  call locate#input(expand('<cword>'), a:add)
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
    call locate#input(line, a:add)
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

function! locate#refresh(flags, silent)
  " refresh location list associated with current buffer
  " if silent is true, only does so if the location list is open and keeps the
  " cursor in place always
  " if silent is false, repeats last search and jumps to match (determined by
  " g:locate_jump_to) or raises an error if there is no search to refresh
  if !exists('w:locate_id') || !has_key(s:patterns, w:locate_id)
    if !a:silent
      echoerr 'No searches to refresh.'
    endif
  elseif !a:silent || match(values(s:locate_ids), w:locate_id) ># -1
    let view = winsaveview()
    execute 'lclose'
    let patterns = s:patterns[w:locate_id]
    let global = s:get_option(a:flags, 'gl', g:locate_global ? 'g' : 'l')
    call s:locate_multiple(patterns, global ==# 'g', 0)
    let total_matches = len(getloclist(0))
    if total_matches
      let height = min([total_matches, g:locate_max_height])
      let position = s:get_option(a:flags, 'fncs', g:locate_jump_to[0])
      call s:open_location_list(height, patterns, position, a:silent)
    endif
    if a:silent
      call winrestview(view)
    else
      echo total_matches . ' match(es) found.'
    endif
  endif
endfunction

" Setup

if strlen(g:locate_highlight) && !s:highlight_exists()
  call s:create_highlight_group(g:locate_highlight)
endif

augroup locate_private
  autocmd!
  autocmd BufEnter * nested silent call <SID>purge_hidden()
  if g:locate_refresh
    autocmd BufWritePost * nested silent call locate#refresh('', 1)
  endif
augroup END
