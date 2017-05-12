" Syntax file for output of gdb breakpoint info

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match GdbBreakpointInfoHeader /\vNum.*$/

" syn region GdbTerminalString start=+L"+ skip=+\\\\\|\\"+ end=+"+
syn match GdbTerminalNumber /\v\dl+/ contained
syn match GdbBreakpointInfoHexa /\v0x[0-9a-zA-Z]+/ contained
"
" syn match GdbBreakpointInfoLine /\v^#\d+ +(0x[0-9a-zA-Z]+ in)? [^ ]+/ contains=GdbTerminalFrameNumber,GdbTerminalFrameDummy,GdbTerminalFrameFunction
syn match GdbBreakpointInfoLineNumber /\v^\d+(\.\d+)?/
syn match GdbBreakpointInfoLineEnable /\v\sy\s/
syn match GdbBreakpointInfoLineDisable /\v\sn\s/


if !exists("did_gdbBreakpointInfo_syntax_inits")
  let did_gdbBreakpointInfo_syntax_inits = 1
  hi link GdbBreakpointInfoHeader Special
  hi link GdbBreakpointInfoLineNumber Number
  hi link GdbBreakpointInfoHexa Comment

  hi link GdbBreakpointInfoLineEnable Title
  hi link GdbBreakpointInfoLineDisable WarningMsg

  hi link GdbTerminalString String
  hi link GdbTerminalFilePositionNumber Number
  hi link GdbTerminalFilePositionFile Comment
  hi link GdbTerminalFrameNumber Todo
  hi link GdbTerminalFrameFunction Function
  hi link GdbTerminalPrintVar Identifier
  hi link GdbTerminalPrintType Type
  hi link GdbTerminalNumber Number
  hi link GdbTerminalBreakpointNumber Todo
  hi link GdbTerminalBreakpointFunction Function
  hi link GdbTerminalVariableNumber Todo
  hi link GdbTerminalVariableType Type
  hi link GdbTerminalPrintMemberOf Type

endif
let b:current_syntax="did_gdbBreakpointInfo_syntax_inits"

