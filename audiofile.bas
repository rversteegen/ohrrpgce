'OHRRPGCE - common routines for inspecting or finding (but not playing) audio files, and text-to-speech
'(C) Copyright 2017 James Paige/OHRRPGCE developers
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#include "config.bi"
#include "util.bi"
#include "common.bi"
#include "string.bi"
#include "loading.bi"
#include "reload.bi"
#include "reloadext.bi"
#include "audiofile.bi"

using Reload.Ext

#ifndef IS_GAME

'#ifdef HAVE_VORBISFILE
#include "vorbis/vorbisfile.bi"
'#endif
#include "lib/mad.bi"

dim shared libvorbisfile as any ptr  'Equal to BADPTR if can't be loaded
dim shared libmad as any ptr  'Equal to BADPTR if can't be loaded

const BADPTR as any ptr = cast(any ptr, -1)

extern "C"

#undef ov_clear
#undef ov_fopen
#undef ov_info
#undef ov_bitrate
#undef ov_time_total
#undef ov_comment
dim shared ov_clear as function(byval vf as OggVorbis_File ptr) as long
dim shared ov_fopen as function(byval path as const zstring ptr, byval vf as OggVorbis_File ptr) as long
dim shared ov_info as function(byval vf as OggVorbis_File ptr, byval link as long) as vorbis_info ptr
dim shared ov_bitrate as function(byval vf as OggVorbis_File ptr, byval link as long) as clong
dim shared ov_time_total as function(byval vf as OggVorbis_File ptr, byval link as long) as double
dim shared ov_comment as function(byval vf as OggVorbis_File ptr, byval link as long) as vorbis_comment ptr

#undef mad_stream_init
#undef mad_stream_finish
#undef mad_stream_buffer
#undef mad_stream_errorstr
#undef mad_header_init
#undef mad_header_decode
dim shared mad_stream_init as sub(byval as mad_stream ptr)
dim shared mad_stream_finish as sub(byval as mad_stream ptr)
dim shared mad_stream_buffer as sub(byval as mad_stream ptr, byval as const ubyte ptr, byval as culong)
dim shared mad_stream_errorstr as function(byval as const mad_stream ptr) as const zstring ptr
dim shared mad_header_init as sub(byval as mad_header ptr)
dim shared mad_header_decode as function(byval as mad_header ptr, byval as mad_stream ptr) as long

end extern


'==========================================================================================
'                                    Examining Files
'==========================================================================================

'Not used anywhere!
function isawav(fi as string) as bool
	if not isfile(fi) then return NO 'duhhhhhh

#define ID(a,b,c,d) asc(a) SHL 0 + asc(b) SHL 8 + asc(c) SHL 16 + asc(d) SHL 24
	dim _RIFF as integer = ID("R","I","F","F") 'these are the "signatures" of a
	dim _WAVE as integer = ID("W","A","V","E") 'wave file. RIFF is the format,
	'dim _fmt_ as integer = ID("f","m","t"," ") 'WAVE is the type, and fmt_ and
	'dim _data as integer = ID("d","a","t","a") 'data are the chunks
#undef ID

	dim chnk_ID as integer
	dim chnk_size as integer
	dim fh as integer
	openfile(fi, for_binary + access_read, fh)

	get #fh, , chnk_ID
	if chnk_ID <> _RIFF then
		close #fh
		return NO 'not even a RIFF file
	end if

	get #fh, , chnk_size 'don't care

	get #fh, , chnk_ID

	if chnk_ID <> _WAVE then
		close #fh
		return NO 'not a WAVE file, pffft
	end if

	'is this good enough? meh, sure.
	close #fh
	return YES
end function

