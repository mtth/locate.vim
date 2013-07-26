" locate.vim

if !exists('g:locate_highlight')
  let g:locate_highlight = 'Search'
endif
if !exists('g:locate_initial_mark')
  let g:locate_initial_mark = 'l'
endif
if !exists('g:locate_max_height')
  let g:locate_max_height = 20
endif
if !exists('g:locate_very_magic')
  let g:locate_very_magic = 0
endif
if !exists('g:locate_global')
  let g:locate_global = 1
endif
if !exists('g:locate_jump')
  let g:locate_jump = 0
endif
if !exists('g:locate_smart_case')
  let g:locate_smart_case = 0
endif
if !exists('g:locate_focus')
  let g:locate_focus = 0
endif

command! -bang -nargs=* Locate call locate#locate_pattern(<q-args>, <bang>0)

nnoremap gl :call locate#locate_cword()<cr>
vnoremap gl :call locate#locate_selection()<cr>
nnoremap gL :call locate#locate_pattern('')<cr>
