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

export RPM_DIST = $(shell rpm -E %dist)
export TACKER_REPO = "http://github.com/trozet/tacker"
export TACKER_BRANCH = "SFC_colorado"
export TACKER_COMMIT = $(shell git ls-remote $(TACKER_REPO) $(TACKER_BRANCH) | awk '{print substr($$1,1,7)}')

export TACKERCLIENT_REPO = "http://github.com/trozet/python-tackerclient"
export TACKERCLIENT_BRANCH = "SFC_refactor"
export TACKERCLIENT_COMMIT = $(shell git ls-remote $(TACKERCLIENT_REPO) $(TACKERCLIENT_BRANCH) | awk '{print substr($$1,1,7)}')

export CONGRESS_REPO = "http://github.com/openstack/congress"
export CONGRESS_BRANCH = "stable/mitaka"
export CONGRESS_COMMIT = $(shell git ls-remote $(CONGRESS_REPO) $(CONGRESS_BRANCH) | awk '{print substr($$1,1,7)}')

export NETVPP_REPO = "https://github.com/openstack/networking-vpp"
export NETVPP_BRANCH = "master"
export NETVPP_COMMIT = $(shell git ls-remote $(NETVPP_REPO) $(NETVPP_BRANCH) | awk '{print substr($$1,1,7)}')

export RPMVERS = $(shell grep Version $(shell pwd)/rpm_specs/opnfv-apex.spec | head -n 1 | awk '{ print $$2 }')
export RPMCOM = $(shell pwd)/noarch/opnfv-apex-common-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMUDR = $(shell pwd)/noarch/opnfv-apex-undercloud-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMODL = $(shell pwd)/noarch/opnfv-apex-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMONO = $(shell pwd)/noarch/opnfv-apex-onos-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm

.PHONY: all
all: iso

.PHONY: clean
clean: images-clean rpms-clean iso-clean tacker-clean tackerclient-clean congress-clean networking-vpp-clean

.PHONY: images
images: undercloud overcloud-full overcloud-opendaylight overcloud-onos

.PHONY: images-clean
images-clean: undercloud-clean overcloud-full-clean overcloud-opendaylight-clean overcloud-onos-clean
	rm -rf images/

.PHONY: rpms
rpms: common-rpm undercloud-rpm opendaylight-rpm onos-rpm

.PHONY: rpms-check
rpms-check: common-rpm-check undercloud-rpm-check opendaylight-rpm-check onos-rpm-check

.PHONY: rpms-clean
rpms-clean: common-rpm-clean undercloud-rpm-clean opendaylight-rpm-clean onos-rpm-clean
	rm -rf noarch
	rm -rf BUILDROOT

opnfv-apex-common.tar.gz:
	pushd ../ && git archive --format=tar.gz --prefix=opnfv-apex-common-$(RPMVERS)/ HEAD > build/opnfv-apex-common.tar.gz

.PHONY: common-rpm-check
common-rpm-check: opnfv-apex-common.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-common.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: common-rpm
common-rpm: opnfv-apex-common.tar.gz $(RPMCOM)

$(RPMCOM):
	@echo "Building the Apex Common RPM"
	# build the common RPM
	rpmbuild --clean -ba rpm_specs/opnfv-apex-common.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: common-rpm-clean
common-rpm-clean:

##################
#  PYTHON TESTS  #
##################

.PHONY: python-tests
python-tests:
	# clean previous coverage data
	rm -rf ../tests/.coverage
	rm -rf ../tests/htmlcov
	# run nose tests
	cd ../tests && PYTHONPATH=../lib/python/ nosetests-3.4 . --with-coverage --cover-package apex --cover-package apex_python_utils --cover-html --cover-min-percentage 90

	# generate reports
	cd ../tests && coverage3 report --include '*lib/python/*' -m

#######################
#  PYTHON PEP8 CHECK  #
#######################

