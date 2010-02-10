#ifndef RELOAD_BI
#define RELOAD_BI

'OHRRPGCE COMMON - XML related functions
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'

#include "udts.bi"

#ifndef null
#define null 0
#endif

Namespace Reload

ENUM NodeInTypes
	rliNull = 0
	rliByte = 1
	rliShort = 2
	rliInt = 3
	rliLong = 4
	rliFloat = 5
	rliString = 6
END ENUM

ENUM NodeTypes
	rltNull
	rltInt
	rltFloat
	rltString
END ENUM

TYPE DocPtr as Doc ptr
TYPE NodePtr as Node ptr
TYPE NodeSetPtr as NodeSet Ptr

TYPE Doc
	version as integer
	root as NodePtr
END TYPE

TYPE Node
	name as string
	namenum as short 'in the string table, used while loading
	nodeType as ubyte
	str as string
	num as LongInt
	flo as Double
	numChildren as integer
	children as NodePtr
	doc as DocPtr
	parent as NodePtr
	nextSib as NodePtr
	prevSib as NodePtr
END TYPE

Type NodeSet
	numNodes as integer
	doc as DocPtr
	nodes as NodePtr Ptr
End Type

Type RPathFragment
	nodename as string
end Type

Type RPathCompiledQuery
	numFragments as integer
	fragment as RPathFragment ptr
End Type

Declare Function CreateDocument() as DocPtr
Declare Function CreateNode(byval doc as DocPtr, nam as string) as NodePtr
Declare sub FreeNode(byval nod as NodePtr)
Declare sub FreeDocument(byval doc as DocPtr)
Declare sub SetContent Overload (byval nod as NodePtr, dat as string)
Declare sub SetContent(byval nod as NodePtr, byval dat as longint)
Declare sub setContent(byval nod as NodePtr, byval dat as double)
Declare sub setContent(byval nod as NodePtr)
Declare Function AddSiblingBefore(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
Declare Function AddSiblingAfter(byval sib as NodePtr, byval nod as NodePtr) as NodePtr
Declare Function AddChild(byval par as NodePtr, byval nod as NodePtr) as NodePtr
Declare sub SetRootNode(byval doc as DocPtr, byval nod as NodePtr)

Declare Function LoadDocument(fil as string) as DocPtr

Declare sub SerializeXML overload (byval doc as DocPtr)
Declare sub serializeXML (byval nod as NodePtr, byval ind as integer = 0)

Declare sub SerializeBin overload (file as string, byval doc as DocPtr)
Declare sub serializeBin (byval nod as NodePtr, byval f as integer = 0, table() as string)

Declare Function GetString(byval node as nodeptr) as string
Declare Function GetInteger(byval node as nodeptr) as LongInt
Declare Function GetFloat(byval node as nodeptr) as Double

Declare Function GetChildByName(byval nod as NodePtr, nam as string) as NodePtr 'NOT recursive
Declare Function FindChildByName(byval nod as NodePtr, nam as string) as NodePtr 'recursive depth first search

Declare function ReadVLI(byval f as integer) as longint
declare Sub WriteVLI(byval f as integer, byval v as Longint)

Declare Function RPathCompile(query as string) as RPathCompiledQuery Ptr
Declare Sub RPathFreeCompiledQuery(byval rpf as RPathCompiledQuery ptr)

Declare Function RPathQuery Overload(query as String, byval context as NodePtr) as NodeSetPtr
Declare Function RPathQuery Overload(byval query as RPathCompiledQuery Ptr, byval context as NodePtr) as NodeSetPtr

End Namespace

#endif
