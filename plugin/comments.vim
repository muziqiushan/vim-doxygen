" *********************************************************************************************
" comments.vim  
" *********************************************************************************************
" Description : Global Plugin to comment and un-comment different 
"               source files in both normal and visual <Shift-V> mode
" Last Change : 26th April, 2006
" Created By  : Jasmeet Singh Anand <jasanand@hotmail.com>
" Version     : 2.2
" Usage       : For VIM 6 -
"               Stick this file in your ~/.vim/plugin directory or 
"               in some other 'plugin' directory that is in your runtime path
"               For VIM 5 -
"               Stick this file somewhere and 'source <path>/comments.vim' it from
"               your ~/.vimrc file
" Note        : I have provided the following key mappings
"               To comment    <Ctrl-C> in both normal and visual <Shift-V> range select mode
"               To un-comment <Ctrl-X> in both normal and visual <Shift-V> range select mode
"               These can be changed based on user's likings or usage
" Contact     : For any comments or bug fixes email me at <jasanand@hotmail.com>
" *********************************************************************************************
 "Modification:
" *********************************************************************************************
" Jasmeet Anand  26th April, 2006 v2.0 
" Fixed C commenting where a single line already had previous comments.
" int x=0; /*this is an x value*/
" Still working on situations like
" Issue A:
" 1 int x=0; /*this
" 2           is 
" 3           an
" 4           x
" 5           value*/
" *********************************************************************************************
" Jasmeet Anand  26th April, 2006 v2.1
" Provided more granule checking for C Code but still working on Issue A
" *********************************************************************************************
" Jasmeet Anand  27th April, 2006 v2.2
" Fixed another minor C code commenting bug
" Provided for .csh, .php, .php2 and .php3 support
" Resolved Issue A with the following logic 
" 1 /* int x=0; */ /*this*/
" 2           /*is*/ 
" 3           /*an*/
" 4           /*x*/
" 5           /*value*/
" However care should be taken when un-commenting it
" in order to retain the previous comments  
" *********************************************************************************************
" Jasmeet Anand  1st May 2006 v2.3
" Provided [:blank:] to accomodate for space and tab characters
" *********************************************************************************************
" Jasmeet Anand  1st May 2006 v2.4
" Provided support for .css as advised by Willem Peter
" *********************************************************************************************
" Jasmeet Anand  2nd May 2006 v2.5
" Removed auto-indenting for .sql, .sh and normal files when un-commenting
" *********************************************************************************************
" Jasmeet Anand  5th June 2006 v2.6
" Added support for .html, .xml, .xthml, .htm, .vim, .vimrc
" files as provided by Jeff Buttars
" *********************************************************************************************
" Smolyar "Rastafarra" Denis 7th June 2007 v2.7
" Added support for .tex
" *********************************************************************************************
" Jasmeet Anand  5th June 2006 v2.8
" Added support for Fortran .f, .F, .f90, .F90, .f95, .F95
" files as provided by Albert Farres
" *********************************************************************************************
" Jasmeet Anand  8th March 2008 v2.9
" Added support for ML, Caml, OCaml .ml, mli, PHP (v.4) .php4, PHP (v.5) .php5
" files as provided by Denis Smolyar
" Added support for noweb (requires only a small enhancement to the tex type)
" as provided by Meik "fuller" Te適er
" Added support for vhdl files provided by Trond Danielsen
" *********************************************************************************************
" Jasmeet Anand 20 th March 2008 v2.10
" Bug fixes for php files as pointed by rastafarra
" *********************************************************************************************
" Jasmeet Anand 29th November 2008 v2.11
" Added support for haskel
" files as provided by Nicolas Martyanoff
" File Format changed to UNIX
" *********************************************************************************************
" Jasmeet Anand 11th January 2009 v2.12
" bug fix for haskel files as prpvided by Jean-Marie
"

" Exit if already loaded
if exists("loaded_comments_plugin")
  finish
endif

let loaded_comments_plugin="v2.10"

" key-mappings your own comments
map <F2> :call <SID>GenDoc()<CR>
map <F3> :call <SID>ValComment()<CR>
map <F4> :call <SID>ValComment1()<CR>
autocmd BufNewFile *.h,*.cpp,*.c,*.cc,*.java,*.pl :call <SID>InsertFormat()
autocmd BufNewFile *.php :call <SID>InsertPHPHead()
autocmd BufNewFile *h :call <SID>InsertHeadFormat()