#macro MUSTLOAD(hfile, procedure)
	procedure = dylibsymbol(hfile, #procedure)
	if procedure = NULL then
		dylibfree(hFile)
		hFile = NULL
		return NO
	end if
#endmacro

local function _load_libvorbisfile(libfile as string) as bool
	#ifdef __FB_DARWIN__
		libvorbisfile = dylibload(libfile + ".framework/" + libfile)
	#else
		libvorbisfile = dylibload(libfile)
	#endif
	if libvorbisfile = NULL then
		debuginfo "Couldn't find " & libfile & ", skipping (not an error)"
		return NO
	end if

	MUSTLOAD(libvorbisfile, ov_clear)
	MUSTLOAD(libvorbisfile, ov_fopen)
	MUSTLOAD(libvorbisfile, ov_info)
	MUSTLOAD(libvorbisfile, ov_bitrate)
	MUSTLOAD(libvorbisfile, ov_time_total)
	MUSTLOAD(libvorbisfile, ov_comment)

	debuginfo "Successfully loaded libvorbisfile symbols from " & libfile
	return YES
end function

' Dynamically load functions from libvorbisfile.
' This isn't really necessary! However it avoids errors if:
' -you use an old copy of SDL_mixer.dll that's laying around
'  (which hasn't been compiled to export these symbols)
' -on Mac you're trying to run ohrrpgce-custom directly without bundling
'  (compiling instructions on the wiki tell you to install a standard SDL_mixer.framework in /Library/Frameworks)
' -libvorbisfile isn't installed, on a Unix machine
local function load_vorbisfile() as bool
	if libvorbisfile = BADPTR then return NO
	if libvorbisfile then return YES
	' Unix
	#ifdef __FB_DARWIN__
		if _load_libvorbisfile("Vorbis") then return YES
	#else
		if _load_libvorbisfile("vorbisfile") then return YES
	#endif
	' libvorbisfile is statically linked into our Windows and Mac SDL_mixer builds
	' and Windows SDL2_mixer.
	' We can load them even if we're using a different music backend
	if _load_libvorbisfile("SDL_mixer") then return YES
	if _load_libvorbisfile("SDL2_mixer") then return YES
	libvorbisfile = BADPTR
	return NO
end function

local function _load_libmad(libfile as string) as bool
	#ifdef __FB_DARWIN__
		libmad = dylibload(libfile + ".framework/" + libfile)
	#else
		libmad = dylibload(libfile)
	#endif
	if libmad = NULL then
		debuginfo "Couldn't find " & libfile & ", skipping (not an error)"
		return NO
	end if

	MUSTLOAD(libmad, mad_stream_init)
	MUSTLOAD(libmad, mad_stream_finish)
	MUSTLOAD(libmad, mad_stream_buffer)
	MUSTLOAD(libmad, mad_stream_errorstr)
	MUSTLOAD(libmad, mad_header_init)
	MUSTLOAD(libmad, mad_header_decode)

	debuginfo "Successfully loaded libmad symbols from " & libfile
	return YES
end function

' Dynamically load functions from libmad
local function load_libmad() as bool
	if libmad = BADPTR then return NO
	if libmad then return YES
	' Unix
	if _load_libmad("mad") then return YES
	' libmad is statically linked into our Windows SDL_mixer and SDL2_mixer builds.
	' Very unlikely to be linked on Linux.
	' We can load them even if we're using a different music backend
	if _load_libmad("SDL_mixer") then return YES
	if _load_libmad("SDL2_mixer") then return YES
	libmad = BADPTR
	return NO
end function

' First index is number of channels, second is quality
dim oggenc_quality_levels(1 to 2, -1 to 10) as integer = { _
	{32, 48, 60, 70, 80, 86, 96, 110, 120, 140, 160, 240}, _
	{45, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 500} _
}

'Return the oggenc quality level most closely matching this bitrate. Assumes 44.1kHz.
function oggenc_quality(channels as integer, bitrate as integer) as integer
        if bitrate <= 0 then return -1
        channels = bound(channels, 1, 2)
        dim bestmatch as double = 999
        dim bestidx as integer
        for idx as integer = lbound(oggenc_quality_levels, 2) to ubound(oggenc_quality_levels, 2)
                dim ratio as double = bitrate / oggenc_quality_levels(channels, idx)
                if ratio < 1 then ratio = 1 / ratio
                if ratio < bestmatch then bestmatch = ratio : bestidx = idx
        next
        return bestidx
end function

