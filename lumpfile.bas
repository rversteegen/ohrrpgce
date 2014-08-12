'OHRRPGCE COMMON - Lumped file format routines
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#include "config.bi"
#include "common.bi"
#include "lumpfile.bi"
#include "lumpfilewrapper.bi"


declare function matchmask(match as string, mask as string) as integer

declare sub Lump_destruct(byref this as Lump)
declare sub LumpedLump_destruct (byref this as LumpedLump)
declare sub LumpedLump_writetofile(byref this as LumpedLump, byval fileno as integer, byval position as integer)
declare function LumpedLump_read(byref this as LumpedLump, byval position as integer, byval bufr as any ptr, byval size as integer) as integer
declare sub FileLump_destruct (byref this as FileLump)
declare sub FileLump_open(byref this as FileLump)
declare sub FileLump_close(byref this as FileLump)
declare sub FileLump_writetofile(byref this as FileLump, byval fileno as integer, byval position as integer)
declare function FileLump_read(byref this as FileLump, byval position as integer, byval bufr as any ptr, byval size as integer) as integer

dim shared lumpvtable(LT_NUM - 1) as LumpVTable_t
LMPVTAB(LT_LUMPED, LumpedLump_,  QLMP(destruct),       NULL,       NULL,        QLMP(writetofile), NULL, QLMP(read))
LMPVTAB(LT_FILE,   FileLump_,    QLMP(destruct),       QLMP(open), QLMP(close), QLMP(writetofile), NULL, QLMP(read))


#ifdef IS_GAME
 EXTERN running_as_slave as integer
#endif


'----------------------------------------------------------------------
'                          LumpIndex class


sub construct_LumpIndex(byref this as LumpIndex)
	'Could call constructor too, but zeroed memory doesn't need it
	'this.numlumps = 0
	this.tablesize = 512
	'this.first = NULL
	'this.last = NULL
	dlist_construct(this.lumps.generic, offsetof(Lump, seq))
	this.table = callocate(sizeof(any ptr) * this.tablesize)
	this.fhandle = 0
	this.unlumpeddir = ""
end sub

sub destruct_LumpIndex(byref this as LumpIndex)
	dim as Lump ptr lmp, temp

	if this.fhandle then close this.fhandle

	lmp = this.lumps.first
	while lmp
		temp = lmp->seq.next
		lmp->index = NULL  'prevents the destructor from bothering to unlink
		lumpvtable(lmp->type).destruct(*lmp)
		deallocate(lmp)
		lmp = temp
	wend

	deallocate(this.table)

	this.Destructor()  'for strings
end sub

sub LumpIndex_addlump(byref this as LumpIndex, byval lump as Lump ptr)
	dim hash as unsigned integer
	dim lmpp as Lump ptr ptr
	
	hash = strhash(lump->lumpname)
	lmpp = @this.table[hash mod this.tablesize]
	while *lmpp
		lmpp = @(*lmpp)->bucket_chain
	wend
	*lmpp = lump

	lump->index = @this

	dlist_append(this.lumps.generic, lump)
end sub

/' FIXME: looks totally broke. Where's the destructor call?
sub LumpIndex_dellump(byref this as LumpIndex, byval lump as Lump ptr)
	dim hash as unsigned integer
	dim lmpp as Lump ptr ptr
	
	hash = strhash(lump->lumpname)
	lmpp = @this.table[hash mod this.tablesize]
	while *lmpp
		if *lmpp = lump then
			*lmpp = lump->bucket_chain
			exit while
		end if
		lmpp = @(*lmpp)->bucket_chain
	wend
	lump->bucket_chain = NULL

	dlist_remove(this.lumps.generic, lump)
	lump->index = NULL	
end sub
'/

'case sensitive
function LumpIndex_findlump(byref this as LumpIndex, lumpname as string) as Lump ptr
	dim hash as unsigned integer
	dim lmp as Lump ptr

	hash = strhash(lumpname)
	lmp = this.table[hash mod this.tablesize]
	while lmp
		if lmp->lumpname = lumpname then return lmp
		lmp = lmp->bucket_chain
	wend

	return NULL
end function

'verify integrity and print contents
sub LumpIndex_debug(byref this as LumpIndex)
	dim lmp as Lump ptr
	dim lumped as LumpedLump ptr
	dim numlumps as integer = 0

	debug "===LumpIndex_debug==="

	for i as integer = 0 to this.tablesize - 1
		lmp = this.table[i]
		while lmp
			numlumps += 1
			if (strhash(lmp->lumpname) mod this.tablesize) <> i then
				debug "LumpIndex_debug error: lump in wrong bucket"
			end if
			lmp = lmp->bucket_chain
		wend
	next

	if numlumps <> this.lumps.numitems then
		debug "error: " & numlumps & " lumps in table, " & this.lumps.numitems & " recorded"
	end if

	numlumps = 0
	lmp = this.lumps.first
	do
		numlumps += 1
		debug lmp->lumpname
		if lmp->type = LT_LUMPED then
			lumped = cast(LumpedLump ptr, lmp)
			debug "  at " & lumped->offset & " len " & lumped->length
		elseif lmp->type = LT_FILE then
			debug "  in " + this.unlumpeddir
		end if
		if lmp->seq.next = NULL then
			if lmp <> this.lumps.last then
				debug "error: ->last corrupt"
			end if
			exit do
		end if
		lmp = lmp->seq.next
	loop

	if numlumps <> this.lumps.numitems then
		debug "error: " & numlumps & " lumps chained, " & this.lumps.numitems & " recorded"
	end if

	debug "====================="
