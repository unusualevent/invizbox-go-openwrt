# InvizBox Go on current OpenWrt

Community port of the InvizBox Go travel router (MT7621 + MT7603, SPI-NOR, no
Ethernet) from the vendor's last firmware (InvizBox 4.4.1 on OpenWrt 21.02) to
**OpenWrt 25.12**, keeping the InvizBox web UI and REST API. The vendor is
defunct and its update servers (Tor v2 onion) no longer exist, so stock units
are stuck.

Status (2026-11): "InvizBox-OpenWRT 5.0.0-dev" runs on real hardware: kernel
6.12, OpenSSL 3.5, Python 3.13, fw4/nftables, Tor transparent proxy, admin UI over
HTTP and HTTPS. Upstream Wi-Fi (AP+client on the single radio) works at the
driver level, but the `wifiwatch` supervisor still needs a rewrite. See
`NOTES.md` → "Known gaps".

## Where the pieces live

| Repo | Branch | Contents |
|---|---|---|
| fork of `openwrt/openwrt` | `invizbox-go-25.12` | Board support (DTS, image stanza, first-boot Wi-Fi script), pcre2 10.48 / zlib 1.3.2 bumps |
| fork of `openwrt/openwrt` | `invizbox-go-24.10` | Same board support on 24.10 (superseded) |
| fork of `invizbox/feed` | `invizbox-go` | InvizBox packages ported to 24.10/25.12 (Python 3.13, nftables, TLS) |
| this repo | — | Build config, rootfs overlay, pre-flash gate, CVE tooling, notes |

## Contents

- `invizbox-go-24.10.config`: diffconfig (also used for 25.12; add `CONFIG_JSON_CYCLONEDX_SBOM=y` for an SBOM).
- `files-go-24.10/`: rootfs overlay (copy to `<openwrt>/files/`). It ships **key-only SSH and no authorized keys**, so add `etc/dropbear/authorized_keys` with your own key before building if you want shell access.
- `03_invizbox_wireless`, `mt7621_invizbox_invizboxgo.dts`, `mt7621.mk-invizbox-stanza.diff`: the board support, also committed on the OpenWrt branches.
- `verify-image.sh`: emulated first boot of a built rootfs (rootless podman, binfmt_misc, qemu-mipsel), with 19 checks covering reachability, Wi-Fi config, firewall, web UI and API. Run it before every flash. It needs a dump of your unit's `factory` partition.
- `cve-count.py`, `cve-report.py`: count NVD CVEs for an image from its CycloneDX SBOM. Results for 5.0.0 are in `invizbox-go-5.0.0-remaining-cves.md`.
- `debug-bootlog/`: optional overlay that writes boot logs to a USB stick. It's a debug aid; don't ship it.
- `NOTES.md`: full port log covering what failed and why, hardware findings, the USB recovery procedure, and the CVE comparison against 4.4.1.

## Build (outline)

1. Clone the OpenWrt fork, branch `invizbox-go-25.12`; add the feed fork via `feeds.conf` (`src-git invizbox <url>;invizbox-go`); `./scripts/feeds update -a && ./scripts/feeds install -a`.
2. Copy `invizbox-go-24.10.config` to `.config`, then `make defconfig`. **Grep `.config` afterwards**: defconfig silently drops InvizBox packages if a dependency is missing.
3. Copy `files-go-24.10/` to `files/`, `make -j$(nproc)`.
4. Gate: `EXPECT_PSK=<your unit's wifi key> ./verify-image.sh build_dir/target-mipsel_24kc_musl/root-ramips <factory-dump.bin>`.
5. Flash from the old firmware with `sysupgrade -n` (configs aren't compatible). Recovery: the Go's U-Boot boots `root_uImage` from a FAT32 USB stick when reset is held at power-on; see `NOTES.md`.

## License

The InvizBox repositories this derives from carry no license file; the overlay
is derived from `invizbox/firmware`. No license has been chosen yet for the
original scripts here.
