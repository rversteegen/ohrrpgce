''
'' gfx_sdl2.bas - External graphics functions implemented in SDL 1.2
''
'' Part of the OHRRPGCE - See LICENSE.txt for GNU GPL License details and disclaimer of liability
''

#include "config.bi"

#ifdef __FB_WIN32__
	'In FB >= 1.04 SDL.bi includes windows.bi; we have to include it first to do the necessary conflict prevention
	include_windows_bi()
#endif

#include "crt.bi"
#include "gfx.bi"
#include "surface.bi"
#include "common.bi"
#include "cutil.bi"
#include "scancodes.bi"
'#define NEED_SDL_GETENV

#ifdef __FB_UNIX__
	'In FB >= 1.04 SDL.bi includes Xlib.bi; fix a conflict
	#undef font
#endif

#include "SDL2\SDL.bi"

EXTERN "C"

#IFDEF __FB_ANDROID__
'This function shows/hides the sdl virtual gamepad
declare sub SDL_ANDROID_SetScreenKeyboardShown (byval shown as integer)
'This function toggles the display of the android virtual keyboard. always returns 1 no matter what
declare function SDL_ANDROID_ToggleScreenKeyboardWithoutTextInput() as integer 
'WARNING: SDL_ANDROID_IsScreenKeyboardShown seems unreliable. Don't use it! It is only declared here to document its existance. see the virtual_keyboard_shown variable instead
declare function SDL_ANDROID_IsScreenKeyboardShown() as bool
declare function SDL_ANDROID_IsRunningOnConsole () as bool
declare function SDL_ANDROID_IsRunningOnOUYA () as bool
declare sub SDL_ANDROID_set_java_gamepad_keymap(byval A as integer, byval B as integer, byval C as integer, byval X as integer, byval Y as integer, byval Z as integer, byval L1 as integer, byval R1 as integer, byval L2 as integer, byval R2 as integer, byval LT as integer, byval RT as integer)
declare sub SDL_ANDROID_set_ouya_gamepad_keymap(byval player as integer, byval udpad as integer, byval rdpad as integer, byval ldpad as integer, byval ddpad as integer, byval O as integer, byval A as integer, byval U as integer, byval Y as integer, byval L1 as integer, byval R1 as integer, byval L2 as integer, byval R2 as integer, byval LT as integer, byval RT as integer)
declare function SDL_ANDROID_SetScreenKeyboardButtonKey(byval buttonId as integer, byval key as integer) as integer
declare function SDL_ANDROID_SetScreenKeyboardButtonDisable(byval buttonId as integer, byval disable as bool) as integer
declare sub SDL_ANDROID_SetOUYADeveloperId (byval devId as zstring ptr)
declare sub SDL_ANDROID_OUYAPurchaseRequest (byval identifier as zstring ptr, byval keyDer as zstring ptr, byval keyDerSize as integer)
declare function SDL_ANDROID_OUYAPurchaseIsReady () as bool
declare function SDL_ANDROID_OUYAPurchaseSucceeded () as bool
declare sub SDL_ANDROID_OUYAReceiptsRequest (byval keyDer as zstring ptr, byval keyDerSize as integer)
declare function SDL_ANDROID_OUYAReceiptsAreReady () as bool
declare function SDL_ANDROID_OUYAReceiptsResult () as zstring ptr
#ENDIF

DECLARE FUNCTION putenv (byval as zstring ptr) as integer
#IFNDEF __FB_WIN32__
'Doens't work on Windows. There we do putenv with a null string
DECLARE FUNCTION unsetenv (byval as zstring ptr) as integer
#ENDIF

'DECLARE FUNCTION SDL_putenv cdecl alias "SDL_putenv" (byval variable as zstring ptr) as integer
'DECLARE FUNCTION SDL_getenv cdecl alias "SDL_getenv" (byval name as zstring ptr) as zstring ptr


DECLARE FUNCTION recreate_window(byval bitdepth as integer = 0) as bool
DECLARE FUNCTION recreate_screen_texture() as bool
DECLARE SUB gfx_sdl2_set_zoom(byval value as integer)
DECLARE FUNCTION present_internal2(srcsurf as SDL_Surface ptr, raw as any ptr, pitch as integer, bitdepth as integer) as bool
DECLARE SUB update_state()
DECLARE FUNCTION update_mouse() as integer
DECLARE SUB update_mouse_visibility()
DECLARE SUB set_forced_mouse_clipping(byval newvalue as bool)
DECLARE SUB internal_set_mouserect(byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)
DECLARE SUB internal_disable_virtual_gamepad()
DECLARE FUNCTION scOHR2SDL(byval ohr_scancode as integer, byval default_sdl_scancode as integer=0) as integer

DECLARE SUB log_error(failed_call as zstring ptr, funcname as zstring ptr)
#define CheckOK(condition, otherwise...)  IF condition THEN log_error(#condition, __FUNCTION__) : otherwise

#IFDEF __FB_DARWIN__

'--These wrapper functions in mac/SDLMain.m call various Cocoa methods
DECLARE SUB sdlCocoaHide()
DECLARE SUB sdlCocoaHideOthers()
DECLARE SUB sdlCocoaMinimise()

#ENDIF

DIM SHARED zoom as integer = 2  'Window size
DIM SHARED smooth_zoom as integer = 2  'Amount to zoom before applying smoothing
DIM SHARED smooth as integer = 0  'Smoothing mode (0 or 1)
DIM SHARED mainwindow as SDL_Window ptr = NULL
DIM SHARED mainrenderer as SDL_Renderer ptr = NULL
DIM SHARED maintexture as SDL_Texture ptr = NULL

DIM SHARED screenbuffer as SDL_Surface ptr = NULL
DIM SHARED last_bitdepth as integer   'Bitdepth of the last gfx_present call

DIM SHARED windowedmode as bool = YES
DIM SHARED resizable as bool = NO
DIM SHARED resize_requested as bool = NO
DIM SHARED resize_request as XYPair
DIM SHARED remember_windowtitle as string
DIM SHARED mouse_visibility as CursorVisibility = cursorDefault
DIM SHARED debugging_io as bool = NO
DIM SHARED joystickhandles(7) as SDL_Joystick ptr
DIM SHARED sdlpalette as SDL_Palette ptr
DIM SHARED framesize as XYPair
DIM SHARED dest_rect as SDL_Rect
DIM SHARED mouseclipped as bool = NO   'Whether we are ACTUALLY clipped
DIM SHARED forced_mouse_clipping as bool = NO
'These were the args to the last call to io_mouserect
DIM SHARED remember_mouserect as RectPoints = ((-1, -1), (-1, -1))
'These are the actual zoomed clip bounds
DIM SHARED as integer mxmin = -1, mxmax = -1, mymin = -1, mymax = -1
DIM SHARED as int32 privatemx, privatemy
DIM SHARED keybdstate(127) as integer  '"real"time keyboard array. See io_sdl2_keybits for docs.
DIM SHARED input_buffer as ustring
DIM SHARED mouseclicks as integer    'Bitmask of mouse buttons clicked (SDL order, not OHR), since last io_mousebits
DIM SHARED mousewheel as integer     'Position of the wheel. A multiple of 120
DIM SHARED virtual_keyboard_shown as bool = NO
DIM SHARED allow_virtual_gamepad as bool = YES
DIM SHARED safe_zone_margin as single = 0.0
DIM SHARED last_used_bitdepth as integer = 0

END EXTERN ' Can't put assignment statements in an extern block

'Translate SDL scancodes into a OHR scancodes
'Of course, scancodes can only be correctly mapped to OHR scancodes on a US keyboard.
'SDL scancodes say what's the unmodified character on a key. For example
'on a German keyboard the +/*/~ key is SDLK_PLUS, gets mapped to
'scPlus, which is the same as scEquals, so you get = when you press
'it.
'If there is no ASCII equivalent character, the key has a SDLK_WORLD_## scancode.

