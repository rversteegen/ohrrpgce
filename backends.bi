'' Header for backends.bas. See gfx.bi and music.bi for the actual interfaces

#ifndef BACKENDS_BI
#define BACKENDS_BI

declare sub load_preferred_gfx_backend ()
declare sub init_preferred_gfx_backend ()
declare sub prefer_gfx_backend overload (name as string)
declare function backends_setoption (opt as string, arg as string) as integer
declare function switch_gfx_backend (name as string) as bool
declare sub read_backend_info ()
declare function valid_gfx_backend (name as string) as bool

declare sub gfx_backend_menu ()
declare sub music_backend_menu ()

'''''' Utilities for dynamic loading

type DynamicSymbolInfo
	symptr as any ptr ptr  'Address of the function/symbol pointer to lookup
	name as zstring ptr
	need as bool
end type

declare sub add_dynamic_sym(symptr as any ptr ptr, name as zstring ptr, need as bool)

#MACRO SHADOW_SYMBOL(sym, need)
  TYPE _remem_type as TYPEOF(@sym)
  #UNDEF sym
  DIM SHARED sym as _remem_type
  add_dynamic_sym(@sym, #sym, need)
  #UNDEF _remem_type
#ENDMACRO

#DEFINE NEED_FUNC(x) SHADOW_SYMBOL(x, YES)
#DEFINE WANT_FUNC(x) SHADOW_SYMBOL(x, NO)

extern symbol_info_vector as DynamicSymbolInfo vector ptr

extern wantpollingthread as bool
extern as string gfxbackend, musicbackend
extern as string gfxbackendinfo, musicbackendinfo, systeminfo
'This is shared between gfx_alleg and music_allegro
extern allegro_initialised as bool

#endif BACKENDS_BI
