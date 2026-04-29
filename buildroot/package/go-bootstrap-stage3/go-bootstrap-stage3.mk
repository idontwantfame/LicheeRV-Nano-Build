################################################################################
#
# go-bootstrap-stage3
#
################################################################################

# Go 1.23.x requires a Go >= 1.20 bootstrap; stage2 (1.19.11) is too old.
# Stage3 builds Go 1.21.7 using stage2, bridging the bootstrap gap.
GO_BOOTSTRAP_STAGE3_VERSION = 1.21.7
GO_BOOTSTRAP_STAGE3_SITE = https://dl.google.com/go
GO_BOOTSTRAP_STAGE3_SOURCE = go$(GO_BOOTSTRAP_STAGE3_VERSION).src.tar.gz

GO_BOOTSTRAP_STAGE3_LICENSE = BSD-3-Clause
GO_BOOTSTRAP_STAGE3_LICENSE_FILES = LICENSE

HOST_GO_BOOTSTRAP_STAGE3_DEPENDENCIES = host-go-bootstrap-stage2

HOST_GO_BOOTSTRAP_STAGE3_ROOT = $(HOST_DIR)/lib/go-$(GO_BOOTSTRAP_STAGE3_VERSION)

# The go build system is not compatible with ccache, so use
# HOSTCC_NOCCACHE.  See https://github.com/golang/go/issues/11685.
HOST_GO_BOOTSTRAP_STAGE3_MAKE_ENV = \
	GO111MODULE=off \
	GOROOT_BOOTSTRAP=$(HOST_GO_BOOTSTRAP_STAGE2_ROOT) \
	GOROOT_FINAL=$(HOST_GO_BOOTSTRAP_STAGE3_ROOT) \
	GOROOT="$(@D)" \
	GOBIN="$(@D)/bin" \
	GOOS=linux \
	CC=$(HOSTCC_NOCCACHE) \
	CXX=$(HOSTCXX_NOCCACHE) \
	CGO_ENABLED=0

define HOST_GO_BOOTSTRAP_STAGE3_BUILD_CMDS
	cd $(@D)/src && \
		$(HOST_GO_BOOTSTRAP_STAGE3_MAKE_ENV) ./make.bash $(if $(VERBOSE),-v)
endef

define HOST_GO_BOOTSTRAP_STAGE3_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/go $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/bin/go
	$(INSTALL) -D -m 0755 $(@D)/bin/gofmt $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/bin/gofmt

	cp -a $(@D)/lib $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/

	mkdir -p $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/pkg
	cp -a $(@D)/pkg/include $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/pkg/
	cp -a $(@D)/pkg/tool $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/pkg/

	# The Go sources must be installed to the host/ tree for the Go stdlib.
	cp -a $(@D)/src $(HOST_GO_BOOTSTRAP_STAGE3_ROOT)/
	# per-package-rsync unconditionally syncs target/ from every dependency;
	# create an empty dir so that rsync doesn't fail for this host-only package.
	mkdir -p $(HOST_DIR)/../target
endef

$(eval $(host-generic-package))
