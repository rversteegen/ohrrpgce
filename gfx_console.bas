''
'' gfx_console - Not a real graphics backend; for testing from the console
''               Uses curses (ncurses on Unix, pdcurses on Windows).
''
'' Part of the OHRRPGCE - See LICENSE.txt for GNU GPL License details and disclaimer of liability
''


#include "config.bi"
#include "gfx_newRenderPlan.bi"
#include "gfx.bi"
#include "common.bi"
#include "allmodex.bi"
#include "curses.bi"
#include once "crt.bi"

#undef raw

extern "C"

declare function putenv (byval as zstring ptr) as integer

'Wrapper functions in curses_wrap.c (really, this backend should be written in C)
declare function get_stdscr() as WINDOW ptr
declare sub set_ESCDELAY(byval val as integer)
#undef stdscr
#define stdscr get_stdscr()

end extern

'Bit of a blooper in curses.bi
#ifdef __FB_WIN32__
 #define CURSES_ERR PDC_ERR
#else
 #define CURSES_ERR NCURSES_ERR
#endif

type KeyMapPair
	curses_key as integer
	ohr_key as integer
end type

dim shared keymappairs(...) as KeyMapPair => { _
	(ASC("A"), scA), _
	(ASC("B"), scB), _
	(ASC("C"), scC), _
	(ASC("D"), scD), _
	(ASC("E"), scE), _
	(ASC("F"), scF), _
	(ASC("G"), scG), _
	(ASC("H"), scH), _
	(ASC("I"), scI), _
	(ASC("J"), scJ), _
	(ASC("K"), scK), _
	(ASC("L"), scL), _
	(ASC("M"), scM), _
	(ASC("N"), scN), _
	(ASC("O"), scO), _
	(ASC("P"), scP), _
	(ASC("Q"), scQ), _
	(ASC("R"), scR), _
	(ASC("S"), scS), _
	(ASC("T"), scT), _
	(ASC("U"), scU), _
	(ASC("V"), scV), _
	(ASC("W"), scW), _
	(ASC("X"), scX), _
	(ASC("Y"), scY), _
	(ASC("Z"), scZ), _
	(ASC("0"), sc0), _
	(ASC("1"), sc1), _
	(ASC("2"), sc2), _
	(ASC("3"), sc3), _
	(ASC("4"), sc4), _
	(ASC("5"), sc5), _
	(ASC("6"), sc6), _
	(ASC("7"), sc7), _
	(ASC("8"), sc8), _
	(ASC("9"), sc9), _
	(ASC(" "), scSpace), _
	(ASC(","), scComma), _
	(ASC("."), scPeriod), _
	(ASC("["), scLeftBracket), _
	(ASC("]"), scRightBracket), _
	(ASC("-"), scMinus), _
	(ASC("+"), scPlus), _
	(KEY_LEFT, scLeft), _
	(KEY_RIGHT, scRight), _
	(KEY_UP, scUp), _
	(KEY_DOWN, scDown), _
	(KEY_ENTER, scEnter), _
	(10, scEnter), _
	(KEY_BACKSPACE, scBackspace), _
	(127, scBackspace), _
	(KEY_DC, scDelete), _
	(27, scEsc), _
	(KEY_HOME, scHome), _
	(KEY_END, scEnd), _
	(KEY_NPAGE, scPageDown), _
	(KEY_PPAGE, scPageUp) _
}

dim shared keymap() as integer

extern "C"

dim shared curses_mode as bool = YES
dim shared force_256_color as bool = YES
dim shared window_state as WindowState
dim shared init_gfx as integer = 0
dim shared as integer mousex = 0, mousey = 0
dim shared inputtext as string
dim shared erasedscr as integer

sub init_keymap()
	redim keymap(KEY_MAX)
	for i as integer = 0 to ubound(keymappairs)
		with keymappairs(i)
			keymap(.curses_key) = .ohr_key
		end with
	next
	for i as integer = 1 to 12
		keymap(KEY_F0 + i) = scF1 - 1 + i
	next
end sub

