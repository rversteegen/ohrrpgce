''
'' music_stub.bas - A dummy backend for isolating problems that may or may not
'' be backend related
''
'' part of OHRRPGCE - see elsewhere for license details
''

#include "music.bi"

'these functions intentionally left blank
sub music_init() : end sub

sub music_close() : end sub

sub music_play(songname as string, fmt as integer=FORMAT_BAM) : end sub

sub music_pause() : end sub

sub music_resume() : end sub

sub music_stop() : end sub

sub music_setvolume(vol as integer) : end sub

function music_getvolume() as integer
	return 8
end function

sub music_fade(targetvol as integer) : end sub

sub sound_init() : end sub

sub sound_close() : end sub

sub sound_reset() : end sub

sub sound_play(byval num as integer, byval loopcount as integer,  byval s as integer = 0) : end sub

sub sound_pause(byval num as integer,  byval s as integer = 0) : end sub

sub sound_stop(byval num as integer,  byval s as integer = 0) : end sub

sub sound_free(byval num as integer) : end sub

function sound_playing(byval num as integer,  byval s as integer = 0) as integer
	return 0
end function

function LoadSound overload(byval num as integer) as integer
	return 0
end function

function LoadSound overload(byval filename as string,  byval num as integer = -1) as integer
	return 0
end function

sub UnloadSound(byval num as integer) : end sub