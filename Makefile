# l2basic09 top-level build
#
# The NitrOS-9 tree is a copy of the nitros9project clones in $(MAINDIR),
# which stay pristine: recipes/export-main.sh writes each one's HEAD into
# build/main/src/ (again only when HEAD changes; recipes/README.md).  Its
# defs, pipe modules and stock Level 2 image are used (the image's own
# stock basic09 and runb are the reference programs in p1 and p4).
# Point NITROS9DIR at another checkout (and BASEIMG at its image) to
# override, e.g. the old-core joust tree.

PYTHON  ?= python3
BUILD   = build

MAINDIR    ?= $(HOME)/projects/wild/main
MAINSRC     = $(CURDIR)/build/main/src
NITROS9DIR ?= $(MAINSRC)/nitros9
MAME       ?= $(HOME)/projects/wild/mame/mame
BASEIMG    ?= $(CURDIR)/build/main/l2_wildbitsjr2.dsk
export NITROS9DIR MAME BASEIMG

# Export (or refresh) the copy before anything reads it
ifeq ($(NITROS9DIR),$(MAINSRC)/nitros9)
ifneq ($(filter-out clean,$(or $(MAKECMDGOALS),all)),)
$(foreach l,$(shell recipes/export-main.sh $(MAINDIR) $(MAINSRC) | tr ' ' '~'),$(info $(subst ~, ,$(l))))
ifneq ($(.SHELLSTATUS),0)
$(error recipes/export-main.sh failed)
endif
endif
endif
SRCDIR  = src
MODDIR  = modules
SCRIPT  = $(SRCDIR)/build-modular-basic09.py

SRCS = $(addprefix $(SRCDIR)/, comand.asm compil.asm binder.asm stmts.asm \
       exprsn.asm cnvio.asm defs b09defs b09type jmpdefs linkage editor pack mem)
DEPS = Makefile $(SCRIPT) $(SRCS)

AS = lwasm --no-warn=ifp1 --6309 --format=os9 \
     --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax \
     --includedir=$(NITROS9DIR)/defs
AFLAGS = -DNOS9VER= -DNOS9MAJ= -DNOS9MIN=

SUBS  = $(BUILD)/syscall $(BUILD)/inkey $(BUILD)/farmem
L2B09 = $(BUILD)/l2b09run $(BUILD)/l2b09ovl $(BUILD)/l2b09cc $(BUILD)/runb-l2
OS9DIR = os9
TOOLS = $(BUILD)/l2b09ctl $(BUILD)/basic09-l2 $(BUILD)/l2b09help $(BUILD)/basic09-l2.hlp

# Test platform (Wildbits Jr2 under MAME for now; see tools/emu-wildbits.sh)
PLATDIR  = $(NITROS9DIR)/recipes/wildbits/l2
PLATAS   = $(AS) -Dwildbits=1 -Djr2 -DNOS9VER=0 -DNOS9MAJ=0 -DNOS9MIN=0 \
           -I$(PLATDIR) -I$(NITROS9DIR)/level2/wildbits -I$(NITROS9DIR)/level2/modules/kernel
PIPEMODS = $(BUILD)/pipeman $(BUILD)/pipeman_named $(BUILD)/piper $(BUILD)/pipe

.NOTPARALLEL:
.PHONY: all subs l2b09 tools pipes langcheck shots video manual k2img jr2img p1test p2test p3test p4test p5atest p5btest p5ctest p5dtest p5etest p5ftest p5gtest p5htest p5itest p5jtest p5ktest p5ltest p5mtest p5ntest p5otest p5ptest p5qtest p5rtest p5stest p5ttest p5utest p5vtest p5wtest p5xtest p5ytest p5ztest p5aatest p6test p7test p8atest p8btest p8ctest p8dtest p8etest p9atest p9btest loadtime clean k2main jr2main main mainsrc

all: subs l2b09 tools

tools: $(TOOLS)

l2b09: $(L2B09)

subs: $(SUBS)

$(BUILD):
	mkdir -p $@

# l2basic09 runtime: the interpreter, commands and debugger, without the
# compiler (L2B09RT; src/MICROWARE.md, docs/COMPILER.md)
$(BUILD)/l2b09run: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1 -DL2B09RT=1 -DLevel=2
	@[ $$(stat -c %s $@) -le 24576 ] || echo "WARNING: $@ is over 24,576 bytes: it needs a fourth 8K block (ARCHITECTURE.md, P5.5)"

# The separate compiler (docs/COMPILER.md): l2b09run's own code, built
# so that LOAD sends each bound procedure to stdout
$(BUILD)/l2b09cc: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1 -DL2B09CC=1 -DLevel=2

