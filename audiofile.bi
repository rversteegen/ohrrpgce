#IFNDEF AUDIOFILE_BI
#DEFINE AUDIOFILE_BI


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
	FORMAT_WAV = 256
END ENUM

'' FX=WAV or OGG only, Music=all but WAV and MP3
#define VALID_FX_FORMAT (FORMAT_WAV or FORMAT_OGG or FORMAT_MP3)
#define VALID_MUSIC_FORMAT (FORMAT_BAM or FORMAT_MIDI or FORMAT_MOD or FORMAT_OGG or FORMAT_MP3 or FORMAT_XM or FORMAT_IT or FORMAT_S3M)
'SDL_Mixer crashes on a lot of MP3s
#if not defined(MUSIC_SDL_BACKEND)
#define PREVIEWABLE_FX_FORMAT (FORMAT_WAV or FORMAT_OGG or FORMAT_MP3)
#define PREVIEWABLE_MUSIC_FORMAT (FORMAT_BAM or FORMAT_MIDI or FORMAT_MOD or FORMAT_OGG or FORMAT_MP3 or FORMAT_XM or FORMAT_IT or FORMAT_S3M)
#else
#define PREVIEWABLE_FX_FORMAT (FORMAT_WAV or FORMAT_OGG)
#define PREVIEWABLE_MUSIC_FORMAT (FORMAT_BAM or FORMAT_MIDI or FORMAT_MOD or FORMAT_OGG or FORMAT_XM or FORMAT_IT or FORMAT_S3M)
#endif


DECLARE FUNCTION isawav(fi as string) as bool
DECLARE SUB read_ogg_metadata(songfile as string, menu() as string)
DECLARE FUNCTION valid_audio_file (filepath as string) as bool
DECLARE FUNCTION getmusictype (file as string) as MusicFormatEnum

DECLARE FUNCTION find_music_lump (songnum as integer) as string
DECLARE FUNCTION find_sfx_lump (sfxnum as integer) as string

EXTERN oggenc_quality_levels(1 to 2, -1 to 10) as integer

#ENDIF
