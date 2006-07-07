-- HamsterSpeak Compiler v.2N

--(C) Copyright 2002 James Paige and Hamster Republic Productions
-- Please read LICENSE.txt for GPL License details and disclaimer of liability

-- This is a compiler for HamsterSpeak scripts used for plotscripting in
-- the O.H.R.RPG.C.E. For more info, visit http://HamsterRepublic.com

-- This code is written in Euphoria 2.2. You can get the public-domain
-- version from http://RapidEuphoria.com . I also highly recommend
-- David Cuny's EE editor which you can download from the same site.

---------------------------------------------------------------------------

--Changelog
--2Na 2006-07-07 Minor update to add new logical operators
--2N 2006-07-07 Added not() logic function
--2M 2006-07-06 Set exit code on warnings
--2L 2006-05-13 Added switch statement (+ case keyword)
--2K 2006-05-01 Added @scriptname and @globalvariable syntax to
--              return script or global ID number at compile-time
--              not run-time (for use with "run script by ID" and
--              "read global" and "write global")
--2J 2006-04-10 Added break, continue, exitscript, exitreturning
--              flow statements. Also fixed some return bugs - TMC
--2I 2006-04-04 Extended HSX header to include number of arguments
--              to a script, to really fix arguments-overflow-into
--              -locals bug
--2H 2006-03-29 Display better help and wait for keypress when run
--              by double-clicking the icon. Added -k command line
--              option to skip waiting for keypress
--2G 2005-10-03 Additional operators $+ and $= by TeeEmCee
--              Mention GPL in help text
--2F 2005-07-24 Strings implemented by TeeEmCee:
--              $id="..." -> setstring
--              $id+"..." -> appendstring
--2E 2005-02-15 Changed license to GPL
--              Added += and -= operators thanks to a patch from
--              The Mad Cacti and Fyrewulff
--2D 2002-08-03 Only a small change, strip out \r from lines of
--              the script as we read them to avoid errors related
--              to busted newlines
--2C 2002-03-05 Fixed some bugs that could cause crashes when
--              non-printable characters exist in the input file.
--              (naturally the script will not compile right, but
--              at least it will not crash)
--2B 2001-06-06 Added := as a commaless separater so it can be
--              defined as an operator
--2A 2001-05-04 Fixed -w command line option when used with -z
--2             First Release

---------------------------------------------------------------------------

without warning       --to avoid annoying warnings
without type_check    --for a very small speed boost
--with profile_time     --time profiling

include hsspiffy.e --various routines, sequence manipulation - James Paige
include graphics.e --standard library, needed for color output

---------------------------------------------------------------------------
--constants--
constant false=0
constant true=1

constant COMPILER_VERSION=2
constant COMPILER_SUB_VERSION='O'
constant COPYRIGHT_DATE="2002"

--these constants are color-flags.
constant COLYEL=239 + YELLOW
constant COLRED=239 + RED
constant COLPNK=239 + BRIGHT_RED
constant COLWHI=239 + WHITE
constant COLBWHI=239 + BRIGHT_WHITE

constant SRC_TEXT=1
constant SRC_LINE=2
constant SRC_FILE=3
constant CMD_TEXT=1
constant CMD_LINE=2
constant RESERVE_CORE=1
constant RESERVE_UNIMPLEMENTED=2
constant RESERVE_FLOW=3
constant RESERVE_FUNCTION=4
constant RESERVE_SCRIPT=5
constant RESERVE_GLOBAL=6
constant RESERVE_BEGIN=7
constant RESERVE_END=8
constant RESERVE_OPERATOR=9
constant RESERVE_BUILTIN=10
constant RESERVE_NAMES={"declaration"
                       ,"unimplimented keyword"
                       ,"flow control"
                       ,"hardcoded function"
                       ,"user script"
                       ,"global variable"
                       ,"bracket "&COLYEL&"("&COLRED
                       ,"bracket "&COLYEL&")"&COLRED
                       ,"operator"
                       ,"builtin command"
                       }
constant PAIR_NUM=1
constant PAIR_NAME=2
constant OPER_TRUENAME=3
constant OPER_LINE=4
constant FUNC_ARGS=3
constant FUNC_LINE=4
constant GLB_LINE=3
constant KIND_NUMBER=1
constant KIND_FLOW=2
constant KIND_GLOBAL=3
constant KIND_LOCAL=4
constant KIND_MATH=5
constant KIND_FUNCTION=6
constant KIND_SCRIPT=7
constant KIND_REFERENCE=8 --converted to KIND_NUMBER in compiled script
constant KIND_OPERATOR=9 --never appears in compiled script
constant KIND_PARENS=10 --never appears in compiled script
constant KIND_LONGNAMES={"number"
                        ,"flow control statement"
                        ,"global variable"
                        ,"local variable"
                        ,"built-in function"
                        ,"hard-coded function"
                        ,"script"
                        ,"reference"
                        ,"untranslated operator"
                        ,"order-of-operations-enforcing parenthesis"
                        }
constant TREE_TRUNK=1
constant TREE_BRANCHES=2
constant CODE_START_BYTE_OFFSET=6

---------------------------------------------------------------------------
--globals--               --initializations--
sequence compiler_dir     compiler_dir=""
sequence source_file      source_file=""
sequence dest_file        dest_file=""
sequence optlist          optlist={}
sequence source           source={}
sequence file_list        file_list={}
integer total_lines       total_lines=0
sequence cmd              cmd={}
sequence constant_list    constant_list=alpha_tree_create()
sequence operator_list    operator_list={}
sequence function_list    function_list={}
sequence global_list      global_list={{},{},{}}
sequence script_list      script_list={}
sequence script_cmd       script_cmd={}
sequence reserved         reserved=alpha_tree_create()
atom start_time           start_time=time()
integer get_cmd_pointer   get_cmd_pointer=0
integer autonumber_id     autonumber_id=32767
sequence flow_list        flow_list={
                              {0,"do"}
                             ,{1,"begin"}
                             ,{2,"end"}
                             ,{3,"return"} 
                             ,{4,"if"}
                             ,{5,"then"}
                             ,{6,"else"}
                             ,{7,"for"}
                             ,{10,"while"}
                             ,{11,"break"}
                             ,{12,"continue"}
                             ,{13,"exitscript"}
                             ,{14,"exitreturning"}
                             ,{15,"switch"}
                             ,{16,"case"}  --never appears in compiled script
                          }
sequence math_list        math_list={
                              {0,"random",{0,1}}
                             ,{1,"exponent",{0,2}} 
                             ,{2,"modulus",{0,1}} 
                             ,{3,"divide",{0,1}} 
                             ,{4,"multiply",{0,0}} 
                             ,{5,"subtract",{0,0}} 
                             ,{6,"add",{0,0}} 
                             ,{7,"xor",{0,0}} 
                             ,{8,"or",{0,0}} 
                             ,{9,"and",{0,0}} 
                             ,{10,"equal",{0,0}} 
                             ,{11,"notequal",{0,0}} 
                             ,{12,"lessthan",{0,0}} 
                             ,{13,"greaterthan",{0,0}} 
                             ,{14,"lessthanorequalto",{0,0}} 
                             ,{15,"greaterthanorequalto",{0,0}} 
                             ,{16,"setvariable",{0,0}} 
                             ,{17,"increment",{0,1}} 
                             ,{18,"decrement",{0,1}} 
                             ,{19,"not",{0}} 
                             ,{20,"logand",{0,1}} 
                             ,{21,"logor",{0,1}} 
                             ,{22,"logxor",{0,1}} 
                          }
sequence all_scripts      all_scripts={}                        
sequence current_script   current_script=""
integer  colors_enabled   colors_enabled=true
integer error_file        error_file=false
sequence used_globals     used_globals={}
sequence used_locals      used_locals={}
integer fast_mode         fast_mode=false
integer end_anchor_kludge end_anchor_kludge=false
integer was_warnings      was_warnings=false
---------------------------------------------------------------------------

--time spent waiting for a user-keypress shouldnt count
function timeless_wait_key()
  atom skip_time
  integer key
  skip_time=time()
  key=wait_key()
  start_time+=time()-skip_time
  return(key)
end function

---------------------------------------------------------------------------

--prints a string with printf to stdout converting color codes
procedure color_print(sequence s,sequence printf_args)
  sequence buffer
  s=sprintf(s,printf_args)
  buffer=""
  for i=1 to length(s) do
    if s[i]<=254 and s[i]>=239 then
      puts(stdout,buffer)
      buffer=""
      if colors_enabled then
        text_color(s[i]-239)
      end if
    else  
      buffer&=s[i]
    end if
  end for 
  if length(buffer) then
    puts(stdout,buffer)
  end if
end procedure

---------------------------------------------------------------------------

procedure opt_wait_for_key()
  integer key
  if not find('k',optlist) then
    color_print("[Press Any Key]",{})
    key=timeless_wait_key()
  end if
end procedure

---------------------------------------------------------------------------

function html_char_convert(sequence s)
  sequence buffer
  sequence result
  result=""
  buffer=""
  for i=1 to length(s) do
    if s[i]=' ' and i>1 then
      if s[i-1]=' ' then
        buffer&="&nbsp;"
      else
        buffer&=s[i]
      end if
    elsif s[i]='<' then
      buffer&="&lt;"
    elsif s[i]='>' then
      buffer&="&gt;"
    else  
      buffer&=s[i]
    end if
  end for 
  if length(buffer) then
    result&=buffer
  end if
  return(result)
end function

---------------------------------------------------------------------------

function error_string_convert(sequence s)
  sequence buffer
  sequence result
  result=""
  buffer=""
  for i=1 to length(s) do
    if s[i]<=254 and s[i]>=239 then
      if s[i]=COLYEL then
        buffer&="<font color=\"#F0F000\">"
      elsif s[i]=COLRED then
        buffer&="</font>"
      elsif s[i]=COLPNK then
        buffer&="<font color=\"#F07070\">"
      elsif s[i]=COLWHI then
        buffer&="<font color=\"#909090\">"
      elsif s[i]=COLBWHI then
        buffer&="<font color=\"#F0F0F0\">"
      end if
    elsif s[i]='\n' then
      buffer&="<br>\n"
    else  
      buffer&=s[i]
    end if
  end for 
  if length(buffer) then
    result&=buffer
  end if
  return(result)
end function

---------------------------------------------------------------------------

--prints a long string wrapped at 80 columns
procedure wrap_print(sequence s,sequence arguments)
  sequence outstring
  s=sprintf(s,arguments)
  while length(s) do
    outstring=before_wrap_point(s)
    s=after_wrap_point(s)
    color_print("%s\n",{outstring})
  end while
end procedure

---------------------------------------------------------------------------

procedure error_file_print(sequence s)
  integer fh
  if error_file then
    fh=open(compiler_dir&"hs_error.htm","a")
    if fh!=failure then
      puts(fh,error_string_convert(s)&"\n")
      close(fh)
    end if
  end if
end procedure

---------------------------------------------------------------------------

--prints out warning message in red with word wrap
procedure simple_warn(sequence s)
  sequence pos
  if not find('w',optlist) then
    --do not warn if -w is set
    pos=get_position()
    if pos[2]>1 then
      printf(stdout,"\n",{})
    end if
    wrap_print(COLRED&"WARNING: %s"&COLWHI&"\n",{s})
    error_file_print(sprintf("<font color=\"#FF0000\">WARNING: %s</font>",{html_char_convert(s)}))
    was_warnings = true
  end if
end procedure

---------------------------------------------------------------------------