DIM SHARED scantrans(0 to SDL_NUM_SCANCODES) as integer
scantrans(SDL_SCANCODE_UNKNOWN) = 0
scantrans(SDL_SCANCODE_BACKSPACE) = scBackspace
scantrans(SDL_SCANCODE_TAB) = scTab
scantrans(SDL_SCANCODE_CLEAR) = 0
scantrans(SDL_SCANCODE_RETURN) = scEnter
scantrans(SDL_SCANCODE_PAUSE) = scPause
scantrans(SDL_SCANCODE_ESCAPE) = scEsc
scantrans(SDL_SCANCODE_SPACE) = scSpace
scantrans(SDL_SCANCODE_APOSTROPHE) = scQuote
scantrans(SDL_SCANCODE_COMMA) = scComma
scantrans(SDL_SCANCODE_PERIOD) = scPeriod
scantrans(SDL_SCANCODE_SLASH) = scSlash
scantrans(SDL_SCANCODE_0) = sc0
scantrans(SDL_SCANCODE_1) = sc1
scantrans(SDL_SCANCODE_2) = sc2
scantrans(SDL_SCANCODE_3) = sc3
scantrans(SDL_SCANCODE_4) = sc4
scantrans(SDL_SCANCODE_5) = sc5
scantrans(SDL_SCANCODE_6) = sc6
scantrans(SDL_SCANCODE_7) = sc7
scantrans(SDL_SCANCODE_8) = sc8
scantrans(SDL_SCANCODE_9) = sc9
scantrans(SDL_SCANCODE_SEMICOLON) = scSemicolon
scantrans(SDL_SCANCODE_EQUALS) = scEquals
scantrans(SDL_SCANCODE_LEFTBRACKET) = scLeftBracket
scantrans(SDL_SCANCODE_BACKSLASH) = scBackslash
scantrans(SDL_SCANCODE_RIGHTBRACKET) = scRightBracket
scantrans(SDL_SCANCODE_MINUS) = scMinus
scantrans(SDL_SCANCODE_GRAVE) = scBackquote
scantrans(SDL_SCANCODE_a) = scA
scantrans(SDL_SCANCODE_b) = scB
scantrans(SDL_SCANCODE_c) = scC
scantrans(SDL_SCANCODE_d) = scD
scantrans(SDL_SCANCODE_e) = scE
scantrans(SDL_SCANCODE_f) = scF
scantrans(SDL_SCANCODE_g) = scG
scantrans(SDL_SCANCODE_h) = scH
scantrans(SDL_SCANCODE_i) = scI
scantrans(SDL_SCANCODE_j) = scJ
scantrans(SDL_SCANCODE_k) = scK
scantrans(SDL_SCANCODE_l) = scL
scantrans(SDL_SCANCODE_m) = scM
scantrans(SDL_SCANCODE_n) = scN
scantrans(SDL_SCANCODE_o) = scO
scantrans(SDL_SCANCODE_p) = scP
scantrans(SDL_SCANCODE_q) = scQ
scantrans(SDL_SCANCODE_r) = scR
scantrans(SDL_SCANCODE_s) = scS
scantrans(SDL_SCANCODE_t) = scT
scantrans(SDL_SCANCODE_u) = scU
scantrans(SDL_SCANCODE_v) = scV
scantrans(SDL_SCANCODE_w) = scW
scantrans(SDL_SCANCODE_x) = scX
scantrans(SDL_SCANCODE_y) = scY
scantrans(SDL_SCANCODE_z) = scZ
scantrans(SDL_SCANCODE_DELETE) = scDelete
scantrans(SDL_SCANCODE_KP_0) = scNumpad0
scantrans(SDL_SCANCODE_KP_1) = scNumpad1
scantrans(SDL_SCANCODE_KP_2) = scNumpad2
scantrans(SDL_SCANCODE_KP_3) = scNumpad3
scantrans(SDL_SCANCODE_KP_4) = scNumpad4
scantrans(SDL_SCANCODE_KP_5) = scNumpad5
scantrans(SDL_SCANCODE_KP_6) = scNumpad6
scantrans(SDL_SCANCODE_KP_7) = scNumpad7
scantrans(SDL_SCANCODE_KP_8) = scNumpad8
scantrans(SDL_SCANCODE_KP_9) = scNumpad9
scantrans(SDL_SCANCODE_KP_PERIOD) = scNumpadPeriod
scantrans(SDL_SCANCODE_KP_DIVIDE) = scNumpadSlash
scantrans(SDL_SCANCODE_KP_MULTIPLY) = scNumpadAsterisk
scantrans(SDL_SCANCODE_KP_MINUS) = scNumpadMinus
scantrans(SDL_SCANCODE_KP_PLUS) = scNumpadPlus
scantrans(SDL_SCANCODE_KP_ENTER) = scNumpadEnter
scantrans(SDL_SCANCODE_KP_EQUALS) = scEquals
scantrans(SDL_SCANCODE_UP) = scUp
scantrans(SDL_SCANCODE_DOWN) = scDown
scantrans(SDL_SCANCODE_RIGHT) = scRight
scantrans(SDL_SCANCODE_LEFT) = scLeft
scantrans(SDL_SCANCODE_INSERT) = scInsert
scantrans(SDL_SCANCODE_HOME) = scHome
scantrans(SDL_SCANCODE_END) = scEnd
scantrans(SDL_SCANCODE_PAGEUP) = scPageup
scantrans(SDL_SCANCODE_PAGEDOWN) = scPagedown
scantrans(SDL_SCANCODE_F1) = scF1
scantrans(SDL_SCANCODE_F2) = scF2
scantrans(SDL_SCANCODE_F3) = scF3
scantrans(SDL_SCANCODE_F4) = scF4
scantrans(SDL_SCANCODE_F5) = scF5
scantrans(SDL_SCANCODE_F6) = scF6
scantrans(SDL_SCANCODE_F7) = scF7
scantrans(SDL_SCANCODE_F8) = scF8
scantrans(SDL_SCANCODE_F9) = scF9
scantrans(SDL_SCANCODE_F10) = scF10
scantrans(SDL_SCANCODE_F11) = scF11
scantrans(SDL_SCANCODE_F12) = scF12
scantrans(SDL_SCANCODE_F13) = scF13
scantrans(SDL_SCANCODE_F14) = scF14
scantrans(SDL_SCANCODE_F15) = scF15
' scantrans(SDL_SCANCODE_NUMLOCK) = scNumlock
scantrans(SDL_SCANCODE_CAPSLOCK) = scCapslock
' scantrans(SDL_SCANCODE_SCROLLOCK) = scScrollLock
scantrans(SDL_SCANCODE_RSHIFT) = scRightShift
scantrans(SDL_SCANCODE_LSHIFT) = scLeftShift
scantrans(SDL_SCANCODE_RCTRL) = scRightCtrl
scantrans(SDL_SCANCODE_LCTRL) = scLeftCtrl
scantrans(SDL_SCANCODE_RALT) = scRightAlt
scantrans(SDL_SCANCODE_LALT) = scLeftAlt
scantrans(SDL_SCANCODE_RGUI) = scRightMeta
scantrans(SDL_SCANCODE_LGUI) = scLeftMeta
scantrans(SDL_SCANCODE_MODE) = scRightAlt   'Possibly (probably not) Alt Gr? So treat it as alt
scantrans(SDL_SCANCODE_HELP) = 0
scantrans(SDL_SCANCODE_PRINTSCREEN) = scPrintScreen
scantrans(SDL_SCANCODE_SYSREQ) = scPrintScreen
scantrans(SDL_SCANCODE_PAUSE) = scPause
scantrans(SDL_SCANCODE_MENU) = scContext
scantrans(SDL_SCANCODE_APPLICATION) = scContext
scantrans(SDL_SCANCODE_POWER) = 0
scantrans(SDL_SCANCODE_UNDO) = 0
EXTERN "C"


PRIVATE SUB log_error(failed_call as zstring ptr, funcname as zstring ptr)
  debugc errError, *funcname & " " & *failed_call & ": " & *SDL_GetError()
END SUB

FUNCTION gfx_sdl2_init(byval terminate_signal_handler as sub cdecl (), byval windowicon as zstring ptr, byval info_buffer as zstring ptr, byval info_buffer_size as integer) as integer
/' Trying to load the resource as a SDL_Surface, Unfinished - the winapi has lost me
#ifdef __FB_WIN32__
  DIM as HBITMAP iconh
  DIM as BITMAP iconbmp
  iconh = cast(HBITMAP, LoadImage(NULL, windowicon, IMAGE_BITMAP, 0, 0, LR_CREATEDIBSECTION))
  GetObject(iconh, sizeof(iconbmp), @iconbmp);
#endif
'/
  'starting with svn revision 3964 custom actually supports capslock
  'as a toggle, so we no longer want to treat it like a regular key.
  'that is why these following lines are commented out

  ''disable capslock/numlock/pause special keypress behaviour
  'putenv("SDL_DISABLE_LOCK_KEYS=1") 'SDL 1.2.14
  'putenv("SDL_NO_LOCK_KEYS=1")      'SDL SVN between 1.2.13 and 1.2.14
  

