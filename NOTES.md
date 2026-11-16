# InvizBox Go — OpenWrt 24.10 port drafts

Scaffold artifacts for the Phase A → Phase B hop of the OpenWrt-24.10 port.
See [`../invizbox-go-recovery-session-2026-11-14.md`](../invizbox-go-recovery-session-2026-11-14.md) §9c for the full plan; this directory holds the early concrete code.

## Files

- `mt7621_invizbox_invizboxgo.dts` — the DTS, modernized to 24.10-expected syntax. Drop this at `target/linux/ramips/dts/` in a fresh openwrt-24.10 tree.
- `mt7621.mk-invizbox-stanza.diff` — the image-build stanza to add to `target/linux/ramips/image/mt7621.mk`, right before the first `ioaccess_*` or similar alphabetical neighbor.

## What's confirmed (Phase A recon, 2026-11-15)

- openwrt-24.10 is kernel 6.6; ramips/mt7621 target has **292 devices**, **95 of which use `kmod-mt7603`** — our WiFi chip is well-supported upstream.
- No `invizbox_invizboxgo` profile in upstream — must be added (it never was).
- `mtk-eip93` is still external (not in 24.10 feeds) — pulled from `github.com/vschagen/mtk-eip93.git`, still actively maintained (last push 2026-04). Branches of interest: `final`, `master`, `refactored`. Pick one that supports kernel 6.6.
- `mt76` driver has mt7603 support mainline; no work needed on the WiFi.
- Deprecated syntax count in the 4.4.1 DTS: **2** (`mtd-mac-address` on gmac0, `mediatek,mtd-eeprom` on wifi) — both replaced in the draft DTS with nvmem-cells.

## Phase B — DTS + target port (next)

1. Clone openwrt-24.10 to a fresh tree (we already have `$WORKDIR/openwrt-24.10` populated).
2. `cp mt7621_invizbox_invizboxgo.dts <tree>/target/linux/ramips/dts/`.
3. Edit `<tree>/target/linux/ramips/image/mt7621.mk` and paste the stanza from `mt7621.mk-invizbox-stanza.diff` at an alphabetical location.
4. Base-files single-gmac entry — not strictly needed since the Go has no ethernet; DSA on single-port is handled by `$(Device/dsa-migration)` plus a one-line default in `target/linux/ramips/base-files/etc/board.d/02_network` (follow the pattern of any other single-port mt7621 device).
5. `make menuconfig` → pick target `ramips`, subtarget `mt7621`, profile `InvizBox Go`.
6. `make -j$(nproc)` to build a bare OpenWrt image for the Go.
7. Verify output lives at `bin/targets/ramips/mt7621/openwrt-ramips-mt7621-invizbox_invizboxgo-squashfs-sysupgrade.bin`.

## Phase B test loop

Every iteration goes through USB-recovery (Path B from the design notes) because we have **no serial console** without opening the case.

1. Build the image.
2. Write to the Fedora USB stick (currently `/dev/sdb` on the build host) as `root_uImage`.
3. On the Go: power off, insert stick, pin-hold reset while powering on 10 s, wait ~2 min for solid-red WiFi LED.
4. If boot succeeds: stock OpenWrt comes up with default LAN `192.168.1.1`. SSH as `root` with no password on first boot.
5. If boot fails: write the known-good 4.4.1 `root_uImage` and try again from §5 of the recovery report.

Budget ~10 min per iteration. First boot may surface:
- LED mapping wrong (adjust `boot`/`failsafe` alias to a working LED).
- Flash partition size mismatch (unlikely — kept same reg from 4.4.1).
- mt7603 EEPROM not found (check nvmem-cell address is `0x0..0x200`, the historical mt7603 cal blob size).
- No upstream net (expected — no ethernet; join its default SSID instead).

## Phase C — firewall3 → firewall4 (nftables) migration

OpenWrt 22.03+ ships `package/network/config/firewall4` (nftables-backed) alongside legacy `firewall`. uci schema is mostly preserved. The Go's custom firewall at `invizbox/firmware/src/files/go/etc/config/firewall` has 3 networks (`lan_vpn1`, `lan_tor`, `lan_clear1`), multiple zones, firewall marks (1/16/32) for policy-routed per-network traffic, and 3 DNS DNAT redirects.

**Concrete migrations needed:**

| 4.4.1 (iptables) | 24.10 firewall4 (nftables) equivalent |
|---|---|
| `option extra '-m conntrack --ctstate NEW'` in `conntrack_all` rule | `option ct_state 'new'` (firewall4 keyword) |
| `config redirect 'dns_*' { target 'DNAT' … }` | unchanged — firewall4 reads this schema |
| Everything else (zones, rules, forwards, marks) | unchanged schema |

The only true breakage is the single `extra` line with raw iptables args. Everything else is a schema-preserved uci bump.

## Phase D red flag — the `eth0.3` dummy interface

The Go's `/etc/config/network` has:

```
config interface 'tor'
    option ifname 'eth0.3'
    option ipaddr '172.31.1.1'
    …
```

That's a VLAN sub-device on eth0 used for *internal routing only* (the Go has no physical ethernet). On swconfig/21.02 this just worked as a dummy endpoint. **On DSA (22.03+) the `eth0.N` namespace doesn't exist** — devices go through `lanN.N` or `wan.N` style, and there's no eth0 to VLAN-sub-divide when the DSA switch has no physical ports mapped.

Options for porting:
1. **Replace with a `dummy` device**: `config device 'dummy_tor' { option type 'dummy' option name 'dummy_tor' }` then `interface tor { option device 'dummy_tor' … }`. OpenWrt has `kmod-dummy` for this.
2. **Replace with a `veth` pair**: `ip link add tor_internal type veth` via a startup script, bind the uci interface to it.
3. **Replace with a `tun` or `tap`** interface already created elsewhere.

