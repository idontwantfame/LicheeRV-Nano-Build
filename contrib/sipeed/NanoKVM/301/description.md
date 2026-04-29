# Issue #301 — Security: hardcoded DNS, Tailscale ip_forward, UPnP, general hardening

**Upstream issue:** sipeed/NanoKVM#301 (Sipeed's official security response thread)  
**Related:** #270, #399, #583, #630  
**Applied to:**
- `overlay/etc/init.d/S20firewall` (new — firewall neutralises ip_forward routing)
- `overlay/etc/init.d/S30eth` (static IP path: removed hardcoded 8.8.8.8/114.114.114.114)
- `overlay/etc/init.d/S95nanokvm` (removed broken iptables block)

## Issues addressed

### Hardcoded public DNS (#399, #583)

`/kvmapp/system/init.d/S30eth` (upstream) and our overlay's `S30eth` static IP path
both wrote hardcoded `nameserver 8.8.8.8` and `nameserver 114.114.114.114` to
`/etc/resolv.conf` on every boot. This:
- Overrides any DNS advertised by DHCP
- Breaks name resolution in air-gapped / enterprise / split-horizon networks
- Sends DNS queries to third-party servers for a device that may handle
  sensitive server credentials

**Fix:** Static IP path now writes only the gateway IP as nameserver.
DHCP path fix is covered by #783/#784.

### Tailscale sets `net.ipv4.ip_forward=1` globally (#301)

Tailscale's startup sysctl turns the NanoKVM into a full IP router, forwarding
traffic between all interfaces. Sipeed acknowledged this; suggested deleting
`/etc/sysctl.d/99-tailscale.conf` as workaround.

**Fix:** `S20firewall` sets `iptables -P FORWARD DROP`. The kernel consults iptables
for forwarding decisions even when `ip_forward=1`, so the DROP policy effectively
prevents all forwarding without disabling ip_forward (which Tailscale needs for
its own tunnel). If explicit forwarding is needed (e.g. usb0→eth0 for the USB
RNDIS-to-LAN case), add specific FORWARD rules manually.

### Broken iptables in S95nanokvm

The original iptables block in `S95nanokvm`:
1. Had no default DROP — all rules APPENDED to a default-ACCEPT policy,
   making them completely redundant
2. SSH rules were for an SSH *client* (OUTPUT dport 22 + INPUT sport 22),
   not an SSH *server* — inbound SSH only worked because of the ACCEPT default
3. The port 8000 OUTPUT DROP blocked *responses* not *connections*, and was
   ineffective even as intended

**Fix:** All iptables management moved to `S20firewall` which runs before any
service binds. Rules are correct and the policy is default-deny.

## Not fixed here (requires changes to NanoKVM-Server binary)

- Tailscale phoning home (STUN, log.tailscale.io) before being configured
- UPnP/IGD port mapping requests at boot
- Authentication transport (hardcoded AES key in TypeScript, no TLS default)
- API running as root
- No CSRF protection
- 30-day JWT TTL with no per-user invalidation
