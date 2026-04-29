# Issue #783 / #784 / #583 — DNS: udhcpc comment breaks nslookup; DHCP DNS silently ignored

**Upstream issues:** sipeed/NanoKVM#783, #784, #583  
**Applied to:** `buildroot/board/cvitek/SG200X/overlay/usr/share/udhcpc/default.script`

## Root cause

Two bugs in the udhcpc `default.script`:

### Bug 1 — `# eth0` comment breaks `nslookup` (#783)

`default.script` writes nameserver lines as:

```
nameserver 10.0.1.1 # eth0
```

`nslookup` (and musl's `resolv` parser) treats everything after whitespace as part of the
address. This causes:

```
nslookup: bad address '10.0.1.1 # eth0'
```

### Bug 2 — DHCP DNS silently discarded when `/boot/resolv.conf` exists (#784 / #583)

`default.script` redirects DNS writes to `/etc/resolv.conf.dhcp` whenever `/boot/resolv.conf`
is present. `/boot/resolv.conf` ships with six hardcoded nameservers (8.8.8.8, 8.8.4.4,
114.114.114.114, etc.) that may be unreachable in enterprise or isolated networks. DHCP-assigned
DNS is never applied, so update downloads (cdn.sipeed.com) and name resolution fail even when
the DHCP server advertises working nameservers.

## Fix

- Remove the `/boot/resolv.conf` redirect: always write DHCP DNS to `/etc/resolv.conf` so
  DHCP-assigned nameservers take effect.
- Strip `# $interface` from nameserver and search lines so musl's resolver can parse them.
- Keep the `grep -vE "# $interface$"` cleanup pattern for the `search` line (still tagged)
  and for `deconfig` to cleanly remove the interface's search domain on lease release.
