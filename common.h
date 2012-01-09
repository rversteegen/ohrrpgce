/* OHRRPGCE
 * This does NOT correspond to common.bi/common.bas
 * Copyright 2011. Please read LICENSE.txt for GNU GPL details and disclaimer of liability
 */

#ifndef COMMON_H
#define COMMON_H

#ifdef __cplusplus
extern "C" {
#endif


#if defined(_WIN32) || defined(WIN32)
# define SLASH '\\'
# define ispathsep(chr) ((chr) == '/' || (chr) == '\\')
#else
# define SLASH '/'
# define ispathsep(chr) ((chr) == '/')
#endif


/* Several other C/C++ compilers, like Comeau C++, also have good gcc compatibility. Change this.
   Apparently the Intel compiler defines __GNUC__ */
#if defined(__GNUC__) || defined(__IBMC__) || defined(__INTEL_COMPILER)
# define pure __attribute__ ((__pure__))
# define format_chk(fmt_arg) __attribute__ ((__format__ (__printf__, fmt_arg, fmt_arg + 1)))
# define noreturn __attribute__ ((__noreturn__))
# define warn_unused_result __attribute__ ((__warn_unused_result__))
#else
# define pure
# define format_chk(fmt_arg)
# define noreturn
//# define inline
#endif

// in common.bas
void debugc(const char *msg, int errorlevel);

// libfb.a
void (*fb_ErrorThrowAt(int line_num, const char *mod_name, void *res_label, void *resnext_label))(void) noreturn;

// in array.c (meh)
void _throw_error(int errorlevel, const char *srcfile, int linenum, const char *msg, ...) format_chk(4);
extern void (*debug_hook)(const char *msg, int errorlevel);
void set_debug_hook(void (*new_debug_hook)(const char *msg, int errorlevel));

#define debug(errorlevel, ...) _throw_error(errorlevel, NULL, 0, __VA_ARGS__)
#define debuginfo(...) _throw_error(1, NULL, 0, __VA_ARGS__)
#define throw_error(...) _throw_error(5, __FILE__, __LINE__, __VA_ARGS__)
#define fatal_error(...) _throw_error(6, __FILE__, __LINE__, __VA_ARGS__)


#ifdef __cplusplus
}
#endif

#endif
