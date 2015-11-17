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
	tar -u --xform="s:instack.qcow2:opnfv-apex-$(RPMVERS)/build/instack.qcow2:" --file=opnfv-apex.tar instack.qcow2
	tar -u --xform="s:instack.xml:opnfv-apex-$(RPMVERS)/build/instack.xml:" --file=opnfv-apex.tar instack.xml
	tar -u --xform="s:baremetalbrbm_brbm1_0.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_0.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_0.xml
	tar -u --xform="s:baremetalbrbm_brbm1_1.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_1.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_1.xml
	tar -u --xform="s:baremetalbrbm_brbm1_2.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_2.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_2.xml
	tar -u --xform="s:baremetalbrbm_brbm1_3.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_3.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_3.xml
	tar -u --xform="s:baremetalbrbm_brbm1_4.xml:opnfv-apex-$(RPMVERS)/build/baremetalbrbm_brbm1_4.xml:" --file=opnfv-apex.tar baremetalbrbm_brbm1_4.xml
	tar -u --xform="s:brbm-net.xml:opnfv-apex-$(RPMVERS)/build/brbm-net.xml:" --file=opnfv-apex.tar brbm-net.xml
	tar -u --xform="s:brbm1-net.xml:opnfv-apex-$(RPMVERS)/build/brbm1-net.xml:" --file=opnfv-apex.tar brbm1-net.xml
	tar -u --xform="s:default-pool.xml:opnfv-apex-$(RPMVERS)/build/default-pool.xml:" --file=opnfv-apex.tar default-pool.xml
	tar -u --xform="s:instackenv-virt.json:opnfv-apex-$(RPMVERS)/build/instackenv-virt.json:" --file=opnfv-apex.tar instackenv-virt.json
	tar -u --xform="s:stack/deploy-ramdisk-ironic.initramfs:opnfv-apex-$(RPMVERS)/build/stack/deploy-ramdisk-ironic.initramfs:" --file=opnfv-apex.tar stack/deploy-ramdisk-ironic.initramfs
	tar -u --xform="s:stack/deploy-ramdisk-ironic.kernel:opnfv-apex-$(RPMVERS)/build/stack/deploy-ramdisk-ironic.kernel:" --file=opnfv-apex.tar stack/deploy-ramdisk-ironic.kernel
	tar -u --xform="s:stack/ironic-python-agent.initramfs:opnfv-apex-$(RPMVERS)/build/stack/ironic-python-agent.initramfs:" --file=opnfv-apex.tar stack/ironic-python-agent.initramfs
	tar -u --xform="s:stack/ironic-python-agent.kernel:opnfv-apex-$(RPMVERS)/build/stack/ironic-python-agent.kernel:" --file=opnfv-apex.tar stack/ironic-python-agent.kernel
	tar -u --xform="s:stack/ironic-python-agent.vmlinuz:opnfv-apex-$(RPMVERS)/build/stack/ironic-python-agent.vmlinuz:" --file=opnfv-apex.tar stack/ironic-python-agent.vmlinuz
	tar -u --xform="s:stack/overcloud-full.initrd:opnfv-apex-$(RPMVERS)/build/stack/overcloud-full.initrd:" --file=opnfv-apex.tar stack/overcloud-full.initrd
	tar -u --xform="s:stack/overcloud-full-odl.qcow2:opnfv-apex-$(RPMVERS)/build/stack/overcloud-full.qcow2:" --file=opnfv-apex.tar stack/overcloud-full-odl.qcow2
	tar -u --xform="s:stack/overcloud-full.vmlinuz:opnfv-apex-$(RPMVERS)/build/stack/overcloud-full.vmlinuz:" --file=opnfv-apex.tar stack/overcloud-full.vmlinuz
	tar -u --xform="s:network-environment.yaml:opnfv-apex-$(RPMVERS)/build/network-environment.yaml:" --file=opnfv-apex.tar network-environment.yaml
	tar -u --xform="s:opendaylight.yaml:opnfv-apex-$(RPMVERS)/build/opendaylight.yaml:" --file=opnfv-apex.tar opendaylight.yaml
	tar -u --xform="s:opendaylight.patch:opnfv-apex-$(RPMVERS)/build/opendaylight.patch:" --file=opnfv-apex.tar opendaylight.patch
	gzip -f opnfv-apex.tar
	rpmbuild -ba opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(REVSTATE) | tr -d '_-')"

.PHONY: instack
instack: instack.qcow2

instack.qcow2:
	@./instack.sh $(USE_MASTER)

.PHONY: instack-clean
instack-clean:
	rm -f instackenv-virt.json
	rm -f baremetalbrbm_brbm1_0.xml
	rm -f baremetalbrbm_brbm1_1.xml
	rm -f baremetalbrbm_brbm1_2.xml
	rm -f baremetalbrbm_brbm1_3.xml
	rm -f baremetalbrbm_brbm1_4.xml
	rm -f instack.xml
	rm -f instack.qcow2

.PHONY: iso
iso:	build-clean instack.qcow2 rpm $(ISOCACHE)
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
