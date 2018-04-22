#  Makefile for buildroot2
#
# Copyright (C) 1999-2005 by Erik Andersen <andersen@codepoet.org>
# Copyright (C) 2006-2012 by the Buildroot developers <buildroot@uclibc.org>
# Copyright (C) 2013-2014 by Blacker <liujh@nationalchip.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

#--------------------------------------------------------------
# Just run 'make menuconfig', configure stuff, then run 'make'.
# You shouldn't need to mess with anything beyond this point...
#--------------------------------------------------------------

# Set and export the version string
export BR2_VERSION:=2013.03.20_REL

# Check for minimal make version (note: this check will break at make 10.x)
MIN_MAKE_VERSION=3.81
ifneq ($(firstword $(sort $(MAKE_VERSION) $(MIN_MAKE_VERSION))),$(MIN_MAKE_VERSION))
$(error You have make '$(MAKE_VERSION)' installed. GNU make >= $(MIN_MAKE_VERSION) is required)
endif

export HOSTARCH := $(shell uname -m | \
	sed -e s/i.86/x86/ \
	    -e s/sun4u/sparc64/ \
	    -e s/arm.*/arm/ \
	    -e s/sa110/arm/ \
	    -e s/ppc64/powerpc/ \
	    -e s/ppc/powerpc/ \
	    -e s/macppc/powerpc/\
	    -e s/sh.*/sh/)

# This top-level Makefile can *not* be executed in parallel
.NOTPARALLEL:

# absolute path
TOPDIR:=$(shell pwd)
CONFIG_CONFIG_IN=Config.in
CONFIG_CONFIG_IN_PROTECT=Config.in.protect
CONFIG=tools/support/kconfig
DATE:=$(shell date +%Y%m%d)

# Compute the full local version string so packages can use it as-is
# Need to export it, so it can be got from environment in children (eg. mconf)
export BR2_VERSION_FULL:=$(BR2_VERSION)$(shell $(TOPDIR)/tools/support/scripts/setlocalversion)

noconfig_targets:=menuconfig nconfig config\
	defconfig %_defconfig release %_release\
	print-version

