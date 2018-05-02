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
export RPMVERS = $(shell grep Version $(shell pwd)/rpm_specs/opnfv-apex-common.spec | head -n 1 | awk '{ print $$2 }')

export BUILD_ROOT = $(shell pwd)
export BUILD_DIR = $(shell dirname $$(pwd))/.build
export CACHE_DIR = $(shell dirname $$(pwd))/.cache
export RPM_DIR_ARGS = -D '_topdir $(BUILD_DIR)' -D '_builddir $(BUILD_DIR)' -D '_sourcedir $(BUILD_DIR)' -D '_rpmdir $(BUILD_DIR)' -D '_specdir $(BUILD_DIR)' -D '_srcrpmdir $(BUILD_DIR)'
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
rpms-check: common-rpm-check

.PHONY: rpms-clean
rpms-clean:
	rm -rf $(BUILD_DIR)/noarch
	rm -rf $(BUILD_DIR)/BUILDROOT

$(BUILD_DIR)/opnfv-apex-common.tar.gz:
	mkdir -p $(BUILD_DIR)
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