Option 1 is cleanest. Only requires `kmod-dummy` in DEVICE_PACKAGES + a `/etc/config/network` tweak. Flag for Phase D package port; the DTS and target port in Phase B are unaffected by this.

## Phase E — integration test loop

Once Phase D produces an image with the custom UI + rest-api + eip93 crypto:

1. USB-recover-flash the new 24.10 image onto the Go.
2. Join the AP (SSID + PSK from the factory mtd2 — unchanged by sysupgrade, see recovery report §4).
3. Walk through the wizard via the React UI.
4. Point `/etc/config/update` at a VPS endpoint you control.
5. Test STA upstream (associate to the upstream AP again as in this session).
6. Test VPN: OpenVPN first (simpler), then strongSwan IKEv2 (harder — the `strongswan-eap-mschapv2` custom package may need rewriting for strongSwan 6.x API).
7. Test Tor mode.
8. Test opkg install from your VPS.

Expect this phase to surface uci-defaults migration bugs (`configuration-update-mt7621` has version-sensitive upgrade logic from 4.0.13 through 4.1.13, and we'd want a new 4.4.1 → 24.10 migration script).

## Phase F — handoff docs

- Updated recovery runbook (equivalent of §5 of the main report, for the 24.10 build).
- `./build.sh go-24.10` wrapper mirroring the structure of invizbox's `build.sh`, baked into your `invizbox/firmware` fork at a branch.
- Rollback tests documented.

## mtk-eip93 upstream status (2026-11-15)

`github.com/vschagen/mtk-eip93` branches:

| Branch | Last commit | Fit |
|---|---|---|
| `master` | 2020-12-10 (`bb5fd1c8`) | Original. 5.x kernel era. What InvizBox 4.4.1 pins. |
| `split` | 2020-12-14 | Dead end. |
| `final` | 2021-10-28 (`ca08387b`) | Still stale. |
| **`refactored`** | **2026-04-08** (`2e1735a6`) | **Active branch.** No root Makefile → pure kernel module source. **Target for the 24.10 port.** |

For the 24.10 port: bump `invizbox/feed/mtk-eip93/Makefile`:
- `PKG_SOURCE_VERSION := 2e1735a64874` (or current tip of `refactored`)
- Add branch pin: `PKG_SOURCE_BRANCH := refactored` (so git clone picks the right ref)
- Verify module compiles against the openwrt-24.10 kernel 6.6 headers; iterate if the API surface moved.

If `refactored` doesn't build on 6.6 on first attempt, fallback is **skip eip93 crypto accel entirely**. The MT7621 CPU does software AES/SHA at ~50-80 Mbps — tolerable for a travel VPN router. Dropping eip93 removes a porting dependency and the device remains fully functional, just slower under VPN load.

## Port progress log

| Date | Phase | Status |
|---|---|---|
| 2026-11-14 | — (recovery) | Flashed 4.0.12 → 4.4.1, 4.4.1 image + 4.2.3 safety image saved to `<artifacts>/` |
| 2026-11-15 | A (recon) | Done. openwrt-24.10 cloned. DTS + mt7621.mk stanza + 03_wireless + firewall4 + eth0.3-dummy flag + mtk-eip93 branch — all identified. |
| 2026-11-15 | B (DTS + target port) | **Run 1 built clean** (DTS compiled, kernel 6.6.159, sysupgrade 7.5 MB). Not flashed: 24.10 generates the radio disabled and the Go has no Ethernet, so it would boot unreachable. |
| 2026-11-15 | B run 2 | Added `03_invizbox_wireless` (this dir; installed at `target/linux/ramips/mt7621/base-files/etc/uci-defaults/`): enables radio, SSID `InvizBoxGo`, PSK read from factory partition offset 65520 (16 bytes), LAN `10.153.146.1/24`, `bridge_empty`. Built in 58 s. Saved as `<artifacts>/OpenWrt-24.10-phaseB-run2-invizboxgo-sysupgrade.bin` (sha256 `b69f0e02…ff38b7`). **Untested on hardware.** |
| — | C (firewall4 migration) | Planned. Scope captured above. |
| — | D (InvizBox packages port) | Planned. Scope captured above. |
| — | E (integration testing) | Planned. |
| — | F (handoff docs) | Planned. |

Latest known-good interim images (durable in `<artifacts>/`):
- `InvizBox-Go-4.4.1-sysupgrade.bin` (sha256 `80abc905…dac9dca7`) — flashed, running on-device
- `InvizBox-Go-4.4.1-sec1-ssl1.1.1w-sysupgrade.bin` (sha256 `b9fd6164…e40b2ef34c`) — OpenSSL bumped, not yet flashed
- `InvizBox-Go-4.2.3-sysupgrade.bin` (sha256 `ac6ecfee…72f83954`) — Path-B safety, not used

Tourniquet sec2 (openssl + strongswan 5.9.14) failed to build 2026-11-15 00:13 UTC — strongswan patches reject on 5.9.14. Next retry: target 5.9.5 (last tested 21.02 version) instead of 5.9.14. Or drop strongswan from the tourniquet entirely since OpenWrt 24.10 will replace it anyway.

## Rollback

At every step, `<artifacts>/InvizBox-Go-4.4.1-sysupgrade.bin` (sha256 `80abc9…dac9dca7`) is the known-good fallback. Write it to the stick as `root_uImage`, pin-reset-boot, device comes back on 4.4.1 ignoring whatever we were testing.

## Flashing the 24.10 image over a running 4.4.1 (found 2026-11-15)

The image metadata is `compat_version 1.1` ("Config cannot be migrated from swconfig to DSA"); 4.4.1 reports 1.0.

- **4.4.1 REST API cannot deliver it.** `rest-api/src/system/firmware.py` runs `sysupgrade --test` on upload (fails on the compat mismatch) and flashes with `sysupgrade -n`, never `-F`.
- **SSH route:** enable SSH on the Go (`PUT /api/system/ssh_keys`), copy the image to `/tmp`, run `sysupgrade -F -n <image>`. Wipes config.
- **USB route:** write the image to a FAT32 stick as `root_uImage`, hold reset while powering on ~10 s, wait for solid red. Bypasses sysupgrade checks.
- Before either, stage a rollback stick with the 4.4.1 image (recovery report section 5, tier B).
- Standing rule: no writes to any USB stick or the device without the operator's explicit go-ahead. Decision on 2026-11-15: hold off.

## Not yet verified on hardware (run 2)

- factory partition PSK offset/mtd lookup (`find_mtd_index factory`, `dd skip=65520 count=16`)
- empty `br-lan` bring-up with only the Wi-Fi AP as a member
- mt7603 EEPROM nvmem cell (`0x0`, `0x200`) and gmac0 MAC cell (`0x22`, 6 bytes) addressing
- LED aliases

## Run 2 on hardware (flashed 2026-11-15 via ssh `sysupgrade -F -n` from 4.4.1)

Verified working: boots, kernel 6.6.159, board name `invizbox,invizboxgo`; `03_invizbox_wireless` ran (radio enabled, SSID `InvizBoxGo`, WPA2 with the PSK read from factory partition offset 65520, LAN 10.153.146.1/24, empty `br-lan` came up, DHCP served 10.153.146.x); mtd layout identical to 4.4.1 (`mtd2` = factory); jffs2 overlay mounted after the first-boot format (~3 min of blinking green, then solid green = done).

**Bug found (fixed in run 3):** EEPROM nvmem cell was `reg = <0x0 0x200>`; mt76 needs `0x400`. Symptom: `mt7603e: Invalid MAC address, using random address` (got `82:8e:e0:03:05:22`; the real MAC is at factory+4 = `<factory MAC>`) and default calibration. Run 3 image: `OpenWrt-24.10-phaseB-run3-invizboxgo-sysupgrade.bin`, sha256 `c40f3fe6…7753a3`. Not yet flashed.

Still open on the running run-2 image: root has no password and dropbear accepts a blank-password login (anyone with the Wi-Fi PSK); `failed to sync jffs2 overlay` appeared once in the first boot log (expected on a fresh overlay, recheck after a reboot that settings persist).

Gotchas hit while flashing: 4.4.1's BusyBox has no `nohup`; its API enables SSH per profile (`PUT /api/profiles/0` with `ssh.enabled:true`), not via the key endpoint.

## Run 3 on hardware (flashed 2026-11-15 00:46 via `sysupgrade` with settings kept)

Image `OpenWrt-24.10-phaseB-run3-invizboxgo-sysupgrade.bin`, sha256 `c40f3fe6b3f3f09c7bdf93eeef20b5e6d3b7c2dc3be2ad8021c5353c397753a3`. **Running on the bench Go now.**

Verified: no `Invalid MAC address` from mt7603e; AP is the real factory MAC `<factory MAC>` (EEPROM nvmem cell `0x400` fix confirmed); SSID `InvizBoxGo`/WPA2/LAN `10.153.146.1/24` survived a keep-settings upgrade; `authorized_keys` survived; solid green LED = boot done; jffs2 overlay on `mtdblock6`; ~3 min from flash to usable network.

Access: key-only SSH, `root@10.153.146.1`, key `<artifacts>/ssh/id_ed25519_invizbox`, host key in `ssh/known_hosts_24.10`. Dropbear `PasswordAuth`/`RootPasswordAuth` are off (blank-password login refused). Join the AP from the build host with the existing NM profile `InvizBoxGo` on dongle `wlp189s0f4u1u4` (`ipv4.never-default yes`). Do not retry `nmcli connection up` in a loop: each call restarts the DHCP wait; scan first and join once with `--wait 30`.

Updated unverified list: LED aliases beyond boot/done (not exercised), nvmem MAC cell for gmac0 (0x22) addressing (no Ethernet to observe), STA+AP concurrent mode (not yet configured), reboot persistence of settings (settings did persist across the keep-settings upgrade, plain reboot not yet tested).

Next (Phase C/D, nothing started): firewall4 migration of the Go's firewall config; replace `eth0.3` with a `dummy` device; rebuild the InvizBox feed packages (admin-interface, rest-api, etc.) against 24.10; mtk-eip93 on kernel 6.6 (`refactored` branch) or skip it.

## Phase D progress (2026-11-15): InvizBox feed on 24.10

Working repos on the build host (not durable; patches exported to `patches/` here): `$WORKDIR/openwrt-24.10` (branch `invizbox-go`: DTS, image stanza, first-boot script) and `$WORKDIR/invizbox-feed` (branch `go-24.10`, based on invizbox/feed @ bef0a9b). Wired together with `src-link invizbox /feed` in `feeds.conf`; build runs in the podman container with `-v invizbox-feed:/feed`.

Findings:
- **mtk-eip93 is obsolete.** 24.10 ships the upstream driver (`kmod-crypto-hw-eip93`, default on mt7621). On the running Go: `mtk-eip93 1e004000.crypto: EIP93 Crypto Engine Initialized`, hardware algos at priority 1500. The out-of-tree package clashes with it and was deleted from the feed branch. No kernel-driver port needed.
- **Relative includes break with src-link.** Python helper includes now use `$(TOPDIR)/feeds/packages/lang/python/...`.
- **rest-api** hard-coded `python3.9` (init script, install path); now taken from `$(PYTHON3_PKG_DIR)`. Dropped deps on `strongswan-eap-mschapv2` (a provider-certificate bundle, unused by the Go) and iptables; diagnostics snapshot uses `nft list ruleset`; TLS is `libustream-mbedtls`. No Python-3.12-sensitive imports found in the REST API source (still to be proven by running it).
- `tor-basic` exists upstream; the `tor`/`tor-basic` Kconfig "recursive dependency" message is harmless (same in 4.4.1 builds).
- Only `netwatch2` is used by the Go (not `netwatch`, `configuration-update-ib2/mt7620`, `usb-automount-ib2`, `luci-app-invizbox`).

**Open design work (not mechanical): `etc/firewall.user` is hand-written iptables** and implements the Go's three-network policy: transparent Tor redirect (hotspot "tor" -> 172.31.1.1:9040 and the router's own traffic to 10.192.0.0/16), masquerade out the STA uplink (`wlan0`) and VPN (`tun1`), forwarding bridge<->uplink, and a connmark scheme for device-to-device traffic across the three bridges. fw4 cannot take iptables scripts; it needs a native uci/nft port. `netwatch2/bin/set_captive.ash` and `unset_captive.ash` also use iptables (captive-portal handling). Also the dummy device for `eth0.3` (the `tor` interface, 172.31.1.1).

