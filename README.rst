.. default-role:: code


Locate.vim
==========

`/` and `?` are search *motions*: simple and powerful. But when searching for a 
common pattern, especially in a large file, it can be hard to get to the one 
match we are looking for (tired of hitting `n`?). They also don't provide an 
overview of where matches are: the only way to figure it out is to move our 
cursor.

Vim comes with a family of commands for this use-case (see `:help vimgrep`), 
but they require a lot of manual work (opening the list of results, no 
highlighting, etc.). `:Locate`, or `:L` for short, handles all this and more!

.. image:: doc/locate.png
   :align: center


Features
--------

* Window specific highlighting!
* Automatic sizing, sorting and updating of results
* `gl` mapping to search for current selection / word under cursor
* Customizable `smartcase` and `very magic` modes

`:help Locate` for the full list of options.


Installation
------------

With `pathogen.vim`_:

.. code:: bash

  $ cd ~/.vim/bundle
  $ git clone https://github.com/mtth/locate.vim

Otherwise simply copy the folders into your `.vim` directory.


.. _`pathogen.vim`: https://github.com/tpope/vim-pathogen
