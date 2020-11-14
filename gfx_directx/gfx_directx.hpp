#pragma once

//// Debug messages and errors

#include <winerror.h>
#include "../errorlevel.h"

// gfx_directx can be linked to modules from the main engine, so we provide
// implementations of debugc and _throw_error
// misc.h defines debug(), debuginfo(), throw_error() and fatal_error() as
// macros which call _throw_error.
#include "../misc.h"

extern bool input_debug;

#define INPUTDEBUG(...)   if (input_debug) debug(errInfo, __VA_ARGS__);

namespace gfx
{
    const char *HRESULTString(HRESULT hresult);
}


//// Events

#include "../gfx.h"  // For EventEnum

namespace gfx
{
    int postEvent(EventEnum event, intptr_t arg1 = 0, intptr_t arg2 = 0);
}