#ifdef IS_CUSTOM
  'By default SDL prevents screensaver (new in SDL 1.2.10)
  putenv("SDL_VIDEO_ALLOW_SCREENSAVER=1")
#endif

  DIM ver as SDL_version
  SDL_GetVersion(@ver)
  *info_buffer = MID("SDL " & ver.major & "." & ver.minor & "." & ver.patch, 1, info_buffer_size)

  DIM video_already_init as bool = (SDL_WasInit(SDL_INIT_VIDEO) <> 0)

  IF SDL_Init(SDL_INIT_VIDEO OR SDL_INIT_JOYSTICK) THEN
    *info_buffer = MID("Can't start SDL (video): " & *SDL_GetError & LINE_END & *info_buffer, 1, info_buffer_size)
    RETURN 0
  END IF

  ' This enables key repeat both for text input and for keys. We only
  ' want it for text input (only with --native-keybd), and otherwise filter out
  ' repeat keypresses.
  ' However, we still get key repeats, apparently from Windows, even if SDL
  ' keyrepeat is disabled (see SDL_KEYDOWN handling).
'  SDL_EnableKeyRepeat(400, 50)

  *info_buffer = *info_buffer & " (" & SDL_NumJoysticks() & " joysticks) Driver:"
'  SDL_VideoDriverName(info_buffer + LEN(*info_buffer), info_buffer_size - LEN(*info_buffer))

  framesize.w = 320
  framesize.h = 200

  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest")

  sdlpalette = SDL_AllocPalette(256)
  CheckOK(sdlpalette = NULL, RETURN 0)

#IFDEF __FB_ANDROID__
  IF SDL_ANDROID_IsRunningOnConsole() THEN
    debuginfo "Running on a console, disable the virtual gamepad"
    internal_disable_virtual_gamepad
  ELSE
    debuginfo "Not running on a console, leave the virtual gamepad visible"
  END IF
#ENDIF

  RETURN recreate_window()
END FUNCTION

PRIVATE FUNCTION recreate_window(byval bitdepth as integer = 0) as bool
  IF mainrenderer THEN SDL_DestroyRenderer(mainrenderer)  'Also destroys textures
  mainrenderer = NULL
  maintexture = NULL
  IF mainwindow THEN SDL_DestroyWindow(mainwindow)
  mainwindow = NULL

  last_used_bitdepth = bitdepth
  DIM flags as Uint32 = 0
  IF resizable THEN flags = flags OR SDL_WINDOW_RESIZABLE
  IF windowedmode = NO THEN
    'flags = flags OR SDL_WINDOW_FULLSCREEN
    ' This means don't change the resolution, instead create a fullscreen window, like gfx_directx
    flags = flags OR SDL_WINDOW_FULLSCREEN_DESKTOP
  END IF

  DIM windowpos as integer
  IF running_as_slave = NO THEN   'Don't display the window straight on top of Custom's
    windowpos = SDL_WINDOWPOS_CENTERED
  ELSE
    windowpos = SDL_WINDOWPOS_UNDEFINED
  END IF

  'Start with initial zoom and repeatedly decrease it if it is too large
  '(This is necessary to run in fullscreen in OSX IIRC)
  DO
    WITH dest_rect
      .x = 0
      .y = 0
      .w = framesize.w * zoom
      .h = framesize.h * zoom
    END WITH
    debuginfo "setvideomode zoom=" & zoom & " w*h = " & dest_rect.w &"*"& dest_rect.h
    mainwindow = SDL_CreateWindow(remember_windowtitle, windowpos, windowpos, _
                                  dest_rect.w, dest_rect.h, flags)
    IF mainwindow = NULL THEN
      'This crude hack won't work for everyone if the SDL error messages are internationalised...
      IF zoom > 1 ANDALSO strstr(SDL_GetError(), "No video mode large enough") THEN
        debug "Failed to open display (windowed = " & windowedmode & ") (retrying with smaller zoom): " & *SDL_GetError
        zoom -= 1
        CONTINUE DO
      END IF
      debug "Failed to open display (windowed = " & windowedmode & "): " & *SDL_GetError
      RETURN 0
    END IF
    EXIT DO
  LOOP

  mainrenderer = SDL_CreateRenderer(mainwindow, -1, SDL_RENDERER_PRESENTVSYNC)
  ' Don't kill the program yet; we might be able to switch to a different backend
  CheckOK(mainrenderer = NULL, RETURN 0)

  SDL_RenderSetLogicalSize(mainrenderer, framesize.w, framesize.h)
  #IFDEF SDL_RenderSetIntegerScale
    'Whether to stick to integer scaling amounts. SDL 2.0.5+
    'SDL_RenderSetIntegerScale(mainrenderer, NO)
  #ENDIF

  IF recreate_screen_texture() = NO THEN RETURN 0

/'
  WITH *mainwindow->format
   debuginfo "gfx_sdl2: created mainwindow size=" & mainwindow->w & "*" & mainwindow->h _
             & " depth=" & .BitsPerPixel & " flags=0x" & HEX(mainwindow->flags) _
             & " R=0x" & hex(.Rmask) & " G=0x" & hex(.Gmask) & " B=0x" & hex(.Bmask)
   'FIXME: should handle the screen surface not being BGRA, or ask SDL for a surface in that encoding
  END WITH
'/

  update_mouse_visibility()
  RETURN 1
END FUNCTION

PRIVATE FUNCTION recreate_screen_texture() as bool
  IF maintexture THEN SDL_DestroyTexture(maintexture)
  maintexture = SDL_CreateTexture(mainrenderer, _
                               SDL_PIXELFORMAT_ARGB8888, _
                               SDL_TEXTUREACCESS_STREAMING, _
                               framesize.w, framesize.h)
  CheckOK(maintexture = NULL, RETURN NO)
  RETURN YES
END FUNCTION

PRIVATE SUB set_window_size(newsize as XYPair, newzoom as integer)
  framesize = newsize
  zoom = newzoom
  'TODO: this doesn't work if fullscreen
  SDL_SetWindowSize(mainwindow, zoom * framesize.w, zoom * framesize.h)
  recreate_screen_texture
END SUB

SUB gfx_sdl2_close()
  IF SDL_WasInit(SDL_INIT_VIDEO) THEN
    IF mainrenderer THEN SDL_DestroyRenderer(mainrenderer)  'Also destroys textures
    mainrenderer = NULL
    maintexture = NULL
    IF mainwindow THEN SDL_DestroyWindow(mainwindow)
    mainwindow = NULL
    IF screenbuffer THEN SDL_FreeSurface(screenbuffer)
    screenbuffer = NULL
    IF sdlpalette THEN SDL_FreePalette(sdlpalette)
    sdlpalette = NULL

    FOR i as integer = 0 TO small(SDL_NumJoysticks(), 8) - 1
      IF joystickhandles(i) <> NULL THEN SDL_JoystickClose(joystickhandles(i))
      joystickhandles(i) = NULL
    NEXT
    SDL_QuitSubSystem(SDL_INIT_VIDEO)
    IF SDL_WasInit(0) = 0 THEN
      SDL_Quit()
    END IF
  END IF
END SUB

FUNCTION gfx_sdl2_getversion() as integer
  RETURN 1
END FUNCTION

