# Issue #442 — mDNS still works after disabling; SSDP always active

**Upstream issue:** sipeed/NanoKVM#442  
**Applied to:**
- `overlay/etc/init.d/S50avahi-daemon` (gated on `/boot/avahi.enable`)
- `overlay/etc/init.d/S50ssdpd` (gated on `/boot/ssdp.enable`)
- `overlay/etc/init.d/S20firewall` (blocks udp/5353 and udp/1900 unless flags present)

## Root cause

The NanoKVM web UI writes a config flag for mDNS into NanoKVM-Server's
`/etc/kvm/server.yaml`, but `S50avahi-daemon` starts `avahi-daemon` unconditionally
without reading that config. So the UI "disable" toggle only prevents the Go server
from advertising via mDNS — the avahi daemon itself keeps running and answering
`.local` queries.

There is no equivalent UI toggle for SSDP; `S50ssdpd` always starts.

## Security concern

Both mDNS and SSDP are network discovery protocols that:
- Advertise the device's hostname, IP, and services to the entire LAN
- Accept inbound queries from any host on the segment
- Have had security vulnerabilities in avahi (CVE-2021-3502, CVE-2021-26720)
- Are unnecessary on an appliance that is accessed by IP or hostname directly

## Fix

Both init scripts now check for a `/boot/` flag file before starting:
- `/boot/avahi.enable` → start avahi-daemon (mDNS)
- `/boot/ssdp.enable` → start ssdpd (SSDP/UPnP device discovery)

Neither flag is created by `sd_gen_burn_image_rootless.sh`, so both services
are off by default. Users who want LAN discovery (e.g. to find the device
via `nanokvm.local`) can `touch /boot/avahi.enable` on the boot partition.

`S20firewall` also blocks udp/5353 and udp/1900 on eth0 unless the respective
flag is present, providing a defence-in-depth layer if the init script flags
are bypassed.
