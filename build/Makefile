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
export RPMVERS = $(shell grep Version $(shell pwd)/rpm_specs/opnfv-apex.spec | head -n 1 | awk '{ print $$2 }')
export RPMCOM = $(shell pwd)/noarch/opnfv-apex-common-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMUDR = $(shell pwd)/noarch/opnfv-apex-undercloud-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMODL = $(shell pwd)/noarch/opnfv-apex-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMONO = $(shell pwd)/noarch/opnfv-apex-onos-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMSFC = $(shell pwd)/noarch/opnfv-apex-opendaylight-sfc-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm

all_networks="admin_network private_network storage_network external_network api_network"



.PHONY: all
all: iso

.PHONY: clean
clean: images-clean rpms-clean iso-clean tacker-clean congress-clean vpp-clean

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
	@rm -rf openstack-tacker-2015.2
	@rm -f openstack-tacker.tar.gz

openstack-tacker.tar.gz:
	@echo "Preparing the Tacker RPM prerequisites"
	git clone http://github.com/trozet/tacker -b SFC_colorado openstack-tacker-2015.2
	tar czf openstack-tacker.tar.gz openstack-tacker-2015.2

.PHONY: tacker-rpm
tacker-rpm: openstack-tacker.tar.gz openstack-tacker-2015.2-1.trozet.noarch.rpm

openstack-tacker-2015.2-1.trozet.noarch.rpm:
	@echo "Building the Tacker RPM"
	rpmbuild --clean -bb --target noarch rpm_specs/openstack-tacker.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)'

#################
#  TACKERCLIENT #
#################

.PHONY: tackerclient-clean

tackerclient-clean:
	@rm -rf python-tackerclient-2015.2
	@rm -f python-tackerclient.tar.gz

python-tackerclient.tar.gz:
	@echo "Preparing the TackerClient RPM prerequisites"
	git clone http://github.com/trozet/python-tackerclient -b SFC_refactor python-tackerclient-2015.2
	tar czf python-tackerclient.tar.gz python-tackerclient-2015.2

.PHONY: tackerclient-rpm
tackerclient-rpm: python-tackerclient.tar.gz python-tackerclient-2015.2-1.trozet.noarch.rpm

python-tackerclient-2015.2-1.trozet.noarch.rpm:
	@echo "Building the TackerClient RPM"
	rpmbuild --clean -bb --target noarch rpm_specs/python-tackerclient.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)'

###############
#  CONGRESS   #
###############

.PHONY: congress-clean

congress-clean:
	@rm -rf openstack-congress-2016.1
	@rm -f openstack-congress.tar.gz

openstack-congress.tar.gz:
	@echo "Preparing the Congress RPM prerequisites"
	git clone http://github.com/openstack/congress -b stable/mitaka openstack-congress-2016.1
	cd openstack-congress-2016.1 && curl -O https://radez.fedorapeople.org/openstack-congress.service
	tar czf openstack-congress.tar.gz openstack-congress-2016.1

.PHONY: congress-rpm
congress-rpm: openstack-congress.tar.gz openstack-congress-2016.1-1.noarch.rpm

openstack-congress-2016.1-1.noarch.rpm:
	@echo "Building the Congress RPM"
	rpmbuild --clean -bb --target noarch rpm_specs/openstack-congress.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)'

###############
#     VPP     #
###############

VPP_DIR = vpp
MAVEN = apache-maven-3.3.9
MAVEN_FILE = $(MAVEN)-bin.tar.gz

.PHONY: vpp-clean
vpp-clean:
	@rm -f vpp-bin.tar.gz
	@rm -rf vpp-bin vpp
	@rm -rf honeycomb $(MAVEN) $(MAVEN_FILE) honeycomb-1.0.0-99.noarch.rpm
	@rm -rf networking-vpp networking-vpp.noarch.rpm

.PHONY: vpp-build
vpp-build: vpp-bin.tar.gz

