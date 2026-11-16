#!/bin/bash
# Pre-flash gate for an InvizBox Go 24.10 image. Runs the image's first boot
# under MIPS emulation (rootless: private binfmt_misc instance, Linux >= 6.7)
# and checks the things that decide whether the Go is reachable and usable
# after flashing. Exits non-zero if any hard check fails.
#
#   verify-image.sh <rootfs-dir> <factory-mtd2.bin>
#
# <rootfs-dir>: openwrt-24.10/build_dir/target-mipsel_24kc_musl/root-ramips
# <factory-mtd2.bin>: dump of this unit's factory partition (PSK source)
# Needs the invizbox-emu:trixie image (qemu-user-static, nftables).
set -u
SRC=${1:?rootfs dir}; MTD=${2:?factory dump}
EXPECT_PSK=${EXPECT_PSK:-}
WORKDIR=${WORKDIR:-$HOME/build/invizbox}; mkdir -p "$WORKDIR/emu"
RUN=$(mktemp -d "$WORKDIR/emu/verify-XXXXXX")
cp -a "$SRC" "$RUN/root"
mkdir -p "$RUN/root/tmp" "$RUN/root/proc" "$RUN/root/dev"
for n in null zero urandom random; do : > "$RUN/root/dev/$n"; done
install -m 600 "$MTD" "$RUN/root/dev/mtd2"
# The factory partition is read-only in the DTS, so `mtd unlock` fails on the
# device; mirror that (on a plain file it blocks forever instead).
mv "$RUN/root/sbin/mtd" "$RUN/root/sbin/mtd.real"
printf '#!/bin/sh\necho "verify: mtd %%s refused (read-only factory)" "$*" >&2\nexit 1\n' > "$RUN/root/sbin/mtd"
chmod 755 "$RUN/root/sbin/mtd"
# `sync` under emulation flushes the host's filesystems and can block for a
# very long time; on the device it is instant. Stub it for child processes too.
mv "$RUN/root/bin/sync" "$RUN/root/bin/sync.real" 2>/dev/null; printf '#!/bin/sh\nexit 0\n' > "$RUN/root/bin/sync"; chmod 755 "$RUN/root/bin/sync"

cat > "$RUN/root/verify-in.sh" <<'EOF'
#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
sync() { :; }
mkdir -p /tmp/sysinfo /tmp/.uci /var/lock /var/run /tmp/run /tmp/ud-done /var/log
echo invizbox,invizboxgo > /tmp/sysinfo/board_name
echo "InvizBox Go" > /tmp/sysinfo/model
/bin/board_detect >/tmp/bd.log 2>&1; echo "board_detect rc=$?"
/bin/config_generate >/tmp/cg.log 2>&1; echo "config_generate rc=$?"
cd /etc/uci-defaults
for f in *; do ( . "./$f" ) >"/tmp/ud.$f.log" 2>&1; rc=$?; [ $rc = 0 ] && mv "$f" /tmp/ud-done/; echo "uci-defaults $f rc=$rc"; done
cd /
echo "== inviz-cert"; /etc/init.d/inviz-cert start >/tmp/cert.log 2>&1; echo "inviz-cert rc=$?"; openssl x509 -in /etc/lighttpd/inviz.box.pem -noout -subject 2>&1 | head -1
echo "== lighttpd -tt"; ( . /lib/functions.sh; user_exists http || user_add http ); grep -q "^www-data:" /etc/group || echo "no www-data group"; lighttpd -tt -f /etc/lighttpd/lighttpd.conf >/tmp/lt.log 2>&1; echo "lighttpd-tt rc=$?"; grep -v "macaddress\|unknown: not found" /tmp/lt.log | head -3
echo "== fw4 print"; fw4 print > /tmp/fw4.nft 2>/tmp/fw4.err; echo "fw4-print rc=$?"; grep -v "ubus\|Netlink\|JSON" /tmp/fw4.err | head -5
echo "== rest api"; JWT_SECRET=verify DEVICE_PRODUCT="InvizBox Go" python3 /verify-api.py 2>&1 | tail -8
EOF
cat > "$RUN/root/verify-api.py" <<'EOF'
import os, sys, io, json
import glob; sys.path.insert(0, glob.glob("/usr/lib/python3.*/site-packages/rest_api")[0])
import rest_api
app = rest_api.BOTTLE_APP
print("api-import ok routes=%d" % len(app.routes))
def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else b""
    env = {"REQUEST_METHOD": method, "PATH_INFO": path, "SCRIPT_NAME": "/api", "QUERY_STRING": "",
           "SERVER_NAME": "inviz.box", "SERVER_PORT": "80", "HTTP_HOST": "10.153.146.1", "wsgi.url_scheme": "http",
           "wsgi.input": io.BytesIO(data), "CONTENT_LENGTH": str(len(data)), "CONTENT_TYPE": "application/json",
           "wsgi.errors": sys.stderr, "wsgi.version": (1, 0), "wsgi.multithread": False, "wsgi.multiprocess": False,
           "wsgi.run_once": True, "REMOTE_ADDR": "10.153.146.2"}
    st = {}
    body = b"".join(app(env, lambda s, h, e=None: st.setdefault("s", s)))
    return st.get("s"), body[:120]
