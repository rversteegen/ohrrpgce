option explicit


#include "crt.bi"
#IFDEF __FB_LINUX__
#include "soundcard.bi"
#ELSE
#include "windows.bi"
#include "win/mmsystem.bi"
#undef MIDIEVENT
#undef createevent
#ENDIF

#IFDEF __FB_LINUX__
dim shared midi_handle as FILE ptr
#ELSE
dim shared midi_handle as HMIDIOUT
#ENDIF
function openMidi() as integer
    #IFDEF __FB_LINUX__
    midi_handle = open("/dev/sequencer",O_WRONLY)
    return midi_handle = NULL
    #ELSE
    'dim moc as MIDIOUTCAPS
    'midiOutGetDevCaps MIDI_MAPPER, @moc, len(MIDIOUTCAPS)
    'debug "Midi port supports Volume changes:" + str$(moc.dwSupport AND MIDICAPS_VOLUME)
    
    return midiOutOpen (@midi_handle,MIDI_MAPPER,0,0,0)
    
    #ENDIF
end function

function closeMidi() as integer
    #IFDEF __FB_LINUX__
    return fclose(midi_handle)
    #ELSE
    return midiOutClose (midi_handle)
    #ENDIF
end function

function shortMidi(event as UByte, a as UByte, b as UByte) as integer
	#IFDEF __FB_LINUX__
	DIM packet(3) as UByte
	packet(0) = SEQ_MIDIPUTC
	packet(1) = event
	write(midi_handle,@packet(0),4)
	packet(1) = a
	write(midi_handle,@packet(0),4)
	packet(1) = b
	write(midi_handle,@packet(0),4)
    return 0
    #ELSE
    return midiOutShortMSG(midi_handle,event SHL 0 + a SHL 8 + b SHL 16)
    #ENDIF
end function

print "(after each step, press a key)"

print "Open midi"
print openMidi
sleep

print "Note on"
print shortMidi(&H90,&H40,100)
sleep

print "Note off"
print shortMidi(&H80,&H40,0)
sleep

print "Close midi"
print closeMidi
sleep