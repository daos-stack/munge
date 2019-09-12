NAME    := munge
SRC_EXT := gz
SOURCE   = https://github.com/dun/munge/archive/$(NAME)-$(VERSION).tar.gz
PATCHES := Make-SUSE-specific-adjustments.patch baselibs.conf \
	   sysconfig.munge README.SUSE

include packaging/Makefile_packaging.mk
