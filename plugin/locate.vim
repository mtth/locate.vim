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
if !exists('g:locate_global')
  let g:locate_global = 1
endif
if !exists('g:locate_jump_to')
  let g:locate_jump_to = 'first'
endif
if !exists('g:locate_very_magic')
  let g:locate_very_magic = 1
endif
if !exists('g:locate_smartcase')
  let g:locate_smartcase = 1
endif
if !exists('g:locate_refresh')
  let g:locate_refresh = 1
endif
if !exists('g:locate_sort')
  let g:locate_sort = 1
endif

command! -bang -nargs=* Locate call locate#pattern(<q-args>, <bang>0)
command! -bang -nargs=* L call locate#pattern(<q-args>, <bang>0)
command! -bang Lpurge call locate#purge(<bang>0)
command! -bang Lrefresh call locate#refresh(<bang>0)

nnoremap <silent> gl :call locate#cword(0)<cr>
vnoremap <silent> gl :call locate#selection(0)<cr>
nnoremap <silent> gL :call locate#cword(1)<cr>
vnoremap <silent> gL :call locate#selection(1)<cr>