function gfx_console_init(byval terminate_signal_handler as sub cdecl (), byval windowicon as zstring ptr, byval info_buffer as zstring ptr, byval info_buffer_size as integer) as integer
	dim retstr as string
	dim ret as integer = 1
	window_state.focused = YES
	window_state.minimised = NO

	if curses_mode then
		retstr = *curses_version()

		dim term as string = *getenv("TERM")
		retstr += " TERM=" & term
		if force_256_color and term = "xterm" then
			'Enable 256 colour mode.
			'Make this assumption, since 256-colour capable
			'terminals seem to be misrepresented as 'xterm' very often
			putenv("TERM=xterm-256color")
			retstr += " (override to xterm-256color)"
		end if

		init_keymap()
		if init_gfx = 0 then
			if initscr() = NULL then
				retstr &= " ... initscr failed"
				ret = 0
			else
				start_color()  'might fail
				cbreak()
				noecho()
				nonl()
				keypad(stdscr, 1)
				set_ESCDELAY(40)
				nodelay(stdscr, 1)
				scrollok(stdscr, 0)
				'notimeout(stdscr, 1)
				intrflush(stdscr, 1)
				retstr &= " has_colors()=" & has_colors() & " can_change_color()=" & can_change_color() & " COLORS=" & COLORS & " COLOR_PAIRS=" & COLOR_PAIRS
			end if
		end if
	else
		retstr = "non-visual mode"
	end if
	*info_buffer = MID(retstr, 1, info_buffer_size)
	return ret
end function

sub gfx_console_close
	if curses_mode then
		'This doesn't reset the colours, unfortunately
		endwin()
		'Reset console
		'fwrite(@!"\&o033[0m", 1, 4, stdout)
	end if
end sub

function gfx_console_getversion() as integer
	return 1
end function

dim shared master_color_to_attr(255) as integer

sub gfx_console_setup_colors(byval pal as RGBcolor ptr)
	'Changes colours to the palette colours, if possible,
	'then computes mapping from master palette colours to terminal
	'colours.
	dim mult as double = 1.
	if can_change_color() then
		for i as integer = 1 to small(COLORS - 1, 255)
			with pal[i]
				init_color(i, 1000 * .r / 255, 1000 * .g / 255, 1000 * .b / 255)
			end with
		next
	elseif COLORS <= 8 then
		' We assume that drawing bold text also brightens also the colours; compensate for that.
		' (Otherwise there would likely be 16 colours).
		mult = 1.5
	end if

	' The number of color pairs that we will use
	dim num_pairs as integer = small(small(COLOR_PAIRS, COLORS), 256)

	' Color pair 0 can't be changed
	for i as integer = 1 to num_pairs - 1
		init_pair(i, i, COLOR_BLACK)
	next

	dim console_pal(255) as RGBcolor

	for i as integer = 0 to num_pairs - 1
		dim as short r, g, b
		color_content(i, @r, @g, @b)
		'debug i & " " & " rgb " & r & " " & g & " " & b
		console_pal(i).r = small(255, mult * cint(r) * 255 \ 1000)
		console_pal(i).g = small(255, mult * cint(g) * 255 \ 1000)
		console_pal(i).b = small(255, mult * cint(b) * 255 \ 1000)
	next

	' for i as integer = 0 to num_pairs - 1
	' 	console_pal(COLORS + i).r = small(255, 128 + console_pal(i).r)
	' 	console_pal(COLORS + i).g = small(255, 128 + console_pal(i).g)
	' 	console_pal(COLORS + i).b = small(255, 128 + console_pal(i).b)
	' next


	master_color_to_attr(0) = 0  'Default text colour rather than black. Don't want it to be invisible
	for i as integer = 1 to 255
		'Bold text, to look more like the default font!
		dim col as integer = nearcolor(console_pal(), pal[i].r, pal[i].g, pal[i].b, 1)
		'debug i & " -> " & col
		master_color_to_attr(i) = COLOR_PAIR(col) OR A_BOLD
	next
end sub

sub gfx_console_showpage(byval raw as ubyte ptr, byval w as integer, byval h as integer)
	if curses_mode = NO then exit sub
	move(0, 0)
	refresh()
	'getch causes a refresh call, which would erase the screen contents... why?!
	'Work around it by not erasing until later
	'werase(stdscr)
	erasedscr = NO
end sub

sub gfx_console_setpal(byval pal as RGBcolor ptr)
	'print "setpal"
	if curses_mode then gfx_console_setup_colors(pal)
end sub

sub gfx_console_printchar (byval ch as integer, byval x as integer, byval y as integer, byval col as integer)
	if curses_mode = NO then exit sub

	'Workaround some stupid ncurses behaviour. See showpage
	if erasedscr = NO then
		werase(stdscr)
		erasedscr = YES
	end if

	if ch >= 32 and ch < 127 or ch >= 161 then
		' if col mod 8 = 0 then
		' 	col = 7
		' else
		' 	col = col mod 8
		' end if
		'col = 1
		attron(master_color_to_attr(col))
		mvaddch(y\8, x\8, ch)
		'attroff(COLOR_PAIR(col))
		attrset(0)
	end if
	'debug x & "," & y & " " & chr(ch)
end sub