--prints out an error message in red with word wrap, then aborts
procedure simple_error(sequence s)
  sequence pos
  pos=get_position()
  if pos[2]>1 then
    printf(stdout,"\n",{})
  end if
  wrap_print(COLRED&"ERROR: %s"&COLWHI&"\n",{s})
  error_file_print(sprintf("<font color=\"#FF0000\">ERROR: %s</font>",{html_char_convert(s)}))
  if end_anchor_kludge then
    error_file_print("</a>\n<hr>\n")
  end if
  opt_wait_for_key()
  abort(1)
end procedure

---------------------------------------------------------------------------

--prints out the copyright info, usage info, and command-line options
procedure check_arg_count(sequence args)
  if length(args)=2 then
    wrap_print("HamsterSpeak semicompiler v%d%s (C)%s James Paige, Hamster Republic Productions\n",{COMPILER_VERSION,COMPILER_SUB_VERSION,COPYRIGHT_DATE})
    wrap_print("Please read LICENSE.txt for GPL License details and disclaimer of liability",{})
    wrap_print(COLYEL&"%s [-cdefwy] source.hss [dest.hs]"&COLWHI&"\n\n",{hs_upper(file_only(args[2]))})
    color_print("   -c colors will be disabled\n",{})
    color_print("   -d dump debug report to hs_debug.txt\n",{})
    color_print("   -f fast mode. disables some optimization\n",{})
    color_print("   -k do not wait for a keypress when finished\n",{})
    color_print("   -w suppress minor warnings\n",{})
    color_print("   -y overwrite the destination file without asking\n",{})
    color_print("   -z write error messages to hs_error.htm\n",{})
    wrap_print("\nFor more info about Hamsterspeak visit "&COLBWHI&"http://HamsterRepublic.com/ohrrpgce"&COLWHI&"\n",{})
    wrap_print("\nThis is a command-line program. You should either run it from the command-line (DOS prompt) or you should drag and drop your script file onto it.\n",{})
    opt_wait_for_key()
    abort(0)
  end if
end procedure

---------------------------------------------------------------------------

--initializes global variables, and generaly gets things ready to roll
procedure init()
  sequence args
  integer index
  integer key
  integer fh
  args=command_line()
  compiler_dir=path_only(args[2])
  check_arg_count(args)
  optlist={}
  index=3
  while index<=length(args) do
    if args[index][1]='-' then
      optlist=optlist&hs_lower(args[index][2..length(args[index])])
      args=delete_element(args,index)
    else
      index+=1  
    end if
  end while
  check_arg_count(args)
  source_file=normalize_filename(args[3])
  if length(args)>3 then
    dest_file=normalize_filename(args[4])
  else
    dest_file=normalize_filename(alter_extension(source_file,"HS"))
  end if
  if find('f',optlist) then
    fast_mode=true
    color_print("using fast mode. some size optimization disabled\n",{})
  end if
  if find('c',optlist) then
    colors_enabled=false
  end if
  --the semi-undocumented command line argument -z writes a file called
  --hs_error.htm formatted for HssEd to read
  if find('z',optlist) then
    error_file=true
    if file_exists(compiler_dir&"hs_error.htm") then
      fh=open(compiler_dir&"hs_error.htm","w")
      if fh!=failure then
        puts(fh,"")
        close(fh)
      end if
    end if
  end if
  wrap_print("Semicompiling "&COLBWHI&"%s"&COLWHI&" to "&COLBWHI&"%s"&COLWHI&"\n",{source_file,dest_file})
  if file_exists(dest_file) then
    if find('y',optlist) then
      --found the -y command line arg, overwrite automatically
      key='y'
    else
      --prompt the user to overwrite
      wrap_print("file "&COLBWHI&"%s"&COLWHI&" already exists. Overwrite it? (Y/N)",{dest_file})
      key=timeless_wait_key()
      color_print(" "&COLYEL&"%s"&COLWHI&"\n",{key})
    end if
    if hs_lower(key)='y' then
    elsif hs_lower(key)='n' then
      simple_error("output file overwrite canceled by user")
    else  
      simple_error(sprintf(COLYEL&"%s"&COLWHI&"? "&COLYEL&"%s"&COLWHI&"!? How is that Y or N?",{key,hs_upper(key)}))
    end if
  end if
  --why the alpha-tree? because the reserved-word list can get HUGE.
  --we want to be able to look up words in it quickly. A btree or some such
  --thing would have been even better, but thats alot of trouble :)
  reserved=alpha_tree_mass_insert(reserved,{
           {"defineconstant",RESERVE_CORE}
          ,{"defineconstant",RESERVE_CORE}
          ,{"defineoperator",RESERVE_CORE}
          ,{"globalvariable",RESERVE_CORE}
          ,{"definefunction",RESERVE_CORE}
          ,{"definescript"  ,RESERVE_CORE}
          ,{"script"        ,RESERVE_CORE}
          ,{"do"            ,RESERVE_FLOW}
          ,{"begin"         ,RESERVE_BEGIN}
          ,{"end"           ,RESERVE_END}
          ,{"return"        ,RESERVE_FLOW}
          ,{"if"            ,RESERVE_FLOW}
          ,{"then"          ,RESERVE_FLOW}
          ,{"else"          ,RESERVE_FLOW}
          ,{"for"           ,RESERVE_FLOW}
          ,{"cfor"          ,RESERVE_UNIMPLEMENTED}
          ,{"foreach"       ,RESERVE_UNIMPLEMENTED}
          ,{"while"         ,RESERVE_FLOW}
          ,{"break"         ,RESERVE_FLOW}
          ,{"continue"      ,RESERVE_FLOW}
          ,{"exitscript"    ,RESERVE_FLOW}
          ,{"exitreturning" ,RESERVE_FLOW}
          ,{"switch"        ,RESERVE_FLOW}
          ,{"case"          ,RESERVE_FLOW}
        })--end mass_insert   
  for i=1 to length(math_list) do
    reserved=alpha_tree_insert(reserved,math_list[i][PAIR_NAME],RESERVE_BUILTIN)
  end for
end procedure

---------------------------------------------------------------------------

function strip_comments(sequence s)
  integer at
  at=find('#',s)
  if at then
    s=s[1..at-1]
  end if
  return s
end function

---------------------------------------------------------------------------

function seek_include(sequence s)
  integer at
  s=strip_comments(s)
  at=match("include",hs_lower(s))
  if at then
    s=s[at+7..length(s)]
    at=match(",",s)
    if at then
      s=s[at+1..length(s)]
      return(trim_whitespace(s))
    end if
  end if
  return("")
end function

---------------------------------------------------------------------------

procedure load_source(sequence filename,sequence reading_how)
  integer fh
  object line
  integer index
  integer filename_index
  sequence include_name
  fh=open(filename,"r")
  if fh!=failure then
    wrap_print("%s "&COLBWHI&"%s"&COLWHI&"\n",{reading_how,filename})
    file_list=append(file_list,filename)
    filename_index=length(file_list)
    index=1
    line=gets(fh)
    while sequence(line) do
      line=exclude(line,"\n\r")
      include_name=seek_include(line)
      if length(include_name) then
        --try current directory
        if file_exists(include_name) then
          load_source(include_name,"including")
        else
          --try source directory
          if file_exists(path_only(source_file)&include_name) then
            load_source(normalize_filename(path_only(source_file)&include_name),"including")
          else  
            --try compiler_directory
            if file_exists(compiler_dir&include_name) then
              load_source(normalize_filename(compiler_dir&include_name),"including")
            else  
              --give up
              load_source(include_name,"including")
            end if
          end if
        end if
      else  
        --stores the original source line, the index in the file, and the index of the filename
        source=append(source,{line,index,filename_index})
      end if
      index+=1
      line=gets(fh)
    end while
    close(fh)
    total_lines+=index
  else
    wrap_print("file "&COLBWHI&"%s"&COLWHI&" not found\n",{filename})
  end if
end procedure

---------------------------------------------------------------------------

procedure show_source_info()
  if total_lines then
    wrap_print("%d lines read from %d files\n",{total_lines,length(file_list)})
  else
    simple_error("no data to compile\n")  
  end if
end procedure

---------------------------------------------------------------------------

function convert_strings(sequence s)
  integer start
  integer stringstart
  integer ptr
  integer at
  integer at2
  integer switch
  sequence output
  sequence result
  start=1
  result=""
  while start<length(s) do
    stringstart=find('$',s[start..length(s)])
    if stringstart=0 then
      exit
    end if
    stringstart+=start-1
    if stringstart>start then
      result=result&s[start..stringstart-1]
    end if
    start=stringstart
    at=match("=\"",s[start..length(s)])
    at2=match("+\"",s[start..length(s)])
    if at=0 and at2=0 then 
      exit
    end if
    if at!=0 and at<at2 or at2=0 then 
      output=",setstring("
    else
      output=",appendstring("
      at=at2
    end if
    if at=2 then --no id
      exit
    end if
    at+=start-1
    output=output&s[stringstart+1..at-1]  --id
    ptr=at+2
    switch=false
    while true do
      if ptr>length(s) then  --did not find a closing " so not a valid string (previous matches presumably a coincidence)
        result=result&s[stringstart..at+1]
        start=at+2 --skip the $..=" and try again
        exit
      end if
      if switch then
        if s[ptr]='"' then
          output=output&sprintf(",%d",{'"'})
        elsif s[ptr]='\\' then
          output=output&sprintf(",%d",{'\\'})
        else
          output=output&sprintf(",%d,%d",{'\\',s[ptr]}) --invalid sequence
        end if
        switch=false
      else
        if s[ptr]='"' then
          result=result&output&")"
          start=ptr+1
          exit
        elsif s[ptr]='\\' then
          switch=true
        else
          output=output&sprintf(",%d",{s[ptr]})
        end if
      end if
      ptr+=1
    end while
  end while
  return(result&s[start..length(s)])
end function

---------------------------------------------------------------------------

--function smush_line(sequence s)
--  sequence sep
--  s=hs_lower(exclude(strip_comments(s)," \t\n"))
--  s=substring_replace(s,"(",",begin,")
--  s=substring_replace(s,")",",end,")
--  sep={"+","--","/","*","^","==","<>",">>","<<","<=",">=",":="}
--  for i=1 to length(sep) do
--    s=substring_replace(s,sep[i],","&sep[i]&",")
--  end for
--  return(s)
--end function

function smush_line(sequence s)
  integer at
  integer start
  sequence sep
  sequence masked
  s=convert_strings(s)
  s=hs_lower(exclude(strip_comments(s)," \t\n"))
  s=substring_replace(s,"(",",begin,")
  s=substring_replace(s,")",",end,")
  masked=s
  sep={"+=","-=","$+","$=","+","--","/","*","^^","^","==","<>",">>","<<","<=",">=",":=","&&","||","^^"}
  for i=1 to length(sep) do
    at=match(sep[i],masked)
    start=1
    while at>=start do
      s=s[1..at-1] & "," & sep[i] & "," & s[at+length(sep[i])..length(s)]
      masked=masked[1..at-1] & repeat(0,length(sep[i])+2) & masked[at+length(sep[i])..length(masked)]
      start=at+length(sep[i])+2
      at=match(sep[i],masked)
    end while
  end for
  return(s)
end function

---------------------------------------------------------------------------

procedure split_commands()
  sequence line,broken
  color_print("splitting commands\n",{})
  for i=1 to length(source) do
    line=smush_line(source[i][SRC_TEXT])
    broken=explode(line,",")
    for j=1 to length(broken) do
      --text,origin
      if length(broken[j]) then
        cmd=append(cmd,{broken[j],i})
      end if
    end for
  end for
end procedure

---------------------------------------------------------------------------

