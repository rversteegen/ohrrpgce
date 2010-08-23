'OHRRPGCE COMMON - RELOAD related functions
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
#define RELOADINTERNAL

'if you find yourself debugging heap issues, define this. If the crashes go away, then I (Mike Caron)
'somehow fscked up the private heap implementation. Or, someone else touched something without
'understanding how it works...

'#define RELOAD_NOPRIVATEHEAP

#include "reload.bi"
#include "util.bi"
#include "lumpfile.bi"


#if defined(IS_GAME) or defined(IS_CUSTOM)
DECLARE SUB debug (s AS STRING)
#else
SUB debug (s AS STRING)
 print "debug: " & s
END SUB
#endif


Namespace Reload

Type hashFunction as Function(byval k as ZString ptr) as integer

'These are in addition to the 'f as integer' overloads in reload.bi
Declare Function ReadVLI(byval f as FILE ptr) as longint
'Can add the FILE* overload back when you actually need it...
Declare Sub WriteVLI(byval f as BufferedFile ptr, byval v as Longint)

Declare Function AddStringToTable (st as string, byval doc as DocPtr) as integer
Declare Function FindStringInTable overload(st as string, byval doc as DocPtr) as integer

Declare Function CreateHashTable(byval doc as Docptr, byval hashFunc as hashFunction, byval b as integer = 65) as Hashptr
Declare Sub DestroyHashTable(byval h as HashPtr)
Declare Function FindItem(byval h as HashPtr, byval key as ZString ptr, byval num as integer = 1) as any ptr
Declare Sub AddItem(byval h as HashPtr, byval key as ZString ptr, byval item as any ptr)
Declare Sub RemoveKey(byval h as HashPtr, byval key as zstring ptr, byval num as integer = 1)

Declare Function LoadNode overload(byval ret as nodeptr) as integer


'===================================================================================================
'= Private Heap abstraction
'= On Windows, we can create a private heap to manage our memory. The advantage is that when the
'= document is eventually freed, we can just nuke the private heap, rather than deallocating
'= everything manually. This is abstracted away 
'===================================================================================================

function RHeapInit(byval doc as docptr) as integer
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	doc->heap = HeapCreate(0, 0, 0)
	return doc->heap <> 0
#else
	'nothing, use the default heap
	return 1
#endif
end function

Function RHeapDestroy(byval doc as docptr) as integer
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	HeapDestroy(doc->heap) 'poof
	doc->heap = 0
	return 0
#else
	'they need to free memory manually
	return 1
#endif
end function

Function RAllocate(byval s as integer, byval doc as docptr) as any ptr
	dim ret as any ptr
	
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	ret = HeapAlloc(doc->heap, HEAP_ZERO_MEMORY, s)
#else
	ret = CAllocate(s)
#endif
	
	return ret
end function

Function RReallocate(byval p as any ptr, byval doc as docptr, byval newsize as integer) as any ptr
	dim ret as any ptr
	
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	ret = HeapReAlloc(doc->heap, HEAP_ZERO_MEMORY, p, newsize)
#else
	ret = Reallocate(p, newsize)
#endif
	
	return ret
end function

Sub RDeallocate(byval p as any ptr, byval doc as docptr)
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	HeapFree(doc->heap, 0, p)
#else
	Deallocate(p)
#endif
End Sub

Function HashZString(byval st as ZString ptr) as integer
	dim as integer ret = 0, i = 0
	
	do while st[i] <> 0
		ret += st[i]
		i += 1
	loop
	
	return ret
end function

