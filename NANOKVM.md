# Building a Minimal NanoKVM Image

This document describes how to build a clean, minimal NanoKVM image using
this repository as the base OS. It replaces the official Sipeed NanoKVM image,
which bundles unrelated packages (aircrack-ng, Python stack, OpenCV, games,
benchmarks) into an appliance device that needs none of them.

## Architecture

```
LicheeRV-Nano-Build (this repo)
  └── sg2002_nanokvm_sd board config
        ├── kernel (Linux 5.10)  — USB HID, RNDIS, UVC already enabled
        ├── u-boot              — identical to licheervnano_sd hardware
        └── buildroot rootfs
              ├── nanokvm-prebuilt  — installs official release tarball into /kvmapp/  [DEFAULT]
              │     (or, with --from-source:)
              ├── nanokvm-sg200x   — assembles /kvmapp/ from skeleton + server
              │     └── nanokvm-server  — builds Go binary + React web UI from source
              ├── ser2net           — serial-to-network bridge (UART access)
              ├── openssh           — SSH
              └── iptables          — NanoKVM uses it for SSH port forwarding
```

The NanoKVM application ships via one of two buildroot packages, depending on build mode:

- **nanokvm-prebuilt** (default): downloads the official `sipeed/NanoKVM` release tarball.
  The tarball is self-contained: RISC-V64 musl binary, Sophgo `dl_lib` `.so` files,
  compiled React web UI, `kvm_system`, `jpg_stream`, and application init scripts.
  The package applies two post-install fixes (see below).

- **nanokvm-sg200x** + **nanokvm-server** (`--from-source`): builds the Go backend and
  React frontend from source using the upstream `sipeed/NanoKVM` repo, then merges the
  result with the `scpcom/nanokvm-skeleton` bundle into `/kvmapp/`.

### Patches applied to the prebuilt package

These fixes are sed-applied at install time because the prebuilt tarball is not compiled
from source:

- **iptables SSH direction fix**: the upstream `S95nanokvm` init script has the iptables
  rules backwards -- they were written to allow an SSH _client_ (OUTPUT --dport 22)
  rather than an SSH _server_ (INPUT --sport 22). Corrected so inbound SSH to the device
  is actually permitted.

- **NTP sync fix**: NTP starts at boot before eth0 is up so the initial sync always fails.
  After NanoKVM-Server starts (by which point the network is ready), S95nanokvm now
  restarts the NTP init script to force a sync.

### LT6911 sensor config

`buildroot/board/cvitek/SG200X/overlay/mnt/data/sensor_cfg.ini.LT` is installed into
`/mnt/data/` on the rootfs. This config is required for devices with the LT6911 HDMI
bridge input; without it the NanoKVM server segfaults on startup when an LT6911 is
present.

## Board: sg2002_nanokvm_sd

Located at `build/boards/sg200x/sg2002_nanokvm_sd/`. Identical hardware to
`sg2002_licheervnano_sd` (same SG2002 SoC, same DDR, same partition layout)
with two memory map changes:

| Setting | licheervnano_sd | nanokvm_sd | Reason |
|---------|----------------|------------|--------|
| `ION_SIZE` | 105 MB | 75 MB | No local display pipeline; frees ~30 MB for user space |
| `BOOTLOGO_SIZE` | 8000 KB | 5632 KB | Smaller boot logo buffer, no LCD |

## Prerequisites

- Docker — see `host/archlinux/`
- The `middleware/v2/` tree cloned alongside this repo (provides Sophgo ISP/VPU libs)
- `host-tools/` cloned (RISC-V toolchains)

All are documented in the main `README.md`.

## Step 1 — Build environment

```bash
cd host/archlinux

docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t licheervnano-build-archlinux .

docker run --rm -it -v "$(pwd)/../..":/build licheervnano-build-archlinux bash
```

The `--build-arg UID/GID` bake your host user's IDs into the image so the
container's `build` user owns the mounted files — this lets autotools
`configure` run without the root safety check.

## Step 2 — Build the NanoKVM image

```bash
bash ./build-nanokvm.sh
```

The script:
1. Loads `sg2002_nanokvm_sd` board config (sets up kernel/u-boot/toolchain env)
2. Merges `buildroot/configs/nanokvm.fragment` on top of
   `cvitek_SG200X_musl_riscv64_defconfig` using Buildroot's `merge_config.sh`,
   producing an ephemeral derived config; appends the NanoKVM package
3. Calls `build_all`
4. Cleans up the ephemeral derived buildroot config

