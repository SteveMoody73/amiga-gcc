# =================================================
# Makefile based Amiga compiler setup.
# (c) Stefan "Bebbo" Franke in 2018
#
# Riding a dead horse...
# =================================================
include disable_implicite_rules.mk
# =================================================
# variables
# =================================================
SHELL = /bin/bash

PREFIX ?= /opt/amiga

UNAME_S := $(shell uname -s)
BUILD := build-$(UNAME_S)

GCC_VERSION ?= $(shell cat 2>/dev/null projects/gcc/gcc/BASE-VER)

BINUTILS_BRANCH := amiga
GCC_BRANCH := gcc-6-branch

GIT_AMIGA_NETINCLUDE := https://github.com/bebbo/amiga-netinclude
GIT_BINUTILS         := https://github.com/bebbo/binutils-gdb
GIT_CLIB2            := https://github.com/bebbo/clib2
GIT_FD2PRAGMA        := https://github.com/bebbo/fd2pragma
GIT_FD2SFD           := https://github.com/cahirwpz/fd2sfd
GIT_GCC              := https://github.com/bebbo/gcc
GIT_IRA              := https://github.com/bebbo/ira
GIT_IXEMUL           := https://github.com/bebbo/ixemul
GIT_LHA              := https://github.com/jca02266/lha
GIT_LIBDEBUG         := https://github.com/bebbo/libdebug
GIT_LIBNIX           := https://github.com/bebbo/libnix
GIT_LIBSDL12         := https://github.com/AmigaPorts/libSDL12
GIT_NEWLIB_CYGWIN    := https://github.com/bebbo/newlib-cygwin
GIT_SFDC             := https://github.com/adtools/sfdc
GIT_VASM             := https://github.com/leffmann/vasm
GIT_VBCC             := https://github.com/bebbo/vbcc
GIT_VLINK            := https://github.com/leffmann/vlink

CFLAGS ?= -Os
CXXFLAGS ?= $(CFLAGS)
CFLAGS_FOR_TARGET ?= -Os -fomit-frame-pointer
CXXFLAGS_FOR_TARGET ?= $(CFLAGS_FOR_TARGET) -fno-exceptions -fno-rtti

E:=CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" CFLAGS_FOR_BUILD="$(CFLAGS)" CXXFLAGS_FOR_BUILD="$(CXXFLAGS)"  CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)" CXXFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)"

# =================================================
# determine exe extension for cygwin
$(eval MYMAKE = $(shell which make 2>/dev/null) )
$(eval MYMAKEEXE = $(shell which "$(MYMAKE:%=%.exe)" 2>/dev/null) )
EXEEXT:=$(MYMAKEEXE:%=.exe)

# Files for GMP, MPC and MPFR

GMP := gmp-6.1.2
GMPFILE := $(GMP).tar.bz2
MPC := mpc-1.0.3
MPCFILE := $(MPC).tar.gz
MPFR := mpfr-3.1.6
MPFRFILE := $(MPFR).tar.bz2

# =================================================
# pretty output ^^
# =================================================
TEEEE := >&

ifeq ($(sdk),)
__LINIT := $(shell rm .state 2>/dev/null)
endif

$(eval has_flock = $(shell which flock 2>/dev/null))
ifeq ($(has_flock),)
FLOCK := echo >/dev/null
else
FLOCK := $(has_flock)
endif

