'' 
'' music_sdl.bas - External music functions implemented in SDL.
''
'' part of OHRRPGCE - see elsewhere for license details
''

option explicit

#include "music.bi"
#include "util.bi"
#include "file.bi"
'warning: due to a FB bug, overloaded functions must be declared before SDL.bi is included
#include "SDL\SDL.bi"
#include "SDL\SDL_mixer.bi"

'extern
declare sub debug(s$)
declare sub bam2mid(infile as string, outfile as string, useOHRm as integer)
declare function isfile(n$) as integer
declare function soundfile$ (sfxnum%)
declare function SDL_RWFromLump(byval lump as Lump ptr) as SDL_RWops ptr
extern tmpdir as string

'local functions
declare function GetSlot(byval num as integer) as integer
declare function next_free_slot() as integer
declare function sfx_slot_info (slot as integer) as string

dim shared music_on as integer = 0  '-1 indicates error, don't try again
dim shared music_vol as integer
dim shared music_paused as integer
dim shared music_song as Mix_Music ptr = NULL
dim shared orig_vol as integer = -1
dim shared nonmidi_vol as integer = MIX_MAX_VOLUME
dim shared nonmidi_playing as integer = 0

'The music module needs to manage a list of temporary files to
'delete when closed, mainly for custom, so they don't get lumped
type delitem
	fname as zstring ptr
	nextitem as delitem ptr
end type

dim shared delhead as delitem ptr = null
dim shared callback_set_up as integer = 0

sub quit_sdl_audio()
	if SDL_WasInit(SDL_INIT_AUDIO) then
		SDL_QuitSubSystem(SDL_INIT_AUDIO)
		if SDL_WasInit(0) = 0 then
			SDL_Quit()
		end if
	end if
end sub

sub music_init()	
	if music_on = 0 then
		dim audio_rate as integer
		dim audio_format as Uint16
		dim audio_channels as integer
		dim audio_buffers as integer
	
		' We're going to be requesting certain things from our audio
		' device, so we set them up beforehand
		audio_rate = MIX_DEFAULT_FREQUENCY
		audio_format = MIX_DEFAULT_FORMAT
		audio_channels = 2
		'Despite the documentation, non power of 2 buffer size MAY work depending on the driver, and pygame even does it
		'At the time, I found that this gave better results than 1k or 2k buffers. I am stubborn
		audio_buffers = 1536  
		
		if SDL_WasInit(0) = 0 then
			if SDL_Init(SDL_INIT_AUDIO) then
				debug "Can't start SDL (audio): " & *SDL_GetError
				music_on = -1  'error
				exit sub
			end if
		elseif SDL_WasInit(SDL_INIT_AUDIO) = 0 then
			if SDL_InitSubSystem(SDL_INIT_AUDIO) then
				debug "Can't start SDL audio subsys: " & *SDL_GetError
				music_on = -1  'error
				quit_sdl_audio()
				exit sub
			end if
		end if
		
		if (Mix_OpenAudio(audio_rate, audio_format, audio_channels, audio_buffers)) <> 0 then
			if (Mix_OpenAudio(audio_rate, audio_format, audio_channels, 2048)) <> 0 then
				debug "Can't open audio : " & *Mix_GetError
				music_on = -1  'error
				quit_sdl_audio()
				exit sub
			end if
		end if
		
		music_vol = 8
		music_on = 1
		music_paused = 0
	end if
end sub

sub music_close()
	if music_on = 1 then
		if orig_vol > 0 then
			'restore original volume
			Mix_VolumeMusic(orig_vol)
		else
			'arbitrary medium value
			Mix_VolumeMusic(64)
		end if
		
		if music_song <> 0 then
			Mix_FreeMusic(music_song)
			music_song = 0
			music_paused = 0
			nonmidi_playing = 0
		end if
		
		Mix_CloseAudio
		quit_sdl_audio()

		music_on = 0
		callback_set_up = 0 	' For SFX
		
		if delhead <> null then
			'delete temp files
			dim ditem as delitem ptr
			dim dlast as delitem ptr
			
			ditem = delhead
			while ditem <> null
				if isfile(*(ditem->fname)) then
					kill *(ditem->fname)
				end if
				deallocate ditem->fname 'deallocate string
				dlast = ditem
				ditem = ditem->nextitem
				deallocate dlast 'deallocate delitem
			wend
			delhead = null
		end if
	end if
end sub

sub music_play(byval lump as Lump ptr, fmt as integer)

end sub

