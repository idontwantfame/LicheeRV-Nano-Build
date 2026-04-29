# LicheeRV-Nano-Build

Fork of the upstream Sipeed LicheeRV-Nano-Build, extended to support building a
minimal NanoKVM image for the SG2002 SoC. Minimal means the default Buildroot
package set is trimmed: tools irrelevant to a KVM appliance (benchmarks, audio,
Bluetooth, WiFi stack, games, Python, debug utilities) are removed to keep the
rootfs lean and focused. Changes include a dedicated sg2002_nanokvm_sd board, a
build-nanokvm.sh script with pre-built binary and from-source modes, Go toolchain
download fixes, and a Buildroot shrink pass.

See [NANOKVM.md](NANOKVM.md) for the full NanoKVM build guide.

---

## Prerequisites

Clone this repository and the required host tools:

```
git clone <this-repo-url> --depth=1

cd LicheeRV-Nano-Build

git clone https://github.com/sophgo/host-tools --depth=1
```

## Building NanoKVM

See [NANOKVM.md](NANOKVM.md) for the full guide. Quick start:

```
./build-nanokvm.sh
```