let g:KeyWordsPrefixToErase = "inline,extern,\"C\",virtual,static,"
let g:TokenNotInFunDeclare = "#,{,},;,"
let g:MAX_PARAM_LINE = 12 

function! <SID>DateInsert()
	$read !date /T
endfunction

function! <SID>OpenNew()
	let s = input("input file name: ")
	execute  ":n"." ".s
endfunction


" Function : GetNthItemFromList (PRIVATE)
" Purpose  : Support reading items from a comma seperated list
"            Used to iterate all the extensions in an extension spec
"            Used to iterate all path prefixes
" Args     : list -- the list (extension spec, file paths) to iterate
"            n -- the extension to get
" Returns  : the nth item (extension, path) from the list (extension 
"            spec), or "" for failure
" Author   : Michael Sharpe <feline@irendi.com>
" History  : Renamed from GetNthExtensionFromSpec to GetNthItemFromList
"            to reflect a more generic use of this function. -- Bindu
function! <SID>GetNthItemFromList(list, n, sep) 
   let itemStart = 0
   let itemEnd = -1
   let pos = 0
   let item = ""
   let i = 0
   while (i != a:n)
      let itemStart = itemEnd + 1
      let itemEnd = match(a:list, a:sep, itemStart)
      let i = i + 1
      if (itemEnd == -1)
         if (i == a:n)
            let itemEnd = strlen(a:list)
         endif
         break
      endif
   endwhile 
   if (itemEnd != -1) 
      let item = strpart(a:list, itemStart, itemEnd - itemStart)
   endif
   return item 
endfunction


function! DebugStr(s)
	return
	echo a:s
endfunction

function! <SID>MatchInList(s, l)
	let i=1
	let kw = <SID>GetNthItemFromList(a:l, i, ",")
	while (strlen(kw)>0)
		call DebugStr("MatchInList Nth ".kw)
		if (match(a:s, kw)!=-1)
			return i
		endif
		let i = i+1
		let kw = <SID>GetNthItemFromList(a:l, i, ",")
	endwhile
	return -1
endfunction


function! <SID>ErasePrefix(s)
	let i=1 
	let ts = substitute(a:s, '^\s\+', "", "")  		
	let kw = <SID>GetNthItemFromList(g:KeyWordsPrefixToErase, i, ",")

	while (strlen(kw)>0)
		call  DebugStr("ErasePrefix Nth ".kw)
		let ts = substitute(ts, '^'.kw, "", "")  	
		let ts = substitute(ts, '^\s\+', "", "")  		
		let i = i+1
		let kw = <SID>GetNthItemFromList(g:KeyWordsPrefixToErase, i, ",")
	endwhile
	return ts
endfunction

function! <SID>GetCurFunction()
	let cur_line_no = line(".")
	let max_line_no = line("$")
	let fun_str = ""
	let raw_fun_str = ""
	let fun_line_count=0

	while (fun_line_count<g:MAX_PARAM_LINE && cur_line_no<=max_line_no)
		let cur_line = getline(cur_line_no)
		let cur_line_no = cur_line_no + 1
		let fun_line_count = fun_line_count+1
		if ( strlen(cur_line)>0 )
			let raw_fun_str = raw_fun_str . cur_line . " \n"
		endif
	endwhile

	call DebugStr("raw_fun_str ".raw_fun_str)

	let idx =0
	let fun_over=0
	let raw_fun_str_len = strlen(raw_fun_str)
	let quote=0
	while (idx<raw_fun_str_len && fun_over==0)
		let cur_char = raw_fun_str[idx]
		"exec DebugStr("cur_char:".cur_char)
		let idx = idx+1

		if (cur_char=="/")
			"check next char
			let next_char = raw_fun_str[idx]
			"exec DebugStr("next_char:".next_char)
					
			if (next_char=="/") 
				"find /n
				let new_line_pos = match(raw_fun_str, "\n", idx)
				if (new_line_pos==-1)
					"echo "error format near //"
					return ""	
				endif
				let idx = new_line_pos+1
				continue
			elseif (next_char=="*")
				let idx = idx+1
				let right_pos = match(raw_fun_str, "*/", idx)
				if (right_pos==-1)
					 "error format near /*"
					return ""	
				endif
				let idx = right_pos+2
				continue	
			else
				 "error format near /"
				return ""
			endif
		endif

		if (cur_char=="(")
			let quote = quote+1
		endif

		if (cur_char==")")
			let quote = quote-1
			if (quote==0)
				let fun_over=1
			endif
		endif

		if (cur_char!="\n")
			let fun_str = fun_str . cur_char
		endif
		"exec DebugStr(fun_str)	
	endwhile


	if (fun_over==1)
		if ( <SID>MatchInList(fun_str, g:TokenNotInFunDeclare)==-1)
			return <SID>ErasePrefix(fun_str)
		endif
	endif

	 "can't find function format!"
	return ""
	
