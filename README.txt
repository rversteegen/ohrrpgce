-----------------------------------------------------------------------------
   Official Hamster Republic RPG Construction Engine    (O.H.R.RPG.C.E)
                                    http://HamsterRepublic.com/ohrrpgce/
-----------------------------------------------------------------------------

Welcome to the OHRRPGCE Source Code! This file gives some basic instructions
for compiling the OHRRPGCE, some hints for hacking improvements, and
apologies for the general crappyness of much of the code :)
-----------------------------------------------------------------------------
We strongly recommend reading http://rpg.HamsterRepublic.com/ohrrpgce/Source
for more detailed up-to-date compiling instructions and documentation of the
source code, especially http://rpg.HamsterRepublic.com/ohrrpgce/Compiling

Please see whatsnew.txt for the changelog.
-----------------------------------------------------------------------------
LICENSE:
  This program is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; either version 2 of the License, or (at your
  option) any later version. See LICENSE.txt for the full text of the GPL.

  Any .RPG files you create are yours to distribute as you please; the GPL
  does not apply to games made with the engine.
-----------------------------------------------------------------------------
WINDOWS/LINUX/UNIX:
  Recommend FreeBasic version 1.05.0
  Requires minimum FreeBasic version 1.00.0
  Download FreeBasic from http://freebasic.net/
   http://rpg.hamsterrepublic.com/ohrrpgce/Getting_FreeBasic
  Compiling requires Python and Scons
  Building HSpeak requires Euphoria v4.0+: http://www.OpenEuphoria.com/
  (Compiling x86_64 versions of HSpeak requires Euphoria 4.1)
  Compiling gfx_directx.dll (optional) requires Visual C++ and a DirectX SDK.
  (See http://rpg.hamsterrepublic.com/ohrrpgce/Compiling#gfx_directx)
  x86, x86_64, and ARM on Win32, GNU/Linux, OSX and Android are tested.
-----------------------------------------------------------------------------
MAC OS X:
  Compiling requires Python, Scons, and a fork of FreeBasic 1.06+
  Read http://rpg.hamsterrepublic.com/ohrrpgce/Compiling_in_Mac_OS_X
-----------------------------------------------------------------------------
ANDROID:
  Requires a fork of FreeBasic 1.06+
  Requires sdl-android (ohrrpgce fork)
  See http://rpg.hamsterrepublic.com/ohrrpgce/Compiling_for_Android for info
-----------------------------------------------------------------------------
INSTRUCTIONS
  Unpack the source code to a new folder
  Install FreeBasic
  Install Python if needed
  Install SConscript
  Run "scons --help" to see options
  Run "scons" to compile Game and Custom
   (32 bit) or "scons arch=64" (64 bit)
  (Unix only) You can run "scons install" to install system-wide or as part
  of creating a package. You can run linux/ohrrpgce.py to create a .deb file.
-----------------------------------------------------------------------------
MAKING IMPROVEMENTS
  There are still lots of bugs that need to be fixed. For a list of known
  bugs, visit http://HamsterRepublic.com/ohrrpgce/buglist.php
  We also welcome code-cleanup and new features as long as you don't break
  compatibility with existing games. If you want to submit a improvement
  see http://rpg.hamsterrepublic.com/ohrrpgce/Source#Submitting_Improvements
-----------------------------------------------------------------------------
WHAT IF YOU WANT TO BREAK COMPATIBILITY?
  I will not accept patches that break compatibility into the official
  version, but you are welcome to make your own "fork" of the OHRRPGCE
  code as long as you obey the conditions of the GPL license. This means that
  if you make your own personal version of the OHRRPGCE based on my source
  code, you have to give others the same freedoms I gave to you. If you want
  to learn more about how the GPL license works, just mail me, and I would
  be happy to elaborate. You can also find the full text of the license in
  LICENSE.txt
-----------------------------------------------------------------------------
HISTORY & AN APOLOGY
  Much of the OHRRPGCE's Source code is ugly. UGLY! Messy! Poorly planned! I
  most sincerely apologize for this fact, and I protest that I am not really
  the terribly incompetent programmer that you might assume I am just by
  reading this code.

  When I first started programming the OHRRPGCE back in late 1996, I was
  ignorant of many important programming concepts. The most noticeable of
  which are procedural programming and namespace scoping. All of my
  subroutines were written using basic's GOSUB RETURN structure, which is
  like a function, except that it has no local namespace, takes no arguments
  and returns no values (so it is really not much like a function at all!)
  a GOSUB routine communicates with the caller entirely using global
  variables. This is quite convenient for a beginner writing simple
  programs, but my global namespace quickly became horribly polluted.

  The next major cause of code ugliness is the 16-bit memory limitation of
  QuickBasic. The linker cannot handle really large object files. Switching
  from Quickbasic's standard linker to FREELINK helped, but still did not
  solve the problem, so I had to break the code up into multiple modules,
  and the only way to do that was to convert my GOSUBs into SUBs and
  FUNCTIONs. Remember now, at the time I was still an ignorant newbie
  programmer, and I did not understand the concept of procedural
  programming. I just saw subs and functions as a way to break my code into
  smaller pieces, and my code was heavily dependant on global namespace, so I
  ended up with a bunch of subs and functions with very very long argument
  lists.

  Then memory limitations struck me again, when the code got to big even for
  the compiler. The long argument lists needed to pass global variables to my
  subs and functions created a lot of compiler overhead, and I had to go
  through the tedious process of turning all those globals in to cross-module
  globals using Quickbasic's COMMON SHARED feature. This alleviated my
  compiling problems, but left me just as bad as ever in terms of namespace
  pollution... but by that point I was used to working in a polluted
  namespace, so I lived with it.

  My code got better later, in particular I was happy with the flexmenu
  routines that I converted some of the menus in CUSTOM to use, but the good
  code is rare, and the bad code still abounds. All of the OHRRPGCE source
  code is still riddled and pock-marked with global usage, badly planned and
  unplanned SUBs and FUNCTIONs, ill-conceived hacks of every kind, and a
  wealth of things that could easily be re-written properly... except that
  they work well enough now, who has the time and motivation to fix them?

  After releasing the source code under the GPL, it turns out that several
  people did in fact have time and motivation to improve the code. These new
  developers had been a blessing, and have revitalized OHRRPGCE development.
  Although bad code still abounds, it is getting better. The OHRRPGCE has
  become an exciting exercise in incrementally transforming a BIG BALL OF MUD
  into well-structured code, while maintaining backwards compatibility all
  along the way.

  Well, I hope that doesn't discourage you too much. Play around with the
  code, have fun, and if you make any improvements that you would like me
  to merge back into the official version, submit patches/pull requests; see
  http://rpg.hamsterrepublic.com/ohrrpgce/Source#Submitting_Improvements
-----------------------------------------------------------------------------
James Paige - Bob@HamsterRepublic.com - http://HamsterRepublic.com/ohrrpgce/
-----------------------------------------------------------------------------
Do you want to keep up with the latest development progress? Subscribe to
the Developer's Mailing list:
http://lists.motherhamster.org/listinfo.cgi/ohrrpgce-motherhamster.org
