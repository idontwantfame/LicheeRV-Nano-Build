# Issue #270 — Some security issues

**Upstream issue:** sipeed/NanoKVM#270  
**Applied to:**
- `buildroot/configs/nanokvm.fragment` (remove tcpdump)
- `overlay/etc/ssh/sshd_config` (AllowTcpForwarding)
- `overlay/etc/init.d/S20firewall` (see #301, #630 — also addresses #270 firewall concerns)

## Issues addressed

### tcpdump on a production appliance

tcpdump is installed via the base defconfig (`BR2_PACKAGE_TCPDUMP=y`). On a device that
handles server credentials and HDMI/USB streams, an attacker with code execution can
capture and exfiltrate traffic. There is no operational reason to ship tcpdump on a
production KVM.

**Fix:** `# BR2_PACKAGE_TCPDUMP is not set` added to `nanokvm.fragment`.

### SSH TCP forwarding

`AllowTcpForwarding yes` in sshd_config lets SSH be used as a tunnel proxy (`-L`/`-R`).
Not needed for KVM access, and creates a pivot point if the device is compromised or
credentials are reused.

**Fix:** `AllowTcpForwarding no` in `overlay/etc/ssh/sshd_config`.

## Not fixed here (requires changes to NanoKVM-Server binary)

- **Hardcoded AES EncryptSecretKey** in TypeScript frontend (`kvmapp/web/js/*.js`) —
  the key is baked into the compiled JavaScript bundle; must be rotated in the source.
- **No CSRF protection** — requires middleware changes in the Go server.
- **30-day JWT TTL with no per-user invalidation** — requires Go server changes.
- **API/server runs as root** — Sipeed acknowledged; changing requires either a setuid
  wrapper or hardware-privilege separation not available in a single-binary build.
- **Update integrity** — downloaded ZIP files from `/kvmapp/system/etc/kvm/` endpoints
  are not hash- or signature-verified; requires Go server changes.
- **Tailscale phoning home before configuration** — Tailscale's own startup behaviour;
  not controllable from init scripts (FORWARD DROP in S20firewall prevents routing but
  not the Tailscale process itself from opening connections).

## Considered but not applied

- **Root password** (`BR2_TARGET_GENERIC_ROOT_PASSWD="root"` in base defconfig) — locking
  it with `!` is possible in `nanokvm.fragment` but would lock users out of serial console
  recovery and force SSH key setup before first access. Left for the user to decide.
- **PermitRootLogin / PasswordAuthentication** — similarly deferred: requiring key-only
  root SSH is correct for a hardened deployment, but the default image should remain
  accessible to first-time users who haven't yet run `ssh-copy-id`.
- **picoclaw AI component** (#794) — `nanokvm-prebuilt.mk` installs
  `/kvmapp/picoclaw` from the 2.4.0 tarball. Can be stripped in
  `nanokvm-post-build.sh` with `rm -rf "${TARGET}/kvmapp/picoclaw"` if desired.