endfunction
	

"pass in : ' int a[23] '
"return  : "int[23],a"
function! <SID>GetSingleParamInfo(s, isparam)
	" unsigned int * ass [1][2]
	
	let single_param = a:s
	call DebugStr("single param ".single_param)
	

	if (a:isparam)
		" erase default value , eg int a = 10
		let single_param = substitute(single_param, '=\(.\+\)', "", "g")  
	endif
	
	" erase ending blank
	let single_param = substitute(single_param, '\(\s\+\)$' , "", "")
	
	" erase blank before '['
	let single_param = substitute(single_param, '\(\s\+\)[', "[", "g")  
	"exec DebugStr(single_param)

	let single_param = substitute(single_param, '^\s\+', "", "")  
	"exec DebugStr(single_param)

	" erase blank before '*' | '&'
	let single_param = substitute(single_param, '\(\s\+\)\*', "*", "g")  
	let single_param = substitute(single_param, '\(\s\+\)&', "\\&", "g")  
	"exec DebugStr(single_param)

	" insert blank to * (&), eg int *i => int * i
	let single_param = substitute(single_param, '\(\*\+\)', "\\0 ", "")  
	let single_param = substitute(single_param, '\(&\+\)', "\\0 ", "")  
	
	call DebugStr("single param processed:" .single_param. "END")
	"call DebugStr("single param processed:" .single_param)

	"let match_res = matchlist(single_param, '\(.\+\)\s\+\(\S\+\)')
	"'^\s/*\(.\+\)\s\+\(.\+\)\s/*$')     
	"exec DebugStr(match_res)
	"let type = match_res[1]
	"let name = match_res[2]
	
	let pos = match(single_param, '\S\+$')
	
	if (pos==-1)
		call DebugStr("pos==-1")
		return ""
	endif

	let type = strpart(single_param, 0, pos-1)
	let name = strpart(single_param, pos)
	
	" type can be "", eg c++ constructor
	if (strlen(name)==0)
		call DebugStr("strlen(name)==0")
		return ""
	endif
	
	
"	if (a:isparam && strlen(type)==0)
"		call DebugStr("a:isparam && strlen(type)==0")
"		return ""
"	endif	

	let bpos = match(name, "[")
	if (bpos!=-1)
		let type = type . strpart(name, bpos)
		let name = strpart(name, 0, bpos)
	endif

	"trim final string
	let type = substitute(type, '\(\s\+\)$' , "", "")
	let name = substitute(name, '\(\s\+\)$' , "", "")
	
	let ret = type.",". name.","
	call DebugStr("RET GetSingleParamInfo " . ret)	
	return ret
endfunction


