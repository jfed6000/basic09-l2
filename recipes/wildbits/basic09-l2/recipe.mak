# basic09-l2 additions to the stock Wildbits l2 recipe (read by
# wildbits.mak through its "-include recipe.mak" hook).

# Declared first so that a plain "make" builds; wildbits.mak adds the
# prerequisites (the first target read is make's default goal).
all:

# Output: l2_basic09-l2k2.dsk or l2_basic09-l2jr2.dsk
RECIPE = basic09-l2

# The stock l2 directory beside this one holds defsfile and padup256
AFLAGS += -I../l2
PADUP = ../l2/padup256 bootfile

# The editor and l2b09run talk over pipes, which must be in OS9Boot
BOOTMODS_EXTRA += pipeman piper pipe

# basic09-l2's own modules, assembled with this tree's defs into
# build/main/ of the repository (B09L2DIR, set by the top-level
# Makefile); the makefile copies them into the image
B09L2BUILD = $(B09L2DIR)/build/main
B09L2MODS = basic09-l2 l2b09run l2b09ovl syscall inkey farmem
all: b09l2