# Strip quotes and then whitespaces
qstrip=$(strip $(subst ",,$(1)))
#"))

# Variables for use in Make constructs
comma:=,
empty:=
space:=$(empty) $(empty)

ifneq ("$(origin O)", "command line")
O:=output
CONFIG_DIR:=$(TOPDIR)
NEED_WRAPPER=
else
# other packages might also support Linux-style out of tree builds
# with the O=<dir> syntax (E.G. Busybox does). As make automatically
# forwards command line variable definitions those packages get very
# confused. Fix this by telling make to not do so
MAKEOVERRIDES =
# strangely enough O is still passed to submakes with MAKEOVERRIDES
# (with make 3.81 atleast), the only thing that changes is the output
# of the origin function (command line -> environment).
# Unfortunately some packages don't look at origin (E.G. uClibc 0.9.31+)
# To really make O go away, we have to override it.
override O:=$(O)
CONFIG_DIR:=$(O)
# we need to pass O= everywhere we call back into the toplevel makefile
EXTRAMAKEARGS = O=$(O)
NEED_WRAPPER=y
endif

# Pull in the user's configuration file
ifeq ($(filter $(noconfig_targets),$(MAKECMDGOALS)),)
-include $(CONFIG_DIR)/.config
endif

# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands
ifdef V
  ifeq ("$(origin V)", "command line")
    KBUILD_VERBOSE=$(V)
  endif
endif
ifndef KBUILD_VERBOSE
  KBUILD_VERBOSE=0
endif

ifeq ($(KBUILD_VERBOSE),1)
  quiet=
  Q=
ifndef VERBOSE
  VERBOSE=1
endif
else
  quiet=quiet_
  Q=@
endif

# we want bash as shell
SHELL:=$(shell if [ -x "$$BASH" ]; then echo $$BASH; \
	else if [ -x /bin/bash ]; then echo /bin/bash; \
	else echo sh; fi; fi)

# kconfig uses CONFIG_SHELL
CONFIG_SHELL:=$(SHELL)

export SHELL CONFIG_SHELL quiet Q KBUILD_VERBOSE VERBOSE

ifndef HOSTAR
HOSTAR:=ar
endif
ifndef HOSTAS
HOSTAS:=as
endif
ifndef HOSTCC
HOSTCC:=gcc
HOSTCC:=$(shell which $(HOSTCC) || type -p $(HOSTCC) || echo gcc)
endif
HOSTCC_NOCCACHE:=$(HOSTCC)
ifndef HOSTCXX
HOSTCXX:=g++
HOSTCXX:=$(shell which $(HOSTCXX) || type -p $(HOSTCXX) || echo g++)
endif
HOSTCXX_NOCCACHE:=$(HOSTCXX)
ifndef HOSTFC
HOSTFC:=gfortran
endif
ifndef HOSTCPP
HOSTCPP:=cpp
endif
ifndef HOSTLD
HOSTLD:=ld
endif
ifndef HOSTLN
HOSTLN:=ln
endif
ifndef HOSTNM
HOSTNM:=nm
endif
HOSTAR:=$(shell which $(HOSTAR) || type -p $(HOSTAR) || echo ar)
HOSTAS:=$(shell which $(HOSTAS) || type -p $(HOSTAS) || echo as)
HOSTFC:=$(shell which $(HOSTLD) || type -p $(HOSTLD) || echo || which g77 || type -p g77 || echo gfortran)
HOSTCPP:=$(shell which $(HOSTCPP) || type -p $(HOSTCPP) || echo cpp)
HOSTLD:=$(shell which $(HOSTLD) || type -p $(HOSTLD) || echo ld)
HOSTLN:=$(shell which $(HOSTLN) || type -p $(HOSTLN) || echo ln)
HOSTNM:=$(shell which $(HOSTNM) || type -p $(HOSTNM) || echo nm)

export HOSTAR HOSTAS HOSTCC HOSTCXX HOSTFC HOSTLD
export HOSTCC_NOCCACHE HOSTCXX_NOCCACHE

# Make sure pkg-config doesn't look outside the buildroot tree
unexport PKG_CONFIG_PATH
unexport PKG_CONFIG_SYSROOT_DIR

# Having DESTDIR set in the environment confuses the installation
# steps of some packages.
unexport DESTDIR

# bash prints the name of the directory on 'cd <dir>' if CDPATH is
# set, so unset it here to not cause problems. Notice that the export
# line doesn't affect the environment of $(shell ..) calls, so
# explictly throw away any output from 'cd' here.
export CDPATH:=
BASE_DIR := $(shell mkdir -p $(O) && cd $(O) >/dev/null && pwd)
$(if $(BASE_DIR),, $(error output directory "$(O)" does not exist))

BUILD_DIR:=$(BASE_DIR)
export BUILD_DIR
OUTPUT_DIR:=$(BASE_DIR)
export OUTPUT_DIR

ifeq ($(BR2_HAVE_DOT_CONFIG),y)

#############################################################
#
# Hide troublesome environment variables from sub processes
#
#############################################################
#unexport CROSS_COMPILE
#unexport ARCH
#unexport CC
#unexport CXX
#unexport CPP
#unexport CFLAGS
#unexport CXXFLAGS
#unexport GREP_OPTIONS
#unexport CONFIG_SITE
#unexport QMAKESPEC

GNU_HOST_NAME:=$(shell tools/support/gnuconfig/config.guess)

##############################################################
#
# The list of stuff to build for the target toolchain
# along with the packages to build for the target.
#
##############################################################

ifeq ($(BR2_CCACHE),y)
BASE_TARGETS += host-ccache
endif

TARGETS:=

# silent mode requested?
QUIET:=$(if $(findstring s,$(MAKEFLAGS)),-q)

# Strip off the annoying quoting
ARCH:=$(call qstrip,$(BR2_ARCH))

KERNEL_ARCH:=$(shell echo "$(ARCH)" | sed -e "s/-.*//" \
	-e s/i.86/i386/ -e s/sun4u/sparc64/ \
	-e s/arm.*/arm/ -e s/sa110/arm/ \
	-e s/aarch64/arm64/ \
	-e s/bfin/blackfin/ \
	-e s/parisc64/parisc/ \
	-e s/powerpc64/powerpc/ \
	-e s/ppc.*/powerpc/ -e s/mips.*/mips/ \
	-e s/sh.*/sh/)

# packages compiled for the host go here
HOST_DIR:=$(call qstrip,$(BR2_HOST_DIR))

# locales to generate
GENERATE_LOCALE=$(call qstrip,$(BR2_GENERATE_LOCALE))

TARGET_DIR:=$(BASE_DIR)/

# Location of a file giving a big fat warning that output/target
# should not be used as the root filesystem.
TARGET_DIR_WARNING_FILE=$(TARGET_DIR)/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM

ifeq ($(BR2_CCACHE),y)
CCACHE:=$(HOST_DIR)/usr/bin/ccache
BUILDROOT_CACHE_DIR = $(call qstrip,$(BR2_CCACHE_DIR))
export BUILDROOT_CACHE_DIR
HOSTCC  := $(CCACHE) $(HOSTCC)
HOSTCXX := $(CCACHE) $(HOSTCXX)
endif

#############################################################
#
# You should probably leave this stuff alone unless you know
# what you are doing.
#
#############################################################

all: env build_elf 


# host-* dependencies have to be handled specially, as those aren't
# visible in Kconfig and hence not added to a variable like TARGETS.
# instead, find all the host-* targets listed in each <PKG>_DEPENDENCIES
# variable for each enabled target.
# Notice: this only works for newstyle gentargets/autotargets packages
TARGETS_HOST_DEPS = $(sort $(filter host-%,$(foreach dep,\
		$(addsuffix _DEPENDENCIES,$(call UPPERCASE,$(TARGETS))),\
		$($(dep)))))
# Host packages can in turn have their own dependencies. Likewise find
# all the package names listed in the HOST_<PKG>_DEPENDENCIES for each
# host package found above. Ideally this should be done recursively until
# no more packages are found, but that's hard to do in make, so limit to
# 1 level for now.
HOST_DEPS = $(sort $(foreach dep,\
		$(addsuffix _DEPENDENCIES,$(call UPPERCASE,$(TARGETS_HOST_DEPS))),\
		$($(dep))))
HOST_SOURCE += $(addsuffix -source,$(sort $(TARGETS_HOST_DEPS) $(HOST_DEPS)))

TARGETS_LEGAL_INFO:=$(patsubst %,%-legal-info,\
		$(TARGETS) $(BASE_TARGETS) $(TARGETS_HOST_DEPS) $(HOST_DEPS))))

