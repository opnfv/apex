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
export APEXRPM = $(shell pwd)/x86_64/opnfv-apex-2.0-$(shell echo $VERSION | tr -d '_-').noarch.rpm

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
	pushd ../ && git archive --format=tar --prefix=opnfv-apex-2.0/ HEAD > build/opnfv-apex.tar
	tar -u --xform="s:instack.qcow2:opnfv-apex-2.0/build/instack.qcow2:" --file=opnfv-apex.tar instack.qcow2
	tar -u --xform="s:instack.xml:opnfv-apex-2.0/build/instack.xml:" --file=opnfv-apex.tar instack.xml
	qemu-img create -f qcow2 baremetalbrbm_0.qcow2 40G
	tar -u --xform="s:baremetalbrbm_0.qcow2:opnfv-apex-2.0/build/baremetalbrbm_0.qcow2:" --file=opnfv-apex.tar baremetalbrbm_0.qcow2
	tar -u --xform="s:baremetalbrbm_0.xml:opnfv-apex-2.0/build/baremetalbrbm_0.xml:" --file=opnfv-apex.tar baremetalbrbm_0.xml
	qemu-img create -f qcow2 baremetalbrbm_1.qcow2 40G
	tar -u --xform="s:baremetalbrbm_1.qcow2:opnfv-apex-2.0/build/baremetalbrbm_1.qcow2:" --file=opnfv-apex.tar baremetalbrbm_1.qcow2
	tar -u --xform="s:baremetalbrbm_1.xml:opnfv-apex-2.0/build/baremetalbrbm_1.xml:" --file=opnfv-apex.tar baremetalbrbm_1.xml
	tar -u --xform="s:brbm.xml:opnfv-apex-2.0/build/brbm.xml:" --file=opnfv-apex.tar brbm.xml
	tar -u --xform="s:instackenv-virt.json:opnfv-apex-2.0/build/instackenv-virt.json:" --file=opnfv-apex.tar instackenv-virt.json
	tar -u --xform="s:stack/deploy-ramdisk-ironic.initramfs:opnfv-apex-2.0/build/stack/deploy-ramdisk-ironic.initramfs:" --file=opnfv-apex.tar stack/deploy-ramdisk-ironic.initramfs
	tar -u --xform="s:stack/deploy-ramdisk-ironic.kernel:opnfv-apex-2.0/build/stack/deploy-ramdisk-ironic.kernel:" --file=opnfv-apex.tar stack/deploy-ramdisk-ironic.kernel
	tar -u --xform="s:stack/ironic-python-agent.initramfs:opnfv-apex-2.0/build/stack/ironic-python-agent.initramfs:" --file=opnfv-apex.tar stack/ironic-python-agent.initramfs
	tar -u --xform="s:stack/ironic-python-agent.kernel:opnfv-apex-2.0/build/stack/ironic-python-agent.kernel:" --file=opnfv-apex.tar stack/ironic-python-agent.kernel
	tar -u --xform="s:stack/ironic-python-agent.vmlinuz:opnfv-apex-2.0/build/stack/ironic-python-agent.vmlinuz:" --file=opnfv-apex.tar stack/ironic-python-agent.vmlinuz
	tar -u --xform="s:stack/overcloud-full.initrd:opnfv-apex-2.0/build/stack/overcloud-full.initrd:" --file=opnfv-apex.tar stack/overcloud-full.initrd
	tar -u --xform="s:stack/overcloud-full.qcow2:opnfv-apex-2.0/build/stack/overcloud-full.qcow2:" --file=opnfv-apex.tar stack/overcloud-full.qcow2
	tar -u --xform="s:stack/overcloud-full.vmlinuz:opnfv-apex-2.0/build/stack/overcloud-full.vmlinuz:" --file=opnfv-apex.tar stack/overcloud-full.vmlinuz
	gzip -f opnfv-apex.tar
	rpmbuild -ba opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(REVSTATE) | tr -d '.-')"

.PHONY: instack
instack: instack.qcow2

instack.qcow2:
	@./instack.sh $(USE_MASTER)

.PHONY: instack-clean
instack-clean:
	rm -f instackenv-virt.json
	rm -f baremetalbrbm_0.xml
	rm -f baremetalbrbm_1.xml
	rm -f instack.xml
	rm -f instack.qcow2
	rm -rf stack


.PHONY: iso
iso:	build-clean instack.qcow2 rpm $(ISOCACHE)
	@mkdir centos release
	pushd centos
	bsdtar -xf ../$(shell basename $(ISOSRC))
	popd	
	# modify the installer iso's contents
	@cp -f isolinux.cfg centos/isolinux/isolinux.cfg
	@cp $(APEXRPM) centos/Packages
	# regenerate yum repo data
	@echo "Generating new yum metadata"
	createrepo --update -g ../c7-opnfv-x86_64-comps.xml centos
	# build the iso
	@echo "Building OPNFV iso"
	mkisofs -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -V "OPNFV CentOS 7 x86_64" -R -J -v -T -o $(NEWISO) centos
	@printf "\n\nISO is built at $(NEWISO)\n\n"