' Return one or more lines of text describing bitrate, sample rate, channels, and comments of an .ogg Vorbis file
function read_ogg_metadata(songfile as string) as string
	if load_vorbisfile() = NO then
		return !"Can't read OGG metadata: missing library\n"
	end if
	'We don't unload libvorbisfile afterwards. No need.

'#ifdef HAVE_VORBISFILE
	dim oggfile as OggVorbis_File
	dim errcode as integer
	log_openfile songfile
	errcode = ov_fopen(songfile, @oggfile)
	if errcode then
		dim msg as string
		select case errcode
			case OV_EREAD:      msg = "ERROR: Can't read file!"
			case OV_ENOTVORBIS: msg = "ERROR: Not a Vorbis (audio) .ogg file!"
			case OV_EVERSION:   msg = "ERROR: Unknown .ogg format version!"
			case OV_EBADHEADER: msg = "ERROR: Corrupt .ogg file!"
			case else:          msg = "ERROR: Can't parse file (error " & errcode & ")"
		end select
		debug "ov_fopen( " & songfile & ") failed : " & msg
		return msg
	end if

	dim ret as string

	' Length
	dim length as double
	length = ov_time_total(@oggfile, -1)
	if length <> OV_EINVAL then
		ret &= "Length:   " & format_duration(length) & !"\n"
	else
		debug "ov_time_total failed on " & songfile
	end if

	' Bit and sample rate, channels
	dim info as vorbis_info ptr
	info = ov_info(@oggfile, -1)
	if info then
		ret &= info->channels & " channel(s)  " &  format(info->rate / 1000, "0.0") & !"kHz  \n"
	else
		debug "ov_info failed on " & songfile
	end if

	' Bitrate
	dim msg as string
	dim bitrate as integer = ov_bitrate(@oggfile, -1)
	if bitrate > 0 then
		msg &= cint(bitrate / 1000) & "kbps"
	elseif info andalso info->bitrate_nominal > 0 then
		' Don't show both the average and the nominal bitrates, that's too much info
		msg &= cint(info->bitrate_nominal / 1000) & "kbps (Nominal)"
	end if
	if info andalso info->bitrate_nominal > 0 andalso in_bound(info->channels, 1, 2) then
		'Compute the quality from the nominal (target) rather than actual quality level
		'because it tells what it was encoded with, which is useful to know.
		msg &= " (quality ~" & oggenc_quality(info->channels, info->bitrate_nominal \ 1000) & ")"
	end if
	if msg <> "" then ret &= "Bitrate:  " & msg & !"\n"

	' Comments
	dim comments as vorbis_comment ptr
	comments = ov_comment(@oggfile, -1)
	if comments then
		ret &= !"\n"
		for idx as integer = 0 TO comments->comments - 1
			' .ogg comment strings are UTF8, not null-terminated
			' They're usually formatted like "AUTHOR=virt", but sometimes lower case or no 'tag' name.
			dim ucmmt as ustring, cmmt as string
			ucmmt = blob_to_string(comments->user_comments[idx], comments->comment_lengths[idx])
			cmmt = utf8_to_OHR(ucmmt)
			dim as integer eqpos = instr(cmmt, "="), spcpos = instr(cmmt, " ")
			if eqpos > 1 andalso (spcpos = 0 orelse spcpos > eqpos) then
				'Seems to be a tag, format it like "Author: virt"
				cmmt = titlecase(left(cmmt, eqpos - 1)) & ": " & mid(cmmt, eqpos + 1)
			end if
                        ret &= cmmt & !"\n"
		next
	else
		debug "ov_comment failed: " & songfile
	end if

	ov_clear(@oggfile)
	return rtrim(ret)
' #else
' 	return "(OGG metadata not enabled in this build)"
' #endif
end function

