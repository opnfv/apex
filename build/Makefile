##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# dradez@redhat.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

export USE_MASTER = ""
export CENTDNLD = http://mirrors.cat.pdx.edu/centos/7.2.1511/isos/x86_64/CentOS-7-x86_64-DVD-1511.iso
export CENTISO = $(shell pwd)/$(shell basename $(CENTDNLD))
export RELEASE = "0"
export ISO = $(shell pwd)/release/OPNFV-CentOS-7-x86_64-${RELEASE}.iso
export RPMVERS = $(shell grep Version $(shell pwd)/opnfv-apex.spec | awk '{ print $$2 }')
export RPMCOM = $(shell pwd)/noarch/opnfv-apex-common-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMUDR = $(shell pwd)/noarch/opnfv-apex-undercloud-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMODL = $(shell pwd)/noarch/opnfv-apex-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMONO = $(shell pwd)/noarch/opnfv-apex-onos-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMSFC = $(shell pwd)/noarch/opnfv-apex-opendaylight-sfc-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm

.PHONY: all
all: iso

.PHONY: clean
clean: images-clean rpms-clean iso-clean

.PHONY: images
images: undercloud overcloud-full overcloud-opendaylight overcloud-onos overcloud-opendaylight-sfc

.PHONY: images-clean
images-clean: undercloud-clean overcloud-full-clean overcloud-opendaylight-clean overcloud-onos-clean overcloud-opendaylight-sfc-clean
	@rm -rf images/

.PHONY: rpms
rpms: common-rpm undercloud-rpm opendaylight-rpm onos-rpm opendaylight-sfc-rpm

.PHONY: rpms-check
rpms-check: common-rpm-check undercloud-rpm-check opendaylight-rpm-check onos-rpm-check opendaylight-sfc-rpm-check

.PHONY: rpms-clean
rpms-clean: common-rpm-clean undercloud-rpm-clean opendaylight-rpm-clean onos-rpm-clean opendaylight-sfc-rpm-clean

.PHONY: common-rpm
common-rpm: $(RPMCOM)

$(RPMCOM):
	@echo "Building the Apex Common RPM"
	# build the common RPM
	pushd ../ && git archive --format=tar.gz --prefix=opnfv-apex-common-$(RPMVERS)/ HEAD > build/opnfv-apex-common.tar.gz
	rpmbuild --clean -ba opnfv-apex-common.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

###############
#  UNDERCLOUD #
###############

.PHONY: undercloud-clean
undercloud-clean:
	@rm -f images/undercloud.*

.PHONY: undercloud
undercloud: images/undercloud.qcow2

images/undercloud.qcow2:
	@echo "Building the Apex Undercloud Image"
	@./undercloud.sh

.PHONY: undercloud-rpm-prep
undercloud-rpm-prep: opnfv-apex-undercloud.tar

opnfv-apex-undercloud.tar: images/undercloud.qcow2
	@echo "Preparing the Apex Undercloud RPM prerequisites"
	pushd ../ && git archive --format=tar --prefix=opnfv-apex-undercloud-$(RPMVERS)/ HEAD > build/opnfv-apex-undercloud.tar
	tar -rf opnfv-apex-undercloud.tar \
               --xform="s:images/undercloud.qcow2:opnfv-apex-undercloud-$(RPMVERS)/build/undercloud.qcow2:" images/undercloud.qcow2
	gzip -f opnfv-apex-undercloud.tar

.PHONY: undercloud-rpm-check
undercloud-rpm-check: undercloud-rpm-prep
	rpmbuild --clean -bi -bl opnfv-apex-undercloud.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D            '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: undercloud-rpm
undercloud-rpm: images/undercloud.qcow2 $(RPMUDR)

$(RPMUDR):
	@echo "Building the Apex Undercloud RPM"
	rpmbuild --clean -ba opnfv-apex-undercloud.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

###############
#  OVERCLOUD  #
###############

.PHONY: overcloud-full-clean
overcloud-full-clean:
	@rm -rf images/overcloud-full.d
	@rm -f images/overcloud-full.*

.PHONY: overcloud-full
overcloud-full: images/overcloud-full.qcow2

images/overcloud-full.qcow2:
	@echo "Building the Apex Base Overcloud Image"
	@./overcloud-full.sh

###############
#    ODL      #
###############

.PHONY: overcloud-opendaylight-clean
overcloud-opendaylight-clean:
	@rm -f images/overcloud-full-opendaylight.qcow2

.PHONY: overcloud-opendaylight
overcloud-opendaylight: images/overcloud-full-opendaylight.qcow2

images/overcloud-full-opendaylight.qcow2: images/overcloud-full.qcow2
	@echo "Building the Apex OpenDaylight Overcloud Image"
	@./overcloud-opendaylight.sh

.PHONY: opendaylight-rpm
opendaylight-rpm: overcloud-opendaylight $(RPMODL)