procedure src_warn(sequence s,integer line)
  if not find('w',optlist) then
    --do not warn if -w is set
    error_file_print(sprintf("<a href=\"%s#%d\">\n",{file_list[source[line][SRC_FILE]],source[line][SRC_LINE]}))
    if length(current_script) then
      simple_warn(
        sprintf(
           "in line %d of script "&COLYEL&"%s"&COLRED&" in "&COLPNK&"%s"&COLRED&"\n"&COLBWHI&"%s"&COLRED&"\n%s\n"
          ,{source[line][SRC_LINE],current_script,file_list[source[line][SRC_FILE]],source[line][SRC_TEXT],s}
        )
      )
    else
      simple_warn(sprintf("in line %d of "&COLPNK&"%s"&COLRED&"\n"&COLBWHI&"%s"&COLRED&"\n%s\n",{source[line][SRC_LINE],file_list[source[line][SRC_FILE]],source[line][SRC_TEXT],s}))
    end if
    error_file_print("</a>\n<hr>\n")
  end if  
end procedure

---------------------------------------------------------------------------

procedure src_error(sequence s,integer line)
  error_file_print(sprintf("<a href=\"%s#%d\">\n",{file_list[source[line][SRC_FILE]],source[line][SRC_LINE]}))
  end_anchor_kludge=true
  if length(current_script) then
    simple_error(
      sprintf(
         "in line %d of script "&COLYEL&"%s"&COLRED&" in "&COLPNK&"%s"&COLRED&"\n"&COLBWHI&"%s"&COLRED&"\n%s\n"
        ,{source[line][SRC_LINE],current_script,file_list[source[line][SRC_FILE]],source[line][SRC_TEXT],s}
      )
    )
  else
    simple_error(sprintf("in line %d of "&COLPNK&"%s"&COLRED&"\n"&COLBWHI&"%s"&COLRED&"\n%s\n",{source[line][SRC_LINE],file_list[source[line][SRC_FILE]],source[line][SRC_TEXT],s}))
  end if
end procedure

---------------------------------------------------------------------------

procedure check_for_reserved(sequence s,integer line,sequence expect)
  if alpha_tree_seek(reserved,s) then
    if compare("top-level declaration",expect)=0 then
      src_error(
        sprintf(
          "Expected %s, but found %s "&COLYEL&"%s"&COLRED&". Perhaps there is an extra "&COLYEL&"end"&COLRED&" or "&COLYEL&")"&COLRED&" earlier in the file"
          ,{expect,RESERVE_NAMES[alpha_tree_data(reserved,s,0)],s}
        )
        ,line
      )
    elsif compare("user script name",expect)=0 then
      if alpha_tree_data(reserved,s,0)=RESERVE_FUNCTION then
        src_warn(sprintf("%s "&COLYEL&"%s"&COLRED&" is already reserved as a %s",{expect,s,RESERVE_NAMES[alpha_tree_data(reserved,s,0)]}),line)
      else  
        src_error(sprintf("Expected %s, but found %s "&COLYEL&"%s"&COLRED,{expect,RESERVE_NAMES[alpha_tree_data(reserved,s,0)],s}),line)
      end if
    else  
      src_error(sprintf("Expected %s, but found %s "&COLYEL&"%s"&COLRED,{expect,RESERVE_NAMES[alpha_tree_data(reserved,s,0)],s}),line)
    end if
  end if
end procedure

---------------------------------------------------------------------------

function musnt_be_a_number(sequence s)
  if length(exclude(s[CMD_TEXT],"-0123456789"))=0 and compare(s[CMD_TEXT],"--")!=0 then
    src_error(sprintf("Expected a name, but found a number "&COLYEL&"%s"&COLRED,{s[CMD_TEXT]}),s[CMD_LINE])
  end if
  return(s[CMD_TEXT])
end function

---------------------------------------------------------------------------

function try_undefined_constant(sequence s)
   sequence const_data
   check_for_reserved(s[CMD_TEXT],s[CMD_LINE],"constant name")
   if alpha_tree_seek(constant_list,s[CMD_TEXT]) then
     --constant is already defined
     const_data=alpha_tree_data(constant_list,s[CMD_TEXT],0)
     src_warn(sprintf("constant "&COLYEL&"%s"&COLRED&" will be ignored because it is already defined in line "&COLYEL&"%d"&COLRED&" of "&COLBWHI&"%s"&COLRED&" with the value "&COLYEL&"%d"&COLRED
                ,{
                   s[CMD_TEXT]
                  ,source[const_data[2]][SRC_LINE]
                  ,file_list[source[const_data[2]][SRC_FILE]]
                  ,const_data[1]
                }
              ),s[CMD_LINE])
   end if
   return musnt_be_a_number(s)
end function

---------------------------------------------------------------------------

function try_undefined_string(sequence s,sequence seeking)
   check_for_reserved(s[CMD_TEXT],s[CMD_LINE],seeking)
   return musnt_be_a_number(s)
end function

---------------------------------------------------------------------------

function force_16_bit(integer n,integer line)
  if n>32767 then
    src_warn(sprintf("number "&COLYEL&"%d"&COLRED&" is out of range for a 16-bit signed integer, and will be truncated to "&COLYEL&"32767"&COLRED,{n}),line)
    n=32767
  elsif n<-32768 then
    src_warn(sprintf("number "&COLYEL&"%d"&COLRED&" is out of range for a 16-bit signed integer, and will be truncated to "&COLYEL&"-32768"&COLRED,{n}),line)
    n=-32768
  end if
  return(n)
end function

---------------------------------------------------------------------------

function try_string_to_number(sequence s)
  integer result
  result=floor(string_to_object(s[CMD_TEXT],0))
  if not string_is_an_integer(s[CMD_TEXT]) then
    src_error(sprintf("Expected number but found "&COLYEL&"%s"&COLRED,{s[CMD_TEXT]}),s[CMD_LINE])
  end if
  result=force_16_bit(result,s[CMD_LINE])
  return(result)
end function

---------------------------------------------------------------------------

function enforce_constants(sequence s)
  --enforces both constants
  object v
  v=alpha_tree_data(constant_list,s,{})
  if length(v) then
    v=v[1]--first element is number (second is line)
    if integer(v) then
      return(sprintf("%d",{v}))
    end if
  end if
  return(s)  
end function

---------------------------------------------------------------------------

function get_cmd()
  sequence result
  if get_cmd_pointer>length(cmd) then
    src_error("Unexpected end of file",cmd[length(cmd)][CMD_LINE])
  end if
  result=cmd[get_cmd_pointer]
  get_cmd_pointer+=1
  result[CMD_TEXT]=enforce_constants(result[CMD_TEXT])
  return(result)
end function

---------------------------------------------------------------------------

function get_cmd_no_constants()
  sequence result
  if get_cmd_pointer>length(cmd) then
    src_error("Unexpected end of file",cmd[length(cmd)][CMD_LINE])
  end if
  result=cmd[get_cmd_pointer]
  get_cmd_pointer+=1
  result[CMD_TEXT]=result[CMD_TEXT]
  return(result)
end function

---------------------------------------------------------------------------

function get_cmd_block(integer convert_constants)
  sequence this
  sequence result
  result={}
  this=get_cmd()
  if compare("begin",this[CMD_TEXT])!=0 then
    src_error(sprintf("Expected "&COLYEL&"begin"&COLRED&" or "&COLYEL&"("&COLRED&" bracket but found "&COLYEL&"%s"&COLRED,{this[CMD_TEXT]}),this[CMD_LINE])
  end if
  while true do
    if convert_constants then
      this=get_cmd()
    else  
      this=get_cmd_no_constants()
    end if
    if compare("begin",this[CMD_TEXT])=0 then
      src_error("Recursive "&COLYEL&"begin"&COLRED&" and "&COLYEL&"("&COLRED&" brackets are not permitted in this block",this[CMD_LINE])
    elsif compare("end",this[CMD_TEXT])=0 then
      exit--break out of the while
    else
      result=append(result,this)  
    end if
  end while
  return(result)
end function

---------------------------------------------------------------------------

procedure parse_constant_block(sequence block)
  integer num
  sequence name
  for i=1 to length(block) by 2 do
    if i+1>length(block) then
      src_error("expected name but constant block ended",block[i][CMD_LINE])
    end if  
    num=try_string_to_number({enforce_constants(block[i][CMD_TEXT]),block[i][CMD_LINE]})
--    name=try_undefined_constant({enforce_constants(block[i+1][CMD_TEXT]),block[i+1][CMD_LINE]})
    name=try_undefined_constant({block[i+1][CMD_TEXT],block[i+1][CMD_LINE]})
    constant_list=alpha_tree_insert(constant_list,name,{num,block[i+1][CMD_LINE]})
  end for
end procedure

---------------------------------------------------------------------------

procedure create_global(integer id,sequence name,integer line)
  integer at
  at=find(id,global_list[PAIR_NUM])
  if at then
    src_error(sprintf("global variable ID "&COLYEL&"%d"&COLRED&" is already defined as "&COLYEL&"%s"&COLRED,{id,global_list[PAIR_NAME][at]}),line)
  else
    if id>=0 then
      global_list[PAIR_NUM]=append(global_list[PAIR_NUM],id)
      global_list[PAIR_NAME]=append(global_list[PAIR_NAME],name)
      global_list[GLB_LINE]=append(global_list[GLB_LINE],line)
      reserved=alpha_tree_insert(reserved,name,RESERVE_GLOBAL)
    else
      src_error(sprintf("global variable ID "&COLYEL&"%d"&COLRED&" is not permitted",{id}),line)
    end if
  end if
end procedure

---------------------------------------------------------------------------

procedure parse_global_block(sequence block)
  integer num
  sequence name
  for i=1 to length(block) by 2 do
    if i+1>length(block) then
      src_error("expected name but globalvariable block ended",block[i][CMD_LINE])
    end if
    num=try_string_to_number(block[i])
    name=try_undefined_string(block[i+1],"global variable name")
    create_global(num,name,block[i][CMD_LINE])
  end for
end procedure

---------------------------------------------------------------------------

procedure parse_operator_block(sequence block)
  integer num
  sequence name,true
  for i=1 to length(block) by 3 do
    if i+2>length(block) then
      src_error("expected name but defineoperator block ended",block[i][CMD_LINE])
    end if
    num=try_string_to_number(block[i])
    name=musnt_be_a_number(block[i+1])
    true=musnt_be_a_number(block[i+2])
    operator_list=append(operator_list,{num,name,true,block[i+2][CMD_LINE]})
    reserved=alpha_tree_insert(reserved,name,RESERVE_OPERATOR)
  end for
end procedure

---------------------------------------------------------------------------

function create_function(sequence list,integer id,sequence name,sequence arglist,integer func_type,integer line)
  integer at
  at=find(id,column(list,PAIR_NUM))
  if at then
    src_error(sprintf("%s ID "&COLYEL&"%d"&COLRED&" is already defined as "&COLYEL&"%s"&COLRED,{RESERVE_NAMES[func_type],id,list[at][PAIR_NAME]}),line)
  else
    if id=0 and func_type=RESERVE_SCRIPT then
      src_error(sprintf("ID "&COLYEL&"%d"&COLRED&" is not valid",{id}),line)
    elsif id<0 then
      id=autonumber_id
      autonumber_id-=1
    end if
    list=append(list,{id,name,arglist,line})
    reserved=alpha_tree_insert(reserved,name,func_type)
  end if
  return(list)
end function

---------------------------------------------------------------------------

