#!/usr/bin/env python

"""
Various utility functions used by SConscript while building, but could also be
used by other tools.
"""

import os
import sys
import subprocess
import platform
import re
import datetime
import fnmatch
import itertools
from SCons.Util import WhereIs

host_win32 = platform.system() == 'Windows'

########################################################################
# Utilities

def get_command_output(cmd, args, shell = True, ignore_stderr = False):
    """Runs a shell command and returns stdout as a string"""
    if shell:
        # Argument must be a single string (additional arguments get passed as extra /bin/sh args)
        if isinstance(args, (list, tuple)):
            args = ' '.join(args)
        cmdargs = '"' + cmd + '" ' + args
    else:
        assert isinstance(args, (list, tuple))
        cmdargs = [cmd] + args
    if ignore_stderr:
        proc = subprocess.Popen(cmdargs, shell=shell, stdout=subprocess.PIPE)
        errtext = ""
    else:
        proc = subprocess.Popen(cmdargs, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    proc.wait()  # To get returncode
    outtext = proc.stdout.read()
    if not ignore_stderr:
        errtext = proc.stderr.read()
        # Annoyingly fbc prints (at least some) error messages to stdout instead of stderr
    if proc.returncode or errtext:
        exit("subprocess.Popen(%s) failed:\n%s\nstderr:%s" % (cmdargs, outtext, errtext))
    return outtext.strip()

########################################################################
# Scanning for FB include files

include_re = re.compile(r'^\s*#include\s+"(\S+)"', re.M | re.I)

# Add an include file to this list if it should be a dependency even if it doesn't exist in a clean build.
generated_includes = ['ver.txt']

def scrub_includes(includes):
    """Remove those include files from a list which scons should ignore
    because they're standard FB/library includes."""
    ret = []
    for fname in includes:
        if fname in generated_includes or os.path.isfile(fname):
            # scons should expect include files in rootdir, where FB looks for them
            # (verprint() provides #/ver.txt, and without the #/ scons won't run it)
            ret.append ('#' + os.path.sep + fname)
    return ret

def basfile_scan(node, env, path):
    contents = node.get_text_contents()
    included = scrub_includes (include_re.findall (contents))
    #print str(node) + " includes", included
    return env.File(included)

########################################################################
# Scanning for HS include files

hss_include_re = re.compile(r'^\s*include\s*,\s*"?([^"\n]+)"?', re.M | re.I)

def hssfile_scan(node, env, path):
    """Find files included into a .hss."""
    contents = node.get_text_contents()
    included = []
    subdir = os.path.dirname(node.srcnode().path)
    for include in hss_include_re.findall (contents):
        include = include.strip()
        # Search for the included file in the same directory as 'node'
        check_for = os.path.join(subdir, include)
        if os.path.isfile(check_for):
            include = check_for
        included.append(include)
    #print str(node) + " includes", included
    # Turning into File nodes allows plotscr.hsd & scancode.hsi to be found in the root dir
    return env.File(included)

########################################################################
# Querying svn, git

def missing (name, message):
    print "%r executable not found. It may not be in the PATH, or simply not installed.\n%s" % (name, message)

def query_revision (rootdir, revision_regex, date_regex, ignore_error, *command):
    "Get the SVN revision and date (YYYYMMDD format) from the output of a command using regexps"
    # Note: this is reimplemented in linux/ohr_debian.py
    rev = 0
    date = ''
    output = None
    try:
        f = subprocess.Popen (command, stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = rootdir)
        output = f.stdout.read()
        errmsg = f.stderr.read()
        if errmsg and not ignore_error:
            print errmsg
    except OSError:
        missing (command[0], '')
        output = ''
    date_match = re.search (date_regex, output)
    if date_match:
       date = date_match.expand ('\\1\\2\\3')
    rev_match = re.search (revision_regex, output)
    if rev_match:
        rev = int (rev_match.group(1))
    return date, rev

def query_svn (rootdir, command):
    """Call with either 'svn info' or 'git svn info'
    Returns a (rev,date) pair, or (0, '') if not an svn working copy"""
    return query_revision (rootdir, 'Revision: (\d+)', 'Last Changed Date: (\d+)-(\d+)-(\d+)', True, *command.split())

def query_git (rootdir):
    """Figure out last svn commit revision and date from a git repo
    which is a git-svn mirror of an svn repo.
    Returns a (rev,date) pair, or (0, '') if not a git repo"""
    if os.path.isdir (os.path.join (rootdir, '.git')):
        # git svn info is really slow on Windows
        if not host_win32 and os.path.isdir (os.path.join (rootdir, '.git', 'svn', 'refs', 'remotes')):
            # If git config settings for git-svn haven't been set up yet, or git-svn hasn't been
            # told to initialise yet, this will take a long time before failing
            date, rev = query_svn (rootdir, 'git svn info')
        else:
            # Try to determine SVN revision ourselves, otherwise doing
            # a plain git clone won't have the SVN revision info
            date, rev = query_revision (rootdir, 'git-svn-id.*@(\d+)', 'Date:\s*(\d+)-(\d+)-(\d+)', False,
                                        *'git log --grep git-svn-id --date short -n 1'.split())
    else:
        date, rev = '', 0
    return date, rev

def svn_rev_from_git_commit (rootdir, commit):
    

########################################################################

def get_euphoria_version():
    """Returns an integer like 40103 meaning 4.1.3"""
    # WARNING! I still have not found any way to capture euc's stderr.
    # This currently just lies on windows, and returns a fake version number
    # (currently the version number installed on the nightly build machine)
    if host_win32: return 40005
    
    # euc does something really weird when you try to capture stderr. Seems to
    # duplicate stdout to stderr.
    # Using stderr=subprocess.STDOUT to merge stderr back into stdout works around it
    # but only on Linux/Mac
    # This works even if you are redirecting:
    #    scons hspeak 2>&1 | tee
    # Which is important because the nightly builds need to do that
    eucver = subprocess.check_output(["euc", "--version"], stderr=subprocess.STDOUT)
    eucver = re.findall(" v([0-9.]+)", eucver)[0]
    print "Euphoria version", eucver
    x,y,z = eucver.split('.')
    return int(x)*10000 + int(y)*100 + int(z)

########################################################################
# Querying fbc

def get_fb_info(fbc = 'fbc'):
    """Find fbc and query its version and default target and arch.
    'fbc' is the program name to use."""
    if not os.path.isfile (fbc):
        fbc = WhereIs (fbc)
        if not fbc:
            raise Exception("FreeBasic compiler is not installed!")
    # Newer versions of fbc (1.0+) print e.g. "FreeBASIC Compiler - Version $VER ($DATECODE), built for linux-x86 (32bit)"
    # older versions printed "FreeBASIC Compiler - Version $VER ($DATECODE) for linux"
    # older still printed "FreeBASIC Compiler - Version $VER ($DATECODE) for linux (target:linux)"
    fbcinfo = get_command_output(fbc, ["-version"])
    version, date = re.findall("Version ([0-9.]+) ([0-9()-]+)", fbcinfo)[0]
    fullfbcversion = version + ' ' + date
    # Convert e.g. 1.04.1 into 1041
    fbcversion = (lambda x,y,z: int(x)*1000 + int(y)*10 + int(z))(*version.split('.'))

    fbtarget = re.findall("target:([a-z]*)", fbcinfo)  # Old versions of fbc.
    if len(fbtarget) == 0:
        # New versions of fbc. Format is os-cpufamily, and it is the
        # directory name where libraries are kept in non-standalone builds.
        fbtarget = re.findall(" built for ([a-zA-Z0-9-_]+)", fbcinfo)
        if len(fbtarget) == 0:
            raise Exception("Couldn't determine fbc default target")
    fbtarget = fbtarget[0]
    if '-' in fbtarget:
        # New versions of fbc
        default_target, default_arch = fbtarget.split('-')
    else:
        # Old versions
        default_target, default_arch = fbtarget, 'x86'

    return fbc, fbcversion, fullfbcversion, default_target, default_arch

########################################################################

def verprint (used_gfx, used_music, fbc, arch, asan, portable, builddir, rootdir, DATAFILES):
    """
    Generate ver.txt, iver.txt (Innosetup), distver.bat.

    rootdir:  the directory containing this script
    builddir: the directory where object files should be placed
    However, all files created here are currently placed in rootdir
    """
    def openw (whichdir, filename):
        if not os.path.isdir (whichdir):
            os.mkdir (whichdir)
        return open (os.path.join (whichdir, filename), 'wb')

    # Determine branch name and svn revision
    f = open (os.path.join (rootdir, 'codename.txt'),'rb')
    lines = []
    for line in f:
        if not line.startswith ('#'):
            lines.append (line.rstrip())
    f.close()
    if len(lines) != 2:
        exit('Expected two noncommented lines in codename.txt')
    codename = lines[0]
    branch_rev = int(lines[1])

    # Determine svn revision and date
    date, rev = query_git (rootdir)
    if rev == 0:
        date, rev = query_svn (rootdir, 'svn info')
    if rev == 0:
        print "Falling back to reading svninfo.txt"
        date, rev = query_svn (rootdir, 'cat svninfo.txt')
    if rev == 0:
        print
        print """ WARNING!!
Could not determine SVN revision, which will result in RPG files without full
version info and could lead to mistakes when upgrading .rpg files. A file called
svninfo.txt should have been included with the source code if you downloaded a
.zip instead of using svn or git."""
        print

    # Discard git/svn date and use current date instead because it doesn't reflect when
    # the source was actually last modified.
    # Unless overridden: https://reproducible-builds.org/specs/source-date-epoch/
    if 'SOURCE_DATE_EPOCH' in os.environ:
        build_date = datetime.datetime.utcfromtimestamp(int(os.environ['SOURCE_DATE_EPOCH']))
    else:
        build_date = datetime.date.today()
    date = build_date.strftime ('%Y%m%d')

    if branch_rev <= 0:
        branch_rev = rev
    fbver = get_fb_info(fbc)[2]
    results = []

    # Backends
    supported_gfx = []
    for gfx in used_gfx:
        if gfx in ('sdl','sdl2','fb','alleg','directx','sdlpp','console'):
            results.append ('#DEFINE GFX_%s_BACKEND' % gfx.upper())
            supported_gfx.append (gfx)
        else:
            exit("Unrecognised gfx backend " + gfx)
    for m in used_music:
        if m in ('native','sdl','sdl2','native2','allegro','silence'):
            results.append ('#DEFINE MUSIC_%s_BACKEND' % m.upper())
            results.append ('#DEFINE MUSIC_BACKEND "%s"' % m)
        else:
            exit("Unrecognised music backend " + m)
    results.append ('#DEFINE SUPPORTED_GFX "%s "' % ' '.join (supported_gfx))
    tmp = ['gfx_choices(%d) = @%s_stuff' % (i, v) for i, v in enumerate (supported_gfx)]
    results.append ("#DEFINE GFX_CHOICES_INIT  " +\
      " :  ".join (['redim gfx_choices(%d)' % (len(supported_gfx) - 1)] + tmp))

    name = 'OHRRPGCE'
    gfx_code = 'gfx_' + "+".join (supported_gfx)
    music_code = 'music_' + "+".join (used_music)
    asan = 'AddrSan' if asan else ''
    portable = 'portable' if portable else ''
    data = {'name' : name, 'codename': codename, 'date': date, 'arch': arch, 'asan': asan,
            'rev' : rev, 'branch_rev' : branch_rev, 'fbver': fbver, 'music': music_code,
            'gfx' : gfx_code, 'portable' : portable, 'DATAFILES' : DATAFILES}

    results.extend ([
        'CONST version as string = "%(name)s %(codename)s %(date)s"' % data,
        'CONST version_code as string = "%(name)s Editor version %(codename)s"' % data,
        'CONST version_revision as integer = %(rev)d' % data,
        'CONST version_date as integer = %(date)s' % data,
        'CONST version_branch as string = "%(codename)s"' % data,
        'CONST version_branch_revision as integer = %(branch_rev)s' % data,
        'CONST version_build as string = "%(date)s %(gfx)s %(music)s"' % data,
        ('CONST long_version as string = "%(name)s %(codename)s %(date)s.%(rev)s'
         ' %(gfx)s/%(music)s FreeBASIC %(fbver)s %(arch)s %(asan)s %(portable)s"') % data,
        'CONST DATAFILES as string = "%(DATAFILES)s"' % data])

    # If there is a build/ver.txt placed there by previous versions of this function
    # then it must be deleted because scons thinks that one is preferred
    # (ver.txt does not go in build/ because FB doesn't look there for includes)
    try:
        os.remove (builddir + 'ver.txt')
    except OSError: pass
    f = openw (rootdir, 'ver.txt')
    f.write ('\n'.join (results))
    f.write ('\n')
    f.close()
    tmpdate = '.'.join([data['date'][:4],data['date'][4:6],data['date'][6:8]])
    f = openw (rootdir, 'iver.txt')
    f.write ('AppVerName=%(name)s %(codename)s %(date)s\n' % data)
    f.write ('VersionInfoVersion=%s.%s\n' % (tmpdate, rev))
    f.close ()
    f = openw (rootdir, 'distver.bat')
    f.write('SET OHRVERCODE=%s\nSET OHRVERDATE=%s' % (codename,
                                                      tmpdate.replace ('.','-')))
    f.close()

########################################################################
# Android

def android_source_actions (sourcelist, rootdir, destdir):
    """Returns a pair (source_nodes, actions) for android-source=1 builds.
    The actions copy a set of C and C++ files to destdir (which is android/tmp/),
    including all C/C++ sources and C-translations of .bas files.
    """
    source_files = []
    source_nodes = []
    for node in sourcelist:
        assert len(node.sources) == 1
        # If it ends with .bas then we can't use the name of the source file,
        # since it doesn't have the game- or edit- prefix if any;
        # use the name of the resulting target instead, which is an .o
        if node.sources[0].name.endswith('.bas'):
            source_files.append (node.abspath[:-2] + '.c')
            # 'node' is for an .o file, but actually we pass -r to fbc, so it
            # produces a .c instead of an .o output. SCons doesn't care that no .o is generated.
            source_nodes += [node]
        else:
            # node.sources[0] itself is a path in build/ (to a nonexistent file)
            source_files.append (node.sources[0].srcnode().abspath)
            source_nodes += node.sources
    # hacky. Copy the right source files to a temp directory because the Android.mk used
    # by the SDL port selects too much.
    # The more correct way to do this would be to use VariantDir to get scons
    # to automatically copy all sources to destdir, but that requires teaching it
    # that -gen gcc generates .c files.
    # (This links lib/gif.cpp as gif.cpp, so copy lib/gif.h to gif.h)
    actions = [
        'rm -fr %s/*' % destdir,
        'mkdir -p %s/fb' % destdir,
        # This actually creates the symlinks before the C/C++ files are generated, but that's OK
        'ln -s ' + ' '.join(source_files) + ' ' + destdir,
        'cp %s/*.h %s/' % (rootdir, destdir),
        'cp %s/*.hpp %s/' % (rootdir, destdir),
        'cp %s/fb/*.h %s/fb/' % (rootdir, destdir),
        'cp %s/lib/*.h %s/' % (rootdir, destdir),
        'cp %s/android/sdlmain.c %s' % (rootdir, destdir),
        # Cause build.sh to re-generate Settings.mk, since extraconfig.cfg may have changed
        'touch %s/android/AndroidAppSettings.cfg' % (rootdir),
    ]
    return source_nodes, actions

########################################################################
# Portability checks
    
def check_lib_requirements(binary):
    """Check and print which versions of glibc and gcc dependency libraries (including libstdc++.so)
    that an ELF binary requires.

    Note that libstdc++ version requirements are reported as GCC requirements,
    because each libstdc++ version is tied to a specific GCC version.
    Old versions before ~2010 are lumped together, and GCC versions newer than 6.1
    aren't supported yet.
    """

    libraries = []
    current_lib = None
    req = {'CXXABI': (), 'GLIBC': (), 'GLIBCXX': (), 'GCC': ()}
    for line in get_command_output("objdump", ["-p", binary]).split('\n'):
        match = re.search("required from (.*):", line)
        if match:
            current_lib = match.group(1)
            libraries.append(current_lib)
        match = re.search("(CXXABI|GCC|GLIBC|GLIBCXX)_([0-9.]*)", line)
        if match:
            symbol = match.group(1)
            version = tuple(map(int, match.group(2).split('.')))
            #print symbol, version
            req[symbol] = max(req[symbol], version)

    # Tables giving the required version of GCC corresponding to each GLIBCXX symbol versioning tag
    GLIBCXX_to_gcc = {
        (3,4,10): (4,3,0),
        (3,4,11): (4,4,0),
        (3,4,12): (4,4,1),
        (3,4,13): (4,4,2),
        (3,4,14): (4,5,0),
        (3,4,15): (4,6,0),
        (3,4,16): (4,6,1),
        (3,4,17): (4,7,0),
        (3,4,18): (4,8,0),
        (3,4,19): (4,8,3),
        (3,4,20): (4,9,0),
        (3,4,21): (5,1,0),
        (3,4,22): (6,1,0),
    }

    # Ditto for CXXABI
    CXXABI_to_gcc = {
        (1,3,2): (4,3,0),
        (1,3,3): (4,4,0),
        (1,3,3): (4,4,1),
        (1,3,3): (4,4,2),
        (1,3,4): (4,5,0),
        (1,3,5): (4,6,0),
        (1,3,5): (4,6,1),
        (1,3,6): (4,7,0),
        (1,3,7): (4,8,0),
        (1,3,7): (4,8,3),
        (1,3,8): (4,9,0),
        (1,3,9): (5,1,0),
        (1,3,10): (6,1,0),
    }

    gcc_release_dates = {
        (4,3,0): 'March 5, 2008',
        (4,4,0): 'April 21, 2009',
        (4,4,1): 'July 22, 2009',
        (4,4,2): 'October 15, 2009',
        (4,5,0): 'April 14, 2010',
        (4,6,0): 'March 25, 2011',
        (4,6,1): 'June 27, 2011',
        (4,7,0): 'March 22, 2012',
        (4,8,0): 'March 22, 2013',
        (4,8,3): 'May 22, 2014',
        (4,9,0): 'April 22, 2014',
        (5,1,0): 'April 22, 2015',
        (6,1,0): 'April 27, 2016',
    }

    glibc_release_dates = {
        (2,26): '2017-08-01',
        (2,25): '2017-02-01',
        (2,24): '2016-08-04',
        (2,23): '2016-02-19',
        (2,22): '2015-08-14',
        (2,21): '2015-02-06',
        (2,20): '2014-09-08',
        (2,19): '2014-02-07',
        (2,18): '2013-08-12',
        (2,17): '2012-12-25',
        (2,16): '2012-06-30',
        (2,15): '2012-03-21',
        (2,14,1): '2011-10-07',
        (2,14): '2011-06-01',
        (2,13): '2011-02-01',
        (2,12,2): '2010-12-13',
        (2,12,1): '2010-08-03',
        (2,12): '2010-05-03',
    }
    #print req

    def verstring(version_tuple):
        return '.'.join(map(str, version_tuple))

    def lookup_version(version_tuple, table):
        if version_tuple < min(table):
            return "before " + table[min(table)]
        elif version_tuple > max(table):
            return "after " + table[max(table)]
        elif version_tuple in table:
            return table[version_tuple]
        return "unknown"

    gcc_ver_reqs = []
    gcc_req = ''

    if 'libstdc++.so.6' in libraries:
        gcc_ver_reqs.append((3,4,0))

    if req['GLIBCXX'] > (3,4,22) or req['CXXABI'] > (1,3,10):
        gcc_req = '>6.1.0'
    else:
        if req['GCC']:
            gcc_ver_reqs.append(req['GCC'])
        # fixme: this isn't very good
        if req['CXXABI'] < (1,3,2):
            pass
        else: #if req['CXXABI'] in GLIBCXX_to_gcc:
            gcc_ver_reqs.append(CXXABI_to_gcc.get(req['CXXABI'], (9, 'unknown')))
        if req['GLIBCXX'] < (3,4,10):
            pass
        else: #if req['GLIBCXX'] in GLIBCXX_to_gcc:
            gcc_ver_reqs.append(GLIBCXX_to_gcc.get(req['GLIBCXX'], (9, 'unknown')))
        if gcc_ver_reqs:
            max_version = max(gcc_ver_reqs)
            gcc_req = verstring(max_version) + ' (released %s)' % lookup_version(max_version, gcc_release_dates)
    if gcc_req:
        gcc_req = 'and libs for gcc ' + gcc_req

    glibc_release = lookup_version(req['GLIBC'], glibc_release_dates)
    print ">>  %s requires glibc %s (released %s) %s" % (
        binary, verstring(req['GLIBC']), glibc_release, gcc_req)

#check_lib_requirements("ohrrpgce-game")