# all targets depend on the crosscompiler and it's prerequisites
$(TARGETS_ALL): __real_tgt_%: $(BASE_TARGETS) %

dirs: $(TOOLCHAIN_DIR) $(BUILD_DIR) $(STAGING_DIR) $(TARGET_DIR) \
	$(HOST_DIR) $(BINARIES_DIR) $(STAMP_DIR)

$(BASE_TARGETS): dirs $(HOST_DIR)/usr/share/buildroot/toolchainfile.cmake

$(BUILD_DIR)/config/auto.conf: $(CONFIG_DIR)/.config
	$(MAKE) $(EXTRAMAKEARGS) HOSTCC="$(HOSTCC_NOCCACHE)" HOSTCXX="$(HOSTCXX_NOCCACHE)" silentoldconfig

prepare: $(BUILD_DIR)/config/auto.conf

world: prepare dirs dependencies $(BASE_TARGETS) $(TARGETS_ALL)

##############################################################################
#
# for DVB-S2 HD Application
#
#
##############################################################################

##############################################################################
# Set Chip Arch
##############################################################################
ifeq ($(BR2_CHIP_GX6602), y)
ARCH:=csky
CHIP:=GX6602
endif

ifeq ($(BR2_CHIP_GX6601), y)
ARCH:=csky
CHIP:=GX6601
endif