'creates and initializes a blank document
Function CreateDocument() as DocPtr
	dim ret as DocPtr
	
	'Holy crap! allocating memory with malloc (and friends), and freeing it with delete?!
	'never, ever do that! In this case, it probably didn't hurt anything, since Doc doesn't
	'have a constructor or destructor. But, if it did... bad things! *shudder*
	' -- Mike, Apr 6, 2010
	' PS: It was me who did this :'(
	
	ret = New Doc
	
	if ret then
		if 0 = RHeapInit(ret) then
			debug "Unable to create heap on Document :("
			delete ret
			return null
		end if
		ret->version = 1
		ret->root = null
		
		'The initial string table has one entry: ""
		ret->strings = RAllocate(sizeof(StringTableEntry), ret)
		ret->strings[0].str = RAllocate(1, ret)
		*ret->strings[0].str = "" 'this is technically redundant.
		ret->numStrings = 1
		ret->numAllocStrings = 1
		ret->stringHash = CreateHashTable(ret, @HashZString)
		ret->delayLoading = no
		
		'add the blank string to the hash
		AddItem(ret->stringHash, ret->strings[0].str, cast(any ptr, 0))
	end if
	
	return ret
End function

'creates and initilalizes an empty node with a given name.
'it associates the node with the given document, and cannot be added to another one!
Function CreateNode(byval doc as DocPtr, nam as string) as NodePtr
	dim ret as NodePtr
	
	if doc = null then return null
	
	ret = RAllocate(sizeof(Node), doc)
	
	ret->doc = doc
	
	ret->namenum = AddStringToTable(nam, doc)
	
	ret->name = doc->strings[ret->namenum].str
	doc->strings[ret->namenum].uses += 1
	
	ret->nodeType = rltNull
	ret->numChildren = 0
	ret->children = null
	ret->lastChild = null
	ret->flags = 0
	
	return ret
End function

Function CreateNode(byval nod as NodePtr, nam as string) as NodePtr
	return CreateNode(nod->doc, nam)
end function

'destroys a node and any children still attached to it.
'if it's still attached to another node, it will be removed from it
sub FreeNode(byval nod as NodePtr, byval options as integer)
	if nod = null then
		debug "FreeNode ptr already null"
		exit sub
	end if
	
	dim tmp as NodePtr
	if 0 = (nod->flags and nfNotLoaded) then
		do while nod->children <> 0
			FreeNode(nod->children)
		loop
	end if
	
	'If this node has a parent, we should remove this node from
	'its list of children
	if nod->parent <> 0 and (options and 1) = 0 then
		dim par as NodePtr = nod->parent
		
		if par->children = nod then
			par->children = nod->nextSib
		end if
		if par->lastChild = nod then
			par->lastChild = nod->prevSib
		end if
		
		par->numChildren -= 1
		
		if nod->nextSib then
			nod->nextSib->prevSib = nod->prevSib
		end if
		
		if nod->prevSib then
			nod->prevSib->nextSib = nod->nextSib
		end if
	end if
	if (options and 1) = 0 then
		if nod->nodeType = rltString and nod->str <> 0 then RDeallocate(nod->str, nod->doc)
		RDeallocate(nod, nod->doc)
	end if
end sub

'This frees an entire document, its root node, and any of its children
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
'NOTE: this frees ALL nodes that were ever attached to this document!
#else
'NOTE! This does not free any nodes that are not currently attached to the
'root node! Beware!
#endif
sub FreeDocument(byval doc as DocPtr)
	if doc = null then return
	
	if doc->fileHandle then fclose(doc->fileHandle)
	
	if RHeapDestroy(doc) then
		if doc->root then
			FreeNode(doc->root)
			doc->root = null
		end if
		
		if doc->strings then
			for i as integer = 0 to doc->numAllocStrings - 1
				if doc->strings[i].str then
					RDeallocate(doc->strings[i].str, doc)
				end if
			next
			RDeallocate(doc->strings, doc)
			doc->strings = null
		end if
		
		if doc->stringHash then
			DestroyHashTable(doc->stringHash)
			doc->stringHash = null
		end if
	end if
	
	'regardless of what heap is in use, doc is on the default heap
	delete doc
end sub

'Loads a node from a binary file, into a document
Function LoadNode(byval f as FILE ptr, byval doc as DocPtr) as NodePtr
	dim ret as NodePtr
	
	dim size as integer
	
	dim as integer here, here2
	fread(@size, 4, 1, f)
	
	here = ftell(f)
	
	ret = CreateNode(doc, "")
	
	ret->namenum = cshort(ReadVLI(f))
	
	if ret->namenum < 0 or ret->namenum > doc->numStrings then
		debug "Node has invalid name: #" & ret->namenum
		ret->namenum = 0
	else
		'debug "Node has valid name: #" & ret->namenum & " " & *doc->strings[ret->namenum].str
		ret->name = doc->strings[ret->namenum].str
		doc->strings[ret->namenum].uses += 1
	end if
	
	ret->nodetype = fgetc(f)
	
	select case ret->nodeType
		case rliNull
		case rliByte
			ret->num = cbyte(fgetc(f))
			ret->nodeType = rltInt
		case rliShort
			dim s as short
			fread(@s, 2, 1, f)
			ret->num = s
			ret->nodeType = rltInt
		case rliInt
			dim i as integer
			fread(@i, 4, 1, f)
			ret->num = i
			ret->nodeType = rltInt
		case rliLong
			fread(@(ret->num), 8, 1, f)
			ret->nodeType = rltInt
		case rliFloat
			fread(@(ret->flo), 8, 1, f)
			ret->nodeType = rltFloat
		case rliString
			dim mysize as integer
			ret->strSize = cint(ReadVLI(f))
			ret->str = RAllocate(ret->strSize + 1, doc)
			fread(ret->str, 1, ret->strSize, f)
			ret->nodeType = rltString
		case else
			debug "unknown node type " & ret->nodeType
			FreeNode(ret)
			return null
	end select
	
	dim nod as nodeptr
	
	ret->numChildren = ReadVLI(f)
	
	if doc->delayLoading then
		ret->fileLoc = ftell(f)
		ret->flags OR= nfNotLoaded
		
		fseek(f, size + here, 0)
	else
		for i as integer = 0 to ret->numChildren - 1
			nod = LoadNode(f, doc)
			if nod = null then
				FreeNode(ret)
				debug "child " & i & " node load failed"
				return null
			end if
			ret->numChildren -= 1
			AddChild(ret, nod)
		next
		
		if ftell(f) - here <> size then
			FreeNode(ret)
			debug "GOSH-diddly-DARN-it! Why did we read " & (ftell(f) - here) & " bytes instead of " & size & "!?"
			return null
		end if
	end if
	
	return ret
End Function

'this loads a node's children
Function LoadNode(byval ret as nodeptr) as integer
	if ret = null then return no
	if (ret->flags AND nfNotLoaded) = 0 then return yes
	
	dim f as FILE ptr = ret->doc->fileHandle
	
	fseek(f, ret->fileLoc, 0)
	
	for i as integer = 0 to ret->numChildren - 1
		dim nod as nodeptr = LoadNode(f, ret->doc)
		if nod = null then
			debug "child " & i & " node load failed"
			return no
		end if
		ret->numChildren -= 1
		AddChild(ret, nod)
	next
	
	ret->flags AND= NOT nfNotLoaded
	
	return yes
End Function

'This loads the string table from a binary document (as if the name didn't clue you in)
Sub LoadStringTable(byval f as FILE ptr, byval doc as docptr)
	dim as uinteger count, size
	
	count = cint(ReadVLI(f))
	
	if count <= 0 then exit sub
	
	for i as integer = 1 to doc->numAllocStrings - 1
		if doc->strings[i].str then RDeallocate(doc->strings[i].str, doc)
	next
	
	doc->strings = RReallocate(doc->strings, doc, (count + 1) * sizeof(StringTableEntry))
	doc->numStrings = count + 1
	doc->numAllocStrings = count + 1
	
	for i as integer = 1 to count
		size = cint(ReadVLI(f))
		'get #f, , size
		doc->strings[i].str = RAllocate(size + 1, doc)
		dim zs as zstring ptr = doc->strings[i].str
		if size > 0 then
			fread(zs, 1, size, f)
		end if
		
		AddItem(doc->stringHash, doc->strings[i].str, cast(any ptr, i))
	next
