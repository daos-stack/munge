NAME    := munge
SRC_EXT := rpm
TARBALL_VERSION = 0.5.13
VERSION := $(TARBALL_VERSION)-lp151.3.3
URL_BASE := https://download.opensuse.org/source/distribution/leap/15.1
URL_BASE := $(URL_BASE)/repo/oss/src
SOURCE   = $(URL_BASE)/$(NAME)-$(VERSION).src.$(SRC_EXT)

SPEC := _topdir/SOURCES/munge.spec

RPMS := _topdir/RPMS/x86_64/lib$(NAME)2-$(VERSION).x86_64.rpm
RPMS += _topdir/RPMS/x86_64/$(NAME)-devel-$(VERSION).x86_64.rpm
RPMS += _topdir/RPMS/x86_64/$(NAME)-$(VERSION).x86_64.rpm
SRPM := _topdir/SRPMS/$(NAME)-$(VERSION).src.$(SRC_EXT)

SOURCES := _topdir/SOURCES/$(NAME)-$(TARBALL_VERSION).tar.gz

SRPM_IN := _topdir/SOURCES/$(NAME)-$(VERSION).src.$(SRC_EXT)

# Can not just CURL the file into the _topdir/SRPMS, the rpmbuild of the
# binary packages replaces it, which makes it newer than the unpacked
# sources.
$(SRPM_IN): Makefile
	rm -rf _topdir
	mkdir -p _topdir/SOURCES
	cd _topdir/SOURCES/; curl -f -L -O '$(SOURCE)'

$(SRPM): $(SPEC)
	mkdir -p _topdir/SRPMS
	ln -f $< $@

$(SOURCES): $(SRPM_IN)
	cd _topdir/SOURCES; rpm2cpio ../../$(SRPM_IN) | cpio -iv

$(SPEC): $(SOURCES)

include Makefile_packaging.mk