.PHONY: python-pep8-check
python-pep8-check:
	pep8 ../lib/python
	pep8 ../tests

###############
#  TACKER     #
###############

.PHONY: tacker-clean

tacker-clean:
	rm -rf openstack-tacker-2015.2
	rm -f openstack-tacker.tar.gz

openstack-tacker.tar.gz:
	@echo "Preparing the Tacker RPM prerequisites"
	git clone $(TACKER_REPO) -b $(TACKER_BRANCH) openstack-tacker-2015.2
	tar czf openstack-tacker.tar.gz openstack-tacker-2015.2

.PHONY: tacker-rpm
tacker-rpm: openstack-tacker.tar.gz noarch/openstack-tacker-2015.2-1.trozetgit$(TACKER_COMMIT).noarch.rpm

noarch/openstack-tacker-2015.2-1.trozetgit$(TACKER_COMMIT).noarch.rpm:
	@echo "Building the Tacker RPM"
	rpmbuild --clean -ba --target noarch rpm_specs/openstack-tacker.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D 'git .trozetgit$(TACKER_COMMIT)'

#################
#  TACKERCLIENT #
#################

.PHONY: tackerclient-clean
tackerclient-clean:
	rm -rf python-tackerclient-2015.2
	rm -f python-tackerclient.tar.gz

python-tackerclient.tar.gz:
	@echo "Preparing the TackerClient RPM prerequisites"
	git clone $(TACKERCLIENT_REPO) -b $(TACKERCLIENT_BRANCH) python-tackerclient-2015.2
	tar czf python-tackerclient.tar.gz python-tackerclient-2015.2

.PHONY: tackerclient-rpm
tackerclient-rpm: python-tackerclient.tar.gz noarch/python-tackerclient-2015.2-1.trozetgit$(TACKERCLIENT_COMMIT).noarch.rpm

noarch/python-tackerclient-2015.2-1.trozetgit$(TACKERCLIENT_COMMIT).noarch.rpm:
	@echo "Building the TackerClient RPM"
	rpmbuild --clean -ba --target noarch rpm_specs/python-tackerclient.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D 'git .trozetgit$(TACKERCLIENT_COMMIT)'

###############
#  CONGRESS   #
###############

.PHONY: congress-clean
congress-clean:
	@rm -rf openstack-congress-2016.1
	@rm -f openstack-congress.tar.gz

openstack-congress.tar.gz:
	@echo "Preparing the Congress RPM prerequisites"
	git clone $(CONGRESS_REPO) -b $(CONGRESS_BRANCH) openstack-congress-2016.1
	cd openstack-congress-2016.1 && curl -O https://radez.fedorapeople.org/openstack-congress.service
	tar czf openstack-congress.tar.gz openstack-congress-2016.1

.PHONY: congress-rpm
congress-rpm: openstack-congress.tar.gz noarch/openstack-congress-2016.1-1.git$(CONGRESS_COMMIT).noarch.rpm


noarch/openstack-congress-2016.1-1.git$(CONGRESS_COMMIT).noarch.rpm:
	@echo "Building the Congress RPM"
	rpmbuild --clean -ba --target noarch rpm_specs/openstack-congress.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D 'git .git$(CONGRESS_COMMIT)'

##################
# NETWORKING-VPP #
##################

.PHONY: networking-vpp-clean
networking-vpp-clean:
	@rm -rf networking-vpp
	@rm -rf networking-vpp-*
	@rm -f networking-vpp.tar.gz
	@rm networking-vpp-agent.service

networking-vpp.tar.gz:
	@echo "Preparing the networking-vpp RPM prerequisites"
	git clone $(NETVPP_REPO) networking-vpp-0.0.1
	tar czf networking-vpp.tar.gz networking-vpp-0.0.1

.PHONY: networking-vpp-rpm
networking-vpp-rpm: noarch/networking-vpp-0.0.1-1.git$(NETVPP_COMMIT)$(RPM_DIST).noarch.rpm