end sub


'----------------------------------------------------------------------
'                           Lump base class


'Not intended to be called on a Lump ptr, instead is used as default destructor of subclasses
'FIXME: broken, destructor not called!
'FIXME: this isn't used, and shouldn't be, I think
private sub Lump_destruct(byref this as Lump)
	if this.opencount then
		debug this.lumpname + " at destruction had nonzero opencount " & this.opencount
	end if
	if this.index then
		'LumpIndex_dellump(*this.index, @this)  'FIXME: best idea?
	end if
end sub

'aka ref()
sub Lump_open(byref this as Lump)
	if lumpvtable(this.type).open = 0 then
		'default (which I can't be bothered to put in a separate function and stick in the vtable)
		this.opencount += 1
	else
		lumpvtable(this.type).open(this)
	end if
end sub

'aka unref()
sub Lump_close(byref this as Lump)
	if lumpvtable(this.type).close = 0 then
		this.opencount -= 1
	else
		lumpvtable(this.type).close(this)
	end if
end sub

'returns true on success
function Lump_unlumpfile(byref this as Lump, whereto as string) as integer
	dim dest as string
	dim of as integer

	if @this = 0 then
		debug "Null lump error"
		return NO
	end if
	if lumpvtable(this.type).writetofile = 0 then
		debug "lump writetofile method not supported"
		return NO
	end if

	dest = whereto + this.lumpname
	if fileiswriteable(dest) = 0 then
		debug "Could not unlump to " + dest
		return NO
	end if
	of = freefile
	open dest for binary access write as #of   'Truncates
	lumpvtable(this.type).writetofile(this, of, 1)
	close of
	return YES
end function

function Lump_read(byref this as Lump, byval position as integer, byval bufr as any ptr, byval size as integer) as integer
	if @this = 0 then
		debug "Null lump error"
		return 0
	end if
	return lumpvtable(this.type).read(this, position, bufr, size)
end function


'----------------------------------------------------------------------
'                           16-bit records
'Why is this here? Because according to the Plan, binsize expanding may be
'handled transparently by the Lump object rather than actually occurring


function loadrecord (buf() as integer, byval fh as integer, byval recordsize as integer, byval record as integer = -1, context as string = "") as bool
'common sense alternative to loadset, setpicstuf
'loads 16bit records in an array
'buf() = buffer to load shorts into, starting at buf(0)
'fh = open file handle
'recordsize = record size in shorts (not bytes)
'record = record number, defaults to read from current file position
'context = filename if known. For debug only.
'returns true if successful, false if failure (eg. file too short)
'Even if the file is too short, reads as much as possible

	dim starttime as double = timer
	dim idx as integer
	if recordsize <= 0 then return NO
	if ubound(buf) < recordsize - 1 then
		debugc errBug, "loadrecord: " & recordsize & " ints will not fit in " & ubound(buf) + 1 & " element array"
		'continue, fit in as much as possible
	end if
	dim readbuf(recordsize - 1) as short

	if record <> -1 then
		seek #fh, recordsize * 2 * record + 1
	end if
	dim ret as bool = YES
	if seek(fh) + 2 * recordsize > lof(fh) + 1 then ret = NO
	get #fh, , readbuf()
	for idx = 0 to small(recordsize - 1, ubound(buf))
		buf(idx) = readbuf(idx)
	next
	debug_if_slow(starttime, 0.1, context)
	return ret
end function

function loadrecord (buf() as integer, filen as string, byval recordsize as integer, byval record as integer = 0, byval expectfile as integer = YES) as bool
'wrapper for above
'set expectfile = NO to suppress errors
	dim f as integer
	dim i as integer

	if recordsize <= 0 then return NO

	if NOT fileisreadable(filen) then
		if expectfile = YES then debug "File not found loading record " & record & " from " & filen
		for i = 0 to recordsize - 1
			buf(i) = 0
		next
		return NO
	end if
	f = freefile
	open filen for binary access read as #f

	loadrecord = loadrecord (buf(), f, recordsize, record, filen)
	close #f
end function

sub storerecord (buf() as integer, byval fh as integer, byval recordsize as integer, byval record as integer = -1)
'same as loadrecord
	if ubound(buf) < recordsize - 1 then
		debugc errBug, "storerecord: array has only " & ubound(buf) + 1 & " elements, record is " & recordsize & " ints"
		'continue, write as much as possible
	end if

	dim idx as integer
	dim writebuf(recordsize - 1) as short

	if record <> -1 then
		seek #fh, recordsize * 2 * record + 1
	end if
	for idx = 0 to small(recordsize - 1, ubound(buf))
		writebuf(idx) = buf(idx)
	next
	put #fh, , writebuf()
end sub

