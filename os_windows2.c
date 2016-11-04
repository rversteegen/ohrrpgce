//OHHRPGCE COMMON - Windows-specific routines which require C implementations
//Please read LICENSE.txt for GNU GPL License details and disclaimer of liability
//
// This file incorporates code from FreeBASIC's src/rtlib/win32/file_dir.c,
// originally under the GNU LGPL 2.1+, with the following copyright notice:
// libfb - FreeBASIC's runtime library
// Copyright (C) 2004-2016 The FreeBASIC development team.


//fb_stub.h MUST be included first, to ensure fb_off_t is 64 bit
#include "fb/fb_stub.h"
#ifndef HOST_CYGWIN
	// For dir()
	#include <direct.h>
#endif

#include <windows.h>

#include <locale.h>
#include "os.h"
#include "common.h"

// In os_windows.bas
FBSTRING *get_windows_error (int errcode);


void init_runtime() {
	// Needed for mbstowcs
	if (!setlocale(LC_ALL, "")) {
		// This will actually end up in ?_debug_archive.txt; see init_runtime in os_unix.c
		debug(errError, "setlocale failed");
	}
}

// (This could have been written in os_windows.bas and there's no special reason it isn't)
void os_get_screen_size(int *wide, int *high) {
	//*wide = *high = 0;
	// This gets the size of the primary monitor
	*wide = GetSystemMetrics(SM_CXSCREEN);
	*high = GetSystemMetrics(SM_CYSCREEN);
	debug(errInfo, "get_screen_size: true screen size %dx%d", *wide, *high);

	// This retrieves the size of the 'work area' on the primary monitor,
	// which is the part of the screen not obscured by taskbar and similar toolbars
	RECT rect;
	if (!SystemParametersInfo(SPI_GETWORKAREA, 0, &rect, 0)) {
		FBSTRING *errstr = get_windows_error(GetLastError());
		debug(errError, "get_screen_size failed: %s", errstr->data);
		delete_fbstring(errstr);
		return;
	}
	*wide = rect.right - rect.left;
	*high = rect.bottom - rect.top;
}


//==========================================================================================
//                                    Replacement for DIR
//==========================================================================================

typedef struct {
	int in_use;
	int attrib;
#ifdef HOST_CYGWIN
	WIN32_FIND_DATA data;
	HANDLE handle;
#else
	struct _finddata_t data;
	long handle;
#endif
} FB_DIRCTX;

// In the original, each thread has its own FB_DIRCTX in TLS.
FB_DIRCTX DIRctx;

static void close_dir ( void )
{
	FB_DIRCTX *ctx = &DIRctx;
#ifdef HOST_MINGW
	_findclose( ctx->handle );
#else
	FindClose( ctx->handle );
#endif
	ctx->in_use = FALSE;
}

static char *find_next ( int *attrib )
{
	char *name = NULL;
	FB_DIRCTX *ctx = &DIRctx;

#ifdef HOST_MINGW
	do
	{
		if( _findnext( ctx->handle, &ctx->data ) )
		{
			close_dir( );
			name = NULL;
			break;
		}
		name = ctx->data.name;
	}
	while( ctx->data.attrib & ~ctx->attrib );

	*attrib = ctx->data.attrib & ~0xFFFFFF00;

#else
	do {
		if( !FindNextFile( ctx->handle, &ctx->data ) ) {
			close_dir();
			name = NULL;
			break;
		}
		name = ctx->data.cFileName;
	} while( ctx->data.dwFileAttributes & ~ctx->attrib );

	*attrib = ctx->data.dwFileAttributes & ~0xFFFFFF00;
#endif

	return name;
}

FBSTRING *fb_DirUnicode( FBSTRING *filespec, int attrib, int *out_attrib )
{
	FB_DIRCTX *ctx = &DIRctx;
	FBSTRING *res;
	ssize_t len;
	int tmp_attrib;
	char *name;
	int handle_ok;

	if( out_attrib == NULL )
		out_attrib = &tmp_attrib;

	len = FB_STRSIZE( filespec );
	name = NULL;

	if( len > 0 )
	{
		/* findfirst */
		if( ctx->in_use )
			close_dir( );

#ifdef HOST_MINGW
		ctx->handle = _findfirst( filespec->data, &ctx->data );
		handle_ok = ctx->handle != -1;
#else
		ctx->handle = FindFirstFile( filespec->data, &ctx->data );
		handle_ok = ctx->handle != INVALID_HANDLE_VALUE;
#endif
		if( handle_ok )
		{
			/* Handle any other possible bits different Windows versions could return */
			ctx->attrib = attrib | 0xFFFFFF00;

			/* archive bit not set? set the dir bit at least.. */
			if( (attrib & 0x10) == 0 )
				ctx->attrib |= 0x20;

#ifdef HOST_MINGW
			if( ctx->data.attrib & ~ctx->attrib )
				name = find_next( out_attrib );
			else
			{
				name = ctx->data.name;
				*out_attrib = ctx->data.attrib & ~0xFFFFFF00;
			}
#else
			if( ctx->data.dwFileAttributes & ~ctx->attrib )
				name = find_next( out_attrib );
			else
			{
				name = ctx->data.cFileName;
				*out_attrib = ctx->data.dwFileAttributes & ~0xFFFFFF00;
			}
#endif
			if( name )
				ctx->in_use = TRUE;
		}
	} else {
		/* findnext */
		if( ctx->in_use )
			name = find_next( out_attrib );
	}

	FB_STRLOCK();

	/* store filename if found */
	if( name ) {
		len = strlen( name );
		res = fb_hStrAllocTemp_NoLock( NULL, len );
		if( res )
			fb_hStrCopy( res->data, name, len );
		else
			res = &__fb_ctx.null_desc;
	} else {
		res = &__fb_ctx.null_desc;
		*out_attrib = 0;
	}

	fb_hStrDelTemp_NoLock( filespec );

	FB_STRUNLOCK();

	return res;
}