end sub

Function LoadDocument(fil as string, byval options as LoadOptions) as DocPtr
	dim ret as DocPtr
	dim f as FILE ptr
	
	f = fopen(fil, "rb")
	if f = 0 then
		debug "failed to open file " & fil
		return null
	end if
	
	dim as ubyte ver
	dim as integer headSize, datSize
	dim as string magic = "    "
	
	dim b as ubyte, i as integer
	
	fread(strptr(magic), 1, 4, f)
	
	if magic <> "RELD" then
		fclose(f)
		debug "Failed to load " & fil & ": No magic RELD signature"
		return null
	end if
	
	ver = fgetc(f)
	
	select case ver
		case 1 ' no biggie
			fread(@headSize, 4, 1, f)
			if headSize <> 13 then 'uh oh, the header is the wrong size
				fclose(f)
				debug "Failed to load " & fil & ": Reload header is " & headSize & "instead of 13"
				return null
			end if
			
			fread(@datSize, 4, 1, f)
			
		case else ' dunno. Let's quit.
			fclose(f)
			debug "Failed to load " & fil & ": Reload version " & ver & " not supported"
			return null
	end select
	
	'if we got here, the document is... not yet corrupt. I guess.
	
	ret = CreateDocument()
	ret->version = ver
	
	if options and optNoDelay then
		ret->delayLoading = no
	else
		ret->delayLoading = yes
		ret->fileHandle = f
	end if
	
	'We'll load the string table first, to assist in debugging.
	
	fseek(f, datSize, 0)
	LoadStringTable(f, ret)
	
	fseek(f, headSize, 0)
	
	ret->root = LoadNode(f, ret)
	
	'Is it possible to serialize a null root? I mean, I don't know why you would want to, but...
	'regardless, if it's null here, it's because of an error
	if ret->root = null then
		fclose(f)
		FreeDocument(ret)
		return null
	end if
	
	'String table: Apply directly to the document tree
	'String table: Apply directly to the document tree
	'String table: Apply directly to the document tree
	'FixNodeName(ret->root, ret)
	
	'String table: already applied long ago
	
	if options and optNoDelay then
		fclose(f)
	end if
	return ret
End Function

'Internal function
'Locates a string in the string table. If it's not there, returns -1
Function FindStringInTable (st as string, byval doc as DocPtr) as integer
	'if st = "" then return 0
	'for i as integer = 0 to doc->numStrings - 1
	'	if *doc->strings[i].str = st then return i
	'next
	
	if st = "" then return 0
	
	dim ret as integer = cint(FindItem(doc->stringhash, st))
	
	if ret = 0 then return -1
	return ret
end function

'Adds a string to the string table. If it already exists, return the index
'If it doesn't already exist, add it, and return the new index
Function AddStringToTable(st as string, byval doc as DocPtr) as integer
	dim ret as integer
	
	ret = cint(FindStringInTable(st, doc))
	
	if ret <> -1 then
		return ret
	end if
	
	if doc->numAllocStrings = 0 then 'This should never run.
		debug "ERROR! Unallocated string table!"
		doc->strings = RAllocate(16 * sizeof(StringTableEntry), doc)
		doc->numAllocStrings = 16
		
		doc->strings[0].str = Rallocate(1, doc)
		*doc->strings[0].str = ""
	end if
	
	if doc->numStrings >= doc->numAllocStrings then 'I hope it's only ever equals...
		dim s as StringTableEntry ptr = RReallocate(doc->strings, doc, sizeof(StringTableEntry) * (doc->numAllocStrings * 2))
		if s = 0 then 'panic
			debug "Error resizing string table"
			return -1
		end if
		for i as integer = doc->numAllocStrings to doc->numAllocStrings * 2 - 1
			s[i].str = 0
			s[i].uses = 0
		next
		
		doc->strings = s
		doc->numAllocStrings = doc->numAllocStrings * 2
	end if
	
	
	doc->strings[doc->numStrings].str = RAllocate(len(st) + 1, doc)
	*doc->strings[doc->numStrings].str = st
	
	AddItem(doc->stringHash, doc->strings[doc->numStrings].str, cast(any ptr, doc->numStrings))
	
	doc->numStrings += 1
	
	
	
	return doc->numStrings - 1
end function

Declare sub serializeBin(byval nod as NodePtr, byval f as BufferedFile ptr, byval doc as DocPtr)

