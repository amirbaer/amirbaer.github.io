" vim 700: set foldmethod=marker:
"
" LastChanged:  20/01/08
" Version:      1.1
" Credits:      Misha Seltzer.

" Section: Basic Settings {{{1

" Section: General Settings {{{2
set nocompatible " Vim, not vi.
set backspace=indent,eol,start " (x) set backspace=2
set autowrite " write modified file on various occasions
set autoindent " always set autoindenting on
set shell=bash " shell to use
filetype plugin indent on
" When editing a file, always jump to the last cursor position
autocmd BufReadPost * if line("'\"") > 0 && line ("'\"") <= line("$") | exe "normal! g'\"" | endif



" Section: Visual Settings {{{2
set cpoptions+=$ " show a $ at the end of changing text
set laststatus=2 " always show status line
set showmatch " show the matching bracket
set tabstop=4 " size of tab
set smarttab " 4 spaces work just like tab
set expandtab " don't write tabs but 4 spaces
set bg=dark " I like dark backgrounds
set wildmode=longest,list " when doing <TAB> show the list of options
set shortmess=aI " abbreviate all messages, and skip intro message
syntax on
set hidden
set ruler       " show the cursor position all the time
set showcmd " Show partial command in the status line
set textwidth=100 " (x) set textwidth=0
autocmd FileType java setlocal textwidth=100 " (x)
autocmd BufRead,BufNewFile *.swig setlocal syntax=cpp " (x)

" Section: Search Settings {{{3
set nohlsearch " do not highlight searches
set incsearch       " do incremental searching (x)
nnoremap <F1> :set hls!<CR>

" Section: Format Settings {{{2
set formatoptions=cql " formatoptions: Options for the "text format" command ("gq")
set shiftwidth=4 " how many spaces to (auto) indent

" Section: Manipulations {{{2
map <F4> :split<CR> " Split the screen into 2 windows.
map <F5> :bp<CR> " Go to the previous buffer
map <F6> :bn<CR> " Go to the next buffer
map <F12> :bd<CR> " Drop the current buffer

" Section: Copy Paste {{{2
" Shift-Insert pasting, like xterm and (gosh) Windows using the '*' register
map <S-Insert> "*P<Right>"
imap <S-Insert> <C-R>*
cmap <S-Insert> <C-R>*

" Make p in Visual mode replace the selected text with the ** register
vnoremap p <ESC>:let current_reg = @"<CR>gvdi<C-R>=current_reg<CR><ESC>
set pastetoggle=<F8> " Map F8 to do the insert in the paste mode


" Section: Amir Settings {{{2

vnoremap <C-c> <Esc> " Map CTRL+C to ESC to overcome the visual block issue of replacing only one line
let mapleader="," " Can't remember why I need this
let g:ftplugin_sql_omni_key = '<C-j>' " Fix delayed CTRL+C in sql files

" Shortcuts
let @f = '$zf%'
let @x = "oconsole.log('XXXXXXXXXXXXXXXXX');"
let @c = 'oconsole.log();klkl'
let @v = '@x@xOconsole.log();klkl'


" Section: Plugins {{{1

" ** <VUNDLE> **
" git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

Plugin 'elzr/vim-json'
let g:vim_json_syntax_conceal = 0

Plugin 'godlygeek/tabular'

Bundle "marijnh/tern_for_vim"
let g:tern_map_keys=1
let g:tern_show_argument_hints='on_hold'
set runtimepath-=~/.vim/bundle/tern_for_vim " disable for now

" CtrlP
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_working_path_mode = 'ra'
"set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " Linux/MacOSX
"set wildignore+=*/node_modules/*,*/live/*,*/dist/*

let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/](live|dist|node_modules)\v[\/]',
  \ 'file': '\v\.(swp|swo|zip|so)$',
  \ }

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" ** </VUNDLE> **


" ** OLD **
"cmap RMT %s/\s//$+\ " Clear trailing whitespaces
"nnoremap Q ^d$ " clear the current line

