# LicheeRV-Nano-Build for NanoKVM Cube

## How & Why?

### How?

Grabbed https://github.com/sipeed/LicheeRV-Nano-Build and just used Claude to do crap for me that I would do anyway which was just faster...

### Why?

Because we know original image is 💩💩💩.

It has lots of crap that doesn't need to be there, so it was trimmed, patched, and fixed.

| Metric | Old Image | New Image |
| -------- | ------- | ------- |
| Bundled KVM app version | 2.2.0 | 2.4.0 |
| HTTPS enabled by default | No | Yes |
| Root space used | 750M | 313M |
| Partition size | 8G | 1G |
| RAM used after boot | ~35M | ~30M |
| trivy rootfs | many | 0 |

See [NANOKVM.md](NANOKVM.md) for all the details and build guide.

---

## Quick start

Clone this repository and the required host tools:

```bash
git clone <this-repo-url> --depth=1
cd LicheeRV-Nano-Build
git clone https://github.com/sophgo/host-tools --depth=1
cd host/archlinux
docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t licheervnano-build-archlinux .
docker run --rm -it -v "$(pwd)/../..":/build licheervnano-build-archlinux bash
./build-nanokvm.sh
```