'This serializes a document as a binary file. This is where the magic happens :)
sub SerializeBin(file as string, byval doc as DocPtr)
	if doc = null then exit sub
	
	dim f as BufferedFile ptr
	
	'BuildStringTable(doc->root, doc)

	'In case things go wrong, we serialize to a temporary file first
	safekill file & ".tmp"
	
	f = Buffered_open(file & ".tmp")
	
	if f = NULL then
		debug "SerializeBin: Unable to open " & file & ".tmp"
		exit sub
	end if
	
	dim i as uinteger, b as ubyte
	
	Buffered_write(f, @"RELD", 4) 'magic signature
	
	Buffered_putc(f, 1) 'version
	
	i = 13 'the size of the header (i.e., offset to the data)
	Buffered_write(f, @i, 4)
	
	i = 0 'we're going to fill this in later. it is the string table post relative to the beginning of the file.
	Buffered_write(f, @i, 4)
	
	'write out the body
	serializeBin(doc->root, f, doc)
	
	'this is the location of the string table (immediately after the data)
	i = Buffered_tell(f)
	
	Buffered_seek(f, 9)
	Buffered_write(f, @i, 4) 'filling in the string table position
	
	'jump back to the string table
	Buffered_seek(f, i)
	
	'first comes the number of strings
	writeVLI(f, doc->numStrings - 1)
	
	'then, write out each string, size then body
	for i = 1 to doc->numStrings - 1
		dim zs as zstring ptr = doc->strings[i].str
		dim zslen as integer = len(*zs)
		writeVLI(f, zslen)
		Buffered_write(f, zs, zslen)
	next
	Buffered_close(f)
	
	safekill file
	if rename(file & ".tmp", file) then
		debug "SerializeBin: could not rename " & file & ".tmp (exists=" & isfile(file & ".tmp") & ") to " & file & " (exists=" & isfile(file) & ")"
		exit sub  'don't delete the data
	end if
	safekill file & ".tmp"
end sub

sub serializeBin(byval nod as NodePtr, byval f as BufferedFile ptr, byval doc as DocPtr)
	if nod = 0 then
		debug "serializeBin null node ptr"
		exit sub
	end if
	dim i as integer, strno as longint, ub as ubyte
	
	'first, if a node isn't loaded, we need to do so.
	if nod->flags AND nfNotLoaded then
		LoadNode(nod)
	end if
	
	dim as integer siz, here = 0, here2, dif
	'siz = seek(f)
	siz = Buffered_tell(f)
	'put #f, , here 'will fill this in later, this is node content size
	Buffered_write(f, @here, 4)
	
	'here = seek(f)
	here = Buffered_tell(f)
	
	'strno = FindStringInTable(nod->name, doc)
	strno = nod->namenum
	if strno = -1 then
		debug "failed to find string " & *nod->name & " in string table"
		exit sub
	end if
	
	WriteVLI(f, strno)
	
	select case nod->nodeType
		case rltNull
			'Nulls have no data, but convey information by existing or not existing.
			'They can also have children.
			ub = rliNull
			Buffered_putc(f, ub)
		case rltInt 'this is good enough, don't need VLI for this
			if nod->num > 2147483647 or nod->num < -2147483648 then
				ub = rliLong
				Buffered_putc(f, ub)
				Buffered_write(f, @(nod->num), 8)
			elseif nod->num > 32767 or nod->num < -32768 then
				ub = rliInt
				Buffered_putc(f, ub)
				i = nod->num
				Buffered_write(f, @i, 4)
			elseif nod->num > 127 or nod->num < -128 then
				ub = rliShort
				Buffered_putc(f, ub)
				dim s as short = nod->num
				Buffered_write(f, @s, 2)
			else
				ub = rliByte
				Buffered_putc(f, ub)
				dim b as byte = nod->num
				Buffered_putc(f, b)
			end if
		case rltFloat
			ub = rliFloat
			Buffered_putc(f, ub)
			Buffered_write(f, @(nod->flo), 8)
		case rltString
			ub = rliString
			Buffered_putc(f, ub)
			WriteVLI(f, nod->strSize)
			Buffered_write(f, nod->str, nod->strSize)
	end select
	
	WriteVLI(f, nod->numChildren)
	dim n as NodePtr
	n = nod->children
	do while n <> null
		serializeBin(n, f, doc)
		n = n->nextSib
	loop
	
	here2 = Buffered_tell(f)
	dif = here2 - here
	Buffered_seek(f, siz)
	Buffered_write(f, @dif, 4)
	Buffered_seek(f, here2)
end sub

'this checks to see if a node is part of a tree, for example before adding to a new parent
Function verifyNodeLineage(byval nod as NodePtr, byval parent as NodePtr) as integer
	if nod = null then return no
	do while parent <> null
		if nod = parent then return no
		parent = parent->parent
	loop
	return yes
end function

'this checks to see whether a node is part of a given family or not
'FIXME: this looks like a slow debug routine to me, why is it used?
Function verifyNodeSiblings(byval sl as NodePtr, byval family as NodePtr) as integer
	dim s as NodePtr
	if sl = 0 then return no
	s = family
	do while s <> 0
		if s = sl then return no
		s = s->prevSib
	loop
	s = family
	do while s <> 0
		if s = sl then return no
		s = s->nextSib
	loop
	return yes
end function