noarch/networking-vpp-0.0.1-1.git$(NETVPP_COMMIT)$(RPM_DIST).noarch.rpm: networking-vpp.tar.gz
	@echo "Building the Networking VPP RPM"
	rpmbuild --clean -ba --target noarch rpm_specs/networking-vpp.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D 'git .git$(NETVPP_COMMIT)'


###############
#  UNDERCLOUD #
###############

.PHONY: undercloud-clean
undercloud-clean:
	rm -f images/undercloud.*
	rm -rf opnfv-tht.tar.gz
	rm -rf opnfv-tht/

.PHONY: undercloud
undercloud: images/undercloud.qcow2

images/undercloud.qcow2: tackerclient-rpm
	@echo "Building the Apex Undercloud Image"
	@./undercloud.sh

opnfv-apex-undercloud.tar.gz: images/undercloud.qcow2
	@echo "Preparing the Apex Undercloud RPM prerequisites"
	pushd ../ && git archive --format=tar --prefix=opnfv-apex-undercloud-$(RPMVERS)/ HEAD > build/opnfv-apex-undercloud.tar
	tar -rf opnfv-apex-undercloud.tar \
               --xform="s:images/undercloud.qcow2:opnfv-apex-undercloud-$(RPMVERS)/build/undercloud.qcow2:" images/undercloud.qcow2
	gzip -f opnfv-apex-undercloud.tar

.PHONY: undercloud-rpm-check
undercloud-rpm-check: opnfv-apex-undercloud.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-undercloud.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: undercloud-rpm
undercloud-rpm: opnfv-apex-undercloud.tar.gz $(RPMUDR)

$(RPMUDR):
	@echo "Building the Apex Undercloud RPM"
	rpmbuild --clean -ba rpm_specs/opnfv-apex-undercloud.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: undercloud-rpm-clean
undercloud-rpm-clean:

###############
#  OVERCLOUD  #
###############

.PHONY: overcloud-full-clean
overcloud-full-clean:
	rm -rf images/overcloud-full.d
	rm -f images/overcloud-full.*
	rm -rf opnfv-puppet-tripleo.tar.gz
	rm -rf opnfv-puppet-tripleo/
	rm -rf os-net-config.tar.gz
	rm -rf os-net-config/

.PHONY: overcloud-full
overcloud-full: images/overcloud-full.qcow2

images/overcloud-full.qcow2: congress-rpm networking-vpp-rpm
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

opnfv-apex.tar.gz: images/overcloud-full-opendaylight.qcow2
	tar -czf opnfv-apex.tar.gz --xform="s:images/overcloud-full-opendaylight.qcow2:opnfv-apex-$(RPMVERS)/build/images/overcloud-full-opendaylight.qcow2:" images/overcloud-full-opendaylight.qcow2

.PHONY: opendaylight-rpm-check
opendaylight-rpm-check: opnfv-apex.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: opendaylight-rpm
opendaylight-rpm: opnfv-apex.tar.gz $(RPMODL)

$(RPMODL):
	@echo "Building the Apex OpenDaylight RPM"
	# build the overcloud RPM
	rpmbuild --clean -ba rpm_specs/opnfv-apex.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: opendaylight-rpm-clean
opendaylight-rpm-clean:

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
	@#rpmbuild --clean rpm_specs/opnfv-apex-onos.spec -D "release $(shell echo $RELEASE | tr -d '_-')"
	rm -rf opnfv-apex-onos.tar.gz

opnfv-apex-onos.tar.gz: images/overcloud-full-onos.qcow2
	tar -czf opnfv-apex-onos.tar.gz --xform="s:images/overcloud-full-onos.qcow2:opnfv-apex-onos-$(RPMVERS)/build/images/overcloud-full-onos.qcow2:" images/overcloud-full-onos.qcow2

