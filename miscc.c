/*
 * miscc.c - Misc functions written in C
 *
 * Please read LICENSE.txt for GPL License details and disclaimer of liability
 */

//fb_stub.h MUST be included first, to ensure fb_off_t is 64 bit
#include "fb/fb_stub.h"
#include <errno.h>
#include <stdarg.h>
#include <string.h>
#include <locale.h>
#include "misc.h"


// This is here so that FBARRAY gets included in debug info and seen by gdb (it's not used anywhere else)
extern FBARRAY __dummy_fbarray;
FBARRAY __dummy_fbarray;


//////////////////////////////// Debug output /////////////////////////////////

//Trying to read errno from FB is unlikely to even link, because it's normally a macro, so this has be in C
char *get_sys_err_string() {
	return strerror(errno);
}

void (*debug_hook)(enum ErrorLevel errorlevel, const char *msg) = debugc;

// This is for the benefit of testing tools (vectortest)
void set_debug_hook(void (*new_debug_hook)(enum ErrorLevel errorlevel, const char *msg)) {
	if (new_debug_hook)
		debug_hook = new_debug_hook;
	else
		debug_hook = debugc;
}

void _throw_error(enum ErrorLevel errorlevel, const char *srcfile, int linenum, const char *msg, ...) {
	va_list vl;
	va_start(vl, msg);
	char buf[256];
	buf[255] = '\0';
	int emitted = 0;
	if (srcfile)
		emitted = snprintf(buf, 255, "On line %d in %s: ", linenum, srcfile);
	vsnprintf(buf + emitted, 255 - emitted, msg, vl);
	va_end(vl);
	debug_hook(errorlevel, buf);
	/*
	if (errorlevel >= 5) {
		// Ah, what the heck, shouldn't run, but I already wrote it (NULLs indicate no RESUME support)
		void (*handler)() = fb_ErrorThrowAt(linenum, srcfile, NULL, NULL);
		handler();
	}
	*/
}

///////////////////////////////// FBSTRINGs ///////////////////////////////////

// Initialise an FBSTRING to a C string
// *fbstr is assumed to be garbage
void init_fbstring(FBSTRING *fbstr, const char *cstr) {
	fb_StrInit(fbstr, -1, (char*)cstr, strlen(cstr), 0);
}

// Initialise an FBSTRING to a copy of an existing string.
// If the src string is marked temp, then it is deleted (its contents are moved rather than copied).
// *fbstr is assumed to be garbage.
void init_fbstring_copy(FBSTRING *fbstr, FBSTRING *src) {
	fb_StrInit(fbstr, -1, src, -1, 0);
}

// Set an existing FBSTRING to a C string
// *fbstr must already be initialised!
void set_fbstring(FBSTRING *fbstr, const char *cstr) {
	fb_StrAssign(fbstr, -1, (char*)cstr, strlen(cstr), 0);
}

// Use this function to return a FB string from C.
// This allocates a temporary descriptor which can be returned.
// (The original string should not be freed.)
FBSTRING *return_fbstring(FBSTRING *fbstr) {
	return fb_StrAllocTempResult(fbstr);
}

// A returnable empty string. The result doesn't
// need to be passed through return_fbstring()
FBSTRING *empty_fbstring() {
	return &__fb_ctx.null_desc;
}

// Delete and free a temp string descriptor, or delete a non-temp string (but not its descriptor)
void delete_fbstring(FBSTRING *str) {
	if (FB_ISTEMP(str)) {
		// You simply assign to NULL. This is equivalent to calling nonpublic function fb_hStrDelTemp.
		// If it's a temp descriptor this frees the string and descriptor, otherwise it does nothing.
		fb_StrAssign(NULL, 0, str, -1, 0);
	} else {
		fb_StrDelete(str);
	}
}

// This is like sprintf, but return result as a FB string.
// Remember: %s is a zstring ptr! Use strptr to pass a FB string.
FBSTRING *strprintf (const char *fmtstr, ...) {
	FBSTRING *ret;
	va_list vl;
	va_start(vl, fmtstr);
	int len = vsnprintf(NULL, 0, fmtstr, vl);
	va_end(vl);

	va_start(vl, fmtstr);
	ret = fb_hStrAllocTemp(NULL, len);
	vsnprintf(ret->data, len + 1, fmtstr, vl);
	va_end(vl);
	//fb_hStrSetLength(dst, len);
	return ret;
}