The fragment (`buildroot/configs/nanokvm.fragment`) is the version-controlled
source of truth for the package delta — adds ser2net, disables packages not
needed on NanoKVM hardware.

The output image lands in `install/soc_sg2002_nanokvm_sd/`.

All output is tee'd to `/tmp/nanokvm-build-YYYYMMDD-HHMMSS.log` automatically.

### Options

```bash
bash ./build-nanokvm.sh --no-shrink    # keep all default packages, add nanokvm only
bash ./build-nanokvm.sh --from-source  # build NanoKVM from source (Go + React + CGO)
bash ./build-nanokvm.sh --clean        # wipe board build artifacts before building
```

### Build utilities

**`clean.sh`** — removes all build output from the working tree so the repo is
safe to commit. By default keeps `buildroot/dl/` (1+ GB of downloaded tarballs)
to avoid re-fetching on the next build.

```bash
./clean.sh        # wipe output dirs, keep download cache
./clean.sh --dl   # also wipe buildroot/dl/ (full clean)
```

Removes: `buildroot/output/`, `install/`, `linux_5.10/build/`,
`fsbl/build/`, `u-boot-2021.10/build/`, `freertos/build/`, `.pnpm-store/`.

**`show-build-errors.sh`** — parses a build log for failures. Automatically
picks the most recent `/tmp/nanokvm-build-*.log`, or accepts an explicit path.

```bash
./show-build-errors.sh                        # latest log
./show-build-errors.sh /tmp/nanokvm-build-*.log
```

Outputs: all `>>>` stage markers (which packages ran), the last stage before
the first `make` error (failed package), matching error lines, and a context
window around the first failure.

## Step 3 — Flash

Standard SD card flashing — same as any LicheeRV Nano image:

```bash
# Replace /dev/sdX with your SD card device
dd if=install/soc_sg2002_nanokvm_sd/*.img of=/dev/sdX bs=4M status=progress
```

## What's included vs excluded

### Included (runtime dependencies)
| Package | Why |
|---------|-----|
| `nanokvm-prebuilt` | NanoKVM application (`/kvmapp/`) — official release tarball |
| `ser2net` | Bridges UART to TCP — allows serial console access to the controlled machine |
| `openssh` | SSH management access to the KVM device itself |
| `iptables` | NanoKVM uses it for SSH port forwarding |
| USB HID gadget | Keyboard + mouse emulation (kernel, already compiled in) |
| USB RNDIS gadget | Network-over-USB for laptop-only setups (kernel, already compiled in) |
| USB mass storage | Exposes SD card partition over USB |

With `--from-source`, `nanokvm-prebuilt` is replaced by `nanokvm-sg200x` + `nanokvm-server`.

### Excluded by `--shrink` (default)

#### No hardware support on NanoKVM PCIe/USB
| Package | Binaries | Reason |
|---------|----------|--------|
| `bluez5_utils`, `bluez-alsa`, `bluez-tools` | hci*, bt-*, l2ping, rfcomm, btattach, sdptool | No Bluetooth hardware |
| `wpa_supplicant` | wpa_supplicant, wpa_cli, wpa_passphrase | No WiFi hardware |
| `wireless-tools` | iwconfig, iwlist, iwgetid, iwpriv, iwspy, ifrename | No WiFi hardware |
| `iw` | iw, rfkill | No WiFi hardware |
| `hostapd` | hostapd, hostapd_cli | No WiFi hardware — and a KVM doesn't need an AP |
| `fbset` | fbset | No local display output |
| `alsa-utils` | alsamixer, amixer, aplay, arecord | No audio pipeline on NanoKVM |

#### Security risk — attack surface with no benefit
| Package | Binaries | Reason |
|---------|----------|--------|
| `aircrack-ng` | airbase-ng, aireplay-ng, airmon-ng, airodump-ng, besside-ng, easside-ng, tkiptun-ng, wesside-ng, and others | WiFi auditing / pentesting toolkit — no WiFi hardware and no legitimate use on an appliance |
| `macchanger` | macchanger | MAC address spoofing — no legitimate use case on a KVM appliance |
| `bind` | mdig, delv, named-rrchecker, arpaname | Full DNS server toolset — exposes unnecessary attack surface; busybox `nslookup` is sufficient |
| `pppd` | pppd, pppdump, pppoe-discovery, chat | PPP dial-up/DSL stack — no use case; unnecessary network protocol handler |

