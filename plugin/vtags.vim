" File: vtags.vim
" Last Change: 2002 Jul 11
" Maintainer: Little Dragon <littledragon@altern.org>
" Version: 0.1.1
"
" Usage:
" While in a supported file, press <F12> to generate the tags.
"
" Recommendations:
" Use a global file to store tags. I have set tags=~/.vimtags
" The script automatically sorts the file alphabetically, so, selecting
" tags should be fast, no matter how many there are.

let g:DefaultContext = "none"
let g:LastContext = g:DefaultContext

function! ParseBuffer()
	let s:TagsDef = ""
	while (SplitString(g:vtags_lang, ',', 'VT_Lang'))
		if (tolower(&filetype) == tolower(g:VT_Lang))
			if (!VerifyLanguageDefinition(g:VT_Lang))
				break
			endif
			let LastLine = line('$')
			let LineCount = 0
			while (LineCount < LastLine)
				let LineCount = LineCount + 1
				let CurrentLine = getline(LineCount)
				while (SplitString(g:vtags_{g:VT_Lang}_obj, ',', 'VT_Obj'))
					if (CurrentLine =~ g:vtags_{g:VT_Lang}_{g:VT_Obj}_regexp)
						let EnabledVar = "g:vtags_" . g:VT_Lang . "_" . g:VT_Obj . "_enable"
						if (exists(EnabledVar) ? {EnabledVar} : 1)
							let VT_Regexp = '^.*' . g:vtags_{g:VT_Lang}_{g:VT_Obj}_regexp . '.*$'
							let VT_Name = substitute(CurrentLine, VT_Regexp, '\1', '')
							if (s:TagsDef !~ '\<' . VT_Name . '\>')
								let s:TagsDef = s:TagsDef . " " . VT_Name
								let VT_TagExpand = ParseTag(g:vtags_{g:VT_Lang}_{g:VT_Obj}_tag, LineCount)
								let VT_Tag = substitute(CurrentLine, VT_Regexp, VT_TagExpand, '')
								let VT_Context = VT_Name
								let FlagsVar = "g:vtags_" . g:VT_Lang . "_" . g:VT_Obj . "_flags"
								let Flags = exists(FlagsVar) ? {FlagsVar} : ""
								if ((strlen(Flags) > 0 && Flags !~ 'c') || !strlen(Flags) > 0)
									let g:LastContext = g:VT_Obj . ' ' . VT_Context
								endif
								call ProcessTag(VT_Tag)
							endif
						endif
					endif
				endwhile
			endwhile
		endif
	endwhile
	unlet s:TagsDef
	call WriteTags()
endfunction

function! ParseTag(p_tag, p_line)
	let retv = a:p_tag
	let retv = substitute(retv, '%F', escape(escape(expand('%:p'), " \\"), "\\"), '')
	let retv = substitute(retv, '%L', getline(a:p_line), '')
	let retv = substitute(retv, '%C', g:LastContext, '')
	let retv = substitute(retv, '%N', a:p_line, '')
	return retv
endfunction

function! GetTagsFile()
	return &tags =~ '[ ,]' ? matchstr(&tags, '^.\{-}[ ,]') : &tags
endfunction

function! GetDefinedTags()
	let retv = ""
	if (filereadable(GetTagsFile()))
		let g:CurrentBuffer = bufnr('%')
		if (!exists("g:TagsBuffer"))
			let g:TagsBuffer = CreateBuffer("open", GetTagsFile())
		endif
		execute 'silent sbuffer ' . g:TagsBuffer
		let LastLine = line('$')
		let LineCount = 0
		while (LineCount < LastLine)
			let LineCount = LineCount + 1
			let CurrentLine = getline(LineCount)
			if (CurrentLine =~ '^\w')
				let Tag = substitute(CurrentLine, '^\(\w\{-}\)\t.*$', '\1', '')
				let retv = retv . Tag . "\t"
			endif
		endwhile
		silent hide
	endif
	return retv
endfunction

function! TagDefined(p_tag)
	let retv = 0
	let tag = a:p_tag
	let tab_match = match(tag, "\t")
	if (tab_match > -1)
		let tag = strpart(tag, 0, tab_match)
	endif
	while (SplitString(g:DefinedTags, "\t", '_TAG'))
		if (tag == g:_TAG)
			let retv = 1
		endif
	endwhile
	if (exists('g:_TAG')) | unlet g:_TAG | endif
	return retv
endfunction

function! ProcessTag(p_tag)
	if (exists("g:TagsBuffer"))
		execute 'silent sbuffer ' . g:TagsBuffer
		if (TagDefined(a:p_tag))
			call search('^' . strpart(a:p_tag, 0, match(a:p_tag, "\t")))
			call setline('.', a:p_tag)
		else
			call append('$', a:p_tag)
		endif
		silent hide
	endif
endfunction

function! WriteTags()
	if (exists("g:TagsBuffer"))
		execute 'silent sbuffer ' . g:TagsBuffer
		call SortR(0, line('$'), 'StrCmp')
		silent write!
		silent hide
	endif
endfunction

function! StrCmp(str1, str2)
	if (a:str1 < a:str2)
		return -1
	elseif (a:str1 > a:str2)
		return 1
	else
		return 0
	endif
endfunction

