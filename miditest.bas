#include "config.bi"
#include "crt.bi"
#include "cutil.bi"
#IFDEF __UNIX__
'Open Sound System
#include "soundcard.bi"

'These headers are both totally nonfunctional, so use manual declarations
'#include "crt/linux/fcntl.bi"
'#include "crt/io.bi"

#define O_WRONLY 01
#define O_RDWR               02
# define O_CLOEXEC     02000000 ' Set close_on_exec.  */

' #define O_CREAT            &o100 /* not fcntl */
' #define O_EXCL             &o200 /* not fcntl */

declare function _close cdecl alias "close" (byval as integer) as integer
declare function _open cdecl alias "open" (byval as zstring ptr, byval as integer) as integer
declare function _write cdecl alias "write" (byval as integer, byval as any ptr, byval as uinteger) as integer

#ELSE
#include "windows.bi"
#include "win/mmsystem.bi"
#undef MIDIEVENT
#undef createevent
#ENDIF

#IFDEF __UNIX__
dim shared midi_handle as integer
#ELSE
dim shared midi_handle as HMIDIOUT
#ENDIF
function openMidi() as integer
    #IFDEF __UNIX__

    '    midi_handle = _open("/dev/sequencer",O_WRONLY)
    midi_handle = _open("/dev/snd/seq",O_RDWR OR O_CLOEXEC)
    print "open err = " & *get_sys_err_string()

    return midi_handle = 0
    #ELSE
    'dim moc as MIDIOUTCAPS
    'midiOutGetDevCaps MIDI_MAPPER, @moc, len(MIDIOUTCAPS)
    'debug "Midi port supports Volume changes:" + str$(moc.dwSupport AND MIDICAPS_VOLUME)

    return midiOutOpen (@midi_handle,MIDI_MAPPER,0,0,0)

    #ENDIF
end function

function closeMidi() as integer
    #IFDEF __UNIX__
    dim ret as integer = _close(midi_handle)
    print "close err = " & *get_sys_err_string()
    return ret
    #ELSE
    return midiOutClose (midi_handle)
    #ENDIF
end function

function shortMidi(event as UByte, a as UByte, b as UByte) as integer
    #IFDEF __UNIX__
    DIM packet(2) as UByte
    packet(0) = event
    packet(1) = a
    packet(2) = b
    dim ret as integer = _write(midi_handle,@packet(0),3)
    print "write err = " & *get_sys_err_string()
    return ret

    #ELSEIF defined(__UNIX__)
    DIM packet(3) as UByte
    packet(0) = SEQ_MIDIPUTC
    packet(1) = event
    _write(midi_handle,@packet(0),4)
    packet(1) = a
    _write(midi_handle,@packet(0),4)
    packet(1) = b
    _write(midi_handle,@packet(0),4)
    return 0
    #ELSE
    return midiOutShortMSG(midi_handle,event SHL 0 + a SHL 8 + b SHL 16)
    #ENDIF
end function

sub waitforkey
    sleep
    'Clear keypress
    dim dummy as string = inkey
end sub

print "(after each step, press a key)"

print "Open midi"
print openMidi
waitforkey

print "Note on"
'print shortMidi(&H90,&H40,100)
print shortMidi(&H90,60, 127)
waitforkey

print "Note off"
print shortMidi(&H80,60, 127)
'print shortMidi(&H80,&H40,0)
waitforkey

print "Close midi"
print closeMidi
waitforkey
