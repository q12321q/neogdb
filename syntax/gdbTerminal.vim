" $Id: gdbTerminal.vim,v 0.1 2016/09/17 16:10:00 $
" Vim syntax file
" Language: gdb in terminal
" Maintainer: q12321q <q12321q@gmail.com>
" Last Change: $Date: 2016/09/17 16:10:00 $

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match GdbTerminalPrompt /\v^\(gdb\)/

syn region GdbTerminalString start=+L"+ skip=+\\\\\|\\"+ end=+"+
syn match GdbTerminalNumber /\v\d+/ contained
syn match GdbTerminalHexa /\v0x[0-9a-zA-Z]+/ contained

syn match GdbTerminalFilePosition /\v\/[^:]+:\d+/ contains=GdbTerminalFilePositionNumber,GdbTerminalFilePositionFile
syn match GdbTerminalFilePositionNumber /\v:\d+/ms=s+1 contained
syn match GdbTerminalFilePositionFile /\v\/[^:]+/ contained

syn match GdbTerminalBreakpoint /\v^Breakpoint +\d+, +[^ ]+ \([^)]+\) at [^ ]+$/ contains=GdbTerminalBreakpointNumber,GdbTerminalBreakpointParam,GdbTerminalBreakpointFunction,GdbTerminalBreakpointFile
syn match GdbTerminalBreakpointFunction /\v[^ ]+/ contained
syn match GdbTerminalBreakpointNumber /\v^Breakpoint \d+/ contained
syn match GdbTerminalBreakpointParam /\v\([^)]+\) at/ contained
syn match GdbTerminalBreakpointFile /\v \/.+$/ contained contains=GdbTerminalFilePositionFile

syn match GdbTerminalFrame /\v^#\d+ +(0x[0-9a-zA-Z]+ in)? [^ ]+/ contains=GdbTerminalFrameNumber,GdbTerminalFrameDummy,GdbTerminalFrameFunction
syn match GdbTerminalFrameNumber /\v#\d+/ contained
syn match GdbTerminalFrameFunction /\v[^ #]+/ contained
syn match GdbTerminalFrameDummy /\v0x[0-9a-zA-Z]+ in/ contained

syn match GdbTerminalVariable /\v^\$\d+ +\= +\([^)]+\).*/ contains=GdbTerminalVariableNumber,GdbTerminalVariableType,GdbTerminalHexa
syn match GdbTerminalVariableNumber /\v^\$\d+/ contained
syn match GdbTerminalVariableType /\v\([^)]+\)/me=e-1,ms=s+1 contained

syn match GdbTerminalPrint /\v^ +[^ ]+ +\= +.*$/ contains=GdbTerminalPrintVar,GdbTerminalHexa,GdbTerminalNumber,GdbTerminalString,GdbTerminalPrintType
syn match GdbTerminalPrintVar /\v[^ ]+ \= /me=e-3 contained
syn match GdbTerminalPrintType /\v\<[^ ]+\> \= /me=e-3 contained
syn match GdbTerminalPrintMemberOf /\vmembers of [^ ]+:$/ms=s+11,me=e-1

syn case ignore


if !exists("did_gdbTerminal_syntax_inits")
  let did_gdbTerminal_syntax_inits = 1
  hi link GdbTerminalPrompt ModeMsg
  hi link GdbTerminalString String
  hi link GdbTerminalFrame Number
  hi link GdbTerminalFilePositionNumber Number
  hi link GdbTerminalFilePositionFile Comment
  hi link GdbTerminalFrameNumber Todo
  hi link GdbTerminalFrameFunction Function
  hi link GdbTerminalPrintVar Identifier
  hi link GdbTerminalPrintType Type
  hi link GdbTerminalHexa SpecialChar
  hi link GdbTerminalNumber Number
  hi link GdbTerminalBreakpointNumber Todo
  hi link GdbTerminalBreakpointFunction Function
  hi link GdbTerminalVariableNumber Todo
  hi link GdbTerminalVariableType Type
  hi link GdbTerminalPrintMemberOf Type

endif
let b:current_syntax="gdbTerminal"