'Handles smoothing and changes to the frame size, then calls present_internal2
'to update the screen
PRIVATE FUNCTION present_internal(raw as any ptr, w as integer, h as integer, bitdepth as integer) as integer
  'debuginfo "gfx_sdl2_present_internal(w=" & w & ", h=" & h & ", bitdepth=" & bitdepth & ")"

  last_bitdepth = bitdepth

  DIM pitch as integer

  'variable resolution handling
  IF framesize.w <> w OR framesize.h <> h THEN
    'debuginfo "gfx_sdl2_present_internal: framesize changing from " & framesize.w & "*" & framesize.h & " to " & w & "*" & h
    set_window_size(XY(w, h), zoom)
  END IF

  pitch = w * IIF(bitdepth = 32, 4, 1)

  IF smooth THEN
    ' Intermediate step: do an enlarged blit to a surface and then do smoothing

    IF screenbuffer THEN
      IF (screenbuffer->w <> w * smooth_zoom OR _
          screenbuffer->h <> h * smooth_zoom OR _
          screenbuffer->format->BitsPerPixel <> bitdepth) THEN
        SDL_FreeSurface(screenbuffer)
        screenbuffer = NULL
      END IF
    END IF

    IF screenbuffer = NULL THEN
      IF bitdepth = 32 THEN
        'screenbuffer = SDL_CreateRGBSurfaceWithFormat(0, w * smooth_zoom, h * smooth_zoom, 32, SDL_PIXELFORMAT_ARGB8888)
        screenbuffer = SDL_CreateRGBSurface(0, w * smooth_zoom, h * smooth_zoom, bitdepth, &h00ff0000, &h0000ff00, &h000000ff, &hff000000)
      ELSE
        screenbuffer = SDL_CreateRGBSurface(0, w * smooth_zoom, h * smooth_zoom, bitdepth, 0,0,0,0)
      END IF
    END IF
    'screenbuffer = SDL_CreateRGBSurfaceFrom(raw, w, h, 8, w, 0,0,0,0)
    IF screenbuffer = NULL THEN
      debugc errDie, "present_internal: Failed to allocate page wrapping surface, " & *SDL_GetError()
    END IF

    IF bitdepth = 8 THEN
      smoothzoomblit_8_to_8bit(raw, screenbuffer->pixels, w, h, screenbuffer->pitch, smooth_zoom, smooth)
    ELSE
      '32 bit surface
      'smoothzoomblit takes the pitch in pixels, not bytes!
      smoothzoomblit_32_to_32bit(cast(RGBcolor ptr, raw), cast(uint32 ptr, screenbuffer->pixels), w, h, screenbuffer->pitch \ 4, smooth_zoom, smooth)
    END IF

    raw = screenbuffer->pixels
    pitch = screenbuffer->pitch

  ELSEIF bitdepth = 8 THEN
    'Need to make a copy of the input, in case gfx_setpal is called

    IF screenbuffer = NULL THEN
      screenbuffer = SDL_CreateRGBSurface(0, w * smooth_zoom, h * smooth_zoom, bitdepth, 0,0,0,0)
    END IF

    'Copy over
    'smoothzoomblit_8_to_8bit(raw, screenbuffer->pixels, w, h, screenbuffer->pitch, 1, smooth)
    SDL_ConvertPixels(w, h, SDL_PIXELFORMAT_INDEX8, raw, pitch, SDL_PIXELFORMAT_INDEX8, screenbuffer->pixels, screenbuffer->pitch)

  ELSE
    ' Can copy directly to maintexture
  END IF

  RETURN present_internal2(screenbuffer, raw, pitch, bitdepth)
END FUNCTION

'Updates the screen. Assumes all size changes have been handled.
'If bitdepth=8 then srcsurf is used, otherwise raw is used, and is a block of
'pixels in SDL_PIXELFORMAT_ARGB8888 with the given pitch.
'The surface or block of pixels must be the same size as maintexture.
PRIVATE FUNCTION present_internal2(srcsurf as SDL_Surface ptr, raw as any ptr, pitch as integer, bitdepth as integer) as bool
  DIM ret as bool = YES

  DIM as integer texw, texh
  DIM texpixels as any ptr
  DIM texpitch as integer
  SDL_QueryTexture(maintexture, NULL, NULL, @texw, @texh)
  CheckOK(SDL_LockTexture(maintexture, NULL, @texpixels, @texpitch), RETURN NO)

  IF bitdepth = 8 THEN
    'SDL2 has two different ways to specify a pixel format:
    ' struct SDL_PixelFormat - the struct used by SDL_Surfaces. Very flexible, includes an SDL_Palette*
    ' enum SDL_PixelFormatEnum - available texture formats.
    'Conversion functions:
    ' SDL_ConvertPixels - convert raw pixel buffer from one SDL_PixelFormatEnum to another
    ' SDL_ConvertSurface - copy of a Surface converted to a SDL_PixelFormat
    ' SDL_ConvertSurfaceFormat - copy of a Surface converted to a SDL_PixelFormatEnum
    ' SDL_BlitSurface - between Surfaces. Does a conversion
    'Also relevant:
    ' SDL_AllocFormat - Get a SDL_PixelFormat from a SDL_PixelFormatEnum
    ' SDL_SetSurfacePalette - Modify's a Surface's SDL_PixelFormat
    ' SDL_CreateRGBSurfaceFrom - A Surface wrapping an existing pixel buffer, defined by masks
    ' SDL_CreateRGBSurfaceWithFormatFrom - A Surface wrapping an existing pixel buffer, defined by SDL_PixelFormatEnum.

    'So can't use SDL_ConvertPixels as it doesn't support a palette.

    CheckOK(SDL_SetSurfacePalette(srcsurf, sdlpalette))

    DIM destsurf as SDL_Surface ptr
    'Avoid SDL_CreateRGBSurfaceWithFormatFrom because it's SDL 2.0.5+
    'destsurf = SDL_CreateRGBSurfaceWithFormatFrom(texpixels, texw, texh, 32, texpitch, SDL_PIXELFORMAT_ARGB8888)
    destsurf = SDL_CreateRGBSurfaceFrom(texpixels, texw, texh, 32, texpitch, &h00ff0000, &h0000ff00, &h000000ff, &hff000000)
    CheckOK(destsurf = NULL)

    CheckOK(SDL_BlitSurface(srcsurf, NULL, destsurf, NULL), ret = NO)

    SDL_FreeSurface(destsurf)
  ELSE

    'Formats are the same, so this will be a simple copy
    CheckOK(SDL_ConvertPixels(texw, texh, SDL_PIXELFORMAT_ARGB8888, raw, pitch, SDL_PIXELFORMAT_ARGB8888, texpixels, texpitch), ret = NO)
    'CheckOK(SDL_UpdateTexture(maintexture, NULL, raw, pitch), ret = NO)
  END IF

  SDL_UnlockTexture(maintexture)

  'SDL_RenderClear(mainrenderer)
  CheckOK(SDL_RenderCopy(mainrenderer, maintexture, NULL, NULL), ret = NO)
  SDL_RenderPresent(mainrenderer)

  update_state()

  RETURN ret
END FUNCTION

'Copies an RGBColor[256] array to sdlpalette
PRIVATE SUB set_palette(pal as RGBColor ptr)
  DIM cols(255) as SDL_Color
  FOR i as integer = 0 TO 255
    cols(i).r = pal[i].r
    cols(i).g = pal[i].g
    cols(i).b = pal[i].b
  NEXT
  SDL_SetPaletteColors(sdlpalette, @cols(0), 0, 256)
END SUB

SUB gfx_sdl2_setpal(byval pal as RGBcolor ptr)
  IF last_bitdepth = 8 THEN
    set_palette pal
    present_internal2(screenbuffer, NULL, 0, last_bitdepth)
  ELSE
    debuginfo "gfx_sdl2_setpal called after a 32bit present"
  END IF
  update_state()
END SUB

FUNCTION gfx_sdl2_present(byval surfaceIn as Surface ptr, byval pal as RGBPalette ptr) as integer
  WITH *surfaceIn
    IF .format = SF_8bit AND pal <> NULL THEN
      set_palette @pal->col(0)
    END IF
    DIM ret as integer
    ret = present_internal(.pColorData, .width, .height, IIF(.format = SF_8bit, 8, 32))
    update_state()
    RETURN ret
  END WITH
END FUNCTION

FUNCTION gfx_sdl2_screenshot(byval fname as zstring ptr) as integer
  gfx_sdl2_screenshot = 0
END FUNCTION

SUB gfx_sdl2_setwindowed(byval towindowed as bool)
  DIM flags as int32 = 0
  IF towindowed = NO THEN flags = SDL_WINDOW_FULLSCREEN_DESKTOP
  IF SDL_SetWindowFullscreen(mainwindow, flags) THEN
    debugc errPrompt, "Could not toggle fullscreen mode: " & *SDL_GetError()
    EXIT SUB
  END IF
  windowedmode = towindowed
  'TODO: call gfx_sdl2_set_resizable here, since that doesn't work on fullscreen windows?
END SUB

SUB gfx_sdl2_windowtitle(byval title as zstring ptr)
  IF SDL_WasInit(SDL_INIT_VIDEO) then
    SDL_SetWindowTitle(mainwindow, title)
  END IF
  remember_windowtitle = *title
END SUB

FUNCTION gfx_sdl2_getwindowstate() as WindowState ptr
  STATIC state as WindowState
  state.structsize = WINDOWSTATE_SZ
  DIM flags as uint32 = SDL_GetWindowFlags(mainwindow)
  'TODO: what about SDL_WINDOW_SHOWN/SDL_WINDOW_HIDDEN?
  state.focused = (flags AND SDL_WINDOW_INPUT_FOCUS) <> 0
  state.minimised = (flags AND SDL_WINDOW_MINIMIZED) = 0
  state.fullscreen = (flags AND (SDL_WINDOW_FULLSCREEN OR SDL_WINDOW_FULLSCREEN_DESKTOP)) <> 0
  state.mouse_over = (flags AND SDL_WINDOW_MOUSE_FOCUS) <> 0
  RETURN @state
