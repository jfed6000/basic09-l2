# l2basic09 top-level build
#
# Only the NitrOS-9 defs directory (os9.d, scf.d, ...) is used from the
# NitrOS-9 tree; point NITROS9DIR at a checkout to override the default.

NITROS9DIR ?= $(HOME)/projects/wild/joust/nitros9_complete/nitros9
REFDIR     ?= $(NITROS9DIR)/../nitros9-languages/basic09
export NITROS9DIR

PYTHON  ?= python3
BUILD   = build
SRCDIR  = src
MODDIR  = modules
SCRIPT  = $(SRCDIR)/build-modular-basic09.py

SRCS = $(addprefix $(SRCDIR)/, comand.asm compil.asm binder.asm stmts.asm \
       exprsn.asm cnvio.asm defs b09defs b09type jmpdefs linkage editor)
DEPS = Makefile $(SCRIPT) $(SRCS)

AS = lwasm --no-warn=ifp1 --6309 --format=os9 \
     --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal,noforwardrefmax \
     --includedir=$(NITROS9DIR)/defs
AFLAGS = -DNOS9VER= -DNOS9MAJ= -DNOS9MIN=

# Stock Microware builds (the baseline everything else is measured against)
STOCK = $(BUILD)/basic09_6809 $(BUILD)/basic09_6309 $(BUILD)/basic09_wildbits \
        $(BUILD)/runb_6809 $(BUILD)/runb_6309
SUBS  = $(BUILD)/syscall $(BUILD)/inkey $(BUILD)/farmem
L2B09 = $(BUILD)/l2b09run
OS9DIR = os9
TOOLS = $(BUILD)/l2b09ctl $(BUILD)/l2b09ed

# Test platform (Wildbits Jr2 under MAME for now; see tools/emu-wildbits.sh)
PLATDIR  = $(NITROS9DIR)/recipes/wildbits/l2
PLATAS   = $(AS) -Dwildbits=1 -Djr2 -DNOS9VER=0 -DNOS9MAJ=0 -DNOS9MIN=0 \
           -I$(PLATDIR) -I$(NITROS9DIR)/level2/wildbits -I$(NITROS9DIR)/level2/modules/kernel
PIPEMODS = $(BUILD)/pipeman $(BUILD)/pipeman_named $(BUILD)/piper $(BUILD)/pipe

.NOTPARALLEL:
.PHONY: all stock subs l2b09 tools pipes k2img check p1test p2test p3test p4test p5atest p5btest p5ctest p5dtest p5etest p5ftest p6test p7test loadtime clean

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

$(BUILD)/%: $(MODDIR)/%.asm $(MODDIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) --includedir=$(CURDIR)/$(MODDIR) $(CURDIR)/$< -o$(CURDIR)/$@

# OS-9 side tools (test clients)
$(BUILD)/%: $(OS9DIR)/%.asm $(OS9DIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) --includedir=$(CURDIR)/$(OS9DIR) $(CURDIR)/$< -o$(CURDIR)/$@

# The editor: 6809 only, and undefined symbols are errors (no undefextern)
EDSRC = $(wildcard $(OS9DIR)/l2b09ed/*.asm)
EDAS  = lwasm --no-warn=ifp1 --format=os9 \
        --pragma=pcaspcr,nosymbolcase,condundefzero,dollarnotlocal,noforwardrefmax \
        --includedir=$(NITROS9DIR)/defs
$(BUILD)/l2b09ed: $(EDSRC) $(OS9DIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(EDAS) $(AFLAGS) --includedir=$(CURDIR)/$(OS9DIR) \
	    --includedir=$(CURDIR)/$(OS9DIR)/l2b09ed $(CURDIR)/$(OS9DIR)/l2b09ed/l2b09ed.asm -o$(CURDIR)/$@

# Pipe modules are not in the stock Wildbits SD boot; tests load them at runtime
pipes: $(PIPEMODS)

$(BUILD)/pipeman_named: $(NITROS9DIR)/level2/modules/pipeman_named.asm | $(BUILD)
	cd $(BUILD) && $(PLATAS) $< -o$(CURDIR)/$@

$(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe: $(BUILD)/%: $(NITROS9DIR)/level1/modules/%.asm | $(BUILD)
	cd $(BUILD) && $(PLATAS) $< -o$(CURDIR)/$@

# P1: compile with stock basic09 from a script, run the packed module with runb
p1test: stock pipes
	tools/emu-wildbits.sh test/p1

p2test: l2b09 pipes
	tools/emu-wildbits.sh test/p2

p3test: l2b09 tools pipes
	tools/emu-wildbits.sh test/p3

p4test: stock l2b09 subs
	tools/emu-wildbits.sh test/p4

p5atest: tools
	EMU_SECONDS=240 tools/emu-wildbits.sh test/p5a

p5btest: tools
	tools/emu-wildbits.sh test/p5b

p5ctest: tools
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p5c

p5dtest: tools
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p5d

p5etest: tools
	EMU_SECONDS=400 tools/emu-wildbits.sh test/p5e

p5ftest: tools l2b09 pipes
	EMU_SECONDS=150 tools/emu-wildbits.sh test/p5f

p6test: l2b09
	EMU_SECONDS=180 tools/emu-wildbits.sh test/p6

p7test: l2b09
	EMU_SECONDS=300 tools/emu-wildbits.sh test/p7

# Benchmark: time l2b09run compiling the 937-line startrek sample
loadtime: l2b09
	tools/emu-wildbits.sh test/loadtime

# An SD card image for trying the editor on a Wildbits K2: the stock K2
# image with the pipe modules added to OS9Boot, l2b09ed, l2b09run and the
# subroutine modules in CMDS, and examples/ in /dd/l2b09
K2IMG = $(BUILD)/l2b09_k2.dsk
k2img: $(K2IMG)

$(K2IMG): $(TOOLS) $(L2B09) $(SUBS) $(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe $(wildcard examples/*)
	cp $(PLATDIR)/l2_wildbitsk2.dsk $@.tmp
	os9 copy -r $@.tmp,OS9Boot $(BUILD)/k2boot.orig
	tools/bootfile-add.py $(BUILD)/k2boot.orig $(BUILD)/k2boot \
	    $(BUILD)/pipeman $(BUILD)/piper $(BUILD)/pipe
	os9 copy -r $(BUILD)/k2boot $@.tmp,OS9Boot
	for m in l2b09ed l2b09run syscall inkey farmem; do \
	    os9 copy -r $(BUILD)/$$m $@.tmp,CMDS/$$m && \
	    os9 attr -q -e -pe -r -pr $@.tmp,CMDS/$$m || exit 1; done
	os9 makdir $@.tmp,L2B09
	for f in examples/*; do os9 copy -l -r $$f $@.tmp,L2B09/$$(basename $$f) || exit 1; done
	mv $@.tmp $@

# Byte-for-byte comparison against the prebuilt modules in the NitrOS-9 tree
check: $(BUILD)/basic09_wildbits $(BUILD)/runb_6809
	cmp $(BUILD)/basic09_wildbits $(REFDIR)/basic09_wildbits
	cmp $(BUILD)/runb_6809 $(REFDIR)/runb_6809
	@echo "check: stock builds match $(REFDIR)"

clean:
	rm -rf $(BUILD)
