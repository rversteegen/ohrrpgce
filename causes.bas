



'Globals
dim cause_tree as CauseNode ptr


'Module-local
dim shared cause_handles as CauseNode ptr vector


function get_handle(nod as CauseNode ptr) as string
        if nod->handle = 0 then
                nod->handle = v_len(cause_handles) + 1  'Offset so handles are positive
                v_append cause_handles, node
        end if
        return "^@" & nod->handle
end

function get_node(handle as string) as CauseNode ptr
        dim handlenum as integer = str2int(@handle[2])  'Skip ^@ prefix
        handlenum -= 1  'Offset
        if handlenum < 0 or handlenum >= v_len(cause_handles) then
                
        end if
end function

sub FreeNode(nod as CauseNode ptr)
	if nod = NULL then
		debug "FreeChildren ptr already null"
		exit sub
	end if

        dim as CauseNode ptr child = nod->children, nextchild
        do while child <> NULL
                nextchild = child->nextSib
                FreeNode(child)
                child = nextchild
        loop
        delete nod
end sub

sub clear_tree()
        cause_handle_counter = 1
        FreeNode cause_tree
end sub


constructor CauseNode(text as zstring ptr)
        this.text = text
end constructor

private sub PrependNode(parent as CauseNode ptr, child as CauseNode ptr)
        child->nextSibling = parent->children
        parent->children = child
end sub

function cause (caused as zstring ptr, cause1 as zstring ptr, cause2 as zstring ptr, cause3 as zstring ptr = 0, cause4 as zstring ptr = 0) as CauseNode ptr
        dim parent as CauseNode ptr = new CauseNode(caused)
        PrependNode(parent, new CauseNode(cause4))
        PrependNode(parent, new CauseNode(cause3))
        PrependNode(parent, new CauseNode(cause2))
        PrependNode(parent, new CauseNode(cause1))
        return parent
end function

'This overload is for efficiency
function cause (caused as zstring ptr, cause1 as zstring ptr) as CauseNode ptr
        dim parent as CauseNode ptr = new CauseNode(caused)
        PrependNode(parent, new CauseNode(cause1))
        return parent
end function

'Returns a string that can be passed to 
function effect (text as zstring ptr) as CauseHdl
        return get_handle(new CauseNode(text))
end function

sub begin_causes(context as zstring ptr, subject as zstring ptr = 0)
end sub

sub end_causes()
end sub

constructor CausalContextType(context as zstring ptr, subject as zstring ptr = 0)
        begin_causes(context, subject)
end constructor

destructor CausalContextType()
        end_causes()
end destructor


function carg_bslot(who as integer) as CauseArgPtr
        dim ret as 
        return cast(CauseArgPtr, ret)
end function