'This marks a node as a string type and sets its data to the provided string
sub SetContent (byval nod as NodePtr, dat as string)
	if nod = null then exit sub
	if nod->nodeType = rltString then
		if nod->str then RDeallocate(nod->str, nod->doc)
		nod->str = 0
	end if
	nod->nodeType = rltString
	nod->str = RAllocate(len(dat) + 1, nod->doc)
	nod->strSize = len(dat)
	*nod->str = dat
end sub

'This marks a node as an integer, and sets its data to the provided integer
sub SetContent(byval nod as NodePtr, byval dat as longint)
	if nod = null then exit sub
	if nod->nodeType = rltString then
		if nod->str then RDeallocate(nod->str, nod->doc)
		nod->str = 0
	end if
	nod->nodeType = rltInt
	nod->num = dat
end sub

'This marks a node as a floating-point number, and sets its data to the provided double
sub SetContent(byval nod as NodePtr, byval dat as double)
	if nod = null then exit sub
	if nod->nodeType = rltString then
		if nod->str then RDeallocate(nod->str, nod->doc)
		nod->str = 0
	end if
	nod->nodeType = rltFloat
	nod->flo = dat
end sub

'This marks a node as a null node. It leaves the old data (but it's no longer accessible*)
'addendum: * - unless it was a string, in which case it's gone.
sub SetContent(byval nod as NodePtr)
	if nod = null then exit sub
	if nod->nodeType = rltString then
		if nod->str then RDeallocate(nod->str, nod->doc)
		nod->str = 0
	end if
	nod->nodeType = rltNull
end sub

'This removes a node from its parent node (eg, pruning it)
'It updates its parent and siblings as to their new relatives
Sub RemoveParent(byval nod as NodePtr)
	if nod->parent then
		'if we are the first child of the parent, special case!
		if nod->parent->children = nod then
			nod->parent->children = nod->nextSib
		end if
		'also again, special case!
		if nod->parent->lastChild = nod then
			nod->parent->lastChild = nod->prevSib
		end if
		
		'disown our parent
		nod->parent->numChildren -= 1
		nod->parent = null
		
		'update our brethren
		if nod->nextSib then
			nod->nextSib->prevSib = nod->prevSib
			nod->nextSib = null
		end if
		
		'them too
		if nod->prevSib then
			nod->prevSib->nextSib = nod->nextSib
			nod->prevSib = null
		end if
	end if
end sub

'This adds a node as a child to another node, updating their relatives
function AddChild(byval par as NodePtr, byval nod as NodePtr) as NodePtr
	
	'If a node is part of the tree already, we can't add it again
	if verifyNodeLineage(nod, par) = NO then return nod
	
	'first, remove us from our old parent
	RemoveParent(nod)
	
	'next, add us to our new parent
	if par then
		
		nod->parent = par
		par->numChildren += 1
		
		if par->children = null then
			par->children = nod
		else
			dim s as NodePtr = par->lastChild
			s->NextSib = nod
			nod->prevSib = s
		end if
		par->lastChild = nod
	end if
	
	return nod
end function

'This adds nod as a sibling *after* another node, sib.
function AddSiblingAfter(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
	
	if verifyNodeSiblings(nod, sib) = NO then return nod
	
	if sib = 0 then return nod
	
	nod->prevSib = sib
	nod->nextSib = sib->nextSib
	sib->nextSib = nod
	if nod->nextSib then
		nod->nextSib->prevSib = nod
	else
		sib->parent->lastChild = nod
	end if
	
	nod->parent = sib->parent
	sib->parent->numChildren += 1
	
	return nod
end function

'This adds nod as a sibling *before* another node, sib.
function AddSiblingBefore(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
	
	if verifyNodeSiblings(nod, sib) = NO then return nod
	
	if sib = 0 then return nod
	
	nod->nextSib = sib
	nod->prevSib = sib->prevSib
	sib->prevSib = nod
	if nod->prevSib then
		nod->prevSib->nextSib = nod
	else
		sib->parent->children = nod
	end if
	
	nod->parent = sib->parent
	sib->parent->numChildren += 1
	
	return nod
end function

'This promotes a node to Root Node status (which, really, isn't that big a deal.)
'NOTE: It automatically frees the old root node (unless it's the same as the new root node)
sub SetRootNode(byval doc as DocPtr, byval nod as NodePtr)
	if doc = null then return
	
	if doc->root = nod then return
	
	if verifyNodeLineage(nod, doc->root) = YES and verifyNodeLineage(doc->root, nod) = YES then
		FreeNode(doc->root)
	end if
	
	doc->root = nod
	
end sub

#define INDENTTAB !"\t"

'Serializes a document as XML to a file
sub SerializeXML (byval doc as DocPtr, byval fh as integer, byval debugging as integer = NO)
	if doc = null then exit sub
	
	SerializeXML(doc->root, fh, debugging)
end sub