" format are "type,name,"
"  begin with function name and then "\n" then followed by param
function! <SID>GetFunctionInfo(fun_str)
	let param_start = match(a:fun_str, "(")
	let fun_info = ""
	
	if (param_start==-1) 
		  "can't find '(' in function "
		return ""
	endif

	let fun_name_part = strpart(a:fun_str, 0, param_start)
	let param_start = param_start + 1
	let param_len   = strlen(a:fun_str) - param_start -1
	let fun_param_part = strpart(a:fun_str, param_start, param_len)
       	
	call DebugStr("FUN :".fun_name_part)
	call DebugStr("PARAM :".fun_param_part)
	
	"analysis fun_name_part
	let temp = <SID>GetSingleParamInfo(fun_name_part, 0)
	if (strlen(temp)==0)
		 "function name analysis failed!!"
		return ""
	endif
	let fun_info = fun_info . temp

	"analysis fun_param_part
	let cur_idx = 0
	let comma_idx = match(fun_param_part, "," , cur_idx)
	call DebugStr("comma_idx :".comma_idx)
	while (comma_idx!=-1) 
		"for earch param
		let single_param = strpart(fun_param_part, cur_idx, comma_idx - cur_idx)	
		let temp = <SID>GetSingleParamInfo(single_param, 1)
		if (strlen(temp)>0)
			let fun_info = fun_info.temp
			let cur_idx = comma_idx + 1
			let comma_idx = match(fun_param_part, "," , cur_idx)
		else
			echo "function param analysis failed!!"
			return ""
		endif
	endwhile
       	
	"last param
	let single_param = strpart(fun_param_part, cur_idx)
    echom single_param

	if (match(single_param, '\S')>=0)
		let temp = <SID>GetSingleParamInfo(single_param, 1)
		if (strlen(temp)>0)
			let fun_info = fun_info.temp
		"else 
			"echo "function param analysis failed!!"
		"	return ""
		endif

	endif	
	
	return fun_info
endfunction


function! <SID>GetUserName()
	let home = $HOME
	let user = $VIM_USER
	return user
endfunction

function! <SID>GetDate()
	"windows
	let date = system("date /T")
	if (v:shell_error!=0)
		"linux
		let date = system("date +\"%Y/%m/%d %H:%M:%S\" ")
	endif

	if (date[strlen(date)-1]=="\n")
		let date = strpart(date, 0, strlen(date)-1)
	endif
	return date
endfunction

function! <SID>GetYear()
	return strftime("%Y")
endfunction

function! <SID>GetLastModifiedDate()
	let fname = expand("%")
	let	date = getftime(fname)
	let strDate = strftime("%c", date)
	return strDate
endfunction	
"     /**
"      * @brief This is a function called Test
"      *
"      * Details about Test
"      * @param a an integer argument.
"      * @param s a constant character pointer.
"      * @return The test results
"      * @author sprite 
"      * @date 2006-07:
"      * @version 1.0
"      * @todo 
"      */

function! <SID>GetDoxygenStyleDoc(fun_info, leading_blank)

	let doc=""
	let idx=1
	let doc  = a:leading_blank."/**\n"
	
	let ret_type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	let fun_name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	if (strlen(fun_name)==0)
		return ""
	endif	

	"let doc = doc . a:leading_blank." * @brief brief description about ".fun_name."\n"
	let doc = doc . a:leading_blank." * @brief \n"
	let doc = doc. a:leading_blank." *\n"
	"let doc = doc . a:leading_blank." * detail description about ".fun_name."\n"
	
	"gen function name part
	let type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	let name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1

	"gen param part
	while(strlen(name)>0)

		let doc = doc . a:leading_blank." * @param [in/out] ".name." "."  : ".type.  "\n"
		let type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
		let idx = idx + 1
		let name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
		let idx = idx + 1
	endwhile

	if (! (strlen(type)==0 && strlen(name)==0) )
		return ""
	endif

	"ret
	if (strlen(ret_type)>0) 
		let doc = doc . a:leading_blank." * @return  ".ret_type. " \n"
		let doc = doc . a:leading_blank." * @retval  "." \n"
	endif

	"other
  let doc = doc . a:leading_blank." * @see \n"
  let doc = doc . a:leading_blank." * @note \n"
	let doc = doc . a:leading_blank." * @author ".<SID>GetUserName()."\n" 
  let doc = doc . a:leading_blank." * @date ".<SID>GetDate()."\n"
	"let doc = doc . a:leading_blank." * @version 1.0.0 \n" 
	"let doc = doc . a:leading_blank." * @todo \n" 

	" end
	let doc = doc . a:leading_blank."**/\n"
	return doc
endfunction
function! <SID>GetFileName()
	let fname = expand("%")
	return fname