function gfx_console_present(byval surfaceIn as Surface ptr, byval pal as BackendPalette ptr) as integer
	gfx_console_showpage(NULL, 0, 0)
	return 0
end function

function gfx_console_screenshot(byval fname as zstring ptr) as integer
	return 0
end function

sub gfx_console_setwindowed(byval iswindow as integer)
end sub

sub gfx_console_windowtitle(byval title as zstring ptr)
	'print "window title: " & *title
end sub

function gfx_console_getwindowstate() as WindowState ptr
	return @window_state
end function

function gfx_console_setoption(byval opt as zstring ptr, byval arg as zstring ptr) as integer
	dim as integer value = str2int(*arg, -1)
	dim as integer ret = 0
	if init_gfx = 0 then
		if *opt = "debuglog" or *opt = "d" then
			curses_mode = NO
			debug_to_console = YES
			ret = 1
		elseif *opt = "dontforce256" then
			force_256_color = NO
			ret = 1
		end if
	else
		debug "gfx_console_setoption: backend already started"
	end if

	return ret
end function

function gfx_console_describe_options() as zstring ptr
	return @!"-d -debuglog        Disable curses; print ?_debug log instead. No user input! \n" _
                 "-dontforce256       Don't assume that TERM=xterm means TERM=xterm-256color"
end function

'------------- IO Functions --------------
sub io_console_init
end sub

sub io_console_updatekeys(byval keybd as integer ptr)
	'uses keybits instead
end sub

sub io_console_keybits(byval keybd as integer ptr)
	for i as integer = 0 to 127
		keybd[i] = 0
	next

	if curses_mode = NO then exit sub

	'This only supports part of the keyboard, and some
	'terminals, like linux vttys support even less (no page up/down)

	dim key as integer
	dim kmkey as integer
	while 1
		key = getch()
		if key = CURSES_ERR then exit while
		kmkey = key
		dim tmp as string = ""
		if key < 256 and key <> 10 and key <> 127 then
			inputtext &= chr(key)
			kmkey = toupper(key)
		end if
		'print "key " & key & " -> " & keymap(kmkey)
		kmkey = keymap(kmkey)
		if kmkey then
			keybd[kmkey] = 3
		end if
	wend
end sub

sub io_console_textinput (byval buf as wstring ptr, byval bufsize as integer)
	dim buflen as integer = bufsize \ 2 - 1
	*buf = LEFT(inputtext, buflen)
	inputtext = MID(inputtext, buflen)
end sub

SUB io_console_show_virtual_keyboard()
 'Does nothing on platforms that have real keyboards
END SUB

SUB io_console_hide_virtual_keyboard()
 'Does nothing on platforms that have real keyboards
END SUB

sub io_console_setmousevisibility(byval visible as integer)
end sub

sub io_console_getmouse(byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer)
	mx = mousex
	my = mousey
	mwheel = 0
	mbuttons = 0
end sub

sub io_console_setmouse(byval x as integer, byval y as integer)
	mousex = x
	mousey = y
end sub

sub io_console_mouserect(byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)
	mousex = xmin
	mousey = ymin
end sub

function io_console_readjoysane(byval joynum as integer, byref button as integer, byref x as integer, byref y as integer) as integer
	x = 0
	y = 0
	return 1
end function

function gfx_console_setprocptrs() as integer
	gfx_init = @gfx_console_init
	gfx_close = @gfx_console_close
	gfx_getversion = @gfx_console_getversion
	gfx_showpage = @gfx_console_showpage
	gfx_setpal = @gfx_console_setpal
	gfx_screenshot = @gfx_console_screenshot
	gfx_setwindowed = @gfx_console_setwindowed
	gfx_windowtitle = @gfx_console_windowtitle
	gfx_getwindowstate = @gfx_console_getwindowstate
	gfx_setoption = @gfx_console_setoption
	gfx_describe_options = @gfx_console_describe_options
	gfx_printchar = @gfx_console_printchar
	io_init = @io_console_init
	io_keybits = @io_console_keybits
	io_updatekeys = @io_console_updatekeys
	io_textinput = @io_console_textinput
	io_show_virtual_keyboard = @io_console_show_virtual_keyboard
	io_hide_virtual_keyboard = @io_console_hide_virtual_keyboard
	io_mousebits = @io_amx_mousebits
	io_setmousevisibility = @io_console_setmousevisibility
	io_getmouse = @io_console_getmouse
	io_setmouse = @io_console_setmouse
	io_mouserect = @io_console_mouserect
	io_readjoysane = @io_console_readjoysane

	'new render API
	gfx_present = @gfx_console_present

	return 1
end function

end extern
