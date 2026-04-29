# Issue #748 — udhcpc missing Option 121 (classless static routes)

**Upstream issue:** sipeed/NanoKVM#748  
**Upstream PR:** sipeed/NanoKVM#749  
**Applied to:** `buildroot/board/cvitek/SG200X/overlay/etc/init.d/S30eth`

## Root cause

udhcpc is started without `-O 121`, so DHCP Option 121 (Classless Static Routes, RFC 3442)
is never requested or processed. Networks that distribute routes via Option 121 (e.g. VPNs,
multi-subnet enterprise LANs) will not have those routes installed on the NanoKVM.

`default.script` already has the `$staticroutes` handling block (the RFC 3442 note at line 70
and the `set -- $staticroutes; while` loop). It just never gets populated because the option
is not requested.

## Fix

Add `-O 121` to both udhcpc invocations in `S30eth` (the fallback DHCP call inside the static
address block, and the primary DHCP call).
