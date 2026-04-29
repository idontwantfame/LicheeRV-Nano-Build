################################################################################
#
# nanokvm-prebuilt
#
# Downloads the official NanoKVM release tarball and installs it into
# /kvmapp/ without building from source.  The tarball is self-contained:
# it includes the NanoKVM-Server binary (RISC-V64 musl), all Sophgo dl_lib
# .so files, the compiled React web UI, kvm_system, jpg_stream, and the
# application-level init scripts under /kvmapp/system/init.d/.
#
# To build from source instead, use nanokvm-sg200x + nanokvm-server.
#
################################################################################

NANOKVM_PREBUILT_VERSION = 2.4.0
NANOKVM_PREBUILT_SITE = https://github.com/sipeed/NanoKVM/releases/download/$(NANOKVM_PREBUILT_VERSION)
NANOKVM_PREBUILT_SOURCE = nanokvm_$(NANOKVM_PREBUILT_VERSION).tar.gz

# Nothing to compile — pre-built binaries for RISC-V64 musl (ld-musl-riscv64xthead.so.1)
define NANOKVM_PREBUILT_BUILD_CMDS
endef

define NANOKVM_PREBUILT_INSTALL_TARGET_CMDS
	mkdir -pv $(TARGET_DIR)/kvmapp/

	# Server binary, Sophgo dl_lib shared libraries, and React web UI
	cp -a $(@D)/server $(TARGET_DIR)/kvmapp/

	# kvm_system and kvm_stream binaries (video capture pipeline)
	cp -a $(@D)/kvm_system $(TARGET_DIR)/kvmapp/

	# jpg_stream binary and its init script
	cp -a $(@D)/jpg_stream $(TARGET_DIR)/kvmapp/

	# KVM sysfs-style control files (resolution, fps, etc.)
	cp -a $(@D)/kvm $(TARGET_DIR)/kvmapp/

	# Application-level init scripts, kernel module, and tools
	cp -a $(@D)/system $(TARGET_DIR)/kvmapp/

	# Agentic KVM skill files
	cp -a $(@D)/picoclaw $(TARGET_DIR)/kvmapp/

	# Version marker — read by the NanoKVM server at runtime
	install -m 0644 $(@D)/version $(TARGET_DIR)/kvmapp/

	# Ensure executables are marked executable after cp -a
	chmod +x $(TARGET_DIR)/kvmapp/server/NanoKVM-Server
	chmod +x $(TARGET_DIR)/kvmapp/kvm_system/kvm_system
	chmod +x $(TARGET_DIR)/kvmapp/kvm_system/kvm_stream
	chmod +x $(TARGET_DIR)/kvmapp/jpg_stream/jpg_stream

	# Fix iptables SSH rules: the upstream rules were written for an SSH client
	# (allow outbound to port 22); correct them to allow inbound SSH to the device.
	sed -i \
		-e 's/OUTPUT -o eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED/INPUT -i eth0 -p tcp --sport 22 -m state --state NEW,ESTABLISHED/g' \
		-e 's/INPUT -i eth0 -p tcp --sport 22 -m state --state ESTABLISHED/OUTPUT -o eth0 -p tcp --dport 22 -m state --state ESTABLISHED/g' \
		$(TARGET_DIR)/kvmapp/system/init.d/S95nanokvm

	# Fix NTP sync: NTP starts before the network is up and never syncs; restart
	# it after the server starts so the clock is corrected once eth0 is ready.
	sed -i 's|/tmp/server/NanoKVM-Server &|/tmp/server/NanoKVM-Server \&\n\n    /etc/init.d/S49ntp restart|' \
		$(TARGET_DIR)/kvmapp/system/init.d/S95nanokvm
endef

$(eval $(generic-package))