## Phase D result (2026-11-15): image with the InvizBox packages builds (run 5)

`<artifacts>/OpenWrt-24.10-phaseD-run5-invizbox-pkgs-sysupgrade.bin`, 17.6 MB, sha256 `b715b2e82725e094d96caeedb6b50ab088e371e2253bc20dde1bbcfbd97eff55`. 227 packages incl. admin-interface 0.4, rest-api 0.7, invizboxutils, ledcontrol, netwatch2, wifiwatch, usb-automount, configuration-update-mt7621, wireguard-procd, tor-basic 0.4.9.13, lighttpd 1.4.85, openvpn 2.6.23, Python 3.11.18 + bottle2 0.12.25/bottle-jwt/apispec/PyJWT/ua-parser. **Built only, never flashed, never run.**

Feed fixes needed to get here (all in `patches/feed/`): src-link-safe python include paths; python path from python3-version.mk (24.10 is Python **3.11**, not 3.12); bottle2 0.12.19 -> 0.12.25 (`inspect.getargspec` removed in 3.11); PyJWT `PYTHON3_PKG_WHEEL_NAME:=pyjwt`; rest-api must not include python3-package.mk (it hooks a wheel build in); mtk-eip93 deleted (upstream driver); rest-api drops strongswan-eap-mschapv2/iptables deps.