' Returns metadata, and optionally modifies filetype to the actual file type (eg MP2 file).
' Doesn't read embedded ID3 tags
' This depends on libmad. It will be present on Windows, and probably on Linux, but not Macs.
function read_mp3_metadata(songfile as string, byref filetype as string = "") as string
	if load_libmad() = NO then
		return !"Can't read MP3 metadata: need libmad\n"
	end if

	' MP3 files doesn't have a header, it's a stream format, a sequence of frames
	' each with its own header, mixed in with arbitrary other data, like ID3 tags.
	' To compute stuff like the duration you need to scan the whole file!
	' libmad is quite a low level library, so doesn't have a function to do that!

	dim duration as double      'In seconds
	dim bits as longint         'bits per second integrated over time
	dim samplerate as integer   'Hz; maximum samplerate of any frame
	dim channels as integer = 1 '1 or 2.
	dim layer as integer        '1, 2, or 3: MP1, MP2, MP3

	' It's a pain to feed libmad just the parts of the file it needs to read,
	' and because MP3 frames are less than 4KB, it won't really save any time anyway.
	dim buf as string = read_file(songfile)
	if buf = "" then return ""

	dim numerrs as integer
	dim stream as mad_stream
	dim header as mad_header
	mad_header_init(@header)
	mad_stream_init(@stream)
	mad_stream_buffer(@stream, @buf[0], len(buf))
	do
		if mad_header_decode(@header, @stream) <> 0 then
			'if MAD_RECOVERABLE(stream.error) then
			if stream.error = MAD_ERROR_BUFLEN then
				'No more data in the buffer
				exit do
			elseif stream.error <> MAD_ERROR_LOSTSYNC then
				'LOSTSYNC happens if other data like ID3 tags are embedded in the file
				if numerrs = 0 then
					debuginfo "error parsing " & songfile & " @ " _
						  & (stream.this_frame - stream.buffer) & ": " & *mad_stream_errorstr(@stream)
				end if
				numerrs += 1
			end if
		else
			dim frame_len as double = header.duration.seconds + header.duration.fraction / MAD_TIMER_RESOLUTION
			duration += frame_len
			samplerate = large(samplerate, header.samplerate)
			bits += frame_len * header.bitrate
			if header.mode <> MAD_MODE_SINGLE_CHANNEL then channels = 2
			layer = large(layer, header.layer)
		end if
	loop
	mad_stream_finish(@stream)

	filetype = "MPEG Layer " & string(layer, "I") & " (MP" & layer & !")"

	' Bit and sample rate, channels
	return "Length:   " & format_duration(duration) & !"\n" & _
	       channels & " channel(s)  " & format(samplerate / 1000, "0.0") & !"kHz  \n" _
	       "Bitrate:  " & cint(bits / duration / 1000) & !"kbps\n"
end function


#endif  'not IS_GAME


' Check that an audio file really is the format it appears to be
' (This isn't and was never really necessary...)
FUNCTION valid_audio_file (filepath as string) as bool
 DIM as string hdmask, realhd
 DIM as integer musfh, chk
 chk = getmusictype(filepath)

 SELECT CASE chk
  CASE FORMAT_BAM
   hdmask = "    "
   realhd = "CBMF"
  CASE FORMAT_MIDI
   hdmask = "    "
   realhd = "MThd"
  CASE FORMAT_XM
   hdmask = "                 "
   realhd = "Extended Module: "
  'Other supported module formats are missing, but I don't see any point adding them
 END SELECT

 IF LEN(hdmask) THEN
  OPENFILE(filepath, FOR_BINARY + ACCESS_READ, musfh)
  GET #musfh, 1, hdmask
  CLOSE #musfh
  IF hdmask <> realhd THEN return NO
 END IF

 RETURN YES
END FUNCTION

function getmusictype (file as string) as MusicFormatEnum
	if real_isfile(file) = NO then
		'no further checking if this is a directory
		return 0
	end if

	dim extn as string, chk as integer
	extn = lcase(justextension(file))

	'special case
	if str(cint(extn)) = extn then return FORMAT_BAM

	select case extn
	case "bam"
		chk = FORMAT_BAM
	case "mid", "bmd"
		chk = FORMAT_MIDI
	case "xm"
		chk = FORMAT_XM
	case "it"
		chk = FORMAT_IT
	case "wav"
		chk = FORMAT_WAV
	case "ogg"
		chk = FORMAT_OGG
	case "mp3"
		chk = FORMAT_MP3
	case "s3m"
		chk = FORMAT_S3M
	case "mod"
		chk = FORMAT_MOD
	case else
		debug "unknown format: " & file & " - " & extn
		chk = 0
	end select

	return chk
