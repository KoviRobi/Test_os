# Makefile - build script

# Disable builtin rules, make sometimes gets confused
.SUFFIXES:

# For verbose compilation, set Q to nothing, that is Q=
Q ?= @
# Also, set Q_REDIR to nothing if you want stdout
Q_REDIR ?= 1> /dev/null

# Macros for prettier quiet output TODO \/ + use colour?
FAILED = if [ -n "$(strip $(Q))" ]; then echo " [31;7mFailed![0m"; fi; false
DONE   = if [ -n "$(strip $(Q))" ]; then echo " [32;7mDone![0m"; fi; true

# build environment
PREFIX ?= /usr
ARMGNU ?= $(PREFIX)/bin/arm-none-eabi

# directories
TMPDIR = tmp
SRCDIR = src
DOCDIR = pdf

# source files
SOURCES_W   = $(patsubst $(SRCDIR)%,$(TMPDIR)%,$(wildcard $(SRCDIR)/*.w)   $(wildcard $(SRCDIR)/*/*.w))
COPY_C      = $(patsubst $(SRCDIR)%,$(TMPDIR)%,$(wildcard $(SRCDIR)/*.c)   $(wildcard $(SRCDIR)/*/*.c))
COPY_H      = $(patsubst $(SRCDIR)%,$(TMPDIR)%,$(wildcard $(SRCDIR)/*.h)   $(wildcard $(SRCDIR)/*/*.h))
COPY_ASM    = $(patsubst $(SRCDIR)%,$(TMPDIR)%,$(wildcard $(SRCDIR)/*.S)   $(wildcard $(SRCDIR)/*/*.S))
COPY_TEX    = $(patsubst $(SRCDIR)%,$(TMPDIR)%,$(wildcard $(SRCDIR)/*.tex) $(wildcard $(SRCDIR)/*/*.tex))

SOURCES_C   = $(wildcard $(TMPDIR)/*.c)   $(wildcard $(TMPDIR)/*/*.c)
SOURCES_H   = $(wildcard $(TMPDIR)/*.h)   $(wildcard $(TMPDIR)/*/*.h)
SOURCES_ASM = $(wildcard $(TMPDIR)/*.S)   $(wildcard $(TMPDIR)/*/*.S)
SOURCES_TEX = $(wildcard $(TMPDIR)/*.tex) $(wildcard $(TMPDIR)/*/*.tex)

# object files
OBJS        = $(patsubst %.S,%.o,$(SOURCES_ASM)) $(patsubst %.c,%.o,$(SOURCES_C))
PDFS        = $(patsubst $(TMPDIR)/%.tex,$(DOCDIR)/%.pdf,$(filter-out %_contents.tex,$(SOURCES_TEX)))

# Build flags
DEPENDFLAGS := -MD -MP
INCLUDES    := -I $(TMPDIR)
BASEFLAGS   := -O2 -fpic -pedantic -pedantic-errors -nostdlib
BASEFLAGS   += -ffreestanding -fomit-frame-pointer -mcpu=arm1176jzf-s
WARNFLAGS   := -Wall -Wextra -Wshadow -Wcast-align -Wwrite-strings
WARNFLAGS   += -Wredundant-decls -Winline
WARNFLAGS   += -Wno-attributes -Wno-deprecated-declarations
WARNFLAGS   += -Wno-div-by-zero -Wno-endif-labels -Wfloat-equal
WARNFLAGS   += -Wformat=2 -Wno-format-extra-args -Winit-self
WARNFLAGS   += -Winvalid-pch -Wmissing-format-attribute
WARNFLAGS   += -Wmissing-include-dirs -Wno-multichar
WARNFLAGS   += -Wredundant-decls -Wshadow
WARNFLAGS   += -Wno-sign-compare -Wswitch -Wsystem-headers -Wundef
WARNFLAGS   += -Wno-pragmas -Wno-unused-but-set-parameter
WARNFLAGS   += -Wno-unused-but-set-variable -Wno-unused-result
WARNFLAGS   += -Wwrite-strings -Wdisabled-optimization -Wpointer-arith
WARNFLAGS   += -Werror
ASFLAGS     := $(INCLUDES) $(DEPENDFLAGS) -D__ASSEMBLY__
CFLAGS      := $(INCLUDES) $(DEPENDFLAGS) $(BASEFLAGS) $(WARNFLAGS)
CFLAGS      += -std=gnu99

