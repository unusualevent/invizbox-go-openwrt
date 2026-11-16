# InvizBox-OpenWRT 5.0.0 (OpenWrt 25.12) — remaining CVEs

*Generated 2026-11-15 from the image's CycloneDX SBOM; NVD API 2.0, exact-version CPE match (`virtualMatchString`).*

## How to read this

- A listed CVE means NVD's published configuration says this exact component version is affected. It does **not** account for fixes OpenWrt backports into its packages, and it does not check whether the vulnerable code is even built for this device.
- The Linux kernel CNA assigns a CVE to most stable-tree fixes. Many kernel entries below concern drivers or subsystems not compiled into the MT7621 image; triaging them needs the kernel `.config`.
- Components not matched: those without a CPE in the SBOM (OpenWrt's own daemons such as procd, netifd, ubus) and hostapd/wpad, whose git-snapshot version cannot be matched.

## Assessment (manual triage, 2026-11-15)

Image: `InvizBox-OpenWRT-5.0.0-dev-os2512-run1` (OpenWrt 25.12, sha256 `15affa28…0fff352`), running on the Go since 2026-11-15 16:22. Comparison with earlier images is in `invizbox-go-port-drafts/README.md` ("CVE comparison"): 4.4.1 had 5,995 matches, 24.10 run 10 had 858, this image has 389.

### Userspace (19 matches)

| Component | Verdict | Notes / action |
|---|---|---|
| PCRE2 10.47 (6) | **Real** | Fixed in 10.48. Two are 32-bit-only bugs, and the Go is 32-bit MIPS. Pulled in by lighttpd (config regexes, trusted input) — exposure low, but bump to 10.48 when the 25.12 packages feed does (or carry the bump in our feed). |
| BusyBox 1.37.0 (2) | **Real, low** | `wget` CR/LF request splitting (scripts use it against fixed URLs); `tar` hidden filenames in listings. Follow OpenWrt's BusyBox updates. |
| util-linux libblkid 2.41.5 (1) | **Real, low–medium** | Malformed partition tables during probing. Reachable by inserting a crafted USB stick (`usb-automount`/`block-mount` probe sticks). Follow upstream. |
| zlib 1.3.1 (2) | **Mostly not applicable** | One is in `contrib/untgz` (not shipped); the other is CPU use in `crc32_combine64` (needs attacker-controlled lengths). Fixed in 1.3.2. |
| Lua 5.1.5 (2) | **Low** | DoS via crafted Lua script; the Go only runs its own trusted scripts. Lua 5.1 is what OpenWrt ships; no upstream fix for 5.1. |
| Mbed TLS 3.6.7 (1) | **Not applicable** | Timing side channel only with LLVM's select-optimize; OpenWrt builds with GCC. |
| Python 3.13.18 (3) | **2 false positives, 1 n/a** | CVE-2020-29396 (Odoo) and CVE-2021-32052 (Django) list Python only as a platform. CVE-2026-3087 (`shutil.unpack_archive` with Windows drive paths) is not used by the REST API. |
| OpenSSL 3.5.9 (1) | **False positive** | CVE-2019-0190 is an Apache `mod_ssl` bug that NVD ties to an OpenSSL version range. |
| Tor 0.4.9.13 (1) | **False positive** | CVE-2017-16541 is a Tor Browser (macOS) bug. |

Net: **userspace has 9 genuine, low-impact items** (PCRE2 ×6, BusyBox ×2, libblkid ×1) plus 2 low/odd ones (zlib, Lua); the rest are false positives or don't apply.

### Kernel 6.12.116 (370 matches)

Critical (20) checked against the image's kernel `.config`:
- **Not built (17):** SMB server/ksmbd and SMB client (CVE-2026-31536, -31608, -31609, -43185, -53010, CVE-2025-39933), RDMA rxe (-46325), qla2xxx FC (-43414), mlx5 (-43465), SCTP (-53246, -53224), netfs (-64066, -64067, -64068, -64160, -64216), netconsole (-43197).
- **Built, applies:** CVE-2026-53260 (TCP `reqsk_queue_hash_req` preemption race).
- **Built, effectively unreachable here:** CVE-2026-43198 (IPv6 TCP accept race) and CVE-2026-43083 (IPv6 IOAM6 option parsing, off per interface by default) — the Go's config disables IPv6 via sysctl.

High/Medium/Low kernel entries are listed below by ID only; most are likewise in unbuilt drivers/filesystems. The practical remedy for the kernel is to follow OpenWrt 25.12 point releases (each bumps 6.12.x); a full triage would map each CVE's fix commit to files built for this config.

## Totals

**389 CVEs** — Critical 20, High 144, Medium 219, Low 6.

| Component | Version | Packages | Total | C | H | M | L |
|---|---|---|---|---|---|---|---|
| linux:linux_kernel | 6.12.116 | kernel, kmod-cdrom, kmod-crypto-aead… | 370 | 20 | 141 | 208 | 1 |
| pcre:pcre2 | 10.47 | libpcre2 | 6 | 0 | 1 | 2 | 3 |
| python:python | 3.13.18 | python3-base, python3-codecs, python3-email… | 3 | 0 | 1 | 2 | 0 |
| busybox:busybox | 1.37.0 | busybox | 2 | 0 | 0 | 1 | 1 |
| lua:lua | 5.1.5 | liblua, lua | 2 | 0 | 0 | 2 | 0 |
| zlib:zlib | 1.3.1 | zlib | 2 | 0 | 0 | 1 | 1 |
| arm:mbed_tls | 3.6.7 | libmbedtls | 1 | 0 | 0 | 1 | 0 |
| kernel:util-linux | 2.41.5 | libblkid, libuuid | 1 | 0 | 0 | 1 | 0 |
| openssl:openssl | 3.5.9 | libopenssl, libopenssl-conf, openssl-util | 1 | 0 | 1 | 0 | 0 |
| torproject:tor | 0.4.9.13 | tor-basic | 1 | 0 | 0 | 1 | 0 |

No matched CVEs (27): acl_project:acl 2.3.2, attr_project:attr 2.5.2, dropbear_ssh_project:dropbear_ssh 2025.89, e2fsprogs_project:e2fsprogs 1.47.3, gnu:diffutils 3.10, haxx:libcurl 8.23.0, iproute2_project:iproute2 6.18.0, iputils:iputils 20250605, jansson_project:jansson 2.14.1, json-c:json-c 0.18, kernel:iw 6.17, libcap-ng_project:libcap-ng 0.8.4, libcap_project:libcap 2.69, libnl_project:libnl 3.12.0, lighttpd:lighttpd 1.4.85, logrotate_project:logrotate 3.22.0, mtd-utils_project:mtd-utils 2.3.0, netfilter:libmnl 1.0.5, netfilter:libnftnl 1.3.1, oberhumer:lzo 2.10, openvpn:openvpn 2.7.8, point-to-point_protocol_project:point-to-point_protocol 2.5.2, popt_project:popt 1.19, pyyaml:pyyaml 6.0.3, pyyaml_project:pyyaml 0.2.5, rng-tools_project:rng-tools 6.17, thekelleys:dnsmasq 2.93.

Not checkable: w1.fi:hostapd (unusable version 2025.08.26~ca266cc2).

## Userspace (non-kernel) CVEs

### pcre:pcre2 10.47

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2026-89161](https://nvd.nist.gov/vuln/detail/CVE-2026-89161) | HIGH | 7.4 | 2026-09-11 | In PCRE2 before 10.48, pcre2_jit_match mishandles a previously copied subject being passed in as a context. An incorrect free operation can occur. |
| [CVE-2026-89158](https://nvd.nist.gov/vuln/detail/CVE-2026-89158) | MEDIUM | 6.5 | 2026-09-11 | PCRE2 before 10.48, on 32-bit platforms, has a pcre2_compile_32 integer overflow and resultant out-of-bounds write. |
| [CVE-2026-89157](https://nvd.nist.gov/vuln/detail/CVE-2026-89157) | MEDIUM | 5.7 | 2026-09-11 | PCRE2 before 10.48, on 32-bit platforms, has a pcre2_pattern_convert out-of-bounds write when an attacker can provide a large pattern. |
| [CVE-2026-89160](https://nvd.nist.gov/vuln/detail/CVE-2026-89160) | LOW | 3.7 | 2026-09-11 | PCRE2 before 10.48 has a pcre2_match out-of-bounds read during the PCRE2_MATCH_INVALID_UTF matching of an invalid UTF subject. |
| [CVE-2026-89156](https://nvd.nist.gov/vuln/detail/CVE-2026-89156) | LOW | 2.9 | 2026-09-11 | PCRE2 before 10.48 has a pcre2_match out-of-bounds read after a JIT fallback when an attacker can provide invalid UTF data. |
| [CVE-2026-89162](https://nvd.nist.gov/vuln/detail/CVE-2026-89162) | LOW | 2.9 | 2026-09-11 | In PCRE2 before 10.48, pcre2_serialize_encode might disclose two bytes to an adversary, typically in a situation where the access available to the adversary is already unsafe. |

### python:python 3.13.18

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2020-29396](https://nvd.nist.gov/vuln/detail/CVE-2020-29396) | HIGH | 8.8 | 2020-12-22 | A sandboxing issue in Odoo Community 11.0 through 13.0 and Odoo Enterprise 11.0 through 13.0, when running with Python 3.6 or later, allows remote authenticated users to execute arbitrary code, leading to privilege escalation. |
| [CVE-2021-32052](https://nvd.nist.gov/vuln/detail/CVE-2021-32052) | MEDIUM | 6.1 | 2021-05-06 | In Django 2.2 before 2.2.22, 3.1 before 3.1.10, and 3.2 before 3.2.2 (with Python 3.9.5+), URLValidator does not prohibit newlines and tabs (unless the URLField form field is used). If an application uses values with newlines in an HTTP response, header… |
| [CVE-2026-3087](https://nvd.nist.gov/vuln/detail/CVE-2026-3087) | MEDIUM | 6.0 | 2026-04-27 | If `shutil.unpack_archive()` is given a ZIP archive with an absolute Windows path containing a drive (`C:\\...`) then the archive will be extracted outside the target directory which is different than other operating systems. Only Windows is affected by this… |

### busybox:busybox 1.37.0

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2025-60876](https://nvd.nist.gov/vuln/detail/CVE-2025-60876) | MEDIUM | 6.5 | 2025-11-10 | BusyBox wget thru 1.3.7 accepted raw CR (0x0D)/LF (0x0A) and other C0 control bytes in the HTTP request-target (path/query), allowing the request line to be split and attacker-controlled headers to be injected. To preserve the HTTP/1.1 request-line shape… |
| [CVE-2025-46394](https://nvd.nist.gov/vuln/detail/CVE-2025-46394) | LOW | 3.2 | 2025-04-23 | In tar in BusyBox through 1.37.0, a TAR archive can have filenames hidden from a listing through the use of terminal escape sequences. |

### lua:lua 5.1.5

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2021-43519](https://nvd.nist.gov/vuln/detail/CVE-2021-43519) | MEDIUM | 5.5 | 2021-11-09 | Stack overflow in lua_resume of ldo.c in Lua Interpreter 5.1.0~5.4.4 allows attackers to perform a Denial of Service via a crafted script file. |
| [CVE-2014-5461](https://nvd.nist.gov/vuln/detail/CVE-2014-5461) | MEDIUM | 5.0 | 2014-09-04 | Buffer overflow in the vararg functions in ldo.c in Lua 5.1 through 5.2.x before 5.2.3 allows context-dependent attackers to cause a denial of service (crash) via a small number of arguments to a function with a large number of fixed arguments. |

### zlib:zlib 1.3.1

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2026-22184](https://nvd.nist.gov/vuln/detail/CVE-2026-22184) | MEDIUM | 4.6 | 2026-01-07 | zlib versions up to and including 1.3.1.2 include a global buffer overflow in the untgz utility located under contrib/untgz. The vulnerability is limited to the standalone demonstration utility and does not affect the core zlib compression library. The flaw… |
| [CVE-2026-27171](https://nvd.nist.gov/vuln/detail/CVE-2026-27171) | LOW | 2.9 | 2026-02-18 | zlib before 1.3.2 allows CPU consumption via crc32_combine64 and crc32_combine_gen64 because x2nmodp can do right shifts within a loop that has no termination condition. |

### arm:mbed_tls 3.6.7

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2025-66442](https://nvd.nist.gov/vuln/detail/CVE-2025-66442) | MEDIUM | 5.1 | 2026-04-01 | In Mbed TLS through 4.0.0, there is a compiler-induced timing side channel (in RSA and CBC/ECB decryption) that only occurs with LLVM's select-optimize feature. TF-PSA-Crypto through 1.0.0 is also affected. |

### kernel:util-linux 2.41.5

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2026-13595](https://nvd.nist.gov/vuln/detail/CVE-2026-13595) | MEDIUM | 6.8 | 2026-06-29 | A flaw was found in the libblkid library of util-linux. During nested partition probing, the BSD, Minix, Solaris x86, and UnixWare partition probers cache a raw pointer to a parent partition entry in a dynamically allocated array. When subsequent partition… |

### openssl:openssl 3.5.9

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2019-0190](https://nvd.nist.gov/vuln/detail/CVE-2019-0190) | HIGH | 7.5 | 2019-01-30 | A bug exists in the way mod_ssl handled client renegotiations. A remote attacker could send a carefully crafted request that would cause mod_ssl to enter a loop leading to a denial of service. This bug can be only triggered with Apache HTTP Server version… |

### torproject:tor 0.4.9.13

| CVE | Severity | Score | Published | Summary |
|---|---|---|---|---|
| [CVE-2017-16541](https://nvd.nist.gov/vuln/detail/CVE-2017-16541) | MEDIUM | 6.5 | 2017-11-04 | Tor Browser before 7.0.9 on macOS and Linux allows remote attackers to bypass the intended anonymity feature and discover a client IP address via vectors involving a crafted web site that leverages file:// mishandling in Firefox, aka TorMoil. NOTE: Tails is… |

## Linux kernel 6.12.116 (370)

### Critical (20)

| CVE | Score | Published | Summary |
|---|---|---|---|
| [CVE-2026-31536](https://nvd.nist.gov/vuln/detail/CVE-2026-31536) | 9.8 | 2026-04-24 | In the Linux kernel, the following vulnerability has been resolved: smb: server: let send_done handle a completion without IB_SEND_SIGNALED With smbdirect_send_batch processing we likely have requests without IB_SEND_SIGNALED, which will be destroyed in the… |
| [CVE-2026-31608](https://nvd.nist.gov/vuln/detail/CVE-2026-31608) | 9.8 | 2026-04-24 | In the Linux kernel, the following vulnerability has been resolved: smb: server: avoid double-free in smb_direct_free_sendmsg after smb_direct_flush_send_list() smb_direct_flush_send_list() already calls smb_direct_free_sendmsg(), so we should not call it… |
| [CVE-2026-31609](https://nvd.nist.gov/vuln/detail/CVE-2026-31609) | 9.8 | 2026-04-24 | In the Linux kernel, the following vulnerability has been resolved: smb: client: avoid double-free in smbd_free_send_io() after smbd_send_batch_flush() smbd_send_batch_flush() already calls smbd_free_send_io(), so we should not call it again after… |
| [CVE-2026-43185](https://nvd.nist.gov/vuln/detail/CVE-2026-43185) | 9.8 | 2026-05-06 | In the Linux kernel, the following vulnerability has been resolved: ksmbd: fix signededness bug in smb_direct_prepare_negotiation() smb_direct_prepare_negotiation() casts an unsigned __u32 value from sp->max_recv_size and req->preferred_send_size to a signed… |
| [CVE-2026-43198](https://nvd.nist.gov/vuln/detail/CVE-2026-43198) | 9.8 | 2026-05-06 | In the Linux kernel, the following vulnerability has been resolved: tcp: fix potential race in tcp_v6_syn_recv_sock() Code in tcp_v6_syn_recv_sock() after the call to tcp_v4_syn_recv_sock() is done too late. After tcp_v4_syn_recv_sock(), the child socket is… |
| [CVE-2026-43414](https://nvd.nist.gov/vuln/detail/CVE-2026-43414) | 9.8 | 2026-05-08 | In the Linux kernel, the following vulnerability has been resolved: scsi: qla2xxx: Completely fix fcport double free In qla24xx_els_dcmd_iocb() sp->free is set to qla2x00_els_dcmd_sp_free(). When an error happens, this function is called by… |
| [CVE-2026-43465](https://nvd.nist.gov/vuln/detail/CVE-2026-43465) | 9.8 | 2026-05-08 | In the Linux kernel, the following vulnerability has been resolved: net/mlx5e: RX, Fix XDP multi-buf frag counting for striding RQ XDP multi-buf programs can modify the layout of the XDP buffer when the program calls bpf_xdp_pull_data() or… |
| [CVE-2026-46325](https://nvd.nist.gov/vuln/detail/CVE-2026-46325) | 9.8 | 2026-06-09 | In the Linux kernel, the following vulnerability has been resolved: RDMA/rxe: Fix iova-to-va conversion for MR page sizes != PAGE_SIZE The current implementation incorrectly handles memory regions (MRs) with page sizes different from the system PAGE_SIZE.… |
| [CVE-2026-53010](https://nvd.nist.gov/vuln/detail/CVE-2026-53010) | 9.8 | 2026-06-24 | In the Linux kernel, the following vulnerability has been resolved: ksmbd: fix use-after-free in smb2_open during durable reconnect In smb2_open, the call to ksmbd_put_durable_fd(fp) drops the reference to the durable file descriptor early during the durable… |
| [CVE-2026-53246](https://nvd.nist.gov/vuln/detail/CVE-2026-53246) | 9.8 | 2026-06-25 | In the Linux kernel, the following vulnerability has been resolved: sctp: validate cached peer INIT chunk length in COOKIE_ECHO processing When a listening SCTP server processes a COOKIE_ECHO chunk, the cached peer INIT chunk embedded after the cookie is… |
| [CVE-2026-53260](https://nvd.nist.gov/vuln/detail/CVE-2026-53260) | 9.8 | 2026-06-25 | In the Linux kernel, the following vulnerability has been resolved: tcp: Add preempt_{disable,enable}_nested() in reqsk_queue_hash_req(). syzbot reported a weird reqsk->rsk_refcnt underflow in __inet_csk_reqsk_queue_drop(). The captured reqsk_put() in… |
| [CVE-2026-64066](https://nvd.nist.gov/vuln/detail/CVE-2026-64066) | 9.8 | 2026-07-19 | In the Linux kernel, the following vulnerability has been resolved: netfs: Fix netfs_read_to_pagecache() to pause on subreq failure Fix netfs_read_to_pagecache() so that it pauses the generation of new subrequests if an already-issued subrequest fails. |
| [CVE-2026-64067](https://nvd.nist.gov/vuln/detail/CVE-2026-64067) | 9.8 | 2026-07-19 | In the Linux kernel, the following vulnerability has been resolved: netfs: Fix missing barriers when accessing stream->subrequests locklessly The list of subrequests attached to stream->subrequests is accessed without locks by netfs_collect_read_results()… |
| [CVE-2026-64068](https://nvd.nist.gov/vuln/detail/CVE-2026-64068) | 9.8 | 2026-07-19 | In the Linux kernel, the following vulnerability has been resolved: netfs: Fix missing locking around retry adding new subreqs Fix netfs_retry_read_subrequests() and netfs_retry_write_stream() to take the appropriate lock when adding extra subrequests into… |
| [CVE-2026-64160](https://nvd.nist.gov/vuln/detail/CVE-2026-64160) | 9.8 | 2026-07-19 | In the Linux kernel, the following vulnerability has been resolved: netfs: Fix potential for tearing in ->remote_i_size and ->zero_point Fix potential tearing in using ->remote_i_size and ->zero_point by copying i_size_read() and i_size_write() and using the… |
| [CVE-2026-64216](https://nvd.nist.gov/vuln/detail/CVE-2026-64216) | 9.8 | 2026-07-24 | In the Linux kernel, the following vulnerability has been resolved: netfs: Fix potential UAF in netfs_unlock_abandoned_read_pages() netfs_unlock_abandoned_read_pages(rreq) accesses the index of the folios it is wanting to unlock and compares that to… |
| [CVE-2025-39933](https://nvd.nist.gov/vuln/detail/CVE-2025-39933) | 9.4 | 2025-10-04 | In the Linux kernel, the following vulnerability has been resolved: smb: client: let recv_done verify data_offset, data_length and remaining_data_length This is inspired by the related server fixes. |
| [CVE-2026-43083](https://nvd.nist.gov/vuln/detail/CVE-2026-43083) | 9.1 | 2026-05-06 | In the Linux kernel, the following vulnerability has been resolved: net: ioam6: fix OOB and missing lock When trace->type.bit6 is set: if (trace->type.bit6) { ... queue = skb_get_tx_queue(dev, skb); qdisc = rcu_dereference(queue->qdisc); This code can lead… |
| [CVE-2026-43197](https://nvd.nist.gov/vuln/detail/CVE-2026-43197) | 9.1 | 2026-05-06 | In the Linux kernel, the following vulnerability has been resolved: netconsole: avoid OOB reads, msg is not nul-terminated msg passed to netconsole from the console subsystem is not guaranteed to be nul-terminated. Before recent commit 7eab73b18630… |
| [CVE-2026-53224](https://nvd.nist.gov/vuln/detail/CVE-2026-53224) | 9.1 | 2026-06-25 | In the Linux kernel, the following vulnerability has been resolved: sctp: validate embedded INIT chunk and address list lengths in cookie sctp_unpack_cookie() only checked that the embedded INIT chunk length did not exceed the remaining cookie payload, but… |

### High (141) — id (score)

CVE-2024-57995 (8.8), CVE-2024-58096 (8.8), CVE-2025-39862 (8.8), CVE-2025-71202 (8.8), CVE-2026-23226 (8.8), CVE-2026-31435 (8.8), CVE-2026-31709 (8.8), CVE-2026-31717 (8.8), CVE-2026-43048 (8.8), CVE-2026-43172 (8.8), CVE-2026-46317 (8.8), CVE-2026-53232 (8.8), CVE-2026-53277 (8.8), CVE-2026-53281 (8.8), CVE-2026-63941 (8.8), CVE-2026-64117 (8.8), CVE-2026-64255 (8.8), CVE-2026-98115 (8.8), CVE-2025-22117 (8.7), CVE-2025-22108 (8.6), CVE-2026-64400 (8.6), CVE-2025-22121 (8.4), CVE-2026-53091 (8.4), CVE-2026-64389 (8.2), CVE-2026-31613 (8.1), CVE-2026-31771 (8.1), CVE-2026-53178 (8.1), CVE-2006-2916 (7.8), CVE-2020-27815 (7.8), CVE-2021-20194 (7.8), CVE-2024-52560 (7.8), CVE-2024-58093 (7.8), CVE-2024-58094 (7.8), CVE-2025-21709 (7.8), CVE-2025-21751 (7.8), CVE-2025-21949 (7.8), CVE-2025-22109 (7.8), CVE-2025-37803 (7.8), CVE-2025-37906 (7.8), CVE-2025-38064 (7.8), CVE-2025-38137 (7.8), CVE-2025-38187 (7.8), CVE-2025-38204 (7.8), CVE-2025-38206 (7.8), CVE-2025-38234 (7.8), CVE-2025-38248 (7.8), CVE-2025-38261 (7.8), CVE-2025-38421 (7.8), CVE-2025-38627 (7.8), CVE-2025-38656 (7.8), CVE-2025-39677 (7.8), CVE-2025-39859 (7.8), CVE-2025-39958 (7.8), CVE-2025-71074 (7.8), CVE-2025-71152 (7.8), CVE-2025-71221 (7.8), CVE-2025-71302 (7.8), CVE-2026-100072 (7.8), CVE-2026-23066 (7.8), CVE-2026-23171 (7.8), CVE-2026-23208 (7.8), CVE-2026-23272 (7.8), CVE-2026-23444 (7.8), CVE-2026-31493 (7.8), CVE-2026-31630 (7.8), CVE-2026-31663 (7.8), CVE-2026-31715 (7.8), CVE-2026-43009 (7.8), CVE-2026-43116 (7.8), CVE-2026-43263 (7.8), CVE-2026-43303 (7.8), CVE-2026-43352 (7.8), CVE-2026-43353 (7.8), CVE-2026-43500 (7.8), CVE-2026-45956 (7.8), CVE-2026-46093 (7.8), CVE-2026-46181 (7.8), CVE-2026-46242 (7.8), CVE-2026-46279 (7.8), CVE-2026-46324 (7.8), CVE-2026-46330 (7.8), CVE-2026-52991 (7.8), CVE-2026-53000 (7.8), CVE-2026-53005 (7.8), CVE-2026-53009 (7.8), CVE-2026-53024 (7.8), CVE-2026-53025 (7.8), CVE-2026-53078 (7.8), CVE-2026-53089 (7.8), CVE-2026-53090 (7.8), CVE-2026-53092 (7.8), CVE-2026-53109 (7.8), CVE-2026-53118 (7.8), CVE-2026-53250 (7.8), CVE-2026-53401 (7.8), CVE-2026-63805 (7.8), CVE-2026-63858 (7.8), CVE-2026-64036 (7.8), CVE-2026-64058 (7.8), CVE-2026-64076 (7.8), CVE-2026-64077 (7.8), CVE-2026-64078 (7.8), CVE-2026-64082 (7.8), CVE-2026-64388 (7.8), CVE-2026-98156 (7.8), CVE-2025-71161 (7.5), CVE-2026-43101 (7.5), CVE-2026-43213 (7.5), CVE-2026-43245 (7.5), CVE-2026-43464 (7.5), CVE-2026-45944 (7.5), CVE-2026-52956 (7.5), CVE-2026-52983 (7.5), CVE-2026-53284 (7.5), CVE-2026-64210 (7.5), CVE-2025-39789 (7.3), CVE-2026-45932 (7.3), CVE-2024-58015 (7.1), CVE-2025-22104 (7.1), CVE-2025-22107 (7.1), CVE-2025-38636 (7.1), CVE-2025-71289 (7.1), CVE-2026-23102 (7.1), CVE-2026-23327 (7.1), CVE-2026-31486 (7.1), CVE-2026-31568 (7.1), CVE-2026-43042 (7.1), CVE-2026-46054 (7.1), CVE-2026-46130 (7.1), CVE-2026-46175 (7.1), CVE-2026-46203 (7.1), CVE-2026-52953 (7.1), CVE-2026-52988 (7.1), CVE-2026-53179 (7.1), CVE-2026-53330 (7.1), CVE-2026-53368 (7.1), CVE-2026-98118 (7.1), CVE-2025-23132 (7.0), CVE-2025-38584 (7.0), CVE-2025-39905 (7.0), CVE-2026-64283 (7.0)

### Medium (208) — id (score)

CVE-2022-38096 (6.3), CVE-2019-3016 (6.2), CVE-2019-3887 (5.6), CVE-2021-3564 (5.5), CVE-2024-58074 (5.5), CVE-2024-58095 (5.5), CVE-2024-58097 (5.5), CVE-2025-21752 (5.5), CVE-2025-21807 (5.5), CVE-2025-21833 (5.5), CVE-2025-22111 (5.5), CVE-2025-22116 (5.5), CVE-2025-22127 (5.5), CVE-2025-23129 (5.5), CVE-2025-23131 (5.5), CVE-2025-23135 (5.5), CVE-2025-23137 (5.5), CVE-2025-37743 (5.5), CVE-2025-37746 (5.5), CVE-2025-37860 (5.5), CVE-2025-37880 (5.5), CVE-2025-38029 (5.5), CVE-2025-38036 (5.5), CVE-2025-38041 (5.5), CVE-2025-38042 (5.5), CVE-2025-38132 (5.5), CVE-2025-38140 (5.5), CVE-2025-38199 (5.5), CVE-2025-38203 (5.5), CVE-2025-38205 (5.5), CVE-2025-38207 (5.5), CVE-2025-38237 (5.5), CVE-2025-38284 (5.5), CVE-2025-38311 (5.5), CVE-2025-38359 (5.5), CVE-2025-38426 (5.5), CVE-2025-38591 (5.5), CVE-2025-38597 (5.5), CVE-2025-38605 (5.5), CVE-2025-38621 (5.5), CVE-2025-39745 (5.5), CVE-2025-39762 (5.5), CVE-2025-39764 (5.5), CVE-2025-39775 (5.5), CVE-2025-39822 (5.5), CVE-2025-39830 (5.5), CVE-2025-39833 (5.5), CVE-2025-39834 (5.5), CVE-2025-39910 (5.5), CVE-2025-39925 (5.5), CVE-2025-40005 (5.5), CVE-2025-40325 (5.5), CVE-2025-68351 (5.5), CVE-2025-71117 (5.5), CVE-2025-71141 (5.5), CVE-2025-71227 (5.5), CVE-2025-71285 (5.5), CVE-2025-71313 (5.5), CVE-2025-71315 (5.5), CVE-2026-100074 (5.5), CVE-2026-100076 (5.5), CVE-2026-100077 (5.5), CVE-2026-22981 (5.5), CVE-2026-22985 (5.5), CVE-2026-22993 (5.5), CVE-2026-23007 (5.5), CVE-2026-23017 (5.5), CVE-2026-23070 (5.5), CVE-2026-23104 (5.5), CVE-2026-23137 (5.5), CVE-2026-23138 (5.5), CVE-2026-23152 (5.5), CVE-2026-23157 (5.5), CVE-2026-23217 (5.5), CVE-2026-23247 (5.5), CVE-2026-23259 (5.5), CVE-2026-23265 (5.5), CVE-2026-23346 (5.5), CVE-2026-23371 (5.5), CVE-2026-23377 (5.5), CVE-2026-23385 (5.5), CVE-2026-23472 (5.5), CVE-2026-31420 (5.5), CVE-2026-31499 (5.5), CVE-2026-31526 (5.5), CVE-2026-31537 (5.5), CVE-2026-31560 (5.5), CVE-2026-31562 (5.5), CVE-2026-31579 (5.5), CVE-2026-31591 (5.5), CVE-2026-31592 (5.5), CVE-2026-31692 (5.5), CVE-2026-31732 (5.5), CVE-2026-31777 (5.5), CVE-2026-43010 (5.5), CVE-2026-43022 (5.5), CVE-2026-43034 (5.5), CVE-2026-43109 (5.5), CVE-2026-43115 (5.5), CVE-2026-43118 (5.5), CVE-2026-43127 (5.5), CVE-2026-43131 (5.5), CVE-2026-43191 (5.5), CVE-2026-43204 (5.5), CVE-2026-43216 (5.5), CVE-2026-43219 (5.5), CVE-2026-43220 (5.5), CVE-2026-43234 (5.5), CVE-2026-43272 (5.5), CVE-2026-43294 (5.5), CVE-2026-43298 (5.5), CVE-2026-43299 (5.5), CVE-2026-43301 (5.5), CVE-2026-43308 (5.5), CVE-2026-43309 (5.5), CVE-2026-43310 (5.5), CVE-2026-43311 (5.5), CVE-2026-43325 (5.5), CVE-2026-43326 (5.5), CVE-2026-43331 (5.5), CVE-2026-43337 (5.5), CVE-2026-43344 (5.5), CVE-2026-43346 (5.5), CVE-2026-43355 (5.5), CVE-2026-43416 (5.5), CVE-2026-43443 (5.5), CVE-2026-43463 (5.5), CVE-2026-43485 (5.5), CVE-2026-45897 (5.5), CVE-2026-45901 (5.5), CVE-2026-45934 (5.5), CVE-2026-45940 (5.5), CVE-2026-45961 (5.5), CVE-2026-45963 (5.5), CVE-2026-46014 (5.5), CVE-2026-46032 (5.5), CVE-2026-46044 (5.5), CVE-2026-46059 (5.5), CVE-2026-46066 (5.5), CVE-2026-46071 (5.5), CVE-2026-46092 (5.5), CVE-2026-46096 (5.5), CVE-2026-46147 (5.5), CVE-2026-46148 (5.5), CVE-2026-46153 (5.5), CVE-2026-46171 (5.5), CVE-2026-46228 (5.5), CVE-2026-46245 (5.5), CVE-2026-46252 (5.5), CVE-2026-46256 (5.5), CVE-2026-46302 (5.5), CVE-2026-46314 (5.5), CVE-2026-52937 (5.5), CVE-2026-52944 (5.5), CVE-2026-52994 (5.5), CVE-2026-53017 (5.5), CVE-2026-53018 (5.5), CVE-2026-53027 (5.5), CVE-2026-53102 (5.5), CVE-2026-53103 (5.5), CVE-2026-53104 (5.5), CVE-2026-53106 (5.5), CVE-2026-53107 (5.5), CVE-2026-53113 (5.5), CVE-2026-53167 (5.5), CVE-2026-53226 (5.5), CVE-2026-53258 (5.5), CVE-2026-53285 (5.5), CVE-2026-53292 (5.5), CVE-2026-53297 (5.5), CVE-2026-53313 (5.5), CVE-2026-53321 (5.5), CVE-2026-53365 (5.5), CVE-2026-53377 (5.5), CVE-2026-63998 (5.5), CVE-2026-63999 (5.5), CVE-2026-64006 (5.5), CVE-2026-64060 (5.5), CVE-2026-64079 (5.5), CVE-2026-64146 (5.5), CVE-2026-64154 (5.5), CVE-2026-64159 (5.5), CVE-2026-64190 (5.5), CVE-2026-64212 (5.5), CVE-2026-64213 (5.5), CVE-2026-98049 (5.5), CVE-2026-98053 (5.5), CVE-2026-98062 (5.5), CVE-2026-98119 (5.5), CVE-2026-98125 (5.5), CVE-2026-98131 (5.5), CVE-2026-98134 (5.5), CVE-2026-98161 (5.5), CVE-2026-98162 (5.5), CVE-2025-4598 (4.7), CVE-2026-22986 (4.7), CVE-2026-23207 (4.7), CVE-2026-23210 (4.7), CVE-2026-23348 (4.7), CVE-2026-23394 (4.7), CVE-2026-23469 (4.7), CVE-2026-31456 (4.7), CVE-2026-43053 (4.7), CVE-2026-46017 (4.7), CVE-2026-46272 (4.7), CVE-2026-53108 (4.7), CVE-2026-64038 (4.7), CVE-2019-3819 (4.4)

### Low (1) — id (score)

CVE-2014-3532 (2.1)