$(RPMODL):
	@echo "Building the Apex OpenDaylight RPM"
	# build the overcloud RPM
	tar -czf opnfv-apex.tar.gz --xform="s:images/overcloud-full-opendaylight.qcow2:opnfv-apex-$(RPMVERS)/build/images/overcloud-full-opendaylight.qcow2:" images/overcloud-full-opendaylight.qcow2
	rpmbuild --clean -ba opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

###############
#    ONOS     #
###############

.PHONY: overcloud-onos-clean
overcloud-onos-clean:
	@rm -f images/overcloud-full-onos.qcow2
	@rm -rf images/puppet-onos
	@rm -f images/puppet-onos.tar.gz

.PHONY: overcloud-onos
overcloud-onos: images/overcloud-full-onos.qcow2

images/overcloud-full-onos.qcow2: images/overcloud-full.qcow2
	@echo "Building the Apex ONOS Overcloud Image"
	@./overcloud-onos.sh

.PHONY: onos-rpm-clean
onos-rpm-clean:
	@rpmbuild --clean opnfv-apex-onos.spec -D "release $(shell echo $RELEASE | tr -d '_-')"

.PHONY: onos-rpm
onos-rpm: overcloud-onos $(RPMONO)

$(RPMONO):
	@echo "Building the Apex ONOS RPM"
	# build the overcloud RPM
	tar -czf opnfv-apex-onos.tar.gz --xform="s:images/overcloud-full-onos.qcow2:opnfv-apex-onos-$(RPMVERS)/build/images/overcloud-full-onos.qcow2:" images/overcloud-full-onos.qcow2
	rpmbuild --clean -ba opnfv-apex-onos.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

###############
#   ODL-SFC   #
###############

.PHONY: overcloud-opendaylight-sfc-clean
overcloud-opendaylight-sfc-clean:
	@rm -f images/overcloud-full-opendaylight-sfc.qcow2

.PHONY: overcloud-opendaylight-sfc
overcloud-opendaylight-sfc: images/overcloud-full-opendaylight-sfc.qcow2

images/overcloud-full-opendaylight-sfc.qcow2: images/overcloud-full-opendaylight.qcow2
	@echo "Building the Apex OpenDaylight Overcloud Image"
	@./overcloud-opendaylight-sfc.sh

.PHONY: opendaylight-sfc-rpm
opendaylight-sfc-rpm: overcloud-opendaylight-sfc $(RPMSFC)

$(RPMSFC):
	@echo "Building the Apex OpenDaylight SFC RPM"
	tar -czf opnfv-apex-opendaylight-sfc.tar.gz --xform="s:images/overcloud-full-opendaylight-sfc.qcow2:opnfv-apex-opendaylight-sfc-$(RPMVERS)/build/images/overcloud-full-opendaylight-sfc.qcow2:" images/overcloud-full-opendaylight-sfc.qcow2
	rpmbuild --clean -ba opnfv-apex-opendaylight-sfc.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

###############
#    ISO      #
###############

$(CENTISO):
	curl $(CENTDNLD) -z $(CENTISO) -o $(CENTISO) --verbose --silent --location

.PHONY: iso-clean
iso-clean:
	@rm -Rf centos
	@rm -Rf release
	@rm -f $(ISO)

.PHONY: mount-centiso umount-centiso
mount-centiso: $(CENTISO)
	@echo "Mounting CentOS ISO in $(CENTDIR)"
	@mkdir -p $(CENTDIR)
	@fuseiso $(CENTISO) $(CENTDIR)

umount-centiso:
	@set +e
	@echo "Unmounting CentOS ISO from $(CENTDIR)"
	@fusermount -u $(CENTDIR)
	@rmdir $(CENTDIR)
	@set -e

.PHONY: iso
iso:	iso-clean images rpms $(CENTISO)
	@echo "Building the Apex ISO"
	@mkdir centos release
	cd centos && bsdtar -xf ../$(shell basename $(CENTISO))
	# modify the installer iso's contents
	@chmod -R u+w centos
	@cp -f isolinux.cfg centos/isolinux/isolinux.cfg
	@ln $(RPMCOM) centos/Packages
	@ln $(RPMUDR) centos/Packages
	@ln $(RPMODL) centos/Packages
	@ln $(RPMONO) centos/Packages
	@ln $(RPMSFC) centos/Packages
	cd centos/Packages && yumdownloader openvswitch && yumdownloader openstack-tripleo
	# regenerate yum repo data
	@echo "Generating new yum metadata"
	createrepo --update -g ../c7-opnfv-x86_64-comps.xml centos
	# build the iso
	@echo "Building OPNFV iso"
	mkisofs -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -V "OPNFV CentOS 7 x86_64" -R -J -v -T -o $(ISO) centos
	isohybrid $(ISO)
	@printf "\n\nISO is built at $(ISO)\n\n"
