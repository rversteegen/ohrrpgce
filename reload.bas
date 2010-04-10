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
#include "crt/stdio.bi"

#if defined(IS_GAME) or defined(IS_CUSTOM)
DECLARE SUB debug (s AS STRING)
#else
SUB debug (s AS STRING)
 print "debug: " & s
END SUB
#endif


Namespace Reload

Declare function ReadVLI(byval f as .FILE ptr) as longint
declare Sub WriteVLI(byval f as .FILE ptr, byval v as Longint)

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
		ret->numStrings = 0
		ret->numAllocStrings = 0
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
	ret->name = nam
	ret->nodeType = rltNull
	ret->numChildren = 0
	ret->children = null
	
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
	if nod->nodeType <> rltArray then
		do while nod->children <> 0
			FreeNode(nod->children)
		loop
	else
		for i as integer = 0 to nod->numChildren - 1
			FreeNode(nod->children + i, 1)
		next
	end if
	
	'If this node has a parent, we should remove this node from
	'its list of children
	if nod->parent <> 0 and (options and 1) = 0 then
		dim par as NodePtr = nod->parent
		
		if par->children = nod then
			par->children = nod->nextSib
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
	
	if RHeapDestroy(doc) then
		if doc->root then
			FreeNode(doc->root)
			doc->root = null
		end if
		
		if doc->strings then
			for i as integer = 0 to doc->numAllocStrings - 1
				if doc->strings[i] then
					RDeallocate(doc->strings[i], doc)
				end if
			next
			RDeallocate(doc->strings, doc)
			doc->strings = null
		end if
	end if
	
	'regardless of what heap is in use, doc is on the default heap
	delete doc
end sub

'This marks a node as a string type and sets its data to the provided string
sub SetContent (byval nod as NodePtr, dat as string)
	if nod = null then exit sub
	nod->nodeType = rltString
	nod->str = dat
end sub

'This marks a node as an integer, and sets its data to the provided integer
sub SetContent(byval nod as NodePtr, byval dat as longint)
	if nod = null then exit sub
	nod->nodeType = rltInt
	nod->num = dat
end sub

'This marks a node as a floating-point number, and sets its data to the provided double
sub SetContent(byval nod as NodePtr, byval dat as double)
	if nod = null then exit sub
	nod->nodeType = rltFloat
	nod->flo = dat
end sub

'This marks a node as a null node. It leaves the old data (but it's no longer accessible)
sub SetContent(byval nod as NodePtr)
	if nod = null then exit sub
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
			dim s as NodePtr
			s = par->children
			do while s->NextSib <> 0
				s = s->NextSib
			loop
			s->NextSib = nod
			nod->prevSib = s
			
		end if
	end if
	
	return nod
end function

