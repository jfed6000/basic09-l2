# Languages and tools for the Wildbits computers only

dirs = basic09-l2
clean_dirs = $(addprefix clean-,$(dirs))

all: $(dirs)

$(dirs):
	$(MAKE) -C $@

clean: $(clean_dirs)

$(clean_dirs):
	$(MAKE) -C $(patsubst clean-%,%,$@) clean

.PHONY: all clean $(dirs) $(clean_dirs)