ifeq ($(BR2_CHIP_GX3201), y)
ARCH:=csky
CHIP:=GX3201
endif

ifeq ($(BR2_CHIP_GX3200), y)
ARCH:=arm
CHIP:=GX3200
endif

ifeq ($(BR2_CHIP_GX3113B), y)
ARCH:=arm
CHIP:=GX3113
endif
##############################################################################
# Set Operating System
##############################################################################
ifeq ($(BR2_OS_ECOS), y)
OS:=ecos
endif

ifeq ($(BR2_OS_LINUX), y)
OS:=linux
endif

CROSS_PATH:=$(ARCH)-$(OS)
GXLIB_PATH:=$(OPT)/opt/goxceed/$(CROSS_PATH)
GXSRC_PATH:=$(shell pwd)

export ARCH
export OS
export CHIP
export GXSRC_PATH
export GXLIB_PATH

export BR2_FAMILY_NAME
export BR2_PROJ_NAME

SUBDIRS=app

##############################################################################
-include  $(GXSRC_PATH)/scripts/inc.Makefile.conf.mak
##############################################################################

print_debug:
	echo $(ARCH)
	echo $(OS)
	echo $(CROSS_PATH)
	echo $(GXLIB_PATH)
	echo $(GXSRC_PATH)

#----------------------------------------------------ecos
#build tag for ecos
ifeq ($(OS), ecos)
build_elf:post_config subdirs
	#mkdir -p output
	#mkdir -p output/objects
	#-rm -f output/out.elf
	#cp ./app/out.elf output -f
	echo "build ok..."

endif
#---------------------------------------------------------

#----------------------------------------------------linux
#build tag for linux
ifeq ($(OS), linux)

#USERDIR=$(shell whoami)
USERDIR=dvb

build_elf:post_config subdirs
	#mkdir -p output
	#-rm -f output/out.elf
	#cp ./app/out.elf output -f
	echo "build app ok. see output directory"

endif
	
.PHONY: build_elf print_debug bin all world dirs clean distclean outputmakefile \
	post_config protect_config prepare_config \
	$(BUILD_DIR)  $(TARGET_DIR) $(HOST_DIR)
 