'serializes a node as XML to standard out.
'It pretty-prints it by adding indentation.
sub SerializeXML (byval nod as NodePtr, byval fh as integer, byval debugging as integer, byval ind as integer = 0)
	if nod = null then exit sub
	
	if nod->flags AND nfNotLoaded then
		LoadNode(nod)
	end if
	
	dim closetag as integer = YES
	
	print #fh, string(ind, INDENTTAB);
	if nod->nodeType = rltNull and nod->numChildren = 0 then
		print #fh, "<" & *nod->name & " />"
		exit sub
	elseif debugging = NO andalso nod->nodeType <> rltNull andalso nod->numChildren = 0 andalso *nod->name = "" then
		'A no-name node like this is typically created when translating from xml;
		'so hide the tags
		ind -= 1
		closetag = NO
	else
		print #fh, "<" & *nod->name;
		
		'find the attribute children and print them
		dim n as NodePtr = nod->children
		do while n <> null
			if n->name[0] = asc("@") then
				print #fh, " " & *(n->name + 1) & "=""";
				print #fh, GetString(n);
				print #fh, """";
			end if
			n = n->nextSib
		loop

		print #fh, ">";
	end if

	if nod->nodeType <> rltNull then
		if nod->numChildren = 0 then
			print #fh, GetString(nod);
		else
			print #fh,
			print #fh, string(ind + 1, INDENTTAB) & GetString(nod)
		end if
	else
		print #fh,
	end if
	
	dim n as NodePtr = nod->children
	
	do while n <> null
		'we've already printed attributes, above
		if n->name[0] <> asc("@") then
			SerializeXML(n, fh, debugging, ind + 1)
		end if
		n = n->nextSib
	loop
	
	if nod->numChildren <> 0 then print #fh, string(ind, INDENTTAB);
	
	if closetag then
		print #fh, "</" & *nod->name & ">"
	else
		print #fh,
	end if
end sub

Function FindChildByName(byval nod as NodePtr, nam as string) as NodePtr
	'recursively searches for a child by name, depth-first
	'can also find self
	if nod = null then return null
	if *nod->name = nam then return nod
	
	if nod->flags AND nfNotLoaded then LoadNode(nod)
	
	dim child as NodePtr
	dim ret as NodePtr
	child = nod->children
	while child <> null
		ret = FindChildByName(child, nam)
		if ret <> null then return ret
		child = child->nextSib
	wend
	return null
End function

Function GetChildByName(byval nod as NodePtr, nam as string) as NodePtr
	'Not recursive!
	'does not find self.
	if nod = null then return null
	
	if nod->flags AND nfNotLoaded then LoadNode(nod)
	
	dim child as NodePtr
	dim ret as NodePtr
	child = nod->children
	while child <> null
		if *child->name = nam then return child
		child = child->nextSib
	wend
	return null
End Function

'This returns a node's content in string form.
Function GetString(byval node as nodeptr) as string
	if node = null then return ""
	
	select case node->nodeType
		case rltInt
			return str(node->num)
		case rltFloat
			return str(node->flo)
		case rltNull
			return ""
		case rltString
			return *node->str
		case else
			return "Unknown value: " & node->nodeType
	end select
End Function

'This returns a node's content in integer form. If the node is a string, and the string
'does not represent an integer of some kind, it will likely return 0.
'Also, null nodes are worth 0
Function GetInteger(byval node as nodeptr) as LongInt
	if node = null then return 0
	
	select case node->nodeType
		case rltInt
			return node->num
		case rltFloat
			return clngint(node->flo)
		case rltNull
			return 0
		case rltString
			return cint(*node->str)
		case else
			return 0
	end select
End Function

'This returns a node's content in floating point form. If the node is a string, and the string
'does not represent a number of some kind, it will likely return 0.
'Also, null nodes are worth 0
Function GetFloat(byval node as nodeptr) as Double
	if node = null then return 0.0
	
	select case node->nodeType
		case rltInt
			return cdbl(node->num)
		case rltFloat
			return node->flo
		case rltNull
			return 0.0
		case rltString
			return cdbl(*node->str)
		case else
			return 0.0
	end select
End Function

'This returns a node's content in ZString form (i.e., a blob of data.) If the node
'is not a string already, it will return null.
Function GetZString(byval node as nodeptr) as ZString ptr
	if node = null then return 0
	
	if node->nodeType <> rltString then
		return 0
	end if
	
	return node->str
End Function

Function GetZStringSize(byval node as nodeptr) as integer
	if node = null then return 0
	
	if node->nodeType <> rltString then
		return 0
	end if
	
	return node->strSize
End Function

'This resizes a node's string blob thing. If the node is not a string, it will
'return 0 and not do anything. Otherwise, it will resize it and return the new
'memory location. If it fails, it will return 0.
'If it succeeds, the old pointer is now invalid. Use the new pointer. (I.e., it follows
'the same rules as realloc()!
'Finally, the new memory block will be bigger than newsize by 1 byte. This is for the
'null terminator, in case you're storing an actual string in here. Please try not
'to overwrite it :)
Function ResizeZString(byval node as nodeptr, byval newsize as integer) as ZString ptr
	if node = null then return 0
	
	if node->nodeType <> rltString then
		return 0
	end if
	
	dim n as zstring ptr = node->str
	
	n = RReallocate(n, node->doc, newsize + 1)
	
	if n = 0 then return 0
	
	for i as integer = node->strSize to newsize
		n[i] = 0
	next
	
	node->str = n
	node->strSize = newsize
	
	return n
	
end function

'Sets the child node of name n to a null value. If n doesn't exist, it adds it
Function SetChildNode(byval parent as NodePtr, n as string) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	'first, check to see if this node already exists
	dim ret as NodePtr = GetChildByName(parent, n)
	
	'it doesn't, so add a new one
	if ret = 0 then
		ret = CreateNode(parent->doc, n)
		AddChild(parent, ret)
	end if
	
	SetContent(ret)
	
	return ret
end Function