.PHONY: onos-rpm-check
onos-rpm-check: opnfv-apex-onos.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-onos.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: onos-rpm
onos-rpm: opnfv-apex-onos.tar.gz $(RPMONO)

$(RPMONO):
	@echo "Building the Apex ONOS RPM"
	# build the overcloud RPM
	rpmbuild --clean -ba rpm_specs/opnfv-apex-onos.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

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
	# add packages to the centos packages
	cd centos/Packages && yumdownloader openvswitch
	cd centos/Packages && yumdownloader openstack-tripleo
	cd centos/Packages && yumdownloader jq
	cd centos/Packages && yumdownloader python34
	cd centos/Packages && yumdownloader python34-libs
	cd centos/Packages && yumdownloader python34-yaml
	cd centos/Packages && yumdownloader python34-setuptools
	cd centos/Packages && yumdownloader ipxe-roms-qemu
	cd centos/Packages && curl -O https://radez.fedorapeople.org/python34-markupsafe-0.23-9.el7.centos.x86_64.rpm
	cd centos/Packages && curl -O https://radez.fedorapeople.org/python3-jinja2-2.8-5.el7.centos.noarch.rpm
	cd centos/Packages && curl -O http://artifacts.opnfv.org/apex/dependencies/python3-ipmi-0.3.0-1.noarch.rpm
	# regenerate yum repo data
	@echo "Generating new yum metadata"
	createrepo --update -g ../c7-opnfv-x86_64-comps.xml centos
	# build the iso
	@echo "Building OPNFV iso"
	mkisofs -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -V "OPNFV CentOS 7 x86_64" -R -J -v -T -o $(ISO) centos
	isohybrid $(ISO)
	@printf "\n\nISO is built at $(ISO)\n\n"

####################
#  python3-jinja2  #
####################

.PHONY: python3-jinja2
python3-jinja2: python3-markupsafe python-jinja2-2.8-5.fc24.src.rpm
	curl -O http://ftp.linux.ncsu.edu/pub/fedora/linux//development/24/Everything/source/tree/Packages/p/python-jinja2-2.8-5.fc24.src.rpm
	rpm2cpio python-jinja2-2.8-5.fc24.src.rpm | cpio -idmv
	sed -i 's/python3-devel/python34-devel/' python-jinja2.spec
	sed -i 's/python3-setuptools/python34-setuptools/' python-jinja2.spec
	sed -i 's/python3-pytest/python34-pytest/' python-jinja2.spec
	sed -i 's/python3-markupsafe/python34-markupsafe/' python-jinja2.spec
	rpmbuild -ba python-jinja2.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "with_python3 1"

.PHONY: python3-jinja2-clean
python3-jinja2-clean:
	rm -f python-jinja2-2.8-5.fc24.src.rpm
	rm -f python-jinja2.spec
	rm -f Jinja2-2.8.tar.gz

########################
#  python3-markupsafe  #
########################

.PHONY: python3-markupsafe
python3-markupsafe: python-markupsafe-0.23-9.fc24.src.rpm
	curl -O http://ftp.linux.ncsu.edu/pub/fedora/linux//development/24/Everything/source/tree/Packages/p/python-markupsafe-0.23-9.fc24.src.rpm
	rpm2cpio python-markupsafe-0.23-9.fc24.src.rpm | cpio -idmv
	sed -i 's/python3-devel/python34-devel/' python-markupsafe.spec
	sed -i 's/python3-setuptools/python34-setuptools/' python-markupsafe.spec
	sed -i 's/python3-pytest/python34-pytest/' python-markupsafe.spec
	sed -i 's/python3-markupsafe/python34-markupsafe/' python-markupsafe.spec
	rpmbuild -ba python-markupsafe.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "with_python3 1"

.PHONY: python3-markupsafe-clean
python3-markupsafe-clean:
	rm -f python-markupsafe-0.23-9.fc24.src.rpm
	rm -f python-markupsafe.spec
	rm -f MarkupSafe-0.23.tar.gz