Build-process gotchas: `make defconfig` can silently drop package selections after a failed Kconfig pass, so always grep `.config` for the selections; verify success from the manifest, not the exit code.

**Not done, and this image would misbehave without it:**
1. Build identity. The 4.4.1 config set `CONFIG_VERSION_PRODUCT="InvizBox Go"`, `VERSION_DIST="InvizBox-OpenWRT"`, `VERSION_MANUFACTURER`, `VERSION_NUMBER=<fw version>` (10 scripts test `DEVICE_PRODUCT = "InvizBox Go"`; the running 24.10 Go says `Generic`). Also `TARGET_PREINIT_DISABLE_FAILSAFE`, `KERNEL_NAMESPACES`/`NET_NS`. Needs a chosen firmware version number (`configuration-update-mt7621` pkg version comes from `VERSION_NUMBER`); `VERSION_REPO` still pointed at the dead onion in 4.4.1.
2. The Go config overlay (`firmware/src/files/go/etc/...`: network, firewall, dhcp, wireless, openvpn, vpn, update, tor torrc, profiles, banner) is not baked into the image.
3. `firewall.user` (iptables) -> nftables/fw4, `eth0.3` -> dummy device, captive-portal scripts (`netwatch2/bin/set_captive.ash`).
4. Nothing from the REST API or UI has run on Python 3.11 yet.

## Run 6 (2026-11-15): identity 5.0.0 + `scan` mode

Image: `<artifacts>/InvizBox-OpenWRT-5.0.0-dev-run6-sysupgrade.bin`, sha256 `3fc27b4b37446961c2fe7f5d0b65354f8bd8966260b1caa551f25ba0fc8b1722`, 227 packages. **Built only; never flashed or run.** Verified in the build tree: `DEVICE_PRODUCT='InvizBox Go'`, `DISTRIB_RELEASE='5.0.0'`, `configuration-update-mt7621-5.0.0-r1`, `scan)` mode in `/lib/netifd/wireless/mac80211.sh`, `15_defaultpassword` matches the product string. Minimal config: `invizbox-go-24.10.config`; target patches: `patches/000*.patch` (Go DTS/stanza/first-boot script, `scan` mode); feed patches: `patches/feed/`.

Gotchas: (1) `CONFIG_VERSION_*` only persist if `CONFIG_DEVEL`, `CONFIG_IMAGEOPT` and `CONFIG_VERSIONOPT` are all set; `make defconfig` drops them silently otherwise. (2) Setting `VERSION_DIST` changes output filenames to `invizbox-openwrt-r0-<rev>-ramips-...`, so older `openwrt-ramips-...` files in `bin/targets` are stale; always take the newest by timestamp. (3) `scan` mode: ported by creating the interface with `iw phy ... interface add ... type managed` in `mac80211_prepare_vif`; the original used a helper 24.10 no longer has. Untested on hardware.