function parse_define_block(sequence block,sequence list,integer func_type)
  integer num
  sequence name
  integer args
  sequence arglist
  integer name_line
  integer i
  i=1
  while i<=length(block) do
    num=try_string_to_number(block[i])
    if i+1>length(block) then
      src_error(sprintf("expected %s name but define block ended",{RESERVE_NAMES[func_type]}),block[i][CMD_LINE])
    else
      i+=1
      name=try_undefined_string(block[i],RESERVE_NAMES[func_type]&" name")
      name_line=block[i][CMD_LINE]
      if i+1>length(block) then
        src_error("expected argument count but define block ended",block[i][CMD_LINE])
      else
        i+=1
        args=try_string_to_number(block[i])
        arglist={}
        for j=1 to args do
          if i+1>length(block) then
            src_error("expected argument default but define block ended",block[i][CMD_LINE])
          else
            i+=1
            arglist=append(arglist,try_string_to_number(block[i]))
          end if
        end for
        list=create_function(list,num,name,arglist,func_type,name_line)
        i+=1
      end if
    end if
  end while
  return(list)
end function

---------------------------------------------------------------------------

procedure parse_for_constants()
  sequence this
  color_print("parsing constants\n",{})
  get_cmd_pointer=1
  while get_cmd_pointer<=length(cmd) do
    --read a top-level command
    this=get_cmd()
    if compare("defineconstant",this[CMD_TEXT])=0 then
      parse_constant_block(get_cmd_block(false))
    end if
  end while
end procedure

---------------------------------------------------------------------------

procedure parse_script()
  sequence name
  sequence arglist
  sequence s
  sequence this
  integer depth
  name=get_cmd()
  current_script=name[CMD_TEXT]
  arglist={}
  while true do
    if get_cmd_pointer>length(cmd) then
      src_error(sprintf("script "&COLYEL&"%s"&COLRED&" is missing "&COLYEL&"begin"&COLRED&" or "&COLYEL&"("&COLRED,{name[CMD_TEXT]}),name[CMD_LINE])
    end if
    this=get_cmd()
    if compare("begin",this[CMD_TEXT])=0 then
      exit--break the while
    end if
    arglist=append(arglist,{try_undefined_string(this,"argument name"),this[CMD_LINE]})
  end while
  --every script is nested inside a big fat do() block
  s={{"do",this[CMD_LINE]}}
  depth=0
  while true do
    s=append(s,this)
    if compare("end",this[CMD_TEXT])=0 then
      depth-=1
      if depth=0 then
        exit--break while
      end if
    elsif compare("begin",this[CMD_TEXT])=0 then
      depth+=1
    else
      if alpha_tree_data(reserved,this[CMD_TEXT],3)<=RESERVE_UNIMPLEMENTED then
        src_error(
          sprintf(
             "%s "&COLYEL&"%s"&COLRED&" is not permitted inside a script. Perhaps "&COLYEL&"%s"&COLRED&" has an extra "&COLYEL&"begin"&COLRED&" or "&COLYEL&"("&COLRED
            ,{RESERVE_NAMES[alpha_tree_data(reserved,this[CMD_TEXT],0)],this[CMD_TEXT],name[CMD_TEXT]}
          )
          ,this[CMD_LINE]
        )
      end if
    end if
    if get_cmd_pointer>length(cmd) then
      src_error(
        sprintf(
           "script "&COLYEL&"%s"&COLRED&" is missing "&COLYEL&"end"&COLRED&" or "&COLYEL&")"&COLRED
          ,{name[CMD_TEXT]}
        )
        ,name[CMD_LINE]
      )
    end if
    this=get_cmd()
  end while
  script_cmd=append(script_cmd,{name,arglist,s})
  current_script=""
end procedure

---------------------------------------------------------------------------

procedure parse_top_level()
  sequence this
  sequence ignore
  color_print("parsing top-level\n",{})
  get_cmd_pointer=1
  while get_cmd_pointer<=length(cmd) do
    --read a top-level command
    this=get_cmd()
    if compare("defineconstant",this[CMD_TEXT])=0 then
      ignore=get_cmd_block(true)
    elsif compare("globalvariable",this[CMD_TEXT])=0 then
      parse_global_block(get_cmd_block(true))
    elsif compare("defineoperator",this[CMD_TEXT])=0 then
      parse_operator_block(get_cmd_block(true))
    elsif compare("definefunction",this[CMD_TEXT])=0 then
      function_list=parse_define_block(get_cmd_block(true),function_list,RESERVE_FUNCTION)
    elsif compare("definescript",this[CMD_TEXT])=0 then
      script_list=parse_define_block(get_cmd_block(true),script_list,RESERVE_SCRIPT)
    elsif compare("script",this[CMD_TEXT])=0 then
      parse_script()
    else
      if get_cmd_pointer>length(cmd) then
        --file ends while looking for top-level declaration
        exit
      else  
        check_for_reserved(this[CMD_TEXT],cmd[get_cmd_pointer][CMD_LINE],"top-level declaration")
        src_error(
          sprintf(
            "Expected top-level declaration but found "&COLYEL&"%s"&COLRED
            ,{this[CMD_TEXT]}
          )
          ,this[CMD_LINE]
        )
      end if
    end if
  end while
  cmd={}
end procedure

---------------------------------------------------------------------------

procedure dump_script_and_function_info(integer fh,sequence list)
  sequence this
  sequence id_string
  for i=1 to length(list) do
    this=list[i]
    if this[1]>autonumber_id then
      id_string=sprintf("AUTONUMBER=%d",{this[1]})
    else  
      id_string=sprintf("ID=%d",{this[1]})
    end if
    printf(fh,"%s %d\t%s\t%s(",{
       file_list[source[this[FUNC_LINE]][SRC_FILE]]
      ,source[this[FUNC_LINE]][SRC_LINE]
      ,id_string
      ,this[2]
    })
    for j=1 to length(this[FUNC_ARGS]) do
      if j>1 then
        printf(fh,",",{})
      end if
      printf(fh,"%d",{this[FUNC_ARGS][j]})
    end for
    printf(fh,")\n",{})
  end for
end procedure

---------------------------------------------------------------------------

function seek_string_by_id(integer id,sequence list,sequence name)
  integer at
  at=find(id,column(list,PAIR_NUM))
  if at then
    return(list[at][PAIR_NAME])
  else  
    simple_error(sprintf("decompiler couldnt find %s ID "&COLYEL&"%d"&COLRED,{name,id}))
  end if
  return("")
end function

---------------------------------------------------------------------------

function name_lookup(sequence pair)
  integer at
  if pair[1]=KIND_NUMBER then
    return(sprintf("%d",{pair[2]}))
  elsif pair[1]=KIND_LOCAL then
    return(sprintf("local%d",{pair[2]}))
  elsif pair[1]=KIND_GLOBAL then
    at=find(pair[2],global_list[PAIR_NUM])
    if at then
      return(global_list[PAIR_NAME][at])
    else  
      simple_error(sprintf("decompiler couldnt find global variable ID "&COLYEL&"%d"&COLRED,{pair[2]}))
    end if
  elsif pair[1]=KIND_FLOW then
    return(seek_string_by_id(pair[2],flow_list,"flow control structure"))
  elsif pair[1]=KIND_SCRIPT then
    return(seek_string_by_id(pair[2],script_list,"user script"))
  elsif pair[1]=KIND_FUNCTION then
    return(seek_string_by_id(pair[2],function_list,"hardcoded function"))
  elsif pair[1]=KIND_MATH then
    return(seek_string_by_id(pair[2],math_list,"built-in function"))
  else  
    simple_error(sprintf("decompiler found illegal kind "&COLYEL&"%d"&COLRED,{pair[1]}))
  end if
end function

---------------------------------------------------------------------------