END FUNCTION

SUB gfx_sdl2_get_screen_size(wide as integer ptr, high as integer ptr)
  'Query the first display.
  'SDL_GetDisplayUsableBounds excludes area for taskbar, OSX menubar, dock, etc.,
  'but was only added in SDL 2.0.5 (Oct 2016), and isn't even in FB's headers
  DIM rect as SDL_Rect
#IFDEF SDL_GetDisplayUsableBounds
  IF SDL_GetDisplayUsableBounds(0, @rect) THEN
#ELSE
  IF SDL_GetDisplayBounds(0, @rect) THEN
#ENDIF
    debug "SDL_GetDisplayUsableBounds: " & *SDL_GetError()
    *wide = 0
    *high = 0
  ELSE
    *wide = rect.w
    *high = rect.h
  END IF
END SUB

FUNCTION gfx_sdl2_supports_variable_resolution() as bool
  'Safe even in fullscreen, I think
  RETURN YES
END FUNCTION

FUNCTION gfx_sdl2_vsync_supported() as bool
  #IFDEF __FB_DARWIN__
    ' OSX always has vsync, and drawing the screen will block until vsync, so this needs
    ' special treatment (as opposed to most other WMs which also do vsync compositing)
    RETURN YES
  #ELSE
    RETURN NO
  #ENDIF
END FUNCTION

FUNCTION gfx_sdl2_set_resizable(byval enable as bool, min_width as integer, min_height as integer) as bool
  resizable = enable
  IF mainwindow = NULL THEN RETURN resizable

  'Note: Can't change resizability of a fullscreen window
  'Argh, SDL_SetWindowResizable was only added in SDL 2.0.5 (Oct 2016)
  #IFDEF SDL_SetWindowResizable
    CheckOK(SDL_SetWindowResizable(mainwindow, resizable), RETURN NO)
  #ELSE
    recreate_window()
  #ENDIF
  SDL_SetWindowMinimumSize(mainwindow, zoom * min_width, zoom * min_height)
  RETURN resizable
END FUNCTION

FUNCTION gfx_sdl2_get_resize(byref ret as XYPair) as bool
  IF resize_requested THEN
    ret = resize_request
    resize_requested = NO
    RETURN YES
  END IF
  RETURN NO
END FUNCTION

'Interesting behaviour: under X11+KDE, if the window doesn't go over the screen edges and is resized
'larger (SDL_SetVideoMode), then it will automatically be moved to fit onscreen (if you DON'T ask for recenter).
SUB gfx_sdl2_recenter_window_hint()
  'Takes effect at the next SDL_SetVideoMode call, and it's then removed
  debuginfo "recenter_window_hint()"
  putenv("SDL_VIDEO_CENTERED=1")
  '(Note this is overridden by SDL_VIDEO_WINDOW_POS, so this function may do nothing when running as slave)
END SUB

SUB gfx_sdl2_set_zoom(byval value as integer)
  IF value >= 1 AND value <= 16 AND value <> zoom THEN
    zoom = value
    smooth_zoom = value
    gfx_sdl2_recenter_window_hint()  'Recenter because the window might go off the screen edge.
    IF mainwindow THEN
      set_window_size(framesize, zoom)
    END IF

    'Update the clip rectangle
    'It would probably be easier to just store the non-zoomed clipped rect (mxmin, etc)
    WITH remember_mouserect
      IF .p1.x <> -1 THEN
        internal_set_mouserect .p1.x, .p2.x, .p1.y, .p2.y
      ELSEIF forced_mouse_clipping THEN
        internal_set_mouserect 0, framesize.w - 1, 0, framesize.h - 1
      END IF
    END WITH
  END IF
END SUB

FUNCTION gfx_sdl2_setoption(byval opt as zstring ptr, byval arg as zstring ptr) as integer
  DIM ret as integer = 0
  DIM value as integer = str2int(*arg, -1)
  IF *opt = "zoom" or *opt = "z" THEN
    gfx_sdl2_set_zoom(value)
    ret = 1
  ELSEIF *opt = "smooth" OR *opt = "s" THEN
    IF value = 1 OR value = -1 THEN  'arg optional (-1)
      smooth = 1
    ELSE
      smooth = 0
    END IF
    ret = 1
  ELSEIF *opt = "input-debug" THEN
    debugging_io = YES
    ret = 1
  END IF
  'globble numerical args even if invalid
  IF ret = 1 AND is_int(*arg) THEN ret = 2
  RETURN ret
END FUNCTION

FUNCTION gfx_sdl2_describe_options() as zstring ptr
  return @"-z -zoom [1...16]   Scale screen to 1,2, ... up to 16x normal size (2x default)" LINE_END _
          "-s -smooth          Enable smoothing filter for zoom modes (default off)" LINE_END _
          "-input-debug        Print extra debug info to c/g_debug.txt related to keyboard, mouse, etc. input"
END FUNCTION

FUNCTION gfx_sdl2_get_safe_zone_margin() as single
 RETURN safe_zone_margin
END FUNCTION

SUB gfx_sdl2_set_safe_zone_margin(margin as single)
 safe_zone_margin = margin
 recreate_window(last_used_bitdepth)
END SUB

FUNCTION gfx_sdl2_supports_safe_zone_margin() as bool
#IFDEF __FB_ANDROID__
 RETURN YES
#ELSE
 RETURN NO
#ENDIF
END FUNCTION

SUB gfx_sdl2_ouya_purchase_request(dev_id as string, identifier as string, key_der as string)
#IFDEF __FB_ANDROID__
 SDL_ANDROID_SetOUYADeveloperId(dev_id)
 SDL_ANDROID_OUYAPurchaseRequest(identifier, key_der, LEN(key_der))
#ENDIF
END SUB

FUNCTION gfx_sdl2_ouya_purchase_is_ready() as bool
#IFDEF __FB_ANDROID__
 RETURN SDL_ANDROID_OUYAPurchaseIsReady() <> 0
#ENDIF
 RETURN YES
END FUNCTION

FUNCTION gfx_sdl2_ouya_purchase_succeeded() as bool
#IFDEF __FB_ANDROID__
 RETURN SDL_ANDROID_OUYAPurchaseSucceeded() <> 0
#ENDIF
 RETURN NO
END FUNCTION

SUB gfx_sdl2_ouya_receipts_request(dev_id as string, key_der as string)
debuginfo "gfx_sdl2_ouya_receipts_request"
#IFDEF __FB_ANDROID__
 SDL_ANDROID_SetOUYADeveloperId(dev_id)
 SDL_ANDROID_OUYAReceiptsRequest(key_der, LEN(key_der))
#ENDIF
END SUB

FUNCTION gfx_sdl2_ouya_receipts_are_ready() as bool
#IFDEF __FB_ANDROID__
 RETURN SDL_ANDROID_OUYAReceiptsAreReady() <> 0
#ENDIF
 RETURN YES
END FUNCTION

FUNCTION gfx_sdl2_ouya_receipts_result() as string
#IFDEF __FB_ANDROID__
 DIM zresult as zstring ptr
 zresult = SDL_ANDROID_OUYAReceiptsResult()
 DIM result as string = *zresult
 RETURN result
#ENDIF
 RETURN ""
END FUNCTION

SUB io_sdl2_init
  'nothing needed at the moment...
END SUB

PRIVATE SUB keycombos_logic(evnt as SDL_Event)
  'Check for platform-dependent key combinations

  IF evnt.key.keysym.mod_ AND KMOD_ALT THEN
    IF evnt.key.keysym.sym = SDLK_RETURN THEN  'alt-enter (not processed normally when using SDL)
      gfx_sdl2_setwindowed(windowedmode XOR YES)
      post_event(eventFullscreened, windowedmode = NO)
    END IF
    IF evnt.key.keysym.sym = SDLK_F4 THEN  'alt-F4
      post_terminate_signal
    END IF
  END IF

