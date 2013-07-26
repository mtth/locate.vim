Locate.vim
==========

Commands
--------

``:Locate[!] PATTERN``

If bang, force focus on location list.

If the pattern is enclosed in non-ID characters, the following options will be 
ignored: ``g:locate_very_magic``, ``g:locate_global``, ``g:locate_jump``.


Mappings
--------

* ``gl``:
  * normal mode: locate ``<cword>``
  * visual mode: locate selection
* ``gL``: refresh location list


Options
-------

* ``g:locate_highlight = ''``: style to highlight matches (empty to cancel) 
* ``g:locate_initial_mark = 'l'``: mark set before jumping to first match 
  (empty to disable).
* ``g:locate_max_height = 20``: maximum height of location list window
* ``g:locate_global = 1``: turn on global search by default
* ``g:locate_jump = 0``: jump to first match
* ``g:locate_very_magic = 0``: activate very magic mode by default
* ``g:locate_smart_case = 0``: activate smart case mode (only works if 
  ``ignorecase`` is set)
* ``g:locate_focus = 0``: focus location list window
