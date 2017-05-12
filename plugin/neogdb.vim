sign define GdbBreakpoint text=● texthl=WarningMsg
sign define GdbCurrentLine text=⇒ texthl=CursorLineNr linehl=diffText


let s:gdb_port = 7778
let s:breakpoints = {}
let s:max_breakpoint_sign_id = 0

let s:plugin_path = escape(expand('<sfile>:p:h:h'), '\')
let s:gdb_backtrace_qf = '/tmp/gdb.backtrace'
let s:gdb_breakpoints_qf = '/tmp/gdb.breakpoints'
let s:brk_file = './.gdb.break'
let s:fl_file = './.gdb.file'

"""""""""""""""""""""""""""""""""""""""""""""""
""" GdbServer
"""""""""""""""""""""""""""""""""""""""""""""""

let s:GdbServer = {}


function s:GdbServer.new(gdb)
  let this = copy(self)
  let this._gdb = a:gdb
  return this
endfunction


function s:GdbServer.on_exit()
  let self._gdb._server_exited = 1
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" GdbPaused
"""""""""""""""""""""""""""""""""""""""""""""""

let s:GdbPaused = vimexpect#State([
      \ ['Continuing.', 'continue'],
      \ ['\v[\o32]{2}([^:]+):(\d+):\d+', 'jump'],
      \ ['neovim_backtrace done', 'neovim_backtrace'],
      \ ['neovim_breakpoints done', 'neovim_breakpoints'],
      \ ['Remote communication error.  Target disconnected.:', 'retry'],
      \ ])


function! s:GdbPaused.continue(...)
  call self._parser.switch(s:GdbRunning)
  call self.update_current_line_sign(0)
endfunction


function!  s:GdbPaused.jump(file, line, ...)

  let l:callback = {}
  let l:callback.args = copy(a:)
  let l:callback.self = self

  function! l:callback.call()
    let self.self._current_buf = bufnr('%')
    let target_buf = bufnr(self.args.file, 1)
    if bufnr('%') != target_buf
      exe 'buffer ' target_buf
      let self.self._current_buf = target_buf
    endif
    exe ':' self.args.line
    let self.self._current_line = self.args.line
    normal! zz
  endfunction

  call self.executeInCodeWindow(l:callback)
endfunction


function!  s:GdbPaused.retry(...)
  if self._server_exited
    return
  endif
  sleep 1
  call self.attach()
  call self.send('continue')
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" Gdb backtrace
"""""""""""""""""""""""""""""""""""""""""""""""

function! s:neovim_backtrace_init(buffer)
  set filetype=gdbTerminal
  nnoremap <buffer><silent> <CR> :GdbGoToFrame<CR>
  nnoremap <buffer><silent> <tab> :GdbGoToFrame<CR>j
  nnoremap <buffer><silent> <S-tab> k:GdbGoToFrame<CR>
endfunction


function! s:GdbPaused.neovim_backtrace(...)
  call g:reswin#Shell('cat ' . s:gdb_backtrace_qf, {'onComplete': function('<SID>neovim_backtrace_init')})
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" Gdb breakpoints
"""""""""""""""""""""""""""""""""""""""""""""""

function! s:neogdb_breakpoints_init(buffer)
  nnoremap <buffer><silent> <CR> :call <SID>neogdb_breakpoints_goto(getline('.'))<CR>
  nnoremap <buffer><silent> r :call <SID>neogdb_breakpoints_refresh()<CR>
  nnoremap <buffer><silent> t :call <SID>neogdb_breakpoints_toggle(getline('.'))<CR>
  nnoremap <buffer><silent> d :call <SID>neogdb_breakpoints_delete(getline('.'))<CR>
  set filetype=gdbBreakpointInfo
endfunction