#IFDEF __FB_DARWIN__
  'We have to handle menu item key combinations here: SDLMain.m only handles the case that you actually click on them
  '(many of those actually generate an SDL keypress event, which is then handled here)

  IF evnt.key.keysym.mod_ AND KMOD_META THEN  'Command key
    IF evnt.key.keysym.sym = SDLK_m THEN
      sdlCocoaMinimise()
    END IF
    IF evnt.key.keysym.sym = SDLK_h THEN
      IF evnt.key.keysym.mod_ AND KMOD_SHIFT THEN
        sdlCocoaHideOthers()  'Cmd-Shift-H
      ELSE
        sdlCocoaHide()  'Cmd-H
      END IF
    END IF
    IF evnt.key.keysym.sym = SDLK_q THEN
      post_terminate_signal
    END IF
    IF evnt.key.keysym.sym = SDLK_f THEN
      gfx_sdl2_setwindowed(windowedmode XOR YES)
      post_event(eventFullscreened, windowedmode = NO)
      ' Includes Cmd+F to fullscreen
    END IF
    'SDL doesn't actually seem to send SDLK_QUESTION...
    IF evnt.key.keysym.sym = SDLK_SLASH AND evnt.key.keysym.mod_ AND KMOD_SHIFT THEN
      keybdstate(scF1) = 2
    END IF
    FOR i as integer = 1 TO 4
      IF evnt.key.keysym.sym = SDLK_0 + i THEN
        gfx_sdl2_set_zoom(i)
      END IF
    NEXT
  END IF
#ENDIF

END SUB

SUB gfx_sdl2_process_events()
  'I assume this uses SDL_PeepEvents instead of SDL_PollEvent because the latter calls SDL_PumpEvents
  DIM evnt as SDL_Event
  WHILE SDL_PeepEvents(@evnt, 1, SDL_GETEVENT, SDL_FIRSTEVENT, SDL_LASTEVENT)
    SELECT CASE evnt.type
      CASE SDL_QUIT_
        IF debugging_io THEN
          debuginfo "SDL_QUIT"
        END IF
        post_terminate_signal
      CASE SDL_KEYDOWN
        keycombos_logic(evnt)
        DIM as integer key = scantrans(evnt.key.keysym.scancode)
        IF debugging_io THEN
          debuginfo "SDL_KEYDOWN scan=" & evnt.key.keysym.scancode & " key=" & evnt.key.keysym.sym & " -> ohr=" & key & " (" & scancodename(key) & ") prev_keystate=" & keybdstate(key)
        END IF
        IF key ANDALSO evnt.key.repeat = 0 THEN
          'Filter out key repeats (key already down, or we just saw a keyup):
          'On Windows (XP at least) we get key repeats even if we don't enable
          'SDL's key repeats, but with a much longer initial delay than the SDL ones.
          'SDL repeats keys by sending extra KEYDOWNs, while Windows sends keyup-keydown
          'pairs. Unfortunately for some reason we don't always get the keydown until
          'the next tick, so that it doesn't get filtered out.
          'gfx_fb suffers the same problem.
          IF keybdstate(key) = 0 THEN keybdstate(key) OR= 2  'new keypress
          keybdstate(key) OR= 1  'key down
        END IF
      CASE SDL_KEYUP
        DIM as integer key = scantrans(evnt.key.keysym.scancode)
        IF debugging_io THEN
          debuginfo "SDY_KEYUP scan=" & evnt.key.keysym.scancode & " key=" & evnt.key.keysym.sym & " -> ohr=" & key & " (" & scancodename(key) & ") prev_keystate=" & keybdstate(key)
        END IF
        'Clear 2nd bit (new keypress) and turn on 3rd bit (keyup)
        IF key THEN keybdstate(key) = (keybdstate(key) AND 2) OR 4
      CASE SDL_TEXTINPUT
        input_buffer += evnt.text.text  'UTF8

      CASE SDL_MOUSEBUTTONDOWN
        'note SDL_GetMouseState is still used, while SDL_GetKeyState isn't
        'Interestingly, although (on Linux/X11) SDL doesn't report mouse motion events
        'if the window isn't focused, it does report mouse wheel button events
        '(other buttons focus the window).
        WITH evnt.button
          mouseclicks OR= SDL_BUTTON(.button)
          IF debugging_io THEN
            debuginfo "SDL_MOUSEBUTTONDOWN mouse " & .which & " button " & .button & " at " & .x & "," & .y
          END IF
        END WITH
      CASE SDL_MOUSEBUTTONUP
        WITH evnt.button
          IF debugging_io THEN
            debuginfo "SDL_MOUSEBUTTONUP   mouse " & .which & " button " & .button & " at " & .x & "," & .y
          END IF
        END WITH

      CASE SDL_MOUSEWHEEL
        IF debugging_io THEN
          debuginfo "SDL_MOUSEWHEEL " & evnt.wheel.x & "," & evnt.wheel.y & " mouse=" & evnt.wheel.which
          'SDL 2.0.4+:  & " dir=" & evnt.wheel.direction
        END IF
        mousewheel += evnt.wheel.y  ' * 120

      CASE SDL_WINDOWEVENT
        IF debugging_io THEN
          debuginfo "SDL_WINDOWEVENT event=" & evnt.window.event
        END IF
        IF evnt.window.event = SDL_WINDOWEVENT_ENTER THEN
          'Gained mouse focus
          /'
          IF evnt.active.gain = 0 THEN
            SDL_ShowCursor(1)
          ELSE
            update_mouse_visibility()
          END IF
          '/
        END IF

        IF evnt.window.event = SDL_WINDOWEVENT_RESIZED THEN
          'This event is delivered when the window size is changed by the user/WM
          'rather than because we changed it.
          IF debugging_io THEN
            debuginfo "SDL_WINDOWEVENT_RESIZED: w=" & evnt.window.data1 & " h=" & evnt.window.data2
          END IF
          IF resizable THEN
            'Round upwards
            resize_request.w = (evnt.window.data1 + zoom - 1) \ zoom
            resize_request.h = (evnt.window.data2 + zoom - 1) \ zoom
            IF framesize.w <> resize_request.w OR framesize.h <> resize_request.h THEN
              'On Windows (XP), changing the window size causes an SDL_VIDEORESIZE event
              'to be sent with the size you just set... this would produce annoying overlay
              'messages in screen_size_update() if we don't filter them out.
              resize_requested = YES
            END IF
            'Nothing happens until the engine calls gfx_get_resize,
            'changes its internal window size (windowsize) as a result,
            'and starts pushing Frames with the new size to gfx_present.

            'Calling SDL_SetVideoMode changes the window size.  Unfortunately it's not possible
            'to reliably override a user resize event with a different window size, at least with
            'X11+KDE, because the window size isn't changed by SDL_SetVideoMode while the user is
            'still dragging the window, and as far as I can tell there is no way to tell what the
            'actual window size is, or whether the user still has the mouse button down while
            'resizing (it isn't reported); usually they do hold it down until after they've
            'finished moving their mouse.  One possibility would be to hook into X11, or to do
            'some delayed SDL_SetVideoMode calls.
          END IF
        END IF
    END SELECT
  WEND
END SUB

'may only be called from the main thread
PRIVATE SUB update_state()
  SDL_PumpEvents()
  update_mouse()
  gfx_sdl2_process_events()
END SUB

SUB io_sdl2_pollkeyevents()
  'might need to redraw the screen if exposed
/'
  IF SDL_Flip(mainwindow) THEN
    debug "pollkeyevents: SDL_Flip failed: " & *SDL_GetError
  END IF
'/
  update_state()
END SUB

SUB io_sdl2_waitprocessing()
  update_state()
END SUB

SUB io_sdl2_keybits (byval keybdarray as integer ptr)
  'keybdarray bits:
  ' bit 0 - key down
  ' bit 1 - new keypress event
  'keybdstate bits:
  ' bit 0 - key down
  ' bit 1 - new keypress event
  ' bit 2 - keyup event

  DIM msg as string
  FOR a as integer = 0 TO &h7f
    keybdstate(a) = keybdstate(a) and 3  'Clear key-up bit
    keybdarray[a] = keybdstate(a)
    IF debugging_io ANDALSO keybdarray[a] THEN
      msg &= "  key[" & a & "](" & scancodename(a) & ")=" & keybdarray[a]
    END IF
    keybdstate(a) = keybdstate(a) and 1  'Clear new-keypress bit
  NEXT
  IF LEN(msg) THEN debuginfo "io_sdl2_keybits returning:" & msg

  keybdarray[scShift] = keybdarray[scLeftShift] OR keybdarray[scRightShift]
  keybdarray[scUnfilteredAlt] = keybdarray[scLeftAlt] OR keybdarray[scRightAlt]
  keybdarray[scCtrl] = keybdarray[scLeftCtrl] OR keybdarray[scRightCtrl]
END SUB

SUB io_sdl2_updatekeys(byval keybd as integer ptr)
  'supports io_keybits instead
END SUB

