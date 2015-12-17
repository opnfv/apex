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
	@rm -f build/opnfv-apex.tar.gz

.PHONY: rpm
rpm:
	pushd ../ && git archive --format=tar --prefix=opnfv-apex-$(RPMVERS)/ HEAD > build/opnfv-apex.tar
	tar -u --xform="s:stack/instack.qcow2:opnfv-apex-$(RPMVERS)/build/instack.qcow2:" --file=opnfv-apex.tar stack/instack.qcow2
	tar -u --xform="s:instack.xml:opnfv-apex-$(RPMVERS)/build/instack.xml:" --file=opnfv-apex.tar instack.xml
	tar -u --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_0.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_0.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_brbm2_brbm3_0.xml
	tar -u --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_1.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_1.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_brbm2_brbm3_1.xml
	tar -u --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_2.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_2.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_brbm2_brbm3_2.xml
	tar -u --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_3.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_3.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_brbm2_brbm3_3.xml
	tar -u --xform="s:baremetalbrbm_brbm1_brbm2_brbm3_4.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_brbm2_brbm3_4.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_brbm2_brbm3_4.xml
	tar -u --xform="s:brbm-net.xml:opnfv-apex-$(RPMVERS)/build/brbm-net.xml:" --file=opnfv-apex.tar brbm-net.xml
	tar -u --xform="s:brbm1-net.xml:opnfv-apex-$(RPMVERS)/build/brbm1-net.xml:" --file=opnfv-apex.tar brbm1-net.xml
	tar -u --xform="s:brbm2-net.xml:opnfv-apex-$(RPMVERS)/build/brbm2-net.xml:" --file=opnfv-apex.tar brbm2-net.xml
	tar -u --xform="s:brbm3-net.xml:opnfv-apex-$(RPMVERS)/build/brbm3-net.xml:" --file=opnfv-apex.tar brbm3-net.xml
	tar -u --xform="s:default-pool.xml:opnfv-apex-$(RPMVERS)/build/default-pool.xml:" --file=opnfv-apex.tar default-pool.xml
	tar -u --xform="s:instackenv-virt.json:opnfv-apex-$(RPMVERS)/build/instackenv-virt.json:" --file=opnfv-apex.tar instackenv-virt.json
	tar -u --xform="s:instackenv.json.example:opnfv-apex-$(RPMVERS)/build/instackenv.json.example:" --file=opnfv-apex.tar instackenv.json.example
	tar -u --xform="s:stack/overcloud-full-odl.qcow2:opnfv-apex-$(RPMVERS)/build/stack/overcloud-full.qcow2:" --file=opnfv-apex.tar stack/overcloud-full-odl.qcow2
	tar -u --xform="s:network-environment.yaml:opnfv-apex-$(RPMVERS)/build/network-environment.yaml:" --file=opnfv-apex.tar network-environment.yaml
	tar -u --xform="s:opendaylight-puppet-neutron.patch:opnfv-apex-$(RPMVERS)/build/opendaylight-puppet-neutron.patch:" --file=opnfv-apex.tar opendaylight-puppet-neutron.patch
	tar -u --xform="s:opendaylight-tripleo-heat-templates.patch:opnfv-apex-$(RPMVERS)/build/opendaylight-tripleo-heat-templates.patch:" --file=opnfv-apex.tar opendaylight-tripleo-heat-templates.patch
	gzip -f opnfv-apex.tar
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
