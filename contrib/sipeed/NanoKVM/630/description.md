# Issue #630 — Web UI not reachable from different subnet / internal firewall

**Upstream issue:** sipeed/NanoKVM#630  
**Applied to:** `overlay/etc/init.d/S20firewall` (new)

## Root cause

The original `S95nanokvm` iptables rules used default-ACCEPT policies with no DROP
anywhere, meaning ALL inbound traffic was accepted. Connections from a different
subnet (e.g. WireGuard/pfSense routed subnet) failing was therefore a routing or
WebRTC issue, not a firewall issue. The reporter's suggestion to "disable the
internal firewall" was based on a misunderstanding of the default-ACCEPT state.

The new `S20firewall` script changes this: INPUT is now default-DROP with explicit
ALLOW rules for port 22, 80, and 443 on eth0. Connections from routed subnets
(VPN, different LAN) will work as long as:

1. The routed subnet's traffic arrives on `eth0` (or `tailscale0` which is fully
   allowed)
2. The application (NanoKVM-Server) binds on `0.0.0.0` not just the local subnet IP
3. WebRTC video uses MJPEG or H.264 Direct modes, or a TURN server is configured
   (WebRTC peer-to-peer fails through NAT/routing — this is a WebRTC limitation,
   not a firewall issue)

## Tailscale interface

Traffic arriving via `tailscale0` is unconditionally accepted by `S20firewall`,
which is the recommended secure remote access path.
