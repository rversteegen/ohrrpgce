

'An CauseHdl is a string of the form "^@1234" where 1234 is a handle to an effect
'in the cause tree
type CauseHdl as string

#ifdef NO_CAUSES
'Smaller compiles

#define effect(text)
#define cause(causes...)

#else

'Using an CauseHdl is equivalent to stating the name of the cause, but
'prevents confusion and is simpler.

'cause should be called after its causes are declared, if at all, otherwise they won't be linked.
'causes of an effect can either be explicitly listed: explicit causes
'or they can occur as effects before the effect: implicit causes.
'causalbreak(): things after not caused by things before
'begincauses(), endcauses(): build a 
'CausalUnit: RAII wrapper for begin/endcauses
'timetempL separates cause and effect

declare sub causalbreak()
declare sub begin_causes(context as zstring ptr, subject as zstring ptr = 0)
declare sub end_causes()

'example: CausalUnit in textbox After conditionals handling.

'-----------Modifiers-----------
'Modifiers take an existing effect and add more information to them. This changes
'their description or adds metadata.
'Of course, the modification itself can have causes, but these are separate from the causes
'of the original effect.
'E.g. SpawnEnemy later Failed
'
'question: In UI, should show
'Failed Effect
' <=Effect
'   <-...
' <=Failure
'   <-...
'or
'Effect
'| <-...
'Failure of Effect
'  <-...
'?

declare function Failed overload (ef as CauseNode ptr, causes...) as CauseNode ptr
declare function Failed overload (ef as zstring ptr, causes...) as CauseNode ptr

'Used inside a context, says the context failed. The direct causes are optional.
'All effects up to this point in the context are also implicit causes.
declare sub failure overload (causes...)

declare function Delayed(ef as string, causes...) as string
'declare sub Metadata(ef as string, meta as string)
'declare sub About(ef as string, meta as string)


declare function effect (text as string) as CauseHdl

'FB doesn't support functions with a variable number of arguments when using -gen gcc,
'but still can call them. So we use a small C helper function to stuff the args into an array.
#define cause(args...)  cause_vararg_helper(_cause, args...)

#macro pass_temp_array(func, args...)
        scope
                var _arr = {args...}
                func(_
        end scope
#endmacro

#define cause(args...) pass_temp_array(_cause, args...)


declare function cause overload (caused as string, cause1 as string) as CauseHdl
declare function cause overload (caused as string, cause1 as string, cause2 as string) as CauseHdl
declare function cause overload (caused as string, cause1 as string, cause2 as string, cause3 as string) as CauseHdl
declare function cause overload (caused as string, cause1 as string, cause2 as string, cause3 as string, cause4 as string) as CauseHdl

#endif

type CauseNode
        text as string
        handle as integer
        'Another tree implementation, another naming scheme!
        firstChild as CauseNode ptr
        lastChild as CauseNode ptr
        nextSibling as CauseNode ptr

        declare constructor(text as zstring ptr)
end type

extern cause_tree as CauseNode

type CausalContextType
        declare constructor(context as zstring ptr, subject as zstring ptr = 0)
        declare destructor()
end type

#define CausalContext(context...)  dim as CausalContextType _cu(context...)


'If a name (carg) now refers to something else, can call this to indicate a break from the past
declare sub identity_changed(subject as CauseArgPtr)

'==========================================================================================
'                                 Cause Arguments
'==========================================================================================


enum 'CauseArgType
        cargBslot
end enum
type CauseArgType as integer

type CauseArg
        argtype as CauseArgType
        union
                bslot_who as integer
        end union
end type

'This is an 'any ptr' stuffed into a zstring ptr
type CauseArgPtr as zstring ptr

'declare function carg_bslot(who as integer) as CauseArgPtr
#define carg_bslot(who) cast(CauseArgPtr, @TYPE<CauseArg>(cargBslot, who))

#define TEMPCARG(argtype, values...) cast(CauseArgPtr, @TYPE<CauseArg>(arg

#define carg_bslot(who) TEMPCARG(cargBslot, who))

#define ENDCAUSE "///"


'==========================================================================================
'                                   Cause Names
'==========================================================================================

'We use defines instead


function bslotname(who as integer) as string
        return iif(who <= 3, "<<hero ", "<<enemy ") & who & "(" & bslot(who).name & ")>>"
end function

#define PickedAttack(atk_id, atk_name) "Picked attack " & atk_id & " " & atk_name 
#define LostTurn(who) bslotname(who) & " lost turn"
'#define NoValidAttacks(who) bslotname(who) & " has no valid attacks"
#define NoValidAttacks() "Has no valid attacks"

#define HasBit(what, bitname) what & " has bit " & bitname
#define BslotHasBit(who, bitname) bslotname(who) & " has bit " & bitname
#define AttackHasBit(atkid, bitname) atkname(atkname) & " has bit " & bitname

#define False(cond) cond & " = false"



#define BslotHasBit(who, bitname) "%s has bit %s = ON", who, bitname, ENDCAUSE

#define BslotHasBit(who, bitname) "%s has bit %s = ON", carg_bslot(who), bitname, ENDCAUSE


#define BslotHasBitOff(who, bitname) bslotname(who) & " has bit " & bitname & " = OFF"
declare function HasStat(who as integer, statnum as integer) as string

function HasStat(who as integer, statnum as integer) as string
        with bslot(who).stat
                return bslotname(who) & " has " & .cur.sta(statnum) & "/" & .max.sta(statnum) & " " & battle_statnames(statnum)
        end with
end function

/'

0.
Pick enemy attack and spawn-when-alone, e [context]
 Count enemies  [context]
  IgnoreBslot(i) <- BslotHasBit(Ignore for alone)
 IsAlone(e)
 SpawnEnemy(f) <- IsAlone(e)
 SpawnEnemy(f) <- IsAlone(e)  [failed]
  Failed <- "No empty slot"
 SkipAIList(e, alone) <- NoValidAttacks()
 SkipAIList(e, normal) <- NoValidAttacks()
 LostTurn(e) <- NoValidAttacks()

1.
(no effects/causes for Normal list)
PickedAttack(atk_id)


'/