sub music_play(songname as string, fmt as integer)
	if music_on = 1 then
		songname = rtrim$(songname)	'lose any added nulls
		
		if fmt = FORMAT_BAM then
			dim midname as string
			dim as integer flen
			flen = filelen(songname)
			'use last 3 hex digits of length as a kind of hash, 
			'to verify that the .bmd does belong to this file
			flen = flen and &h0fff
			midname = tmpdir & trimpath$(songname) & "-" & lcase(hex(flen)) & ".bmd"
			'check if already converted
			if isfile(midname) = 0 then
				bam2mid(songname, midname,0)
				'add to list of temp files
				dim ditem as delitem ptr
				if delhead = null then
					delhead = allocate(sizeof(delitem))
					ditem = delhead
				else
					ditem = delhead
					while ditem->nextitem <> null
						ditem = ditem->nextitem
					wend
					ditem->nextitem = allocate(sizeof(delitem))
					ditem = ditem->nextitem
				end if
				ditem->nextitem = null
				'allocate space for zstring
				ditem->fname = allocate(len(midname) + 1)
				*(ditem->fname) = midname 'set zstring
			end if
			songname = midname
			fmt = FORMAT_MIDI
		end if

		'stop current song
		if music_song <> 0 then
			Mix_FreeMusic(music_song)
			music_song = 0
			music_paused = 0
		end if

		music_song = Mix_LoadMUS(songname)
		if music_song = 0 then
			debug "Could not load song " + songname + " : " & *Mix_GetError
			exit sub
		end if
		
		Mix_PlayMusic(music_song, -1)			
		music_paused = 0

		'not really working when songs are being faded in.
		if orig_vol = -1 then
			orig_vol = Mix_VolumeMusic(-1)
		end if
					
		if music_vol = 0 then
			Mix_VolumeMusic(0)
		else
			if fmt <> FORMAT_MIDI then
				Mix_VolumeMusic(nonmidi_vol)
			else
				'add a small adjustment because 15 doesn't go into 128
				Mix_VolumeMusic((music_vol * 8) + 8)
			end if
		end if
		
		if fmt <> FORMAT_MIDI then
			nonmidi_playing = -1
		else
			nonmidi_playing = 0
		end if
	end if
end sub

sub music_pause()
	'Pause is broken in SDL_Mixer, so just stop.
	music_stop
end sub

sub music_resume()
	if music_on = 1 then
		if music_song > 0 then
			Mix_ResumeMusic
			music_paused = 0
		end if
	end if
end sub

sub music_stop()
	if music_on = 1 then
		if music_song > 0 then
			Mix_HaltMusic
			nonmidi_playing = 0
		end if
	end if
end sub

sub music_setvolume(vol as integer)
	if nonmidi_playing then
		'Separate volume for XMs because they're annoying
		nonmidi_vol = iif(vol=0, 0, (vol * 8) + 8)
		if music_on = 1 then
			Mix_VolumeMusic(nonmidi_vol)
		end if
	else
		music_vol = vol
		if music_on = 1 then
			if music_vol = 0 then
				Mix_VolumeMusic(0)
			else
				'add a small adjustment because 15 doesn't go into 128
				Mix_VolumeMusic((music_vol * 8) + 8)
			end if
		end if
	end if
end sub

function music_getvolume() as integer
	if nonmidi_playing then
		music_getvolume = nonmidi_vol \ 8
	else
		music_getvolume = music_vol
	end if
end function

'------------ Sound effects --------------

DECLARE sub SDL_done_playing cdecl(byval channel as integer)

TYPE sound_effect
	used as integer 'whether this slot is free
	effectID as integer 'which sound is loaded
	
	paused as integer
	playing as integer
	
	pause_pos as integer
	
	buf as Mix_Chunk ptr
END TYPE

dim shared sfx_slots(7) as sound_effect

dim shared sound_inited as integer 'must be non-zero for anything but _init to work

sub sound_init
  	'if this were called twice, the world would end.
  	if sound_inited then exit sub
  
  	'anything that might be initialized here is done in music_init
  	'but, I must do it here too
   	music_init
   	if (callback_set_up = 0) then
  		Mix_channelFinished(@SDL_done_playing)
	  	callback_set_up = 1
  	end if
  	sound_inited = 1
end sub

sub sound_reset
	dim i as integer
	'trying to free something that's already freed... bad!
	if sound_inited = 0 then exit sub
	for i = 0 to ubound(sfx_slots)
		UnloadSound(i)
	next
end sub

sub sound_close
	sound_reset()
	sound_inited = 0
end sub


function next_free_slot() as integer
  	static retake_slot as integer = 0
  	dim i as integer

  	'Look for empty slots
  	for i = 0 to ubound(sfx_slots)
    	if sfx_slots(i).used = 0 then
      		return i
    	end if
  	next

  	'Look for silent slots
  	for i = 0 to ubound(sfx_slots)
  		retake_slot = (retake_slot + 1) mod (ubound(sfx_slots)+1)
  		with sfx_slots(retake_slot)
    		if .playing = 0 and .paused = 0 then
    			Mix_FreeChunk(.buf)
    			.used = 0
      			return retake_slot
   		 	end if
   		 end with
  	next

  	return -1 ' no slot found
