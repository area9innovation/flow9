# utility makefile for my own use: don't try to use it 

DEFS =
#DEFS = -D typepos
HX = haxe  $(DEFS)
TEST_DIR = mytests
ROOT = ../..
FLOWOPT = -I $(TEST_DIR)
FLOW = neko flow.n
FULL = $(ROOT)/full/flow
#FLOW = ./FlowNeko2
#FLOWOPT =  $(DEFS)
#export FLOW_EDITOR := emacs
#export FLOW_DEBUG  := on

.PRECIOUS: %.asm %.debug %.inc.debug

run: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --bytecode main.bytecode $(TEST_DIR)/main.flow

runni: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT)  --compile main.bytecode $(TEST_DIR)/main.flow

run1: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --debuginfo main.debug.1 --bytecode main.bytecode $(TEST_DIR)/main.flow

debug: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --rebuild --incremental --debuginfo main.debug  --compile main.bytecode $(TEST_DIR)/main.flow

debug1: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --debuginfo main.debug.1 --compile main.bytecode $(TEST_DIR)/main.flow


debugs: debug debug1

finddef: flow.n
	$(FLOW) --emacs --find-definition 676 $(TEST_DIR)/main.flow

peg: compgram.flow
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --compile compgram.bytecode compgram.flow; exit 0

ref: flow.n
	$(FLOW) --rules flowref.rules --refactor flowref.flow --refactor-sfx ".ref"

refind: flow.n
	$(FLOW) --rules flowref.rules --refactor-files flowref.list  --refactor-sfx ".ref"

refall: flow.n
	$(FLOW) --rules flowref.rules --refactor-all flow --refactor-sfx ".ref"

compgram.flow: flow.n Makefile $(TEST_DIR)/main.flow lingo/compilepeg.flow
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --bytecode main.bytecode $(TEST_DIR)/main.flow; exit 0

#run: flow.n
#	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --bytecode $(TEST_DIR)/incremental.byte $(TEST_DIR)/main.flow

swf: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --opt-simple --tailcall-swf --swf $(FULL)/main.swf $(TEST_DIR)/main.flow

swfdasm:
	cd $(FULL); abcexport main.swf; rm -rf main-0; rabcdasm main-0.abc

swfdasm2:
	cd $(FULL); abcexport staining2.swf; rm -rf staining2-0; rabcdasm staining2-0.abc

req: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --incremental --dontrun --bytecode $(TEST_DIR)/incremental.byte $(TEST_DIR)/req.flow

rebuild: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT) --rebuild --disassembly --incremental --bytecode $(TEST_DIR)/incremental.byte $(TEST_DIR)/main.flow

runc: cleanobjs run

cleanobjs:
	rm -rf object/*

runu: flow.n
	$(FLOW) -I $(TEST_DIR) $(FLOWOPT)  --bytecode $(TEST_DIR)/incremental.byte $(TEST_DIR)/main.flow

commit:
	svn commit

flow.n: $(wildcard *.hx)
	$(HX) FlowNeko.hxml


build.n: $(dir *.hx)
	$(HX) Build.hxml

flash: $(dir *.hx)
	$(HX) FlowFlash.hxml

runner: $(dir *.hx)
	$(HX) FlowRunner.hxml

test: flow.n build.n flash runner

hxcpp:
	haxe FlowCpp.hxml

flowtest: flow.n
	time $(FLOW) -I flow $(FLOWOPT) --dontrun --bytecode $(ROOT)/TEST/wikibytes.byte flow/wikiwiki.flow 

flowtestswf: flow.n
	time $(FLOW) -I flow $(FLOWOPT) --dontrun --tailcall-swf --swf $(ROOT)/wikibytes.swf flow/wikiwiki.flow 
#>$(HOME)/TEST/flow.s

flowtestinc: flow.n
	$(FLOW) -I flow $(FLOWOPT)  --incremental --rebuild --dontrun --bytecode $(ROOT)/TEST/wikibytes.byteinc0 flow/wikiwiki.flow
	echo " " >> flow/sound.flow
	$(FLOW) -I flow $(FLOWOPT)  --incremental --dontrun --bytecode $(ROOT)/TEST/wikibytes.byteinc1 flow/wikiwiki.flow

%.asm: %.flow Makefile flow.n
	$(FLOW) -I flow $(FLOWOPT) --disassembly  --dontrun --bytecode $@.byte $<  | grep -v -w StructDef >$@

%.inc.asm: %.flow Makefile flow.n
	$(FLOW) -I flow $(FLOWOPT) --rebuild --incremental --disassembly --dontrun --bytecode $@.byte $<  | grep -v -w StructDef >$@

%.diff.asm: %.asm %.inc.asm
	diff -u $^ >$@

%.debug: %.flow Makefile flow.n
	$(FLOW) -I flow $(FLOWOPT)  --rebuild --incremental --dontrun --bytecode $@.byte $<  --debuginfo $@

%.inc.debug: %.flow Makefile flow.n
	$(FLOW) -I flow $(FLOWOPT) --incremental --dontrun --bytecode $@.byte $<  --debuginfo $@

%.diff.debug: %.debug %.inc.debug
	diff -u $^ >$@

rundebug: force $(TEST_DIR)/main.diff.debug

flowdebug: force flow/wikiwiki.diff.debug



#.PHONY: runasm flowasm gameasm

runasm: force $(TEST_DIR)/main.diff.asm

flowasm: flow/wikiwiki.diff.asm

gameasm: $(FULL)/labsmart/anatomy/ecg/game.diff.asm

smartasm: force smartbuilder/smartbuilder.diff.asm

force:
	rm -rf `find . -name \*.asm` `find . -name \*.debug`

flowclear:
	rm -f $(ROOT)/TEST/wiki*



flowtestall: flowclear flowtest flowtestinc flowtestswf

testb: flow.n build.n
	neko build.n --incremental

patch:
	svn diff >patch.diff

deploy: build.n flow.n
	rm -f $(FULL)/*.hx* $(FULL)/*.n; rm -rf $(FULL)/redefines; cp Makefile *.hx *.hxml $^ $(FULL); cp `find redefines -name \*.hx` $(FULL)/
	#rm -f $(FULL)/tests/incremental/*; cp tests/incremental/*.flow $(FULL)/tests/incremental/
	make -C $(FULL) test

deployflow:
	cp flow/*.flow $(FULL)/flow/

deploy2:
	cp FlowNeko2 $(FULL)

optimize: flow.n
	$(FLOW) --bytecode operformance.bytecode  --optimise  tests/performance.flow

DIR = flow
ARC = flow
arc:
	@echo archiving...
	@rm -f `find . -name \*~`
	@cd ..; rm -f $(ARC).tar.bz2; tar -c $(DIR)/*.hx $(DIR)/*.hxml $(DIR)/*.xml $(DIR)/Makefile | bzip2 >$(ARC).tar.bz2
	@ls -l ../$(ARC).tar.bz2
	@cp ../$(ARC).tar.bz2 ../$(ARC)-`date +%y-%b-%d-at-%H-%M`.tar.bz2

rebuildflow:
	rm -rf object/*
	rm -f *.bytecode
	time neko build.n --incremental

rebuildswf:
	#rm -rf object/*
	rm -f *.swf
	time neko build.n --force-swf
