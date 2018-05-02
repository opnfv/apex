##############################################################################
# Copyright (c) 2016 Red Hat Inc.
# dradez@redhat.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

export USE_MASTER = ""
export RELEASE = "0"

export RPM_DIST = $(shell rpm -E %dist)

export NETVPP_VERS := $(shell grep Version $(shell pwd)/rpm_specs/networking-vpp.spec | head -n 1 | awk '{ print $$2 }')
export NETVPP_REPO := $(shell awk -F\= '/^netvpp_repo/ {print $$2}' variables.sh )
export NETVPP_BRANCH := $(shell awk -F\= '/^netvpp_branch/ {print $$2}' variables.sh )
export NETVPP_COMMIT := $(shell git ls-remote $(NETVPP_REPO) $(NETVPP_BRANCH) | awk '{print substr($$1,1,7)}')

export RELRPMVERS = $(shell grep Version $(shell pwd)/rpm_specs/opnfv-apex-release.spec | head -n 1 | awk '{ print $$2 }')
export RPMVERS = $(shell grep Version $(shell pwd)/rpm_specs/opnfv-apex.spec | head -n 1 | awk '{ print $$2 }')

export BUILD_ROOT = $(shell pwd)
export BUILD_DIR = $(shell dirname $$(pwd))/.build
export CACHE_DIR = $(shell dirname $$(pwd))/.cache
export RPM_DIR_ARGS = -D '_topdir $(BUILD_DIR)' -D '_builddir $(BUILD_DIR)' -D '_sourcedir $(BUILD_DIR)' -D '_rpmdir $(BUILD_DIR)' -D '_specdir $(BUILD_DIR)' -D '_srcrpmdir $(BUILD_DIR)'

export RPMREL = $(BUILD_DIR)/noarch/opnfv-apex-release-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm
export RPMCOM = $(BUILD_DIR)/noarch/python34-opnfv-apex-$(RPMVERS)-$(shell echo ${RELEASE} | tr -d '_-').noarch.rpm

.PHONY: all
all: rpms

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean-cache
clean-cache:
	rm -rf $(CACHE_DIR)

.PHONY: rpms
rpms: common-rpm

.PHONY: rpms-check
rpms-check: release-rpm-check common-rpm-check

.PHONY: rpms-clean
rpms-clean:
	rm -rf $(BUILD_DIR)/noarch
	rm -rf $(BUILD_DIR)/BUILDROOT

$(BUILD_DIR)/opnfv-apex-release.tar.gz:
	mkdir -p $(BUILD_DIR)
	pushd ../ && git archive --format=tar.gz --prefix=opnfv-apex-release-$(RELRPMVERS)/ HEAD > $(BUILD_DIR)/opnfv-apex-release.tar.gz

.PHONY: release-rpm-check
release-rpm-check: $(BUILD_DIR)/opnfv-apex-release.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-release.spec $(RPM_DIR_ARGS) -D "_release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: release-rpm
release-rpm: $(BUILD_DIR)/opnfv-apex-release.tar.gz $(RPMREL)

$(RPMREL):
	@echo "Building the Apex Release RPM"
	# build the release RPM
	rpmbuild --clean -ba rpm_specs/opnfv-apex-release.spec $(RPM_DIR_ARGS) -D "_release $(shell echo $(RELEASE) | tr -d '_-')"

$(BUILD_DIR)/opnfv-apex-common.tar.gz:
	pushd ../ && git archive --format=tar.gz --prefix=opnfv-apex-$(RPMVERS)/ HEAD > $(BUILD_DIR)/opnfv-apex-common.tar.gz

.PHONY: common-rpm-check
common-rpm-check: $(BUILD_DIR)/opnfv-apex-common.tar.gz
	rpmbuild --clean -bi -bl rpm_specs/opnfv-apex-common.spec $(RPM_DIR_ARGS) -D "_release $(shell echo $(RELEASE) | tr -d '_-')"

.PHONY: common-rpm
common-rpm: $(BUILD_DIR)/opnfv-apex-common.tar.gz $(RPMCOM)

$(RPMCOM):
	@echo "Building the Apex Common RPM"
	# build the common RPM
	rpmbuild --clean -ba rpm_specs/opnfv-apex-common.spec $(RPM_DIR_ARGS) -D "_release $(shell echo $(RELEASE) | tr -d '_-')"

##################
#  PYTHON TESTS  #
##################

.PHONY: python-tests
python-tests:
	tox -e py35

#######################
#  PYTHON PEP8 CHECK  #
#######################

.PHONY: python-pep8-check
python-pep8-check:
	tox -e pep8

#############
#  YAMLLINT #
#############

.PHONY: yamllint
yamllint:
	@echo "Running yamllint against all .yaml files"
	cd ../ && yamllint $(shell cd ../ && git ls-tree -r HEAD --name-only | grep 'yaml$$')
#############
#  RPMLINT  #
#############

.PHONY: rpmlint
rpmlint:
	@echo "Running rpmlint against all RPM spec files"
	rpmlint rpm_specs/*.spec

##################
# NETWORKING-VPP #
##################

$(BUILD_DIR)/python-networking-vpp.tar.gz:
	@echo "Preparing the networking-vpp RPM prerequisites"
	git clone $(NETVPP_REPO) -b $(NETVPP_BRANCH) $(BUILD_DIR)/python-networking-vpp-$(NETVPP_VERS)
	tar czf $(BUILD_DIR)/python-networking-vpp.tar.gz -C $(BUILD_DIR) python-networking-vpp-$(NETVPP_VERS)

.PHONY: networking-vpp-rpm
networking-vpp-rpm: $(BUILD_DIR)/noarch/python-networking-vpp-*.noarch.rpm

$(BUILD_DIR)/noarch/python-networking-vpp-*.noarch.rpm: $(BUILD_DIR)/python-networking-vpp.tar.gz
	@echo "Building the Networking VPP RPM"
	rpmbuild --clean -ba --target noarch rpm_specs/networking-vpp.spec $(RPM_DIR_ARGS) -D 'git .git$(NETVPP_COMMIT)'
