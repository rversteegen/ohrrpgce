// Definition of the OHRRPGCE graphics backend API (both old and new).
// Any C/C++ program exporting or importing the API can include this file.

#ifndef GFX_H
#define GFX_H

#include "stdint.h"

#include "config.h"  // for boolint
#include "gfx_common/DllFunctionInterface.h"
#include "gfx_msg.h"
#include "errorlevel.h"

#include "surface.h"
#include "allmodex.h"  // for XYPair

// See documentation of this constant in gfx.bi
#define CURRENT_GFX_API_VERSION 2

struct WindowState
{
	int structsize;    // Number of members
	boolint focused;
	boolint minimised;
	boolint fullscreen;
	int unused;        // Obsolete, used to be user_toggled_fullscreen
	boolint mouse_over;
	XYPair windowsize; // The actual size (client area), not the resolution seen by the engine
	int zoom;
};
#define WINDOWSTATE_SZ 8

struct JoystickInfo
{
	// All of this data is optional except for num_axes, num_hats
	int instance_id;         // Uniquely identifies a joystick. (Some backends may not be to track
	                         // correctly if there are multiple joysticks plugged in at once).
	                         // Unplugging and replugging a jotstick should assign a new ID.
	char model_guid[15];     // Identifies the model of hardware. Provided by winapi and SDL2
	char name[40];           // Concatenation of product and instance name, if both available
	int num_buttons;         // At most 32. 0 if not known.
	int num_axes;            // At most 8.
	int num_hats;            // At most 4.
	int num_balls;           // I don't actually expect we will ever use this - backend should just report balls as axes
};

struct IOJoystickState
{
	int structsize;          // Number of members in the struct or inside info (not counting info itself),
	                         // set to IOJOYSTICKSTATE_SZ by both engine and backend. Always at least 11
	unsigned int buttons_down; // Whether each button is currently down
	unsigned int buttons_new;  // (Optional) Whether a new keypress has happened for each button, since last poll
	int axes[8];             // Values from -1000 to 1000
	int hats[4];             // Length 4 bitvector: left=1, right=2, up=4, down=8
	JoystickInfo info;
};
#define IOJOYSTICKSTATE_SZ 11

typedef void (__cdecl *FnDebug)(enum ErrorLevel errlvl, const char* message);

enum EventEnum {
	eventTerminate = 0,      // Window or application close request event
	eventFullscreened = 1,   // Windowed/fullscreen state changed by WM/user. arg1 is new fullscreen state
	eventLostJoystick = 2,   // A joystick has been removed and following joysticsk have been renumbered.
	                         // arg1 is the index of the joystick
};

//Allowed to be called from another thread.
//Maybe ought to guarantee backend won't be reentered.
//Return value is INT_MIN if the event wasn't understood, and event-specific but generally 0 if it was.
typedef intptr_t (*FnEventHandler)(EventEnum event, intptr_t arg1, intptr_t arg2);

struct GfxInitData
{
	int structsize;    // Number of members
	const char* windowtitle;
	const char* windowicon;
	void (__cdecl *PostTerminateSignal)(void);
	FnDebug DebugMsg;
	FnEventHandler PostEvent;
};
#define GFXINITDATA_SZ 6

enum CursorVisibility {
	CV_Hidden = 0,   // (cursorHidden)  Cursor always hidden
	CV_Visible = -1, // (cursorVisible) Cursor always shown, except on touch screens
	CV_Default = -2  // (cursorDefault) Cursor shown when windowed, hidden in fullscreen
};


DFI_CLASS_BEGIN( GfxBackendDll );

//terminate_signal_handler is a pointer to post_terminate_signal, for dynamically linked graphics backends.
//windowicon is platform specific: name of the icon resource on Windows, no meaning yet elsewhere
DFI_DECLARE_CDECL( int, gfx_init, void (__cdecl *terminate_signal_handler)(void) , const char* windowicon, char* info_buffer, int info_buffer_size );
DFI_DECLARE_CDECL( void, gfx_close );

DFI_DECLARE_CDECL( int, gfx_getversion );
DFI_DECLARE_CDECL( void, gfx_setdebugfunc, FnDebug DebugMsg );

DFI_DECLARE_CDECL( void, gfx_showpage, unsigned char *raw, int w, int h ); //obsolete
DFI_DECLARE_CDECL( int, gfx_present, Surface* pSurfaceIn, RGBPalette* palette ); //new interface for presentation
DFI_DECLARE_CDECL( void, gfx_setpal, unsigned int *pal ); //set colour palette, DWORD where colors ordered b,g,r,a
DFI_DECLARE_CDECL( int, gfx_screenshot, const char* fname );
DFI_DECLARE_CDECL( void, gfx_setwindowed, int iswindow );
DFI_DECLARE_CDECL( void, gfx_windowtitle, const char* title );
DFI_DECLARE_CDECL( struct WindowState*, gfx_getwindowstate );
DFI_DECLARE_CDECL( void, gfx_set_window_size, XYPair newsize, int newzoom );