'This adds the given node as a sibling *after* another node.
function AddSiblingAfter(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
	
	if verifyNodeSiblings(nod, sib) = NO then return nod
	
	if sib = 0 then return nod
	
	nod->prevSib = sib
	nod->nextSib = sib->nextSib
	sib->nextSib = nod
	if nod->nextSib then nod->nextSib->prevSib = nod
	
	nod->parent = sib->parent
	sib->parent->numChildren += 1
	
	return nod
end function

'This adds the given node as a sibling *before* another node.
function AddSiblingBefore(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
	
	if verifyNodeSiblings(nod, sib) = NO then return nod
	
	if sib = 0 then return nod
	
	nod->nextSib = sib
	nod->prevSib = sib->prevSib
	sib->prevSib = nod
	if nod->prevSib then nod->prevSib->nextSib = nod
	
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

'Internal function
'Locates a string in the string table. If it's not there, returns -1
Function FindStringInTable(st as string, doc as DocPtr) as integer
	if st = "" then return 0
	for i as integer = 0 to doc->numStrings - 1
		if *doc->strings[i] = st then return i + 1
	next
	return -1
end function

'Adds a string to the string table. If it already exists, return the index
'If it doesn't already exist, add it, and return the new index
Function AddStringToTable(st as string, doc as DocPtr) as integer
	dim ret as integer
	
	ret = FindStringInTable(st, doc)
	
	if ret <> -1 then return ret
	
	if doc->numAllocStrings = 0 then
		doc->strings = RAllocate(16 * sizeof(zstring ptr), doc)
		doc->numAllocStrings = 16
	else
		if doc->numStrings >= doc->numAllocStrings then 'I hope it's only ever equals...
			dim s as zstring ptr ptr = RReallocate(doc->strings, doc, sizeof(zstring ptr) * (doc->numAllocStrings * 2))
			if s = 0 then 'panic
				debug "Error resizing string table"
				return -1
			end if
			for i as integer = doc->numAllocStrings to doc->numAllocStrings * 2 - 1
				s[i] = 0
			next
			
			doc->strings = s
			doc->numAllocStrings = doc->numAllocStrings * 2
		end if
	end if
	
	doc->strings[doc->numStrings] = RAllocate(len(st) + 1, doc)
	*doc->strings[doc->numStrings] = st
	doc->numStrings += 1
	
	return doc->numStrings
end function

'This traverses a node tree, and gathers all the node names into a string table
sub BuildStringTable(byval nod as NodePtr, doc as DocPtr)
	static start as NodePtr
	
	if nod = null then exit sub
	
	if start = 0 then
		start = nod
	end if
	
	AddStringToTable(nod->name, doc)
	
	dim n as NodePtr
	
	n = nod->children
	do while n <> 0
		BuildStringTable(n, doc)
		n = n->nextSib
	loop
	
	if start = nod then
		start = null
	end if
end sub

'Serializes a document as XML to standard out
sub SerializeXML (byval doc as DocPtr)
	if doc = null then exit sub
	
	serializeXML(doc->root)
end sub

'serializes a node as XML to standard out.
'It pretty-prints it by adding indentation.
sub serializeXML (byval nod as NodePtr, byval ind as integer = 0)
	if nod = null then exit sub
	
	print string(ind, "	");
	if nod->nodeType = rltArray then
		print "<" & nod->name & "reload:array=""array"">"
	elseif nod->nodeType <> rltNull or nod->numChildren <> 0 then
		if nod->name <> "" then
			print "<" & nod->name & ">";
		end if
	elseif nod->nodeType = rltNull and nod->numChildren = 0 then
		print "<" & nod->name & " />"
		exit sub
	end if
	
	if nod->nodeType <> rltNull and nod->numChildren <> 0 then print
	
	select case nod->nodeType
		case rltInt
			print "" & nod->num;
		case rltFloat
			print "" & nod->flo;
		case rltString
			print "" & nod->str;
		'case rltNull
		'	print ;
	end select
	
	if nod->numChildren <> 0 then print
	
	dim n as NodePtr = nod->children
	
	if nod->nodeType <> rltArray then
		do while n <> null
			serializeXML(n, ind + 1)
			n = n->nextSib
		loop
	else
		for i as integer = 0 to nod->numChildren - 1
			serializeXML(n + i, ind + 1)
		next
	end if
	
	if nod->numChildren <> 0 then print string(ind, "	");
	
	if nod->nodeType <> rltNull or nod->numChildren <> 0 then
		if nod->name <> "" then
			print "</" & nod->name & ">"
		else
			print
		end if
	end if
	
end sub

Declare sub serializeBin(byval nod as NodePtr, byval f as .FILE ptr, byval doc as DocPtr)

'This serializes a document as a binary file. This is where the magic happens :)
sub SerializeBin(file as string, byval doc as DocPtr)
	if doc = null then exit sub
	
	dim f as .FILE ptr
	
	BuildStringTable(doc->root, doc)
	
	'In case things go wrong, we serialize to a temporary file first
	if dir(file & ".tmp") <> "" then
		kill file & ".tmp"
	end if
	
	f = fopen(file & ".tmp", "wb")
	
	if f = 0 then
		debug "Unable to open file"
		exit sub
	end if
	
	dim i as uinteger, b as ubyte
	
	fputs("RELD", f) 'magic signature
	
	fputc(1, f)'version
	
	i = 13 'the size of the header (i.e., offset to the data)
	fwrite(@i, 4, 1, f)
	
	i = 0 'we're going to fill this in later. it is the string table post relative to the beginning of the file.
	fwrite(@i, 4, 1, f) 
	
	'write out the body
	serializeBin(doc->root, f, doc)
	
	'this is the location of the string table (immediately after the data)
	i = ftell(f)
	
	fseek(f, 9, 0) 
	fwrite(@i, 4, 1, f) 'filling in the string table position
	
	'jump back to the string table
	fseek(f, i, 0)
	
	'first comes the number of strings
	writeVLI(f, doc->numStrings)
	
	'then, write out each string, size then body
	for i = 0 to doc->numStrings - 1
		dim zs as zstring ptr = doc->strings[i]
		writeVLI(f, len(*zs))
		fputs(zs, f)
	next
	fclose(f)
	
	kill file
	rename file & ".tmp", file
	kill file & ".tmp"
end sub

sub serializeBin(byval nod as NodePtr, byval f as .FILE ptr, byval doc as DocPtr)
	if nod = 0 then
		debug "serializeBin null node ptr"
		exit sub
	end if
	dim i as integer, strno as longint, ub as ubyte
	
	dim as integer siz, here = 0, here2, dif
	'siz = seek(f)
	siz = ftell(f)
	'put #f, , here 'will fill this in later, this is node content size
	fwrite(@here, 4, 1, f)
	
	'here = seek(f)
	here = ftell(f)
	
	strno = FindStringInTable(nod->name, doc)
	if strno = -1 then
		debug "failed to find string " & nod->name & " in string table"
		exit sub
	end if
	
	WriteVLI(f, strno)
	
	select case nod->nodeType
		case rltNull
			'Nulls have no data, but convey information by existing or not existing.
			'They can also have children.
			ub = rliNull
			fputc(ub, f)
		case rltInt 'this is good enough, don't need VLI for this
			if nod->num > 2147483647 or nod->num < -2147483648 then
				ub = rliLong
				fputc(ub, f)
				fwrite(@(nod->num), 8, 1, f)
			elseif nod->num > 32767 or nod->num < -32768 then
				ub = rliInt
				fputc(ub, f)
				i = nod->num
				fwrite(@i, 4, 1, f)
			elseif nod->num > 127 or nod->num < -128 then
				ub = rliShort
				fputc(ub, f)
				dim s as short = nod->num
				fwrite(@s, 2, 1, f)
			else
				ub = rliByte
				fputc(ub, f)
				dim b as byte = nod->num
				fputc(b, f)
			end if
		case rltFloat
			ub = rliFloat
			fputc(ub, f)
			fwrite(@(nod->flo), 8, 1, f)
		case rltString
			ub = rliString
			fputc(ub, f)
			WriteVLI(f, len(nod->str))
			fputs(nod->str, f)
			
	end select
	
	WriteVLI(f, nod->numChildren) 'is this cast necessary?
	
	dim n as NodePtr
	n = nod->children
	do while n <> null
		serializeBin(n, f, doc)
		n = n->nextSib
	loop
	
	here2 = ftell(f)
	dif = here2 - here
	fseek(f, siz, 0)
	fwrite(@dif, 4, 1, f)
	fseek(f, here2, 0)
end sub

Function FindChildByName(byval nod as NodePtr, nam as string) as NodePtr
	'recursively searches for a child by name, depth-first
	'can also find self
	if nod = null then return null
	if nod->name = nam then return nod
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
	dim child as NodePtr
	dim ret as NodePtr
	child = nod->children
	while child <> null
		if child->name = nam then return child
		child = child->nextSib
	wend
	return null
End Function

'Loads a node from a binary file, into a document
Function LoadNode(f as .FILE ptr, byval doc as DocPtr) as NodePtr
	dim ret as NodePtr
	
	ret = CreateNode(doc, "!") '--the "!" indicates no tag name has been loaded for this node yet
	
	dim size as integer
	
	dim as integer here, here2
	fread(@size, 4, 1, f)
	
	here = ftell(f)
	
	ret->namenum = cshort(ReadVLI(f))
	
	ret->nodetype = fgetc(f)
	
	select case ret->nodeType
		case rliNull
		case rliByte
			ret->num = fgetc(f)
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
			mysize = cint(ReadVLI(f))
			ret->str = string(mysize, " ")
			fread(strptr(ret->str), 1, mysize, f)
			ret->nodeType = rltString
		case else
			debug "unknown node type " & ret->nodeType
			FreeNode(ret)
			return null
	end select
	
	
	
	dim nod as nodeptr
	
	ret->numChildren = ReadVLI(f)
	
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
	
	return ret
End Function

'This loads the string table from a binary document (as if the name didn't clue you in)
Sub LoadStringTable(byval f as .FILE ptr, byval doc as docptr)
	dim as uinteger count, size
	
	count = cint(ReadVLI(f))
	
	if count <= 0 then exit sub
	
	if doc->strings <> 0 then
		for i as integer = 0 to doc->numAllocStrings - 1
			RDeallocate(doc->strings[i], doc)
		next
		RDeallocate(doc->strings, doc)
	end if
	
	doc->strings = RAllocate(count * sizeof(zstring ptr), doc)
	doc->numStrings = count
	doc->numAllocStrings = count
	
	for i as integer = 0 to count - 1
		size = cint(ReadVLI(f))
		'get #f, , size
		doc->strings[i] = RAllocate(size + 1, doc)
		dim zs as zstring ptr = doc->strings[i]
		if size > 0 then
			fread(zs, 1, size, f)
		end if
	next
end sub

'After loading a binary document, the in-memory nodes don't have names, only numbers represting entries
'in the string table. This function fixes that by copying out of the string table
function FixNodeName(byval nod as nodeptr, byval doc as DocPtr) as integer
	if nod = null then return -1
	
	if nod->namenum > doc->numStrings + 1 or nod->namenum < 0 then
		return -1
	end if
	
	if nod->namenum > 0 then
		nod->name = *doc->strings[nod->namenum - 1]
	else
		nod->name = ""
	end if
	
	dim tmp as nodeptr = nod->children
	do while tmp <> null
		FixNodeName(tmp, doc)
		tmp = tmp->nextSib
	loop
	
	return 0
end function

Function LoadDocument(fil as string, byval options as LoadOptions) as DocPtr
	dim ret as DocPtr
	dim f as .FILE ptr
	
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
		debug "No RELD magic"
		return null
	end if
	
	ver = fgetc(f)
	
	select case ver
		case 1 ' no biggie
			fread(@headSize, 4, 1, f)
			if headSize <> 13 then 'uh oh, the header is the wrong size
				fclose(f)
				debug "Reload header is " & headSize & "instead of 13"
				return null
			end if
			
			fread(@datSize, 4, 1, f)
			
		case else ' dunno. Let's quit.
			fclose(f)
			debug "Reload version " & ver & " not supported"
			return null
	end select
	
	'if we got here, the document is... not yet corrupt. I guess.
	
	ret = CreateDocument()
	ret->version = ver
	
	ret->root = LoadNode(f, ret)
	
	'Is it possible to serialize a null root? I mean, I don't know why you would want to, but...
	'regardless, if it's null here, it's because of an error
	if ret->root = null then
		fclose(f)
		FreeDocument(ret)
		return null
	end if
	
	fseek(f, datSize, 0)
	LoadStringTable(f, ret)
	
	'String table: Apply directly to the document tree
	'String table: Apply directly to the document tree
	'String table: Apply directly to the document tree
	FixNodeName(ret->root, ret)
	
	fclose(f)
	
	return ret
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
			return node->str
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
			return cint(node->str)
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
			return cdbl(node->str)
		case else
			return 0.0
	end select
End Function

'Sets the child node of name n to a null value. If n doesn't exist, it adds it
Function SetChildNode(parent as NodePtr, n as string) as NodePtr
	if parent = 0 then return 0
	
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
Function SetChildNode(parent as NodePtr, n as string, val as longint) as NodePtr
	if parent = 0 then return 0
	
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
Function SetChildNode(parent as NodePtr, n as string, val as double) as NodePtr
	if parent = 0 then return 0
	
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
Function SetChildNode(parent as NodePtr, n as string, val as string) as NodePtr
	if parent = 0 then return 0
	
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
Function GetChildNodeInt(parent as NodePtr, n as string, d as longint) as longint
	if parent = 0 then return d
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	return GetInteger(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeFloat(parent as NodePtr, n as string, d as double) as Double
	if parent = 0 then return d
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	
	return GetFloat(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeStr(parent as NodePtr, n as string, d as string) as string
	if parent = 0 then return d
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d
	
	return GetString(nod) 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and retrieves its value. d is the default, if n doesn't exist
Function GetChildNodeBool(parent as NodePtr, n as string, d as integer) as integer
	if parent = 0 then return d
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	if nod = 0 then return d <> 0
	
	return GetInteger(nod) <> 0 'yes, I realize I don't check for null. GetInteger does, though.
end function

'looks for a child node of the name n, and returns whether it finds it or not. For "flags", etc
Function GetChildNodeExists(parent as NodePtr, n as string) as integer
	if parent = 0 then return 0
	
	dim nod as NodePtr = GetChildByName(parent, n)
	
	return nod <> 0
end function

Function DocumentRoot(byval doc as DocPtr) as NodePtr
	return doc->root
end Function

Function NumChildren(byval nod as NodePtr) as Integer
	return nod->numChildren
end Function

Function FirstChild(byval nod as NodePtr) as NodePtr
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
	return nod->name
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

Sub WriteVLI(byval f as .FILE ptr, byval v as Longint)
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
	
	fputc(o, f)
	'put #f, , o
	
	do while v > 0
		o = v and &b1111111 'extract the next 7 bits
		v = v SHR 7
		
		if v > 0 then o OR= &b10000000
		
		'put #f, , o
		fputc(o, f)
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

function ReadVLI(byval f as .FILE ptr) as longint
	dim o as ubyte
	dim ret as longint = 0
	dim neg as integer = 0
	dim bit as integer = 0
	
	'get #f, , o
	o = fgetc(f)
	
	if o AND &b1000000 then neg = yes
	
	ret OR= (o AND &b111111) SHL bit
	bit += 6
	
	do while o AND &b10000000
		'get #f, , o
		o = fgetc(f)
		
		ret OR= (o AND &b1111111) SHL bit
		bit += 7
	loop
	
	if neg then ret *= -1
	
	return ret
	
end function


Sub TestStringTables()
	dim d as docptr = CreateDocument()
	dim s as string
	
	for i as integer = 0 to 1200 step 3
		s = str(i)
		
		if i = 2925 then
			dim q as integer = 0
		end if
		
		print s & " - " & AddStringToTable(s, d)
	next
	
	FreeDocument(d)
	
end sub


End Namespace
