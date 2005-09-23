'' Compatibility functions/definitions for OHRRPGCE
' This file is specific to either FreeBasic or QuickBasic and
' defines the necessary functions to maintain compatibility
' between the two

'' FreeBasic version

#ifndef DEMACRO
#ifndef DONESTR
option nokeyword str
#define str$(x) xstr$((x))
#define DONESTR
#endif
#endif

#ifdef __FB_LINUX__
#define PATH_SEP "/"
#else
#define PATH_SEP "\"
#endif

' keyword(?) in QB
DECLARE SUB INTERRUPTX (intnum AS INTEGER,inreg AS RegType, outreg AS RegType)
declare function xstr$ overload (x as integer)
declare function xstr$ (x as single)
declare function xstr$ (x as double)