//gfx_setoption recieves an option name and the following option which may or may not be a related argument
//returns 0 if unrecognised, 1 if recognised but arg is ignored, 2 if arg is gobbled
DFI_DECLARE_CDECL( int, gfx_setoption, const char* opt, const char* arg );
DFI_DECLARE_CDECL( const char*, gfx_describe_options );

DFI_DECLARE_CDECL( void, io_init );
DFI_DECLARE_CDECL( void, io_pollkeyevents );

//DFI_DECLARE_CDECL( void, io_waitprocessing );

//DFI_DECLARE_CDECL( void, io_keybits, int* keybdarray );
DFI_DECLARE_CDECL( void, io_keybits, int *keybd );
DFI_DECLARE_CDECL( void, io_textinput, wchar_t* buffer, int bufferLen );
DFI_DECLARE_CDECL( char*, io_get_clipboard_text );
DFI_DECLARE_CDECL( void, io_set_clipboard_text, const char* text );

//DFI_DECLARE_CDECL( void, io_mousebits, int* mx, int* my, int* mwheel, int* mbuttons, int* mclicks );
DFI_DECLARE_CDECL( int, io_setmousevisibility, enum CursorVisibility visibility );
DFI_DECLARE_CDECL( void, io_getmouse, int* mx, int* my, int* mwheel, int* mbuttons );
DFI_DECLARE_CDECL( void, io_setmouse, int x, int y );
DFI_DECLARE_CDECL( void, io_mouserect, int xmin, int xmax, int ymin, int ymax );
DFI_DECLARE_CDECL( int, io_readjoysane, int joynum, unsigned int* buttons, int* jx, int* jy );  //obsolete
DFI_DECLARE_CDECL( int, io_get_joystick_state, int joynum, IOJoystickState* state );
DFI_DECLARE_CDECL( int, io_poll_joysticks );  //returns number of joysticks
DFI_DECLARE_CDECL( void, io_poll_joysticks_done );


/////////////////////////////////////////////////////////////////////////////////////////////
//Interfaces 2.0?


/////////////////////////////////////////////////////////////////////////////////////////////
//basic backend functions
DFI_DECLARE_CDECL( int, gfx_Initialize, const struct GfxInitData* pCreationData ); //initializes the backend; if failed, returns 0
DFI_DECLARE_CDECL( void, gfx_Shutdown ); //shuts down the backend--does not post the termination signal

DFI_DECLARE_CDECL( int, gfx_SendMessage, unsigned int msg, unsigned int dwParam, void* pvParam ); //sends a message to the backend; return value depends on message sent

DFI_DECLARE_CDECL( int, gfx_GetVersion ); //returns the backend version

/////////////////////////////////////////////////////////////////////////////////////////////
//graphical functions
//presents a surface from ohr to the backend's backbuffer, converting it with the palette supplied;
//if pSurface == NULL, a maintained copy of the surface will be used
//if pPalette == NULL, a maintained copy of the palette will be used
DFI_DECLARE_CDECL( void, gfx_PresentOld, unsigned char *pSurface, int nWidth, int nHeight, unsigned int *pPalette );

DFI_DECLARE_CDECL( int, gfx_ScreenShot, const char* szFileName ); //takes a screenshot; if failed, returns 0

/////////////////////////////////////////////////////////////////////////////////////////////
//messaging functions
DFI_DECLARE_CDECL( void, gfx_PumpMessages ); //pumps the backend's message queues and polls input

DFI_DECLARE_CDECL( void, gfx_SetWindowTitle, const char* szTitle ); //sets the window title; the backend may add messages to the window title to describe further option
DFI_DECLARE_CDECL( const char*, gfx_GetWindowTitle ); //returns the window title without the backend's possible additions
DFI_DECLARE_CDECL( void, gfx_GetWindowState, int nID, struct WindowState *pState ); //returns window information

DFI_DECLARE_CDECL( void, gfx_SetCursorVisibility, enum CursorVisibility visibility ); //visibility of the OS cursor over the client area
DFI_DECLARE_CDECL( void, gfx_ClipCursor, int left, int top, int right, int bottom ); //clips the os cursor to the ohr rectangle, which is scaled to the client area; passing a negative for any value disables the clip

/////////////////////////////////////////////////////////////////////////////////////////////
//input functions
DFI_DECLARE_CDECL( int, gfx_GetKeyboard, int *pKeyboard ); //gets the keyboard state in a format the engine understands; returns 0 on failure
DFI_DECLARE_CDECL( void, gfx_GetText, wchar_t *pBuffer, int bufferLen ); //gets the textual input since the last call, stores it in a buffer which can hold len-1 characters

DFI_DECLARE_CDECL( int, gfx_GetMouse, int* x, int* y, int* wheel, int* buttons ); //gets the mouse position and button state; returns 0 on failure
DFI_DECLARE_CDECL( int, gfx_SetMouse, int x, int y); //sets the mouse position; returns 0 on failure


DFI_CLASS_END( GfxBackendDll );

#endif
