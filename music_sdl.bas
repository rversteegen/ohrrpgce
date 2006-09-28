'' 
'' music_sdl.bas - External music functions implemented in SDL.
''
'' part of OHRRPGCE - see elsewhere for license details
''

option explicit

#include "music.bi"
#include "SDL\SDL.bi"
#include "SDL\SDL_mixer.bi"

'extern
declare sub debug(s$)
declare sub bam2mid(infile as string, outfile as string, useOHRm as integer)
declare function isfile(n$) as integer
declare function soundfile$ (sfxnum%)
declare sub sound_slot_free(byval slot as integer)
declare function next_free_slot() as integer
declare function sound_replay(byval num as integer, byval l as integer) as integer
declare sub sound_debug(s$, byval sample as integer, byval slot as integer)
declare sub sound_dump(s$, slot as integer)

dim shared music_on as integer = 0
dim shared music_vol as integer
dim shared music_paused as integer
dim shared music_song as Mix_Music ptr = NULL
dim shared orig_vol as integer = -1
dim shared xm_vol as integer = MIX_MAX_VOLUME
dim shared mod_playing as integer = 0

'The music module needs to manage a list of temporary files to
'delete when closed, mainly for custom, so they don't get lumped
type delitem
	fname as zstring ptr
	nextitem as delitem ptr
end type

dim shared delhead as delitem ptr = null

sub music_init()	
	dim version as uinteger
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
		audio_buffers = 4096
		
'		SDL_Init(SDL_INIT_VIDEO or SDL_INIT_AUDIO)
		SDL_Init(SDL_INIT_AUDIO)
		
		if (Mix_OpenAudio(audio_rate, audio_format, audio_channels, audio_buffers)) <> 0 then
			Debug "Can't open audio"
			music_on = -1
			SDL_Quit()
			exit sub
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
			mod_playing = 0
		end if
		
		Mix_CloseAudio
		SDL_Quit
		music_on = 0
		
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

sub music_play(songname as string, fmt as music_format)
	if music_on = 1 then
		songname = rtrim$(songname)	'lose any added nulls
		
		if fmt = FORMAT_BAM then
			dim midname as string
			dim as integer bf, flen
			'get length of input file
			bf = freefile
			open songname for binary access read as #bf
			flen = lof(bf)
			close #bf
			'use last 3 hex digits of length as a kind of hash, 
			'to verify that the .bmd does belong to this file
			flen = flen and &h0fff
			midname = songname + "-" + lcase(hex(flen)) + ".bmd"
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
			debug "Could not load song " + songname
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
			if fmt = FORMAT_MOD then
				Mix_VolumeMusic(xm_vol)
			else
				'add a small adjustment because 15 doesn't go into 128
				Mix_VolumeMusic((music_vol * 8) + 8)
			end if
		end if
		
		if fmt = FORMAT_MOD then
			mod_playing = -1
		else
			mod_playing = 0
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
			mod_playing = 0
		end if
	end if
end sub

sub music_setvolume(vol as integer)
	if mod_playing then
		'Separate volume for XMs because they're annoying
		xm_vol = iif(vol=0, 0, (vol * 8) + 8)
		if music_on = 1 then
			Mix_VolumeMusic(xm_vol)
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
	if mod_playing then
		music_getvolume = xm_vol \ 8
	else
		music_getvolume = music_vol
	end if
end function

sub music_fade(targetvol as integer)
'Unlike the original version, this will pause everything else while it
'fades, so make sure it doesn't take too long
	dim vstep as integer = 1
	dim i as integer
	dim cvol as integer
	
	cvol = music_getvolume
	if cvol > targetvol then vstep = -1
	for i = cvol to targetvol step vstep
		music_setvolume(i)
		sleep 10
	next	
end sub


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
  Mix_channelFinished(@SDL_done_playing)
  sound_inited = 1
end sub

sub sound_close
  'trying to free something that's already freed... bad!
  if sound_inited = 0 then exit sub
  
  dim i as integer

    for i = 0 to 7
    with sfx_slots(i)
      if .used then
        Mix_FreeChunk(.buf)
        .paused = 0
        .playing = 0
        .used = 0
	.effectID = 0
        .buf = 0
      end if
    end with
  next
  
  sound_inited = 0
end sub