Fork inventory (invizbox/openwrt over upstream 21.02.3, Go-relevant only): scan mode (ported), dnsmasq.init per-instance restart + `vpn*` interface trigger and a "suppress failed to bind tunX" patch (NOT ported), firewall.init tweaks for fw3 (obsolete with fw4), mt7621.dtsi eip93 node (upstream now), GD25Q512 flash id (not needed, 6.6 detects it), common.sh exit code (cosmetic).

## Run 8 (2026-11-15): first image judged safe to flash

`<artifacts>/InvizBox-OpenWRT-5.0.0-dev-run8-gated-sysupgrade.bin`, sha256 `2c5f2e78e9b84e3467bba3d75050e5715c2a3d7b6de132850ac2a88837645e30`. Passed `verify-image.sh` 19/19 and `sysupgrade -T` on the Go. Flash with `sysupgrade -n` (fresh config; keeping run-3 settings would shadow the overlay).

What made it safe (each found by the gate or by reading the scripts, not on hardware):
- Go config overlay ported to 24.10 (`files-go-24.10/`, installed as `openwrt-24.10/files/`): `update` stamped `5.0.0` (without it the 4.0->4.1 migrations replay onto a fresh config); wireless `band '2g'`, scan iface pinned `wlan0`, APs `psk2+aes`; LED sysfs `green:wifi`/`red:wifi`; dropbear key-only on lan_vpn1 + `authorized_keys` baked in; crontab jobs for absent scripts dropped.
- `eth0.3` -> empty bridge `br-tor` (172.31.1.1) for Tor's TransPort/DNSPort.
- `firewall.user` (iptables) -> native fw4: zones, `lan_vpn1->tunnels` and `lan_clear1->wan` forwardings, masq on wan+tunnels, DNS DNATs, Tor-TransPort redirect, router .onion DNAT via `/etc/invizbox/tor-output.nft`. Gate caught: redirect without ports rendered an invalid nft rule (would have left the box with no firewall); `disable_ipv6` unsupported in fw4.
- Feed: `python3-uuid` (REST API died at import), `lighttpd-mod-openssl` via config not DEPENDS (DEPENDS made a Kconfig loop that silently dropped admin-interface), new `inviz-cert` init (the TLS cert was generated by a patched lighttpd init in the InvizBox packages fork).
- `15_defaultpassword` tries to write the provider id into the factory partition (`mtd unlock /dev/mtd2`). The 24.10 DTS marks factory `read-only`, so it refuses; keep it that way (calibration + MAC live there).
- `03_invizbox_wireless` now exits when the image ships its own wireless config.

Not ported (does not affect access): connmark inter-network forwarding; `netwatch2` captive-portal scripts (iptables, so captive mode is broken); dnsmasq per-instance restart/VPN trigger; `new_device.lua` under 24.10's jailed dnsmasq is untested.

`verify-image.sh` notes: rootless binfmt_misc instance in a podman container (needs kernel >= 6.7), real chroot; proot does not work (no statx translation). `mtd` and `sync` are stubbed inside the copy. Factory dump `<artifacts>/go-factory-mtd2.bin` contains VPN credentials; keep 600.

## Run 8 on hardware (2026-11-15 13:47): FAILED, Wi-Fi never came up; recovered via USB

`sysupgrade -n` of run 8 succeeded but the Go stopped transmitting entirely (MAC absent from scans, any SSID). An `InvizBoxGo` beacon may have appeared ~2 min after the flash (13:49-13:51) but joins failed and it was gone after. Cause not yet known; the emulated gate cannot exercise real Wi-Fi. Prime suspect: the hand-ported `scan` wireless mode (`wlan0`), which no test exercised; others: wifiwatch/netwatch2 reconfiguring the radio after first boot.

Recovered with the USB path (U-Boot `root_uImage`, run 3 image) at ~14:03; worked first try. Stick prep without root: udisks over D-Bus (`Block.Format dos`, `CreatePartitionAndFormat` 0x0c, then `Block.Format vfat` on sdb1; use `gdbus --timeout 600`; do NOT pass `erase: zero`, it zeroes the whole device). Stick `/dev/sdb` (29.4G Flash Disk) now holds `root_uImage` = run 3 (sha256 `c40f3fe6…`), labelled INVIZREC; keep it as the standing rollback stick.

After recovery: run 3, real MAC, key-only SSH (host key in `ssh/known_hosts_recovered`).

Lesson: the gate needs a Wi-Fi stage. Before the next full flash, test the wireless config on the live run-3 device first with a self-reverting experiment (apply config, `wifi`, auto-restore after N seconds).

## Root cause of runs 8/9 losing Wi-Fi (found 2026-11-15 from on-device boot logs)

Debug image run 9 = run 8 + `debug-bootlog/` (snapshots dmesg/state to the recovery stick every 10 s when a stick with `root_uImage` is present). Logs: `<artifacts>/bootlogs-run9-2026-11-15/`.

Boot 1 timeline (uptime): 63.7 s AP `phy0-ap0` joins `br-lan_vpn1`; t=30 snapshot shows BOTH `phy0-ap0` (AP) and `wlan0` (managed, created by the ported `scan` mode) with netifd `pending`; 69 s AP torn down; from t=40 on only `wlan0` exists and netifd reports `up:true` with no AP, forever. The Go then rebooted once after ~7 min (cause not captured). Memory steady (~135 MB free).

Cause: the hand-ported `scan` mode created `wlan0` with `iw phy ... interface add` outside hostapd; on 24.10 hostapd owns interface creation on the phy and the two race during the first radio setup. Single radio (MT7603): AP + client must share it. Experiment A (live, reload path) missed it because there the race went the other way (wlan0 lost).