///////////////////////////////// Hashing /////////////////////////////////////


#define ROT(a, b) ((a << b) | (a >> (32 - b)))

// Quite fast hash, ported from fb2c++ (as strihash,
// original was case insensitive) which I wrote and tested myself.
// Actually it turns out this can distribute nonideally for non-text,
// proving it really was a bad idea.
// strp may be NULL iif length is 0
uint32_t stringhash(const unsigned char *strp, int length) {
	uint32_t hash = 0xbaad1dea;
	int extra_bytes = length & 3;

	length /= 4;
	while (length) {
		hash += *(uint32_t *)strp;
		strp += 4;
		hash = (hash << 5) - hash;  // * 31
		hash ^= ROT(hash, 19);
		length -= 1;
	}

	if (extra_bytes) {
		if (extra_bytes == 3)
			hash += *(uint32_t *)strp & 0xffffff;
		else if (extra_bytes == 2)
			hash += *(uint32_t *)strp & 0xffff;
		else if (extra_bytes == 1)
			hash += *strp;
		hash = (hash << 5) - hash;  // * 31
		hash ^= ROT(hash, 19);
	}

	//No need to be too thorough, will get rehashed if needed anyway
	hash += ROT(hash, 2);
	hash ^= ROT(hash, 27); // There are only 2^31 possible results of this step
	hash += ROT(hash, 16);
	return hash;
}


/////////////////////// Put x87 FPU in double-precision mode //////////////////

// For cross-platform portability, force x87 floating-point calculations to be
// done with intermediate results stored in double precision (53 bit mantissa)
// instead of extended double precision (64 bit mantissa) registers.  We change
// the x87 control register to accomplish this.  But it only affects the
// mantissa, not the exponent, so does not remove all inconsistencies.
//
// See http://yosefk.com/blog/consistency-how-to-defeat-the-purpose-of-ieee-floating-point.html
// and http://christian-seiler.de/projekte/fpmath/

// Indirectly include features.h (for glibc detection), which might not exist
#include <limits.h>

// Check for x86 or amd64, for Visual C++, GCC
#if defined(_M_IX86) || defined(_M_AMD64) || defined(__i386__) || defined(__x86_64__)

#if defined(_MSC_VER) || defined(_WIN32)
// Windows, either Visual C++ or MinGW. Note, Windows defaults to double-precision,
// but MinGW switches on extended precision

#include <float.h>

// Unfortunately at least some MinGW versions (4.8.1) ship with a copy of
// gcc with a float.h which shadows the MinGW float.h header
#ifndef _PC_53
#define	_PC_53		0x00010000
#define	_MCW_PC		0x00030000
_CRTIMP unsigned int __cdecl __MINGW_NOTHROW _controlfp (unsigned int unNew, unsigned int unMask);
#endif

void disable_extended_precision() {
	_controlfp(_PC_53, _MCW_PC);
}

#elif defined(__gnu_linux__) || defined(__GNU_LIBRARY__) || defined(__GLIBC__)
// For glibc

#include <fpu_control.h>

void disable_extended_precision() {
	fpu_control_t cw;
	_FPU_GETCW(cw);
	cw = (cw & ~_FPU_EXTENDED) | _FPU_DOUBLE;
	_FPU_SETCW(cw);
}

#else

// Mac: apparently no macro provided to switch the precision, but apparently not
// needed on Macs because SSE is used for everything when possible?
// According to one source, all BSD*s use double precision by default, although
// they did not always, so don't know if this is still true either.

void disable_extended_precision() {}

#endif

#else

// Not x86
void disable_extended_precision() {}

#endif


///////////////////////////////////////////////////////////////////////////////

// This sets the locale (LC_ALL) according to the environment, while the FB
// runtime only sets the LC_CTYPE locale (needed for mbstowcs).
// (I'm not aware of any reason we need to load other locale settings, but it might not hurt.)
// (FB's headers have setlocale, but I don't like to trust them)
void init_crt() {
	// setlocale always fails on Android
#ifndef __ANDROID__
	// Needed for mbstowcs
	if (!setlocale(LC_ALL, "")) {
		// This will actually end up in ?_debug_archive.txt, also
		// this runs before log_dir, tmpdir etc are set. Should call
		// init_runtime in a better way.
		debug(errError, "setlocale failed");
	}
#endif
}