'Enabling unicode will cause combining keys to go dead on X11 (on non-US
'layouts that have them). This usually means certain punctuation keys such as '
'On both X11 and Windows, disabling unicode input means SDL_KEYDOWN events
'don't report the character value (.unicode_).
SUB io_sdl2_enable_textinput (byval enable as integer)
END SUB

SUB io_sdl2_textinput (byval buf as wstring ptr, byval bufsize as integer)
  DIM out as wstring ptr = utf8_decode(@input_buffer[0])
  IF out = NULL THEN
    debug "io_sdl2_textinput: utf8_decode failed"
  ELSE
    *buf = LEFT(*out, bufsize)
    DEALLOCATE out
  END IF
  input_buffer = ""
END SUB

SUB io_sdl2_show_virtual_keyboard()
 'Does nothing on platforms that have real keyboards
#IFDEF __FB_ANDROID__
 if not virtual_keyboard_shown then
  SDL_ANDROID_ToggleScreenKeyboardWithoutTextInput()
  virtual_keyboard_shown = YES
 end if
#ENDIF
END SUB

SUB io_sdl2_hide_virtual_keyboard()
 'Does nothing on platforms that have real keyboards
#IFDEF __FB_ANDROID__
 if virtual_keyboard_shown then
  SDL_ANDROID_ToggleScreenKeyboardWithoutTextInput()
  virtual_keyboard_shown = NO
 end if
#ENDIF
END SUB

SUB io_sdl2_show_virtual_gamepad()
 'Does nothing on other platforms
#IFDEF __FB_ANDROID__
 if allow_virtual_gamepad then
  SDL_ANDROID_SetScreenKeyboardShown(YES)
 else
  debuginfo "io_sdl2_show_virtual_gamepad was supressed because of a previous call to internal_disable_virtual_gamepad"
 end if
#ENDIF
END SUB

SUB io_sdl2_hide_virtual_gamepad()
 'Does nothing on other platforms
#IFDEF __FB_ANDROID__
 SDL_ANDROID_SetScreenKeyboardShown(NO)
#ENDIF
END SUB

PRIVATE SUB internal_disable_virtual_gamepad()
 'Does nothing on other platforms
#IFDEF __FB_ANDROID__
 io_sdl2_hide_virtual_gamepad
 allow_virtual_gamepad = NO
#ENDIF
END SUB

SUB io_sdl2_remap_android_gamepad(byval player as integer, gp as GamePadMap)
'Does nothing on non-android
#IFDEF __FB_ANDROID__
 SELECT CASE player
  CASE 0
   SDL_ANDROID_set_java_gamepad_keymap ( _
    scOHR2SDL(gp.A, SDL_SCANCODE_RETURN), _
    scOHR2SDL(gp.B, SDL_SCANCODE_ESCAPE), _
    0, _
    scOHR2SDL(gp.X, SDL_SCANCODE_ESCAPE), _
    scOHR2SDL(gp.Y, SDL_SCANCODE_ESCAPE), _
    0, _
    scOHR2SDL(gp.L1, SDL_SCANCODE_PAGEUP), _
    scOHR2SDL(gp.R1, SDL_SCANCODE_PAGEDOWN), _
    scOHR2SDL(gp.L2, SDL_SCANCODE_HOME), _
    scOHR2SDL(gp.R2, SDL_SCANCODE_END), _
    0, 0)
  CASE 1 TO 3
    SDL_ANDROID_set_ouya_gamepad_keymap ( _
    player, _
    scOHR2SDL(gp.Ud, SDL_SCANCODE_UP), _
    scOHR2SDL(gp.Rd, SDL_SCANCODE_RIGHT), _
    scOHR2SDL(gp.Dd, SDL_SCANCODE_DOWN), _
    scOHR2SDL(gp.Ld, SDL_SCANCODE_LEFT), _
    scOHR2SDL(gp.A, SDL_SCANCODE_RETURN), _
    scOHR2SDL(gp.B, SDL_SCANCODE_ESCAPE), _
    scOHR2SDL(gp.X, SDL_SCANCODE_ESCAPE), _
    scOHR2SDL(gp.Y, SDL_SCANCODE_ESCAPE), _
    scOHR2SDL(gp.L1, SDL_SCANCODE_PAGEUP), _
    scOHR2SDL(gp.R1, SDL_SCANCODE_PAGEDOWN), _
    scOHR2SDL(gp.L2, SDL_SCANCODE_HOME), _
    scOHR2SDL(gp.R2, SDL_SCANCODE_END), _
    0, 0)
  CASE ELSE
   debug "WARNING: io_sdl2_remap_android_gamepad: invalid player number " & player
 END SELECT
#ENDIF
END SUB

SUB io_sdl2_remap_touchscreen_button(byval button_id as integer, byval ohr_scancode as integer)
'Pass a scancode of 0 to disabled/hide the button
'Does nothing on non-android
#IFDEF __FB_ANDROID__
 SDL_ANDROID_SetScreenKeyboardButtonDisable(button_id, (ohr_scancode = 0))
 SDL_ANDROID_SetScreenKeyboardButtonKey(button_id, scOHR2SDL(ohr_scancode, 0))
#ENDIF
END SUB

FUNCTION io_sdl2_running_on_console() as bool
#IFDEF __FB_ANDROID__
 RETURN SDL_ANDROID_IsRunningOnConsole()
#ENDIF
 RETURN NO
END FUNCTION

FUNCTION io_sdl2_running_on_ouya() as bool
#IFDEF __FB_ANDROID__
 RETURN SDL_ANDROID_IsRunningOnOUYA()
#ENDIF
 RETURN NO
END FUNCTION

PRIVATE SUB update_mouse_visibility()
  DIM vis as integer
  IF mouse_visibility = cursorDefault THEN
    IF windowedmode THEN vis = 1 ELSE vis = 0
  ELSEIF mouse_visibility = cursorVisible THEN
    vis = 1
  ELSE
    vis = 0
  END IF
  SDL_ShowCursor(vis)
#IFDEF __FB_DARWIN__
  'Force clipping in fullscreen, and undo when leaving, because you
  'can move the cursor to the screen edge, where it will be visible
  'regardless of whether SDL_ShowCursor is used.
  set_forced_mouse_clipping (windowedmode = NO AND vis = 0)
#ENDIF
END SUB

SUB io_sdl2_setmousevisibility(visibility as CursorVisibility)
  mouse_visibility = visibility
  update_mouse_visibility()
END SUB

'Change from SDL to OHR mouse button numbering (swap middle and right)
PRIVATE FUNCTION fix_buttons(byval buttons as integer) as integer
  DIM mbuttons as integer = 0
  IF SDL_BUTTON(SDL_BUTTON_LEFT) AND buttons THEN mbuttons = mbuttons OR mouseLeft
  IF SDL_BUTTON(SDL_BUTTON_RIGHT) AND buttons THEN mbuttons = mbuttons OR mouseRight
  IF SDL_BUTTON(SDL_BUTTON_MIDDLE) AND buttons THEN mbuttons = mbuttons OR mouseMiddle
  RETURN mbuttons
END FUNCTION

' Returns currently down mouse buttons, in SDL order, not OHR order
PRIVATE FUNCTION update_mouse() as integer
  DIM x as int32
  DIM y as int32
  DIM buttons as int32

  IF SDL_GetWindowFlags(mainwindow) AND SDL_WINDOW_MOUSE_FOCUS THEN
    IF mouseclipped THEN
      buttons = SDL_GetRelativeMouseState(@x, @y)
      'debuginfo "gfx_sdl2: relativemousestate " & x & " " & y
      privatemx = bound(privatemx + x, mxmin, mxmax)
      privatemy = bound(privatemy + y, mymin, mymax)
    ELSE
      buttons = SDL_GetMouseState(@x, @y)
      privatemx = x
      privatemy = y
    END IF
  END IF
  RETURN buttons
END FUNCTION

SUB io_sdl2_mousebits (byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer, byref mclicks as integer)
  DIM buttons as integer
  buttons = update_mouse()
  mx = privatemx \ zoom
  my = privatemy \ zoom

  mwheel = mousewheel
  mclicks = fix_buttons(mouseclicks)
  mbuttons = fix_buttons(buttons or mouseclicks)
  mouseclicks = 0
END SUB

SUB io_sdl2_getmouse(byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer)
  'supports io_mousebits instead
END SUB

SUB io_sdl2_setmouse(byval x as integer, byval y as integer)
  IF mouseclipped THEN
    privatemx = x * zoom
    privatemy = y * zoom
  ELSE
    IF SDL_GetWindowFlags(mainwindow) AND SDL_WINDOW_MOUSE_FOCUS THEN
      SDL_WarpMouseInWindow mainwindow, x * zoom, y * zoom
      SDL_PumpEvents  'Needed for SDL_WarpMouse to work?