# build rules
.PHONY: all clean dist-clean
all: stage1_source_files stage2_compilation stage3_transfer

clean:
	test ! -d $(TMPDIR) || { find $(TMPDIR)  -type f -exec rm {} \;; find $(TMPDIR)/ -depth -type d -exec rmdir {} \;; }

doc-clean:
	test ! -d $(DOCDIR) || { find $(DOCDIR)  -type f -exec rm {} \;; find $(DOCDIR)/ -depth -type d -exec rmdir {} \;; }

dist-clean: clean doc-clean
	$(RM) kernel.elf kernel.img
	find $(TMPDIR) -name '*.d' -exec rm {} \;


# ---------------------------------------------------------------------
.PHONY : stage1_source_files
stage1_source_files: $(SOURCES_W) $(COPY_C) $(COPY_H) $(COPY_ASM)

# CWEB.
$(TMPDIR)/%.w: $(SRCDIR)/%.w $(SRCDIR)/%.ch
	@if [ -n "$(Q)" -a ! -d $(dir $@) ]; then echo "Making directory $(dir $@) ..."; fi
	$(Q)test -d $(dir $@) || { mkdir -p $(dir $@) && $(DONE); } || { $(FAILED); }
	-
	$(Q)cp $< $@ # To keep target happy too
	@if [ -n "$(Q)" ]; then echo "Tangling (C) $< in $$PWD ..."; fi
	$(Q)cd $(dir $@) && \
		CWEBINPUTS=$(realpath .) ctangle -bhp \
		$(realpath $<) \
		$(wildcard $(addsuffix .ch,$(basename $(abspath $<)))) \
		&& { $(DONE); } \
		|| { rm $(abspath $@) $(addsuffix .c,$(basename $(abspath $@))); $(FAILED); false; }
	-
	@if [ -n "$(Q)" ]; then echo "Weaving (TeX) $< in $$PWD ..."; fi
	$(Q)cd $(dir $@) && \
		CWEBINPUTS=$(realpath .) cweave -bhp \
		$(realpath $<) \
		$(wildcard $(addsuffix .ch,$(basename $(abspath $<)))) \
		&& { $(DONE); } \
		|| { rm $(abspath $@) $(addsuffix .tex,$(basename $(abspath $@))); $(FAILED); false; }
	@echo

$(SRCDIR)/%.ch:
	@test -e $@ && echo "Using $@ as a changefile" || true # No changefile

