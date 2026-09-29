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
SUBS  = $(BUILD)/syscall $(BUILD)/inkey

.NOTPARALLEL:
.PHONY: all stock subs check clean

all: stock subs

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

$(BUILD)/%: $(MODDIR)/%.asm $(MODDIR)/defsfile | $(BUILD)
	cd $(BUILD) && $(AS) $(AFLAGS) --includedir=$(CURDIR)/$(MODDIR) $(CURDIR)/$< -o$(CURDIR)/$@

# Byte-for-byte comparison against the prebuilt modules in the NitrOS-9 tree
check: $(BUILD)/basic09_wildbits $(BUILD)/runb_6809
	cmp $(BUILD)/basic09_wildbits $(REFDIR)/basic09_wildbits
	cmp $(BUILD)/runb_6809 $(REFDIR)/runb_6809
	@echo "check: stock builds match $(REFDIR)"

clean:
	rm -rf $(BUILD)