end function


'==========================================================================================
'                                     Music/SFX Lumps
'==========================================================================================


function find_music_lump(songnum as integer) as string
  DIM songbase as string, songfile as string

  songbase = workingdir & SLASH & "song" & songnum
  songfile = ""

  IF real_isfile(songbase & ".mp3") THEN
    songfile = songbase & ".mp3"
  ELSEIF real_isfile(songbase & ".ogg") THEN
    songfile = songbase & ".ogg"
  ELSEIF real_isfile(songbase & ".mod") THEN
    songfile = songbase & ".mod"
  ELSEIF real_isfile(songbase & ".xm") THEN
    songfile = songbase & ".xm"
  ELSEIF real_isfile(songbase & ".s3m") THEN
    songfile = songbase & ".s3m"
  ELSEIF real_isfile(songbase & ".it") THEN
    songfile = songbase & ".it"
  ELSEIF real_isfile(songbase & ".mid") THEN
    songfile = songbase & ".mid"
  ELSEIF real_isfile(songbase & ".bam") THEN
    songfile = songbase & ".bam"
  ELSEIF real_isfile(game & "." & songnum) THEN
    songfile = game & "." & songnum ' old-style BAM naming scheme
  END IF
  'Can import wav (converting to ogg), but don't need to look for it
  RETURN songfile
END FUNCTION

' Translate sfx number to lump name
function find_sfx_lump (sfxnum as integer) as string
	dim as string sfxbase

	sfxbase = workingdir & SLASH & "sfx" & sfxnum
	if real_isfile(sfxbase & ".ogg") THEN
		return sfxbase & ".ogg"
	elseif real_isfile(sfxbase & ".mp3") then
		return sfxbase & ".mp3"
	elseif real_isfile(sfxbase & ".wav") then
		return sfxbase & ".wav"
	else
		return ""
	end if
end function

'Find out whether each song or sfx actually exists rather than being a blank record.
'Fills in imported_files().
'imported_files() should be pre-initialised to right length!
'sfx: if true, check for sfx instead of files.
sub list_of_imported_songs_or_sfx(imported_files() as bool, sfx as bool)
#ifdef IS_CUSTOM
	flusharray imported_files(), , NO
	dim filelist() as string
	findfiles workingdir, ALLFILES, fileTypeFile, , filelist()
	for idx as integer = 0 to ubound(filelist)
		dim as integer snumber = -1  'song or sfx number
		dim as string basename = trimextension(filelist(idx)), extn = justextension(filelist(idx))
		'Just accept unknown audio file extensions
		if sfx then
			if starts_with(basename, "sfx") then
				snumber = str2int(mid(basename, 4), -1, YES)
			end if
		else
			if starts_with(basename, "song") then
				snumber = str2int(mid(basename, 5), -1, YES)
			else 'if basename = archinym then
				snumber = str2int(extn, -1, YES)  'BAM file
			end if
		end if

		if snumber > -1 andalso snumber <= ubound(imported_files) then imported_files(snumber) = YES
	next
#else
	'Don't need such superfluous features bloating Game
	flusharray imported_files(), , YES
#endif
end Sub


'==========================================================================================
'                                     Text-to-speech
'==========================================================================================

#IFDEF WITH_TTS

DIM SHARED voice_sound_slot as integer = -1


FUNCTION speaker_for_text(text as string) as string
 DIM where as integer = INSTR(text, ":")
 IF where THEN
  RETURN LCASE(TRIM(LEFT(text, where - 1)))
 END IF
 RETURN "default"
END FUNCTION