'Sets the child node of name n to an integer value. If n doesn't exist, it adds it
Function SetChildNode(byval parent as NodePtr, n as string, byval val as longint) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	'first, check to see if this node already exists
	dim ret as NodePtr = GetChildByName(parent, n)
	
	'it doesn't, so add a new one
	if ret = 0 then
		ret = CreateNode(parent->doc, n)
		AddChild(parent, ret)
	end if
	
	SetContent(ret, val)
	
	return ret
end Function

'Sets the child node of name n to a floating point value. If n doesn't exist, it adds it
Function SetChildNode(byval parent as NodePtr, n as string, byval val as double) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	'first, check to see if this node already exists
	dim ret as NodePtr = GetChildByName(parent, n)
	
	'it doesn't, so add a new one
	if ret = 0 then
		ret = CreateNode(parent->doc, n)
		AddChild(parent, ret)
	end if
	
	SetContent(ret, val)
	
	return ret
end Function

'Sets the child node of name n to a string value. If n doesn't exist, it adds it
Function SetChildNode(byval parent as NodePtr, n as string, val as string) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	'first, check to see if this node already exists
	dim ret as NodePtr = GetChildByName(parent, n)
	
	'it doesn't, so add a new one
	if ret = 0 then
		ret = CreateNode(parent->doc, n)
		AddChild(parent, ret)
	end if
	
	SetContent(ret, val)
	
	return ret
