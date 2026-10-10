# Where the NitrOS-9 sources are, for the recipes under recipes/.
#
# The recipes here build disk images from a NitrOS-9 checkout without
# copying it: recipes/wildbits/<name>/ mirrors the tree's own layout, so
# the relative includes in its makefiles (../wildbits.mak,
# ../../rules.mak, ../../libs.mak) land on the small forwarding files
# next to this one.  Override on the command line or in the environment:
#   make NITROS9DIR=/path/to/nitros9 LANGUAGES=/path/to/nitros9-languages

NITROS9DIR ?= $(HOME)/projects/wild/main/nitros9
# The tree's rules.mak reassigns NITROS9DIR from the current directory
# when it is not in the environment; pin it.
override NITROS9DIR := $(abspath $(NITROS9DIR))
export NITROS9DIR

# basic09_wildbits and runb come from nitros9-languages beside the tree
LANGUAGES ?= $(abspath $(NITROS9DIR)/../nitros9-languages)
export LANGUAGES

# The top of this repository
B09L2DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
