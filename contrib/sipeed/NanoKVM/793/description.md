# Issue #793 — ntpd gives up at boot when DNS/NTP unreachable; time stuck at 1970

**Upstream issue:** sipeed/NanoKVM#793  
**Applied to:** `buildroot/board/cvitek/SG200X/overlay/etc/ntp.conf` (new overlay file)

## Root cause

The default `/etc/ntp.conf` uses four individual `server` entries:

```
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst
server 4.pool.ntp.org iburst
```

On cold boot after a power loss, the upstream router may not have finished booting when
NanoKVM starts ntpd. DNS resolution of `pool.ntp.org` fails, ntpd exhausts its retry
budget against all four servers, and gives up. The device stays in 1970.

Consequence: Tailscale refuses to connect (certificate validation requires sane system
time); SSL connections to update servers fail; log timestamps are wrong.

## Fix

Add `pool pool.ntp.org iburst` as the primary directive. The `pool` keyword instructs
ntpd to continuously re-resolve the pool hostname and replace peers as they become
available, rather than resolving once at startup and giving up. Individual `server`
entries are kept as explicit fallbacks for environments where the pool DNS is blocked.

Reference: https://community.ntppool.org/t/recommend-the-superior-pool-not-server-in-ntp-conf/2590
