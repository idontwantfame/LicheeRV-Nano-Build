# Issue #300 — KVM pings network gateway constantly

**Upstream issue:** sipeed/NanoKVM#300  
**Applied to:** `overlay/etc/kvm/stop_ping` (new empty sentinel file)

## Root cause

`kvm_system` calls `chack_net_state()` which pings the default gateway every 2 seconds
to determine whether Ethernet is up. This is a workaround for a hardware bug in the
SG2002 chip's internal PHY — the kernel-provided link status is frequently wrong, so
Sipeed uses ICMP echo as an alternative.

The constant ping is:
- Noisy on the network (one ICMP echo every 2s, always to the gateway)
- Irrelevant on link-local or IPv6-only networks that have no IPv4 gateway
- A minor privacy/observability concern (announces the device's presence continuously)

## Fix

`kvm_system` checks for `/etc/kvm/stop_ping` at startup. If the file exists, the ping
loop is disabled. The overlay ships the file so pinging is off by default.

Sipeed's documented workaround is:
```
touch /etc/kvm/stop_ping && /etc/init.d/S95nanokvm restart
```

## Tradeoff

Disabling the ping means `kvm_system` falls back to the kernel PHY status for Ethernet
state detection. On the SG2002 this status can be unreliable — the web UI's network
status indicator may show stale state after a cable unplug/replug. KVM functionality
itself (video, HID, serial) is unaffected; only the status display is impacted.

For a device on a stable network this is the better default. Users who need reliable
link-state detection can `rm /etc/kvm/stop_ping` to re-enable gateway pinging.