endfunction
function! <SID>GetVer()
  let fname = system("cvs st ".<SID>GetFileName()." |grep -o \"Sticky Tag:.*\"|awk -F'[\t\t]' '{print $3}' ")
  if (strlen(matchstr(fname, "PD_BL")) <= 0)
	  let fname = system("cvs st ".<SID>GetFileName()."|grep -o \"Working revision:.*\"|awk -F'[\t]' '{print $2}' ")
	  if ( strlen(fname) > 6)
		  let fname = "1.0"
	  endif
  endif
	if (fname[strlen(fname)-1]=="\n")
		let fname = strpart(fname,0,strlen(fname)-1)
	endif
	return fname
endfunction

function! <SID>GetEmail()
  return $VIM_USER."@baidu.com"
endfunction

function! <SID>GetDoxFileHeader(leading_blank)

	let doc = ""
  let doc = doc. a:leading_blank."/***************************************************************************\n"
	let doc = doc. a:leading_blank." * \n"
  let doc = doc. a:leading_blank." * Copyright (c) ".<SID>GetYear()." Baidu.com, Inc. All Rights Reserved\n"
  let doc = doc. a:leading_blank." * \n"
  let doc = doc. a:leading_blank." **************************************************************************/\n"
  let doc = doc. a:leading_blank." \n \n \n"
  let doc = doc. a:leading_blank."/**\n"
	let doc = doc. a:leading_blank." * @file ".<SID>GetFileName()."\n"
	let doc = doc. a:leading_blank." * @author ".<SID>GetUserName()."(".<SID>GetEmail().")\n"
	let doc = doc. a:leading_blank." * @date ".<SID>GetDate()."\n"
	let doc = doc. a:leading_blank." * @brief \n"
	let doc = doc. a:leading_blank." *  \n"
	let doc = doc. a:leading_blank." **/\n"
    call append(line('$'), "/* vim: set expandtab ts=4 sw=4 sts=4 tw=80: */")
    return doc


endfunction

function! <SID>GetDoxMainpage(leading_blank)

	let doc = ""
	let doc = doc.a:leading_blank."/**\n"
	let doc = doc.a:leading_blank."* @mainpage xxx介绍及使用方法 \n"
	let doc = doc.a:leading_blank."* \<h2>概述</h2>\n"
	let doc = doc.a:leading_blank."* <p>xxxxxxxxxxx</p>\n"
	let doc = doc.a:leading_blank."* <ol></ol>\n"
	let doc = doc.a:leading_blank."* <h2>使用方法</h2>\n"
	let doc = doc.a:leading_blank."* <hr>\n"
	let doc = doc.a:leading_blank."* <p>问题请发送<a href=\"mailto:".<SID>GetEmail()."?subject=[dilib]\">.".<SID>GetEmail()."</a></p>\n"
	let doc = doc. a:leading_blank."*/\n"
	return doc
endfunction

function! <SID>GetDoxClass(leading_blank)
	let doc = ""
	let doc = doc.a:leading_blank."/**\n"
	let doc = doc. a:leading_blank."* @brief short description\n"
	let doc = doc. a:leading_blank."*   detail description\n"
	let doc = doc. a:leading_blank."*  \n"
	let doc = doc. a:leading_blank."*/\n"
	return doc
endfunction
function! <SID>GetDoxGroup(leading_blank)
	let doc = ""
	let doc = doc.a:leading_blank."/** @addtogroup groupname\n"
	let doc = doc. a:leading_blank."*  \n"
	let doc = doc. a:leading_blank."* <ul>\n"
	let doc = doc. a:leading_blank."* <li> item1\n"
	let doc = doc. a:leading_blank."* 	<ol>\n"
	let doc = doc. a:leading_blank."* 	<li> subitem11\n"
	let doc = doc. a:leading_blank."* 	<li> subitem12\n"
	let doc = doc. a:leading_blank."* 	</ol>\n"
	let doc = doc. a:leading_blank."* <li> item2\n"
	let doc = doc. a:leading_blank."* 	<ol>\n"
	let doc = doc. a:leading_blank."* 	<li> subitem21\n"
	let doc = doc. a:leading_blank."* 	<li> subitem22\n"
	let doc = doc. a:leading_blank."* 	</ol>\n"
	let doc = doc. a:leading_blank."* </ul>\n"
	let doc = doc. a:leading_blank."* @{\n"
	let doc = doc. a:leading_blank."*/\n"
	let doc = doc. a:leading_blank." \n"
	let doc = doc. a:leading_blank."/** @} */\n"
	return doc