Fix (run 10): scan port reverted; `mac80211.sh` is byte-identical to stock 24.10, a `scan` wifi-iface is ignored. Live experiment C (run 3 + run 8 wireless/network, stock script, full `wifi down` + network restart): AP up on ch 11 for 60 s, no managed iface, netifd settled.

Consequence: REST API network scanning (`iwinfo wlan0 scan`) does not work until a 24.10-native design exists. Scanning from the AP interface (`iwinfo phy0-ap0 scan`) returned nothing, then hung and knocked the client off. Candidate: travelmate's approach.

Also seen: `logread` failed for the whole boot ("Failed to find log object") although `logd` was running; investigate.

Recovery count today: 2 (both via USB `root_uImage`, both first try). Note: udisks `power-off` on eject left the build host's front port unable to enumerate the stick later (descriptor read -110); eject with `unmount` only.

## Run 10 on hardware (flashed 2026-11-15 14:54, `sysupgrade -n`): WORKS

`<artifacts>/InvizBox-OpenWRT-5.0.0-dev-run10-sysupgrade.bin`, sha256 `09bbc47bb5268f364afd631558c4b83fcc62d9a3177a49f1063a49ba282bc99e`. InvizBox-OpenWRT 5.0.0 on OpenWrt 24.10 / kernel 6.6. Still contains the debug boot logger (only acts with the recovery stick inserted).

Verified on the device: AP `InvizBoxGo` ch 11 WPA2 with the factory PSK, real MAC, DHCP from the `vpn1` dnsmasq instance, key-only SSH (host key `ssh/known_hosts_run10`), all uci-defaults completed, logd works; running: lighttpd, rest-api, tor, dnsmasq x3, wifiwatch, dropbear; fw4 loaded with every ported rule (masq wan/tunnels, Tor-TransPort, dns_vpn1/tor/clear1, router .onion DNAT); from a client: web UI 200, `/api/ping` 204 over HTTP and HTTPS, `POST /api/auth/token` with root + factory PSK returns a JWT.

LED: rapid green while booting, steady green, then off when first boot completes (InvizBox LED config).

Known gaps on run 10:
- `netwatch2` crash-loops: `require("update")` (package `update` not selected, same as 4.4.1) and its captive check fetches the dead `https://update.invizbox.com/captive`. Needs a redesign around the operator's own update server (captive detection, VPN list refresh, connectivity LEDs).
- No nearby-network scan for the UI (scan mode removed; needs a 24.10-native design).
- Connmark inter-network forwarding, captive-portal iptables scripts, dnsmasq per-instance restart: not ported.
- Debug boot logger should be removed for a release build (`files/etc/init.d/bootlog-usb`, `files/etc/rc.d/S12bootlog-usb`, `files/usr/sbin/bootlog-usb.sh`).

## Upstream Wi-Fi (STA) on 24.10/25.12 — measured 2026-11-15

One radio (MT7603): AP and client share `phy0` and must share a channel. Self-restoring experiments on run 10:
- Exp D: hostapd moves the AP via `ubus call hostapd apsta_state` both by CSA (`AP-CSA-FINISHED freq=2437`) and by restart; clients follow seamlessly.
- Exp E (wifiwatch paused, `wan` = `sta` to the upstream, psk-mixed): client associated in 9 s, DHCP lease from upstream, AP followed to channel 6 automatically; one `DISASSOC_LOW_ACK` ~30 s after connect, wpa_supplicant reconnected in 5 s, stable for 60+ s after.
- 24.10/25.12 AP+STA behaviour (`wpa_supplicant.uc` -> `hostapd.uc apsta_state`): AP follows the client's frequency; **while the client is disconnected/scanning, hostapd stops the AP**. If the saved upstream is unreachable the hotspot stays dark.
- The REST API accepts only `none|wep|psk-mixed` for upstream encryption (`internet.py validate_internet`).

What failed in the first (API-driven) attempt was **wifiwatch**: it saw the 5 s gap without a default route and switched `wan` back to `scan`; its reconnect logic depends on `iwinfo wlan0 scan`, which no longer exists, so it never reconnected.

**wifiwatch rewrite — done 2026-11-16** (feed commit `wifiwatch: work with OpenWrt 24.10+ AP+STA`): 60 s grace on a lost uplink, then back to `scan` so the AP returns; known networks found through a short-lived `scan0` interface (experiment G) instead of `wlan0`; rescan every 120 s; failed networks retried after 10 min. Proven on hardware: the first connect (found the upstream, joined, AP followed to its channel, default route up). **Not yet exercised:** the grace period on a real drop, the fallback when the upstream disappears, and reconnecting after it returns.

Other bugs found in the logs: `new_device.lua` fails under 24.10/25.12 dnsmasq (`dhcp-script.sh` runs it with the shell: `syntax error: unexpected "("`); OpenVPN restarts every 5 s on the placeholder config (should ship `enabled '0'`); the overlay `system` config lacked `compat_version '1.1'` (fixed in the overlay; makes keep-settings upgrades between our images possible).

## Rebase to OpenWrt 25.12 (2026-11-15)

Correction: 24.10 is NOT the current stable; **25.12 is** (tags up to v25.12.6). The earlier "24.10 = current stable" claim was wrong. 24.10 ships OpenSSL 3.0.22 (end of life Oct 2026); 25.12 ships OpenSSL **3.5.9 (LTS)**.

Tree: `$WORKDIR/openwrt-25.12` branch `invizbox-go` = upstream `60c494a` + the two Go commits (`ramips: mt7621: add InvizBox Go`, `skip first-boot wifi script...`); no scan-mode commit. Same `files/` overlay, same feed via `src-link`.