#### Redundant / superseded
| Package | Binaries | Reason |
|---------|----------|--------|
| `tinc` | tincd | Third VPN daemon — WireGuard and Tailscale already cover VPN access |
| `haveged` | haveged | Hardware entropy daemon — SG2002 has a hardware RNG and `seedrng` is already present at boot |
| `ipmitool` | ipmitool, ipmievd | IPMI/BMC server management — entirely unrelated to IP-KVM; NanoKVM manages its own hardware |
| `sqlite` | sqlite3 | Embedded database — no NanoKVM component uses a database |
| `ffmpeg`, `mpg123` | ffmpeg, ffprobe, mpg123 | Media frameworks — NanoKVM uses its own MaixCDK/kvm_system video pipeline |
| `opencv4` | (libraries) | Computer vision — same reason as ffmpeg |
| `libwebsockets` | (library) | WebSocket library — NanoKVM server brings its own |

#### Development and debug tools
| Package | Binaries | Reason |
|---------|----------|--------|
| `gdb` | gdb, gdbserver, gdb-add-index | Source-level debugger — dev tool, not for production appliance |
| `strace` | strace, strace-log-merge | Syscall tracer — dev tool |
| `evtest`, `libevdev` | evtest, libevdev-tweak-device, mouse-dpi-tool, touchpad-edge-detector | Input device testing — dev tools |
| `spidev_test` | spidev_test | SPI bus test utility — dev tool |
| `tmux` | tmux | Terminal multiplexer — not needed on an appliance |
| `setserial` | setserial | Low-level serial port configuration — ser2net handles serial |
| `expect`, `tcl` | expect, tclsh | Scripting / test automation — not used at runtime |
| `squashfs-tools` | mksquashfs, unsquashfs | SquashFS manipulation — not needed at runtime |

#### Benchmarks and toys
| Package | Binaries | Reason |
|---------|----------|--------|
| `dhrystone`, `coremark`, `ramspeed`, `stress` | dhrystone, coremark, ramspeed, stress-ng | CPU/memory benchmarks — no use on an appliance |
| `iperf3` | iperf3 | Network bandwidth benchmark — same category |
| `ascii-invaders`, `gnuchess`, `sl`, `xorcurses`, `lcdtest` | ascii_invaders, gnuchess, sl, xorcurses | Games and toys |

#### Redundant transfer tools
| Package | Binaries | Reason |
|---------|----------|--------|
| `mosh` | mosh, mosh-client, mosh-server | Mobile shell — SSH covers remote access |
| `lrzsz` | lrz, lrzcat, lrzip, rx, sb, sx, sz | XMODEM/YMODEM/ZMODEM serial file transfer — not needed |

#### Python runtime (not used by NanoKVM)
| Package | Reason |
|---------|--------|
| `python3` + all `python-*` packages | NanoKVM-Server is a Go binary; the web UI is pre-built React. No Python runs at runtime. The fragment disables `BR2_PACKAGE_PYTHON3` which cascades to all sub-packages via dependency resolution. |

## USB gadget configuration

The boot FAT partition contains marker files that the init system reads to
configure USB gadgets on boot. The `sg_gen_burn_image_rootless.sh` and
`genimage_rootless.cfg` files in `build/tools/common/sd_tools/` have been
updated for NanoKVM:

| File | Purpose |
|------|---------|
| `usb.dev` | USB device mode (always present) |
| `usb.rndis0` | RNDIS network interface — SSH over USB |
| `usb.disk0` | Mass storage — exposes `/dev/mmcblk0p3` over USB |
| `usb.keyboard` | HID keyboard emulation |
| `usb.mouse` | HID mouse emulation |
| `usb.touchpad` | HID touchpad emulation |
| `hostname.prefix` | Sets hostname prefix to `kvm` |

## Remaining steps (not yet done)

- ~~**Step 3**: Write a minimal buildroot config fragment~~ — Done.
  `buildroot/configs/nanokvm.fragment` is the version-controlled package delta.
  `build-nanokvm.sh` applies it via `merge_config.sh -m` (shrink mode) or falls
  back to a copy + manual ser2net injection (--no-shrink mode).