function bytepair_to_word(sequence data)
  integer result
  result=data[1]+data[2]*#100
  if result>32767 then
    --convert negatives
    result=or_bits(result,#FFFF0000)
  end if
  return(result)
end function

---------------------------------------------------------------------------

function get_kind_and_id(sequence data)
  return({bytepair_to_word(data[1..2]),bytepair_to_word(data[3..4])})
end function

---------------------------------------------------------------------------

function dump_script_binary(sequence bin,integer offset,integer depth)
  sequence result
  sequence kind_and_id
  integer kind
  integer argcount
  integer new_offset
  result=""
  kind_and_id=get_kind_and_id(bin[1+offset*2..1+offset*2+3])
  kind=kind_and_id[1]
  result&=sprintf("%s%s",{
     repeat(' ',depth)--indent
    ,name_lookup(kind_and_id)
  })
  if kind=KIND_FLOW or kind=KIND_SCRIPT or kind=KIND_FUNCTION or kind=KIND_MATH then
    argcount=bytepair_to_word(bin[1+offset*2+4..1+offset*2+5])
    if argcount then
      result&="(\n"
      for i=1 to argcount do
        new_offset=bytepair_to_word(bin[1+offset*2+6+(i-1)*2..1+offset*2+6+(i-1)*2+1])
        result&=dump_script_binary(bin,new_offset,depth+2)
      end for
      result&=repeat(' ',depth)&")\n"
    else  
      result&="()\n"
    end if
  else
    result&="\n"
  end if

  return(result)
end function

---------------------------------------------------------------------------

function dump_script_tree(sequence tree,integer depth)
  sequence result
  result=""
    for i=1 to length(tree)  do
      result&=sprintf("%s%s",{
         repeat(' ',depth)--indent
        ,tree[i][TREE_TRUNK][CMD_TEXT]
      })
      if length(tree[i][TREE_BRANCHES])>0 then
        result&="(\n"
        result&=dump_script_tree(tree[i][TREE_BRANCHES],depth+2)
        result&=repeat(' ',depth)&")\n"
      else
        result&="\n"
      end if
    end for
  return(result)
end function

---------------------------------------------------------------------------

procedure dump_debug_report()
  integer fh
  sequence debug_file
  --only do this if the -d debug option was on the command line
  if find('d',optlist) then
    if length(path_only(dest_file))>1 then
      debug_file=normalize_filename(path_only(dest_file)&"hs_debug.txt")
    else  
      debug_file="hs_debug.txt"
    end if
    fh=open(debug_file,"w")
    if fh!=failure then
      wrap_print("Writing debug report file "&COLBWHI&"%s"&COLWHI&"\n",{debug_file})  
      -------------------------------------
      printf(fh,"[Scripts]\n",{})
      dump_script_and_function_info(fh,script_list)
      printf(fh,"\n",{})
      -------------------------------------
      printf(fh,"[Global Variables]\n",{})
      for i=1 to length(global_list[PAIR_NUM]) do
        printf(fh,"%s %d\tID=%d\t%s\n",{
           file_list[source[global_list[GLB_LINE][i]][SRC_FILE]]
          ,source[global_list[GLB_LINE][i]][SRC_LINE]
          ,global_list[PAIR_NUM][i]
          ,global_list[PAIR_NAME][i]
        })
      end for
      printf(fh,"\n",{})
      -------------------------------------
      printf(fh,"[Builtin Functions]\n",{})
      dump_script_and_function_info(fh,function_list)
      printf(fh,"\n",{})
      -------------------------------------
      printf(fh,"[Operators]\n",{})
      for i=1 to length(operator_list) do
        printf(fh,"%s %d\t%s\t%s\tPriority=%d\n",{
           file_list[source[operator_list[i][OPER_LINE]][SRC_FILE]]
          ,source[operator_list[i][OPER_LINE]][SRC_LINE]
          ,operator_list[i][PAIR_NAME]
          ,operator_list[i][OPER_TRUENAME]
          ,operator_list[i][PAIR_NUM]
        })
      end for
      printf(fh,"\n",{})
      -------------------------------------
      printf(fh,"[Script Dumps]\n",{})
      for i=1 to length(all_scripts) do
        printf(fh,"%s %d\tID=%d\t%s\n",{
           file_list[source[all_scripts[i][3]][SRC_FILE]]
          ,source[all_scripts[i][3]][SRC_LINE]
          ,all_scripts[i][1]
          ,all_scripts[i][2]
        })
        for j=1 to length(all_scripts[i][5]) do
          printf(fh,"%s %d\tvar=%s\n",{
             file_list[source[all_scripts[i][5][j][CMD_LINE]][SRC_FILE]]
            ,source[all_scripts[i][5][j][CMD_LINE]][SRC_LINE]
            ,all_scripts[i][5][j][CMD_TEXT]
          })
        end for
        printf(fh,"%d bytes compiled\n",{length(all_scripts[i][6])})
--        printf(fh,"%s\n\n",{dump_script_tree(all_scripts[i][4],0)})
        printf(fh,"%s\n\n",{dump_script_binary(all_scripts[i][6][CODE_START_BYTE_OFFSET+1..length(all_scripts[i][6])],0,0)})
      end for
      printf(fh,"\n",{})
      -------------------------------------
      close(fh)
    else
      wrap_print("Error opening debug report file "&COLBWHI&"%s"&COLRED&"\n",{debug_file})  
    end if
  end if
end procedure

---------------------------------------------------------------------------

function get_cmd_depth(integer ptr,sequence data,integer depth)
  sequence result
  sequence this
  result={}
  while true do
    --if get_key()=27 then abort(1/0) end if
    if ptr>length(data) then
      src_error("block ended prematurely. Missing "&COLYEL&"end"&COLRED&" or "&COLYEL&")"&COLRED&"?",data[length(data)][CMD_LINE])
    end if
    this=data[ptr]
    ptr+=1
    if compare("end",this[CMD_TEXT])=0 then
      depth-=1
    elsif compare("begin",this[CMD_TEXT])=0 then
      depth+=1
    end if
    if depth=0 then
      exit --break out of the while
    else
      result=append(result,this)  
    end if
  end while
  return({ptr,result})
end function

---------------------------------------------------------------------------

--identify the kind and id of a text command. Does not support untranslaed operators or floaty parethesis
function what_kind_and_id(sequence command,sequence local_vars)
  integer kind,id
  integer keyword
  sequence s
  sequence str_temp
  s=command[CMD_TEXT]
  keyword=alpha_tree_data(reserved,s,0)
  if string_is_an_integer(s) then
    kind=KIND_NUMBER
    id=string_to_object(s,{})
  elsif length(s) and s[1] = '@' then
    kind=KIND_REFERENCE
    id=0 -- ID always resolves to 0 for references here, since it is too early to know all
         -- script IDs. The real work is done in binary_compile_recurse
  elsif find(s,column(local_vars,CMD_TEXT)) then
    kind=KIND_LOCAL
    id=find(s,column(local_vars,CMD_TEXT))
  elsif keyword=RESERVE_GLOBAL then
    kind=KIND_GLOBAL
    id=global_list[PAIR_NUM][find(s,global_list[PAIR_NAME])]
  elsif keyword=RESERVE_FLOW then
    kind=KIND_FLOW
    id=flow_list[find(s,column(flow_list,PAIR_NAME))][PAIR_NUM]
  elsif keyword=RESERVE_FUNCTION then
    kind=KIND_FUNCTION
    id=function_list[find(s,column(function_list,PAIR_NAME))][PAIR_NUM]
  elsif keyword=RESERVE_SCRIPT then
    kind=KIND_SCRIPT
    id=script_list[find(s,column(script_list,PAIR_NAME))][PAIR_NUM]
  elsif keyword=RESERVE_BUILTIN then
    kind=KIND_MATH
    id=math_list[find(s,column(math_list,PAIR_NAME))][PAIR_NUM]
  else
    src_error(sprintf("Unrecognised name "&COLYEL&"%s"&COLRED&". It has not been defined as script, constant, variable, or anything else",{s}),command[CMD_LINE])
  end if
  return({kind,id})
end function

---------------------------------------------------------------------------

--identify the kind of a text command
function what_kind(sequence command,sequence local_vars, integer look_for_operators)
  integer kind
  integer keyword
  sequence s
  s=command[CMD_TEXT]
  keyword=alpha_tree_data(reserved,s,0)
  if string_is_an_integer(s) then
    kind=KIND_NUMBER
  elsif length(s) and s[1] = '@' then
    kind=KIND_REFERENCE
  elsif find(s,column(local_vars,CMD_TEXT)) then
    kind=KIND_LOCAL
  elsif length(s)=0 then
    kind=KIND_PARENS
  elsif look_for_operators and find(s,column(operator_list,PAIR_NAME)) then
    kind=KIND_OPERATOR --this MUST go before KIND_MATH, because some operators and math functions have the same name
  elsif keyword=RESERVE_GLOBAL then
    kind=KIND_GLOBAL
  elsif keyword=RESERVE_FLOW or keyword=RESERVE_BEGIN or keyword=RESERVE_END then
    kind=KIND_FLOW
  elsif keyword=RESERVE_FUNCTION then
    kind=KIND_FUNCTION
  elsif keyword=RESERVE_SCRIPT then
    kind=KIND_SCRIPT
  elsif keyword=RESERVE_BUILTIN then
    kind=KIND_MATH
  else
    src_error(sprintf("Unrecognised name "&COLYEL&"%s"&COLRED&". It has not been defined as script, constant, variable, or anything else",{s}),command[CMD_LINE])
  end if
  return(kind)
end function

---------------------------------------------------------------------------

function how_many_args(sequence name,integer kind)
  integer result
  integer at
  if kind=KIND_PARENS then
    result=-1 --parens support (n,operator,n) but if one of n is an operator, it comes out to be more :P
  elsif kind=KIND_FLOW then
    result=-1 --flow supports an unknown number of args
  elsif kind=KIND_OPERATOR then
    result=0 -- its important that operators behave as zero-arg-thingamabobs before they are translated into builtin math functions
  elsif kind=KIND_MATH then
    at=find(name[CMD_TEXT],column(math_list,PAIR_NAME))
    result=length(math_list[at][FUNC_ARGS])
  elsif kind=KIND_FUNCTION then
    at=find(name[CMD_TEXT],column(function_list,PAIR_NAME))
    result=length(function_list[at][FUNC_ARGS])
  elsif kind=KIND_SCRIPT then
    at=find(name[CMD_TEXT],column(script_list,PAIR_NAME))
    result=length(script_list[at][FUNC_ARGS])
  else  
    --numbers, variables, etc do not permit args
    result=0
  end if
  return(result)
end function

---------------------------------------------------------------------------

function get_script_cmd(integer ptr,sequence data,sequence vars)
  sequence command
  sequence this
  sequence after
  integer kind
  integer argcount
  after={}
  command=data[ptr]
  ptr+=1
  if compare("end",command[CMD_TEXT])=0 then
    src_error(COLYEL&"end"&COLRED&" or "&COLYEL&")"&COLRED&" without "&COLYEL&"begin"&COLRED&" or "&COLYEL&"("&COLRED,command[CMD_LINE])
  elsif compare("begin",command[CMD_TEXT])=0 then
    --floaty brackets for order-of-operations-enforcement
    ptr-=1
    command[CMD_TEXT]=""
  elsif compare("variable",command[CMD_TEXT])=0 then
    --must ignore variable declaration
    if ptr<=length(data) then
      --there is room for args
      ptr+=1--only increment the pointer when we have args
      after=get_cmd_depth(ptr,data,1)
      ptr=after[1]   --this is a hack, because we cannot say {n,n}=func()
    end if
    --recursing seems the easyest way to skip a command
    return(get_script_cmd(ptr,data,vars))
  end if

  if ptr<=length(data) then
    --there is room for args
    kind=what_kind(command,vars,true)
    argcount=how_many_args(command,kind)

    if argcount=0 then
      --no arguments are allowed
    else
      this=data[ptr]
      if compare("begin",this[CMD_TEXT])=0 then
        --yes, it has args
        ptr+=1--only increment the pointer when we have args
        after=get_cmd_depth(ptr,data,1)
        ptr=after[1]   --this is a hack, because we cannot say {n,n}=func()
        after=after[2]
      elsif kind=KIND_SCRIPT or kind=KIND_FUNCTION or kind=KIND_FLOW then
        --has no args, but thats okay (check later)
      else  
        --has no args, but requires them!
        src_error(sprintf(
                     "expected "&COLYEL&"()"&COLRED&" or "&COLYEL&"begin,end"&COLRED&" for %s "&COLYEL&"%s"&COLRED&" but found "&COLYEL&"%s"&COLRED
                    ,{KIND_LONGNAMES[kind],command[CMD_TEXT],this[CMD_TEXT]}),command[CMD_LINE]
                  ) 
      end if
    end if
  end if
  return({ptr,{command,after}})
end function

---------------------------------------------------------------------------

function compile_commands(sequence script_data,sequence vars)
  integer ptr
  sequence this
  sequence command
  sequence result
  result={}
  ptr=1
  while true do
    this=get_script_cmd(ptr,script_data,vars)
    ptr=this[1]
    command=this[2]
    if length(command[2])>0 then
      --this command has arguments that need parsing
      command[2]=compile_commands(command[2],vars)
    end if
    result=append(result,command)
    if ptr>length(script_data) then
      exit --break out of while when there is no more data
    end if
  end while
  return(result)
end function

---------------------------------------------------------------------------

function gather_local_vars(sequence vars,sequence data)
  sequence this
  integer at
  integer ptr
  ptr=1
  while true do
    this=data[ptr]
    ptr+=1
    if compare("variable",this[CMD_TEXT])=0 then
      if ptr>length(data) then
        src_error(sprintf(COLYEL&"variable"&COLRED&" should be followed by "&COLYEL&"(name)"&COLRED,{}),this[CMD_LINE])
      end if
      this=data[ptr]
      ptr+=1
      if compare("begin",this[CMD_TEXT])=0 then
        while true do
          if ptr>length(data) then
            src_error(sprintf(COLYEL&"variable"&COLRED&" should be followed by "&COLYEL&"(name)"&COLRED,{}),this[CMD_LINE])
          end if
          this=data[ptr]
          ptr+=1
          if compare("end",this[CMD_TEXT])=0 then
            exit--break the while
          end if
          check_for_reserved(this[CMD_TEXT],this[CMD_LINE],"local variable name")
          at=find(this[CMD_TEXT],column(vars,CMD_TEXT))
          if at then
            src_error(
              sprintf(
                "local variable/argument "&COLYEL&"%s"&COLRED&" is already defined in line %d of "&COLBWHI&"%s"&COLRED,{this[CMD_TEXT],source[vars[at][CMD_LINE]][SRC_LINE]
               ,file_list[source[vars[at][CMD_LINE]][SRC_FILE]]}
              )
              ,this[CMD_LINE]
            )
          else
            vars=append(vars,this)
          end if
        end while
      else
        src_error(sprintf(COLYEL&"variable"&COLRED&" should be followed by "&COLYEL&"(name)"&COLRED,{}),this[CMD_LINE])
      end if
    end if
    if ptr>length(data) then
      exit --break out of the while
    end if
  end while
  return(vars)
end function

---------------------------------------------------------------------------

--parse the script tree and make if absorb then and else, for and while absorb do, check arg(count)s of flow statements
function normalize_flow_control(sequence tree,sequence vars)
  integer ptr
  sequence s
  integer line
  integer argkind
  integer var_at
  ptr=1
  while ptr<=length(tree) do
    s=tree[ptr][TREE_TRUNK][CMD_TEXT]
    line=tree[ptr][TREE_TRUNK][CMD_LINE]
    if compare("if",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>1 then
        src_error(sprintf(
                      COLYEL&"if"&COLRED&" statement has %d conditions. It should have only one. Use "&COLYEL&"and"&COLRED&" and "&COLYEL&"or"&COLRED&" for complex conditions"
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      elsif length(tree[ptr][TREE_BRANCHES])=0 then
        src_error(sprintf(COLYEL&"if"&COLRED&" statement has no condition. It should have one.",{}),line)
      end if
      if ptr<length(tree) then
        --there is room
        if compare("then",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
          --found then
          tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1])
          tree=delete_element(tree,ptr+1)
          if ptr<length(tree) then
            --there is room for else
            if compare("else",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
              --found else after then
              tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1])
              tree=delete_element(tree,ptr+1)
            else
              --no else found, but thats okay.  
              --add dummy else
              tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"else",line},{}})
            end if  
          else  
            --add dummy else
            tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"else",line},{}})
          end if
        elsif compare("else",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
          --found else
          --add dummy then before else
          tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"then",line},{}})
          tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1])
          tree=delete_element(tree,ptr+1)
        else  
          --found neither then nor else
          src_error(sprintf("expected "&COLYEL&"then"&COLRED&" or "&COLYEL&"else"&COLRED&" but found "&COLYEL&"%s"&COLRED,{tree[ptr+1][TREE_TRUNK][CMD_TEXT]}),line)  
        end if
      else
        --no room for then or else
        src_error(COLYEL&"if"&COLRED&" does not have "&COLYEL&"then"&COLRED&" or "&COLYEL&"else"&COLRED,line)  
      end if
    elsif compare("while",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>1 then
        src_error(sprintf(
                  COLYEL&"while"&COLRED&" statement has %d conditions. It should have only one. Use "&COLYEL&"and"&COLRED&" and "&COLYEL&"or"&COLRED&" for complex conditions"
                  ,{length(tree[ptr][TREE_BRANCHES])}
                  ),line)
      elsif length(tree[ptr][TREE_BRANCHES])=0 then
        src_error(sprintf(COLYEL&"while"&COLRED&" statement has no condition. It should have one.",{}),line)
      end if
      if ptr<length(tree) then
        --there is room
        if compare("do",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
          --found do
          tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1])
          tree=delete_element(tree,ptr+1)
        else
          src_error(sprintf(COLYEL&"while"&COLRED&" should be followed by "&COLYEL&"do"&COLRED&", not by "&COLYEL&"%s"&COLRED&".",{tree[ptr+1][TREE_TRUNK][CMD_TEXT]}),line)
        end if
      else  
        src_error(sprintf(COLYEL&"while"&COLRED&" should be followed by "&COLYEL&"do"&COLRED,{}),line)
      end if    
    elsif compare("for",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])<3 then
        src_error(sprintf(COLYEL&"for"&COLRED&" statement needs three arguments",{}),line)
      elsif length(tree[ptr][TREE_BRANCHES])>4 then
        src_error(sprintf(COLYEL&"for"&COLRED&" statement has too many arguments (%d)",{length(tree[ptr][TREE_BRANCHES])}),line)
      elsif length(tree[ptr][TREE_BRANCHES])=3 then
        --append default step value
        tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"1",tree[ptr][TREE_TRUNK][CMD_LINE]},{}})
      end if
      argkind=what_kind(tree[ptr][TREE_BRANCHES][1][TREE_TRUNK],vars,true)
      if argkind=KIND_LOCAL then
        --translate into a numeric reference to a variable
        used_locals=append(used_locals,tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT])
        var_at=find(tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT],column(vars,CMD_TEXT))
        tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]=sprintf("-%d",{var_at})
      elsif argkind=KIND_GLOBAL then
        --warn, then translate into a numeric reference to a variable
        src_warn(sprintf(
          "Using global variable "&COLYEL&"%s"&COLRED&" as the counter in a "&COLYEL&"for"&COLRED&" loop"
         ,{tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]}
        ),tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_LINE])
        var_at=find(tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT],global_list[PAIR_NAME])
        tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]=sprintf("%d",{global_list[PAIR_NUM][var_at]})
      else  
        --only variables allowed as the first argument of a "for"
        src_error(
           sprintf("first argument of "&COLYEL&"for"&COLRED&" statement must be a variable, not %s "&COLYEL&"%s"&COLRED,{
              KIND_LONGNAMES[argkind]
             ,tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]
           })
          ,tree[ptr][TREE_BRANCHES][1][TREE_TRUNK][CMD_LINE]
        )
      end if
      if ptr<length(tree) then
        --there is room
        if compare("do",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
          --found do
          tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1])
          tree=delete_element(tree,ptr+1)
        else
          src_error(sprintf(COLYEL&"for"&COLRED&" should be followed by "&COLYEL&"do"&COLRED&", not by "&COLYEL&"%s"&COLRED&".",{tree[ptr+1][TREE_TRUNK][CMD_TEXT]}),line)
        end if
      else  
        src_error(sprintf(COLYEL&"for"&COLRED&" should be followed by "&COLYEL&"do"&COLRED,{}),line)
      end if
    elsif compare("return",s)=0 or compare("exitreturning",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>1 then
        src_error(sprintf(
                      COLYEL&s&COLRED&" statement has %d arguments. It should have only one."
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      elsif length(tree[ptr][TREE_BRANCHES])=0 then
        src_error(sprintf(COLYEL&s&COLRED&" statement has no argument. It should have one. Prehaps you meant to use "&COLYEL&"exit script"&COLRED,{}),line)
      end if
    elsif compare("break",s)=0 or compare("continue",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>1 then
        src_error(sprintf(
                      COLYEL&s&COLRED&" statement has %d arguments. It should have no more than one."
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      elsif length(tree[ptr][TREE_BRANCHES])=0 then
        --append default value
        tree[ptr][TREE_BRANCHES]={{{"1",tree[ptr][TREE_TRUNK][CMD_LINE]},{}}}
      end if
    elsif compare("exitscript",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>0 then
        src_error(sprintf(
                      COLYEL&s&COLRED&" statement has %d arguments. It should have none. Prehaps you meant to use "&COLYEL&"exit returning"&COLRED
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      end if
    elsif compare("switch",s)=0 then
      if length(tree[ptr][TREE_BRANCHES])>1 then
        src_error(sprintf(
                      COLYEL&s&COLRED&" statement has %d expressions. It should have only one."
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      elsif length(tree[ptr][TREE_BRANCHES])=0 then
        src_error(sprintf(
                      COLYEL&s&COLRED&" statement has no expression to match! Write "&COLYEL&"switch (expression) do (...)"&COLRED
                      ,{length(tree[ptr][TREE_BRANCHES])}
                    ),line)
      end if
      if ptr<length(tree) then
        --there is room
        if compare("do",tree[ptr+1][TREE_TRUNK][CMD_TEXT])=0 then
          --found do, move its arguments to switch, behind the expression
          for j=1 to length(tree[ptr+1][TREE_BRANCHES]) do
            line=tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_LINE]
            if j=1 and compare("case",tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT]) then
              src_error(sprintf(COLYEL&"switch() do("&COLRED&" should be followed with a "&COLYEL&"case"&COLRED&", not with "&COLYEL&"%s"&COLRED&".",{tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT]}),line)
            end if
            if compare("else",tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT])=0 then
              if j=length(tree[ptr+1][TREE_BRANCHES]) then
                --convert the else to a do
                tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"do",line},tree[ptr+1][TREE_BRANCHES][j][TREE_BRANCHES]})
              else
                src_error(sprintf(COLYEL&"else"&COLRED&" should be last statement inside a "&COLYEL&"switch"&COLRED&" block",{}),line)
              end if
            elsif compare("case",tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT])=0 then
              --expand case
              tree[ptr][TREE_BRANCHES]=tree[ptr][TREE_BRANCHES]&tree[ptr+1][TREE_BRANCHES][j][TREE_BRANCHES]
            elsif compare("do",tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT])=0 then
              tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],tree[ptr+1][TREE_BRANCHES][j])
              if j=length(tree[ptr+1][TREE_BRANCHES]) then
                --insert a dummy do default block since else has been left out
                tree[ptr][TREE_BRANCHES]=append(tree[ptr][TREE_BRANCHES],{{"do",line},{}})
              end if
            else
              src_error(sprintf("Expected "&COLYEL&"case do"&COLRED&" or "&COLYEL&"else"&COLRED&", but found "&COLYEL&"%s"&COLRED&".",{tree[ptr+1][TREE_BRANCHES][j][TREE_TRUNK][CMD_TEXT]}),line)
            end if
          end for
          tree=delete_element(tree,ptr+1)
        else
          src_error(sprintf(COLYEL&"switch"&COLRED&" should be followed by "&COLYEL&"do"&COLRED&", not by "&COLYEL&"%s"&COLRED&".",{tree[ptr+1][TREE_TRUNK][CMD_TEXT]}),line)
        end if
      else  
        src_error(sprintf(COLYEL&"switch"&COLRED&" should be followed by "&COLYEL&"do"&COLRED,{}),line)
      end if
    elsif compare("case",s)=0 then
      src_error(sprintf(COLYEL&"case"&COLRED&" is not allowed outside of "&COLYEL&"switch"&COLRED,{}),line)
    end if
    tree[ptr][TREE_BRANCHES]=normalize_flow_control(tree[ptr][TREE_BRANCHES],vars)
    ptr+=1
  end while
  return(tree)  