25.12 changes that needed porting (feed commit "OpenWrt 25.12 (Python 3.13)..."): Python **3.13** removed `cgi` and 25.12 has no `python3-cgi` -> bottle 0.13.4 (no cgi, keeps a getargspec shim); `python3-flup` dropped from the 25.12 packages feed -> packaged flup 1.0.3 in our feed (the REST API uses the threaded `flup.server.fcgi`, which doesn't touch cgi). Missing deps made Kconfig drop every InvizBox package until fixed. The feed index cache (`feeds/invizbox.tmp`) went stale after adding a package; move it aside and `feeds update -i invizbox`. Package manager is apk (`CONFIG_USE_APK=y`); TLS lib package name is `libopenssl3`.

Image `<artifacts>/InvizBox-OpenWRT-5.0.0-dev-os2512-run1-sysupgrade.bin`, sha256 `15affa28039b513c7d5094d4b43140a0c8cb5e4264ff645c8a142fd690fff352`, 20.2 MB: kernel 6.12.116, OpenSSL 3.5.9, mbedTLS 3.6.7, Python 3.13.18, BusyBox 1.37.0, dropbear 2025.89, dnsmasq 2.93, hostapd 2025.08.26, lighttpd 1.4.85, Tor 0.4.9.13, OpenVPN 2.7.8, bottle 0.13.4, flup 1.0.3. Gate: 19/19. Flashed on the Go 2026-11-15 16:22 (`sysupgrade -n`; `-T` without `-n` fails on config compat 1.0->1.1, see above).

## CVE comparison (NVD, exact-version CPE match, 2026-11-15)

Method: `cve-count.py` queries NVD API 2.0 `virtualMatchString` per unique CPE in the image's CycloneDX SBOM (`CONFIG_JSON_CYCLONEDX_SBOM=y`), paginated, cached in `$WORKDIR/cve/out/nvd-cache.json`. 4.4.1 (21.02 has no SBOM) was reconstructed from its manifest + each package's `PKG_CPE_ID`. cve-bin-tool 3.4 was tried and abandoned (GitLab advisory YAML parse crash, OSV/EPSS fetch failures, missing `purl2cpe` table).

| | 4.4.1 (21.02) | run 10 (24.10) | 25.12 run 1 |
|---|---|---|---|
| Total | 5,995 | 858 | **389** |
| Critical / High / Medium / Low | 206 / 2,489 / 3,234 / 66 | 39 / 349 / 458 / 12 | **20 / 144 / 219 / 6** |
| Linux kernel | 5,658 (5.4.188) | 822 (6.6.159) | **370 (6.12.116)** |
| Non-kernel | 337 (218 of them vim 8.2) | 36 | **19** |

Caveats: the kernel CNA issues CVEs for most stable fixes, many in drivers not built for MT7621; version-range matching ignores OpenWrt backports; hostapd (git-snapshot version) cannot be matched; 21.02 tagged fewer packages with CPEs (4.4.1 is understated); vim and strongSwan are not in the new images. Per-CVE list for 25.12: `invizbox-go-5.0.0-remaining-cves.md`.

### 25.12 run 1 on hardware (flashed 16:22, stable at 16:30) — WORKS

Verified on the device: kernel 6.12.116, OpenSSL 3.5.9; AP `InvizBoxGo` ch 11 on the real MAC; lighttpd, rest-api, tor, dnsmasq x3, wifiwatch, dropbear running; all 10 ported fw4 rules loaded; uci-defaults all completed; logd ok; from a client: web UI 200, `/api/ping` 204 over HTTPS (TLS 1.3), login returns a JWT. Host key: `<artifacts>/ssh/known_hosts_os2512`. Same gaps as run 10 (netwatch2, UI network scan, wifiwatch rewrite, OpenVPN placeholder, new_device.lua). Still has the debug boot logger.

## Scanning without a permanent `wlan0` (experiments F/G, 25.12, 2026-11-15)

- **F:** `iw phy phy0 interface add scan0 type managed` (inheriting the AP's MAC) -> `ip link set up` fails (`RTNETLINK answers: No error information`), 0 results. The AP was unaffected.
- **G:** same, but with its own locally-administered MAC (`02:` + AP MAC tail) -> **works**: 31 and 35 networks found in 10–11 s per round, the AP stayed on channel 11 and the connected client stayed associated throughout; iface deleted after each scan.
- So the run 8/9 failure came from a *persistent* `wlan0` created during hostapd setup, not from scanning itself. A transient scan iface, created while hostapd is idle and deleted right after, is safe. This unblocks both the wifiwatch rewrite (find known networks before switching the client on, without darkening the AP) and the UI network list.

## Battery / power (checked 2026-11-15)

The Go's battery is **not visible to software**, on stock or on our firmware:
- No `/sys/class/power_supply`, hwmon, IIO or ADC devices; nothing battery-related in dmesg.
- No I2C bus: both the vendor DTS (4.2.3/4.4.1) and ours mux the SoC's `i2c` pin group to GPIO, so any fuel-gauge or charger IC on those pins is not reachable as I2C. `kmod-rtc-pcf8563` is installed but no RTC registers (no I2C node) — dead weight in `DEVICE_PACKAGES`.
- Claimed GPIOs are only the two Wi-Fi LEDs (3, 4) and reset (18).
- The vendor admin UI's only battery reference is help text telling the user to look at the **battery indicator LEDs** on the case — charge state is handled entirely by the charger hardware.
- Not ruled out: a charger "charging/full" status line on an unclaimed GPIO. Finding it needs a sweep reading all unclaimed GPIO inputs while the charger is plugged in vs unplugged (operator action). Even then it would give charging/not-charging, not capacity or health; cell health can only be judged by runtime or by measuring the cell.

## Run 2 (25.12) and Tor Wi-Fi — 2026-11-16

**Run 2 image** (built, gated 19/19, not flashed): pcre2 10.48 and zlib 1.3.2 (refreshed ARM patch 004, dropped obsolete 005, `.pc` path moved to `lib/pkgconfig`), `compat_version '1.1'` in the overlay. CVE count with the corrected matcher: **381** (run 1: 389; 24.10: 858; 4.4.1: 5,995). Userspace is down to 11 matches, none real-and-fixable: BusyBox ×2 (no fixed release), Lua 5.1 ×2, util-linux ×1, mbedTLS ×1 (LLVM-only), Python/OpenSSL/Tor ×5 (NVD mis-attributions). `cve-count.py` now re-checks each match against NVD's own version ranges: NVD's `virtualMatchString` treats the CPE update field as a wildcard, so a final release (pcre2 10.48) also matched entries for its release candidates (`10.48:rc1`).

**Upstream Wi-Fi (live on the Go, in the feed):** wifiwatch scans through a short-lived `scan0` interface with a locally administered MAC (the AP keeps running), waits 60 s before acting on a lost uplink, rescans every 120 s when there is no uplink, and retries failed networks after 10 minutes. Note `sysupgrade -n` wipes `known_networks`; re-add the upstream after flashing.

**Fixes found while enabling Tor Wi-Fi:**
- lighttpd stops for good when the first NTP sync jumps the clock (the Go has no working RTC); `etc/lighttpd/conf.d/05-no-clock-jump-restart.conf` disables that restart.
- bottle 0.13 refuses to re-assign attributes on Bottle app objects; the REST API does this for runtime state, so every network, firmware or reboot change returned HTTP 500. Fixed with a patch in `python3-bottle2`.
- Tor transparent proxy: Tor now also listens on `10.153.147.1:9040` and the `tor_transparent` redirect targets it, instead of `172.31.1.1` on the carrier-less `br-tor` bridge.

**Tor Wi-Fi enabled through the API** (`PUT /api/networks/lan_tor`): SSID `InvizBoxGo-Tor` (same key as `InvizBoxGo`), 10.153.147.0/24, DNS via Tor's DNSPort, all TCP via Tor's TransPort. Confirmed from a phone client (Tor shows the client's streams). Management (SSH, key-only) stays on `InvizBoxGo` / `lan_vpn1`, which reaches the internet only through the WireGuard VPN (see below).

## Open items (as of 2026-11-16)

1. **wifiwatch: test the unexercised paths.** Take the upstream away (or move out of range), confirm the AP comes back within ~60–90 s, and the Go rejoins when the upstream returns. Watch for clients dropping during each 120 s scan.
2. **UI network scan.** `rest-api/src/system/internet.py` still runs `iwinfo wlan0 scan`, which only works while the Go is connected upstream. Point it at the `scan0` helper (same approach as wifiwatch).
3. **netwatch2** crash-loops (`require("update")` missing; captive check uses the dead `update.invizbox.com`). Needs a redesign around a self-hosted update server.
4. ~~OpenVPN placeholder restarts every 5 s~~ — done 2026-11-16: `vpn_1` ships `enabled '0'` and the init script is disabled on the Go. The `openvpn-openssl` package stays installed because `invizboxutils` depends on it. The operator doesn't use OpenVPN; a future Mullvad setup would use WireGuard (Mullvad has been retiring OpenVPN).
5. **`new_device.lua`** fails under 24.10+ dnsmasq (`dhcp-script.sh` runs it with the shell).
6. **Debug boot logger** still in the overlay used for builds; remove for release.
7. **Run 2 image** (pcre2/zlib bumps, `compat_version`) is built and gated but not flashed; the Go runs run 1 plus live fixes (wifiwatch, bottle patch, lighttpd clock-jump, Tor TransPort). A run 3 build should carry all of these.
8. Not ported: connmark inter-network forwarding, captive-portal scripts, per-instance dnsmasq restart.

## WireGuard / Mullvad on the VPN network — 2026-11-16

`wireguard-procd` (InvizBox's procd-managed WireGuard, device `tun1`, routing table 1 for `lan_vpn1`) now accepts provider configs in wg-quick format as downloaded: it strips the keys `wg setconf` rejects, takes the address from `Address=`, applies `MTU=` (default 1420), points the `vpn1` dnsmasq instance at the config's `DNS=` through the tunnel, and installs the table route as `dev tun1` (the original `via <own address>` route was rejected by the kernel). Feed commit `wireguard-procd: accept wg-quick provider configs`.

Tested on the Go with a Mullvad WireGuard config (Salt Lake City): handshake; a client on `InvizBoxGo` reports `mullvad_exit_ip: true` at am.i.mullvad.net; DNS answered by Mullvad through the tunnel; with the tunnel stopped, client traffic fails instead of leaking to the uplink (fw4 only forwards `lan_vpn1` → `tunnels`).

Setup (manual; the UI's provider/location flow depended on InvizBox's dead server lists):
1. Generate a WireGuard config in your Mullvad account (Linux format) and copy one `.conf` to `/etc/wireguard/` on the Go, mode 600.
2. `uci set wireguard.vpn_1.filename=/etc/wireguard/<file>.conf; uci set wireguard.vpn_1.enabled=1; uci commit wireguard; /etc/init.d/wireguard restart`
3. Check: `wg show tun1` (recent handshake), then am.i.mullvad.net from a client on `InvizBoxGo`.
To switch servers, point `filename` at another file and restart. `InvizBoxGo-Tor` is unaffected (Tor only).
