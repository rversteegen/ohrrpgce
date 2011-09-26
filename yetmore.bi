#ifndef YETMORE_BI
#define YETMORE_BI

DECLARE SUB add_rem_swap_lock_hero (box as TextBox)
DECLARE FUNCTION checksaveslot (slot as integer) as integer
DECLARE SUB erasesaveslot (slot as integer)
DECLARE SUB load_special_tag_caches ()
DECLARE SUB embedtext (text as string, byval limit as integer=0)
DECLARE SUB scriptstat (byval id as integer)
DECLARE SUB forceparty ()
DECLARE FUNCTION gethighbyte (byval n as integer) as integer
DECLARE FUNCTION getnpcref (byval seekid as integer, byval offset as integer) as integer
DECLARE FUNCTION get_valid_npc (byval seekid as integer, byval errlvl as integer = 5) as integer
DECLARE FUNCTION get_valid_npc_id (byval seekid as integer, byval errlvl as integer = 5) as integer
DECLARE SUB greyscalepal
DECLARE FUNCTION herobyrank (byval slot as integer) as integer
DECLARE SUB interpolatecat
DECLARE SUB onkeyscript (byval scriptnum as integer)
DECLARE FUNCTION playtime (byval d as integer, byval h as integer, byval m as integer) as string
DECLARE SUB playtimer
DECLARE FUNCTION rank_to_party_slot (byval rank as integer) as integer
DECLARE FUNCTION party_slot_to_rank (byval slot as integer) as integer
DECLARE FUNCTION rankincaterpillar (byval heroid as integer) as integer
DECLARE SUB scriptadvanced (byval id as integer)
DECLARE SUB scriptmisc (byval id as integer)
DECLARE SUB scriptnpc (byval id as integer)
DECLARE SUB setdebugpan
DECLARE SUB tweakpalette (byval r as integer, byval g as integer, byval b as integer, byval first as integer = 0, byval last as integer = 255)
DECLARE SUB update_vehicle_state ()
DECLARE FUNCTION vehpass (byval n as integer, byval tile as integer, byval default as integer) as integer
DECLARE SUB vehicle_graceful_dismount ()
DECLARE SUB vishero ()
DECLARE SUB visnpc ()
DECLARE SUB set_walkabout_sprite (byval cont as Slice Ptr, byval pic as integer=-1, byval pal as integer=-2)
DECLARE SUB set_walkabout_frame (byval cont as Slice Ptr, byval direction as integer, byval frame as integer)
DECLARE SUB set_walkabout_vis (byval cont as Slice Ptr, byval vis as integer)
DECLARE SUB wrapaheadxy (byref x as integer, byref y as integer, byval direction as integer, byval distance as integer, byval unitsize as integer)
DECLARE SUB cropposition (byref x as integer, byref y as integer, byval unitsize as integer)
DECLARE FUNCTION wrappass (byval x as integer, byval y as integer, byref xgo as integer, byref ygo as integer, byval isveh as integer) as integer
DECLARE FUNCTION wrapzonetest (byval zone as integer, byval x as integer, byval y as integer, byval xgo as integer, byval ygo as integer) as integer
DECLARE FUNCTION wrapcollision (byval xa as integer, byval ya as integer, byval xgoa as integer, byval ygoa as integer, byval xb as integer, byval yb as integer, byval xgob as integer, byval ygob as integer) as integer
DECLARE FUNCTION wraptouch (byval x1 as integer, byval y1 as integer, byval x2 as integer, byval y2 as integer, byval distance as integer) as integer
DECLARE SUB wrappedsong (byval songnumber as integer)
DECLARE SUB stopsong
DECLARE SUB wrapxy (byref x as integer, byref y as integer, byval wide as integer, byval high as integer)
DECLARE FUNCTION backcompat_sound_id (byval id as integer) as integer
DECLARE SUB loadsay (byval box_id as integer)
DECLARE SUB load_text_box_portrait (byref box as TextBox, byref gfx as GraphicPair)
DECLARE FUNCTION valid_plotslice(byval handle as integer, byval errlev as integer=5) as integer
DECLARE FUNCTION valid_plotsprite(byval handle as integer) as integer
DECLARE FUNCTION valid_plotrect(byval handle as integer) as integer
DECLARE FUNCTION valid_plottextslice(byval handle as integer) as integer
DECLARE FUNCTION valid_plotgridslice(byval handle as integer) as integer
DECLARE FUNCTION valid_resizeable_slice(byval handle as integer, byval ignore_fill as integer=NO) as integer
DECLARE FUNCTION create_plotslice_handle(byval sl as Slice Ptr) as integer
DECLARE FUNCTION find_plotslice_handle(byval sl as Slice Ptr) as integer
DECLARE FUNCTION load_sprite_plotslice(byval spritetype as integer, byval record as integer, byval pal as integer=-2) as integer
DECLARE SUB replace_sprite_plotslice(byval handle as integer, byval spritetype as integer, byval record as integer, byval pal as integer=-2)
DECLARE SUB change_rect_plotslice(byval handle as integer, byval style as integer=-2, byval bgcol as integer=-1, byval fgcol as integer=-1, byval border as integer=-3, byval translucent as RectTransTypes=transUndef)
DECLARE FUNCTION valid_spriteslice_dat(byval sl as Slice Ptr) as integer
DECLARE SUB vehscramble(byref mode_val as integer, byval trigger_cleanup as integer, byval targx as integer, byval targy as integer)
DECLARE SUB write_checkpoint ()

#endif