sub storerecord (buf() as integer, filen as string, byval recordsize as integer, byval record as integer = 0)
'wrapper for above
	dim f as integer

	if NOT fileiswriteable(filen) then
		debug "could not write record to " & filen
		exit sub
	end if
	f = freefile
	open filen for binary access read write as #f

	storerecord buf(), f, recordsize, record
	close #f
end sub

'Compares two files record-by-record, setting each element of the difference array to:
'0: records are identical
'1: records differ
'2: left file is short; this record only in right file
'-2: right file is short; this record only in left file
'recordsize = record size in shorts (not bytes)
'maskarray = if specified, only compare SHORTs in each record which are nonzero in maskarray
'Return true on success, false if one of the files doesn't exist
function compare_files_by_record(differences() as integer, leftfile as string, rightfile as string, byval recordsize as integer, byval maskarray as integer ptr = NULL) as integer
	redim differences(0)

	dim as integer fh1, fh2
	fh1 = freefile
	if open(leftfile for binary access read as #fh1) then return NO
	fh2 = freefile
	if open(rightfile for binary access read as #fh2) then
		close #fh1
		return NO
	end if

	dim as integer buf1(recordsize - 1), buf2(recordsize - 1)
	dim as integer length1, length2
	length1 = LOF(fh1) \ (2 * recordsize)
	length2 = LOF(fh2) \ (2 * recordsize)

	redim differences(large(length1, length2) - 1)

	for record as integer = 0 to ubound(differences)
		if length1 - 1 < record then
			differences(record) = -2
		elseif length2 - 1 < record then
			differences(record) = 2
		else
			loadrecord buf1(), fh1, recordsize, record
			loadrecord buf2(), fh2, recordsize, record
			if maskarray then
				for j as integer = 0 to recordsize - 1
					if maskarray[j] then
						if buf1(j) <> buf2(j) then
							differences(record) = 1
							exit for
						end if
					end if
				next
			else
				if memcmp(@buf1(0), @buf2(0), recordsize * 4) then   '* 4 since array of ints!
					differences(record) = 1
				end if
			end if
		end if
	next
	close #fh1
	close #fh2
	return YES
end function


'----------------------------------------------------------------------
'                           FileLump class


'A constructor of temporary file lumps.
'Used to extract a file from a lump, creating a new file only if necessary.
'Will delete itself and the file when closed, if a file/FileLump had to be created.
'Read only! Behaviour when the actual or retyrned lumps are written to is undefined.
function FileLump_tempfromlump(byref lmp as Lump) as FileLump ptr
	dim flump as FileLump ptr
	if lmp.type = LT_FILE then
		flump = cast(FileLump ptr, @lmp)
		'don't need to open an actual file handle; just increment the refcount
		'FileLump_open(*flump)
		flump->opencount += 1
		'FIXME
		if flump->filename = "" then flump->filename = flump->index->unlumpeddir + flump->lumpname
		return flump
	else
		'new file, in a Lump wrapper
		dim filename as string
		filename = tmpdir & randint(100000000) & "_" & lmp.lumpname

		if Lump_unlumpfile(lmp, tmpdir) = 0 then return NULL
		local_file_move(tmpdir + lmp.lumpname, filename)

		flump = callocate(sizeof(FileLump))
		with *flump
			.type = LT_FILE
			.lumpname = lmp.lumpname
			.length = lmp.length
			.filename = filename
			.opencount = 1
			.istemp = YES

		 	'leaving .index as NULL, and not adding to any index
		end with
		return flump
	end if
end function

sub FileLump_destruct (byref this as FileLump)
	if this.opencount then
		debug this.lumpname + " at destruction had nonzero opencount " & this.opencount
	end if
	if this.fhandle then
		close this.fhandle
	end if
	if this.istemp then
		if this.filename <> "" then
			safekill this.filename
		else
			debug "FileLump without explicit filename marked temp"
		end if
	end if
	this.Destructor()  'for strings
end sub

sub FileLump_open(byref this as FileLump)
	this.opencount += 1
	if this.fhandle = 0 then
		dim fname as string = this.filename
		if fname = "" then fname = this.index->unlumpeddir + this.lumpname
		this.fhandle = freefile
		open fname for binary as #this.fhandle
	end if
end sub

sub FileLump_close(byref this as FileLump)
	this.opencount -= 1
	if this.opencount = 0 then
		if this.fhandle then
			close this.fhandle
			this.fhandle = 0
		end if
		if this.istemp then
			FileLump_destruct(this)
			deallocate(@this)
		end if
	end if
end sub

sub FileLump_writetofile(byref this as FileLump, byval fileno as integer, byval position as integer)
	'unfinished
end sub

/'
sub FileLump_unlumpfile(byref this as FileLump, whereto as string)
	writeablecopyfile this.index->unlumpeddir + this.lumpname, whereto + this.lumpname
end sub
'/

function FileLump_read(byref this as FileLump, byval position as integer, byval bufr as any ptr, byval size as integer) as integer
	if this.fhandle = 0 then
		'temporarily open instead?
		debug "open FileLump before read"
		return 0
	end if
	dim amnt as integer
	fgetiob this.fhandle, position, bufr, size, @amnt
	return amnt
end function

function indexunlumpeddir (whichdir as string) as LumpIndex ptr
	dim index as LumpIndex ptr

	index = callocate(sizeof(LumpIndex))
	construct_LumpIndex(*index)
	index->unlumpeddir = whichdir

	dim filelist() as string
	findfiles whichdir, ALLFILES, fileTypeFile, NO, filelist()
	for i as integer = 0 to ubound(filelist)
		dim lmp as FileLump ptr
		lmp = callocate(sizeof(FileLump))
		lmp->type = LT_FILE
		lmp->lumpname = filelist(i)
		LumpIndex_addlump(*index, cast(Lump ptr, lmp))
	next

	return index
end function


'----------------------------------------------------------------------
'                           LumpedLump class

'Not intended to be called on a Lump ptr, instead is used as default destructor of subclasses
'FIXME: broken, destructor not called!
private sub LumpedLump_destruct(byref this as LumpedLump)
	if this.opencount then
		debug this.lumpname + " at destruction had nonzero opencount " & this.opencount
	end if
	if this.index then
		'LumpIndex_dellump(*this.index, @this)  'FIXME: best idea?
	end if
end sub


sub LumpedLump_writetofile(byref this as LumpedLump, byval fileno as integer, byval position as integer)
	dim bufr as byte ptr
	dim size as integer

	if this.index->fhandle = 0 then
		debug "lumped file not open"
		exit sub
	end if

	bufr = allocate(32768)

	'copy the data
	seek this.index->fhandle, this.offset
	seek fileno, position
	size = this.length
	while size > 0
		fget this.index->fhandle, , bufr, small(size, 32768)
		fput fileno, , bufr, small(size, 32768)
		size -= 32768
	wend
	deallocate(bufr)
end sub

function LumpedLump_read(byref this as LumpedLump, byval position as integer, byval bufr as any ptr, byval size as integer) as integer
	dim amount as unsigned integer
	fgetiob(this.index->fhandle, this.offset + position, bufr, small(size, this.length - position), @amount)
	return amount
end function

function indexlumpfile (lumpfile as string, byval keepopen as integer = YES) as LumpIndex ptr
	dim index as LumpIndex ptr
	dim lf as integer
	dim dat as ubyte
	dim size as integer
	dim maxsize as integer
	dim lname as string
	dim namelen as integer

	if NOT fileisreadable(lumpfile) then
		debug "indexlumpfile: could not read " + lumpfile
		return NULL
	end if

	index = callocate(sizeof(LumpIndex))
	construct_LumpIndex(*index)

	lf = freefile
	open lumpfile for binary access read lock write as #lf
	if keepopen then index->fhandle = lf
	maxsize = lof(lf)

	do
		'get lump name
		lname = ""
		namelen = 0
		while not eof(lf) and namelen <= 50
			get #lf, , dat
			if dat = 0 then exit while
			lname = lname + chr(dat)
			namelen += 1
		wend
		if namelen > 50 then
			debug "indexlumpfile: corrupt lump file " & lumpfile & " : lump name too long: '" & lname & "'" 
			exit do
		end if
		if eof(lf) then
			debug "indexlumpfile: corrupt lump file " + lumpfile + " : garbage"
			exit do
		end if

		lname = lcase(lname)
		'debug "lump name <" + lname + ">"

		'if instr(lname, "\") or instr(lname, "/") then
		'	debug "lump file " + lumpfile + " : unsafe lump name " + lname
		'	exit do
		'end if

		'get lump size - byte order = 3,4,1,2
		fget lf, , cast(short ptr, @size) + 1, 2
		fget lf, , cast(short ptr, @size), 2
		'debug "lump size " + str(size)

		if size + seek(lf) > maxsize + 1 then
			debug lumpfile + ": corrupt lump size " & size & " exceeds source size " & maxsize
			exit do
		end if

		dim lmp as LumpedLump ptr
		lmp = callocate(sizeof(LumpedLump))
		lmp->type = LT_LUMPED
		lmp->lumpname = lname
		lmp->offset = seek(lf)
		lmp->length = size
		LumpIndex_addlump(*index, cast(Lump ptr, lmp))

		seek #lf, seek(lf) + size
		if eof(lf) then
			'success
			if keepopen = 0 then close lf
			return index
		end if
	loop
	'while loop exits on error

	'closes file
	destruct_LumpIndex(*index)
	deallocate(index)
	return NULL
end function


'----------------------------------------------------------------------
'                         Lump FileWrapper

extern "C"

function FileWrapper_open(byval lump as Lump ptr) as FileWrapper ptr
	dim filew as FileWrapper ptr
	filew = callocate(sizeof(FileWrapper))
	filew->lump = lump
	'filew->index = index
	filew->pos = 0
	
	return filew
end function

sub FileWrapper_close(byref this as FileWrapper)
	deallocate(@this)
end sub

function FileWrapper_seek(byref this as FileWrapper, byval offset as integer, byval whence as integer) as integer
	if whence = SEEK_SET then
		this.pos = offset
	elseif whence = SEEK_CUR then
		this.pos += offset
	elseif whence = SEEK_END then
		this.pos = this.lump->length + offset
	end if
	this.pos = bound(this.pos, 0, this.lump->length)
	return this.pos
end function

function FileWrapper_read(byref this as FileWrapper, byval bufr as any ptr, byval size as integer, byval maxnum as integer) as integer
	dim ret as integer
	if size <= 0 or maxnum <= 0 then
		return 0
	end if
	ret = Lump_read(*this.lump, this.pos, bufr, size * maxnum)
	this.pos = bound(this.pos + ret, 0, this.lump->length)
	return ret \ size
end function

end extern

'----------------------------------------------------------------------
'                           Lumped files


function read_lump_size(byval fh as integer) as integer
	'get lump size - PDP-endian byte order = 3,4,1,2
	dim size as integer
	dim dat as ubyte
	get #fh, , dat
	size = (dat shl 16)
	get #fh, , dat
	size = size or (dat shl 24)
	get #fh, , dat
	size = size or dat
	get #fh, , dat
	size = size or (dat shl 8)
	return size
end function

'Returns true on success
function extract_lump(lf as integer, srcfile as string, destfile as string, size as integer, showerrors as bool) as bool
	'write yon file
	dim of as integer
	dim csize as integer

	'debug "  -> " & destfile

	of = freefile
	if open(destfile for binary access write as #of) then
		debug "unlumpfile(" + srcfile + "): " + destfile + " not writable, skipping"
		if isfile(destfile) then
			debug "(file already exists)"
		end if
		if showerrors then showerror "Could not unlump " & destfile & " (file not writeable) from " & srcfile & ". Some game data will be missing."
		return NO
	else
		'copy the data
		dim bufr as ubyte ptr = allocate(16384)
		while size > 0
			csize = small(16384, size)
			'copy a chunk of file
			fget lf, , bufr, csize
			fput of, , bufr, csize
			size = size - csize
		wend

		deallocate(bufr)
		close #of
		return YES
	end if
end function

'Try to unlump a damaged lumped file
'Bit of a mess, and not full featured (many types of corruption might require modifying this code)
sub recover_lumped_file(lumpfile as string, destpath as string = "")
	dim dat as ubyte
	dim lname as string
	dim namelen as integer  'not including nul
	' Exclude space because it occurs in a lot of false positives
	dim filename_chars as zstring ptr = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-~."
	/'
	dim lumplike(...) as string => {
		"ohrrpgce.", "archinym.lmp", "attack.bin", "binsize.bin", "browse.txt", "defpal#.bin", "commands.bin", _
		"defpass.bin", "fixbits.bin", "scripts.bin", "scripts.txt", "lookup1.bin", "sfxdata.bin", "songdata.bin", _
		"palettes.bin", "plotscr.lst", "menuitem.bin", "menus.bin", "uicolors.bin", "slicetree_#_#.reld", _
		"slicelookup.txt", "distrib.reld", "heroes.reld", archinym + "." _
	}
	'/

	dim lf as integer
	lf = freefile
	if open(lumpfile for binary access read as #lf) <> 0 then
		debug "recover_lumped_file: Could not open file " + lumpfile
		exit sub
	end if

	lname = ""
	dim maxsize as integer = lof(lf)
	maxsize = large(2 * 1024 * 1024, maxsize)

	'If this is false then look for possible lump headers
	'in the middle of authentic-looking lumps instead of skipping over them.
	'Leads to lots of garbage lumps though.
	dim skipping as bool = YES
	dim extracting as bool = YES

	dim prev_lump_data as integer = 1 'offset
	dim prev_lump_name as string
	dim prev_lump_size as integer

	get #lf, , dat	'read first byte
	while not eof(lf)
		'Search forward from the current file position
		'for what looks like the start of the next lump.

		if dat = 0 then
			'May be NUL byte at end of lump name
			if len(lname) <= 3 then
				' Not likely to be a lump name, ignore
				lname = ""
			else
				dim size as integer = read_lump_size(lf)
				dim as integer fpos = seek(lf)
				' Require . in lumpnames (excludes HS header in .HSP)
				if size > maxsize - (fpos - 1) or size < 1 or instr(lname, ".") = 0 then
					'Nope, go back
					seek lf, fpos - 4
				else
					dim header_start as integer = fpos - (len(lname) + 5)
					dim skipped as integer = header_start - (prev_lump_data + prev_lump_size)
					if skipped then
						debug "   ...skipping " & skipped & " unclaimed bytes"
					end if
					if extracting andalso len(prev_lump_name) then
						dim extract_size as integer = header_start - prev_lump_data
						seek lf, prev_lump_data
						extract_lump(lf, lumpfile, destpath + lcase(prev_lump_name), extract_size, NO)
						seek lf, fpos
					end if
					debug "possible lump '" & lname & "' length " & size & " @ " & fpos
					prev_lump_name = lname
					lname = ""

					prev_lump_data = fpos
					prev_lump_size = size
					if skipping then
						seek lf, fpos + size
					end if

					'if extract_lump(lf, lumpfile, path + lcase(lname), size, showerrors) then

				end if
			end if
		else
			if strchr(filename_chars, dat) = NULL then
				lname = ""
			else
				if len(lname) > 25 then
					lname = mid(lname, 2)
				end if
				lname &= chr(dat)
			end if
		end if
		get #lf, , dat
	wend

	if extracting andalso len(prev_lump_name) then
		dim as integer fpos = seek(lf)
		' Extract until end
		seek lf, prev_lump_data
		extract_lump(lf, lumpfile, destpath + lcase(prev_lump_name), fpos - prev_lump_data, NO)
		seek lf, fpos
	end if
end sub

sub unlump (lumpfile as string, ulpath as string, byval showerrors as bool = YES)
	unlumpfile(lumpfile, "", ulpath, showerrors)
end sub

sub unlumpfile (lumpfile as string, fmask as string, path as string, byval showerrors as bool = YES)
	dim lf as integer
	dim dat as ubyte
	dim size as integer
	dim maxsize as integer
	dim lname as string
	dim namelen as integer  'not including nul
	dim nowildcards as integer = 0

	if NOT fileisreadable(lumpfile) then
		debug "unlumpfile: " + lumpfile + " is not readable"
		if showerrors then showerror lumpfile + " is not readable"
		exit sub
	end if
	lf = freefile
	open lumpfile for binary access read as #lf
	maxsize = LOF(lf)

	if len(path) > 0 and right(path, 1) <> SLASH then path = path & SLASH

	'should make browsing a bit faster
	if len(fmask) > 0 then
		if instr(fmask, "*") = 0 and instr(fmask, "?") = 0 then
			nowildcards = -1
		end if
	end if

	get #lf, , dat	'read first byte
	while not eof(lf)
		'get lump name
		lname = ""
		namelen = 0
		while not eof(lf) and dat <> 0 and namelen < 64
			lname = lname + chr(dat)
			get #lf, , dat
			namelen += 1
		wend
		if namelen = 0 or namelen > 50 then
			debug "unlumpfile: corrupt lumped file " + lumpfile + ": lump length not in range 1--50: '" & lname & "' @ " & seek(lf)
			if showerrors then showerror "File " + lumpfile + " seems to be corrupt"
			exit while
		end if
		'debug "lump name '" + lname + "' at " & seek(lf)
		lname = lcase(lname)

		if lname <> exclusive(lname, "abcdefghijklmnopqrstuvwxyz0123456789_-~. ") then
			debug "corrupt lump file " + lumpfile + " : unallowable lump name '" + lname + "'"
			if showerrors then showerror "File " + lumpfile + " seems to be corrupt"
			exit while
		end if

		if not eof(lf) then
			size = read_lump_size(lf)
			if size > maxsize then
				debug lumpfile + ": corrupt lump size " & size & " exceeds source size " & maxsize
				if showerrors then showerror "File " + lumpfile + " seems to be corrupt (possibly cut short)"
				exit while
			end if

			'debug "lump size " & size

			dim skiplump as bool = YES

			'do we want this file?
			if matchmask(lname, lcase(fmask)) then
				if extract_lump(lf, lumpfile, path + lname, size, showerrors) then
					skiplump = NO
				end if

				'early out if we're only looking for one file
				if nowildcards then exit while
			end if

			if skiplump then
				'skip to next name
				dim endpos as integer
				endpos = seek(lf) + size
				seek #lf, endpos
			end if

			if not eof(lf) then
				get #lf, , dat
			end if
		end if
	wend

	close #lf
end sub

sub copylump(package as string, lump as string, dest as string, byval ignoremissing as integer = NO)
	if len(dest) and right(dest, 1) <> SLASH then dest = dest + SLASH
	if isdir(package) then
		'unlumped folder
		if ignoremissing then
			if not isfile(package + SLASH + lump) then exit sub
		end if
		writeablecopyfile package + SLASH + lump, dest + lump
	else
		'lumpfile
		'Don't show errors if we don't really care (actually this matters only in one place:
		'don't show a very scary error when browsing for RPGs if there is a corrupt file in
		'the directory)
		unlumpfile package, lump, dest, ignoremissing = NO
	end if
end sub

function islumpfile (lumpfile as string, fmask as string) as integer
	dim lf as integer
	dim dat as ubyte
	dim size as integer
	dim maxsize as integer
	dim lname as string
	dim namelen as integer  'not including nul

	islumpfile = 0

	if NOT fileisreadable(lumpfile) then exit function
	lf = freefile
	open lumpfile for binary access read as #lf
	maxsize = LOF(lf)

	get #lf, , dat	'read first byte
	while not eof(lf)
		'get lump name
		lname = ""
		namelen = 0
		while not eof(lf) and dat <> 0 and namelen < 64
			lname = lname + chr(dat)
			get #lf, , dat
			namelen += 1
		wend
		if namelen > 50 then
			debug "islumpfile: corrupt lump file " + lumpfile + " : lump name too long: '" & lname & "'"
			exit while
		end if
		lname = lcase(lname)
		'debug "lump name " + lname

		if lname <> exclusive(lname, "abcdefghijklmnopqrstuvwxyz0123456789_-. ") then
			debug "corrupt lump file " + lumpfile + " : unallowable lump name '" + lname + "'"
			exit while
		end if

		if not eof(lf) then
			size = read_lump_size(lf)
			if size > maxsize then
				debug lumpfile + ": corrupt lump size " & size & " exceeds source size " & maxsize
				exit while
			end if

			'do we want this file?
			if matchmask(lname, lcase(fmask)) then
				islumpfile = -1
				exit function
			else
				'skip to next name
				seek #lf, seek(lf) + size
			end if

			if not eof(lf) then
				get #lf, , dat
			end if
		end if
	wend

	close #lf
end function

sub lumpfiles (filelist() as string, lumpfile as string, path as string)
	dim as integer lf, tl  'lumpfile, tolump

	dim dat as ubyte
	dim size as integer
	dim lname as string 'name actually written
	dim bufr as ubyte ptr
	dim csize as integer

	lf = freefile
	if open(lumpfile for binary access write as #lf) <> 0 then
		debug "lumpfiles: Could not open file " + lumpfile
		exit sub
	end if

	bufr = callocate(16384)

	'get file to lump
	for i as integer = 0 to ubound(filelist)
		lname = ucase(filelist(i))
		if len(lname) > 50 orelse lname <> exclusive(lname, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.") then
			debug "lumpfiles: bad lump name '" & lname & "'"
			continue for
		end if

		tl = freefile
		open path + filelist(i) for binary access read as #tl
		if err <> 0 then
			debug "failed to open " + path + lname + " for lumping"
			continue for
		end if

		'write lump name
		put #lf, , lname
		dat = 0
		put #lf, , dat

		'write lump size - PDP-endian byte order = 3,4,1,2
		size = lof(tl)
		dat = (size and &hff0000) shr 16
		put #lf, , dat
		dat = (size and &hff000000) shr 24
		put #lf, , dat
		dat = size and &hff
		put #lf, , dat
		dat = (size and &hff00) shr 8
		put #lf, , dat

		'write lump
		while size > 0
			csize = small(16384, size)
			'copy a chunk of file
			fget(tl, , bufr, csize)
			fput(lf, , bufr, csize)
			size = size - csize
		wend

		close #tl
	next

	close #lf

	deallocate bufr
end sub

function matchmask(match as string, mask as string) as integer
	dim i as integer
	dim m as integer
	dim si as integer, sm as integer

	'special cases
	if mask = "" then
		matchmask = 1
		exit function
	end if

	i = 0
	m = 0
	while (i < len(match)) and (m < len(mask)) and (mask[m] <> asc("*"))
		if (match[i] <> mask[m]) and (mask[m] <> asc("?")) then
			matchmask = 0
			exit function
		end if
		i = i+1
		m = m+1
	wend

	if (m >= len(mask)) and (i < len(match)) then
		matchmask = 0
		exit function
	end if

	while i < len(match)
		if m >= len(mask) then
			'run out of mask with string left over, rewind
			i = si + 1 ' si will always be set by now because of *
			si = i
			m = sm
		else
			if mask[m] = asc("*") then
				m = m + 1
				if m >= len(mask) then
					'* eats the rest of the string
					matchmask = 1
					exit function
				end if
				i = i + 1
				'store the positions in case we need to rewind
				sm = m
				si = i
			else
				if (mask[m] = match[i]) or (mask[m] = asc("?")) then
					'ok, next
					m = m + 1
					i = i + 1
				else
					'mismatch, rewind to last * positions, inc i and try again
					m = sm
					i = si + 1
					si = i
				end if
			end if
		end if
	wend

  	while (m < len(mask)) and (mask[m] = asc("*"))
  		m = m + 1
  	wend

  	if m < len(mask) then
		matchmask = 0
	else
		matchmask = 1
	end if
end function

'Given a list of lumps reorder them to speed up RPG browsing, and exclude *.tmp files
sub fixlumporder (filelist() as string)
	dim as integer temp, readpos, writepos

	'--move archinym.lmp and browse.txt to front
	temp = str_array_findcasei(filelist(), "browse.txt")
	if temp > -1 then swap filelist(0), filelist(temp)
	temp = str_array_findcasei(filelist(), "archinym.lmp")
	if temp > -1 then swap filelist(1), filelist(temp)

	'--exclude illegal *.tmp files; shuffle them to the end of the array, then trimming them
	writepos = 0
	for readpos = 0 to ubound(filelist)
		if lcase(right(filelist(readpos), 4)) <> ".tmp" then
			swap filelist(readpos), filelist(writepos)
			writepos += 1
		end if
	next
	redim preserve filelist(-1 to writepos - 1)
end sub

'----------------------------------------------------------------------
'                           BufferedFile
'
'This is (currently) just an output file which buffers writes to near the end of
'the file. The purpose is to speed serialization of RELOAD documents, which
'requires lots of seeking backwards in the file, but normally to positions near
'the end. Unfortunately C's stdio buffered files flush when fseek is called, and
'FreeBasic's files inherit this.
'In future, likely to be integrated into LumpFile.


function Buffered_open (filename as string) as BufferedFile ptr
	dim bfile as BufferedFile ptr

	bfile = callocate(sizeof(BufferedFile))

	with *bfile
		.fh = freefile
		if open(filename for output as .fh) then
			debug "BufferedFile: Could not open " & filename
			deallocate bfile
			return NULL
		end if

		.buf = allocate(BF_BUFSIZE)
		.filename = allocate(len(filename) + 1)
		strcpy(.filename, strptr(filename))
	end with

	return bfile
end function

sub Buffered_close (byval bfile as BufferedFile ptr)
	with *bfile
		if .bufStart < .len then
			fput .fh, .bufStart + 1, .buf, .len - .bufStart
		end if
		close .fh
		send_lump_modified_msg(.filename)
		deallocate(.buf)
		deallocate(.filename)
	end with
	deallocate(bfile)
end sub

'offset is from 0 at start of file
sub Buffered_seek (byval bfile as BufferedFile ptr, byval offset as unsigned integer)
	with *bfile
		if offset > .bufStart + BF_BUFSIZE then
			'Flush and move buffer to end
			fput .fh, .bufStart + 1, .buf, .len - .bufStart
			.len = offset
			.pos = offset
			.bufStart = offset
		elseif offset >= .bufStart then
			.pos = offset
		else
			'seek fh, offset
			.pos = offset
		end if
	end with
end sub

function Buffered_tell (byval bfile as BufferedFile ptr) as integer
	return bfile->pos
end function

sub Buffered_write (byval bfile as BufferedFile ptr, byval databuf as any ptr, byval amount as integer)
	with *bfile

		if .pos < .bufStart then
			if .pos + amount > .bufStart then
				'Crap! Have to flush to prevent overlap from being written over
				'when buf is next flushed
				fput .fh, .bufStart + 1, .buf, .len - .bufStart
				.bufStart = .len
				if .pos + amount > .len then .bufStart = .pos + amount
			end if
			fput .fh, .pos + 1, databuf, amount
		else
			if .pos + amount > .bufStart + BF_BUFSIZE then
				'Buffer can't take it. First we flush everything before the start of
				'the new data (not the whole buffer) - everything past .pos is overwritten
				fput .fh, .bufStart + 1, .buf, .pos - .bufStart
				.bufStart = .pos

				if amount >= BF_BUFSIZE then
					'Oh, write anyway
					fput .fh, , databuf, amount
					.bufStart += amount
				else
					memcpy(.buf, databuf, amount)
				end if
			else
				'We actually get to buffer it!
				memcpy(.buf + (.pos - .bufStart), databuf, amount)
			end if
		end if
		.pos += amount
		if .pos > .len then .len = .pos
	end with
end sub

'version of above optimised for a single byte
sub Buffered_putc (byval bfile as BufferedFile ptr, byval datum as ubyte)
	with *bfile
		if .pos < .bufStart then
			fput .fh, .pos + 1, @datum, 1
		else
			dim as integer bufindex = .pos - .bufStart
			if bufindex = BF_BUFSIZE then
				'Buffer is full
				fput .fh, .bufStart + 1, .buf, BF_BUFSIZE
				.bufStart = .pos

				.buf[0] = datum
			else
				'We actually get to buffer it!
				.buf[bufindex] = datum
			end if
		end if
		.pos += 1
		if .pos > .len then .len = .pos
	end with
end sub


'----------------------------------------------------------------------
'                     filelayer.cpp support stuff


'This is called on EVERY OPEN call once the OPEN hook is registered!
'See filelayer.cpp (where it is registered as pfnLumpfileFilter)
'Returns whether the file is a normal lump file in workingdir.
'This is used to determine whether the file should be hooked
'writable: whether attempting to *explicitly* open with write access
function inworkingdir(filename as string, byval writable as bool) as bool
	if RIGHT(filename, 10) = "_debug.txt" then return NO
	'if RIGHT(filename, 12) = "_archive.txt" then return NO
	'Uncomment this for OPEN tracing (or you could just use strace...)
	'debuginfo "OPEN(" & filename & ")  " & ret

	dim ret as integer = YES
	if strncmp(strptr(filename), strptr(workingdir), len(workingdir)) <> 0 then ret = NO
	if right(filename, 4) = ".tmp" then ret = NO

#ifdef IS_GAME
	if running_as_slave andalso ret andalso writable then
		fatalerror "Engine bug: Illegally tried to write to " & filename
	end if
#endif

	return ret
end function

'A crude synchronisation measure. Waits until receiving a message with the given prefix,
'placing it in line_in, discarding everything else. Returns true on success
function channel_wait_for_msg(byref channel as IPCChannel, wait_for_prefix as string, line_in as string = "", byval timeout_ms as integer = 500) as integer
	dim timeout as double = TIMER + timeout_ms / 1000

	do
		line_in = ""
		while channel_input_line(channel, line_in) = 0
			if channel = NULL_CHANNEL then
				debug "channel_wait_for_msg: channel closed"
				return NO
			end if
			sleep 10
			if TIMER > timeout then
				debuginfo "channel_wait_for_msg timed out"
				return NO
			end if
		wend
		if instr(line_in, wait_for_prefix) = 1 then
			return YES
		end if
		debug "warning: channel_wait_for_msg discarding message: " & line_in
	loop
end function
