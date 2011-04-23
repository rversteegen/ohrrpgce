#ifndef COMMON_BASE_BI
#define COMMON_BASE_BI

#ifdef COMMON_BI
#error Include at most one of common.bi, common_base.bi
#endif

declare sub debug (s as string)
declare sub debuginfo (s as string)
declare sub fatalerror (s as string)
declare sub debugc cdecl alias "debugc" (byval s as zstring ptr, byval errorlevel as integer)

declare function readkey () as string
declare function rightafter (s as string, d as string) as string

'Called by fatalerror
extern cleanup_function as sub ()

#endif