end function

sub sound_play(byval num as integer, byval l as integer,  byval s as integer = 0)
	dim slot as integer
	
	if s=0 then 
		slot=GetSlot(num)
		if slot=-1 then 
			slot=LoadSound(num)
		end if
	else
		slot=num
	end if
	
	if slot=-1 then exit sub
	
	with sfx_slots(slot)
		if .buf = 0 then
			exit sub
		end if

		if l then l = -1

		if .paused then
			Mix_Resume(slot)
			.paused = 0
		end if

		if .playing=0 then
			if mix_playchannel(slot,.buf,l) = -1 then
				exit sub
			end if
			.playing = 1
		end if
	end with

end sub

sub sound_pause(byval num as integer,  byval s as integer = 0)
	dim slot as integer

	if s=0 then 
		slot=GetSlot(num)
	else
		slot=num
	end if

	if slot=-1 then exit sub
	
	with sfx_slots(slot)
		if .playing <> 0 and .paused = 0 then
			.paused = 1
			Mix_Pause(slot)
		end if
	end with
end sub

sub sound_stop(byval num as integer,  byval s as integer = 0)
	dim slot as integer
	
	if s=0 then 
		slot=GetSlot(num)
	else
		slot=num
	end if
	
	if slot=-1 then exit sub
    with sfx_slots(slot)
        if .playing <> 0 then
          	Mix_HaltChannel(slot)
          	.playing = 0
          	.paused = 0
        end if  
    end with
end sub

sub sound_free(byval num as integer)
  dim i as integer
  for i = 0 to ubound(sfx_slots)
    with sfx_slots(i)
      if .effectID = num then UnloadSound i
    end with
  next
end sub

function sound_playing(byval num as integer, byval s as integer=0) as integer
	dim slot as integer
	
	if s=0 then 
		slot=GetSlot(num)
	else
		slot=num
	end if
	
	if slot=-1 then return 0
	if sfx_slots(slot).used = 0 then return 0
	
    return sfx_slots(slot).playing
end function

'Returns the slot in the sound pool which corresponds to the given sound effect
'if the sound is not loaded, returns -1
Function GetSlot(byval num as integer) as integer
  dim i as integer
  for i = 0 to ubound(sfx_slots)
    with sfx_slots(i)
      if .used AND .effectID = num then return i
    end with
  next

  return -1
End Function

'Loads an OHR sound (num) into a slot. Returns the slot number, or -1 if an error
'occurs
Function LoadSound overload(byval num as integer) as integer
  dim ret as integer
  ret = GetSlot(num)
  if ret >= 0 then return ret

  return LoadSound(soundfile(num), num)
End Function

function LoadSound overload(byval lump as Lump ptr,  byval num as integer = -1) as integer
	return -1
end function

function LoadSound overload(byval f as string,  byval num as integer = -1) as integer
	dim slot as integer
	dim sfx as Mix_Chunk ptr
	
	if f="" then return -1
	if not isfile(f) then return -1
	
	'File size restriction to stop massive oggs being decompressed
	'into memory
 	if filelen(f) > 500*1024 then 
 		debug "Sound effect file too large (>500k): " & f 
 		return -1
 	end if
	
	sfx = Mix_LoadWav(@f[0])
	
	if (sfx = NULL) then return -1
	
	slot=next_free_slot()

	if slot = -1 then
		debug "LoadSound(""" & f & """, " & num & ") no more sound slots available"
	else
		with sfx_slots(slot)
			.used = 1
			.effectID = num
			.buf = sfx
			.playing = 0
			.paused = 0
		end with
	end if

	return slot 'yup, that's all

end function

'Unloads a sound loaded in a slot. TAKES A CACHE SLOT, NOT AN SFX ID NUMBER!
Sub UnloadSound(byval slot as integer)
  	if sfx_slots(slot).used = 0 then exit sub
  	with sfx_slots(slot)
        Mix_FreeChunk(.buf)
        .paused = 0
        .playing = 0
        .used = 0
		.effectID = 0
        .buf = 0
  	end with
End Sub

sub SDL_done_playing cdecl(byval channel as integer)
  	sfx_slots(channel).playing = 0
end sub

'-- for debugging
function sfx_slot_info (slot as integer) as string
 with sfx_slots(slot)
   return .used & " " & .effectID & " " & .paused & " " & .playing & " " & .pause_pos & " " & .buf
 end with
end function