end Function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeInt(byval parent as NodePtr, n as string, byval d as longint) as longint
	if parent = 0 then return d
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	return GetInteger(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeFloat(byval parent as NodePtr, n as string, byval d as double) as Double
	if parent = 0 then return d
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	
	return GetFloat(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeStr(byval parent as NodePtr, n as string, d as string) as string
	if parent = 0 then return d
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	
	return GetString(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeBool(byval parent as NodePtr, n as string, byval d as integer) as integer
	if parent = 0 then return d
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d <> 0
	
	return GetInteger(nod) <> 0 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and returns whether it finds it or not. For "flags", etc
Function GetChildNodeExists(byval parent as NodePtr, n as string) as integer
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	return nod <> 0
end function

'Appends a child node of name n with a null value.
Function AppendChildNode(byval parent as NodePtr, n as string) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim ret as NodePtr
	ret = CreateNode(parent->doc, n)
	AddChild(parent, ret)
	
	SetContent(ret)
	
	return ret
end Function

'Appends a child node of name n to with integer value.
Function AppendChildNode(byval parent as NodePtr, n as string, byval val as longint) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim ret as NodePtr = AppendChildNode(parent, n)
	SetContent(ret, val)
	
	return ret
end Function

'Appends a child node of name n with a floating point value.
Function AppendChildNode(byval parent as NodePtr, n as string, byval val as double) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim ret as NodePtr = AppendChildNode(parent, n)
	SetContent(ret, val)
	
	return ret
end Function

'Appends a child node of name n with a string value.
Function AppendChildNode(byval parent as NodePtr, n as string, val as string) as NodePtr
	if parent = 0 then return 0
	
	if parent->flags AND nfNotLoaded then LoadNode(parent)
	
	dim ret as NodePtr = AppendChildNode(parent, n)
	SetContent(ret, val)
	
	return ret
end Function

Function DocumentRoot(byval doc as DocPtr) as NodePtr
	return doc->root
end Function

Function NumChildren(byval nod as NodePtr) as Integer
	if nod->flags AND nfNotLoaded then LoadNode(nod) 'odds are, they're about to ask about the kids
	return nod->numChildren
end Function

Function FirstChild(byval nod as NodePtr) as NodePtr
	if nod->flags AND nfNotLoaded then LoadNode(nod)
	return nod->children
end Function

Function NextSibling(byval nod as NodePtr) as NodePtr
	return nod->nextSib
End Function

Function PrevSibling(byval nod as NodePtr) as NodePtr
	return nod->prevSib
End Function

Function NodeType(byval nod as NodePtr) as NodeTypes
	return nod->nodeType
End Function

Function NodeName(byval nod as NodePtr) as String
	return *nod->name
End Function


'This writes an integer out in such a fashion as to minimize the number of bytes used. Eg, 36 will
'be stored in one byte, while 365 will be stored in two, 10000 in three bytes, etc
Sub WriteVLI(byval f as integer, byval v as Longint)
	dim o as ubyte
	dim neg as integer = 0
	
	if o < 0 then
		neg = yes
		v = abs(v)
	end if
	
	o = v and &b111111 'first, extract the low six bits
	v = v SHR 6
	
	if neg then   o OR=  &b1000000 'bit 6 is the "number is negative" bit
	
	if v > 0 then o OR= &b10000000 'bit 7 is the "omg there's more data" bit
	
	put #f, , o
	
	do while v > 0
		o = v and &b1111111 'extract the next 7 bits
		v = v SHR 7
		
		if v > 0 then o OR= &b10000000
		
		put #f, , o
	loop

end sub

Sub WriteVLI(byval f as BufferedFile ptr, byval v as Longint)
	dim o as ubyte
	dim neg as integer = 0
	
	if o < 0 then
		neg = yes
		v = abs(v)
	end if
	
	o = v and &b111111 'first, extract the low six bits
	v = v SHR 6
	
	if neg then   o OR=  &b1000000 'bit 6 is the "number is negative" bit
	
	if v > 0 then o OR= &b10000000 'bit 7 is the "omg there's more data" bit
	
	Buffered_putc(f, o)
	
	do while v > 0
		o = v and &b1111111 'extract the next 7 bits
		v = v SHR 7
		
		if v > 0 then o OR= &b10000000
		
		Buffered_putc(f, o)
	loop

end sub

'This reads the number back in again
function ReadVLI(byval f as integer) as longint
	dim o as ubyte
	dim ret as longint = 0
	dim neg as integer = 0
	dim bit as integer = 0
	
	get #f, , o
	
	if o AND &b1000000 then neg = yes
	
	ret OR= (o AND &b111111) SHL bit
	bit += 6
	
	do while o AND &b10000000
		get #f, , o
		
		ret OR= (o AND &b1111111) SHL bit
		bit += 7
	loop
	
	if neg then ret *= -1
	
	return ret
	
end function

function ReadVLI(byval f as FILE ptr) as longint
	dim tmp as integer
	dim o as ubyte
	dim ret as longint = 0
	dim neg as integer = 0
	dim bit as integer = 0
	
	'get #f, , o
	tmp = fgetc(f)
	
	if tmp = -1 then return 0
	
	o = tmp
	
	if o AND &b1000000 then neg = yes
	
	ret OR= (o AND &b111111) SHL bit
	bit += 6
	
	do while o AND &b10000000
		'get #f, , o
		tmp = fgetc(f)
		if tmp = -1 then return 0
		
		o = tmp
		
		ret OR= (o AND &b1111111) SHL bit
		bit += 7
	loop
	
	if neg then ret *= -1
	
	return ret
	
end function


'I am aware of the hash table implementation in util.bas. However, this is tuned
'for this purpose. Plus, I want everything contained on the private heap (if applicable)
Type ReloadHashItem
	key as zstring ptr 
	item as any ptr 'this doesn't have to be a pointer...
	nxt as ReloadHashItem ptr
End Type

Type ReloadHash
	bucket as ReloadHashItem ptr ptr
	numBuckets as uinteger
	numItems as uinteger
	doc as DocPtr
	hashFunc as hashFunction
end Type


Function CreateHashTable(byval doc as Docptr, byval hashFunc as hashFunction, byval b as integer) as ReloadHash ptr
	dim ret as HashPtr = RAllocate(sizeof(ReloadHash), doc)
	
	with *ret
		.bucket = RAllocate(sizeof(ReloadHashItem ptr) * b, doc)
		.numBuckets = b
		.numItems = 0
		.doc = doc
		.hashFunc = hashFunc
	end with
	
	return ret
End Function

Sub DestroyHashTable(byval h as HashPtr)
	if h = 0 then return
	
	for i as integer = 0 to h->numBuckets - 1
		do while h->bucket[i]
			dim t as ReloadHashItem ptr
			t = h->bucket[i]->nxt
			RDeallocate(h->bucket[i], h->doc)
			h->bucket[i] = t
		loop
	next
	RDeallocate(h->bucket, h->doc)
	
	RDeallocate(h, h->doc)
end sub

Function FindItem(byval h as HashPtr, byval key as ZString ptr, byval num as integer) as any ptr
	dim b as ReloadHashItem ptr
	
	dim hash as integer = h->hashFunc(key)
	
	b = h->bucket[hash mod h->numBuckets]
	
	do while b
		if *b->key = *key then
			num -= 1
			if num <= 0 then return b->item
		end if
		b = b->nxt
	loop
	
	return 0
End Function

Sub AddItem(byval h as HashPtr, byval key as ZString ptr, byval item as any ptr)
	dim hash as integer = h->hashFunc(key)
	
	dim as ReloadHashItem ptr b, newitem = RAllocate(sizeof(ReloadHashItem), h->doc)
	
	newitem->key = key
	newitem->item = item
	newitem->nxt = 0
	
	b = h->bucket[hash mod h->numBuckets]
	
	if b then
		do while b->nxt
			b = b->nxt
		loop
		b->nxt = newitem
	else
		h->bucket[hash mod h->numBuckets] = newitem
	end if
end Sub

Sub RemoveKey(byval h as HashPtr, byval key as zstring ptr, byval num as integer)
	dim as ReloadHashItem ptr b, prev
	
	dim hash as integer = h->hashFunc(key)
	
	b = h->bucket[hash mod h->numBuckets]
	
	prev = 0
	do while b
		if *b->key = *key then
			if num <> -1 then
				num -= 1
				if num = 0 then
					if prev then
						prev->nxt = b->nxt
					end if
					
					RDeallocate(b, h->doc)
					return
				end if
			else
				if prev then
					prev->nxt = b->nxt
				end if
				
				RDeallocate(b, h->doc)
			end if
		end if
		prev = b
		b = b->nxt
	loop
end sub

Function MemoryUsage(byval doc as DocPtr) as longint
#if defined(__FB_WIN32__) and not defined(RELOAD_NOPRIVATEHEAP)
	dim ret as longint = 0
	if 0 = HeapLock(doc->heap) then return 0
	
	dim entry as PROCESS_HEAP_ENTRY
	
	entry.lpData = null
	do while HeapWalk(doc->heap, @entry) <> FALSE
		if entry.wFlags AND PROCESS_HEAP_ENTRY_BUSY then
			ret += entry.cbData
		end if
	loop
	
	HeapUnlock(doc->heap)
	
	return ret
#else
	return 0 'who knows?
#endif
end function

End Namespace