end function

---------------------------------------------------------------------------

function convert_operators_recurse(sequence tree,integer priority)
  integer ptr
  ptr=1
  while ptr<=length(tree) do
    --for each peer branch on the tree
    for j=1 to length(operator_list) do
      if priority=operator_list[j][PAIR_NUM] then
        --for each operator that matches the current priority
        if compare(operator_list[j][PAIR_NAME],tree[ptr][TREE_TRUNK][CMD_TEXT])=0 then
          --found an operator
          if length(tree[ptr][TREE_BRANCHES])=0 then
            --has no args. if it has args, we assume it is an "or" "and" or "xor" that has already been converted
            if ptr=1 then
              --there is no room for the before-operands. Bad!
              src_error(sprintf("operator "&COLYEL&"%s"&COLRED&" is missing its left-side operand",tree[ptr][TREE_TRUNK][CMD_TEXT]),tree[ptr][TREE_TRUNK][CMD_LINE])
            elsif ptr=length(tree) then
              --there is no room for the after-operand. Bad!
              src_error(sprintf("operator "&COLYEL&"%s"&COLRED&" is missing its right-side operand",tree[ptr][TREE_TRUNK][CMD_TEXT]),tree[ptr][TREE_TRUNK][CMD_LINE])
            else
              --convert the operator to its true functio name (which might be the same)
              tree[ptr][TREE_TRUNK][CMD_TEXT]=operator_list[j][OPER_TRUENAME]
              --grab the operands and turn them into REAL args  
              tree[ptr][TREE_BRANCHES]={tree[ptr-1],tree[ptr+1]}
              --delete the operands
              tree=delete_element(tree,ptr+1)
              tree=delete_element(tree,ptr-1)
              --re-align the pointer
              ptr-=1
            end if
          end if
        end if
      end if
    end for
    --recurse
    tree[ptr][TREE_BRANCHES]=convert_operators_recurse(tree[ptr][TREE_BRANCHES],priority)
    ptr+=1
  end while
  return(tree)
end function

---------------------------------------------------------------------------

function convert_operators(sequence tree)
  sequence priority_list
  priority_list={}
  --build a list of valid priorities
  for i=1 to length(operator_list) do
    if not find(operator_list[i][PAIR_NUM],priority_list) then
      priority_list=append(priority_list,operator_list[i][PAIR_NUM])
    end if
  end for
  priority_list=sort(priority_list)
  for i=1 to length(priority_list) do
    tree=convert_operators_recurse(tree,priority_list[i])
  end for
  return(tree)
end function

---------------------------------------------------------------------------