function! s:neogdb_breakpoints_parse_line(line)
  let l:match =  matchlist(a:line, '\v^(\d+%(\.\d+)?)\s+(breakpoint)?\s+%(keep)?\s+(y|n)\s+\S+\s+in\s+(\S+)\([^)]*\)\s+at\s+(\/[^:]+):(\d+)')
  if len(l:match)
    return {
          \ 'number': l:match[1],
          \ 'type': l:match[2],
          \ 'enable': l:match[3] == 'y' ? v:true : v:false,
          \ 'function': l:match[4],
          \ 'file': l:match[5],
          \ 'line': l:match[6]
          \ }
  endif

  " 1       breakpoint     keep y   <MULTIPLE>
  let l:match =  matchlist(a:line, '\v^(\d+%(\.\d+)?)\s+(breakpoint)?\s+%(keep)?\s+(y|n)\s+')
  if len(l:match)
    return {
          \ 'number': l:match[1],
          \ 'type': l:match[2],
          \ 'enable': l:match[3] == 'y' ? v:true : v:false
          \ }
  endif
  return {}
endfunction


function! s:neogdb_breakpoints_refresh()
  if !exists('g:gdb')
    return
  endif

  call g:gdb.send('neovim_breakpoints')
endfunction


function! s:neogdb_breakpoints_goto(line)
  if !exists('g:gdb')
    return
  endif

  let l:breakpoint = s:neogdb_breakpoints_parse_line(a:line)

  if exists('l:breakpoint.file') && exists('l:breakpoint.line')
    let l:callback = {}
    let l:callback.breakpoint = l:breakpoint

    function! l:callback.call()
      let target_buf = bufnr(self.breakpoint.file, 1)
      if bufnr('%') != target_buf
        exe 'buffer ' target_buf
      endif
      exe ':' self.breakpoint.line
      normal! zz
    endfunction

    call g:gdb.executeInCodeWindow(l:callback)
  endif
endfunction


function! s:neogdb_breakpoints_toggle(line)
  if !exists('g:gdb')
    return
  endif

  let l:breakpoint = s:neogdb_breakpoints_parse_line(a:line)

  if exists('l:breakpoint.number') && exists('l:breakpoint.enable')
    if l:breakpoint.enable
      call g:gdb.send(printf('disable %s', l:breakpoint.number))
    else
      call g:gdb.send(printf('enable %s', l:breakpoint.number))
    endif
    call g:gdb.send('neovim_breakpoints')
  endif
endfunction


function! s:neogdb_breakpoints_delete(line)
  if !exists('g:gdb')
    return
  endif

  let l:breakpoint = s:neogdb_breakpoints_parse_line(a:line)

  if exists('l:breakpoint.number')
    call g:gdb.send(printf('delete %s', l:breakpoint.number))
    call g:gdb.send('neovim_breakpoints')
  endif
endfunction


function! s:GdbPaused.neovim_breakpoints(...)
  call g:reswin#Shell('cat ' . s:gdb_breakpoints_qf, {
    \   'keepFocus': v:false,
    \   'preservePosition': v:true,
    \   'onCreate': function('<SID>neogdb_breakpoints_init')
    \ })
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" GdbRunning
"""""""""""""""""""""""""""""""""""""""""""""""

let s:GdbRunning = vimexpect#State([
      \ ['\v^Breakpoint \d+', 'pause'],
      \ ['\v\[Inferior\ +.{-}\ +exited\ +normally', 'disconnected'],
      \ ['(gdb)', 'pause'],
      \ ])


function! s:GdbRunning.pause(...)
  call self._parser.switch(s:GdbPaused)
  if !self._initialized
    call self.send('source ' . s:plugin_path . '/gdb/gdbinit')
    if !empty(self._server_addr)
      call self.send('set remotetimeout 50')
      call self.attach()
      call self.send('c')
    endif
    call s:RefreshBreakpoints()
    let self._initialized = 1
  endif
endfunction


function! s:GdbRunning.disconnected(...)
  if !self._server_exited && self._reconnect
    " Refresh to force a delete of all watchpoints
    call s:RefreshBreakpoints()
    sleep 1
    call self.attach()
    call self.send('continue')
  endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" Gdb
"""""""""""""""""""""""""""""""""""""""""""""""

let s:Gdb = {}