#IFDEF __FB_DARWIN__
      ' SDL Mac bug (SDL 1.2.14, OS 10.8.5): if the cursor is off the window
      ' when SDL_WarpMouse is called then the mouse gets moved onto the window,
      ' but SDL forgets to hide the cursor if it was previously requested, and further,
      ' SDL_ShowCursor(0) does nothing because SDL thinks it's already hidden.
      ' So call SDL_ShowCursor twice in a row as workaround.
      SDL_ShowCursor(1)
      update_mouse_visibility()
#ENDIF
    END IF
  END IF
END SUB

PRIVATE SUB internal_set_mouserect(byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)
  'In SDL 1.2 SDL_WM_GrabInput causes most WM key combinations to be blocked
  'Now in SDL 2, keyboard is not grabbed by default (see SDL_HINT_GRAB_KEYBOARD),
  'but I assume switching to relative mouse mode is effectively grabbing anyway.
  IF mouseclipped = NO AND (xmin >= 0) THEN
    'enter clipping mode
    mouseclipped = YES
    SDL_GetMouseState(@privatemx, @privatemy)
    SDL_SetRelativeMouseMode YES
  ELSEIF mouseclipped = YES AND (xmin = -1) THEN
    'exit clipping mode
    mouseclipped = NO
    SDL_SetRelativeMouseMode NO
    SDL_WarpMouseInWindow mainwindow, privatemx, privatemy
  END IF
  mxmin = xmin * zoom
  mxmax = xmax * zoom + zoom - 1
  mymin = ymin * zoom
  mymax = ymax * zoom + zoom - 1
END SUB

'This turns forced mouse clipping on or off
PRIVATE SUB set_forced_mouse_clipping(byval newvalue as bool)
  newvalue = (newvalue <> 0)
  IF newvalue <> forced_mouse_clipping THEN
    forced_mouse_clipping = newvalue
    IF forced_mouse_clipping THEN
      IF mouseclipped = NO THEN
        internal_set_mouserect 0, framesize.w - 1, 0, framesize.h - 1
      END IF
      'If already clipped: nothing to be done
    ELSE
      WITH remember_mouserect
        internal_set_mouserect .p1.x, .p2.x, .p1.y, .p2.y
      END WITH
    END IF
  END IF
END SUB

SUB io_sdl2_mouserect(byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)
  WITH remember_mouserect
    .p1.x = xmin
    .p1.y = ymin
    .p2.x = xmax
    .p2.y = ymax
  END WITH
  IF forced_mouse_clipping AND xmin = -1 THEN
    'Remember that we are now meant to be unclipped, but clip to the window
    internal_set_mouserect 0, framesize.w - 1, 0, framesize.h - 1
  ELSE
    internal_set_mouserect xmin, xmax, ymin, ymax
  END IF
END SUB

FUNCTION io_sdl2_readjoysane(byval joynum as integer, byref button as integer, byref x as integer, byref y as integer) as integer
  IF joynum < 0 OR SDL_NumJoysticks() < joynum + 1 THEN RETURN 0
  IF joystickhandles(joynum) = NULL THEN
    joystickhandles(joynum) = SDL_JoystickOpen(joynum)
    IF joystickhandles(joynum) = NULL THEN
      debug "Couldn't open joystick " & joynum & ": " & *SDL_GetError
      RETURN 0
    END IF
  END IF
  SDL_JoystickUpdate() 'should this be here? moved from io_sdl2_readjoy
  button = 0
  FOR i as integer = 0 TO SDL_JoystickNumButtons(joystickhandles(joynum)) - 1
    IF SDL_JoystickGetButton(joystickhandles(joynum), i) THEN button = button OR (1 SHL i)
  NEXT
  'SDL_JoystickGetAxis returns a value from -32768 to 32767
  x = SDL_JoystickGetAxis(joystickhandles(joynum), 0) / 32768.0 * 100
  y = SDL_JoystickGetAxis(joystickhandles(joynum), 1) / 32768.0 * 100
  IF debugging_io THEN
    debuginfo "gfx_sdl2: joysane: x=" & x & " y=" & y & " button=" & button
  END IF
  RETURN 1
END FUNCTION

PRIVATE FUNCTION scOHR2SDL(byval ohr_scancode as integer, byval default_sdl_scancode as integer=0) as integer
 'Convert an OHR scancode into an SDL scancode
 '(the reverse can be accomplished just by using the scantrans array)
 IF ohr_scancode = 0 THEN RETURN default_sdl_scancode
 FOR i as integer = 0 TO UBOUND(scantrans)
  IF scantrans(i) = ohr_scancode THEN RETURN i
 NEXT i
 RETURN 0
END FUNCTION

SUB io_sdl2_set_clipboard_text(text as zstring ptr)  'ustring
  CheckOK(SDL_SetClipboardText(text))
END SUB

FUNCTION io_sdl2_get_clipboard_text() as zstring ptr  'ustring
  RETURN SDL_GetClipboardText()
END FUNCTION

FUNCTION gfx_sdl2_setprocptrs() as integer
  gfx_init = @gfx_sdl2_init
  gfx_close = @gfx_sdl2_close
  gfx_getversion = @gfx_sdl2_getversion
  gfx_setpal = @gfx_sdl2_setpal
  gfx_screenshot = @gfx_sdl2_screenshot
  gfx_setwindowed = @gfx_sdl2_setwindowed
  gfx_windowtitle = @gfx_sdl2_windowtitle
  gfx_getwindowstate = @gfx_sdl2_getwindowstate
  gfx_get_screen_size = @gfx_sdl2_get_screen_size
  gfx_supports_variable_resolution = @gfx_sdl2_supports_variable_resolution
  gfx_vsync_supported = @gfx_sdl2_vsync_supported
  gfx_get_resize = @gfx_sdl2_get_resize
  gfx_set_resizable = @gfx_sdl2_set_resizable
  gfx_recenter_window_hint = @gfx_sdl2_recenter_window_hint
  gfx_setoption = @gfx_sdl2_setoption
  gfx_describe_options = @gfx_sdl2_describe_options
  gfx_get_safe_zone_margin = @gfx_sdl2_get_safe_zone_margin
  gfx_set_safe_zone_margin = @gfx_sdl2_set_safe_zone_margin
  gfx_supports_safe_zone_margin = @gfx_sdl2_supports_safe_zone_margin
  gfx_ouya_purchase_request = @gfx_sdl2_ouya_purchase_request
  gfx_ouya_purchase_is_ready = @gfx_sdl2_ouya_purchase_is_ready
  gfx_ouya_purchase_succeeded = @gfx_sdl2_ouya_purchase_succeeded
  gfx_ouya_receipts_request = @gfx_sdl2_ouya_receipts_request
  gfx_ouya_receipts_are_ready = @gfx_sdl2_ouya_receipts_are_ready
  gfx_ouya_receipts_result = @gfx_sdl2_ouya_receipts_result
  io_init = @io_sdl2_init
  io_pollkeyevents = @io_sdl2_pollkeyevents
  io_waitprocessing = @io_sdl2_waitprocessing
  io_keybits = @io_sdl2_keybits
  io_updatekeys = @io_sdl2_updatekeys
  io_enable_textinput = @io_sdl2_enable_textinput
  io_textinput = @io_sdl2_textinput
  io_get_clipboard_text = @io_sdl2_get_clipboard_text
  io_set_clipboard_text = @io_sdl2_set_clipboard_text
  io_show_virtual_keyboard = @io_sdl2_show_virtual_keyboard
  io_hide_virtual_keyboard = @io_sdl2_hide_virtual_keyboard
  io_show_virtual_gamepad = @io_sdl2_show_virtual_gamepad
  io_hide_virtual_gamepad = @io_sdl2_hide_virtual_gamepad
  io_remap_android_gamepad = @io_sdl2_remap_android_gamepad
  io_remap_touchscreen_button = @io_sdl2_remap_touchscreen_button
  io_running_on_console = @io_sdl2_running_on_console
  io_running_on_ouya = @io_sdl2_running_on_ouya
  io_mousebits = @io_sdl2_mousebits
  io_setmousevisibility = @io_sdl2_setmousevisibility
  io_getmouse = @io_sdl2_getmouse
  io_setmouse = @io_sdl2_setmouse
  io_mouserect = @io_sdl2_mouserect
  io_readjoysane = @io_sdl2_readjoysane

  gfx_present = @gfx_sdl2_present

  RETURN 1
END FUNCTION

END EXTERN