function fix_arguments(sequence tree,integer kind,sequence list,sequence vars)
  integer at,var_at
  integer argkind
  at=find(tree[TREE_TRUNK][CMD_TEXT],column(list,PAIR_NAME))
  if length(list[at][FUNC_ARGS]) < length(tree[TREE_BRANCHES]) then
    --warn and truncate if too many args are present
    src_warn(sprintf(
      "%s "&COLYEL&"%s"&COLRED&" has %d more arguments than it needs"
      ,{KIND_LONGNAMES[kind],tree[TREE_TRUNK][CMD_TEXT],length(tree[TREE_BRANCHES])-length(list[at][FUNC_ARGS])}
    ),tree[TREE_TRUNK][CMD_LINE])
    tree[TREE_BRANCHES]=tree[TREE_BRANCHES][1..length(list[at][FUNC_ARGS])]
  elsif length(list[at][FUNC_ARGS]) > length(tree[TREE_BRANCHES]) then
    --add defaults if not enough args are present
    if kind=KIND_MATH then
      --special processing for math
      if list[at][PAIR_NUM]<16 or list[at][PAIR_NUM]=19 then
        --math shouldnt have defaults
        src_error(sprintf(
          "math function "&COLYEL&"%s"&COLRED&" has %d arguments it should always have %d"
          ,{tree[TREE_TRUNK][CMD_TEXT],length(tree[TREE_BRANCHES]),length(math_list[list[at][PAIR_NUM]][3])}
        ),tree[TREE_TRUNK][CMD_LINE])
      else
        --variable stuff can have a defaults
        if length(tree[TREE_BRANCHES]) = 0 then
          --no defaults for first argument of variable function
          src_error(sprintf(
            "variable manipulation function "&COLYEL&"%s"&COLRED&" has %d arguments it needs at least 1"
            ,{tree[TREE_TRUNK][CMD_TEXT],length(tree[TREE_BRANCHES])}
          ),tree[TREE_TRUNK][CMD_LINE])
        elsif length(tree[TREE_BRANCHES]) = 1 then
          --make defaults for second arg of variable function  
          if list[at][PAIR_NUM]=16 then
            --setvariable
            tree[TREE_BRANCHES]=append(tree[TREE_BRANCHES],{
               {"0",tree[TREE_TRUNK][CMD_LINE]}
              ,{}
            })
          else
            --increment and decrement  
            tree[TREE_BRANCHES]=append(tree[TREE_BRANCHES],{
               {"1",tree[TREE_TRUNK][CMD_LINE]}
              ,{}
            })
          end if
        end if
      end if
    else  
      --normal processing for script and function
      for i=length(tree[TREE_BRANCHES])+1 to length(list[at][FUNC_ARGS]) do
        tree[TREE_BRANCHES]=append(tree[TREE_BRANCHES],{
           {sprintf("%d",{list[at][FUNC_ARGS][i]}),tree[TREE_TRUNK][CMD_LINE]}
          ,{}
        })
      end for
    end if
  end if
    --this is as good a time as any to make sure that var maipulation functions point to real variables
    if kind=KIND_MATH and list[at][PAIR_NUM]>=16 and list[at][PAIR_NUM]<19 then
      argkind=what_kind(tree[TREE_BRANCHES][1][TREE_TRUNK],vars,false)
      if argkind=KIND_LOCAL then
        --its local. translate it to a numeric reference
        var_at=find(tree[TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT],column(vars,CMD_TEXT))
        tree[TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]=sprintf("-%d",{var_at})
      elsif argkind=KIND_GLOBAL then
        --its global. translate it to a numeric reference
        var_at=find(tree[TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT],global_list[PAIR_NAME])
        tree[TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]=sprintf("%d",{global_list[PAIR_NUM][var_at]})
      else
        --its not a variable. bad!
        src_error(sprintf(
          "first argument of variable manipulation function "&COLYEL&"%s"&COLRED&" must be a variable, not %s "&COLYEL&"%s"&COLRED
          ,{tree[TREE_TRUNK][CMD_TEXT],KIND_LONGNAMES[argkind],tree[TREE_BRANCHES][1][TREE_TRUNK][CMD_TEXT]}
        ),tree[TREE_TRUNK][CMD_LINE])
      end if
    end if
  return(tree[TREE_BRANCHES])
end function

---------------------------------------------------------------------------

function normalize_arguments(sequence tree,sequence vars)
  integer kind
  --unlike the flow normalization and operator translation we do not insert/delete elements from the current level, so we can use a "for" safely, and dont need a "while"
  for i=1 to length(tree) do
    kind=what_kind(tree[i][TREE_TRUNK],vars,false)
    if kind=KIND_SCRIPT then
      tree[i][TREE_BRANCHES]=fix_arguments(tree[i],kind,script_list,vars)
    elsif kind=KIND_FUNCTION then
      tree[i][TREE_BRANCHES]=fix_arguments(tree[i],kind,function_list,vars)
    elsif kind=KIND_MATH then
      tree[i][TREE_BRANCHES]=fix_arguments(tree[i],kind,math_list,vars)
    end if --number, flow, global, local, parens need no argchecking
    if length(tree[i][TREE_BRANCHES]) then
      --if there are sub-arguments, recurse
      tree[i][TREE_BRANCHES]=normalize_arguments(tree[i][TREE_BRANCHES],vars)
    end if
  end for
  return(tree)  
end function

---------------------------------------------------------------------------