L0 = @__p=
L00 = __p=
ifeq ($(verbose),)
L1 = ; ($(FLOCK) 200; echo -e \\033[33m$$__p...\\033[0m >>.state; echo -ne \\033[33m$$__p...\\033[0m ) 200>.lock; mkdir -p log; __l="log/$$__p.log" ; (
L2 = )$(TEEEE) "$$__l"; __r=$$?; ($(FLOCK) 200; if (( $$__r > 0 )); then \
  echo -e \\r\\033[K\\033[31m$$__p...failed\\033[0m; \
  tail -n 100 "$$__l"; \
  echo -e \\033[31m$$__p...failed\\033[0m; \
  echo -e \\033[1mless \"$$__l\"\\033[0m; \
  else echo -e \\r\\033[K\\033[32m$$__p...done\\033[0m; fi \
  ;grep -v "$$__p" .state >.state0 2>/dev/null; mv .state0 .state ;echo -n $$(cat .state | paste -sd " " -); ) 200>.lock; [[ $$__r -gt 0 ]] && exit $$__r; echo -n ""
else
L1 = ;
L2 = ;
endif

# =================================================
# working out the correct prefix path for msys
DETECTED_CC = $(CC)
ifeq ($(CC),cc)
DETECTED_VERSION =  $(shell $(CC) -v |& grep version)
ifneq ($(findstring clang,$(DETECTED_VERSION)),)
DETECTED_CC = clang
endif
ifneq ($(findstring gcc,$(DETECTED_VERSION)),)
DETECTED_CC = gcc
endif
endif

USED_CC_VERSION = $(shell $(DETECTED_CC) -v |& grep Target)
BUILD_TARGET=unix
ifneq ($(findstring msys,$(USED_CC_VERSION)),)
BUILD_TARGET=msys
  else
  ifneq ($(findstring mingw,$(USED_CC_VERSION)),)
BUILD_TARGET=msys
  endif
endif

PREFIX_TARGET = $(PREFIX)
ifneq ($(findstring :,$(PREFIX)),)
# Under mingw convert paths such as c:/gcc to /c/gcc
# Quotes added to work around a broken pipe error when running under MinGW
PREFIX_SUB = "/$(subst \,/,$(subst :,,$(PREFIX)))"
PREFIX_PATH = $(subst ",,$(PREFIX_SUB))
else
PREFIX_PATH = $(PREFIX)
endif

export PATH := $(PREFIX_PATH)/bin:$(PATH)

UPDATE = __x=
ANDPULL = ;__y=$$(git branch | grep '*' | cut -b3-);echo setting remote origin from $$(git remote get-url origin) to $$__x using branch $$__y;\
	git remote remove origin; \
	git remote add origin $$__x; \
	git pull origin $$__y;\
	git branch --set-upstream-to=origin/$$__y $$__y; \

# =================================================

.PHONY: x init
x:
	@if [ "$(sdk)" == "" ]; then \
		$(MAKE) help; \
	else \
		$(MAKE) sdk; \
	fi

# =================================================
# help
# =================================================
.PHONY: help
help:
	@echo "make help            display this help"
	@echo "make info            print prefix and other flags"
	@echo "make all             build and install all"
	@echo "make <target>        builds a target: binutils, gcc, gprof, fd2sfd, fd2pragma, ira, sfdc, vasm, vbcc, vlink, libnix, ixemul, libgcc, clib2, libdebug, libSDL12, ndk, ndk13"
	@echo "make clean           remove the build folder"
	@echo "make clean-<target>	remove the target's build folder"
	@echo "make clean-prefix    remove all content from the prefix folder"
	@echo "make update          perform git pull for all targets"
	@echo "make update-<target> perform git pull for the given target"
	@echo "make sdk=<sdk>       install the sdk <sdk>"
	@echo "make all-sdk         install all sdks"
	@echo "make info			display some info"

# =================================================
# all
# =================================================
ifeq ($(BUILD_TARGET),msys)
.PHONY: install-dll
all: install-dll
endif
.PHONY: all gcc gprof binutils fd2sfd fd2pragma ira sfdc vasm vbcc vlink libnix ixemul libgcc clib2 libdebug libSDL12 ndk ndk13
all: gcc binutils gprof fd2sfd fd2pragma ira sfdc vbcc vasm vlink libnix ixemul libgcc clib2 libdebug libSDL12 ndk ndk13

# =================================================
# clean
# =================================================
ifeq ($(BUILD_TARGET),msys)
.PHONY: clean-gmp clean-mpc clean-mpfr
clean: clean-gmp clean-mpc clean-mpfr
endif

.PHONY: clean-prefix clean clean-gcc clean-binutils clean-fd2sfd clean-fd2pragma clean-ira clean-sfdc clean-vasm clean-vbcc clean-vlink clean-libnix clean-ixemul clean-libgcc clean-clib2 clean-libdebug clean-libSDL12 clean-newlib clean-ndk
clean: clean-gcc clean-binutils clean-fd2sfd clean-fd2pragma clean-ira clean-sfdc clean-vasm clean-vbcc clean-vlink clean-libnix clean-ixemul clean-clib2 clean-libdebug clean-libSDL12 clean-newlib clean-ndk clean-gmp clean-mpc clean-mpfr
	rm -rf $(BUILD)
	rm -rf *.log
	mkdir -p $(BUILD)

clean-gcc:
	rm -rf $(BUILD)/gcc

clean-gmp:
	rm -rf projects/gcc/gmp

clean-mpc:
	rm -rf projects/gcc/mpc

clean-mpfr:
	rm -rf projects/gcc/mpfr

clean-libgcc:
	rm -rf $(BUILD)/gcc/m68k-amigaos
	rm $(BUILD)/gcc/_libgcc_done

clean-binutils:
	rm -rf $(BUILD)/binutils

clean-gprof:
	rm -rf $(BUILD)/binutils/gprof

clean-fd2sfd:
	rm -rf $(BUILD)/fd2sfd

clean-fd2pragma:
	rm -rf $(BUILD)/fd2pragma

clean-ira:
	rm -rf $(BUILD)/ira

clean-sfdc:
	rm -rf $(BUILD)/sfdc

clean-vasm:
	rm -rf $(BUILD)/vasm

clean-vbcc:
	rm -rf $(BUILD)/vbcc

clean-vlink:
	rm -rf $(BUILD)/vlink

clean-ndk:
	rm -rf $(BUILD)/ndk*

clean-libnix:
	rm -rf $(BUILD)/libnix

clean-ixemul:
	rm -rf $(BUILD)/ixemul

clean-clib2:
	rm -rf $(BUILD)/clib2

clean-libdebug:
	rm -rf $(BUILD)/libdebug

clean-libSDL12:
	rm -rf $(BUILD)/libSDL12

clean-newlib:
	rm -rf $(BUILD)/newlib

# clean-prefix drops the files from prefix folder
clean-prefix:
	rm -rf $(PREFIX_PATH)/bin
	rm -rf $(PREFIX_PATH)/libexec
	rm -rf $(PREFIX_PATH)/lib/gcc
	rm -rf $(PREFIX_PATH)/m68k-amigaos
	@mkdir -p $(PREFIX_PATH)/bin

# =================================================
# update all projects
# =================================================
ifeq ($(BUILD_TARGET),msys)
.PHONY: update-gmp update-mpc update-mpfr
update: update-gmp update-mpc update-mpfr
endif

.PHONY: update update-gcc update-binutils update-fd2sfd update-fd2pragma update-ira update-sfdc update-vasm update-vbcc update-vlink update-libnix update-ixemul update-clib2 update-libdebug update-libSDL12 update-ndk update-newlib update-netinclude
update: update-gcc update-binutils update-fd2sfd update-fd2pragma update-ira update-sfdc update-vasm update-vbcc update-vlink update-libnix update-ixemul update-clib2 update-libdebug update-libSDL12 update-ndk update-newlib update-netinclude

update-gcc: projects/gcc/configure
	@cd projects/gcc && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-binutils: projects/binutils/configure
	@cd projects/binutils && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-fd2sfd: projects/fd2sfd/configure
	@cd projects/fd2sfd && git pull

update-fd2pragma: projects/fd2pragma/makefile
	@cd projects/fd2pragma && git pull

update-ira: projects/ira/Makefile
	@cd projects/ira && git pull

update-sfdc: projects/sfdc/configure
	@cd projects/sfdc && git pull

update-vasm: projects/vasm/Makefile
	@cd projects/vasm && git pull

update-vbcc: projects/vbcc/Makefile
	@cd projects/vbcc && git pull

update-vlink: projects/vlink/Makefile
	@cd projects/vlink && git pull

update-libnix: projects/libnix/configure
	@cd projects/libnix && git pull

update-ixemul: projects/ixemul/configure
	@cd projects/ixemul && git pull

update-clib2: projects/clib2/LICENSE
	@cd projects/clib2 && git pull

update-libdebug: projects/libdebug/configure
	@cd projects/libdebug && git pull

update-libSDL12: projects/libSDL12/Makefile.bax
	@cd projects/libSDL12 && git pull

update-ndk: download/NDK39.lha
	mkdir -p $(BUILD)
	make projects/NDK_3.9.info

update-newlib: projects/newlib-cygwin/newlib/configure
	@cd projects/newlib-cygwin && git pull

update-netinclude: projects/amiga-netinclude/README.md
	@cd projects/amiga-netinclude && git pull

update-gmp:
	@mkdir -p download
	@mkdir -p projects
	if [ -a download/$(GMPFILE) ]; \
	then rm -rf projects/$(GMP); rm -rf projects/gcc/gmp; \
	else cd download && wget ftp://ftp.gnu.org/gnu/gmp/$(GMPFILE); \
	fi;
	@cd projects && tar xf ../download/$(GMPFILE)
	
update-mpc:
	@mkdir -p download
	@mkdir -p projects
	if [ -a download/$(MPCFILE) ]; \
	then rm -rf projcts/$(MPC); rm -rf projects/gcc/mpc; \
	else cd download && wget ftp://ftp.gnu.org/gnu/mpc/$(MPCFILE); \
	fi;
	@cd projects && tar xf ../download/$(MPCFILE)

update-mpfr:
	@mkdir -p download
	@mkdir -p projects
	if [ -a download/$(MPFRFILE) ]; \
	then rm -rf projects/$(MPFR); rm -rf projects/gcc/mpfr; \
	else cd download && wget ftp://ftp.gnu.org/gnu/mpfr/$(MPFRFILE); \
	fi;
	@cd projects && tar xf ../download/$(MPFRFILE)

status-all:
	GCC_VERSION=$(shell cat 2>/dev/null projects/gcc/gcc/BASE-VER)
# =================================================
# B I N
# =================================================
	
# =================================================
# binutils
# =================================================
CONFIG_BINUTILS :=--prefix=$(PREFIX_TARGET) --target=m68k-amigaos --disable-plugins --disable-werror --enable-tui --disable-nls
BINUTILS_CMD := m68k-amigaos-addr2line m68k-amigaos-ar m68k-amigaos-as m68k-amigaos-c++filt \
	m68k-amigaos-ld m68k-amigaos-nm m68k-amigaos-objcopy m68k-amigaos-objdump m68k-amigaos-ranlib \
	m68k-amigaos-readelf m68k-amigaos-size m68k-amigaos-strings m68k-amigaos-strip
BINUTILS := $(patsubst %,$(PREFIX_PATH)/bin/%$(EXEEXT), $(BINUTILS_CMD))

BINUTILS_DIR := . bfd gas ld binutils opcodes
BINUTILSD := $(patsubst %,projects/binutils/%, $(BINUTILS_DIR))

ifeq ($(findstring Darwin,$(shell uname)),)
ALL_GDB := all-gdb
INSTALL_GDB := install-gdb
endif

binutils: $(BUILD)/binutils/_done

$(BUILD)/binutils/_done: $(BUILD)/binutils/Makefile $(shell find 2>/dev/null projects/binutils -not \( -path projects/binutils/.git -prune \) -not \( -path projects/binutils/gprof -prune \) -type f)
	@touch -t 0001010000 projects/binutils/binutils/arparse.y
	@touch -t 0001010000 projects/binutils/binutils/arlex.l
	@touch -t 0001010000 projects/binutils/ld/ldgram.y
	@touch -t 0001010000 projects/binutils/intl/plural.y
	$(L0)"make binutils"$(L1)$(MAKE) -C $(BUILD)/binutils all-gas all-binutils all-ld $(ALL_GDB) $(L2)
	$(L0)"install binutils"$(L1)$(MAKE) -C $(BUILD)/binutils install-gas install-binutils install-ld $(INSTALL_GDB) $(L2) 
	@echo "done" >$@

$(BUILD)/binutils/Makefile: projects/binutils/configure
	@mkdir -p $(BUILD)/binutils
	$(L0)"configure binutils"$(L1) cd $(BUILD)/binutils && $(E) $(PWD)/projects/binutils/configure $(CONFIG_BINUTILS) $(L2)
	 

projects/binutils/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b $(BINUTILS_BRANCH) --depth 16 $(GIT_BINUTILS) binutils

# =================================================
# gcc
# =================================================
CONFIG_GCC = --prefix=$(PREFIX_TARGET) --target=m68k-amigaos --enable-languages=c,c++,objc --enable-version-specific-runtime-libs --disable-libssp --disable-nls \
	--with-headers=$(PWD)/projects/newlib-cygwin/newlib/libc/sys/amigaos/include/ --disable-shared  --src=../../projects/gcc \
	--with-stage1-ldflags="-dynamic-libgcc -dynamic-libstdc++" --with-boot-ldflags="-dynamic-libgcc -dynamic-libstdc++"


GCC_CMD := m68k-amigaos-c++ m68k-amigaos-g++ m68k-amigaos-gcc-$(GCC_VERSION) m68k-amigaos-gcc-nm \
	m68k-amigaos-gcov m68k-amigaos-gcov-tool m68k-amigaos-cpp m68k-amigaos-gcc m68k-amigaos-gcc-ar \
	m68k-amigaos-gcc-ranlib m68k-amigaos-gcov-dump
GCC := $(patsubst %,$(PREFIX_PATH)/bin/%$(EXEEXT), $(GCC_CMD))

GCC_DIR := . gcc gcc/c gcc/c-family gcc/cp gcc/objc gcc/config/m68k libiberty libcpp libdecnumber
GCCD := $(patsubst %,projects/gcc/%, $(GCC_DIR))

gcc: $(BUILD)/gcc/_done

$(BUILD)/gcc/_done: $(BUILD)/gcc/Makefile $(shell find 2>/dev/null $(GCCD) -maxdepth 1 -type f )
	$(L0)"make gcc"$(L1) $(MAKE) -C $(BUILD)/gcc all-gcc $(L2) 
	$(L0)"install gcc"$(L1) $(MAKE) -C $(BUILD)/gcc install-gcc $(L2) 
	@echo "done" >$@

$(BUILD)/gcc/Makefile: projects/gcc/configure $(BUILD)/binutils/_done
	@mkdir -p $(BUILD)/gcc
ifeq ($(BUILD_TARGET),msys)
	@mkdir -p projects/gcc/gmp
	@mkdir -p projects/gcc/mpc
	@mkdir -p projects/gcc/mpfr
	@rsync -a projects/$(GMP)/* projects/gcc/gmp
	@rsync -a projects/$(MPC)/* projects/gcc/mpc
	@rsync -a projects/$(MPFR)/* projects/gcc/mpfr
endif	
	$(L0)"configure gcc"$(L1) cd $(BUILD)/gcc && $(E) $(PWD)/projects/gcc/configure $(CONFIG_GCC) $(L2) 

projects/gcc/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b $(GCC_BRANCH) --depth 16 $(GIT_GCC)

# =================================================
# gprof
# =================================================
CONFIG_GRPOF := --prefix=$(PREFIX_TARGET) --target=m68k-amigaos --disable-werror

gprof: $(BUILD)/binutils/_gprof

$(BUILD)/binutils/_gprof: $(BUILD)/binutils/gprof/Makefile $(shell find 2>/dev/null projects/binutils/gprof -type f)
	$(L0)"make gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof all $(L2)
	$(L0)"install gprof"$(L1)$(MAKE) -C $(BUILD)/binutils/gprof install $(L2) 
	@echo "done" >$@

$(BUILD)/binutils/gprof/Makefile: projects/binutils/gprof/configure $(BUILD)/binutils/_done
	@mkdir -p $(BUILD)/binutils/gprof
	$(L0)"configure gprof"$(L1) cd $(BUILD)/binutils/gprof && $(E) $(PWD)/projects/binutils/gprof/configure $(CONFIG_GRPOF) $(L2)

# =================================================
# fd2sfd
# =================================================
CONFIG_FD2SFD := --prefix=$(PREFIX_TARGET) --target=m68k-amigaos

fd2sfd: $(BUILD)/fd2sfd/_done

$(BUILD)/fd2sfd/_done: $(PREFIX_PATH)/bin/fd2sfd
	@echo "done" >$@

$(PREFIX_PATH)/bin/fd2sfd: $(BUILD)/fd2sfd/Makefile $(shell find 2>/dev/null projects/fd2sfd -not \( -path projects/fd2sfd/.git -prune \) -type f)
	$(L0)"make fd2sfd"$(L1) $(MAKE) -C $(BUILD)/fd2sfd all $(L2)
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install fd2sfd"$(L1) $(MAKE) -C $(BUILD)/fd2sfd install $(L2)
 
$(BUILD)/fd2sfd/Makefile: projects/fd2sfd/configure
	@mkdir -p $(BUILD)/fd2sfd
	$(L0)"configure fd2sfd"$(L1) cd $(BUILD)/fd2sfd && $(E) $(PWD)/projects/fd2sfd/configure $(CONFIG_FD2SFD) $(L2) 

projects/fd2sfd/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_FD2SFD)
	for i in $$(find patches/fd2sfd/ -type f); \
	do if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "projects/$${j%.diff}" "$$i"; fi ; done

# =================================================
# fd2pragma
# =================================================
fd2pragma: $(BUILD)/fd2pragma/_done

$(BUILD)/fd2pragma/_done: $(PREFIX_PATH)/bin/fd2pragma
	@echo "done" >$@

$(PREFIX_PATH)/bin/fd2pragma: $(BUILD)/fd2pragma/fd2pragma
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install fd2sfd"$(L1) install $(BUILD)/fd2pragma/fd2pragma $(PREFIX_PATH)/bin/ $(L2)

$(BUILD)/fd2pragma/fd2pragma: projects/fd2pragma/makefile $(shell find 2>/dev/null projects/fd2pragma -not \( -path projects/fd2pragma/.git -prune \) -type f)
	@mkdir -p $(BUILD)/fd2pragma
	$(L0)"make fd2sfd"$(L1) cd projects/fd2pragma && $(CC) -o $(PWD)/$@ $(CFLAGS) fd2pragma.c $(L2)

projects/fd2pragma/makefile:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_FD2PRAGMA)

# =================================================
# ira
# =================================================
ira: $(BUILD)/ira/_done

$(BUILD)/ira/_done: $(PREFIX_PATH)/bin/ira
	@echo "done" >$@

$(PREFIX_PATH)/bin/ira: $(BUILD)/ira/ira
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install ira"$(L1) install $(BUILD)/ira/ira $(PREFIX_PATH)/bin/ $(L2)

$(BUILD)/ira/ira: projects/ira/Makefile $(shell find 2>/dev/null projects/ira -not \( -path projects/ira/.git -prune \) -type f)
	@mkdir -p $(BUILD)/ira
	$(L0)"make ira"$(L1) cd projects/ira && $(CC) -o $(PWD)/$@ $(CFLAGS) *.c -std=c99 $(L2)

projects/ira/Makefile:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_IRA)

# =================================================
# sfdc
# =================================================
CONFIG_SFDC := --prefix=$(PREFIX_TARGET) --target=m68k-amigaos

sfdc: $(BUILD)/sfdc/_done

$(BUILD)/sfdc/_done: $(PREFIX_PATH)/bin/sfdc
	@echo "done" >$@

$(PREFIX_PATH)/bin/sfdc: $(BUILD)/sfdc/Makefile $(shell find 2>/dev/null projects/sfdc -not \( -path projects/sfdc/.git -prune \)  -type f)
	$(L0)"make sfdc"$(L1) $(MAKE) -C $(BUILD)/sfdc sfdc $(L2) 
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install sfdc"$(L1) install $(BUILD)/sfdc/sfdc $(PREFIX_PATH)/bin $(L2)

$(BUILD)/sfdc/Makefile: projects/sfdc/configure
	@rsync -a projects/sfdc $(BUILD)/ --exclude .git
	$(L0)"configure sfdc"$(L1) cd $(BUILD)/sfdc && $(E) $(PWD)/$(BUILD)/sfdc/configure $(CONFIG_SFDC) $(L2) 

projects/sfdc/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_SFDC)
	for i in $$(find patches/sfdc/ -type f); \
	do if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "projects/$${j%.diff}" "$$i"; fi ; done

# =================================================
# vasm
# =================================================
VASM_CMD := vasmm68k_mot
VASM := $(patsubst %,$(PREFIX_PATH)/bin/%$(EXEEXT), $(VASM_CMD))

vasm: $(BUILD)/vasm/_done

$(BUILD)/vasm/_done: $(BUILD)/vasm/Makefile 
	$(L0)"make vasm"$(L1) $(MAKE) -C $(BUILD)/vasm CPU=m68k SYNTAX=mot $(L2) 
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install vasm"$(L1) install $(BUILD)/vasm/vasmm68k_mot $(PREFIX_PATH)/bin/ ;\
	install $(BUILD)/vasm/vobjdump $(PREFIX_PATH)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vasm/Makefile: projects/vasm/Makefile $(shell find 2>/dev/null projects/vasm -not \( -path projects/vasm/.git -prune \) -type f)
	@rsync -a projects/vasm $(BUILD)/ --exclude .git
	@touch $(BUILD)/vasm/Makefile

projects/vasm/Makefile:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_VASM)

# =================================================
# vbcc
# =================================================
VBCC_CMD := vbccm68k vprof vc
VBCC := $(patsubst %,$(PREFIX_PATH)/bin/%$(EXEEXT), $(VBCC_CMD))

vbcc: $(BUILD)/vbcc/_done

$(BUILD)/vbcc/_done: $(BUILD)/vbcc/Makefile
	$(L0)"make vbcc dtgen"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc bin/dtgen $(L2)
	@cd $(BUILD)/vbcc && echo -e "y\\ny\\nsigned char\\ny\\nunsigned char\\nn\\ny\\nsigned short\\nn\\ny\\nunsigned short\\nn\\ny\\nsigned int\\nn\\ny\\nunsigned int\\nn\\ny\\nsigned long long\\nn\\ny\\nunsigned long long\\nn\\ny\\nfloat\\nn\\ny\\ndouble\\n" >c.txt
	$(L0)"run vbcc dtgen"$(L1) cd $(BUILD)/vbcc && bin/dtgen machines/m68k/machine.dt machines/m68k/dt.h machines/m68k/dt.c <c.txt $(L2)
	$(L0)"make vbcc"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc $(L2) 
	@mkdir -p $(PREFIX_PATH)/bin/
	@rm -rf $(BUILD)/vbcc/bin/*.dSYM
	$(L0)"install vbcc"$(L1) install $(BUILD)/vbcc/bin/v* $(PREFIX_PATH)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vbcc/Makefile: projects/vbcc/Makefile $(shell find 2>/dev/null projects/vbcc -not \( -path projects/vbcc/.git -prune \) -type f)
	@rsync -a projects/vbcc $(BUILD)/ --exclude .git
	@mkdir -p $(BUILD)/vbcc/bin
	@touch $(BUILD)/vbcc/Makefile

projects/vbcc/Makefile:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_VBCC)

# =================================================
# vlink
# =================================================
VLINK_CMD := vlink
VLINK := $(patsubst %,$(PREFIX_PATH)/bin/%$(EXEEXT), $(VLINK_CMD))

vlink: $(BUILD)/vlink/_done vbcc-target

$(BUILD)/vlink/_done: $(BUILD)/vlink/Makefile $(shell find 2>/dev/null projects/vlink -not \( -path projects/vlink/.git -prune \) -type f)
	$(L0)"make vlink"$(L1) cd $(BUILD)/vlink && TARGET=m68k $(MAKE) $(L2) 
	@mkdir -p $(PREFIX_PATH)/bin/
	$(L0)"install vlink"$(L1) install $(BUILD)/vlink/vlink $(PREFIX_PATH)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vlink/Makefile: projects/vlink/Makefile
	@rsync -a projects/vlink $(BUILD)/ --exclude .git

projects/vlink/Makefile:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_VLINK)

.PHONY: lha
lha: $(BUILD)/_lha_done

$(BUILD)/_lha_done:
	@if [ ! -e "$$(which lha 2>/dev/null)" ]; then \
	  cd $(BUILD) && rm -rf lha; \
	  $(L00)"clone lha"$(L1) git clone $(GIT_LHA); $(L2); \
	  cd lha; \
	  $(L00)"configure lha"$(L1) aclocal; autoheader; automake -a; autoconf; ./configure; $(L2); \
	  $(L00)"make lha"$(L1) make all; $(L2); \
	  $(L00)"install lha"$(L1) mkdir -p $(PREFIX_PATH)/bin/; install src/lha$(EXEEXT) $(PREFIX_PATH)/bin/lha$(EXEEXT); $(L2); \
	fi
	@echo "done" >$@ 


.PHONY: vbcc-target
vbcc-target: $(BUILD)/vbcc_target_m68k-amigaos/_done

$(BUILD)/vbcc_target_m68k-amigaos/_done: $(BUILD)/vbcc_target_m68k-amigaos.info patches/vc.config $(BUILD)/vasm/_done
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/vbcc/include
	$(L0)"copying vbcc headers"$(L1) rsync $(BUILD)/vbcc_target_m68k-amigaos/targets/m68k-amigaos/include/* $(PREFIX_PATH)/m68k-amigaos/vbcc/include $(L2)
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/vbcc/lib
	$(L0)"copying vbcc headers"$(L1) rsync $(BUILD)/vbcc_target_m68k-amigaos/targets/m68k-amigaos/lib/* $(PREFIX_PATH)/m68k-amigaos/vbcc/lib $(L2)
	@echo "done" >$@
	$(L0)"creating vbcc config"$(L1) sed -e "s|PREFIX|$(PREFIX_PATH)|g" patches/vc.config >$(BUILD)/vasm/vc.config ;\
	install $(BUILD)/vasm/vc.config $(PREFIX_PATH)/bin/ $(L2) 
	

$(BUILD)/vbcc_target_m68k-amigaos.info: download/vbcc_target_m68k-amigaos.lha $(BUILD)/_lha_done
	$(L0)"unpack vbcc_target_m68k-amigaos"$(L1) cd $(BUILD) && lha xf ../download/vbcc_target_m68k-amigaos.lha $(L2)
	@touch $(BUILD)/vbcc_target_m68k-amigaos.info

download/vbcc_target_m68k-amigaos.lha:
	$(L0)"downloading vbcc_target"$(L1) cd download && wget http://server.owl.de/~frank/vbcc/2017-08-14/vbcc_target_m68k-amigaos.lha $(L2)

# =================================================
# L I B R A R I E S
# =================================================
# =================================================
# NDK - no git
# =================================================

NDK_INCLUDE = $(shell find 2>/dev/null projects/NDK_3.9/Include/include_h -type f)
NDK_INCLUDE_SFD = $(shell find 2>/dev/null projects/NDK_3.9/Include/sfd -type f -name *.sfd)
NDK_INCLUDE_INLINE = $(patsubst projects/NDK_3.9/Include/sfd/%_lib.sfd,$(PREFIX_PATH)/m68k-amigaos/ndk-include/inline/%.h,$(NDK_INCLUDE_SFD))
NDK_INCLUDE_LVO    = $(patsubst projects/NDK_3.9/Include/sfd/%_lib.sfd,$(PREFIX_PATH)/m68k-amigaos/ndk-include/lvo/%_lib.i,$(NDK_INCLUDE_SFD))
NDK_INCLUDE_PROTO  = $(patsubst projects/NDK_3.9/Include/sfd/%_lib.sfd,$(PREFIX_PATH)/m68k-amigaos/ndk-include/proto/%.h,$(NDK_INCLUDE_SFD))
SYS_INCLUDE2 = $(filter-out $(NDK_INCLUDE_PROTO),$(patsubst projects/NDK_3.9/Include/include_h/%,$(PREFIX_PATH)/m68k-amigaos/ndk-include/%, $(NDK_INCLUDE)))

.PHONY: ndk-inline ndk-lvo ndk-proto

ndk: $(BUILD)/ndk-include_ndk

$(BUILD)/ndk-include_ndk: $(BUILD)/ndk-include_ndk0 $(NDK_INCLUDE_INLINE) $(NDK_INCLUDE_LVO) $(NDK_INCLUDE_PROTO) projects/fd2sfd/configure projects/fd2pragma/makefile
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_ndk0: projects/NDK_3.9.info $(NDK_INCLUDE)
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include
	@rsync -a $(PWD)/projects/NDK_3.9/Include/include_h/* $(PREFIX_PATH)/m68k-amigaos/ndk-include --exclude proto
	@rsync -a $(PWD)/projects/NDK_3.9/Include/include_i/* $(PREFIX_PATH)/m68k-amigaos/ndk-include
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk/lib
	@rsync -a $(PWD)/projects/NDK_3.9/Include/fd $(PREFIX_PATH)/m68k-amigaos/ndk/lib
	@rsync -a $(PWD)/projects/NDK_3.9/Include/sfd $(PREFIX_PATH)/m68k-amigaos/ndk/lib
	@rsync -a $(PWD)/projects/NDK_3.9/Include/linker_libs $(PREFIX_PATH)/m68k-amigaos/ndk/lib
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include/proto
	@cp -p projects/NDK_3.9/Include/include_h/proto/alib.h $(PREFIX_PATH)/m68k-amigaos/ndk-include/proto
	@cp -p projects/NDK_3.9/Include/include_h/proto/cardres.h $(PREFIX_PATH)/m68k-amigaos/ndk-include/proto
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline
	@cp -p projects/fd2sfd/cross/share/m68k-amigaos/alib.h $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline
	@cp -p projects/fd2pragma/Include/inline/stubs.h $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline
	@cp -p projects/fd2pragma/Include/inline/macros.h $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

ndk-inline: $(NDK_INCLUDE_INLINE) sfdc $(BUILD)/ndk-include_inline
$(NDK_INCLUDE_INLINE): $(PREFIX_PATH)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_inline $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc inline $(@F)"$(L1) sfdc --target=m68k-amigaos --mode=macros --output=$@ $(patsubst $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline/%.h,projects/NDK_3.9/Include/sfd/%_lib.sfd,$@) $(L2)

ndk-lvo: $(NDK_INCLUDE_LVO) sfdc
$(NDK_INCLUDE_LVO): $(PREFIX_PATH)/bin/sfdc $(NDK_INCLUDE_SFD) $(BUILD)/ndk-include_lvo $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc lvo $(@F)"$(L1) sfdc --target=m68k-amigaos --mode=lvo --output=$@ $(patsubst $(PREFIX_PATH)/m68k-amigaos/ndk-include/lvo/%_lib.i,projects/NDK_3.9/Include/sfd/%_lib.sfd,$@) $(L2)

ndk-proto: $(NDK_INCLUDE_PROTO) sfdc
$(NDK_INCLUDE_PROTO): $(PREFIX_PATH)/bin/sfdc $(NDK_INCLUDE_SFD)	$(BUILD)/ndk-include_proto $(BUILD)/ndk-include_ndk0
	$(L0)"sfdc proto $(@F)"$(L1) sfdc --target=m68k-amigaos --mode=proto --output=$@ $(patsubst $(PREFIX_PATH)/m68k-amigaos/ndk-include/proto/%.h,projects/NDK_3.9/Include/sfd/%_lib.sfd,$@) $(L2)

$(BUILD)/ndk-include_inline: projects/NDK_3.9.info
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include/inline
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_lvo: projects/NDK_3.9.info
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include/lvo
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/lvo
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

$(BUILD)/ndk-include_proto: projects/NDK_3.9.info
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include/proto
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/proto
	@mkdir -p $(BUILD)/ndk-include/
	@echo "done" >$@

projects/NDK_3.9.info: $(BUILD)/_lha_done download/NDK39.lha $(shell find 2>/dev/null patches/NDK_3.9/ -type f)
	@mkdir -p projects
	@mkdir -p $(BUILD)/
	$(L0)"unpack ndk"$(L1) cd projects && lha xf ../download/NDK39.lha $(L2)
	@touch -t 0001010000 download/NDK39.lha
	$(L0)"patch ndk"$(L1) for i in $$(find patches/NDK_3.9/ -type f); do \
	   if [[ "$$i" == *.diff ]] ; \
		then j=$${i:8}; patch -N "projects/$${j%.diff}" "$$i"; \
		else cp -pv "$$i" "projects/$${i:8}"; fi ; done $(L2)
	@touch projects/NDK_3.9.info

download/NDK39.lha:
	@mkdir -p download
	@cd download && wget http://www.haage-partner.de/download/AmigaOS/NDK39.lha


# =================================================
# NDK1.3 - emulated from NDK
# =================================================
.PHONY: ndk_13
ndk13: $(BUILD)/ndk-include_ndk13

$(BUILD)/ndk-include_ndk13: $(BUILD)/ndk-include_ndk
	@while read p; do mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$(dirname $$p); cp $(PREFIX_PATH)/m68k-amigaos/ndk-include/$$p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$p; done < patches/ndk13/hfiles
	$(L0)"extract ndk13"$(L1) while read p; do \
	  mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$(dirname $$p); \
	  if grep V36 $(PREFIX_PATH)/m68k-amigaos/ndk-include/$$p; then \
	  LC_CTYPE=C sed -n -e '/#ifndef  CLIB/,/V36/p' $(PREFIX_PATH)/m68k-amigaos/ndk-include/$$p >$(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$p; \
	  echo -e "#ifdef __cplusplus\n}\n#endif /* __cplusplus */\n#endif" >>$(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$p; \
	  else cp $(PREFIX_PATH)/m68k-amigaos/ndk-include/$$p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$p; fi \
	done < patches/ndk13/chfiles $(L2)
	@while read p; do mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$(dirname $$p); echo "" >$(PREFIX_PATH)/m68k-amigaos/ndk13-include/$$p; done < patches/ndk13/ehfiles
	@echo '#undef	EXECNAME' > $(PREFIX_PATH)/m68k-amigaos/ndk13-include/exec/execname.h
	@echo '#define	EXECNAME	"exec.library"' >> $(PREFIX_PATH)/m68k-amigaos/ndk13-include/exec/execname.h
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk/lib/fd13
	@while read p; do LC_CTYPE=C sed -n -e '/##base/,/V36/P'  $(PREFIX_PATH)/m68k-amigaos/ndk/lib/fd/$$p >$(PREFIX_PATH)/m68k-amigaos/ndk/lib/fd13/$$p; done < patches/ndk13/fdfiles
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk/lib/sfd13
	@for i in $(PREFIX_PATH)/m68k-amigaos/ndk/lib/fd13/*; do fd2sfd $$i $(PREFIX_PATH)/m68k-amigaos/ndk13-include/clib/$$(basename $$i _lib.fd)_protos.h > $(PREFIX_PATH)/m68k-amigaos/ndk/lib/sfd13/$$(basename $$i .fd).sfd; done
	$(L0)"macros+protos ndk13"$(L1) for i in $(PREFIX_PATH)/m68k-amigaos/ndk/lib/sfd13/*; do \
	  sfdc --target=m68k-amigaos --mode=macros --output=$(PREFIX_PATH)/m68k-amigaos/ndk13-include/inline/$$(basename $$i _lib.sfd).h $$i; \
	  sfdc --target=m68k-amigaos --mode=proto --output=$(PREFIX_PATH)/m68k-amigaos/ndk13-include/proto/$$(basename $$i _lib.sfd).h $$i; \
	done $(L2)
	@echo "done" >$@

# =================================================
# netinclude
# =================================================
$(BUILD)/_netinclude: projects/amiga-netinclude/README.md $(BUILD)/ndk-include_ndk $(shell find 2>/dev/null projects/amiga-netinclude/include -type f)
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/ndk-include
	@rsync -a $(PWD)/projects/amiga-netinclude/include/* $(PREFIX_PATH)/m68k-amigaos/ndk-include
	@echo "done" >$@

projects/amiga-netinclude/README.md: 
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_AMIGA_NETINCLUDE)

# =================================================
# libamiga
# =================================================
LIBAMIGA := $(PREFIX_PATH)/m68k-amigaos/lib/libamiga.a $(PREFIX_PATH)/m68k-amigaos/lib/libb/libamiga.a

libamiga: $(LIBAMIGA)
	@echo "built $(LIBAMIGA)"

$(LIBAMIGA):
	@mkdir -p $(@D)
	@cp -p $(patsubst $(PREFIX_PATH)/m68k-amigaos/%,%,$@) $(@D)

# =================================================
# libnix
# =================================================

CONFIG_LIBNIX := --prefix=$(PREFIX_PATH)/m68k-amigaos/libnix --target=m68k-amigaos --host=m68k-amigaos

LIBNIX_SRC = $(shell find 2>/dev/null projects/libnix -not \( -path projects/libnix/.git -prune \) -not \( -path projects/libnix/sources/stubs/libbases -prune \) -not \( -path projects/libnix/sources/stubs/libnames -prune \) -type f)

libnix: $(BUILD)/libnix/_done

$(BUILD)/libnix/_done: $(BUILD)/libnix/Makefile
	$(L0)"make libnix"$(L1) $(MAKE) -C $(BUILD)/libnix $(L2) 
	$(L0)"install libnix"$(L1) $(MAKE) -C $(BUILD)/libnix install $(L2)
	@cd $(BUILD)/newlib/complex && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libb/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020 && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libm020/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libm020/libb/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020/libb32 && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libm020/libb32/libm.a $(COMPLEX_FILES)
	@echo "done" >$@
		
$(BUILD)/libnix/Makefile: $(BUILD)/newlib/_done $(BUILD)/ndk-include_ndk $(BUILD)/ndk-include_ndk13 $(BUILD)/_netinclude $(BUILD)/binutils/_done $(BUILD)/gcc/_done projects/libnix/configure projects/libnix/Makefile.in $(LIBAMIGA) $(LIBNIX_SRC)
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/libnix/lib/libnix 
	@mkdir -p $(BUILD)/libnix
	@echo 'void foo(){}' > $(BUILD)/libnix/x.c
	@if [ ! -e $(PREFIX_PATH)/m68k-amigaos/lib/libstubs.a ]; then $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/lib/libstubs.a; fi
	@mkdir -p $(PREFIX_PATH)/lib/gcc/m68k-amigaos/$(GCC_VERSION)
	@if [ ! -e $(PREFIX_PATH)/lib/gcc/m68k-amigaos/$(GCC_VERSION)/libgcc.a ]; then $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/lib/gcc/m68k-amigaos/$(GCC_VERSION)/libgcc.a; fi
	$(L0)"configure libnix"$(L1) cd $(BUILD)/libnix && CFLAGS="$(CFLAGS_FOR_TARGET)" AR=m68k-amigaos-ar AS=m68k-amigaos-as CC=m68k-amigaos-gcc $(A) $(PWD)/projects/libnix/configure $(CONFIG_LIBNIX) $(L2) 
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/libnix/include/
	@rsync -a projects/libnix/sources/headers/* $(PREFIX_PATH)/m68k-amigaos/libnix/include/
	@touch $(BUILD)/libnix/Makefile
	
projects/libnix/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_LIBNIX)

# =================================================
# gcc libs
# =================================================
LIBGCCS_NAMES := libgcov.a libstdc++.a libsupc++.a
LIBGCCS := $(patsubst %,$(PREFIX_PATH)/lib/gcc/m68k-amigaos/$(GCC_VERSION)/%,$(LIBGCCS_NAMES))

libgcc: $(BUILD)/gcc/_libgcc_done

$(BUILD)/gcc/_libgcc_done: $(BUILD)/libnix/_done $(LIBAMIGA) $(shell find 2>/dev/null projects/gcc/libgcc -type f)
	$(L0)"make libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc all-target $(L2) 
	$(L0)"install libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc install-target $(L2)
	@echo "done" >$@

# =================================================
# clib2
# =================================================

clib2: $(BUILD)/clib2/_done

$(BUILD)/clib2/_done: projects/clib2/LICENSE $(shell find 2>/dev/null projects/clib2 -not \( -path projects/clib2/.git -prune \) -type f) $(BUILD)/libnix/Makefile $(LIBAMIGA)
	@mkdir -p $(BUILD)/clib2/
	@rsync -a projects/clib2/library/* $(BUILD)/clib2
	@cd $(BUILD)/clib2 && find * -name lib\*.a -delete
	$(L0)"make clib2"$(L1) $(MAKE) -C $(BUILD)/clib2 -f GNUmakefile.68k $(L2) 
	@mkdir -p $(PREFIX_PATH)/m68k-amigaos/clib2
	@rsync -a $(BUILD)/clib2/include $(PREFIX_PATH)/m68k-amigaos/clib2
	@rsync -a $(BUILD)/clib2/lib $(PREFIX_PATH)/m68k-amigaos/clib2
	@cd $(BUILD)/newlib/complex && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/clib2/lib/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/clib2/lib/libb/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020 && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/clib2/lib/libm020/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/clib2/lib/libm020/libb/libm.a $(COMPLEX_FILES)
	@cd $(BUILD)/newlib/complex/libm020/libb32 && $(PREFIX_PATH)/bin/m68k-amigaos-ar rcs $(PREFIX_PATH)/m68k-amigaos/clib2/lib/libm020/libb32/libm.a $(COMPLEX_FILES)
	@echo "done" >$@	

projects/clib2/LICENSE:
	@mkdir -p projects
	@cd projects && git clone -b master --depth 4 $(GIT_CLIB2)

# =================================================
# libdebug
# =================================================
CONFIG_LIBDEBUG := --prefix=$(PREFIX_PATH) --target=m68k-amigaos --host=m68k-amigaos

libdebug: $(BUILD)/libdebug/_done

$(BUILD)/libdebug/_done: $(BUILD)/libdebug/Makefile
	$(L0)"make libdebug"$(L1) $(MAKE) -C $(BUILD)/libdebug $(L2) 
	@cp $(BUILD)/libdebug/libdebug.a $(PREFIX_PATH)/m68k-amigaos/lib/
	@echo "done" >$@

$(BUILD)/libdebug/Makefile: $(BUILD)/libnix/_done projects/libdebug/configure $(shell find 2>/dev/null projects/libdebug -not \( -path projects/libdebug/.git -prune \) -type f)
	@mkdir -p $(BUILD)/libdebug
	$(L0)"configure libdebug"$(L1) cd $(BUILD)/libdebug && LD=m68k-amigaos-ld CC=m68k-amigaos-gcc CFLAGS="$(CFLAGS_FOR_TARGET)" $(PWD)/projects/libdebug/configure $(CONFIG_LIBDEBUG) $(L2)

projects/libdebug/configure:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4 $(GIT_LIBDEBUG)
	@touch -t 0001010000 projects/libdebug/configure.ac

# =================================================
# libsdl
# =================================================
CONFIG_LIBSDL12 := PREFX=$(PREFIX_PATH) PREF=$(PREFIX_PATH)

libSDL12: $(BUILD)/libSDL12/_done

$(BUILD)/libSDL12/_done: $(BUILD)/libSDL12/Makefile.bax
	$(MAKE) sdk=ahi 
	$(MAKE) sdk=cgx 
	$(L0)"make libSDL12"$(L1) cd $(BUILD)/libSDL12 && CFLAGS="$(CFLAGS_FOR_TARGET)" $(MAKE) -f Makefile.bax $(CONFIG_LIBSDL12) $(L2) 
	$(L0)"install libSDL12"$(L1) cp $(BUILD)/libSDL12/libSDL.a $(PREFIX_PATH)/m68k-amigaos/lib/ $(L2)
	@mkdir -p $(PREFIX_PATH)/include/GL
	@mkdir -p $(PREFIX_PATH)/include/SDL
	@rsync -a $(BUILD)/libSDL12/include/GL/*.i $(PREFIX_PATH)/include/GL/
	@rsync -a $(BUILD)/libSDL12/include/GL/*.h $(PREFIX_PATH)/include/GL/
	@rsync -a $(BUILD)/libSDL12/include/SDL/*.h $(PREFIX_PATH)/include/SDL/
	@echo "done" >$@

$(BUILD)/libSDL12/Makefile.bax: $(BUILD)/libnix/_done projects/libSDL12/Makefile.bax $(shell find 2>/dev/null projects/libSDL12 -not \( -path projects/libSDL12/.git -prune \) -type f)
	@mkdir -p $(BUILD)/libSDL12
	@rsync -a projects/libSDL12/* $(BUILD)/libSDL12
	@touch $(BUILD)/libSDL12/Makefile.bax

projects/libSDL12/Makefile.bax:
	@mkdir -p projects
	@cd projects &&	git clone -b master --depth 4  $(GIT_LIBSDL12)


# =================================================
# newlib
# =================================================
NEWLIB_CONFIG := CC=m68k-amigaos-gcc CXX=m68k-amigaos-g++
NEWLIB_FILES = $(shell find 2>/dev/null projects/newlib-cygwin/newlib -type f)

.PHONY: newlib
newlib: $(BUILD)/newlib/_done

COMPLEX_FILES = lib_a-cabs.o   lib_a-cacosf.o   lib_a-cacosl.o  lib_a-casin.o    lib_a-casinhl.o  lib_a-catanh.o   lib_a-ccos.o    lib_a-ccoshl.o        lib_a-cephes_subrl.o  lib_a-cimag.o   lib_a-clog10.o   lib_a-conj.o   lib_a-cpowf.o   lib_a-cprojl.o  lib_a-csin.o    lib_a-csinhl.o  lib_a-csqrtl.o  lib_a-ctanhf.o \
	lib_a-cabsf.o  lib_a-cacosh.o   lib_a-carg.o    lib_a-casinf.o   lib_a-casinl.o   lib_a-catanhf.o  lib_a-ccosf.o   lib_a-ccosl.o         lib_a-cexp.o          lib_a-cimagf.o  lib_a-clog10f.o  lib_a-conjf.o  lib_a-cpowl.o   lib_a-creal.o   lib_a-csinf.o   lib_a-csinl.o   lib_a-ctan.o    lib_a-ctanhl.o \
	lib_a-cabsl.o  lib_a-cacoshf.o  lib_a-cargf.o   lib_a-casinh.o   lib_a-catan.o    lib_a-catanhl.o  lib_a-ccosh.o   lib_a-cephes_subr.o   lib_a-cexpf.o         lib_a-cimagl.o  lib_a-clogf.o    lib_a-conjl.o  lib_a-cproj.o   lib_a-crealf.o  lib_a-csinh.o   lib_a-csqrt.o   lib_a-ctanf.o   lib_a-ctanl.o \
	lib_a-cacos.o  lib_a-cacoshl.o  lib_a-cargl.o   lib_a-casinhf.o  lib_a-catanf.o   lib_a-catanl.o   lib_a-ccoshf.o  lib_a-cephes_subrf.o  lib_a-cexpl.o         lib_a-clog.o    lib_a-clogl.o    lib_a-cpow.o   lib_a-cprojf.o  lib_a-creall.o  lib_a-csinhf.o  lib_a-csqrtf.o  lib_a-ctanh.o 

$(BUILD)/newlib/_done: $(BUILD)/newlib/newlib/libc.a 
	@echo "done" >$@

$(BUILD)/newlib/newlib/libc.a: $(BUILD)/newlib/newlib/Makefile $(BUILD)/ndk-include_ndk $(NEWLIB_FILES)
	$(L0)"make newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib $(L2) 
	$(L0)"install newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib install $(L2) 
	@mkdir -p $(BUILD)/newlib/complex
	@cd $(BUILD)/newlib/complex && $(PREFIX_PATH)/bin/m68k-amigaos-ar x $(PREFIX_PATH)/m68k-amigaos/lib/libm.a $(COMPLEX_FILES)
	@mkdir -p $(BUILD)/newlib/complex/libb
	@cd $(BUILD)/newlib/complex/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar x $(PREFIX_PATH)/m68k-amigaos/lib/libb/libm.a $(COMPLEX_FILES)
	@mkdir -p $(BUILD)/newlib/complex/libm020
	@cd $(BUILD)/newlib/complex/libm020 && $(PREFIX_PATH)/bin/m68k-amigaos-ar x $(PREFIX_PATH)/m68k-amigaos/lib/libm020/libm.a $(COMPLEX_FILES)
	@mkdir -p $(BUILD)/newlib/complex/libm020/libb
	@cd $(BUILD)/newlib/complex/libm020/libb && $(PREFIX_PATH)/bin/m68k-amigaos-ar x $(PREFIX_PATH)/m68k-amigaos/lib/libm020/libb/libm.a $(COMPLEX_FILES)
	@mkdir -p $(BUILD)/newlib/complex/libm020/libb32
	@cd $(BUILD)/newlib/complex/libm020/libb32 && $(PREFIX_PATH)/bin/m68k-amigaos-ar x $(PREFIX_PATH)/m68k-amigaos/lib/libm020/libb32/libm.a $(COMPLEX_FILES)
	@touch $@

ifeq (,$(wildcard $(BUILD)/gcc/_done))
$(BUILD)/newlib/newlib/Makefile: $(BUILD)/gcc/_done
endif

$(BUILD)/newlib/newlib/Makefile: projects/newlib-cygwin/configure  
	@mkdir -p $(BUILD)/newlib/newlib
	@rsync -a $(PWD)/projects/newlib-cygwin/newlib/libc/include/ $(PREFIX_PATH)/m68k-amigaos/sys-include
	$(L0)"configure newlib"$(L1) cd $(BUILD)/newlib/newlib && $(NEWLIB_CONFIG) CFLAGS="$(CFLAGS_FOR_TARGET)" CXXFLAGS="$(CXXFLAGS_FOR_TARGET)" $(PWD)/projects/newlib-cygwin/newlib/configure --host=m68k-amigaos --prefix=$(PREFIX) --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-reent-small --enable-newlib-mb $(L2)

projects/newlib-cygwin/newlib/configure: 
	@mkdir -p projects
	@cd projects &&	git clone -b amiga --depth 4  $(GIT_NEWLIB_CYGWIN)

# =================================================
# ixemul
# =================================================
projects/ixemul/configure:
	@mkdir -p projects
	@cd projects &&	git clone $(GIT_IXEMUL)

# =================================================
# sdk installation
# =================================================
.PHONY: sdk all-sdk
sdk: libnix $(BUILD)/_lha_done
	$(L0)"sdk $(sdk)"$(L1) $(PWD)/sdk/install install $(sdk) $(PREFIX_PATH) $(L2)

SDKS0=$(shell find sdk/*.sdk)
SDKS=$(patsubst sdk/%.sdk,%,$(SDKS0))
.PHONY: $(SDKS)
all-sdk: $(SDKS)

$(SDKS): libnix
	$(MAKE) sdk=$@ 

# =================================================
# update repos
# =================================================
.PHONY: update-repos
update-repos:
	@cd projects/amiga-netinclude && $(UPDATE)$(GIT_AMIGA_NETINCLUDE)$(ANDPULL)
	@cd projects/binutils         && $(UPDATE)$(GIT_BINUTILS)$(ANDPULL)
	@cd projects/clib2            && $(UPDATE)$(GIT_CLIB2)$(ANDPULL)
	@cd projects/fd2pragma        && $(UPDATE)$(GIT_FD2PRAGMA)$(ANDPULL)
	@cd projects/fd2sfd           && $(UPDATE)$(GIT_FD2SFD)$(ANDPULL)
	@cd projects/gcc              && $(UPDATE)$(GIT_GCC)$(ANDPULL)
	@cd projects/ira              && $(UPDATE)$(GIT_IRA)$(ANDPULL)
	@cd projects/ixemul           && $(UPDATE)$(GIT_IXEMUL)$(ANDPULL)
#	@cd projects/lha              && $(UPDATE)$(GIT_LHA)$(ANDPULL)
	@cd projects/libdebug         && $(UPDATE)$(GIT_LIBDEBUG)$(ANDPULL)
	@cd projects/libnix           && $(UPDATE)$(GIT_LIBNIX)$(ANDPULL)
	@cd projects/libsdl12         && $(UPDATE)$(GIT_LIBSDL12)$(ANDPULL)
	@cd projects/newlib-cygwin    && $(UPDATE)$(GIT_NEWLIB_CYGWIN)$(ANDPULL)
	@cd projects/sfdc             && $(UPDATE)$(GIT_SFDC)$(ANDPULL)
	@cd projects/vasm             && $(UPDATE)$(GIT_VASM)$(ANDPULL)
	@cd projects/vbcc             && $(UPDATE)$(GIT_VBCC)$(ANDPULL)
	@cd projects/vlink            && $(UPDATE)$(GIT_VLINK)$(ANDPULL)


# =================================================
# Copy needed dll files
# =================================================

install-dll: $(BUILD)/_installdll_done

$(BUILD)/_installdll_done: $(BUILD)/newlib/_done
ifeq ($(BUILD_TARGET),msys)
	rsync /usr/bin/msys-2.0.dll $(PREFIX_PATH)/bin
	rsync /usr/bin/msys-2.0.dll $(PREFIX_PATH)/libexec/gcc/m68k-amigaos/$(GCC_VERSION)
	rsync /usr/bin/msys-2.0.dll $(PREFIX_PATH)/m68k-amigaos/bin
	rsync /usr/bin/msys-stdc++-6.dll $(PREFIX_PATH)/bin
	rsync /usr/bin/msys-stdc++-6.dll $(PREFIX_PATH)/libexec/gcc/m68k-amigaos/$(GCC_VERSION)
	rsync /usr/bin/msys-stdc++-6.dll $(PREFIX_PATH)/m68k-amigaos/bin
	rsync /usr/bin/msys-gcc_s-seh-1.dll $(PREFIX_PATH)/bin
	rsync /usr/bin/msys-gcc_s-seh-1.dll $(PREFIX_PATH)/libexec/gcc/m68k-amigaos/$(GCC_VERSION)
	rsync /usr/bin/msys-gcc_s-seh-1.dll $(PREFIX_PATH)/m68k-amigaos/bin

endif
	echo "done" >$@
	touch $@

# =================================================
# info
# =================================================
.PHONY: info v r
info:
	@echo $@ $(UNAME_S)
	@echo PREFIX=$(PREFIX_PATH)
	@echo GCC_GIT=$(GCC_GIT)
	@echo GCC_BRANCH=$(GCC_BRANCH)
	@echo GCC_VERSION=$(GCC_VERSION)
	@echo CFLAGS=$(CFLAGS)
	@echo CFLAGS_FOR_TARGET=$(CFLAGS_FOR_TARGET)
	@echo BINUTILS_GIT=$(BINUTILS_GIT)
	@echo BINUTILS_BRANCH=$(BINUTILS_BRANCH)
	@$(CC) -v -E - </dev/null |& grep " version "
	@$(CXX) -v -E - </dev/null |& grep " version "
	@echo $(BUILD)

v:
	@for i in projects/* ; do cd $$i 2>/dev/null && echo $$i && (git log -n1 --pretty=oneline) && cd ../..; done
	@echo "." && git log -n1 --pretty=oneline

r:
	@for i in projects/* ; do cd $$i 2>/dev/null && echo $$i && (git remote -v) && cd ../..; done
	@echo "." && git remote -v
