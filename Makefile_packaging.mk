# Common Makefile for including
# Needs the following variables set at a minium:
# NAME :=
# DEB_NAME :=
# SRC_EXT :=
# SOURCE =
# ID_LIKE := $(shell . /etc/os-release; echo $$ID_LIKE)

ifeq ($(DEB_NAME),)
DEB_NAME := $(NAME)
endif
ID_LIKE := $(shell . /etc/os-release; echo $$ID_LIKE)
COMMON_RPM_ARGS := --define "%_topdir $$PWD/_topdir"
DIST    := $(shell rpm $(COMMON_RPM_ARGS) --eval %{?dist})
ifeq ($(DIST),)
SED_EXPR := 1p
else
SED_EXPR := 1s/$(DIST)//p
endif
SPEC    := $(NAME).spec
ifeq ($(VERSION),)
VERSION := $(shell rpm $(COMMON_RPM_ARGS) --specfile --qf '%{version}\n' $(SPEC) | sed -n '1p')
endif
DOT     := .
DEB_VERS := $(subst rc,~rc,$(VERSION))
DEB_RVERS := $(subst $(DOT),\$(DOT),$(DEB_VERS))
DEB_BVERS := $(basename $(subst ~rc,$(DOT)rc,$(DEB_VERS)))
RELEASE := $(shell rpm $(COMMON_RPM_ARGS) --specfile --qf '%{release}\n' $(SPEC) | sed -n '$(SED_EXPR)')
SRPM    ?= _topdir/SRPMS/$(NAME)-$(VERSION)-$(RELEASE)$(DIST).src.rpm
ifeq ($(RPMS),)
RPMS    := $(addsuffix .rpm,$(addprefix _topdir/RPMS/x86_64/,$(shell rpm --specfile $(SPEC))))
endif
DEB_TOP := _topdir/BUILD
DEB_BUILD := $(DEB_TOP)/$(NAME)-$(DEB_VERS)
DEB_TARBASE := $(DEB_TOP)/$(DEB_NAME)_$(DEB_VERS)
ifeq ($(SOURCES),)
SOURCES := $(addprefix _topdir/SOURCES/,$(notdir $(SOURCE)) $(PATCHES))
endif
ifeq ($(ID_LIKE),debian)
DEBS    := $(addsuffix _$(DEB_VERS)-1_amd64.deb,$(shell sed -n '/-udeb/b; s,^Package:[[:blank:]],$(DEB_TOP)/,p' debian/control))
CLEAN_TARBALS := $(shell rm -f *.tar.$(SRC_EXT))
#Ubuntu Containers do not set a UTF-8 environment by default.
ifndef LANG
export LANG = C.UTF-8
endif
ifndef LC_ALL
export LC_ALL = C.UTF-8
endif
TARGETS := $(DEBS)
else
ifndef LANG
export LANG = en_US.utf8
endif
ifndef LC_ALL
export LC_ALL = en_US.utf8
endif
TARGETS := $(RPMS) $(SRPM)
endif
all: $(TARGETS)

%/:
	mkdir -p $@

_topdir/SOURCES/%: % | _topdir/SOURCES/
	rm -f $@
	ln $< $@

$(NAME)-$(VERSION).tar.$(SRC_EXT).asc:
	curl -f -L -O '$(SOURCE).asc'

$(NAME)-$(VERSION).tar.$(SRC_EXT):
	curl -f -L -O '$(SOURCE)'

v$(VERSION).tar.$(SRC_EXT):
	curl -f -L -O '$(SOURCE)'

$(VERSION).tar.$(SRC_EXT):
	curl -f -L -O '$(SOURCE)'

$(DEB_TOP)/%: % | $(DEB_TOP)/

$(DEB_BUILD)/%: % | $(DEB_BUILD)/

$(DEB_BUILD).tar.$(SRC_EXT): $(notdir $(SOURCE)) | $(DEB_TOP)/
	ln -f $< $@