" Close gdb session
function! s:Gdb.kill()
  call self.update_current_line_sign(0)

  if bufexists(self._client_buf)
    exe 'bd! ' . self._client_buf
  endif

  if self._server_buf != -1 && bufexists(self._server_buf)
    exe 'bd! ' . self._server_buf
  endif

  if exists('g:gdb')
    unlet g:gdb
  endif
endfunction


" Send command to the gdb session
function! s:Gdb.send(data)
  call jobsend(self._client_id, "\<c-u>" . a:data . "\<cr>")
endfunction


" Execute a function in the context of the code window
function! s:Gdb.executeInCodeWindow(callback)
  if tabpagenr() != self._tab
    " Don't do anything if we are not in the debugger tab
    return
  endif

  let l:source_window = winnr()
  exe self._code_window 'wincmd w'

  try
    call a:callback.call()
  finally
    " Go back to the origin window
    exe l:source_window 'wincmd w'
    call self.update_current_line_sign(1)
  endtry
endfunction


" Attach the gdb session a the gdb server
function! s:Gdb.attach()
  call self.send(printf('target remote %s', self._server_addr))
endfunction


" Update the sign corresponding to the current line
function! s:Gdb.update_current_line_sign(add)
  " to avoid flicker when removing/adding the sign column(due to the change in
  " line width), we switch ids for the line sign and only remove the old line
  " sign after marking the new one
  let old_line_sign_id = get(self, '_line_sign_id', 4999)
  let self._line_sign_id = old_line_sign_id == 4999 ? 4998 : 4999

  if a:add && self._current_line != -1 && self._current_buf != -1
    exe 'sign place ' . self._line_sign_id 
          \ . ' name=GdbCurrentLine'
          \ . ' line=' . self._current_line
          \ . ' buffer=' . self._current_buf
  endif

  exe 'sign unplace '.old_line_sign_id
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" Functions
"""""""""""""""""""""""""""""""""""""""""""""""


" Initialize the gdb session
function! s:Spawn(server_cmd, client_cmd, server_addr, reconnect)
  if exists('g:gdb')
    throw 'Gdb already running'
  endif

  let gdb = vimexpect#Parser(s:GdbRunning, copy(s:Gdb))
  " gdbserver port
  let gdb._server_addr = a:server_addr
  let gdb._reconnect = a:reconnect
  let gdb._initialized = 0
  " window number that will be displaying the current file
  let gdb._code_window = 1
  let gdb._current_buf = -1
  let gdb._current_line = -1
  let gdb._has_breakpoints = 0 
  let gdb._server_exited = 0
  " Create new tab for the debugging view
  " tabnew
  let gdb._tab = tabpagenr()
  " create horizontal split to display the current file and maybe gdbserver
  " sp
  let gdb._server_buf = -1

  if type(a:server_cmd) == type('')
    " spawn gdbserver in a vertical split
    let server = s:GdbServer.new(gdb)
    vsp | enew | let gdb._server_id = termopen(a:server_cmd, server)
    let gdb._code_window = 2
    let gdb._server_buf = bufnr('%')
  endif

  vsplit | enew | let gdb._client_id = termopen(a:client_cmd, gdb)

  let gdb._client_buf = bufnr('%')
  set ft=gdbTerminal
  autocmd TermClose <buffer> call <SID>Kill()
  " go to the window that displays the current file
  exe gdb._code_window 'wincmd w'

  let g:gdb = gdb
endfunction


" Toggle breakpoint on the current line
function! s:ToggleBreak()
  let file_name = bufname('%')
  let file_breakpoints = get(s:breakpoints, file_name, {})
  let linenr = line('.')
  if has_key(file_breakpoints, linenr)
    call remove(file_breakpoints, linenr)
  else
    let file_breakpoints[linenr] = 1
  endif
  let s:breakpoints[file_name] = file_breakpoints
  call s:RefreshBreakpointSigns()
  call s:RefreshBreakpoints()
endfunction


" Delete all breakpoints
function! s:ClearBreak()
  let s:breakpoints = {}
  call s:RefreshBreakpointSigns()
  call s:RefreshBreakpoints()
endfunction


" Refresh signs corresponding to active breakpoints
function! s:RefreshBreakpointSigns()
  let buf = bufnr('%')
  let i = 5000
  while i <= s:max_breakpoint_sign_id
    exe 'sign unplace '.i
    let i += 1
  endwhile
  let s:max_breakpoint_sign_id = 0
  let id = 5000
  for linenr in keys(get(s:breakpoints, bufname('%'), {}))
    exe 'sign place '.id.' name=GdbBreakpoint line='.linenr.' buffer='.buf
    let s:max_breakpoint_sign_id = id
    let id += 1
  endfor
endfunction


" Refresh in memory breakpoint list with the gdb session
function! s:RefreshBreakpoints()
  if !exists('g:gdb')
    return
  endif
  if g:gdb._parser.state() == s:GdbRunning
    " pause first
    call jobsend(g:gdb._client_id, "\<c-c>")
  endif
  if g:gdb._has_breakpoints
    call g:gdb.send('delete')
  endif
  let g:gdb._has_breakpoints = 0
  for [file, breakpoints] in items(s:breakpoints)
    for linenr in keys(breakpoints)
      let g:gdb._has_breakpoints = 1
      call g:gdb.send('break '.file.':'.linenr)
    endfor
  endfor
endfunction


" Add the list of breakpoints to the quickfix list
function! s:ListBreak()
  if !exists('g:gdb')
    return
  endif

  let l:list = []
  for [file, breakpoints] in items(s:breakpoints)
    for lnum in keys(breakpoints)
      call add(list, {
            \ 'filename': file,
            \ 'lnum': lnum,
            \ })
    endfor
  endfor

  call setqflist(l:list, 'r', 'neovim_gdb breakpoints')
endfunction


function! s:GetExpression(...) range
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][:col2 - 1]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction


" Send command to the gdb session
function! s:Send(data)
  if !exists('g:gdb')
    return
  endif

  call g:gdb.send(a:data)
endfunction


" Print an expression in the gdb session
function! s:Eval(expr)
  call s:Send(printf('print %s', a:expr))
endfunction


" Watch an expression in the gdb session
function! s:Watch(expr)
  let expr = a:expr
  if expr[0] != '&'
    let expr = '&' . expr
  endif

  call s:Eval(expr)
  call s:Send('watch *$')
endfunction


" Interrupt gdb session
function! s:Interrupt()
  if !exists('g:gdb')
    return
  endif
  call s:Send('\<c-c>info line')
endfunction


" Kill gdb session
function! s:Kill()
  if !exists('g:gdb')
    return
  endif
  call g:gdb.kill()
endfunction

" Go to Frame in a neovim backtrac window
function! s:GoToFrame()
  let matchs =  matchlist(getline('.'), '\c^#\(\d\+\)\s')
  if len(matchs)
    call s:Send(printf('frame %d', matchs[1]))
  endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""
""" Commands
"""""""""""""""""""""""""""""""""""""""""""""""

command! -nargs=+ -complete=file Gdb call s:Spawn(0, printf('gdb -q -f %s', <q-args>), 0, 0)
command! GdbClose call s:Kill()
command! GdbToggleBreakpoint call s:ToggleBreak()
command! GdbClearBreakpoints call s:ClearBreak()
command! GdbListBreakpoints call s:ListBreak()
command! GdbContinue call s:Send("c")
command! GdbNext call s:Send("n")
command! GdbUntil call s:Send(printf("until %s:%d", bufname('%'), line('.')))
command! GdbStep call s:Send("s")
command! GdbFinish call s:Send("finish")
command! GdbFrame call s:Send("frame" . (len(<q-args>) ? ' ' . <q-args> : ''))
command! GdbGoToFrame call s:GoToFrame()
command! GdbFrameUp call s:Send("up")
command! GdbFrameDown call s:Send("down")
command! GdbInterrupt call s:Interrupt()
command! GdbEvalWord call s:Eval(expand('<cword>'))
command! -range GdbEvalRange call s:Eval(s:GetExpression(<f-args>))
command! GdbWatchWord call s:Watch(expand('<cword>'))
command! -range GdbWatchRange call s:Watch(s:GetExpression(<f-args>))