for m, p, b in (("GET", "/", None), ("GET", "/ping", None),
                ("POST", "/auth/token", {"username": "root", "password": "wrong"}),
                ("GET", "/system/info/generic", None)):
    s, out = req(m, p, b)
    print("api %s %s -> %s %s" % (m, p, s, out[:70]))
EOF
chmod +x "$RUN/root/verify-in.sh"

podman run --rm --cap-add=SYS_ADMIN --cap-add=NET_ADMIN --security-opt label=disable -v "$RUN":/sim invizbox-emu:trixie bash -c '
mkdir -p /binfmt && mount -t binfmt_misc binfmt_misc /binfmt
echo ":qemu-mipsel:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x08\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xfe\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-mipsel-static:F" > /binfmt/register 2>/dev/null
R=/sim/root; mount -t proc proc $R/proc
for n in null zero urandom random; do mount --bind /dev/$n $R/dev/$n; done
timeout 1200 chroot $R /bin/sh /verify-in.sh || echo "verify-in rc=$? (timeout or failure)"
sed "s#include \"/etc/invizbox/#include \"/sim/root/etc/invizbox/#" $R/tmp/fw4.nft > /sim/fw4-check.nft
[ -s /sim/fw4-check.nft ] && grep -q "table inet fw4" /sim/fw4-check.nft && nft -c -f /sim/fw4-check.nft >/sim/nft-check.log 2>&1 && echo "nft-check rc=0" || { echo "nft-check rc=1"; head -6 /sim/nft-check.log; }
' > "$RUN/report.txt" 2>&1

R="$RUN/root"; fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
cat "$RUN/report.txt" | grep -v "write error"
echo "================ checks ($RUN)"
check "version 5.0.0 kept (no migration replay)" "grep -q \"firmware '5.0.0'\" $R/etc/config/update"
check "AP lan enabled, SSID InvizBoxGo" "grep -A7 \"wifi-iface 'lan'\" $R/etc/config/wireless | grep -q \"ssid 'InvizBoxGo'\""
check "no TOKENPASSWORD left in wireless" "! grep -q TOKENPASSWORD $R/etc/config/wireless"
[ -n "$EXPECT_PSK" ] && check "AP key = factory PSK" "grep -q \"key '$EXPECT_PSK'\" $R/etc/config/wireless"
check "AP encryption psk2+aes" "grep -A7 \"wifi-iface 'lan'\" $R/etc/config/wireless | grep -q \"psk2+aes\""
check "scan iface pinned to wlan0" "grep -A3 \"wifi-iface 'wan'\" $R/etc/config/wireless | grep -q \"ifname 'wlan0'\""
check "lan_vpn1 = 10.153.146.1" "grep -A4 \"interface 'lan_vpn1'\" $R/etc/config/network | grep -q 10.153.146.1"
check "dropbear enabled key-only on lan_vpn1" "grep -A5 \"dropbear 'lan_vpn1'\" $R/etc/config/dropbear | grep -q \"enable '1'\" && grep -A5 \"dropbear 'lan_vpn1'\" $R/etc/config/dropbear | grep -q \"PasswordAuth 'off'\""
check "authorized_keys present" "[ -s $R/etc/dropbear/authorized_keys ]"
check "root password set" "grep -q '^root:\\\$' $R/etc/shadow"
check "PSK script ran ok" "grep -q 'uci-defaults 15_defaultpassword rc=0' $RUN/report.txt"
check "migration scripts ran ok" "grep -q 'uci-defaults 18_base_files rc=0' $RUN/report.txt && grep -q 'uci-defaults 20_rest-api rc=0' $RUN/report.txt"
check "TLS cert generated" "grep -q 'inviz-cert rc=0' $RUN/report.txt"
check "lighttpd config valid" "grep -q 'lighttpd-tt rc=0' $RUN/report.txt"
check "fw4 ruleset renders" "grep -q 'fw4-print rc=0' $RUN/report.txt"
check "fw4 ruleset passes nft -c" "grep -q 'nft-check rc=0' $RUN/report.txt"
check "REST API imports" "grep -q 'api-import ok' $RUN/report.txt"
check "REST API /ping answers" "grep -qE 'api GET /ping -> (200|204)' $RUN/report.txt"
check "REST API protects endpoints" "grep -qE 'api GET /system/info/generic -> 40[13]' $RUN/report.txt"
exit $fail
