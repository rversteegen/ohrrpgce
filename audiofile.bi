'OHRRPGCE - Audio file inspection routines
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#IFNDEF AUDIOFILE_BI
#DEFINE AUDIOFILE_BI

#include "reload.bi"

'Used for soundeffects too
ENUM MusicFormatEnum
	FORMAT_UNSPECIFIED = 0
	FORMAT_BAM = 1
	FORMAT_MIDI = 2
	FORMAT_MOD = 4
	FORMAT_OGG = 8
	FORMAT_MP3 = 16
	FORMAT_XM = 32
	FORMAT_IT = 64
	FORMAT_S3M = 128
	FORMAT_MODULES = FORMAT_MOD or FORMAT_XM or FORMAT_IT or FORMAT_S3M
	FORMAT_WAV = 256
	FORMAT_FLAC = 512  'Not used or supported yet
END ENUM

#define VALID_SFX_FORMAT (FORMAT_WAV or FORMAT_OGG or FORMAT_MP3)
'' Music=all
#define VALID_MUSIC_FORMAT (FORMAT_BAM or FORMAT_MIDI or FORMAT_MODULES or FORMAT_OGG or FORMAT_MP3 or FORMAT_WAV)


DECLARE FUNCTION isawav(fi as string) as bool
DECLARE FUNCTION read_ogg_metadata(songfile as string) as string
DECLARE FUNCTION read_mp3_metadata(songfile as string, byref filetype as string = "") as string
DECLARE FUNCTION valid_audio_file (filepath as string) as bool
DECLARE FUNCTION getmusictype (file as string) as MusicFormatEnum

DECLARE FUNCTION find_music_lump (songnum as integer) as string
DECLARE FUNCTION find_sfx_lump (sfxnum as integer) as string
DECLARE SUB list_of_imported_songs_or_sfx(imported_files() as bool, sfx as bool)

#IFDEF WITH_TTS
DECLARE FUNCTION speaker_for_text(text as string) as string
DECLARE FUNCTION get_voice(byval voiceid as string) as Reload.Node ptr
DECLARE FUNCTION voice_for_text(text as string) as Reload.Node ptr
DECLARE FUNCTION describe_voice(voice as Reload.Node ptr) as string
DECLARE SUB speak_text(text as string, voice as Reload.Node ptr = NULL)
#ENDIF
DECLARE SUB stop_speaking()

EXTERN oggenc_quality_levels(1 to 2, -1 to 10) as integer

#ENDIF
