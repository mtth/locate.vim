" locate.vim

if (exists('g:locate_disable') && g:locate_disable) || &compatible
  finish
endif

if !exists('g:locate_highlight')
  let g:locate_highlight = 'Search'
endif
if !exists('g:locate_initial_mark')
  let g:locate_initial_mark = 'l'
endif
if !exists('g:locate_max_height')
  let g:locate_max_height = 20
endif
if !exists('g:locate_focus')
  let g:locate_focus = 0
endif
if !exists('g:locate_very_magic')
  let g:locate_very_magic = 1
endif
if !exists('g:locate_global')
  let g:locate_global = 1
endif
if !exists('g:locate_jump')
  let g:locate_jump = 1
endif
if !exists('g:locate_smart_case')
  let g:locate_smart_case = 1
endif

command! -bang -nargs=* Locate call locate#pattern(<q-args>, <bang>0)
command! -bang -nargs=* L call locate#pattern(<q-args>, <bang>0)
command! -bang Lpurge call locate#purge(<bang>0)

nnoremap <silent> gl :call locate#cword()<cr>
vnoremap <silent> gl :call locate#selection()<cr>
nnoremap <silent> gL :call locate#refresh()<cr>