- ~~**Step 4**: Audit the kernel config~~ — Done. Removed in `sg2002_nanokvm_sd_defconfig`:
  - **WiFi/RF**: `CFG80211`, `RFKILL`, `AIC_WLAN_SUPPORT`, `USB_NET_RNDIS_WLAN`
    (`RTL8188FU` was already off; USB gadget RNDIS kept)
  - **Audio**: `SOUND` and all `SND_*` drivers (SoC codec, I2S, USB audio),
    `USB_U_AUDIO`, `USB_F_UAC1` — no audio hardware on NanoKVM
  - **Bluetooth**: `BT` and all sub-protocols/transports — no BT hardware
  - **Filesystems**: `JFFS2`, `UBIFS` (NAND only), `SQUASHFS` (not in boot path)
    (`EXFAT_FS` kept — `S01fs` formats `/dev/mmcblk0p3` exFAT for USB mass storage)
  - **Display**: `BACKLIGHT_CLASS_DEVICE`, `BACKLIGHT_PWM` — no LCD
  - **Input**: `INPUT_TOUCHSCREEN`, `MAGIC_SYSRQ` — headless appliance
    (`INPUT_UINPUT` kept — NanoKVM server uses it for HID gadget injection)
  - **LED**: `V4L2_FLASH_LED_CLASS` — no camera flash
  - **Network**: `IP_VS` (load balancer with all protocols/schedulers disabled)
  - **Locale**: `NLS_ISO8859_1/2/3` — UTF-8 only
  - Left alone: `FB`/`FB_CVITEK` (ISP/VPU pipeline risk), LED GPIO framework
    (status LEDs), `USB_VIDEO_CLASS` (conservative)
- ~~**Step 5**: Verify musl compatibility of the pre-built libs~~ — Done. The official
  release tarball links against `ld-musl-riscv64xthead.so.1`; confirmed RISC-V64 musl.
- ~~**Step 6**: First boot validation~~ — Done. Two successful builds completed.
- ~~**OpenSSL hardening**~~ — Done. Added to `nanokvm.fragment`: `ENABLE_SSL3`,
  `ENABLE_WEAK_SSL`, and `UNSECURE` (unit-test/debug infrastructure) disabled.
  SSLv3 (POODLE) and weak cipher suites have no use on a production KVM appliance.

## Package security updates (to do)

The toolchain and kernel are frozen by the SoC vendor and cannot be bumped.
The following application packages can be updated with a version + hash change
in their `.mk` / `.hash` files — patches need a rebase check but are small.

| Package | Current | Action | Priority |
|---------|---------|--------|----------|
| ~~**OpenSSH**~~ | ~~9.6p1~~ | Done — bumped to 9.9p2 | ~~**High** — CVE-2024-6387 (regreSSHion, RCE in sshd) affects ≤ 9.7p1~~ |
| ~~**OpenSSL**~~ | ~~3.1.4~~ | Done — bumped to 3.5.6 LTS (3.1.x EOL); 2 upstreamed patches dropped, 1 non-MMU patch dropped (irrelevant on SG2002) | ~~**High**~~ |
| ~~**BusyBox**~~ | ~~1.36.1~~ | Done — bumped to 1.37.0 | ~~Low — stability / minor CVEs~~ |

Process for each:
1. Update `VERSION` in `buildroot/package/<pkg>/<pkg>.mk`
2. Fetch the SHA256 of the new tarball from the project's download page
3. Update `buildroot/package/<pkg>/<pkg>.hash`
4. Verify patches still apply: `patch --dry-run -p1 < *.patch` against new source
5. Delete the package stamp and rebuild: `rm buildroot/output/build/<pkg>-*/.stamp_*`

Packages that **cannot** be updated: the cross-compiler (GCC 10.2.0, T-Head
Xuantie-900 proprietary fork), Linux 5.10.4 (SG2002-specific patch set), and
musl 1.2.4 (ABI-coupled to the pre-built external toolchain).

## Known unknowns

- The prebuilt version is pinned to `2.4.0` of `sipeed/NanoKVM` (latest as of
  2026-04-10). Run `./update-nanokvm-prebuilt.sh [VERSION]` to bump — it fetches
  `sha256.txt` from the release and rewrites the `.mk` and `.hash` files automatically.
  After bumping, check whether the iptables/NTP patches in `nanokvm-prebuilt.mk` still
  apply cleanly against the new `S95nanokvm`. For the from-source path, bump
  `NANOKVM_SERVER_VERSION` / `NANOKVM_SG200X_VERSION` in their respective `.mk` files
  manually (no equivalent helper yet).

- BusyBox 1.37.0 `SHA1_HWACCEL`/`SHA256_HWACCEL`: the upstream `busybox.mk` guard that
  disables these options was scoped to `BR2_i386` only, leaving RISC-V unprotected
  (enabling either option causes an undeclared-identifier compile error because
  `get_shaNI()` contains x86 `cpuid` inline assembly). Fixed in our tree: the guard is
  now `ifeq ($(BR2_i386)$(BR2_x86_64),)` — disabled on all non-x86 architectures.