$(DEB_TARBASE).orig.tar.$(SRC_EXT) : $(DEB_BUILD).tar.$(SRC_EXT)
	rm -f $(DEB_TOP)/*.orig.tar.*
	ln -f $< $@

$(DEB_TOP)/.detar: $(notdir $(SOURCE)) $(DEB_TARBASE).orig.tar.$(SRC_EXT) 
	# Unpack tarball
	rm -rf ./$(DEB_BUILD)/*
	mkdir -p $(DEB_BUILD)
	tar -C $(DEB_BUILD) --strip-components=1 -xpf $<
	touch $@

# Extract patches for Debian
$(DEB_TOP)/.patched: $(PATCHES) check-env $(DEB_TOP)/.detar | \
	$(DEB_BUILD)/debian/
	mkdir -p ${DEB_BUILD}/debian/patches
	mkdir -p $(DEB_TOP)/patches
	for f in $(PATCHES); do \
          rm -f $(DEB_TOP)/patches/*; \
	  if git mailsplit -o$(DEB_TOP)/patches < "$$f" ;then \
	      fn=$$(basename "$$f"); \
	      for f1 in $(DEB_TOP)/patches/*;do \
	        [ -e "$$f1" ] || continue; \
	        f1n=$$(basename "$$f1"); \
	        echo "$${fn}_$${f1n}" >> $(DEB_BUILD)/debian/patches/series ; \
	        mv "$$f1" $(DEB_BUILD)/debian/patches/$${fn}_$${f1n}; \
	      done; \
	  else \
	    fb=$$(basename "$$f"); \
	    cp "$$f" $(DEB_BUILD)/debian/patches/ ; \
	    echo "$$fb" >> $(DEB_BUILD)/debian/patches/series ; \
	    if ! grep -q "^Description:\|^Subject:" "$$f" ;then \
	      sed -i '1 iSubject: Auto added patch' \
	        "$(DEB_BUILD)/debian/patches/$$fb" ;fi ; \
	    if ! grep -q "^Origin:\|^Author:\|^From:" "$$f" ;then \
	      sed -i '1 iOrigin: other' \
	        "$(DEB_BUILD)/debian/patches/$$fb" ;fi ; \
	  fi ; \
	done
	touch $@


# Move the debian files into the Debian directory.
ifeq ($(ID_LIKE),debian)
$(DEB_TOP)/.deb_files : $(shell find debian -type f) \
	  $(DEB_TOP)/.detar | \
	  $(DEB_BUILD)/debian/
	find debian -maxdepth 1 -type f -exec cp '{}' '$(DEB_BUILD)/{}' ';'
	if [ -e debian/source ]; then \
	  cp -r debian/source $(DEB_BUILD)/debian; fi
	if [ -e debian/local ]; then \
	  cp -r debian/local $(DEB_BUILD)/debian; fi
	if [ -e debian/examples ]; then \
	  cp -r debian/examples $(DEB_BUILD)/debian; fi
	if [ -e debian/upstream ]; then \
	  cp -r debian/upstream $(DEB_BUILD)/debian; fi
	if [ -e debian/tests ]; then \
	  cp -r debian/tests $(DEB_BUILD)/debian; fi
	rm -f $(DEB_BUILD)/debian/*.ex $(DEB_BUILD)/debian/*.EX
	rm -f $(DEB_BUILD)/debian/*.orig
	touch $@
endif

# see https://stackoverflow.com/questions/2973445/ for why we subst
# the "rpm" for "%" to effectively turn this into a multiple matching
# target pattern rule
$(subst rpm,%,$(RPMS)): $(SPEC) $(SOURCES)
	rpmbuild -bb $(COMMON_RPM_ARGS) $(RPM_BUILD_OPTIONS) $(SPEC)

$(subst deb,%,$(DEBS)): $(DEB_BUILD).tar.$(SRC_EXT) \
	  $(DEB_TOP)/.deb_files $(DEB_TOP)/.detar $(DEB_TOP)/.patched
	rm -f $(DEB_TOP)/*.deb $(DEB_TOP)/*.ddeb $(DEB_TOP)/*.dsc \
	      $(DEB_TOP)/*.dsc $(DEB_TOP)/*.build* $(DEB_TOP)/*.changes \
	      $(DEB_TOP)/*.debian.tar.*
	rm -rf $(DEB_TOP)/*-tmp
	cd $(DEB_BUILD); debuild --no-lintian -b -us -uc
	cd $(DEB_BUILD); debuild -- clean
	git status
	rm -rf $(DEB_TOP)/$(NAME)-tmp
	lfile1=$(shell echo $(DEB_TOP)/$(NAME)[0-9]*_$(DEB_VERS)-1_amd64.deb);\
	  lfile=$$(ls $${lfile1}); \
	  lfile2=$${lfile##*/}; lname=$${lfile2%%_*}; \
	  dpkg-deb -R $${lfile} \
	    $(DEB_TOP)/$(NAME)-tmp; \
	  if [ -e $(DEB_TOP)/$(NAME)-tmp/DEBIAN/symbols ]; then \
	    sed 's/$(DEB_RVERS)-1/$(DEB_BVERS)/' \
	    $(DEB_TOP)/$(NAME)-tmp/DEBIAN/symbols \
	    > $(DEB_BUILD)/debian/$${lname}.symbols; fi
	cd $(DEB_BUILD); debuild -us -uc
	rm $(DEB_BUILD).tar.$(SRC_EXT)
	for f in $(DEB_TOP)/*.deb; do \
	  echo $$f; dpkg -c $$f; done

ifneq ($(SRC_EXT),rpm)
$(SRPM): $(SPEC) $(SOURCES)
	rpmbuild -bs $(COMMON_RPM_ARGS) $(SPEC)
endif

srpm: $(SRPM)

$(RPMS): Makefile

rpms: $(RPMS)

$(DEBS): Makefile

debs: $(DEBS)

ls: $(TARGETS)
	ls -ld $^

mockbuild: $(SRPM) Makefile
	mock $(MOCK_OPTIONS) $<

rpmlint: $(SPEC)
	rpmlint $<

# Debian wants a distclean target
#distclean:
#	@echo "distclean"

check-env:
ifndef DEBEMAIL
	$(error DEBEMAIL is undefined)
endif
ifndef DEBFULLNAME
	$(error DEBFULLNAME is undefined)
endif

show_version:
	@echo $(VERSION)

show_tag:
	@echo ${TAG}

show_release:
	@echo $(RELEASE)

show_rpms:
	@echo $(RPMS)

show_source:
	@echo $(SOURCE)
	@echo -$(NAME)-$(VERSION).tar.$(SRC_EXT)-

source: $(notdir $(SOURCE))

show_sources:
	@echo $(SOURCES)

show_targets:
	@echo $(TARGETS)

.PHONY: srpm rpms debs ls mockbuild rpmlint FORCE show_version show_tag \
     show_release show_rpms source show_source show_sources show_targets \
     check-env
