" locate.vim

if (exists('g:locate_disable') && g:locate_disable) || &compatible
  finish
endif

if !exists('g:locate_highlight')
  let g:locate_highlight = 'IncSearch'
endif
if !exists('g:locate_initial_mark')
  let g:locate_initial_mark = ''
endif
if !exists('g:locate_max_height')
  let g:locate_max_height = 20
endif
if !exists('g:locate_focus')
  let g:locate_focus = 1
endif
if !exists('g:locate_global')
  let g:locate_global = 0
endif
if !exists('g:locate_jump_to')
  let g:locate_jump_to = 'next'
endif
if !exists('g:locate_very_magic')
  let g:locate_very_magic = 0
endif
if !exists('g:locate_smartcase')
  let g:locate_smartcase = 0
endif
if !exists('g:locate_refresh')
  let g:locate_refresh = 1
endif
if !exists('g:locate_sort')
  let g:locate_sort = 1
endif
if !exists('g:locate_mappings')
  let g:locate_mappings = 1
endif

command! -bang -nargs=* Locate call locate#input(<q-args>, <bang>0)
command! -bang -nargs=* L call locate#input(<q-args>, <bang>0)
command! -bang Lpurge call locate#purge(<bang>0)
command! -bang -nargs=? Lrefresh call locate#refresh(<q-args>, <bang>0)

if g:locate_mappings
  nnoremap <silent> gl :call locate#cword(0)<cr>
  xnoremap <silent> gl :call locate#selection(0)<cr>
  nnoremap <silent> gL :call locate#cword(1)<cr>
  xnoremap <silent> gL :call locate#selection(1)<cr>
endif
