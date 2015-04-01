" vim600: set foldmethod=marker:
"
" LastChanged:	13/13/05
" Version:	1.0

" Section: Basic Settings {{{1

" Section: General Settings {{{2
set nocompatible " VIM, not vi
set showcmd " Show partial command in the status line
set autowrite " write modified file on various occasions
set shell=bash " shell to use
set hidden
set backspace=2

" Section: Visual Settings {{{2
set cpoptions+=$ " show a $ at the end of changing text
set laststatus=2 " always show status line
set showmatch " show the matching bracket
set tabstop=4 " size of tab
set autoindent " auto indention
set expandtab " don't write tabs but 4 spaces
set smarttab " 4 spaces work just like tab
set bg=dark " I like dark backgrounds
set wildmode=longest,list " when doing <TAB> show the list of options
set shortmess=aI " abbreviate all messages, and skip intro message

" Section: Syntax Highlighting {{{3
" source ...
syntax on

" Section: Search Settings {{{3
set nohlsearch " do not highlight searches
nnoremap <F1> :set nohls!<cr>

" Section: Format Settings {{{2
set formatoptions=cql " formatoptions: Options for the "text format" command ("gq")
set shiftwidth=4 " how many spaces to (auto) indent
au BufEnter *.py set ts=4 " override python.vim's suspicious ts=8 modeline
set textwidth=0

" Section: GUI Settings {{{2
if has("gui")
        colorscheme koehler
endif

" Section: Abbreviations {{{1
" This function returns the full name of the user that runs vim
function! GetFullUserName( )
        return system("perl -e 'my $name = (getpwuid($<))[6] || \"Unknown\"; print \"$name\";'")
endfunction

" Print date and created by line
iab Ydate <C-R>=strftime("%B %e, %Y")<CR>
iab Ycreated Created <C-R>=strftime("%B %e, %Y")<CR> by <C-R>=GetFullUserName()<CR>

" Section: Reality {{{2
" Print the real ownerz of this file
iab Yowner Ori Peleg and Misha Seltzer

" Section: Mapping {{{1
" Clear trailing whitespaces
cmap RMT %s/\s//$+\
nnoremap Q ^d$ " clear the current line

" Section: Buffers manipulations {{{2
map <F4> :split<CR> " Split the screen into 2 windows.
map <F5> :bp<CR> " Go to the previous buffer
map <F6> :bn<CR> " Go to the next buffer
map <F12> :bd<CR> " Drop the current buffer

" Section: Copy Paste {{{2
" Shift-Insert pasting, like xterm and (gosh) Windows using the '*' register
map <S-Insert> "*P<Right>"
imap <S-Insert> <C-R>*
imap <S-Insert> <C-R>*
" Make p in Visual mode replace the selected text with the ** register
vnoremap p <ESC>:let current_reg = @"<CR>gvdi<C-R>=current_reg<CR><ESC>
set pastetoggle=<F10> " Map F10 to do the insert in the paste mode

" <Leader>
let mapleader=","

" Fix delayed CTRL+C in sql files
let g:ftplugin_sql_omni_key = '<C-j>'

