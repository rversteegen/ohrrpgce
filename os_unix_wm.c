// This file contains Unix-specific OS routines which should only be linked into
// Game and Custom, not the commandline utils, namely X11 stuff.
// (However this module is linked on all Unices, including OSX, not just ones using X11)
//
// Please read LICENSE.txt for GNU GPL License details and disclaimer of liability


#if !defined(__APPLE__) && !defined(__ANDROID__)
#define X_WINDOWS 1
#endif

//fb_stub.h MUST be included first, to ensure fb_off_t is 64 bit
#include "fb/fb_stub.h"

#ifdef X_WINDOWS
#include <X11/Xlib.h>
#endif

#include <string.h>

#include "common.h"
#include "os.h"


//==========================================================================================
//                                          X11
//==========================================================================================


#ifdef X_WINDOWS

void os_get_screen_size(int *wide, int *high) {
	Display *display;
	display = XOpenDisplay(NULL);  // uses display indicated by $DISPLAY env var
	if (!display) {
		debug(errError, "get_screen_size: XOpenDisplay failed");
		*wide = *high = 0;
		return;
	}

	int screen = DefaultScreen(display);
	*wide = DisplayWidth(display, screen);
	*high = DisplayHeight(display, screen);
	XCloseDisplay(display);
}

#else

// Not implemented, will fallback to gfx_get_screen_size
void os_get_screen_size(int *wide, int *high) {
	*wide = *high = 0;
}

#endif

#if defined(X_WINDOWS) && defined(GFX_SDL_X11)

#define _NET_WM_STATE_REMOVE        0    /* remove/unset property */
#define _NET_WM_STATE_ADD           1    /* add/set property */
#define _NET_WM_STATE_TOGGLE        2    /* toggle property  */

void x11_maximise_window(Display *disp, Window window) {
/*
	XEvent xev;
	Atom wm_state  =  XInternAtom(dpy, "_NET_WM_STATE", False);
	Atom max_horz  =  XInternAtom(dpy, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
	Atom max_vert  =  XInternAtom(dpy, "_NET_WM_STATE_MAXIMIZED_VERT", False);
	debuginfo("maxvert %lu", max_vert);
	debuginfo("display %p %lu", dpy ,window);

	memset(&xev, 0, sizeof(xev));
	xev.type = ClientMessage;
	xev.xclient.window = window;
	xev.xclient.message_type = wm_state;
	xev.xclient.format = 32;
	xev.xclient.data.l[0] = _NET_WM_STATE_ADD;
	xev.xclient.data.l[1] = max_horz;
	xev.xclient.data.l[2] = max_vert;

	XSendEvent(dpy, DefaultRootWindow(dpy), False, SubstructureNotifyMask, &xev);
*/

    Atom wmState = XInternAtom(disp, "_NET_WM_STATE", False);
    Atom fullScreen = XInternAtom(disp, "_NET_WM_STATE_FULLSCREEN", False);
 
    XEvent xev;
    xev.xclient.type=ClientMessage;
    xev.xclient.serial = 0;
    xev.xclient.send_event=True;
    xev.xclient.window=window;
    xev.xclient.message_type=wmState;
    xev.xclient.format=32;
    xev.xclient.data.l[0] = _NET_WM_STATE_TOGGLE;
    xev.xclient.data.l[1] = fullScreen;
    xev.xclient.data.l[2] = 0;
 
    XSendEvent (disp, DefaultRootWindow(disp), False,
                   SubstructureRedirectMask | SubstructureNotifyMask, &xev);
}

#include "SDL/SDL_syswm.h"

// Returns true on success
boolint gfx_sdl_x11_maximise_window() {
	debuginfo("here!");

	SDL_SysWMinfo info;
	SDL_VERSION(&info.version);
	int ret = SDL_GetWMInfo(&info);
	if (ret != 1) {
		debug(errDebug, "SDL_GetWMInfo failed: %d %s", ret, SDL_GetError());
		return 0;
	}

	// No other values are documented, but may as well check...
	if (info.subsystem != SDL_SYSWM_X11)
		return 0;

	info.info.x11.lock_func();
	x11_maximise_window(info.info.x11.display, info.info.x11.window);
	info.info.x11.unlock_func();
	return 1;
}

#else

boolint gfx_sdl_x11_maximise_window() { return 0; }

#endif
