#ifndef MENUSTUF_BI
#define MENUSTUF_BI
DECLARE SUB buystuff (byval shop_id as integer, byval shoptype as integer, storebuf() as integer)
DECLARE FUNCTION chkOOBtarg (byval target as integer, byval atk as integer) as integer
DECLARE SUB update_hero_max_and_cur_stats (byval who as integer)
DECLARE SUB doequip (byval toequip as integer, byval who as integer, byval where as integer, byval defwep as integer)
DECLARE SUB equip (byval who as integer)
DECLARE FUNCTION getOOBtarg (byval search_direction as integer, byref target as integer, byval atk as integer, byval recheck as integer=NO) as integer
DECLARE SUB itemmenuswap (invent() as InventSlot, iuse() as integer, permask() as integer, byval it1 as integer, byval it2 as integer)
DECLARE FUNCTION items_menu () as integer
DECLARE FUNCTION use_item_by_id(byval item_id as integer, byref trigger_box as integer, name_override as string="") as integer
DECLARE FUNCTION use_item_in_slot(byval slot as integer, byref trigger_box as integer, byref consumed as bool=NO) as integer
DECLARE SUB update_inventory_caption (byval i as integer)
DECLARE SUB oobcure (byval attacker as integer, byval target as integer, byval atk as integer, byval target_count as integer)
DECLARE SUB patcharray (array() as integer, n as string)
DECLARE FUNCTION picksave (byval loading as integer) as integer
DECLARE SUB sellstuff (byval id as integer, storebuf() as integer)
DECLARE SUB spells_menu (byval who as integer)
DECLARE SUB status (byval pt as integer)
DECLARE FUNCTION trylearn (byval who as integer, byval atk as integer) as bool
DECLARE SUB unequip (byval who as integer, byval where as integer, byval defwep as integer, byval resetdw as integer)
DECLARE SUB loadshopstuf (array() as integer, byval id as integer)
DECLARE FUNCTION count_available_spells(byval who as integer, byval list as integer) as integer
DECLARE FUNCTION outside_battle_cure (byval atk as integer, byref target as integer, byval attacker as integer, byval spread as integer) as integer
DECLARE SUB purchases_menu ()
DECLARE FUNCTION get_enabled_store_name () as string
DECLARE FUNCTION sanity_check_store_name(storename as string) as string
DECLARE FUNCTION product_enabled_for_current_store(byval prod as NodePtr) as bool
DECLARE SUB do_purchase_action (byval prod as NodePtr, byval new_purch as bool=YES)

DECLARE FUNCTION get_persist_reld() as NodePtr
DECLARE SUB write_persist_reld()
DECLARE SUB close_persist_reld()

#endif