--returns a two-char string that represents a 16-bit word in least-signifigant-byte-first order
function output_word(integer n)
  integer b1,b2
  b1=and_bits(n,#FF)
  b2=floor(and_bits(n,#FFFF)/256)
  return({b1,b2})
end function

---------------------------------------------------------------------------

--looks for a matching block of code that we can refer to instead of rewriting the code
--somewhat time consuming
function seek_appropriate_reference(sequence result,sequence done_code)
  for i=1 to length(done_code)-(length(result)-1) by 2 do
    if compare(result,done_code[i..i+(length(result)-1)])=0 then
      return((i-1)/2)
    end if
  end for
  return(-1)
end function

---------------------------------------------------------------------------

--return value is a sequence when new command data was appended, and an integer when an offset is returned
function binary_compile_recurse(sequence tree,sequence vars,sequence done_code)
  sequence result
  integer kind,id
  integer at
  sequence s
  integer offset
  sequence value_temp, str_temp
  object sub_result
  sequence done_code_plus_result
  result={}
  kind=what_kind(tree[TREE_TRUNK],vars,false)
  s=tree[TREE_TRUNK][CMD_TEXT]
  if kind=KIND_NUMBER then
    value_temp=value(s)
    result&=output_word(kind)
    result&=output_word(force_16_bit(value_temp[2],tree[TREE_TRUNK][CMD_LINE]))
  elsif kind=KIND_REFERENCE then
    str_temp = s[2..length(s)]
    --is it a global variable?
    at=find(str_temp,global_list[PAIR_NAME])
    if at then
      --yes, it is a global, compile to global ID
      result&=output_word(KIND_NUMBER)
      id=global_list[PAIR_NUM][at]
      result&=output_word(id)
    else
      --is it a script?
      at=find(str_temp,column(script_list,PAIR_NAME))
      if at then
        --yes, it is a script. Compile to a script ID
        result&=output_word(KIND_NUMBER)
        id=script_list[at][PAIR_NUM]
        result&=output_word(id)
      else
        src_error(sprintf("reference "&COLYEL&"@%s"&COLRED&" could not be resolved",{str_temp}),tree[TREE_TRUNK][CMD_LINE])
      end if
    end if
  elsif kind=KIND_GLOBAL then
    at=find(s,global_list[PAIR_NAME])
    result&=output_word(kind)
    result&=output_word(global_list[PAIR_NUM][at])
  elsif kind=KIND_LOCAL then
    at=find(s,column(vars,CMD_TEXT))
    result&=output_word(kind)
    result&=output_word(at-1)
  elsif kind=KIND_SCRIPT or kind=KIND_FUNCTION or kind=KIND_FLOW or kind=KIND_MATH then
    if kind=KIND_SCRIPT then
      at=find(s,column(script_list,PAIR_NAME))
      id=script_list[at][PAIR_NUM]
    elsif kind=KIND_FUNCTION then
      at=find(s,column(function_list,PAIR_NAME))
      id=function_list[at][PAIR_NUM]
    elsif kind=KIND_FLOW then
      at=find(s,column(flow_list,PAIR_NAME))
      id=flow_list[at][PAIR_NUM]
    elsif kind=KIND_MATH then
      at=find(s,column(math_list,PAIR_NAME))
      id=math_list[at][PAIR_NUM]
    end if
    result&=output_word(kind)
    result&=output_word(id)
    result&=output_word(length(tree[TREE_BRANCHES]))
    for i=1 to length(tree[TREE_BRANCHES]) do
      --add placeholders for each argoffset
      result&={#FFFFFF,#FFFFFF} --these values are waaaay out if range for a 16-bit number, so it will never be matched by seek_appropriate_reference
    end for
    for i=1 to length(tree[TREE_BRANCHES]) do
      --actually evaluate each argument and set the real offsets
      done_code_plus_result=done_code&result --prefabricating this is faster, since we use it twice
      offset=floor(length(done_code_plus_result)/2)
      sub_result=binary_compile_recurse(tree[TREE_BRANCHES][i],vars,done_code_plus_result)
      if sequence(sub_result) then
        --if new data was added, append it
        result&=sub_result
      else
        --if a matching reference was available use it
        offset=sub_result
      end if
      result[7+(i-1)*2..8+(i-1)*2]=output_word(offset)
    end for
  else
    src_error(sprintf("Compiler Bug! Illegal kind "&COLYEL&"%d"&COLRED&" for "&COLYEL&"%s"&COLRED,{kind,s}),tree[TREE_TRUNK][CMD_LINE])
  end if
  if not fast_mode then
    at=seek_appropriate_reference(result,done_code)
    if at>=0 then
      --found existing data exactly like this command, so just return a reference to it
      return(at)
    end if
  end if
  --return the data for this command to be appended
  return(result)
end function

---------------------------------------------------------------------------

function binary_compile(integer id,sequence tree,sequence vars)
  sequence result
  integer at
  --binary data is all in 16-bit signed words.
  --the first word is the zero-rooted byte-offset of the first executable code byte
  --in retrospect, word-offset would have been more appropriate, since everything is word-alinged, but hey! gotta be backwards compatable!
  result=output_word(CODE_START_BYTE_OFFSET)
  --the second word is the number of local variables
  result&=output_word(length(vars))
  --the third word is the number of arguments the script takes (also in SCRIPTS.TXT)
  at=find(id,column(script_list,PAIR_NUM))
  result&=output_word(length(script_list[at][FUNC_ARGS]))
  --what follows is command data in the format [kindID,Value,argcount,argpointerlist]
  --numbers and variables have no argcount or argpointerlist
  --an argpointer is the zero-rooted word-offset of the argument relative
  --to the start of the executable commands. I realise that this format is
  --unnecisaraly complicated. I had hoped to get benefits of being able to
  --store frequently reused commands only once and then just point to them,
  --but in actual practice, it isnt worth the trouble, since the only
  --commands that tend to be redundant are the really short ones.
  --the first command is always a "do". there can be only one top-level command
  if length(tree)!=1 then
    simple_error(sprintf("compiler bug! script tree has %s root nodes",{length(tree)}))
  end if
  result&=binary_compile_recurse(tree[1],vars,"")
  return(result)
end function

---------------------------------------------------------------------------

--floaty brackets are un-needed after the operators have been translated.
function collapse_floaty_brackets(sequence tree)
  integer i
  sequence graft
  i=1
  while i<=length(tree) do
    if length(tree[i][TREE_TRUNK][CMD_TEXT])=0 then
      --found a floaty-bracket
      graft=tree[i][TREE_BRANCHES]
      tree=delete_element(tree,i)
      tree=insert_sequence(tree,graft,i)
    else
      if length(tree[i][TREE_BRANCHES]) then
        tree[i][TREE_BRANCHES]=collapse_floaty_brackets(tree[i][TREE_BRANCHES])
      end if
      i+=1
    end if
  end while
  return(tree)
end function

---------------------------------------------------------------------------

function sanity_check(sequence tree,sequence vars,sequence parent)
  sequence s
  sequence kind_and_id
  integer kind,id
  for i=1 to length(tree) do
    s=tree[i][TREE_TRUNK][CMD_TEXT]
    kind_and_id=what_kind_and_id(tree[i][TREE_TRUNK],vars)
    kind=kind_and_id[1]
    id=kind_and_id[2]
    if (compare("if",parent)=0 or compare("while",parent)=0) and i=1 then
      if kind=KIND_NUMBER then
        if id then
          src_warn(sprintf("condition is always true ("&COLYEL&"%d"&COLRED&")",{id}),tree[i][TREE_TRUNK][CMD_LINE])
        else
          src_warn("condition is always false",tree[i][TREE_TRUNK][CMD_LINE])
        end if
      elsif kind=KIND_FLOW then
        src_warn(sprintf("should not use flow control command "&COLYEL&"%s"&COLRED&" as a condition",{s}),tree[i][TREE_TRUNK][CMD_LINE])
      end if
    elsif compare("do",parent)=0 or compare("then",parent)=0 or compare("else",parent)=0 then
      if kind=KIND_NUMBER then
        src_warn(sprintf("Expected script, function, or flow control, but found an expression with value "&COLYEL&"%d"&COLRED&". It will do nothing here."
                 ,{id}),tree[i][TREE_TRUNK][CMD_LINE])
      elsif kind=KIND_GLOBAL then
        src_warn(sprintf("Expected script, function, or flow control, but found global variable "&COLYEL&"%s"&COLRED&". It will do nothing here."
                 ,{s}),tree[i][TREE_TRUNK][CMD_LINE])
      elsif kind=KIND_LOCAL then
        src_warn(sprintf("Expected script, function, or flow control, but found local variable "&COLYEL&"%s"&COLRED&". It will do nothing here."
                 ,{vars[id][CMD_TEXT]}),tree[i][TREE_TRUNK][CMD_LINE])
      elsif kind=KIND_MATH and id<=15 then
        src_warn(sprintf("built-in function "&COLYEL&"%s"&COLRED&" is returning a value that is being discarded"
                 ,{s}),tree[i][TREE_TRUNK][CMD_LINE])
      end if
    end if
    if kind=KIND_GLOBAL then
      if not find(s,used_globals) then
        used_globals=append(used_globals,s)
      end if
    elsif kind=KIND_LOCAL then
      if not find(s,used_locals) then
        used_locals=append(used_locals,s)
      end if
    end if
    if length(tree[i][TREE_BRANCHES]) then
      --if there are sub-arguments, recurse
      tree[i][TREE_BRANCHES]=sanity_check(tree[i][TREE_BRANCHES],vars,tree[i][TREE_TRUNK][CMD_TEXT])
    end if
  end for
  return(tree)  
end function

---------------------------------------------------------------------------

function optimized_arg(sequence tree,sequence vars)
  sequence kind_and_id
  integer kind,id
  object arg1,arg2
  kind_and_id=what_kind_and_id(tree[TREE_TRUNK],vars)
  kind=kind_and_id[1]
  id=kind_and_id[2]
  if kind=KIND_NUMBER then
    return(id)
  elsif kind=KIND_MATH and id<=15 then
    arg1=optimized_arg(tree[TREE_BRANCHES][1],vars)
    arg2=optimized_arg(tree[TREE_BRANCHES][2],vars)
    if integer(arg1) and integer(arg2) then
       if id=0 then
         --random
         if arg1=arg2 then
           return(arg1)
         end if
       elsif id=1 then
         --exponent
         return(power(arg1,arg2))
       elsif id=2 then
         --modulus
         return(floor(remainder(arg1,arg2)))
       elsif id=3 then
         --divide
         return(floor(arg1/arg2))
       elsif id=4 then
         --multiply
         return(arg1*arg2)
       elsif id=5 then
         --subtract
         return(arg1-arg2)
       elsif id=6 then
         --add
         return(arg1+arg2)
       elsif id=7 then
         --xor
         return(xor_bits(arg1,arg2))
       elsif id=8 then
         --or
         return(or_bits(arg1,arg2))
       elsif id=9 then
         --and
         return(and_bits(arg1,arg2))
       elsif id=10 then
         --equal
         return(abs(arg1=arg2)*-1)
       elsif id=11 then
         --notequal
         return(abs(arg1!=arg2)*-1)
       elsif id=12 then
         --lessthan
         return(abs(arg1<arg2)*-1)
       elsif id=13 then
         --greaterthan
         return(abs(arg1>arg2)*-1)
       elsif id=14 then
         --lessthanorequalto
         return(abs(arg1<=arg2)*-1)
       elsif id=15 then
         --greaterthanorequalto
         return(abs(arg1>=arg2)*-1)
       end if
    end if
  end if
  return({})
end function

---------------------------------------------------------------------------

--goes through a script simplifying expressions that always have the same value
function optimize_script(sequence tree,sequence vars)
  object arg
  for i=1 to length(tree) do
    arg=optimized_arg(tree[i],vars)
    if integer(arg) then
      tree[i][TREE_TRUNK][CMD_TEXT]=sprintf("%d",arg)
      tree[i][TREE_BRANCHES]={}
    end if
    if length(tree[i][TREE_BRANCHES]) then
      --if there are sub-arguments, recurse
      tree[i][TREE_BRANCHES]=optimize_script(tree[i][TREE_BRANCHES],vars)
    end if
  end for
  return(tree)  
end function

---------------------------------------------------------------------------

procedure warn_unused_locals(sequence vars)
  for i=1 to length(vars) do
    if not find(vars[i][CMD_TEXT],used_locals) then
      src_warn(sprintf("local variable "&COLYEL&"%s"&COLRED&" is never used",{vars[i][CMD_TEXT]}),vars[i][CMD_LINE])
    end if
  end for
end procedure

---------------------------------------------------------------------------

procedure warn_unused_globals()
  integer at
  for i=1 to length(global_list[PAIR_NUM]) do
    at=find(global_list[PAIR_NAME][i],used_globals)
    if not at then
      src_warn(sprintf("global variable "&COLYEL&"%s"&COLRED&" ID "&COLYEL&"%d"&COLRED&" is never used",{global_list[PAIR_NAME][i],global_list[PAIR_NUM][i]}),global_list[GLB_LINE][i])
    end if
  end for
end procedure

---------------------------------------------------------------------------

procedure compile_a_script(integer id,sequence name_data,sequence arg_data,sequence script_data)
  sequence script_tree
  sequence local_vars
  sequence binary
  current_script=name_data[CMD_TEXT]
  local_vars=arg_data --start with argument names (so we can check for conflicts)
  local_vars=gather_local_vars(local_vars,script_data)
  used_locals={}
  script_tree=compile_commands(script_data,local_vars)
  script_tree=convert_operators(script_tree)
  script_tree=normalize_flow_control(script_tree,local_vars)
  script_tree=normalize_arguments(script_tree,local_vars)
  script_tree=collapse_floaty_brackets(script_tree)
  if not fast_mode then
    script_tree=optimize_script(script_tree,local_vars)
    script_tree=sanity_check(script_tree,local_vars,"")
    warn_unused_locals(local_vars)
  end if
  binary=binary_compile(id,script_tree,local_vars)
  all_scripts=append(all_scripts,{
     id                   --id
    ,name_data[CMD_TEXT]  --name
    ,name_data[CMD_LINE]  --source line
    ,script_tree
    ,local_vars
    ,binary               --compiled data to go into the HSX lumps
  })

  current_script=""
end procedure

---------------------------------------------------------------------------

procedure compile_each_script()
  integer at
  sequence count
  count=repeat(0,length(file_list))
  color_print("compiling scripts",{})
  for i=1 to length(script_cmd) do
    at=find(script_cmd[i][1][CMD_TEXT],column(script_list,PAIR_NAME))
    if at then
      --color_print("%s\n",{script_cmd[i][1][CMD_TEXT]})
      if length(script_cmd[i][2]) != length(script_list[at][FUNC_ARGS]) then
        src_error(
           sprintf(
             "script "&COLYEL&"%s"&COLRED&" has %d arguments named, but has %d arguments in its declaration"
             ,{script_cmd[i][1][CMD_TEXT],length(script_cmd[i][2]),length(script_list[at][FUNC_ARGS])}
           )
           ,script_cmd[i][1][CMD_LINE]
        )
      else
        compile_a_script(
           script_list[at][PAIR_NUM] --ID
          ,script_cmd[i][1]          --Name
          ,script_cmd[i][2]          --argnames
          ,script_cmd[i][3]          --data
        )
        count[source[script_cmd[i][1][CMD_LINE]][SRC_FILE]]+=1
      end if
    else
      src_error(sprintf("script "&COLYEL&"%s"&COLRED&" is not defined",{script_cmd[i][1][CMD_TEXT]}),script_cmd[i][1][CMD_LINE])  
    end if
    color_print(".",{})
  end for
  color_print("\n",{})
  if not fast_mode then
    warn_unused_globals()
  end if
  for i=1 to length(count) do
    if count[i] then
      wrap_print("compiled %d scripts from "&COLBWHI&"%s"&COLWHI&"\n",{count[i],file_list[i]})
    end if
  end for
end procedure

---------------------------------------------------------------------------

function generate_scripts_dot_txt()
  sequence result
  result=""
  for i=1 to length(script_list) do
    result&=sprintf("%s\r\n%d\r\n%d\r\n",{script_list[i][PAIR_NAME],script_list[i][PAIR_NUM],length(script_list[i][FUNC_ARGS])})
    for j=1 to length(script_list[i][FUNC_ARGS]) do
      result&=sprintf("%d\r\n",{script_list[i][FUNC_ARGS][j]})
    end for
  end for
  return(result)
end function

---------------------------------------------------------------------------

procedure write_output_file()
  integer fh
  if length(all_scripts) then
    fh=open(dest_file,"wb")
    if fh!=-1 then
      wrap_print("writing output file "&COLBWHI&"%s"&COLWHI&"\n",{dest_file})
      --write header and version
      if write_lump(fh,"HS","HamsterSpeak"&output_word(COMPILER_VERSION))=false then
        simple_error("unable to write header")
      end if
      --write script index
      if write_lump(fh,"scripts.txt",generate_scripts_dot_txt())=false then
        simple_error("unable to write script index")
      end if
      --write each script
      for i=1 to length(all_scripts) do
        if write_lump(fh,sprintf("%d.hsx",{all_scripts[i][1]}),all_scripts[i][6])=false then
          simple_error(sprintf("unable to write script "&COLYEL&"%s"&COLRED,{all_scripts[i][2]}))
        end if
      end for
      close(fh)
    else
      simple_error(sprintf("attempt to open"&COLYEL&"%s"&COLRED&" failed",{dest_file}))  
    end if
  else  
    color_print("no scripts to output\n",{})  
  end if
end procedure

---------------------------------------------------------------------------

init()
load_source(source_file,"reading")
show_source_info()
split_commands()
parse_for_constants()
parse_top_level()
compile_each_script()
dump_debug_report()
write_output_file()

color_print("done (%g seconds)\n",{time()-start_time})
opt_wait_for_key()
if was_warnings = true then
  abort(2)
end if

