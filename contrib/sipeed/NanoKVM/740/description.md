# Issue #740 — USB RNDIS gadget gets a random MAC address on each host reboot

**Upstream issue:** sipeed/NanoKVM#740  
**Applied to:** `buildroot/board/cvitek/SG200X/overlay/etc/init.d/S03usbhid`

## Root cause

When the Linux USB gadget framework creates an RNDIS function without explicit MAC addresses,
the kernel generates random values for `host_addr` and `dev_addr` on each gadget bind.
From the host's perspective, the USB ethernet adapter appears as a new device after every
NanoKVM reboot: a new MAC, a new DHCP lease, and potentially a new IP address. Hosts that
assign static IPs based on MAC address (common in enterprise and home lab setups) cannot
rely on the adapter's identity.

## Fix

Derive deterministic MAC addresses from the device's serial key (`/device_key`) using
SHA-512. The first 10 hex digits of the hash give 5 MAC address octets; the first byte is
forced to `0x02` (locally administered, unicast) to avoid conflicts with OUI-registered
addresses.

Two distinct seeds (`${KEY}host` and `${KEY}dev`) produce different MACs for `host_addr`
(the host PC side) and `dev_addr` (the NanoKVM usb0 side), both stable across reboots.
