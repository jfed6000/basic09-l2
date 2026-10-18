# l2basic09 top-level build
#
# The NitrOS-9 tree is a copy of the nitros9project clones in $(MAINDIR),
# which stay pristine: recipes/export-main.sh writes each one's HEAD into
# build/main/src/ (again only when HEAD changes; recipes/README.md).  Its
# defs, pipe modules and stock Level 2 image are used, and the stock
# basic09/runb built there are the reference for "make check".
# Point NITROS9DIR at another checkout (and BASEIMG at its image) to
# override, e.g. the old-core joust tree.

PYTHON  ?= python3
BUILD   = build

MAINDIR    ?= $(HOME)/projects/wild/main
MAINSRC     = $(CURDIR)/build/main/src
NITROS9DIR ?= $(MAINSRC)/nitros9
REFDIR     ?= $(NITROS9DIR)/../nitros9-languages/basic09
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
       exprsn.asm cnvio.asm defs b09defs b09type jmpdefs linkage editor pack)
DEPS = Makefile $(SCRIPT) $(SRCS)

AS = lwasm --no-warn=ifp1 --6309 --format=os9 \
     --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax \
     --includedir=$(NITROS9DIR)/defs
AFLAGS = -DNOS9VER= -DNOS9MAJ= -DNOS9MIN=

# Stock Microware builds (the baseline everything else is measured against)
STOCK = $(BUILD)/basic09_6809 $(BUILD)/basic09_6309 $(BUILD)/basic09_wildbits \
        $(BUILD)/runb_6809 $(BUILD)/runb_6309
SUBS  = $(BUILD)/syscall $(BUILD)/inkey $(BUILD)/farmem
L2B09 = $(BUILD)/l2b09run $(BUILD)/l2b09ovl
OS9DIR = os9
TOOLS = $(BUILD)/l2b09ctl $(BUILD)/basic09-l2 $(BUILD)/l2b09help $(BUILD)/basic09-l2.hlp

# Test platform (Wildbits Jr2 under MAME for now; see tools/emu-wildbits.sh)
PLATDIR  = $(NITROS9DIR)/recipes/wildbits/l2
PLATAS   = $(AS) -Dwildbits=1 -Djr2 -DNOS9VER=0 -DNOS9MAJ=0 -DNOS9MIN=0 \
           -I$(PLATDIR) -I$(NITROS9DIR)/level2/wildbits -I$(NITROS9DIR)/level2/modules/kernel
PIPEMODS = $(BUILD)/pipeman $(BUILD)/pipeman_named $(BUILD)/piper $(BUILD)/pipe

.NOTPARALLEL:
.PHONY: all stock subs l2b09 tools pipes k2img jr2img check p1test p2test p3test p4test p5atest p5btest p5ctest p5dtest p5etest p5ftest p5gtest p5htest p5itest p5jtest p5ktest p5ltest p5mtest p5ntest p5otest p5ptest p5qtest p5rtest p5stest p5ttest p5utest p6test p7test loadtime clean k2main jr2main main mainsrc

all: stock subs l2b09 tools

tools: $(TOOLS)

l2b09: $(L2B09)

stock: $(STOCK)
subs: $(SUBS)

$(BUILD):
	mkdir -p $@

$(BUILD)/basic09_6809: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1

$(BUILD)/basic09_6309: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1 -DH6309=1

$(BUILD)/basic09_wildbits: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1 -Dwildbits=1

$(BUILD)/runb_6809: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) runb $@ -DCOMMUNITY=1

$(BUILD)/runb_6309: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) runb $@ -DCOMMUNITY=1 -DH6309=1

# l2basic09 runtime: Basic09 without the line editor (see src/b09type, L2B09)
$(BUILD)/l2b09run: $(DEPS) | $(BUILD)
	$(PYTHON) $(SCRIPT) basic09 $@ -DCOMMUNITY=1 -DL2B09=1 -DLevel=2
	@[ $$(stat -c %s $@) -le 24576 ] || echo "WARNING: $@ is over 24,576 bytes: it needs a fourth 8K block (ARCHITECTURE.md, P5.5)"

# Cold commands (PACK) that l2b09run loads when they are typed
$(BUILD)/l2b09ovl: $(SRCDIR)/overlay.asm $(DEPS) | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) -DCOMMUNITY=1 -DL2B09=1 -DLevel=2 --includedir=$(CURDIR)/$(SRCDIR) $(CURDIR)/$< -o$(CURDIR)/$@

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
p1test: stock pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p1

p2test: l2b09 pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p2

p3test: l2b09 tools pipes $(BASEIMG)
	tools/emu-wildbits.sh test/p3

p4test: stock l2b09 subs $(BASEIMG)
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

p6test: l2b09 $(BASEIMG)
	EMU_SECONDS=180 tools/emu-wildbits.sh test/p6

p7test: l2b09 $(BASEIMG)
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p7

# Benchmark: time l2b09run compiling the 937-line startrek sample
loadtime: l2b09 $(BASEIMG)
	tools/emu-wildbits.sh test/loadtime

# SD card images for trying the editor on a Wildbits K2 or Jr2: the stock
# image with the pipe modules added to OS9Boot, basic09-l2, l2b09run,
# l2b09help and the subroutine modules in CMDS, the help file in SYS, and
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
	for m in basic09-l2 l2b09run l2b09ovl l2b09help syscall inkey farmem; do \
	    os9 copy -r $(BUILD)/$$m $@.tmp,CMDS/$$m && \
	    os9 attr -q -e -pe -r -pr $@.tmp,CMDS/$$m || exit 1; done
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
# The stock image is rebuilt when a clone's HEAD changes; building it also
# builds the reference basic09_wildbits and runb_6809 for "make check".
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

# Byte-for-byte comparison against the stock modules built in the copy
# (or the prebuilt ones in REFDIR, for another tree)
check: $(BUILD)/basic09_wildbits $(BUILD)/runb_6809 $(if $(filter $(MAINSRC)/%,$(REFDIR)),$(CURDIR)/$(BUILD)/main/l2_wildbitsjr2.dsk)
	cmp $(BUILD)/basic09_wildbits $(REFDIR)/basic09_wildbits
	cmp $(BUILD)/runb_6809 $(REFDIR)/runb_6809
	@echo "check: stock builds match $(REFDIR)"

clean:
	rm -rf $(BUILD)