vpp-bin.tar.gz: vpp honeycomb $(MAVEN)
	$(MAKE) -C $(VPP_DIR) UNATTENDED=yes install-dep bootstrap build pkg-rpm
	$(MAKE) -C $(VPP_DIR)/build-root PLATFORM=vpp TAG=vpp_debug vpp-api-install
	pushd vpp/vpp-api/python && python setup.py bdist
	pushd vpp/build-root/build-vpp-native/vpp-api/java/ && ../../../../../$(MAVEN)/bin/mvn install:install-file -Dfile=jvpp-registry-16.12.jar -DgroupId=io.fd.vpp -DartifactId=jvpp-registry -Dversion=16.12-SNAPSHOT -Dpackaging=jar
	pushd vpp/build-root/build-vpp-native/vpp-api/java/ && ../../../../../$(MAVEN)/bin/mvn install:install-file -Dfile=jvpp-core-16.12.jar -DgroupId=io.fd.vpp -DartifactId=jvpp-core -Dversion=16.12-SNAPSHOT -Dpackaging=jar
	pushd honeycomb && ../$(MAVEN)/bin/mvn clean install -DskipTests
	pushd honeycomb/packaging/rpm/ && BUILD_NUMBER=99 ./rpmbuild.sh
	mkdir vpp-bin
	mv vpp/build-root/*.rpm vpp-bin/
	mv honeycomb/packaging/rpm/RPMS/noarch/*.rpm .
	mv vpp/vpp-api/python/dist/*.tar.gz vpp-bin/
	tar czf vpp-bin.tar.gz vpp-bin

vpp:
	git clone https://gerrit.fd.io/r/vpp

honeycomb:
	git clone https://gerrit.fd.io/r/p/honeycomb.git

$(MAVEN): $(MAVEN_FILE)
	tar zxvf apache-maven-3.3.9-bin.tar.gz
	cp mvn_settings.xml $(MAVEN)/conf/settings.xml

$(MAVEN_FILE):
	wget http://www.webhostingjams.com/mirror/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz

.PHONY: networking-vpp-rpm
networking-vpp-rpm: networking-vpp.noarch.rpm

networking-vpp.noarch.rpm: networking-vpp
	pushd networking-vpp && python setup.py bdist_rpm --binary-only
	mv networking-vpp/dist/*.rpm networking-vpp.noarch.rpm

networking-vpp:
	git clone https://git.openstack.org/openstack/networking-vpp

###############
#  UNDERCLOUD #
###############

.PHONY: undercloud-clean
undercloud-clean:
	@rm -f images/undercloud.*

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

###############
#  OVERCLOUD  #
###############

.PHONY: overcloud-full-clean
overcloud-full-clean:
	@rm -rf images/overcloud-full.d
	@rm -f images/overcloud-full.*

.PHONY: overcloud-full
overcloud-full: images/overcloud-full.qcow2

images/overcloud-full.qcow2: tacker-rpm tackerclient-rpm congress-rpm networking-vpp-rpm
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
	@rpmbuild --clean rpm_specs/opnfv-apex-onos.spec -D "release $(shell echo $RELEASE | tr -d '_-')"

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

opnfv-apex-opendaylight-sfc.tar.gz: images/overcloud-full-opendaylight-sfc.qcow2
	tar -czf opnfv-apex-opendaylight-sfc.tar.gz --xform="s:images/overcloud-full-opendaylight-sfc.qcow2:opnfv-apex-opendaylight-sfc-$(RPMVERS)/build/images/overcloud-full-opendaylight-sfc.qcow2:" images/overcloud-full-opendaylight-sfc.qcow2

.PHONY: opendaylight-sfc-rpm-check
opendaylight-sfc-rpm-check: opnfv-apex-opendaylight-sfc.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-opendaylight-sfc.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: opendaylight-sfc-rpm
opendaylight-sfc-rpm: opnfv-apex-opendaylight-sfc.tar.gz $(RPMSFC)

$(RPMSFC):
	@echo "Building the Apex OpenDaylight SFC RPM"
	rpmbuild --clean -ba rpm_specs/opnfv-apex-opendaylight-sfc.spec -D '_topdir %(echo `pwd`)' -D '_builddir %(echo `pwd`)' -D '_sourcedir %(echo `pwd`)' -D '_rpmdir %(echo `pwd`)' -D '_specdir %(echo `pwd`)' -D '_srcrpmdir %(echo `pwd`)' -D "release $(shell echo $(RELEASE) | tr -d '_-')"

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