endfunction


function! <SID>GenDoc()
	let l:synopsisLine=line(".")+1
    let l:synopsisCol=col(".")

	let cur_line = line(".")
	let first_line = getline(cur_line)
	let leading_blank = ""

	if (strlen(matchstr(first_line, '\S'))==0)
		return
	else 
		let leading_blank = matchstr(first_line, '\(\s*\)')
	endif 

	let fun_str = <SID>GetCurFunction()
	if (strlen(fun_str)==0) 
		return
	endif

	call DebugStr("FUN_BODY ".fun_str)

	let fun_info = <SID>GetFunctionInfo(fun_str)
	call DebugStr("fun_info ".fun_info."END")
	
	let doc = <SID>GetDoxygenStyleDoc(fun_info, leading_blank)

	if (strlen(doc)>0)
		let idx =1
		let li = <SID>GetNthItemFromList(doc, idx, "\n")
		while (strlen(li)>0)
			call append( cur_line-1, li.expand("<CR>"))
			let idx = idx + 1
			let cur_line = cur_line + 1
			let li = <SID>GetNthItemFromList(doc, idx, "\n")
		endwhile
	endif
    exec l:synopsisLine
    exec "normal " . l:synopsisCol . "|"
    startinsert!

endfunction
function! <SID>GetDoxFH(type)
	let l:synopsisLine=line(".")+1
    let l:synopsisCol=col(".")

	let cur_line = line(".")
    let first_line = getline(cur_line)
	let leading_blank = matchstr(first_line, '\(\s*\)')
	if (a:type == 1) 

		let doc = <SID>GetDoxFileHeader(leading_blank)
	elseif (a:type == 0)
		let doc = <SID>GetDoxMainpage(leading_blank)
	elseif (a:type == 2)
		let doc = <SID>GetDoxClass(leading_blank)
		if (strlen(matchstr(first_line, '\S'))==0)
			return
		endif
	elseif (a:type == 3)
		let doc = <SID>GetDoxGroup(leading_blank)
	endif

	if (strlen(doc)>0)
		let idx =1
		let li = <SID>GetNthItemFromList(doc, idx, "\n")
		while (strlen(li)>0)
			call append( cur_line-1, li.expand("<CR>"))
			let idx = idx + 1
			let cur_line = cur_line + 1
			let li = <SID>GetNthItemFromList(doc, idx, "\n")
		endwhile
	endif

	normal 17g
    "exec l:synopsisLine
    "exec "normal " . l:synopsisLine . "|"
    startinsert!

endfunction

function! <SID>ValComment()
  
  call cursor(line('.'), col('$'))
  exec "normal! a\t\t  /**<        */"
  call cursor(line('.'), col('$')-9)
  startinsert
  
endfunction

function! <SID>ValComment1()
	if (&filetype == 'vim')
		normal O" 
	elseif (&filetype == 'sh')
		normal 0#
	elseif (&filetype == 'tpl')
		normal 0<!---->
	elseif (strlen(matchstr(&filetype,'^\(php\)\|^\(c\)')) >0)
		normal! O// 
	endif
		call cursor(line('.'), col('$'))
		call cursor(line('.'), 1)
  startinsert!
endfunction


function! <SID>InsertPHPHead()

  call append(0, "<?php")
  call <SID>GetDoxFH(1)
  let idx = 5 
  while (idx > 0)
    call append(line('$') - 1, "")
    let idx = idx - 1
  endwhile

  "call append(line('$'), "?>")

endfunction

function! <SID>InsertFormat()
  call <SID>GetDoxFH(1)
  let idx = 20
  while (idx > 0)
    call append(line('$') - 1, "")
    let idx = idx - 1
  endwhile

  call cursor(15, 11)
endfunction

function! <SID>InsertHeadFormat()
  let s = toupper(<SID>GetFileName())
  let s = substitute(s, "[\.]", "_", "g")
  call append(19, "#ifndef  __". s. "_")
  call append(20, "#define  __". s. "_")
  call append(line('$')-2, "#endif  //__". s. "_")
endfunction
