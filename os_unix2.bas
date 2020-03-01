'OHRRPGCE COMMON - Generic Unix versions of OS-specific routines
'Please read LICENSE.txt for GNU GPL License details and disclaimer of liability
'
'This module is for Unix-specific functions that are more easily implemented
'in FB than in C.
'(But in fact almost all such code is in util.bas or common.rbas rather than here)

#include "config.bi"
#include "os.bi"
#include "util.bi"
#include "common_base.bi"

extern "C"

declare function _open_console_process_handle(term_file as zstring ptr) as ProcessHandle

' This may return either the name that the process was called with, which may have a full, relative, or no path,
' or just return the full path to the executable. Not necessarily equal to COMMAND(0).
' Returns "" if invalid or don't have permission.
' (Should return "<unknown>" if the pid exists but we can't get the path)
function get_process_path (pid as integer) as string
	dim cmdname as string
#if defined(__GNU_LINUX__)
	' With GNU ps, "-o command" and "-o cmd" return the name and arguments it was called with,
	' and "-o comm" is just the first 15 characters of the command name after stripping the path.
	' It appears to be impossible to get the non-truncated command name and path without also getting
	' the args and other post-processing to process stuff like "kdeinit4: ksysguard [kdeinit]"
	' The alternative, reading /proc/$pid/exe (linux-specific) changes if the exe is moved or deleted,
        ' which makes it unreliable for checking if the same pid and exe pair are still running.
	run_and_get_output("ps -p " & pid & " -o comm=", cmdname)
	'run_and_get_output("readlink /proc/" & pid & "/exe", cmdname)
#elseif  defined(__FB_ANDROID__)
	' On Android 4.4.2, ps doesn't support -o comm= option, and the output looks like
	'USER     PID   PPID  VSIZE  RSS   PRIO  NICE  RTPRI SCHED   WCHAN    PC         NAME
	'u0_a115   9481  159   380324 27624 20    0     0     0     ffffffff 00000000 S com.hamsterrepublic.ohrrpgce.custom
	run_and_get_output("ps -p " & pid, cmdname)
	dim where as integer = instrrev(cmdname, " ")
	if where then
		cmdname = mid(cmdname, where + 1)
	else
		cmdname = "<unknown>"
	end if
#else
	' On OSX (BSD) "-o comm" returns the name the command was called with (which may or may not include a path),
	' "-o command" adds the arguments, and "-o cmd" does not work.
	run_and_get_output("ps -p " & pid & " -o command=", cmdname)
#endif
	return rtrim(cmdname, !"\n")
end function

'Internal to terminal_emulator_commandline
LOCAL SUB try_term(byref termname as string, byref termexe as string, trywhat as string)
 IF LEN(trywhat) ANDALSO termname = "" THEN
  termexe = where_is_app(trywhat)
  IF LEN(termexe) THEN termname = trimpath(trywhat)
 END IF
END SUB

'Returns 0 on failure.
'If successful, you should call cleanup_process with the handle after you don't need it any longer.
'This is currently designed for asynchronously running console applications.
'On Windows it displays a visible console window, on Unix it doesn't.
'Could be generalised in future as needed.
'TODO: spawn_console_process() in customsubs.rbas basically implements this, move here!
function open_console_process (executable as string, args as string, title as string = "") as ProcessHandle

  DIM termexe as string
  DIM termargs as string


'Unix only!
'Form a commandline (split into and returned in termexe and termargs) to run
''executable args' in a terminal emulator. 'title' is an optional title to give
'the window, and may not be respected.
'Returns an error message, or "" on success.
'FUNCTION terminal_emulator_commandline(byref termexe as string, byref termargs as string, executable as string, args as string) as string
 ' TODO: this isn't going to work on OSX... unless maybe you have X11 installed?
 DIM termname as string
 try_term termname, termexe, read_config_str("terminal")
 'TODO: The follow emulators are disabled because they don't wait 
 try_term termname, termexe, "xfce4-terminal"
 try_term termname, termexe, "gnome-terminal"
 try_term termname, termexe, "konsole"
 try_term termname, termexe, "vte-2.91"   'Weird name... only other naming I could find was vte-2.90
 try_term termname, termexe, "xterm"
 IF termexe = "" THEN
   visible_debug "Can't find a terminal emulator; can't continue. " _
		 "Set 'terminal' in ohrrpgce_config.ini or install one " _
		 "of gnome-terminal, xfce4-terminal, konsole or xterm."
   RETURN 0
 END IF

 DIM term_file as string = tmpdir & "term_" & randint(10000) & ".tmp"
 safekill term_file
 DIM shellargs as string = _
     _ ' $$ is the shell PID not the process PID, but that's OK
     _ '"echo $$ > " & escape_filename(term_file) _
     "touch " & escape_filename(term_file) _
     & "; " & escape_filename(executable) & " " & args _
     & "; echo $? > " & escape_filename(term_file)
 shellargs = "sh -c """ & shellargs & """"

 termargs = " -e """ & escape_string(shellargs, """\") & """"
 IF termname = "xterm" THEN
  '-e must be last. sb/rightbar for scrollbar
  termargs = " -sb -rightbar -geometry 120x30 -bg black -fg gray90 -title '" & title & "'" + termargs
 ELSEIF termname = "xfce4-terminal" ORELSE termname = "gnome-terminal" THEN
  ' Support --geometry and -x
  ' gnome-terminal has --disable-factory to not spawn a child process and detach, but it's being dropped
  termargs += " --title '" & title & "'"
 ELSEIF LEFT(termname, 3) = "vte" THEN
  termargs = " --background-color=black --foreground-color=gray90 -- " & shellargs
 END IF
 'konsole doesn't support --title or -x


 dim proc as ProcessHandle = open_process(termexe, termargs, NO, NO)
 if proc = 0 then return 0
 ?"opened"
 'The handle is useless for most term emulators because they fork and detach themselves
 cleanup_process @proc
 'Create a new handle
 return _open_console_process_handle(strptr(term_file))
end function


end extern