'A speaker is the name of a speaker, and identifies a voice.
'A voice is a Node ptr (under /voices/), which is either an alias for
'another voice, or a flite voice and set of flite arguments.
'A voiceid is a string used to identify a flite voice.
FUNCTION get_voice(byval speaker as string) as Node ptr
 DIM gen_root as NodePtr = get_general_reld()
 DIM voice as NodePtr
 FOR safety as integer = 1 TO 4
  voice = NodeByPath(gen_root, "/voices/" & speaker)
  'Alias to another voice?
  speaker = GetChildNodeStr(voice, "alias")
  IF LEN(speaker) THEN CONTINUE FOR

  IF voice THEN RETURN voice

  'Missing? Fallback to default, which may not exist
  RETURN NodeByPath(gen_root, "/voices/default")
 NEXT
END FUNCTION

FUNCTION voice_for_text(text as string) as Node ptr
 RETURN get_voice(speaker_for_text(text))
END FUNCTION

FUNCTION describe_voice(voice as Node ptr) as string
 IF voice = NULL THEN RETURN "(None, no default)"
 DIM ret as string = GetChildNodeStr(voice, "name")
 IF LEN(ret) = 0 THEN ret = "<name>"
 DIM al as string = GetChildNodeStr(voice, "alias")
 IF LEN(al) THEN ret &= ": Alias to " & al
 DIM nod as Node ptr  = GetChildByName(voice, "voiceid")
 IF nod THEN
  DIM voiceid as string = GetString(nod)
  ret &= ": " & IIF(LEN(voiceid), voiceid, "None")
 END IF
 RETURN ret
 'Ignore the arguments
END FUNCTION

'voice: override the default voice for the text, which is determined by the speaker
'Only one piece of text can be spoken at once (make voice_sound_slot an argument to change that)
SUB speak_text(text as string, byval voice as Node ptr = NULL)
 IF voice_sound_slot > -1 THEN sound_unload voice_sound_slot

 IF voice = NULL THEN
  voice = voice_for_text(text)
  IF voice = NULL THEN EXIT SUB
 END IF

 DIM voiceid as string = GetChildNodeStr(voice, "voiceid", "!kal")
 IF LEN(voiceid) = 0 THEN EXIT SUB  'Silence

 IF starts_with(voiceid, "m-") ORELSE starts_with(voiceid, "f-") THEN voiceid = MID(voiceid, 3)

 DIM voicefile as string
 IF voiceid[0] = ASC("!") THEN
  'Voices compiled into flite
  voicefile = MID(voiceid, 2)
 ELSE
  'Downloaded voices (flite's bin/get_voices script can download these)
  voicefile = get_support_dir() & SLASH "flite_voices" SLASH "cmu_us_" & voiceid & ".flitevox"
 END IF

 DIM spoken_text as string = text
 replacestr(spoken_text, """", "")   'TODO: escape properly
 DIM temp as integer = INSTR(spoken_text, ":")
 IF temp THEN spoken_text = MID(spoken_text, temp + 1)

 'Build list of arguments to flite
 DIM outfile as string = tmpdir & "voice.wav"
 DIM args as string = " -voice " & voicefile & " -t """ & spoken_text & """"
 ' Omit the -o arg to have flite play the audio file itself. That's better with music_sdl,
 ' which doesn't play low-samplerate files correctly.
 args &= " -o " & escape_filename(outfile)

 DIM arg as Node ptr = FirstChild(voice)
 WHILE arg
  DIM argname as string = NodeName(arg)
  IF starts_with(argname, "arg:") THEN
   args &= " -s " & MID(argname, 5) & "=" & GetString(arg)
  END IF
  arg = NextSibling(arg)
 WEND

 DIM flite as string = find_helper_app("flite")
 IF LEN(flite) = 0 THEN visible_debug "Can't find flite program. http://festvox.org/flite/" : EXIT SUB

 'open_process(flite, args, NO, NO)
 ? flite & args
 IF checked_system(flite & args) = 0 THEN
  voice_sound_slot = sound_play_file(outfile)
 END IF
END SUB

'Stops speak_text()
SUB stop_speaking()
 IF voice_sound_slot > -1 THEN
  sound_unload voice_sound_slot
  voice_sound_slot = -1
  safekill tmpdir & "voice.wav"
 END IF
END SUB

#ELSE

'Avoid some #ifdefs by providing this stub always
SUB stop_speaking()
END SUB

#ENDIF
