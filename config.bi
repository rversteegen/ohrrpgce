'OHRRPGCE Common - Configuration/platform specific/important macros
'This file is (should be) included everywhere, and is a dumping ground for macros and other global declarations

#IFNDEF CONFIG_BI
#DEFINE CONFIG_BI

#IF __FB_DEBUG__
 #DEFINE _GSTR & " -g"
#ELSE
 #DEFINE _GSTR
#ENDIF
#IF __FB_ERR__
 #DEFINE _ESTR & " -exx"
#ELSE
 #DEFINE _ESTR
#ENDIF
#IF     defined( __FB_LINUX__)
 #DEFINE _PSTR & " Linux"
 #DEFINE __UNIX__
#ELSEIF defined(__FB_FREEBSD__)
 #DEFINE _PSTR & " FreeBSD"
 #DEFINE __UNIX__
#ELSEIF defined(__FB_NETBSD__)
 #DEFINE _PSTR & " NetBSD"
 #DEFINE __UNIX__
#ELSEIF defined(__FB_OPENBSD__)
 #DEFINE _PSTR & " OpenBSD"
 #DEFINE __UNIX__
#ELSEIF defined(__FB_DARWIN__)
 #DEFINE _PSTR & " Mac OS X/Darwin"
 #DEFINE __UNIX__
#ELSEIF defined(__FB_WIN32__)
 #DEFINE _PSTR & " Win32"
#ELSEIF defined(__FB_DOS__)
 #DEFINE _PSTR & " DOS"
#ELSE
 #DEFINE _PSTR & " Unknown Platform"
#ENDIF
#IFDEF SCRIPTPROFILE
 #DEFINE _SSTR & " script_profiling"
#ELSE
 #DEFINE _SSTR
#ENDIF
CONST build_info as string = "" _GSTR _ESTR _SSTR _PSTR

'__FB_UNIX__ only defined in FB 0.21 on (I think)
'Note: it's always defined, either to 0 or -1. HATE
#IF __FB_UNIX__
 #IFNDEF __UNIX__
  #DEFINE __UNIX__
 #ENDIF
#ENDIF

#IFDEF __UNIX__
 'FB's headers check for __FB_LINUX__
 #DEFINE __FB_LINUX__
#ENDIF

EXTERN wantpollingthread as integer
EXTERN as string gfxbackend, musicbackend
EXTERN as string gfxbackendinfo, musicbackendinfo, systeminfo

#undef getkey

'included only for $inclib?
#include once "crt.bi"
#undef rand
#undef abort
#undef bound
#undef strlen

'it was too awful (collision-wise) to include all of windows.bi
#macro include_windows_bi()
'# include "windows.bi"
# ifndef windows_bi_included
#  define windows_bi_included
#  undef point
#  define _X86_
#  include "win/windef.bi"
#  include "win/winbase.bi"
#  undef max
#  undef min
#  undef getcommandline
#  undef copyfile
#  undef istag
#  undef ignore
# endif
#endmacro

#if  __FB_VERSION__ = "0.15"
'use native gosubs

#define retrace return
#define retrievestate
#define rememberstate
#define crt_jmp_buf byte

#elseif 1
'use nearly-as-fast assembly version (one extra jump)

#undef gosub
#define gosub _gosub_beta(__LINE__,__FUNCTION_NQ__)
'the "if 0 then" is used to place a label after the goto
#define _gosub_beta(a,b) asm : call gosub_##b##_line_##a end asm : if 0 then asm : gosub_##b##_line_##a: end asm : goto
#define retrace asm ret
#define retrievestate
#define rememberstate
#define crt_jmp_buf byte

#else  'choose GOSUB workaround

'alternative to above blocks, use this code on non x86 platforms
'use a setjmp/longjmp kludge

'#include "crt/setjmp.bi"
' setjmp.bi is incorrect
type crt_jmp_buf:dummy(63) as byte:end type
#ifdef __FB_WIN32__
declare function setjmp cdecl alias "_setjmp" (byval as any ptr) as integer
#else
declare function setjmp cdecl alias "setjmp" (byval as any ptr) as integer
#endif
declare sub longjmp cdecl alias "longjmp" (byval as any ptr, byval as integer)

extern gosubbuf() as crt_jmp_buf
extern gosubptr as integer
option nokeyword gosub
#define gosub if setjmp(@gosubbuf(gosubptr)) then gosubptr-=1 else gosubptr+=1:goto
#define retrace longjmp(@gosubbuf(gosubptr-1),1)
#define retrievestate gosubptr=localgosubptr
#define rememberstate localgosubptr=gosubptr
#endif  'choose GOSUB workaround

'#DEFINE CLEAROBJ(OBJ) memset(@(OBJ),0,LEN(OBJ))
'#DEFINE COPYOBJ(TO,FROM) memcpy(@(TO),@(FROM),LEN(FROM))

#ifdef __UNIX__
#define SLASH "/"
#define ispathsep(character) (character = ASC("/"))
#define LINE_END !"\n"
#define CUSTOMEXE "ohrrpgce-custom"
#define DOTEXE ""
#define ALLFILES "*"
#else
#define SLASH "\"
#define ispathsep(character) (character = ASC("/") OR character = ASC("\"))
#define LINE_END !"\r\n"
#define CUSTOMEXE "CUSTOM.EXE"
#define DOTEXE ".exe"
#define ALLFILES "*.*"
#endif

#ENDIF