# runb-l2: RunB built from basic09-l2's source (module name RunB), with
# far arrays; it replaces stock RunB (ARCHITECTURE.md, "runb-l2")
$(BUILD)/runb-l2: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) runb $@ -DCOMMUNITY=1 -DLevel=2

# Cold commands (PACK) that l2b09run loads when they are typed
$(BUILD)/l2b09ovl: $(SRCDIR)/overlay.asm $(DEPS) | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) -DCOMMUNITY=1 -DLevel=2 --includedir=$(CURDIR)/$(SRCDIR) $(CURDIR)/$< -o$(CURDIR)/$@

$(BUILD)/%: $(MODDIR)/%.asm $(MODDIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) --includedir=$(CURDIR)/$(MODDIR) $(CURDIR)/$< -o$(CURDIR)/$@

# OS-9 side tools (test clients)
$(BUILD)/%: $(OS9DIR)/%.asm $(OS9DIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) --includedir=$(CURDIR)/$(OS9DIR) $(CURDIR)/$< -o$(CURDIR)/$@

# The editor: 6809 only, and undefined symbols are errors (no undefextern)
EDSRC = $(wildcard $(OS9DIR)/basic09-l2/*.asm)
EDAS  = lwasm --no-warn=ifp1 --format=os9 \
        --pragma=pcaspcr,nosymbolcase,condundefzero,dollarnotlocal,noforwardrefmax \
        --includedir=$(NITROS9DIR)/defs
$(BUILD)/basic09-l2: $(EDSRC) $(OS9DIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(EDAS) $(AFLAGS) --includedir=$(CURDIR)/$(OS9DIR) \
	    --includedir=$(CURDIR)/$(OS9DIR)/basic09-l2 $(CURDIR)/$(OS9DIR)/basic09-l2/basic09-l2.asm -o$(CURDIR)/$@

# The help browser (docs/HELP.md): the editor's screen and key code, with
# branch lengths left to lwasm (its size does not matter as the editor's does)
HVSRC = $(wildcard $(OS9DIR)/l2b09help/*.asm) $(OS9DIR)/basic09-l2/term.asm $(OS9DIR)/basic09-l2/keys.asm
$(BUILD)/l2b09help: $(HVSRC) $(OS9DIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(EDAS) --pragma=autobranchlength $(AFLAGS) --includedir=$(CURDIR)/$(OS9DIR) \
	    --includedir=$(CURDIR)/$(OS9DIR)/basic09-l2 $(CURDIR)/$(OS9DIR)/l2b09help/l2b09help.asm -o$(CURDIR)/$@

# The help file: every KEYTAB word and every error in errmsg must have a page
$(BUILD)/basic09-l2.hlp: $(wildcard help/*.txt) tools/mkhelp.py src/comand.asm | $(BUILD)
	tools/mkhelp.py --errmsg $(NITROS9DIR)/level1/sys/errmsg -o $@

# Pipe modules are not in the stock Wildbits SD boot; tests load them at runtime
pipes: $(PIPEMODS)

$(BUILD)/pipeman_named: $(NITROS9DIR)/level2/modules/pipeman_named.asm | $(BUILD)
	cd $(BUILD) && $(PLATAS) $< -o$(CURDIR)/$@

$(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe: $(BUILD)/%: $(NITROS9DIR)/level1/modules/%.asm | $(BUILD)
	cd $(BUILD) && $(PLATAS) $< -o$(CURDIR)/$@

# P1: compile with stock basic09 from a script, run the packed module with runb
p1test: pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p1

p2test: l2b09 pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p2

p3test: l2b09 tools pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p3

p4test: l2b09 subs $(BASEIMG)
	tools/emu-wildbits.sh test/p4

p5atest: tools $(BASEIMG)
	EMU_SECONDS=240 tools/emu-wildbits.sh test/p5a

p5btest: tools $(BASEIMG)
	tools/emu-wildbits.sh test/p5b

p5ctest: tools $(BASEIMG)
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p5c

p5dtest: tools $(BASEIMG)
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p5d

p5etest: tools $(BASEIMG)
	EMU_SECONDS=400 tools/emu-wildbits.sh test/p5e

p5ftest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5f

p5gtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5g

p5htest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5h

p5itest: tools $(BASEIMG)
	EMU_SECONDS=400 tools/emu-wildbits.sh test/p5i
	test/p5i/check build/emu/p5i

p5jtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5j

p5ktest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5k

p5ltest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=90 tools/emu-wildbits.sh test/p5l

p5mtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=120 tools/emu-wildbits.sh test/p5m

p5ntest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5n

p5otest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5o

p5ptest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=90 tools/emu-wildbits.sh test/p5p

p5qtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=120 tools/emu-wildbits.sh test/p5q

p5rtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=40 tools/emu-wildbits.sh test/p5r

p5stest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=90 tools/emu-wildbits.sh test/p5s

p5ttest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=40 tools/emu-wildbits.sh test/p5t

p5utest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5u

p5vtest: tools l2b09 pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5v

# The debugger shows the statement it stopped at on a line with several
p5wtest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=260 tools/emu-wildbits.sh test/p5w

# A compile error at a ":" between statements gets a hint
p5xtest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=90 tools/emu-wildbits.sh test/p5x

# Shift+RUN/STOP is Run (^R); RUN/STOP alone is not (the output once)
p5ytest: l2b09 tools pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p5y
	@[ $$(grep -c 'shift run' build/emu/p5y/term.out) -eq 1 ] || { echo "p5y: FAILED (not run exactly once)"; exit 1; }

# Stepping onto an INPUT: the program's window comes up, the answer gets there
p5ztest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=160 tools/emu-wildbits.sh test/p5z

p5aatest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=120 tools/emu-wildbits.sh test/p5aa

# the Options menu's marks, Ctrl+3 (80x60), F2 (All: pretty print)
p5abtest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5ab

# F1's help browser double-spaced like the editor (-d), on 80x60
p5actest: l2b09 tools pipes $(BASEIMG)
	EMU_SECONDS=60 tools/emu-wildbits.sh test/p5ac

p6test: l2b09 $(BASEIMG)
	EMU_SECONDS=180 tools/emu-wildbits.sh test/p6

p7test: l2b09 $(BASEIMG)
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p7

# The compiler's work while running (debugger PRINT/LET, RUN arguments):
# the reference for the separate compiler (docs/COMPILER.md)
p8atest: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/p8a

# l2b09cc (step 1 of the separate compiler): it compiles, and sends each
# bound procedure to stdout as a %PROC frame; tools/ccframes.py checks them
p8btest: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/p8b
	tools/ccframes.py build/emu/p8b/cc.out

# Steps 3-4: l2b09run has no compiler; LOAD, KILL ... go through l2b09cc
p8ctest: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/p8c

# Compatibility: a PACKed module the compiler never saw, run with arguments
p8dtest: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/p8d

# RUN/STOP (keyboard abort) at an INPUT: a break, not error 2
# runb-l2: packed modules run as under stock RunB (and by name, through the shell)
p9atest: l2b09 pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p9a

# runb-l2: a packed program with far arrays (p7's) runs as in l2b09run
p9btest: l2b09 pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p9b

p8etest: l2b09 tools pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p8e
	@! grep -a '^< ERROR\|^< %ERROR' build/emu/p8e/ctl.out || { echo "p8e: FAILED (an error for the break)"; exit 1; }

# Benchmark: time l2b09run compiling the 937-line startrek sample
loadtime: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/loadtime

# SD card images for trying the editor on a Wildbits K2 or Jr2: the stock
# image with the pipe modules added to OS9Boot, basic09-l2, l2b09run,
# l2b09help and the subroutine modules in CMDS, runb-l2 as CMDS/runb, the
# help file in SYS, and
# examples/ in /dd/l2b09
K2IMG  = $(BUILD)/l2b09_k2.dsk
JR2IMG = $(BUILD)/l2b09_jr2.dsk
k2img: $(K2IMG)
jr2img: $(JR2IMG)

$(BUILD)/l2b09_%.dsk: $(CURDIR)/$(BUILD)/main/l2_wildbits%.dsk $(TOOLS) $(L2B09) $(SUBS) $(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe $(wildcard examples/*)
	cp $< $@.tmp
	os9 copy -r $@.tmp,OS9Boot $(BUILD)/$*boot.orig
	tools/bootfile-add.py $(BUILD)/$*boot.orig $(BUILD)/$*boot \
	    $(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe
	os9 copy -r $(BUILD)/$*boot $@.tmp,OS9Boot
	for m in basic09-l2 l2b09run l2b09cc l2b09ovl l2b09help syscall inkey farmem; do \
	    os9 copy -r $(BUILD)/$$m $@.tmp,CMDS/$$m && \
	    os9 attr -q -e -pe -r -pr $@.tmp,CMDS/$$m || exit 1; done
	os9 copy -r $(BUILD)/runb-l2 $@.tmp,CMDS/runb
	os9 attr -q -e -pe -r -pr $@.tmp,CMDS/runb
	os9 copy -r $(BUILD)/basic09-l2.hlp $@.tmp,SYS/basic09-l2.hlp
	os9 makdir $@.tmp,L2B09
	for f in examples/*; do case $$f in *.b09) l=-l ;; *) l= ;; esac; \
	    os9 copy $$l -r $$f $@.tmp,L2B09/$$(basename $$f) || exit 1; done
	for f in examples/*.bin; do [ -f $$f ] || continue; \
	    os9 copy -r $$f $@.tmp,SYS/BACKGROUNDS/$$(basename $$f) || exit 1; done
	mv $@.tmp $@

# Disk images for the new (Longview) core, built in the copy of the main
# repos (recipes/README.md):
#   k2main, jr2main   build/main/l2_wildbits{k2,jr2}.dsk (the stock image;
#                     the jr2 one is the tests' BASEIMG) and
#                     l2_basic09-l2{k2,jr2}.dsk (basic09-l2 added by the
#                     recipe in recipes/wildbits/basic09-l2)
#   main              both
# The stock image is rebuilt when a clone's HEAD changes.
MAINRCP   = $(MAINSRC)/nitros9/recipes/wildbits
MAINHEADS = $(MAINSRC)/nitros9.head $(MAINSRC)/nitros9-languages.head $(MAINSRC)/nitros9-apps.head
MAINMAKE  = $(MAKE) NITROS9DIR=$(MAINSRC)/nitros9 LANGUAGES=$(MAINSRC)/nitros9-languages \
            NITROS9_APPS_DIR=$(MAINSRC)/nitros9-apps B09L2DIR=$(CURDIR)
.PHONY: main mainsrc
main: k2main jr2main
mainsrc:
	recipes/export-main.sh $(MAINDIR) $(MAINSRC)
$(CURDIR)/$(BUILD)/main/l2_wildbits%.dsk: $(MAINHEADS)
	$(MAINMAKE) -C $(MAINRCP)/l2 PLATFORM=$*
	cp $(MAINRCP)/l2/l2_wildbits$*.dsk $@
k2main jr2main: %main: mainsrc $(CURDIR)/$(BUILD)/main/l2_wildbits%.dsk
	mkdir -p $(MAINRCP)/basic09-l2
	cp -p recipes/wildbits/basic09-l2/makefile recipes/wildbits/basic09-l2/recipe.mak $(MAINRCP)/basic09-l2/
	$(MAINMAKE) -C $(MAINRCP)/basic09-l2 PLATFORM=$*
	cp $(MAINRCP)/basic09-l2/l2_basic09-l2$*.dsk $(BUILD)/main/

# nitros9-languages/wildbits/basic09-l2 (docs/ARCHITECTURE.md, "Upstreaming
# to NitrOS-9"): export into a copy of the languages tree from build/main/src,
# build it there the way nitros9-languages does, and require every module
# to be byte-identical to this repository's build
LANGDIR  = $(BUILD)/lang/nitros9-languages
LANGMODS = l2b09run l2b09cc l2b09ovl runb-l2 basic09-l2 l2b09help farmem basic09-l2.hlp
# The video, from video/shotlist.txt (video/README.md)
video:
	video/build.py

# The User's Manual (manual/README.md): ReportLab in a virtualenv under build/
MANUALPY = build/manual/venv/bin/python
manual: $(MANUALPY)
	$(MANUALPY) manual/build.py
$(MANUALPY):
	python3 -m venv build/manual/venv
	build/manual/venv/bin/pip install -q reportlab==4.2.5 pillow

# Screenshots of the editor for the video slides and the manual
# (tools/shots/shots.sh; the scenarios editor, edit and debug)
shots: l2b09 tools pipes $(BASEIMG)
	tools/shots/shots.sh
	tools/shots/shots.sh edit
	tools/shots/shots.sh debug

langcheck: l2b09 subs tools
	rm -rf $(BUILD)/lang
	mkdir -p $(BUILD)/lang
	cp -a $(MAINSRC)/nitros9-languages $(LANGDIR)
	tools/export-lang.sh $(LANGDIR)
	$(MAKE) -C $(LANGDIR) wildbits NITROS9DIR=$(NITROS9DIR)
	for m in $(LANGMODS); do cmp $(LANGDIR)/wildbits/basic09-l2/$$m $(BUILD)/$$m || exit 1; done
	@echo "langcheck: $(words $(LANGMODS)) files byte-identical"

clean:
	rm -rf $(BUILD)
