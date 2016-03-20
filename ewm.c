#include <SDL/SDL.h>
#include <SDL/SDL_syswm.h>
#include <stdio.h>
#include <stdlib.h>

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/cursorfont.h>
#include <X11/Xmu/WinUtil.h>

#define _NET_WM_STATE_REMOVE        0    /* remove/unset property */
#define _NET_WM_STATE_ADD           1    /* add/set property */
#define _NET_WM_STATE_TOGGLE        2    /* toggle property  */

static int toggle_WindowedFullScreen (Display *disp, Window win) {

	XEvent xev;
	Atom wm_state  =  XInternAtom(disp, "_NET_WM_STATE", False);
	Atom max_horz  =  XInternAtom(disp, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
	Atom max_vert  =  XInternAtom(disp, "_NET_WM_STATE_MAXIMIZED_VERT", False);

	memset(&xev, 0, sizeof(xev));
	xev.type = ClientMessage;
	xev.xclient.window = win;
	xev.xclient.message_type = wm_state;
	xev.xclient.format = 32;
	xev.xclient.data.l[0] = _NET_WM_STATE_ADD;
	xev.xclient.data.l[1] = max_horz;
	xev.xclient.data.l[2] = max_vert;

	XSendEvent(disp, DefaultRootWindow(disp), False, SubstructureNotifyMask, &xev);
return 1;
/*
    Atom wmState = XInternAtom(disp, "_NET_WM_STATE", False);
    Atom fullScreen = XInternAtom(disp, "_NET_WM_STATE_FULLSCREEN", False);
 
    XEvent xev;
    xev.xclient.type=ClientMessage;
    xev.xclient.serial = 0;
    xev.xclient.send_event=True;
    xev.xclient.window=win;
    xev.xclient.message_type=wmState;
    xev.xclient.format=32;
    xev.xclient.data.l[0] = _NET_WM_STATE_TOGGLE;
    xev.xclient.data.l[1] = fullScreen;
    xev.xclient.data.l[2] = 0;
 
    if (XSendEvent (disp, DefaultRootWindow(disp), False,
                   SubstructureRedirectMask | SubstructureNotifyMask, &xev)) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
*/
}

int main (int argc, char *argv[])
{
    SDL_Surface *screen;
    if (SDL_Init (SDL_INIT_VIDEO) != 0) {
        printf ("SDL Init failed: %s", SDL_GetError());
        return 1;
    }

    atexit(SDL_Quit);

    // Get the current video hardware information
    const SDL_VideoInfo* vidInfo = SDL_GetVideoInfo();
    printf ("Current screen size: %dx%d\n", vidInfo->current_w, vidInfo->current_h);

    int width = 200;//vidInfo->current_w;
    int height = 300;//vidInfo->current_h;
    int bpp = vidInfo->vfmt->BitsPerPixel;

    screen = SDL_SetVideoMode (width, height, bpp, 0);
    if (screen == NULL) {
        printf ("Setting video mode failed: %s", SDL_GetError());
        return 1;
    }

    SDL_SysWMinfo info;
    Window window;
    Display *display;

    SDL_VERSION(&info.version);
    if (SDL_GetWMInfo (&info)) {
        printf ("Got WM info.\n");
        window = info.info.x11.wmwindow;
        display = info.info.x11.display;
    } else {
        printf ("ERROR: can't get WM info.\n");
    }

    printf ("ScreenCount = %d\n", ScreenCount(display));
    printf ("DefaultScreen = %d\n", DefaultScreen(display));
    printf ("DisplayWidth = %d\n", DisplayWidth(display, DefaultScreen(display)));
    printf ("DisplayHeight = %d\n", DisplayHeight(display, DefaultScreen(display)));
    printf ("XDisplayName = %s\n", XDisplayName(NULL));

    /* info.info.x11.lock_func(); */
    /* int success = toggle_WindowedFullScreen (display, window); */
    /* printf("Called toggle_WindowedFullScreen, returned %d\n", success); */
    /* info.info.x11.unlock_func(); */

    SDL_Event event;
    int quitFlag = 0;

    while (quitFlag == 0) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_KEYDOWN) {
                if (event.key.keysym.sym == SDLK_q || event.key.keysym.sym == SDLK_ESCAPE) {
                    quitFlag = 1;
                } else if (event.key.keysym.sym == SDLK_w) {
                    info.info.x11.lock_func();
                    int success = toggle_WindowedFullScreen (display, window);
                    printf("Called toggle_WindowedFullScreen, returned %d\n", success);
                    info.info.x11.unlock_func();
                } else if (event.key.keysym.sym == SDLK_g) {
                    SDL_WM_GrabInput (SDL_GRAB_ON);
                } else if (event.key.keysym.sym == SDLK_u) {
                    SDL_WM_GrabInput (SDL_GRAB_OFF);
                }
            }
        }
    }

    return EXIT_SUCCESS;
}
