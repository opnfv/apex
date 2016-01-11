##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# dradez@redhat.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

SHELL = /bin/bash
############################################################################
# BEGIN of variables to customize
#
#Input args
export UNIT_TEST = FALSE
export USE_MASTER = ""
export INTERACTIVE = TRUE
export CENTDNLD = http://mirrors.cat.pdx.edu/centos/7.1.1503/isos/x86_64/CentOS-7-x86_64-DVD-1503-01.iso
export ISOSRC = file:$(shell pwd)/CentOS-7-x86_64-DVD-1503-01.iso
export ISOCACHE = $(shell pwd)/$(shell basename $(ISOSRC))
export PRODNO = "OPNFV_BGS"
export REVSTATE = "0000"
export NEWISO = $(shell pwd)/release/OPNFV-CentOS-7-x86_64-${REVSTATE}.iso
export RPMVERS = $(shell grep Version $(shell pwd)/opnfv-apex.spec | awk '{ print $$2 }')
export APEXRPMCOM = $(shell pwd)/noarch/opnfv-apex-common-$(RPMVERS)-$(shell echo ${REVSTATE} | tr -d '_-').noarch.rpm
export APEXRPMINS = $(shell pwd)/noarch/opnfv-apex-undercloud-$(RPMVERS)-$(shell echo ${REVSTATE} | tr -d '_-').noarch.rpm
export APEXRPM = $(shell pwd)/noarch/opnfv-apex-$(RPMVERS)-$(shell echo ${REVSTATE} | tr -d '_-').noarch.rpm

# Note! Invoke with "make REVSTATE=RXXXX all" to make release build!
# Invoke with ICOCACHE=/full/path/to/iso if cached ISO is in non-standard location.

#Build variables
export BUILD_BASE := $(shell pwd)
export CACHE_DIR := $(BUILD_BASE)/cache
export VERSION_FILE := $(BUILD_BASE)/.versions
export TOPDIR := $(shell pwd)

CENTDIR := $(TOPDIR)/centiso
#
# END of variables to customize
#############################################################################

SUBCLEAN = $(addsuffix .clean,$(SUBDIRS))


.PHONY: all
all: iso
	@echo "Versions of cached build results built by" $(shell hostname) "at" $(shell date -u) > $(VERSION_FILE)
	@echo "cache.mk" $(shell md5sum $(BUILD_BASE)/cache.mk | cut -f1 -d " ") >> $(VERSION_FILE)
	@echo "config.mk" $(shell md5sum $(BUILD_BASE)/config.mk | cut -f1 -d " ") >> $(VERSION_FILE)

############################################################################
# BEGIN of Include definitions
#
include config.mk
include cache.mk
#
# END Include definitions
#############################################################################

$(ISOCACHE):
	test -s $(ISOCACHE) || { wget -nv $(CENTDNLD) ; }

.PHONY: mount-centiso umount-centiso
mount-centiso: $(ISOCACHE)
	@echo "Mounting CentOS ISO in $(CENTDIR)"
	@mkdir -p $(CENTDIR)
	@fuseiso $(ISOCACHE) $(CENTDIR)

umount-centiso:
	@set +e
	@echo "Unmounting CentOS ISO from $(CENTDIR)"
	@fusermount -u $(CENTDIR)
	@rmdir $(CENTDIR)
	@set -e

.PHONY: build-clean $(SUBCLEAN)
build-clean: instack-clean $(SUBCLEAN)
	@rm -Rf centos
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)

.PHONY: clean $(SUBCLEAN)
clean:  clean-cache build-clean $(SUBCLEAN)
	@rm -f *.iso
	@rm -Rf release
	@rm -Rf newiso
	@rm -f $(NEWISO)
	@rm -f $(BUILD_BASE)/.versions

$(SUBCLEAN): %.clean:
	$(MAKE) -C $* -f Makefile clean

.PHONY: rpm-clean
rpm-clean:
	@rm -f build/opnfv-apex-common.tar.gz
	@rm -f build/opnfv-apex-undercloud.tar.gz
	@rm -f build/opnfv-apex.tar.gz

