# basic09-l2 Level 2 disk image for Wildbits: the stock l2 recipe plus
# recipe.mak.  This folder is copied into the exported NitrOS-9 tree
# (build/main/src/nitros9/recipes/wildbits/basic09-l2, recipes/README.md)
# and built there, beside the stock recipes; the top-level Makefile
# passes NITROS9DIR (the copy) and B09L2DIR (this repository).
#   make                  K2 image: l2_basic09-l2k2.dsk
#   make PLATFORM=jr2     Jr2 image: l2_basic09-l2jr2.dsk
include ../l2/makefile

# After the stock image is built: basic09-l2's modules go to CMDS (the
# stock inkey and syscall are replaced, and runb-l2 replaces RunB as
# CMDS/runb), the help file to SYS, and
# examples/ to /dd/L2B09.
# toolshed's os9 copy can fail with exit status 0, so the result is
# checked with os9 dir.
.PHONY: b09l2 b09l2-mods
b09l2-mods:
	$(MAKE) -C $(B09L2DIR) BUILD=build/main l2b09 subs build/main/basic09-l2 \
	    build/main/l2b09help build/main/basic09-l2.hlp
b09l2: libs $(DSKIMAGE) b09l2-mods
	for m in $(B09L2MODS); do \
	    os9 copy -r $(B09L2BUILD)/$$m $(DSKIMAGE),CMDS/$$m && \
	    os9 attr -q -e -pe -r -pr $(DSKIMAGE),CMDS/$$m || exit 1; done
	os9 copy -r $(B09L2BUILD)/runb-l2 $(DSKIMAGE),CMDS/runb
	os9 attr -q -e -pe -r -pr $(DSKIMAGE),CMDS/runb
	rm -f $(B09L2BUILD)/runb.check
	os9 copy -r $(DSKIMAGE),CMDS/runb $(B09L2BUILD)/runb.check
	cmp -s $(B09L2BUILD)/runb-l2 $(B09L2BUILD)/runb.check || \
	    { echo "$(DSKIMAGE): CMDS/runb is not runb-l2" >&2; exit 1; }
	os9 copy -r $(B09L2BUILD)/basic09-l2.hlp $(DSKIMAGE),SYS/basic09-l2.hlp
	os9 dir $(DSKIMAGE),L2B09 >/dev/null 2>&1 || os9 makdir $(DSKIMAGE),L2B09
	for f in $(B09L2DIR)/examples/*; do \
	    case $$f in *.b09) l=-l ;; *) l= ;; esac; \
	    os9 copy $$l -r $$f $(DSKIMAGE),L2B09/$$(basename $$f) || exit 1; done
	for f in $(B09L2DIR)/examples/*.bin; do [ -f $$f ] || continue; \
	    os9 copy -r $$f $(DSKIMAGE),SYS/BACKGROUNDS/$$(basename $$f) || exit 1; done
	for m in $(B09L2MODS); do \
	    os9 dir $(DSKIMAGE),CMDS | tr -s ' ' '\n' | grep -qx $$m || \
	    { echo "$(DSKIMAGE): CMDS/$$m is missing" >&2; exit 1; }; done
	os9 dir $(DSKIMAGE),SYS | tr -s ' ' '\n' | grep -qx basic09-l2.hlp || \
	    { echo "$(DSKIMAGE): SYS/basic09-l2.hlp is missing" >&2; exit 1; }
