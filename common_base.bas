'OHRRPGCE - Common code for utilities
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'
'This module is for code to be linked into utilities, but not Game and Custom.
'These are replacements for common.rbas functions in a non-graphical environment.

#include "config.bi"
#include "common_base.bi"
#include "file.bi"

DIM workingdir as string

DIM context_string as string


DIM cleanup_function as sub ()

SUB debug (s as string)
  print s
END SUB

SUB debuginfo (s as string)
  print s
END SUB

SUB debugc cdecl alias "debugc" (byval errorlevel as errorLevelEnum, byval s as zstring ptr)
  IF errorlevel >= errFatal THEN fatalerror *s
  IF errorlevel = errBug OR errorlevel = errPromptBug OR errorlevel = errFatalBug THEN print "(BUG) ",
  IF errorlevel >= errError THEN print "ERROR: ",
  print *s
END SUB

SUB showerror (msg as string, isfatal as bool = NO, isbug as bool = NO)
 IF isfatal THEN
  fatalerror msg
 ELSE
  print msg
 END IF
END SUB

SUB visible_debug (msg as string, errlvl as errorLevelEnum = errDebug)
 debugc errlvl, msg
 'notification msg + !"\nPress any key..."
END SUB

SUB fatalerror (e as string)
  IF e <> "" THEN print "ERROR: " + e
  IF cleanup_function THEN cleanup_function()
  SYSTEM 1
END SUB

'TODO: this is basically identical between here and common.rbas, so should be moved to
'a different module
'This is a drop-in replacement for scripterr which can be called from outside
'the script interpreter. It hides some errors when playing a game in release mode,
'just like scripterr.
'context overrides the name of the current script command, if any. It does not override
'the context_string global, which is also reported.
SUB reporterr(msg as zstring ptr, errlvl as scriptErrEnum = serrBadOp, context as zstring ptr = NULL)
 'It's possible to be currently executing a script command, and for
 'context_string to be set, eg "advance textbox" calls advance_text_box, which
 'can cause an error. If we have both contexts, then the script command is
 'the outer, and context_string the inner, eg "advancetextbox: Textbox 1: invalid hero ID"
 'But 'context' is always the innermost
 DIM full_msg as string = *msg
 IF context THEN
  full_msg = *context & ": "
 END IF
 IF LEN(context_string) THEN
  full_msg = context_string & ": " & full_msg
 END IF
 IF errlvl >= serrBug THEN
  debugc errPromptBug, full_msg
 ELSEIF errlvl >= serrWarn THEN
  'errlvl >= serrError: Something like an unreadable data file
  'errlvl = serrBadOp or errlvl = serrWarn: Likely something like out-of-bounds data
  debugc errPromptError, full_msg
 ELSE
  'Info or ignore
  debugc errInfo, full_msg
 END IF
END SUB
