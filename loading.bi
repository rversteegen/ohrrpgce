'OHRRPGCE - loading.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from loading.bas

#IFNDEF LOADING_BI
#DEFINE LOADING_BI

declare sub loadnpcd(file as string, dat() as npctype)
declare sub setnpcd(npcd as npctype, offset as integer, value as integer)
declare function getnpcd(npcd as npctype, offset as integer) as integer
declare sub cleannpcd(dat() as npctype)
declare sub loadnpcl(file as string, dat() as npcinst, num as integer)
declare sub sernpcl(npc() as npcinst, z, buffer(), num as integer, xoffset as integer, yoffset as integer)
declare sub desernpcl(npc() as npcinst, z, buffer(), num as integer, xoffset as integer, yoffset as integer)
declare sub cleannpcl(dat() as npcinst, num as integer)
declare sub serinventory(invent() as inventslot, z, buf())
declare sub deserinventory(invent() as inventslot, z, buf())
declare sub cleaninventory(invent() as inventslot)
declare sub loadtiledata(filename as string, array(), byval numlayers as integer = 1, byref wide as integer = 0, byref high as integer = 0)
declare sub savetiledata(filename as string, array(), byval numlayers as integer = 1)
declare sub cleantiledata(array(), wide as integer, high as integer, numlayers as integer = 1)
declare SUB DeserDoorLinks(filename as string, array() as doorlink)
declare Sub SerDoorLinks(filename as string, array() as doorlink, withhead as integer = 1)
declare sub CleanDoorLinks(array() as doorlink)
declare Sub DeSerDoors(filename as string, array() as door, record as integer)
declare Sub SerDoors(filename as string, array() as door, record as integer)
declare Sub CleanDoors(array() as door)
declare Sub LoadStats(fh as integer, sta as stats ptr)
declare Sub SaveStats(fh as integer, sta as stats ptr)
declare Sub LoadStats2(fh as integer, lev0 as stats ptr, lev99 as stats ptr)
declare Sub SaveStats2(fh as integer, lev0 as stats ptr, lev99 as stats ptr)
declare Sub DeSerHeroDef(filename as string, hero as herodef ptr, record as integer)
declare Sub SerHeroDef(filename as string, hero as herodef ptr, record as integer)
declare Sub LoadMenuData(menusfile AS STRING, menuitemfile AS STRING, dat AS MenuDef, record AS INTEGER)
declare Sub LoadMenuItems(menuitemfile AS STRING, mi() AS MenuDefItem, record AS INTEGER)
declare Sub SortMenuItems(mi() AS MenuDefItem)
declare Sub LoadVehicle (file AS STRING, veh(), vehname$, record AS INTEGER)
declare Sub SaveVehicle (file AS STRING, veh(), vehname$, record AS INTEGER)

#ENDIF