function! SortR(start, end, cmp)
	if (a:start >= a:end)
		return
	endif
	let partition = a:start - 1
	let middle = partition
	let partStr = getline((a:start + a:end) / 2)
	let i = a:start
	while (i <= a:end)
		let str = getline(i)
		execute "let result = " . a:cmp . "(str, partStr)"
		if (result <= 0)
			let partition = partition + 1
			if (result == 0)
				let middle = partition
			endif
			if (i != partition)
				let str2 = getline(partition)
				call setline(i, str2)
				call setline(partition, str)
			endif
		endif
		let i = i + 1
	endwhile
	if (middle != partition)
		let str = getline(middle)
		let str2 = getline(partition)
		call setline(middle, str2)
		call setline(partition, str)
	endif
	call SortR(a:start, partition - 1, a:cmp)
	call SortR(partition + 1, a:end, a:cmp)
endfunction

function! VerifyLanguageDefinition(p_lang)
	let LangOK = 0
	let Error = ""
	if (g:vtags_lang !~ '\<' . a:p_lang . '\>')
		let Error = "The vtags '" . a:p_lang . "' language definition does not exist"
	elseif (!exists('g:vtags_' . a:p_lang . '_obj') || !strlen(g:vtags_{a:p_lang}_obj) > 0)
		let Error = "The vtags '" . a:p_lang . "' language does not have an object definition"
	else
		while (SplitString(g:vtags_{a:p_lang}_obj, ',', 'V_Str'))
			let VarPrefix = 'g:vtags_' . a:p_lang . '_' . g:V_Str . '_'
			if (!exists(VarPrefix . "regexp"))
				let Error = "The vtags '" . a:p_lang . "' language does not have a regexp definition for the '" . g:V_Str . "' object"
				break
			elseif (!exists(VarPrefix . "tag"))
				let Error = "The vtags '" . a:p_lang . "' language does not have a tag definition for the '" . g:V_Str . "' object"
				break
			endif
		endwhile
		if (strlen(Error) == 0)
			let LangOK = 1
		endif
	endif
	if (!LangOK)
		echohl Error
		echo Error . '.'
		echohl None
	endif
	return LangOK
endfunction

function! SplitString(p_str, p_separator, p_var)
	" Clean up previous sessions if they exist.
	if (exists("g:SS_" . a:p_var . "_Finish"))
		if (exists('g:'.a:p_var)) | unlet {'g:'.a:p_var} | endif
		if (exists("g:SS_" . a:p_var . "_LastMatch")) | unlet g:SS_{a:p_var}_LastMatch | endif
		if (exists("g:SS_" . a:p_var . "_Done")) | unlet g:SS_{a:p_var}_Done | endif
		unlet g:SS_{a:p_var}_Finish
	endif
	if (strlen(a:p_str) == 0)
		return 0
	endif
	if (StrMatchNo(a:p_str, a:p_separator) == 0)
		if (exists('g:'.a:p_var))
			if (strlen({'g:'.a:p_var}) > 0)
				unlet {'g:'.a:p_var}
				let g:SS_{a:p_var}_Finish = 1
				return 0
			endif
		endif
		let {'g:'.a:p_var} = a:p_str
		return 1
	else
		if (!exists("g:SS_" . a:p_var . "_LastMatch"))
			let g:SS_{a:p_var}_LastMatch = 0
		endif
		let Match = match(a:p_str, a:p_separator, g:SS_{a:p_var}_LastMatch)
		let Length = Match - g:SS_{a:p_var}_LastMatch
		if (Match > -1)
			let {'g:'.a:p_var} = substitute(strpart(a:p_str, g:SS_{a:p_var}_LastMatch, Length), '^\s*\|\s*$', '', '')
			let g:SS_{a:p_var}_LastMatch = Match + 1
			return 1
		else
			if (!exists("g:SS_" . a:p_var . "_Done"))
				let Length = strlen(a:p_str) - g:SS_{a:p_var}_LastMatch
				let {'g:'.a:p_var} = substitute(strpart(a:p_str, g:SS_{a:p_var}_LastMatch, 100), '^\s*\|\s*$', '', '')
				let g:SS_{a:p_var}_Done = 1
				return 1
			else
				unlet {'g:'.a:p_var}
				unlet g:SS_{a:p_var}_LastMatch
				unlet g:SS_{a:p_var}_Done
				let g:SS_{a:p_var}_Finish = 1
				return 0
			endif
		endif
	endif
endfunction

function! StrMatchNo(haystack, needle)
	let LastMatch = match(a:haystack, a:needle)
	if LastMatch > -1
		let Result = 1
		while LastMatch > -1
			let LastMatch = match(a:haystack, a:needle, LastMatch+1)
			if LastMatch > -1
				let Result = Result + 1
			endif
		endwhile
	else
		let Result = 0
	endif
	return Result
endfunction

function! CreateBuffer(type, name)
	if (a:type == "new")
		exec "silent new " . a:name
	elseif (a:type == "open")
		exec "silent split " . a:name
	endif
	setlocal noswapfile
	setlocal bufhidden=hide
	setlocal nobuflisted
	setlocal nowrap
	setlocal autoread
	setlocal modifiable
	let buf_nr = bufnr('%')
	silent hide
	return buf_nr
endfunction

let g:DefinedTags = GetDefinedTags()

nmap <silent> <F12> :echo "Parsing..."<CR>:call ParseBuffer()<CR>:echo "Done."<CR>
