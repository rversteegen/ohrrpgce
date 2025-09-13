'OHRRPGCE - Audiere audio output
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
'
'This is not an actual music backend; it is included as part of music_native and music_native2
'It plays sound effects using Audiere.
'music_native/native2 play non-MIDI music by treating them as sound effects.
'music_audiere has no limit on number sound effects playing at once.

#include "config.bi"
#include "common.bi"
#include "const.bi"
#include "util.bi"
#include "music.bi"
#include "audwrap/audwrap.bi"


TYPE SoundEffectSlot EXTENDS SoundEffectSlotBase
  audiereID as integer 'audwrap slot number
  paused as bool
END TYPE

extern sfx_slots() as SoundEffectSlot ptr


'Number of times sound_init called. Must be non-zero for anything but _init to work
dim shared sound_init_count as integer


sub sound_init
  sound_init_count += 1
  'debug "sound init = " & sound_init_count
  ?"sound init " , sound_init_count

  if sound_init_count <> 1 then exit sub

  if AudInit() then
    exit sub ':(
  end if

  redim sfx_slots(10)
?"slots = " & ubound(sfx_slots)


  'music_init 'for safety (don't worry, they won't recurse (much))
end sub

sub sound_close
  sound_init_count -= 1
  debug "sound close = " & sound_init_count

  'trying to free something that's already freed... bad!
  if sound_init_count <> 0 then exit sub
  'debug "sound_close"

  sound_reset()

  AudClose()

  'music_close
end sub

sub sound_reset
  for slot as integer = 0 to ubound(sfx_slots)
    sound_unload(slot)
  next
end sub

sub sound_play(slot as integer, loopcount as integer, volume as single)
  'debug ">>sound_play(" & slot & ", " & loopcount & "," & volume & ")"
  if sfx_slots(slot) = NULL then debug "sound_play: bad slot " & slot : exit sub

  with *sfx_slots(slot)
  'debug str(AudIsPlaying(.audiereID))
    if AudIsPlaying(.audiereID) <> 0 and .paused = NO then
      'debug "<<already playing"
      exit sub
    end if

    AudPlay(.audiereID)
    AudSetVolume(.audiereID, bound(volume, 0., 1.))

    'for consistency with other backends, can't change loop behaviour of a paused effect
    if .paused = NO then AudSetRepeat(.audiereID, loopcount)
    .paused = NO
  end with
  'debug "<<done"
end sub

sub sound_pause(slot as integer)
  'debug ">>sound_pause(" & slot & ")"
  if sfx_slots(slot) = NULL then exit sub

  with *sfx_slots(slot)
    if sound_playing(slot) = 0 OR .paused then
      exit sub
    end if

    .paused = YES
    AudPause(.audiereID)
  end with
end sub

sub sound_stop(slot as integer)
  'debug ">>sound_stop(" + slot + ")"
  if sfx_slots(slot) = NULL then exit sub

  with *sfx_slots(slot)
    AudStop(.audiereID)
    .paused = NO
  end with
end sub

sub sound_setvolume(slot as integer, volume as single)
  if sfx_slots(slot) = NULL then exit sub
  AudSetVolume(sfx_slots(slot)->audiereID, bound(volume, 0., 1.))
end sub

function sound_getvolume(slot as integer) as single
  if sfx_slots(slot) = NULL then return 0.
  return AudGetVolume(sfx_slots(slot)->audiereID)
end function

sub sound_free(num as integer)
  for slot as integer = 0 to ubound(sfx_slots)
    if sfx_slots(slot) andalso sfx_slots(slot)->effectID = num then
      sound_unload(slot)
    end if
  next
end sub

function sound_playing(slot as integer) as bool
  if sfx_slots(slot) = NULL then return NO
  return AudIsPlaying(sfx_slots(slot)->audiereID) <> 0
end function

function sound_getlength(slot as integer) as double
  if sfx_slots(slot) = NULL then return -1.0
  return AudGetLength(sfx_slots(slot)->audiereID)
end function

function sound_seekable(slot as integer) as bool
  if sfx_slots(slot) = NULL then return NO
  return AudIsSeekable(sfx_slots(slot)->audiereID) <> 0
end function

function sound_gettime(slot as integer) as double
  if sfx_slots(slot) = NULL then return -1.0
  return AudGetPosition(sfx_slots(slot)->audiereID)
end function

function sound_settime(slot as integer, position as double) as bool
  if sfx_slots(slot) = NULL then return NO
  AudSetPosition(sfx_slots(slot)->audiereID, position)
  return YES
end function


'-------------------------------------------------------------------------------


/'
' Returns the first sound slot with the given sound effect ID (num);
' if the sound is not loaded, returns -1.
function sound_slot_with_id(num as integer) as integer
  dim slot as integer
  for slot = 0 to ubound(sfx_slots)
    if sfx_slots(slot) = NULL then continue for
    with *sfx_slots(slot)
      'debug "slot = " & slot & ", used = " & .used & ", effID = " _
      '      & .effectID & ", sndID = " & .audiereID & ", AudIsValid = " & AudIsValidSound(.audiereID)
      if (.effectID = num or num = -1) andalso AudIsValidSound(.audiereID) then return slot
    end with
  next
  return -1
end function
'/

'Loads a sound into a slot, and marks its ID num (equal to OHR sfx number).
'Returns the slot number, or -1 if an error occurs.
function sound_load overload(lump as Lump ptr, mode as SoundPlayMode, num as integer = -1) as integer
  return -1
end function

function sound_load(fname as string /', mode as SoundPlayMode'/, num as integer = -1) as integer
  ' 1. allocate space in the sound pool
  ' 2. load the sound

  dim slot as integer

  'iterate through the pool
  for slot = 0 to ubound(sfx_slots)
    if sfx_slots(slot) = NULL then exit for
  next

  'otherwise, slot will be left =ing sfx_slots size + 1
  if slot = ubound(sfx_slots) + 1 then
    'Grow the sound pool
?"growing " & ubound(sfx_slots)
    redim preserve sfx_slots(ubound(sfx_slots) * 1.5)
  end if

  'ok, now slot points at a valid slot. goody.

  ' 2. load the sound

  dim extn as string = justextension(fname)
  dim audslot as integer  'Audiere sound number
  log_openfile fname
'  if extn = "mp3" or extn = "ogg" then
    audslot = AudLoadSound(fname, YES)  'Streaming
/'  else
    audslot = AudLoadSound(fname, NO)  'Don't stream
  end if
'/

  if audslot = -1 then return -1 'crap

  'if we got this far, yes!
  sfx_slots(slot) = new SoundEffectSlot
  with *sfx_slots(slot)
    .audiereID = audslot
    .effectID = num
  end with

  return slot
end function

'Unloads a sound loaded in a slot. TAKES A SLOT, NOT AN SFX NUMBER!
sub sound_unload(slot as integer)
  dim byref sfxslot as SoundEffectSlot ptr = sfx_slots(slot)
  if sfxslot then
    if AudIsValidSound(sfxslot->audiereID) then AudUnloadSound(sfxslot->audiereID)
    delete sfxslot
    sfxslot = NULL
  end if
end sub
