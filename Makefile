NAME    := munge
SRC_EXT := rpm
TARBALL_VERSION = 0.5.13
VERSION := $(TARBALL_VERSION)-lp151.3.3
URL_BASE := https://download.opensuse.org/source/distribution/leap/15.1
URL_BASE := $(URL_BASE)/repo/oss/src
SOURCE   = $(URL_BASE)/$(NAME)-$(VERSION).src.$(SRC_EXT)

RPMS := _topdir/RPMS/x86_64/lib$(NAME)2-$(VERSION).x86_64.rpm
RPMS += _topdir/RPMS/x86_64/$(NAME)-devel-$(VERSION).x86_64.rpm
RPMS += _topdir/RPMS/x86_64/$(NAME)-$(VERSION).x86_64.rpm

TARBALL := _topdir/SOURCES/$(NAME)-$(TARBALL_VERSION).tar.gz

COMMON_RPM_ARGS := --define "%_topdir $$PWD/_topdir"
SRPM := _topdir/SOURCES/$(NAME)-$(VERSION).src.$(SRC_EXT)

$(SRPM): Makefile
	rm -rf _topdir
	mkdir -p _topdir/SOURCES
	cd _topdir/SOURCES/; curl -f -L -O '$(SOURCE)'

$(TARBALL): $(SRPM)
	cd _topdir/SOURCES; rpm2cpio ../../$(SRPM) | cpio -iv

TARGETS := $(RPMS) $(SRPM)
all: $(TARGETS)

# see https://stackoverflow.com/questions/2973445/ for why we subst
# # the "rpm" for "%" to effectively turn this into a multiple matching
# # target pattern rule
$(subst rpm,%,$(RPMS)): $(TARBALL)
	rpmbuild $(COMMON_RPM_ARGS) -ba _topdir/SOURCES/munge.spec

srpm: $(SRPM)

$(RPMS): Makefile

rpms: $(RPMS)

ls: $(TARGETS)
	ls -ld $^

show_rpms:
	@echo $(RPMS)

show_targets:
	@echo $(TARGETS)

.PHONY: srpm rpms ks show_targets