.PHONY: rpm
rpm:
	# build the common RPM
	pushd ../ && git archive --format=tar.gz --prefix=opnfv-apex-common-$(RPMVERS)/ HEAD > build/opnfv-apex-common.tar.gz
	rpmbuild -ba opnfv-apex-common.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(REVSTATE) | tr -d '_-')"
	# build the undercloud RPM
	tar -czf opnfv-apex-undercloud.tar.gz \
               --xform="s:stack/instack.qcow2:opnfv-apex-undercloud-$(RPMVERS)/build/instack.qcow2:" \
	       --xform="s:instack.xml:opnfv-apex-undercloud-$(RPMVERS)/build/instack.xml:" \
	       --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_0.xml:opnfv-apex-undercloud-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_0.xml:" \
	       --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_1.xml:opnfv-apex-undercloud-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_1.xml:" \
	       --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_2.xml:opnfv-apex-undercloud-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_2.xml:" \
	       --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_3.xml:opnfv-apex-undercloud-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_3.xml:" \
	       --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_4.xml:opnfv-apex-undercloud-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_4.xml:" \
	       --xform="s:brbm-net.xml:opnfv-apex-undercloud-$(RPMVERS)/build/brbm-net.xml:" \
	       --xform="s:brbm1-net.xml:opnfv-apex-undercloud-$(RPMVERS)/build/brbm1-net.xml:" \
	       --xform="s:brbm2-net.xml:opnfv-apex-undercloud-$(RPMVERS)/build/brbm2-net.xml:" \
	       --xform="s:brbm3-net.xml:opnfv-apex-undercloud-$(RPMVERS)/build/brbm3-net.xml:" \
	       --xform="s:default-pool.xml:opnfv-apex-undercloud-$(RPMVERS)/build/default-pool.xml:" \
	       --xform="s:network-environment.yaml:opnfv-apex-undercloud-$(RPMVERS)/build/network-environment.yaml:" \
	       --xform="s:nics/controller.yaml:opnfv-apex-undercloud-$(RPMVERS)/build/nics/controller.yaml:" \
	       --xform="s:nics/compute.yaml:opnfv-apex-undercloud-$(RPMVERS)/build/nics/compute.yaml:" \
	       --xform="s:instackenv-virt.json:opnfv-apex-undercloud-$(RPMVERS)/build/instackenv-virt.json:" \
	       --xform="s:instackenv.json.example:opnfv-apex-undercloud-$(RPMVERS)/build/instackenv.json.example:" \
	       stack/instack.qcow2 instack.xml baremetalbrbm_brbm1_brbm2_brbm3_0.xml baremetalbrbm_brbm1_brbm2_brbm3_1.xml \
	       baremetalbrbm_brbm1_brbm2_brbm3_2.xml baremetalbrbm_brbm1_brbm2_brbm3_3.xml baremetalbrbm_brbm1_brbm2_brbm3_4.xml \
	       brbm-net.xml brbm1-net.xml brbm2-net.xml brbm3-net.xml default-pool.xml instackenv-virt.json network-environment.yaml \
	       nics/controller.yaml nics/compute.yaml instackenv-virt.json instackenv.json.example
	rpmbuild -ba opnfv-apex-undercloud.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(REVSTATE) | tr -d '_-')"
	# build the overcloud RPM
	tar -czf opnfv-apex.tar.gz --xform="s:stack/overcloud-full-odl.qcow2:opnfv-apex-$(RPMVERS)/build/stack/overcloud-full.qcow2:" stack/overcloud-full-odl.qcow2
	rpmbuild -ba opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(REVSTATE) | tr -d '_-')"

.PHONY: instack
instack:
	@./instack.sh $(USE_MASTER)

.PHONY: instack-clean
instack-clean:
	rm -f instackenv-virt.json
	rm -f baremetalbrbm_brbm1_brbm2_brbm3_0.xml
	rm -f baremetalbrbm_brbm1_brbm2_brbm3_1.xml
	rm -f baremetalbrbm_brbm1_brbm2_brbm3_2.xml
	rm -f baremetalbrbm_brbm1_brbm2_brbm3_3.xml
	rm -f baremetalbrbm_brbm1_brbm2_brbm3_4.xml
	rm -f instack.xml

.PHONY: iso
iso:	build-clean instack rpm $(ISOCACHE)
	@mkdir centos release
	cd centos && bsdtar -xf ../$(shell basename $(ISOSRC))
	# modify the installer iso's contents
	@cp -f isolinux.cfg centos/isolinux/isolinux.cfg
	@cp $(APEXRPMCOM) centos/Packages
	@cp $(APEXRPMINS) centos/Packages
	@cp $(APEXRPM) centos/Packages
	cd centos/Packages && yumdownloader openvswitch
	# regenerate yum repo data
	@echo "Generating new yum metadata"
	createrepo --update -g ../c7-opnfv-x86_64-comps.xml centos
	# build the iso
	@echo "Building OPNFV iso"
	mkisofs -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -V "OPNFV CentOS 7 x86_64" -R -J -v -T -o $(NEWISO) centos
	isohybrid $(NEWISO)
	@printf "\n\nISO is built at $(NEWISO)\n\n"