sub sound_debug(s$, byval sample as integer, byval slot as integer)
  debug "ERROR: " + s$ + " (sample=" + STR$(sample) + ", slot=" + STR$(slot) + ")"
end sub

sub sound_dump(s$, slot as integer)
  with sfx_slots(slot)
    debug s$ + " slot=" + STR$(slot) + ",used=" + STR$(.used) + ",playing=" + STR$(.playing) + ",paused=" + STR$(.paused) + ",effectID=" + STR$(.effectID)
  end with
end sub

function sound_load(byval slot as integer, f as string) as integer
  'slot is the sfx_slots element to use, or -1 to automatically pick one
  'f is the file.
  dim i as integer

  with sfx_slots(slot)
    if .used then
      sound_slot_free(slot)
    end if

    .used = 1
    .buf = Mix_LoadWAV(@f[0])

    if .buf = NULL then return -1
  end with

  return slot 'yup, that's all
  
end function

sub sound_slot_free(byval slot as integer)
  with sfx_slots(slot)
    if .used then
      .used = 0
      .effectID = 0
      .playing = 0
      .paused = 0
      if .buf <> NULL then mix_freechunk(.buf)
      .buf = NULL
    end if
  end with
end sub

function next_free_slot() as integer
  dim i as integer

  'Look for empty slots
  for i = 0 to ubound(sfx_slots)
    if sfx_slots(i).used = 0 then
      return i
    end if
  next

  'Look for silent slots
  for i = 0 to ubound(sfx_slots)
    if sfx_slots(i).playing = 0 and sfx_slots(i).paused = 0 then
      sound_slot_free(i)
      return i
    end if
  next

  return -1 ' no slot found
end function

function sound_replay(byval num as integer, byval l as integer) as integer
  dim i as integer

  for i = 0 to ubound(sfx_slots)
    with sfx_slots(i)
      if .used <> 0 and .playing = 0 and .effectID = num then
        if .paused then
          Mix_Resume(i)
          .paused = 0
        else
          if mix_playchannel(i,.buf,l) = -1 then
            sound_debug "failure to restart sound", num, i
            sound_slot_free i
            return 0 'failure
          end if
          .playing = 1
        end if
        return -1 'success
      end if
    end with
  next

  return 0 'false if not found
end function

sub sound_play(byval num as integer, byval l as integer)
  dim slot as integer

  'first see if this sound is already loaded
  if sound_replay(num, l) then
    exit sub ' successfully played and already-loaded sound
  end if

  slot = next_free_slot()
    
  if slot = -1 then
   sound_debug "no free slots", num, -1
   exit sub
  end if

  sound_load(slot, soundfile(num))

  with sfx_slots(slot)
    if .buf = 0 then
      sound_debug "sfx buffer is zero for sample", num, slot
      exit sub
    end if
    
    if l then l = -1
    if mix_playchannel(slot,.buf,l) = -1 then
      sound_debug "failed to load sfx", num, slot
      exit sub
    end if
    .effectID = num
    .playing = 1

  end with
end sub

sub sound_pause(byval num as integer)
  dim i as integer
  
  for i = 0 to ubound(sfx_slots)
    with sfx_slots(i)
      if .used <> 0 and .effectID = num then
        if .playing <> 0 and .paused <> 0 then
          .paused = 1
          Mix_Pause(i)
        end if
      end if
    end with
  next i  
end sub

sub sound_free(byval num as integer)
  dim i as integer
  for i = 0 to ubound(sfx_slots)
    with(sfx_slots(i))
      if .used <> 0 and .effectID = num then
        sound_slot_free i
      end if
    end with
  next i
end sub

sub sound_stop(byval num as integer)
  dim i as integer

  for i = 0 to ubound(sfx_slots)
    with sfx_slots(i)
      if .used <> 0 and .effectID = num then
        if .playing <> 0 then
          .playing = 0
          .paused = 0
          Mix_HaltChannel(i)
        end if  
      end if
    end with
  next i
end sub

function sound_playing(byval slot as integer) as integer
  with sfx_slots(slot)
    if .used = 0 then return 0
    
    return .playing
    
  end with
end function

function sound_slots as integer
  return ubound(sfx_slots)
end function

sub SDL_done_playing cdecl(byval channel as integer)
  sfx_slots(channel).playing = 0
end sub

