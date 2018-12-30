
set ts=4
set sts=4
set sw=4
set noexpandtab

set foldmethod=syntax
set foldlevel=1000

if !exists("*FlowDefinition")
	function! FlowDefinition(open_cmd)
		let c = "flow --find-definition ".expand("<cword>")." ".expand("%:p")
		let o = system(c)
		let path_line = split(split(o)[0], ":")
		if len(path_line) >= 2
			let vc = a:open_cmd." +".path_line[1]." ".path_line[0]
			:execute vc
		else 
			echo "Can't parse flow --find-definition output"
			echo o
		endif
	endfunction
endif

map <leader>fd :call FlowDefinition("edit")<CR>
map <leader>fD :call FlowDefinition("tabedit")<CR>


