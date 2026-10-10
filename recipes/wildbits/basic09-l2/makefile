# basic09-l2 Level 2 disk image for Wildbits, built from the NitrOS-9
# tree's own l2 recipe plus recipe.mak.
#   make                  K2 image: l2_basic09-l2k2.dsk
#   make PLATFORM=jr2     Jr2 image: l2_basic09-l2jr2.dsk
include ../../nitros9.mak
include $(NITROS9DIR)/recipes/wildbits/l2/makefile

# After the stock image is built: basic09-l2's modules go to CMDS (the
# stock inkey and syscall are replaced) and examples/ to /dd/L2B09.
# toolshed's os9 copy can fail with exit status 0, so the result is
# checked with os9 dir.
.PHONY: b09l2 b09l2-mods
b09l2-mods:
	$(MAKE) -C $(B09L2DIR) BUILD=build/main l2b09 subs build/main/basic09-l2
b09l2: $(DSKIMAGE) b09l2-mods
	for m in $(B09L2MODS); do \
	    os9 copy -r $(B09L2BUILD)/$$m $(DSKIMAGE),CMDS/$$m && \
	    os9 attr -q -e -pe -r -pr $(DSKIMAGE),CMDS/$$m || exit 1; done
	os9 dir $(DSKIMAGE),L2B09 >/dev/null 2>&1 || os9 makdir $(DSKIMAGE),L2B09
	for f in $(B09L2DIR)/examples/*; do \
	    os9 copy -l -r $$f $(DSKIMAGE),L2B09/$$(basename $$f) || exit 1; done
	for m in $(B09L2MODS); do \
	    os9 dir $(DSKIMAGE),CMDS | tr -s ' ' '\n' | grep -qx $$m || \
	    { echo "$(DSKIMAGE): CMDS/$$m is missing" >&2; exit 1; }; done