# C.
$(TMPDIR)/%.h: $(SRCDIR)/%.h
	@if [ -n "$(Q)" -a ! -d $(dir $@) ]; then echo "Making directory $(dir $@) ..."; fi
	$(Q)test -d $(dir $@) || { mkdir -p $(dir $@) && $(DONE); } || { $(FAILED); }
	-
	@if [ -n "$(Q)" ]; then echo "Copying $< to $@ ..."; fi
	$(Q)cp $< $@ && { $(DONE); || { $(FAILED); }
	@echo

$(TMPDIR)/%.c: $(SRCDIR)/%.c
	@if [ -n "$(Q)" -a ! -d $(dir $@) ]; then echo "Making directory $(dir $@) ..."; fi
	$(Q)test -d $(dir $@) || { mkdir -p $(dir $@) && $(DONE); } || { $(FAILED); }
	-
	@if [ -n "$(Q)" ]; then echo "Copying $< to $@ ..."; fi
	$(Q)cp $< $@ && { $(DONE); || { $(FAILED); }
	@echo

# AS.
$(TMPDIR)/%.S: $(SRCDIR)/%.S
	@if [ -n "$(Q)" -a ! -d $(dir $@) ]; then echo "Making directory $(dir $@) ..."; fi
	$(Q)test -d $(dir $@) || { mkdir -p $(dir $@) && $(DONE); } || { $(FAILED); }
	-
	@if [ -n "$(Q)" ]; then echo "Copying $< to $@ ..."; fi
	$(Q)cp $< $@ && { $(DONE); || { $(FAILED); }
	@echo

# ---------------------------------------------------------------------
.PHONY: stage2_compilation
stage2_compilation: kernel.img docs

# C.
$(TMPDIR)/%.o: $(TMPDIR)/%.c
	@if [ -n "$(Q)" ]; then echo "Compiling (C) $< to $@ ..."; fi
	$(Q)$(ARMGNU)-gcc $(CFLAGS) -c $< -o $@ $(Q_REDIR) && { $(DONE); } || { $(FAILED); }
	@echo

# AS.
$(TMPDIR)/%.o: $(TMPDIR)/%.S
	@if [ -n "$(Q)" ]; then echo "Compiling (ASM) $< to $@ ..."; fi
	$(Q)$(ARMGNU)-gcc $(ASFLAGS) -c $< -o $@ $(Q_REDIR) && { $(DONE); } || { $(FAILED); }
	@echo

# PDF.
$(DOCDIR)/%.pdf: $(TMPDIR)/%.tex
	@if [ -n "$(Q)" -a ! -d $(dir $@) ]; then echo "Making directory $(dir $@) ..."; fi
	$(Q)test -d $(dir $@) || { mkdir -p $(dir $@) && $(DONE); } || { $(FAILED); }
	-
	@if [ -n "$(Q)" ]; then echo "Compiling (TeX) $< ..."; fi
	$(Q)cd $(dir $<) && pdftex -halt-on-error $(notdir $<) $(Q_REDIR) && { $(DONE); } || { $(FAILED); }
	-
	@if [ -n "$(Q)" ]; then echo "Moving $(patsubst %.tex, %.pdf, $<) to $(dir $@) ..."; fi
	$(Q)mv $(patsubst %.tex,%.pdf,$<) $(dir $@) && { $(DONE); } || { $(FAILED); }
	@echo

docs: stage1_source_files $(PDFS)
	@if [ -z "$(strip $(PDFS))" ]; then echo -e "\n\nNo TeX files found, perhaps due to directory caching. If so, just try running the make command again. Also, try running \"make stage1_source_files\" before to be safe."; false; fi

# include $(wildcard src/*.d) $(wildcard src/*/*.d)

kernel.elf: $(OBJS) $(SRCDIR)/link-arm-eabi.ld
	@if [ -z "$(strip $(OBJS))" ]; then echo -e "\n\nNo object targets, perhaps due to directory caching. If so, just try running the make command again. Also, try running \"make stage1_source_files\" before to be safe."; false; fi
	@if [ -n "$(Q)" ]; then echo "Linking $(OBJS) according to $(SRCDIR)/link-arm-eabi.ld to $@ ..."; fi
	$(Q)$(ARMGNU)-ld $(OBJS) -T$(SRCDIR)/link-arm-eabi.ld -o $@ $(Q_REDIR) && { $(DONE); } || { $(FAILED); }
	@echo

kernel.img: kernel.elf
	@if [ -n "$(Q)" ]; then echo "Outputting binary to $@ ..."; fi
	$(Q)$(ARMGNU)-objcopy kernel.elf -O binary kernel.img $(Q_REDIR) && { $(DONE); } || { $(FAILED); }
	@echo

# ---------------------------------------------------------------------
.PHONY: stage3_transfer
stage3_transfer:
	@if [ -n "$(Q)" ]; then echo "Transferring via /dev/ttyUSB0"; fi
	$(Q)./raspbootcom /dev/ttyUSB0 kernel.img && { $(DONE); } || { $(FAILED); }
	@echo
