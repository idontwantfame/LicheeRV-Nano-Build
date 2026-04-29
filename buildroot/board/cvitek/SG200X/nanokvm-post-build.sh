#!/bin/sh
# Post-build script for NanoKVM images.
# Called by buildroot with TARGET_DIR as $1 after all packages are installed
# but before the filesystem image is created.

TARGET="$1"

# ---- /mnt/system/usr/bin: Sophgo middleware dev/test tools ------------------
# Build-time test applications from the middleware SDK (~3 MB).
rm -rf "${TARGET}/mnt/system/usr/bin"

# ---- /mnt/system/ko: modules irrelevant on NanoKVM -------------------------
rm -f "${TARGET}/mnt/system/ko/efivarfs.ko"    # EFI variables — no EFI on RISC-V
rm -f "${TARGET}/mnt/system/ko/backlight.ko"   # LCD backlight — kernel support removed
rm -f "${TARGET}/mnt/system/ko/pwm_bl.ko"      # PWM backlight — kernel support removed

# ---- Init scripts: hardware not present on NanoKVM PCIe --------------------
# WiFi — kernel CFG80211/AIC8800 disabled, CP_EXT_WIRELESS disabled
rm -f "${TARGET}/etc/init.d/S25wifimod"
rm -f "${TARGET}/etc/init.d/S30wifi"

# S03usbdev (Rev2.1) is superseded by S03usbhid for NanoKVM.  Both scripts
# are unconditional and assign the UDC — running both causes a double
# bind/unbind that the host sees as a spurious USB disconnect at boot.
rm -f "${TARGET}/etc/init.d/S03usbdev"

# S08usbdev is the MaixCAM generic gadget configurator — gated on /boot/usb.dev,
# which NanoKVM also creates to enable S30gadget_nic.  Without removal it runs
# at S08, after S03usbhid, and re-creates the gadget with licheervnano identity
# causing a second USB reset and wrong device name on the host.
rm -f "${TARGET}/etc/init.d/S08usbdev"

# LCD backlight — kernel BACKLIGHT_CLASS_DEVICE/BACKLIGHT_PWM removed
rm -f "${TARGET}/etc/init.d/S04backlight"

# Touchscreen — kernel INPUT_TOUCHSCREEN removed; modules won't be present
rm -f "${TARGET}/etc/init.d/S05tp"

# Framebuffer — only activates if /boot/fb flag exists, never set on NanoKVM
rm -f "${TARGET}/etc/init.d/S04fb"

# MaixCAM UI scripts — Qt fingerpaint demo, input-event key binding, ADB monitor
rm -f "${TARGET}/etc/gui.sh"
rm -f "${TARGET}/etc/input-event-daemon.conf"
rm -f "${TARGET}/etc/adbd_monitor.sh"

# ---- Init scripts: Sophgo SDK diagnostic/test scripts ----------------------
# None of these run at KVM runtime; they're MaixCAM manufacturing/QA tools.
rm -f "${TARGET}/etc/init.d/S99audtest"
rm -f "${TARGET}/etc/init.d/S99camtest"
rm -f "${TARGET}/etc/init.d/S99ednctest"
rm -f "${TARGET}/etc/init.d/S99input-event-daemon"
rm -f "${TARGET}/etc/init.d/S99ivetest"
rm -f "${TARGET}/etc/init.d/S99lcdtest"
rm -f "${TARGET}/etc/init.d/S99loadtest"
rm -f "${TARGET}/etc/init.d/S99modeltest"
rm -f "${TARGET}/etc/init.d/S99nettest"
rm -f "${TARGET}/etc/init.d/S99nntest"
rm -f "${TARGET}/etc/init.d/S99temptest"

# ---- /etc/passwd + /etc/shadow: unused system accounts ---------------------
# ftp      — vsftpd removed from build
# mail     — no mail server
# www-data — no web server (NanoKVM serves over its own Go binary)
# operator — legacy placeholder, no service uses it
# sync     — allows anyone with shell access to sync; unnecessary
for ACCOUNT in ftp mail www-data operator sync; do
    sed -i "/^${ACCOUNT}:/d" "${TARGET}/etc/passwd"
    sed -i "/^${ACCOUNT}:/d" "${TARGET}/etc/shadow" 2>/dev/null || true
    sed -i "/^${ACCOUNT}:/d" "${TARGET}/etc/group"  2>/dev/null || true
done

# ---- libopencv_video.so.409 stub for NanoKVM-Server -------------------------
# libkvm.so in the prebuilt NanoKVM tarball has DT_NEEDED libopencv_video.so.409
# but the tarball doesn't ship it.  Compile a minimal valid ELF stub here so the
# dynamic linker resolves the reference without the nanokvm-prebuilt package
# stamp-file caching getting in the way.
STUB="${TARGET}/kvmapp/server/dl_lib/libopencv_video.so.409"
if [ ! -f "${STUB}" ]; then
    HOST_DIR="$(dirname "${TARGET}")/host"
    CROSS_GCC=$(for f in "${HOST_DIR}/bin/"*-linux-*-gcc; do [ -f "$f" ] && case "$f" in *++) ;; *) echo "$f" ;; esac; done | head -1)
    if [ -n "${CROSS_GCC}" ]; then
        echo '' | "${CROSS_GCC}" -shared -Wl,-soname,libopencv_video.so.409 \
            -nostdlib -x c - -o "${STUB}"
        echo "Created libopencv_video.so.409 stub at ${STUB}"
    else
        echo "WARNING: cross-compiler not found; libopencv_video.so.409 stub not created" >&2
        echo "  NanoKVM-Server will fail to start — run with --clean to rebuild nanokvm-prebuilt" >&2
    fi
fi