$(BUILD_DIR)/.root:
	mkdir -p $(TARGET_DIR)
	if ! [ -d "$(TARGET_DIR)/bin" ]; then \
		if [ -d "$(TARGET_SKELETON)" ]; then \
			cp -fa $(TARGET_SKELETON)/* $(TARGET_DIR)/; \
		fi; \
	fi
	cp support/misc/target-dir-warning.txt $(TARGET_DIR_WARNING_FILE)
	-find $(TARGET_DIR) -type d -name CVS -print0 -o -name .svn -print0 | xargs -0 rm -rf
	-find $(TARGET_DIR) -type f \( -name .empty -o -name '*~' \) -print0 | xargs -0 rm -rf
	touch $@

$(TARGET_DIR): $(BUILD_DIR)/.root

show-targets:
	@echo $(TARGETS)

else # ifeq ($(BR2_HAVE_DOT_CONFIG),y)

all: menuconfig

# configuration
# ---------------------------------------------------------------------------

HOSTCFLAGS=$(CFLAGS_FOR_BUILD)
export HOSTCFLAGS

$(BUILD_DIR)/config/%onf:
	mkdir -p $(@D)/lxdialog
	$(MAKE) CC="$(HOSTCC_NOCCACHE)" HOSTCC="$(HOSTCC_NOCCACHE)" obj=$(@D) -C $(CONFIG) -f Makefile.br $(@F)

COMMON_CONFIG_ENV = \
	KCONFIG_AUTOCONFIG=$(BUILD_DIR)/config/auto.conf \
	KCONFIG_AUTOHEADER=$(BUILD_DIR)/config/autoconf.h \
	KCONFIG_TRISTATE=$(BUILD_DIR)/config/tristate.config \
	BUILDROOT_CONFIG=$(CONFIG_DIR)/.config


menuconfig :$(BUILD_DIR)/config/mconf prepare_config outputmakefile 
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

nconfig : $(BUILD_DIR)/config/nconf prepare_config outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

config : $(BUILD_DIR)/config/conf prepare_config outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN)

oldconfig: $(BUILD_DIR)/config/conf outputmakefile
	mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --oldconfig $(CONFIG_CONFIG_IN)

randconfig: $(BUILD_DIR)/config/conf outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --randconfig $(CONFIG_CONFIG_IN)

allyesconfig: $(BUILD_DIR)/config/conf outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --allyesconfig $(CONFIG_CONFIG_IN)

allnoconfig: $(BUILD_DIR)/config/conf outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --allnoconfig $(CONFIG_CONFIG_IN)

defconfig: $(BUILD_DIR)/config/conf outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --defconfig$(if $(BR2_DEFCONFIG),=$(BR2_DEFCONFIG)) $(CONFIG_CONFIG_IN)

%_defconfig: $(BUILD_DIR)/config/conf prepare_config $(TOPDIR)/configs/%_defconfig outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --defconfig=$(TOPDIR)/configs/$@ $(CONFIG_CONFIG_IN)

savedefconfig: $(BUILD_DIR)/config/conf outputmakefile
	@mkdir -p $(BUILD_DIR)/config
	@$(COMMON_CONFIG_ENV) $< --savedefconfig=$(CONFIG_DIR)/defconfig $(CONFIG_CONFIG_IN)

endif # ifeq ($(BR2_HAVE_DOT_CONFIG),y)

#############################################################
#
# Cleanup and misc junk
#
#############################################################

# outputmakefile generates a Makefile in the output directory, if using a
# separate output directory. This allows convenient use of make in the
# output directory.
outputmakefile: 
	echo

post_config:
	scripts/config_parse.sh

prepare_config:
	scripts/factory_config_proj.sh

protect_config: $(BUILD_DIR)/config/mconf
	@mkdir -p $(BUILD_DIR)/config
	@echo "system/projects/"$(BR2_FAMILY_NAME)"/"$(BR2_PROJ_NAME)
	@$(MAKE) -C $(GXSRC_PATH)/system/projects protect_config
	#@$(COMMON_CONFIG_ENV) $< $(CONFIG_CONFIG_IN_PROTECT)

help:
	@echo 'Cleaning:'
	@echo '  clean                  - delete all files created by build'
	@echo '  distclean              - delete all non-source files (including .config)'
	@echo
	@echo
	@echo 'Configuration:'
	@echo '  menuconfig             - interactive curses-based configurator'
	@echo '  nconfig                - interactive ncurses-based configurator'
	@echo '  config                 - interactive configurator'
	@echo
	@echo
	@echo 'Miscellaneous:'
	@echo '  make V=0|1             - 0 => quiet build (default), 1 => verbose build'
	@echo '  make O=dir             - Locate all output files in "dir", including .config'
	@echo
	@echo
	@echo 'Preconfiged:'
	@$(foreach b, $(sort $(notdir $(wildcard $(TOPDIR)/configs/*_defconfig))), \
	  printf "  %-35s - Configure for %s\\n" $(b) $(b:_defconfig=);)
	@echo
	@echo
	@echo 'Release:'
	@echo '  e.g. : make release family=public'
	@echo 
	@echo

#release: OUT=buildroot-$(BR2_VERSION)

# Create release tarballs. We need to fiddle a bit to add the generated
# documentation to the git output
ifdef family
release:
	@echo "get ready for releasing..."
	@echo $(family)
	bash scripts/release_projects.sh $(family)

else
release:
	@echo "Please give a family name"
	@echo "make release family=public"
	@echo 

endif

print-version:
	@echo $(BR2_VERSION_FULL)

distclean:
	@echo "Distcleaning ..."
	@echo "remove "$(OUTPUT_DIR)
	@rm -rf $(OUTPUT_DIR)
	@echo "remove .config .config.old"
	@rm -f .config .config.old 
	@rm -f app/deps  app/signal_connect.c app/include/app_config.h app/app_config.c
	@rm -f system/projects/.config system/projects/.config.old 
	@rm -f system/projects/Config.in.proj


.PHONY: $(noconfig_targets)
