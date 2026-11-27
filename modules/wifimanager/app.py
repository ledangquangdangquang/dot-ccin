#!/usr/bin/env python3
"""WiFi/IP config manager: a localhost web UI over nmcli. Run: python3 app.py"""
import json, re, secrets, subprocess, time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

HOST, PORT = "127.0.0.1", 8765
TOKEN = secrets.token_hex(16)  # blocks cross-site POSTs from other browser tabs
UUID_RE = re.compile(r"^[0-9a-fA-F-]{36}$")

# Editable nmcli properties: key -> (label, options or None for free text)
FIELDS = {
    "connection.id": ("Tên profile", None),
    "connection.autoconnect": ("Tự kết nối", ["yes", "no"]),
    "ipv4.method": ("IPv4 method", ["auto", "manual", "shared", "link-local", "disabled"]),
    "ipv4.addresses": ("IPv4 address (vd 192.168.1.50/24)", None),
    "ipv4.gateway": ("IPv4 gateway", None),
    "ipv4.dns": ("DNS IPv4 (cách nhau dấu phẩy)", None),
    "ipv4.ignore-auto-dns": ("Bỏ DNS từ DHCP", ["no", "yes"]),
    "ipv6.method": ("IPv6 method", ["auto", "dhcp", "manual", "ignore", "disabled", "link-local", "shared"]),
    "ipv6.addresses": ("IPv6 address", None),
    "ipv6.gateway": ("IPv6 gateway", None),
    "ipv6.dns": ("DNS IPv6", None),
    "ipv6.ignore-auto-dns": ("Bỏ DNS IPv6 từ router", ["no", "yes"]),
    "802-11-wireless.ssid": ("SSID", None),
    "802-11-wireless.band": ("Băng tần (a=5GHz, bg=2.4GHz, trống=tự động)", ["", "a", "bg"]),
    "802-11-wireless.channel": ("Kênh (0=tự động)", None),
    "802-11-wireless.hidden": ("Mạng ẩn", ["no", "yes"]),
    "802-11-wireless.mtu": ("MTU (0=tự động)", None),
    "802-11-wireless.cloned-mac-address": ("MAC (permanent/random/stable/preserve/xx:xx:..)", None),
    "802-11-wireless-security.psk": ("Mật khẩu máy này dùng để kết nối (không đổi mật khẩu router)", None),
    "802-3-ethernet.mtu": ("MTU (0=tự động)", None),
    "802-3-ethernet.cloned-mac-address": ("MAC (permanent/random/stable/preserve/xx:xx:..)", None),
}


def run(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if r.returncode:
        raise RuntimeError((r.stderr or r.stdout).strip())
    return r.stdout


def nmcli(*args):
    return run("nmcli", *args)


def terse(line):
    """Split one `nmcli -t -f A,B` line; ':' and '\\' inside values are backslash-escaped."""
    out, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur, esc = cur + ch, False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append(cur)
            cur = ""
        else:
            cur += ch
    return out + [cur]


def check_uuid(uuid):
    if not isinstance(uuid, str) or not UUID_RE.match(uuid):
        raise ValueError("uuid không hợp lệ")


def connections():
    rows = (terse(l) for l in nmcli("-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show").splitlines())
    return [dict(name=n, uuid=u, type=t, device=d) for n, u, t, d in rows
            if t in ("802-11-wireless", "802-3-ethernet")]


def conn_dump(uuid, secrets=False):
    check_uuid(uuid)
    d = {}
    for line in nmcli(*(["-s"] if secrets else []), "-t", "connection", "show", "uuid", uuid).splitlines():
        k, _, v = line.partition(":")  # single-connection dump: values are not escaped
        d[k] = v
    return d


def conn_detail(uuid):
    d = conn_dump(uuid)
    fields = [dict(key=k, label=lbl, options=opts, value="" if k.endswith(".psk") else d[k])
              for k, (lbl, opts) in FIELDS.items() if k in d]
    runtime = {k: v for k, v in d.items() if k.startswith(("GENERAL.STATE", "IP4.", "IP6.ADDRESS", "IP6.GATEWAY"))}
    return dict(fields=fields, runtime=runtime)


def save(uuid, changes, apply):
    check_uuid(uuid)
    args = []
    for k, v in changes.items():
        if k not in FIELDS:
            raise ValueError(f"không cho phép sửa: {k}")
        if not isinstance(v, str) or "\n" in v:
            raise ValueError(f"giá trị không hợp lệ: {k}")
        if k.endswith(".psk") and not v:
            continue
        args += [k, v]
    if args:
        nmcli("connection", "modify", "uuid", uuid, *args)
    if apply:  # re-activate so the new IP/wifi settings take effect now
        nmcli("connection", "up", "uuid", uuid)


def scan():
    out = nmcli("-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,CHAN", "device", "wifi", "list", "--rescan", "auto")
    rows = (terse(l) for l in out.splitlines())
    return [dict(active=a == "*", ssid=s, signal=int(sig or 0), security=sec, chan=c)
            for a, s, sig, sec, c in rows if s]


def g(pat, s):
    m = re.search(pat, s)
    return m.group(1) if m else ""


# (modulation, bits per symbol, coding rate) by MCS index for VHT/HE/EHT; HT uses index % 8
MCS = [("BPSK", 1, "1/2"), ("QPSK", 2, "1/2"), ("QPSK", 2, "3/4"), ("16-QAM", 4, "1/2"), ("16-QAM", 4, "3/4"),
       ("64-QAM", 6, "2/3"), ("64-QAM", 6, "3/4"), ("64-QAM", 6, "5/6"), ("256-QAM", 8, "3/4"), ("256-QAM", 8, "5/6"),
       ("1024-QAM", 10, "3/4"), ("1024-QAM", 10, "5/6"), ("4096-QAM", 12, "3/4"), ("4096-QAM", 12, "5/6")]
STD = {"EHT": ("WiFi 7 (802.11be)", 13), "HE": ("WiFi 6 (802.11ax)", 11), "VHT": ("WiFi 5 (802.11ac)", 9)}
LEGACY = {"1": ("DSSS/DBPSK", 1, "—"), "2": ("DSSS/DQPSK", 2, "—"), "5.5": ("CCK", 4, "—"), "11": ("CCK", 8, "—"),
          "6": ("BPSK", 1, "1/2"), "9": ("BPSK", 1, "3/4"), "12": ("QPSK", 2, "1/2"), "18": ("QPSK", 2, "3/4"),
          "24": ("16-QAM", 4, "1/2"), "36": ("16-QAM", 4, "3/4"), "48": ("64-QAM", 6, "2/3"), "54": ("64-QAM", 6, "3/4")}


def phy(line):
    """Decode an iw bitrate, e.g. '1080.6 MBit/s 80MHz HE-MCS 10 HE-NSS 2 HE-GI 0 HE-DCM 0'."""
    rate = g(r"([\d.]+) MBit/s", line)
    out = dict(rate=rate + " Mbit/s" if rate else "", width=(g(r"(\d+)MHz", line) or "20") + " MHz", dcm="—")
    tag = next((t for t in STD if f"{t}-MCS" in line), None)
    if tag:
        std, top = STD[tag]
        mcs, nss = int(g(tag + r"-MCS (\d+)", line)), int(g(tag + r"-NSS (\d+)", line) or 1)
        gi = g(tag + r"-GI (\d)", line)
        gi = ["0.8 µs", "1.6 µs", "3.2 µs"][int(gi)] if gi in ("0", "1", "2") else ("0.4 µs" if "short GI" in line else "0.8 µs")
        if tag in ("HE", "EHT"):
            out["dcm"] = "bật" if g(tag + r"-DCM (\d)", line) == "1" else "tắt"
    elif g(r"\bMCS (\d+)", line):
        raw = int(g(r"\bMCS (\d+)", line))
        std, top, mcs, nss = "WiFi 4 (802.11n)", 7, raw % 8, raw // 8 + 1
        gi = "0.4 µs" if "short GI" in line else "0.8 µs"
    else:
        mod, bits, coding = LEGACY.get(f"{float(rate):g}" if rate else "", ("—", "—", "—"))  # iw prints "54.0"
        return dict(out, std="802.11a/b/g (cũ)", mcs="—", mod=mod, bits=bits, coding=coding, nss=1, gi="—")
    mod, bits, coding = MCS[mcs] if mcs < len(MCS) else ("?", "?", "?")
    return dict(out, std=std, mcs=f"{mcs} / {top} (tối đa)", mod=mod, bits=bits, coding=coding, nss=nss, gi=gi)


def status():
    """Live link info of the connected wifi device (iw + nmcli + sysfs byte counters)."""
    devs = (terse(l) for l in nmcli("-t", "-f", "DEVICE,TYPE,STATE", "device").splitlines())
    dev = next((d for d, t, s in devs if t == "wifi" and s == "connected"), None)
    if not dev:
        return {"connected": False}
    link, info = run("iw", "dev", dev, "link"), run("iw", "dev", dev, "info")

    d = {}
    for line in nmcli("-t", "device", "show", dev).splitlines():
        k, _, v = line.partition(":")
        d[k] = v
    active = (terse(l) for l in nmcli("-t", "-f", "IN-USE,SECURITY", "device", "wifi", "list", "--rescan", "no").splitlines())
    sta = run("iw", "dev", dev, "station", "dump")
    num = lambda pat: int(g(pat, sta) or 0)
    quality = dict(
        chains=g(r"signal:\s+-?\d+ \[([^\]]+)\]", sta), signal_avg=g(r"signal avg:\s+(-?\d+)", sta),
        beacon_avg=g(r"beacon signal avg:\s+(-?\d+)", sta), tx_packets=num(r"tx packets:\s+(\d+)"),
        retries=num(r"tx retries:\s+(\d+)"), failed=num(r"tx failed:\s+(\d+)"), beacon_loss=num(r"beacon loss:\s+(\d+)"),
        rx_drop=num(r"rx drop misc:\s+(\d+)"), connected=num(r"connected time:\s+(\d+)"),
        mfp=g(r"MFP:\s+(\w+)", sta), wmm=g(r"WMM/WME:\s+(\w+)", sta), dtim=g(r"DTIM period:\s+(\d+)", sta),
        beacon_int=g(r"beacon interval:\s*(\d+)", sta), short_preamble=g(r"short preamble:\s+(\w+)", sta))
    freq = float(g(r"freq: ([\d.]+)", link) or 0)
    counters = {}
    for k in ("rx", "tx"):
        with open(f"/sys/class/net/{dev}/statistics/{k}_bytes") as f:
            counters[k + "_bytes"] = int(f.read())
    return dict(
        connected=True, device=dev, connection=d.get("GENERAL.CONNECTION", ""),
        ssid=g(r"SSID: (.*)", link), bssid=g(r"Connected to (\S+)", link), mac=g(r"addr (\S+)", info),
        channel=int(g(r"channel (\d+)", info) or 0), freq=freq, width=g(r"width: (\d+ MHz)", info),
        band="2.4 GHz" if freq < 3000 else "5 GHz" if freq < 5925 else "6 GHz",
        signal=int(g(r"signal: (-?\d+)", link) or 0), txpower=g(r"txpower ([\d.]+ dBm)", info),
        rx_rate=g(r"rx bitrate: ([\d.]+ MBit/s)", link), tx_rate=g(r"tx bitrate: ([\d.]+ MBit/s)", link),
        rx_phy=phy(g(r"rx bitrate: (.*)", link)), tx_phy=phy(g(r"tx bitrate: (.*)", link)), quality=quality,
        security=next((s for a, s in active if a == "*"), ""),
        ip=d.get("IP4.ADDRESS[1]", ""), gateway=d.get("IP4.GATEWAY", ""),
        dns=", ".join(v for k, v in d.items() if k.startswith("IP4.DNS")),
        t=time.monotonic(), **counters)


def gateway():
    return g(r"default via (\S+)", run("ip", "route", "show", "default"))


def parse_ping(txt):
    rtt = re.search(r"= ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ms", txt)
    return dict(loss=float(g(r"([\d.]+)% packet loss", txt) or 100),
                **({k: float(rtt[i]) for i, k in enumerate(("min", "avg", "max", "mdev"), 1)} if rtt else
                   dict(min=None, avg=None, max=None, mdev=None)))


def ping_all():
    targets = {"gw": gateway(), "net": "1.1.1.1"}
    procs = {k: subprocess.Popen(["ping", "-n", "-q", "-c", "3", "-i", "0.2", "-W", "1", h],
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
             for k, h in targets.items() if h}
    return {k: dict(host=targets[k], **parse_ping(p.communicate(timeout=10)[0])) for k, p in procs.items()}


DOMAIN_RE = re.compile(r"(?=.{1,253}$)[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+")
IPV4_RE = re.compile(r"\d{1,3}(?:\.\d{1,3}){3}")


def dns_check(name):
    name = (name or "").strip().lower().rstrip(".")
    if not DOMAIN_RE.fullmatch(name):
        raise ValueError("tên miền không hợp lệ")
    r = subprocess.run(["getent", "ahostsv4", name], capture_output=True, text=True, timeout=10)
    system = sorted({l.split()[0] for l in r.stdout.splitlines() if l.strip()})
    gw, router = gateway(), None
    if gw:
        try:  # what other devices at home get: they use the router's DNS
            r = subprocess.run(["dig", "+short", "+time=2", "+tries=1", "A", name, "@" + gw],
                               capture_output=True, text=True, timeout=10)
            router = [x for x in r.stdout.split() if IPV4_RE.fullmatch(x)]
        except (OSError, subprocess.TimeoutExpired):
            pass
    blocked = lambda ips: bool(ips) and all(ip == "0.0.0.0" for ip in ips)
    return dict(name=name, gw=gw, system=system, router=router,
                blocked=blocked(system), router_blocked=router is not None and blocked(router))


def wifi_qr_text(ssid, psk, key_mgmt, hidden):
    q = lambda v: re.sub(r'([\\;,:"])', r"\\\1", v)  # WIFI: URI escapes \ ; , : "
    t = "WPA" if key_mgmt in ("wpa-psk", "sae") else "nopass"
    return f"WIFI:T:{t};S:{q(ssid)};" + (f"P:{q(psk)};" if t == "WPA" else "") + ("H:true;" if hidden else "") + ";"


def wifi_qr(uuid):
    d = conn_dump(uuid, secrets=True)
    if "802-11-wireless.ssid" not in d:
        raise ValueError("không phải profile WiFi")
    km, psk = d.get("802-11-wireless-security.key-mgmt", ""), d.get("802-11-wireless-security.psk", "")
    if km in ("wpa-psk", "sae") and not psk:
        raise ValueError("không đọc được mật khẩu đã lưu (thiếu quyền?)")
    ssid = d["802-11-wireless.ssid"]
    return dict(ssid=ssid, password=psk, text=wifi_qr_text(ssid, psk, km, d.get("802-11-wireless.hidden") == "yes"))


def connect(ssid, password):
    if not isinstance(ssid, str) or not ssid or not isinstance(password, str):
        raise ValueError("thiếu SSID")
    nmcli("device", "wifi", "connect", ssid, *(["password", password] if password else []))


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, ctype="application/json"):
        data = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def guarded(self, fn):
        if self.headers.get("Host") not in (f"127.0.0.1:{PORT}", f"localhost:{PORT}"):
            return self.send(403, {"error": "bad host"})  # DNS-rebinding guard
        try:
            self.send(200, fn())
        except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as e:
            self.send(400, {"error": str(e)})

    def do_GET(self):
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        if url.path == "/":
            if self.headers.get("Host") not in (f"127.0.0.1:{PORT}", f"localhost:{PORT}"):
                return self.send(403, {"error": "bad host"})  # page embeds TOKEN; don't leak it via rebinding
            return self.send(200, PAGE.replace("__TOKEN__", TOKEN), "text/html")
        routes = {"/api/connections": connections, "/api/scan": scan, "/api/status": status, "/api/ping": ping_all,
                  "/api/dns": lambda: dns_check(q.get("name")),
                  "/api/conn": lambda: conn_detail(q.get("uuid"))}
        if url.path not in routes:
            return self.send(404, {"error": "not found"})
        self.guarded(routes[url.path])

    def do_POST(self):
        if not secrets.compare_digest(self.headers.get("X-Token", ""), TOKEN):
            return self.send(403, {"error": "bad token"})
        try:
            b = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        except ValueError:
            return self.send(400, {"error": "bad json"})
        routes = {
            "/api/save": lambda: save(b.get("uuid"), b.get("changes") or {}, bool(b.get("apply"))),
            "/api/up": lambda: (check_uuid(b.get("uuid")), nmcli("connection", "up", "uuid", b["uuid"]))[0],
            "/api/down": lambda: (check_uuid(b.get("uuid")), nmcli("connection", "down", "uuid", b["uuid"]))[0],
            "/api/connect": lambda: connect(b.get("ssid"), b.get("password", "")),
            "/api/qr": lambda: wifi_qr(b.get("uuid")),  # POST+token: returns the saved password
        }
        if self.path not in routes:
            return self.send(404, {"error": "not found"})
        self.guarded(routes[self.path])

    def log_message(self, format, *args):
        pass


PAGE = r"""<!doctype html><html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>WiFi Manager</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
/* Hallmark · genre: modern-minimal · macrostructure: Workbench (live readout + config bench) · theme: Cobalt, recoloured to the repo's Catppuccin Mocha
 * tone: technical · anchor hue: blue · enrichment: none (the charts are the picture) · nav: flush bordered bar · footer: none (single-screen tool)
 * pre-emit critique: P4 H4 E4 S4 R5 V4
 * Mocha is dark, so Cobalt's one contrasting band inverts: the config bench sits on mantle below the base readout.
 * Fonts degrade to system faces offline. */
:root{color-scheme:dark;
 --color-paper:#1e1e2e;--color-band:#181825;--color-well:#11111b;
 --color-ink:#cdd6f4;--color-ink-2:#bac2de;--color-muted:#9399b2;--color-faint:#7f849c;
 --color-rule:#313244;--color-rule-2:#45475a;--color-hover:#313244;
 --color-accent:#89b4fa;--color-accent-hover:#b4befe;--color-accent-ink:#11111b;--color-alt:#fab387;
 --color-ok:#a6e3a1;--color-err:#f38ba8;--color-qr:#ffffff;
 --font-display:"Space Grotesk",ui-sans-serif,system-ui,sans-serif;
 --font-body:Inter,ui-sans-serif,system-ui,sans-serif;
 --font-mono:"JetBrains Mono","Ubuntu Mono","DejaVu Sans Mono",ui-monospace,monospace;
 --text-2xs:12.5px;--text-xs:13.5px;--text-sm:15px;--text-base:16px;--text-md:18px;--text-readout:38px;
 --space-1:4px;--space-2:8px;--space-3:12px;--space-4:16px;--space-5:24px;--space-6:32px;--space-7:48px;
 --radius:6px;--ease-out:cubic-bezier(.16,1,.3,1);--dur:120ms;
 /* names the chart JS paints with */
 --s1:var(--color-accent);--s2:var(--color-alt);--grid:var(--color-rule);--bar:var(--color-rule-2);
 --card:var(--color-paper);--fg:var(--color-ink);--muted:var(--color-muted)}
*{box-sizing:border-box}[hidden]{display:none!important}
html,body{overflow-x:clip}
body{margin:0;background:var(--color-paper);color:var(--color-ink-2);font:var(--text-base)/1.5 var(--font-body)}
code{font:var(--text-xs) var(--font-mono);color:var(--color-ink)}
/* bar */
.bar{position:sticky;top:0;z-index:20;display:flex;align-items:center;gap:var(--space-4);
 padding:var(--space-3) max(var(--space-4),calc((100% - 1560px)/2 + var(--space-4)));/* aligns with .wrap's column */
 background:var(--color-paper);border-bottom:1px solid var(--color-rule)}
.mark{font:600 var(--text-md)/1 var(--font-display);letter-spacing:-.01em;color:var(--color-ink);white-space:nowrap}
.mark i{font-style:normal;color:var(--color-accent)}
#msg{flex:1;min-width:0;font:var(--text-xs)/1.4 var(--font-mono);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.err{color:var(--color-err)}.okm{color:var(--color-ok)}
/* readout: four instruments split by hairlines, no boxes */
.wrap{max-width:1560px;margin:0 auto;padding:0 var(--space-4)}
.readout{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));border-bottom:1px solid var(--color-rule)}
.tile{min-width:0;padding:var(--space-5) var(--space-4) var(--space-4);border-left:1px solid var(--color-rule)}
.tile:first-child{border-left:0;padding-left:0}
.lbl{display:block;font:500 var(--text-2xs)/1 var(--font-mono);letter-spacing:.06em;text-transform:uppercase;color:var(--color-faint)}
.tile .v{margin-top:var(--space-3);font:500 var(--text-readout)/1.1 var(--font-display);letter-spacing:-.02em;color:var(--color-ink);
 font-variant-numeric:tabular-nums;overflow-wrap:anywhere}
.tile .s{margin-top:var(--space-1);font-size:var(--text-xs);color:var(--color-muted)}
/* panels: hairline-ruled rows, not cards */
.grid2{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);column-gap:var(--space-6)}
.card{min-width:0;padding:var(--space-5) 0}
.wrap>.grid2,.wrap>.card{border-bottom:1px solid var(--color-rule)}
.stack>.card+.card{border-top:1px solid var(--color-rule)}
h2{margin:0 0 var(--space-3);font:500 var(--text-md)/1.3 var(--font-display);letter-spacing:-.01em;color:var(--color-ink)}
table.kv{width:100%;border-collapse:collapse;font-size:var(--text-sm)}
table.kv td{padding:6px 0;border-bottom:1px solid var(--color-rule);vertical-align:top}
table.kv tr:last-child td{border-bottom:0}
table.kv td:first-child{width:40%;padding-right:var(--space-3);color:var(--color-muted)}
table.kv td+td{padding-right:var(--space-2);font:var(--text-xs)/1.5 var(--font-mono);color:var(--color-ink);font-variant-numeric:tabular-nums;word-break:break-word}
table.kv b{font-weight:500}
.tag{font-size:var(--text-xs);color:var(--color-muted)}
#chanNote{margin-bottom:var(--space-3)}#pingNote{margin-top:var(--space-2)}
/* charts */
.chart{position:relative}.chart svg{display:block;width:100%}
.chart svg text{fill:var(--color-faint);font:var(--text-2xs) var(--font-mono)}
.tip{position:absolute;top:0;z-index:2;pointer-events:none;padding:6px 10px;background:var(--color-well);border:1px solid var(--color-rule-2);
 border-radius:var(--radius);font:var(--text-xs)/1.5 var(--font-mono);color:var(--color-ink);white-space:nowrap}
.tip b{font-weight:500;color:var(--color-ink-2)}
.lg{display:flex;flex-wrap:wrap;gap:var(--space-4);margin-bottom:var(--space-2);font:var(--text-xs) var(--font-mono);color:var(--color-muted)}
.sw{display:inline-block;width:12px;height:2px;margin-right:6px;vertical-align:middle}
/* help tooltips */
[data-tip]{position:relative}[data-tip]:not(button){cursor:help}
td[data-tip],h2[data-tip],label[data-tip]{text-decoration:underline dotted var(--color-faint);text-underline-offset:4px}
[data-tip]:hover::after,[data-tip]:focus-visible::after{content:attr(data-tip);position:absolute;left:0;top:calc(100% + 6px);z-index:30;
 width:max-content;max-width:min(340px,85vw);white-space:pre-line;padding:10px 12px;background:var(--color-well);color:var(--color-ink-2);
 border:1px solid var(--color-rule-2);border-radius:var(--radius);font:400 var(--text-xs)/1.55 var(--font-body);
 text-transform:none;letter-spacing:0;text-align:left;pointer-events:none}
.tile:nth-child(n+3)::after{left:auto!important;right:0}
/* controls: 6px, ruler-drawn; one solid accent button per form */
button,a.btn{display:inline-flex;align-items:center;gap:6px;padding:7px 12px;border:1px solid var(--color-rule-2);border-radius:var(--radius);
 background:transparent;color:var(--color-ink);font:500 var(--text-sm)/1.2 var(--font-body);white-space:nowrap;text-decoration:none;cursor:pointer;
 transition:border-color var(--dur) var(--ease-out),background-color var(--dur) var(--ease-out)}
button:hover,a.btn:hover{border-color:var(--color-accent);background:var(--color-hover)}
button:active,a.btn:active{transform:translateY(1px)}
button:disabled{opacity:.45;cursor:not-allowed;border-color:var(--color-rule-2);background:transparent;transform:none}
button.pri{background:var(--color-accent);border-color:var(--color-accent);color:var(--color-accent-ink)}
button.pri:hover{background:var(--color-accent-hover);border-color:var(--color-accent-hover)}
a.btn{padding:5px 10px;color:var(--color-accent);font-size:var(--text-xs)}a.btn::after{left:auto!important;right:0}
:focus-visible{outline:2px solid var(--color-accent);outline-offset:2px}
label{display:block;margin:var(--space-3) 0 var(--space-1);font-size:var(--text-xs);color:var(--color-muted)}
label code{margin-left:6px;font-size:var(--text-2xs);color:var(--color-faint)}
input,select{width:100%;padding:7px 10px;border:1px solid var(--color-rule-2);border-radius:var(--radius);background:var(--color-well);
 color:var(--color-ink);font:var(--text-sm)/1.4 var(--font-mono)}
input::placeholder{color:var(--color-faint)}
input:focus-visible,select:focus-visible{border-color:var(--color-accent);outline-offset:1px}
.row{display:flex;flex-wrap:wrap;gap:var(--space-2);margin-top:var(--space-4)}
#dnsName{flex:1;width:auto;min-width:0}#dnsOut{margin-top:var(--space-3);font-size:var(--text-sm)}
.blk{color:var(--color-err);font-weight:600}
pre{margin:0;padding:var(--space-3);background:var(--color-well);border:1px solid var(--color-rule);border-radius:var(--radius);
 font:var(--text-xs)/1.6 var(--font-mono);color:var(--color-ink-2);overflow:auto}
.qr{display:inline-block;margin:var(--space-3) 0;padding:var(--space-3);background:var(--color-qr);border-radius:var(--radius)}
/* config bench */
.bench{margin-top:var(--space-7);background:var(--color-band);border-top:1px solid var(--color-rule)}
main{display:grid;grid-template-columns:300px minmax(0,1fr);column-gap:var(--space-6);max-width:1560px;margin:0 auto;padding:var(--space-2) var(--space-4) var(--space-7)}
.item{display:flex;justify-content:space-between;align-items:baseline;gap:var(--space-2);padding:9px var(--space-3);border-bottom:1px solid var(--color-rule);
 cursor:pointer;transition:background-color var(--dur) var(--ease-out)}
.item:hover,.item.sel{background:var(--color-hover)}
.item.sel{box-shadow:inset 2px 0 0 var(--color-accent)}
.item>span:first-child{min-width:0;color:var(--color-ink);overflow-wrap:anywhere}
.item .tag{font:var(--text-2xs)/1.5 var(--font-mono);color:var(--color-faint);white-space:nowrap}
.item>span:first-child .tag{white-space:normal}
.on{color:var(--color-ok)!important}
.item .on::before{content:"";display:inline-block;width:6px;height:6px;margin-right:6px;border-radius:50%;background:currentColor;vertical-align:1px}
#scan{margin-top:var(--space-2)}
#detail>h2:only-child{color:var(--color-muted)}
@media (max-width:760px){
 :root{--text-readout:28px}
 .readout{grid-template-columns:repeat(2,minmax(0,1fr))}
 .tile:nth-child(odd){border-left:0;padding-left:0}
 .tile:nth-child(-n+2){border-bottom:1px solid var(--color-rule)}
 .grid2,main{grid-template-columns:minmax(0,1fr)}
 .grid2>*+*{border-top:1px solid var(--color-rule)}
 .tile:nth-child(n+3)::after{left:0!important;right:auto}.tile:nth-child(even)::after{left:auto!important;right:0}
}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style></head><body>
<header class="bar"><span class="mark">WiFi<i>/</i>IP</span><span id="msg" role="status"></span>
 <a id="adminLink" class="btn" data-h="b_admin" target="_blank" rel="noopener noreferrer" hidden>Trang quản trị router ↗</a></header>
<section class="wrap">
 <div class="readout" id="tiles"></div>
 <div class="grid2">
  <div class="card"><h2>Thông số kết nối</h2><table class="kv" id="params"></table></div>
  <div class="stack">
   <div class="card"><h2 data-h="h_sig">Tín hiệu (dBm) · 2 phút gần nhất</h2><div class="chart" id="chSig"></div></div>
   <div class="card"><h2 data-h="h_net">Lưu lượng (Mbps)</h2>
    <div class="lg"><span><i class="sw" style="background:var(--s1)"></i>Tải xuống</span><span><i class="sw" style="background:var(--s2)"></i>Tải lên</span></div>
    <div class="chart" id="chNet"></div></div>
  </div>
 </div>
 <div class="card"><h2 data-h="h_chan">Số mạng WiFi trên mỗi kênh</h2><div class="tag" id="chanNote">Đang quét...</div><div class="chart" id="chChan"></div></div>
 <div class="grid2">
  <div class="card"><h2 data-h="h_mod">Điều chế &amp; tốc độ PHY</h2><table class="kv" id="modt"></table></div>
  <div class="card"><h2 data-h="h_q">Chất lượng liên kết</h2><table class="kv" id="qt"></table></div>
 </div>
 <div class="grid2">
  <div class="card"><h2 data-h="h_ping">Ping (ms) · 2 phút</h2>
   <div class="lg"><span><i class="sw" style="background:var(--s1)"></i>Router</span><span><i class="sw" style="background:var(--s2)"></i>Internet (1.1.1.1)</span></div>
   <div class="chart" id="chPing"></div><div class="tag" id="pingNote">Đang đo...</div></div>
  <div class="stack">
   <div class="card"><h2 data-h="h_retry">Tỉ lệ gửi lại (%) · 2 phút</h2><div class="chart" id="chRetry"></div></div>
   <div class="card"><h2 data-h="h_mcs">MCS theo thời gian</h2>
    <div class="lg"><span><i class="sw" style="background:var(--s1)"></i>RX (router → máy)</span><span><i class="sw" style="background:var(--s2)"></i>TX (máy → router)</span></div>
    <div class="chart" id="chMcs"></div></div>
  </div>
 </div>
 <div class="card"><h2 data-h="h_dns">Kiểm tra trang có bị chặn không (DNS)</h2>
  <div class="row"><input id="dnsName" placeholder="vd: example.com" onkeydown="if(event.key==='Enter')dnsCheck()">
   <button data-h="b_dns" onclick="dnsCheck()">Kiểm tra</button></div><div id="dnsOut"></div></div>
</section>
<section class="bench"><main>
 <div class="stack">
  <div class="card"><h2 data-h="h_profiles">Profile đã lưu</h2><div id="conns"></div></div>
  <div class="card"><h2 data-h="h_scan">Mạng xung quanh</h2>
   <button id="scanBtn" data-h="b_scan" onclick="doScan()">Quét WiFi</button><div id="scan"></div></div>
 </div>
 <div class="card" id="detail"><h2>Chọn một profile để sửa</h2></div>
</main></section>
<script>
const TOKEN="__TOKEN__";let cur=null,orig={};
const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function msg(t,ok){$("msg").className=ok?"okm":"err";$("msg").textContent=t}
async function api(path,body){
 const r=await fetch(path,body?{method:"POST",headers:{"Content-Type":"application/json","X-Token":TOKEN},body:JSON.stringify(body)}:{});
 const j=await r.json();if(!r.ok)throw new Error(j.error||r.status);return j}
async function loadConns(){
 try{const cs=await api("/api/connections");
  $("conns").innerHTML=cs.map(c=>`<div class="item ${c.uuid===cur?"sel":""}" tabindex="0" role="button" onclick="openConn('${c.uuid}')">
   <span>${esc(c.name)}</span><span class="tag ${c.device?"on":""}">${c.device?"đang dùng":c.type==="802-3-ethernet"?"ethernet":"wifi"}</span></div>`).join("")||"<i>Không có</i>";
 }catch(e){msg(e.message)}}
async function openConn(uuid){
 cur=uuid;loadConns();
 try{const d=await api("/api/conn?uuid="+uuid);orig={};
  const f=d.fields.map(x=>{orig[x.key]=x.value;
   const inp=x.options?`<select data-k="${x.key}">${[...new Set([x.value,...x.options])].map(o=>`<option ${o===x.value?"selected":""} value="${esc(o)}">${esc(o||"(tự động)")}</option>`).join("")}</select>`
    :`<input data-k="${x.key}" value="${esc(x.value)}" ${x.key.endsWith(".psk")?'type="password"':""}>`;
   return `<label data-h="${x.key}">${esc(x.label)} <code>${x.key}</code></label>${inp}`}).join("");
  const rt=Object.entries(d.runtime).map(([k,v])=>`${k}: ${v}`).join("\n");
  $("detail").innerHTML=`<h2>Sửa profile</h2>${f}
   <div class="row"><button class="pri" data-h="b_apply" onclick="saveConn(true)">Lưu &amp; áp dụng</button>
   <button data-h="b_save" onclick="saveConn(false)">Chỉ lưu</button><button data-h="b_up" onclick="post('/api/up')">Kết nối</button>
   <button data-h="b_down" onclick="post('/api/down')">Ngắt</button>
   ${d.fields.some(x=>x.key==="802-11-wireless.ssid")?'<button data-h="b_qr" onclick="showQR()">Chia sẻ (QR)</button>':""}</div><div id="qrBox"></div>
   <h2 style="margin-top:18px" data-h="h_rt">Trạng thái hiện tại</h2><pre>${esc(rt||"Chưa kết nối")}</pre>`;
  applyHelp();
 }catch(e){msg(e.message)}}
async function saveConn(apply){
 const changes={};document.querySelectorAll("#detail [data-k]").forEach(el=>{if(el.value!==orig[el.dataset.k])changes[el.dataset.k]=el.value});
 msg(apply?"Đang lưu và kết nối lại...":"Đang lưu...",true);
 try{await api("/api/save",{uuid:cur,changes,apply});msg("Đã lưu"+(apply?" và áp dụng":""),true);openConn(cur)}catch(e){msg(e.message)}}
async function post(path){msg("Đang xử lý...",true);try{await api(path,{uuid:cur});msg("Xong",true);openConn(cur)}catch(e){msg(e.message)}}
async function doScan(){
 $("scanBtn").disabled=true;
 try{const ns=await api("/api/scan");lastScan=ns;chanChart();
  $("scan").innerHTML=ns.map((n,i)=>`<div class="item" data-i="${i}" tabindex="0" role="button"><span>${esc(n.ssid)} <span class="tag">kênh ${esc(n.chan)} · ${esc(n.security||"mở")}</span></span>
   <span class="tag ${n.active?"on":""}">${n.signal}%</span></div>`).join("");
  $("scan").querySelectorAll(".item").forEach(el=>el.onclick=()=>joinNet(ns[el.dataset.i]));
 }catch(e){msg(e.message)}finally{$("scanBtn").disabled=false}}
async function joinNet(n){
 const pw=n.security?prompt(`Mật khẩu cho "${n.ssid}" (bỏ trống nếu đã lưu):`):"";if(pw===null)return;
 msg("Đang kết nối "+n.ssid+"...",true);
 try{await api("/api/connect",{ssid:n.ssid,password:pw});msg("Đã kết nối "+n.ssid,true);loadConns()}catch(e){msg(e.message)}}
// ---- live status + charts ----
const POLL=2,HIST=60,HS={sig:[],rx:[],tx:[],retry:[],mr:[],mt:[],pgw:[],pnet:[]};let prev=null,ST=null,lastScan=[];
const quality=d=>Math.max(0,Math.min(100,2*(d+100)));
const grade=d=>d>=-50?"Rất tốt":d>=-60?"Tốt":d>=-70?"Khá":"Yếu";
const push=(a,v)=>{a.push(v);if(a.length>HIST)a.shift()};
const ago=k=>k?k*POLL+"s trước":"bây giờ";
async function tick(){
 if(tick.busy)return;tick.busy=true;
 try{const s=await api("/api/status");ST=s;
  if(!s.connected){TILES.forEach(([k])=>{set("tv_"+k,"—");set("ts_"+k,"")});set("ts_ch","Chưa kết nối WiFi");
   PARAMS.forEach(([k])=>set("pv_"+k,"—"));MODROWS.forEach(([k])=>{set("mr_"+k,"—");set("mt_"+k,"—")});QROWS.forEach(([k])=>set("qv_"+k,"—"));return}
  push(HS.sig,s.signal);
  let liveRetry=null;
  if(prev&&s.t>prev.t){const dt=s.t-prev.t,dp=s.quality.tx_packets-(prev.quality?.tx_packets??0);
   if(prev.quality&&dp>0)liveRetry=(s.quality.retries-prev.quality.retries)/dp*100;
   push(HS.rx,Math.max(0,(s.rx_bytes-prev.rx_bytes)*8/dt/1e6));push(HS.tx,Math.max(0,(s.tx_bytes-prev.tx_bytes)*8/dt/1e6))}
  prev=s;
  const tv={ch:[s.channel,`${s.freq} MHz · ${s.width}`],sig:[s.signal+" dBm",`${grade(s.signal)} · ${quality(s.signal)}%`],
   rate:[(parseFloat(s.rx_rate)||0)+" Mbps",`${s.rx_phy.std.split(" (")[0]} · ${s.rx_phy.mod} · ${s.rx_phy.nss} luồng`],band:[s.band,s.ssid]};
  for(const k in tv){set("tv_"+k,tv[k][0]);set("ts_"+k,tv[k][1])}
  const pv={ssid:s.ssid,bssid:s.bssid,conn:s.connection,ch:`${s.channel} (${s.freq} MHz)`,width:s.width,band:s.band,
   sig:`${s.signal} dBm · ${grade(s.signal)} (${quality(s.signal)}%)`,sec:s.security||"Mở",rate:`${s.rx_rate} / ${s.tx_rate}`,
   txp:s.txpower,ip:s.ip,gw:s.gateway,dns:s.dns,dev:`${s.device} · ${s.mac}`};
  PARAMS.forEach(([k])=>set("pv_"+k,pv[k]||"—"));
  MODROWS.forEach(([k])=>{set("mr_"+k,s.rx_phy[k]??"—");set("mt_"+k,s.tx_phy[k]??"—")});
  const mcsNum=p=>{const n=parseInt(p.mcs);return isNaN(n)?null:n};
  push(HS.mr,mcsNum(s.rx_phy));push(HS.mt,mcsNum(s.tx_phy));if(liveRetry!=null)push(HS.retry,liveRetry);
  lineChart($("chRetry"),[{label:"",name:"Retry",color:"var(--s1)",vals:HS.retry}],{min:0,max:20,dp:0,fmt:v=>v.toFixed(1)+"%"});
  lineChart($("chMcs"),[{label:"RX",name:"RX",color:"var(--s1)",vals:HS.mr},{label:"TX",name:"TX",color:"var(--s2)",vals:HS.mt}],{min:0,max:11,dp:0,fmt:v=>"MCS "+v});
  const q=s.quality,pct=q.tx_packets?(q.retries/q.tx_packets*100).toFixed(1)+"%":"—";
  const qv={chains:q.chains?q.chains.split(", ").map(v=>v+" dBm").join(" · "):"",avg:q.signal_avg&&q.signal_avg+" dBm",beacon:q.beacon_avg&&q.beacon_avg+" dBm",
   retry:`${pct} từ lúc kết nối`+(liveRetry!=null?` · ${liveRetry.toFixed(1)}% trong 2s gần nhất`:""),failed:q.failed,bloss:q.beacon_loss,drop:q.rx_drop,
   uptime:dur(q.connected),mfp:q.mfp,wmm:q.wmm,beaconint:`${q.beacon_int} TU · DTIM ${q.dtim}`,preamble:q.short_preamble};
  QROWS.forEach(([k])=>set("qv_"+k,qv[k]??"—"));
  const a=$("adminLink"),gwOk=/^\d{1,3}(\.\d{1,3}){3}$/.test(s.gateway);  // only ever link to a plain IPv4
  a.hidden=!gwOk;if(gwOk&&a.getAttribute("href")!==`http://${s.gateway}/`)a.href=`http://${s.gateway}/`;
  lineChart($("chSig"),[{label:"",name:"Tín hiệu",color:"var(--s1)",vals:HS.sig}],{min:-90,max:-20,dp:0,fmt:v=>v.toFixed(0)+" dBm"});
  lineChart($("chNet"),[{label:"↓",name:"Tải xuống",color:"var(--s1)",vals:HS.rx},{label:"↑",name:"Tải lên",color:"var(--s2)",vals:HS.tx}],{min:0,max:1,dp:1,fmt:v=>v.toFixed(2)+" Mbps"});
  if(lastScan.length)chanChart();
 }catch(e){msg(e.message)}finally{tick.busy=false}}
function lineChart(el,series,o){
 // null = no sample (e.g. every ping lost): drawn as a gap, shown as "—"
 const all=series.flatMap(s=>s.vals).filter(v=>v!=null);if(!all.length){el.innerHTML="";return}
 const W=el.clientWidth||400,H=170,L=44,R=124,T=10,B=20,f=v=>v==null?"—":o.fmt(v);
 let lo=Math.min(o.min,...all),hi=Math.max(o.max,...all);if(hi===lo)hi=lo+1;
 const X=i=>L+(W-L-R)*i/(HIST-1),Y=v=>T+(H-T-B)*(1-(v-lo)/(hi-lo)),off=s=>HIST-s.vals.length;
 let g="";for(let k=0;k<=3;k++){const v=lo+(hi-lo)*k/3,y=Y(v);
  g+=`<line x1="${L}" x2="${W-R}" y1="${y}" y2="${y}" stroke="var(--grid)"/><text x="${L-6}" y="${y+4}" text-anchor="end">${v.toFixed(o.dp)}</text>`}
 g+=`<text x="${L}" y="${H-4}">−${(HIST-1)*POLL}s</text><text x="${W-R}" y="${H-4}" text-anchor="end">bây giờ</text>`;
 // direct labels at the line ends, nudged apart so two series never overlap
 const ends=series.map(s=>({s,last:s.vals.at(-1),y:Y(s.vals.at(-1)??lo)})).sort((a,b)=>a.y-b.y);
 for(let i=1;i<ends.length;i++)ends[i].ly=Math.max(ends[i].y,(ends[i-1].ly??ends[i-1].y)+16);
 const lines=ends.map(({s,last,y,ly})=>{
  const d=s.vals.map((v,i)=>v==null?"":(i&&s.vals[i-1]!=null?"L":"M")+X(off(s)+i)+","+Y(v)).join("");
  return `<path d="${d}" fill="none" stroke="${s.color}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>
  ${last==null?"":`<circle cx="${X(HIST-1)}" cy="${y}" r="4" fill="${s.color}" stroke="var(--card)" stroke-width="2"/>`}
  <text x="${X(HIST-1)+9}" y="${(ly??y)+4}" style="fill:var(--fg)">${s.label} ${f(last)}</text>`}).join("");
 el.innerHTML=`<svg viewBox="0 0 ${W} ${H}" height="${H}" role="img" aria-label="${esc(series.map(s=>s.name+" "+f(s.vals.at(-1))).join(", "))}">${g}${lines}
  <line class="xh" y1="${T}" y2="${H-B}" stroke="var(--muted)" stroke-dasharray="3 3" visibility="hidden"/>
  <rect x="${L}" y="${T}" width="${W-L-R}" height="${H-T-B}" fill="transparent"/></svg><div class="tip" hidden></div>`;
 const svg=el.querySelector("svg"),tip=el.querySelector(".tip"),xh=el.querySelector(".xh");
 const show=mx=>{
  const i=mx==null?-1:Math.max(0,Math.min(HIST-1,Math.round((mx-L)/(W-L-R)*(HIST-1))));
  const rows=i<0?"":series.map(s=>{const j=i-off(s);return j>=0?`<div><i class="sw" style="background:${s.color}"></i>${s.name}: ${f(s.vals[j])}</div>`:""}).join("");
  if(!rows){tip.hidden=true;xh.setAttribute("visibility","hidden");return}
  tip.innerHTML=`<b>${ago(HIST-1-i)}</b>${rows}`;tip.hidden=false;
  tip.style.left=Math.max(0,Math.min(X(i)+10,W-tip.offsetWidth))+"px";
  xh.setAttribute("x1",X(i));xh.setAttribute("x2",X(i));xh.setAttribute("visibility","visible")};
 svg.onmousemove=e=>{const r=svg.getBoundingClientRect();el._mx=(e.clientX-r.left)*W/r.width;show(el._mx)};
 svg.onmouseleave=()=>{el._mx=null;show(null)};
 show(el._mx)}
function chanChart(){
 const by={};lastScan.forEach(n=>(by[n.chan]??=[]).push(n.ssid));
 const chans=Object.keys(by).map(Number).filter(c=>c>0).sort((a,b)=>a-b);if(!chans.length)return;
 const cur=ST&&ST.connected?ST.channel:null;
 let note=cur?`Bạn đang ở kênh ${cur} (${ST.band}), có ${Math.max(0,(by[cur]?.length||1)-1)} mạng khác cùng kênh.`:"";
 if(cur&&cur<=14){const best=[1,6,11].sort((a,b)=>(by[a]?.length||0)-(by[b]?.length||0))[0];
  note+=best===cur?" Đây đã là kênh ít chen nhất trong 1/6/11.":` Kênh ít chen nhất trong 1/6/11: ${best}.`}
 $("chanNote").textContent=note;
 // one empty slot between the 2.4 GHz and 5 GHz groups
 const slots=[];chans.forEach((c,i)=>{if(i&&chans[i-1]<=14&&c>14)slots.push(null);slots.push(c)});
 const el=$("chChan"),W=el.clientWidth||600,H=180,L=28,R=8,T=18,B=36;
 const max=Math.max(...chans.map(c=>by[c].length)),sw=(W-L-R)/slots.length,bw=Math.min(28,sw*.62);
 const Y=v=>T+(H-T-B)*(1-v/max);
 let g="";for(const v of [...new Set([0,Math.round(max/2),max])]){
  g+=`<line x1="${L}" x2="${W-R}" y1="${Y(v)}" y2="${Y(v)}" stroke="var(--grid)"/><text x="${L-6}" y="${Y(v)+4}" text-anchor="end">${v}</text>`}
 const groups={};
 const bars=slots.map((c,i)=>{if(c==null)return"";
  const n=by[c].length,x=L+sw*i+(sw-bw)/2,y=Y(n),y0=Y(0),r=Math.min(4,bw/2,y0-y),hl=c===cur;
  (groups[c<=14?"2.4 GHz":"5 GHz"]??=[]).push(x+bw/2);
  return `<g data-c="${c}"><rect x="${L+sw*i}" y="${T}" width="${sw}" height="${H-T-B}" fill="transparent"/>
   <path d="M${x},${y0}V${y+r}Q${x},${y} ${x+r},${y}H${x+bw-r}Q${x+bw},${y} ${x+bw},${y+r}V${y0}Z" fill="${hl?"var(--s1)":"var(--bar)"}"/>
   ${hl?`<text x="${x+bw/2}" y="${y-5}" text-anchor="middle" style="fill:var(--fg);font-weight:600">${n}</text>`:""}
   <text x="${x+bw/2}" y="${H-B+14}" text-anchor="middle" ${hl?'style="fill:var(--fg);font-weight:600"':""}>${c}</text></g>`}).join("");
 const bands=Object.entries(groups).map(([b,xs])=>`<text x="${(xs[0]+xs.at(-1))/2}" y="${H-4}" text-anchor="middle">${b}</text>`).join("");
 el.innerHTML=`<svg viewBox="0 0 ${W} ${H}" height="${H}" role="img" aria-label="Số mạng theo kênh">${g}${bars}${bands}</svg><div class="tip" hidden></div>`;
 const svg=el.querySelector("svg"),tip=el.querySelector(".tip");
 svg.onmousemove=e=>{const gEl=e.target.closest("[data-c]");if(!gEl){tip.hidden=true;return}
  const c=+gEl.dataset.c,list=by[c];
  tip.innerHTML=`<b>Kênh ${c}${c===cur?" (đang dùng)":""}: ${list.length} mạng</b>`+list.slice(0,10).map(s=>`<div>${esc(s)}</div>`).join("")+(list.length>10?`<div>… +${list.length-10}</div>`:"");
  tip.hidden=false;const r=svg.getBoundingClientRect(),mx=(e.clientX-r.left)*W/r.width;
  tip.style.left=Math.max(0,Math.min(mx+12,W-tip.offsetWidth))+"px"};
 svg.onmouseleave=()=>{tip.hidden=true}}
// ---- hover/focus help ----
const MTU="Kích thước gói tin tối đa (byte). 0/auto = mặc định 1500.\nChỉ giảm (vd 1400) khi dùng VPN/PPPoE mà một số trang không tải được.";
const MAC="MAC máy dùng khi nối mạng này:\npermanent = MAC thật của card\nrandom = ngẫu nhiên mỗi lần kết nối (riêng tư hơn)\nstable = ngẫu nhiên nhưng cố định cho mạng này\npreserve = giữ MAC hiện tại\nhoặc tự điền, vd 02:11:22:33:44:55.\nĐổi MAC có thể khiến router cấp IP khác hoặc chặn nếu có lọc MAC.";
const SIG="Cường độ sóng nhận được, đơn vị dBm (số âm, càng gần 0 càng mạnh).\n≥ -50: rất tốt\n-50 → -60: tốt\n-60 → -70: khá, gọi video vẫn ổn\n< -70: yếu, dễ chập chờn";
const BAND="2.4 GHz: xuyên tường tốt, đi xa, nhưng chậm và đông mạng.\n5 GHz: nhanh, ít nhiễu, tầm ngắn hơn.\n6 GHz (WiFi 6E/7): nhanh và ít nhiễu nhất, tầm ngắn nhất.";
const HELP={
 t_ch:"Kênh router đang phát.\n2.4 GHz: kênh 1–13, chỉ 1, 6, 11 không chồng lấn nhau.\n5 GHz: kênh 36–165, nhiều chỗ hơn.\nKênh do router chọn; muốn đổi phải vào trang quản trị router.",
 t_sig:SIG,t_band:BAND,
 t_rate:"Tốc độ kết nối vật lý giữa card và router (PHY rate), KHÔNG phải tốc độ Internet.\nTốc độ tải thực tế thường chỉ ~50–70% con số này và còn bị giới hạn bởi gói cước.",
 p_ssid:"Tên mạng WiFi.",
 p_bssid:"Địa chỉ MAC của điểm phát (router/AP) bạn đang nối.\nRouter 2 băng hoặc hệ mesh có nhiều BSSID dùng chung một SSID.",
 p_conn:"Profile NetworkManager đang dùng (lưu mật khẩu, cấu hình IP...). Sửa trong khung bên dưới.",
 p_ch:"Số kênh và tần số trung tâm của kênh (MHz).",
 p_width:"Độ rộng kênh. Rộng hơn (40/80/160 MHz) thì nhanh hơn nhưng dễ nhiễu và chiếm chỗ của mạng khác.\n20 MHz là chuẩn ở 2.4 GHz.",
 p_band:BAND,p_sig:SIG+"\n% chỉ là quy đổi gần đúng.",
 p_sec:"Chuẩn mã hoá WiFi: WPA3 > WPA2 > WPA1 (cũ, yếu) > WEP (không an toàn).\n'Mở' = không mã hoá, người xung quanh có thể nghe lén dữ liệu không qua HTTPS.",
 p_rate:"RX = tốc độ nhận (router → máy), TX = tốc độ gửi (máy → router).\nĐây là tốc độ link tối đa hiện tại, thay đổi theo chất lượng sóng.",
 p_txp:"Công suất phát của card WiFi MÁY BẠN (chiều máy → router). 20 dBm ≈ 100 mW.\nKhông liên quan trực tiếp tới 'Tín hiệu': đó là sóng router phát tới máy, đã suy hao qua khoảng cách và tường (mất 60–70 dB là bình thường).\nDo driver và quy định từng quốc gia đặt.",
 p_ip:"Địa chỉ IP của máy trong mạng nội bộ, kèm prefix.\n/24 = subnet 255.255.255.0 (254 thiết bị).",
 p_gw:"Gateway = địa chỉ router. Mọi gói tin ra Internet đều đi qua đây.",
 p_dns:"Máy chủ phân giải tên miền (google.com → IP). Thường do router cấp qua DHCP.\nCó thể đặt 1.1.1.1 hoặc 8.8.8.8 trong profile.",
 p_dev:"Tên card mạng trong Linux và địa chỉ MAC đang dùng (có thể là MAC giả nếu bật ngẫu nhiên hoá).",
 "connection.id":"Tên hiển thị của profile, chỉ để bạn nhận ra; không ảnh hưởng kết nối.",
 "connection.autoconnect":"yes = tự kết nối khi bắt được mạng này.\nCó nhiều mạng đã lưu thì NetworkManager chọn theo độ ưu tiên và lần dùng gần nhất.",
 "ipv4.method":"auto = nhận IP tự động từ router (DHCP) — mặc định.\nmanual = IP tĩnh, phải điền address + gateway + DNS.\nshared = chia sẻ mạng cho thiết bị khác (máy thành router).\nlink-local = chỉ IP 169.254.x.x, không ra Internet.\ndisabled = tắt IPv4.",
 "ipv4.addresses":"IP tĩnh kèm prefix, vd 192.168.1.50/24.\nNên chọn IP ngoài dải DHCP của router để tránh trùng. Bắt buộc khi method = manual.",
 "ipv4.gateway":"IP của router, thường 192.168.1.1 hoặc 192.168.0.1.\nSai gateway: vẫn vào được mạng LAN nhưng mất Internet.",
 "ipv4.dns":"Máy chủ DNS, nhiều cái cách nhau dấu phẩy, vd 1.1.1.1,8.8.8.8.\nĐể trống = dùng DNS router cấp.",
 "ipv4.ignore-auto-dns":"yes = bỏ DNS router cấp qua DHCP (IPv4), chỉ dùng DNS bạn điền ở trên.\nDùng khi muốn ép dùng 1.1.1.1 / 8.8.8.8.\nLưu ý: chỉ áp dụng IPv4 — DNS IPv6 phải bỏ riêng ở 'Bỏ DNS IPv6 từ router'.",
 "ipv6.method":"auto = tự động (SLAAC/DHCPv6), nên dùng.\ndhcp = chỉ DHCPv6.\nmanual = IPv6 tĩnh.\nignore/disabled = không dùng IPv6 (thử khi IPv6 của nhà mạng chập chờn).",
 "ipv6.addresses":"IPv6 tĩnh kèm prefix, vd 2001:db8::10/64. Chỉ cần khi method = manual.",
 "ipv6.gateway":"Router IPv6. Thường để trống, máy tự học từ router.",
 "ipv6.dns":"DNS IPv6, vd 2606:4700:4700::1111 (Cloudflare).",
 "ipv6.ignore-auto-dns":"yes = bỏ DNS IPv6 router quảng bá (vd fe80::1).\nCần bật cùng với 'Bỏ DNS từ DHCP' của IPv4, nếu không máy vẫn có thể hỏi DNS của router qua IPv6.",
 "802-11-wireless.ssid":"Tên mạng mà profile này kết nối tới. Phải khớp chính xác, phân biệt hoa/thường.",
 "802-11-wireless.band":"Ép kết nối một băng:\na = chỉ 5 GHz\nbg = chỉ 2.4 GHz\ntrống = tự chọn\nHữu ích khi router 2 băng dùng chung một tên.",
 "802-11-wireless.channel":"Chỉ kết nối nếu router phát đúng kênh này — KHÔNG đổi được kênh của router.\nĐể 0 (tự động); đặt sai sẽ không kết nối được.",
 "802-11-wireless.hidden":"yes nếu router ẩn tên mạng, để máy chủ động dò tìm.\nẨn SSID không làm mạng an toàn hơn.",
 "802-11-wireless.mtu":MTU,"802-3-ethernet.mtu":MTU,
 "802-11-wireless.cloned-mac-address":MAC,"802-3-ethernet.cloned-mac-address":MAC,
 "802-11-wireless-security.psk":"Mật khẩu MÁY NÀY dùng để kết nối (8–63 ký tự). Để trống = giữ mật khẩu cũ.\nKHÔNG đổi mật khẩu của router. Chỉ dùng khi router đã được đổi mật khẩu và máy cần cập nhật theo.\nĐiền khác mật khẩu router thì máy sẽ không kết nối được.\nMuốn đổi mật khẩu WiFi thật: vào 'Trang quản trị router' (góc trên).",
 h_mod:"Cách card và router đang mã hoá dữ liệu lên sóng, đo riêng chiều nhận (RX) và gửi (TX).\nRouter tự nâng/hạ MCS liên tục theo chất lượng sóng: sóng sạch → điều chế dày (1024-QAM) + nhiều luồng → nhanh.",
 h_q:"Số liệu từ lúc kết nối (iw station dump): cho biết đường truyền có ổn định không.",
 m_std:"Thế hệ WiFi của khung đang dùng: WiFi 4 (n), 5 (ac), 6 (ax), 7 (be).\nBị giới hạn bởi bên yếu hơn giữa card và router.",
 m_rate:"Tốc độ vật lý của kiểu mã hoá hiện tại, phụ thuộc MCS × số luồng × độ rộng kênh × GI.\nTốc độ tải thực tế thường chỉ 50–70% con số này.",
 m_mcs:"Modulation and Coding Scheme: chỉ số chọn cặp (điều chế, tỉ lệ mã hoá).\nCàng cao càng nhanh nhưng cần sóng càng sạch.\nTối đa: WiFi 4 = 7, WiFi 5 = 9, WiFi 6 = 11, WiFi 7 = 13.",
 m_mod:"Kiểu điều chế trên TỪNG sóng mang con OFDM: mỗi ký hiệu có bao nhiêu trạng thái.\nWiFi 4/5 dùng OFDM, WiFi 6/7 dùng OFDMA (chia kênh thành hàng trăm sóng mang con); QAM là cách mã hoá bit lên mỗi sóng mang con đó.\nBPSK / QPSK: bền nhưng chậm (dùng khi sóng yếu)\n16 / 64-QAM: trung bình\n256-QAM (WiFi 5), 1024-QAM (WiFi 6), 4096-QAM (WiFi 7): rất nhanh, cần sóng mạnh và ít nhiễu (thường ≥ -55 → -60 dBm).",
 m_bits:"Số bit mỗi ký hiệu mang được = log2(số điểm chòm sao).\n1024-QAM = 10 bit, 256-QAM = 8 bit, 64-QAM = 6 bit.",
 m_coding:"Tỉ lệ mã sửa lỗi (FEC): 5/6 = cứ 6 bit thì 5 bit là dữ liệu, 1 bit để sửa lỗi.\nTỉ lệ thấp (1/2) bền hơn nhưng chậm hơn.",
 m_nss:"Số luồng không gian (MIMO) truyền song song qua nhiều ăng-ten. 2 luồng ≈ gấp đôi 1 luồng.\nLaptop thường 2×2; TX hay chỉ còn 1 luồng khi chiều máy → router kém hơn.",
 m_width:"Độ rộng kênh của khung này. Gấp đôi độ rộng ≈ gấp đôi tốc độ, nhưng dễ nhiễu hơn.",
 m_gi:"Guard interval: khoảng nghỉ giữa các ký hiệu để chống sóng dội.\nNgắn (0.4 / 0.8 µs) = nhanh hơn; dài (1.6 / 3.2 µs) = bền hơn ở nơi nhiều phản xạ.",
 m_dcm:"Dual Carrier Modulation (WiFi 6): gửi cùng dữ liệu trên 2 sóng mang con để bền khi sóng yếu, đổi lại tốc độ giảm một nửa.",
 q_chains:"Tín hiệu đo riêng ở từng ăng-ten của card.\nChênh nhau nhiều (> 10 dB) thường do hướng đặt máy hoặc ăng-ten bị che (tay, màn hình).",
 q_avg:"Tín hiệu trung bình của các khung dữ liệu gần đây, ổn định hơn số tức thời.",
 q_beacon:"Tín hiệu trung bình của beacon (gói router phát ~10 lần/giây ở tốc độ thấp nhất).",
 q_retry:"Tỉ lệ khung phải gửi lại vì router không xác nhận (ACK).\n< 10%: tốt · 10–20%: có nhiễu / chen kênh · > 20%: kém, ping sẽ dao động.\nSố '2s gần nhất' là tình trạng hiện tại.",
 q_failed:"Khung gửi thất bại hẳn sau khi hết lượt gửi lại. Nên ≈ 0.",
 q_bloss:"Số lần mất liên tiếp beacon của router. Tăng dần = sóng chập chờn, sắp rớt mạng.",
 q_drop:"Gói nhận được nhưng driver bỏ (trùng lặp, lỗi giải mã...). Vài trăm trong nhiều giờ là bình thường.",
 q_uptime:"Thời gian đã kết nối liên tục với router (BSSID) này.",
 q_mfp:"Management Frame Protection (802.11w / PMF): chống giả mạo gói ngắt kết nối (tấn công deauth).\nBắt buộc với WPA3. 'no' = mạng WPA2 chưa bật PMF.",
 q_wmm:"WiFi Multimedia: ưu tiên gói thoại / video. Bắt buộc để chạy WiFi 4 trở lên.",
 q_beaconint:"Beacon interval (TU ≈ 1.024 ms; 100 TU ≈ 0.1 s) và DTIM (máy thức dậy nhận broadcast sau mỗi bao nhiêu beacon).\nDTIM lớn tiết kiệm pin hơn nhưng trễ hơn.",
 q_preamble:"Short preamble / slot time: phần đầu khung ngắn hơn → hiệu suất cao hơn. 'no' thường do có thiết bị 802.11b cũ.",
 h_ping:"Ping mỗi 2 giây tới router (chặng WiFi) và tới 1.1.1.1 (ra Internet).\nRouter cao/dao động → lỗi ở WiFi. Chỉ Internet cao → lỗi ở nhà mạng.\nPing router tốt: < 5 ms. Jitter = độ dao động; > 10 ms sẽ thấy lag khi gọi video/chơi game.\nCard Intel bật tiết kiệm pin cũng làm ping router dao động.",
 h_retry:"Tỉ lệ khung phải gửi lại trong từng 2 giây.\n< 10%: tốt · 10–20%: có nhiễu/chen kênh · > 20%: kém.\nĐỉnh nhọn thường trùng lúc mạng hàng xóm tải nặng hoặc có vật cản.",
 h_mcs:"MCS card và router chọn theo thời gian. Đường thẳng ở mức cao = sóng ổn định.\nTụt xuống liên tục = sóng yếu/nhiễu, router phải hạ điều chế cho bền.",
 h_dns:"Kiểm tra một tên miền có bị DNS chặn không, ở cả máy này lẫn qua router.\n0.0.0.0 = bị chặn (Cloudflare Family).\nThiết bị khác trong nhà dùng DNS router, nên chỉ bị chặn nếu router chặn.",
 b_dns:"Phân giải tên miền qua DNS hệ thống và qua router, rồi so sánh.",
 b_qr:"Tạo mã QR chứa tên mạng + mật khẩu đã lưu, để điện thoại quét là vào mạng.\nMật khẩu chỉ hiện khi bạn bấm 'Hiện'.",
 b_admin:"Mở trang cấu hình router (địa chỉ gateway) trong tab mới.\nỞ đó đổi được mật khẩu WiFi, tên mạng, kênh phát, DNS cho cả nhà.\nTài khoản đăng nhập thường in ở mặt dưới router hoặc do nhà mạng cấp.",
 h_profiles:"Các mạng đã lưu trong NetworkManager (WiFi và dây). 'đang dùng' = đang kết nối.\nBấm để xem và sửa cấu hình.",
 h_scan:"Các mạng WiFi máy bắt được, kèm kênh và kiểu bảo mật.\n% = cường độ sóng. Bấm vào mạng để kết nối.",
 h_sig:"Cường độ sóng theo thời gian, đo mỗi 2 giây.\nDao động mạnh = có vật cản, nhiễu, hoặc bạn đang di chuyển.\nDi chuột lên biểu đồ để xem từng điểm.",
 h_net:"Lưu lượng thực tế đang đi qua card WiFi (mọi ứng dụng cộng lại).\nKhác 'Tốc độ link': đây là mức đang dùng, không phải mức tối đa.",
 h_chan:"Số mạng WiFi bắt được trên mỗi kênh; cột xanh là kênh bạn đang dùng.\nMạng cùng kênh phải chia nhau thời gian phát → chậm, ping dao động.\nKênh chồng lấn (vd 4, 5, 7, 8 so với 6) còn gây nhiễu nặng hơn.\nDi chuột lên cột để xem tên các mạng.",
 h_rt:"Cấu hình đang chạy thực tế của profile (IP, gateway, DNS được cấp), có thể khác cấu hình đã lưu.",
 b_apply:"Lưu và kết nối lại ngay để áp dụng. Mạng sẽ mất vài giây.",
 b_save:"Chỉ lưu; áp dụng ở lần kết nối sau.",
 b_up:"Kết nối bằng profile này.",b_down:"Ngắt kết nối profile này.",
 b_scan:"Quét lại các mạng WiFi xung quanh (mất vài giây).",
};
function applyHelp(){document.querySelectorAll("[data-h]").forEach(e=>{const t=HELP[e.dataset.h];
 if(t&&!e.dataset.tip){e.dataset.tip=t;if(e.tagName!=="BUTTON")e.tabIndex=0}})}
const dur=t=>{const h=Math.floor(t/3600),m=Math.floor(t%3600/60);return h?`${h} giờ ${m} phút`:`${m} phút ${t%60} giây`};
const MODROWS=[["std","Chuẩn WiFi"],["rate","Tốc độ PHY"],["mcs","MCS"],["mod","Điều chế"],["bits","Bit / ký hiệu"],["coding","Tỉ lệ mã hoá"],
 ["nss","Luồng không gian (NSS)"],["width","Độ rộng kênh"],["gi","Guard interval"],["dcm","DCM"]];
const QROWS=[["chains","Tín hiệu từng ăng-ten"],["avg","Tín hiệu trung bình"],["beacon","Tín hiệu beacon TB"],["retry","Tỉ lệ gửi lại (retry)"],
 ["failed","Gửi thất bại"],["bloss","Beacon bị mất"],["drop","Gói nhận bị bỏ"],["uptime","Đã kết nối"],["mfp","MFP / PMF"],["wmm","WMM (QoS)"],
 ["beaconint","Beacon / DTIM"],["preamble","Short preamble"]];
const set=(id,v)=>{const e=$(id);if(e&&e.textContent!==String(v))e.textContent=v};
const TILES=[["ch","Kênh"],["sig","Tín hiệu"],["rate","Tốc độ link"],["band","Băng tần"]];
const PARAMS=[["ssid","SSID"],["bssid","BSSID (router)"],["conn","Profile"],["ch","Kênh"],["width","Độ rộng kênh"],["band","Băng tần"],
 ["sig","Tín hiệu"],["sec","Bảo mật"],["rate","Tốc độ RX / TX"],["txp","Công suất phát"],["ip","IP"],["gw","Gateway"],["dns","DNS"],["dev","Card mạng"]];
// built once; tick() only updates text so open tooltips don't flicker every poll
$("tiles").innerHTML=TILES.map(([k,l])=>`<div class="tile" data-h="t_${k}"><span class="lbl">${l}</span><div class="v" id="tv_${k}">—</div><div class="s" id="ts_${k}"></div></div>`).join("");
$("params").innerHTML=PARAMS.map(([k,l])=>`<tr><td data-h="p_${k}">${l}</td><td id="pv_${k}">—</td></tr>`).join("");
$("modt").innerHTML=`<tr><td></td><td><b>↓ RX</b><div class="tag">router → máy</div></td><td><b>↑ TX</b><div class="tag">máy → router</div></td></tr>`
 +MODROWS.map(([k,l])=>`<tr><td data-h="m_${k}">${l}</td><td id="mr_${k}">—</td><td id="mt_${k}">—</td></tr>`).join("");
$("qt").innerHTML=QROWS.map(([k,l])=>`<tr><td data-h="q_${k}">${l}</td><td id="qv_${k}">—</td></tr>`).join("");
applyHelp();
async function pingTick(){
 if(pingTick.busy)return;pingTick.busy=true;
 try{const r=await api("/api/ping"),gw=r.gw,net=r.net;
  push(HS.pgw,gw?.avg??null);push(HS.pnet,net?.avg??null);
  lineChart($("chPing"),[{label:"Router",name:"Router",color:"var(--s1)",vals:HS.pgw},{label:"Net",name:"Internet",color:"var(--s2)",vals:HS.pnet}],
   {min:0,max:20,dp:0,fmt:v=>v.toFixed(1)+" ms"});
  // shortcut: verdict uses only the latest 3-ping sample, upgrade to a rolling window if it flaps too much
  const pf=p=>p&&p.avg!=null?`${p.avg.toFixed(1)} ms (jitter ${p.mdev.toFixed(1)} ms, mất ${p.loss}%)`:"mất gói";
  const v=!gw||gw.avg==null?"Không ping được router."
   :gw.loss>0||gw.avg>15||gw.mdev>10?"⚠ Trễ/dao động ngay ở chặng WiFi → nguyên nhân nằm ở WiFi (nhiễu, chen kênh, sóng yếu, card tiết kiệm pin)."
   :!net||net.avg==null||net.loss>0||net.avg>80?"WiFi ổn, nhưng ra Internet chậm/mất gói → do nhà mạng hoặc đường truyền bên ngoài."
   :"✓ Ổn định cả WiFi lẫn Internet.";
  set("pingNote",`Router: ${pf(gw)} · Internet: ${pf(net)}. ${v}`);
 }catch(e){msg(e.message)}finally{pingTick.busy=false}}
async function dnsCheck(){
 const n=$("dnsName").value.trim();if(!n)return;$("dnsOut").textContent="Đang kiểm tra...";
 try{const r=await api("/api/dns?name="+encodeURIComponent(n));
  const row=(label,ips,blk)=>`<div><b>${label}:</b> ${ips==null?"không kiểm tra được":ips.length?esc(ips.join(", ")):"không phân giải được"} → `
   +(blk?`<span class="blk">BỊ CHẶN</span>`:ips==null?"?":ips.length?"không bị chặn":"bị chặn (NXDOMAIN) hoặc tên miền không tồn tại")+`</div>`;
  $("dnsOut").innerHTML=`<div style="margin-bottom:4px"><code>${esc(r.name)}</code></div>`+row("Máy này (DNS hệ thống)",r.system,r.blocked)
   +row(`Qua router ${esc(r.gw||"?")} (điện thoại, máy khác trong nhà)`,r.router,r.router_blocked)
   +`<div class="tag" style="margin-top:6px">Trình duyệt bật DNS-over-HTTPS (vd Firefox của bạn) dùng DNS riêng, có thể khác kết quả trên.</div>`;
 }catch(e){$("dnsOut").textContent=e.message}}
const QR_URL="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js",QR_SRI="sha384-3zSEDfvllQohrq0PHL1fOXJuC/jSOO34H46t6UQfobFOmxE5BpjjaIJY5F2/bMnU";
const loadQR=()=>window.QRCode?Promise.resolve():new Promise((ok,no)=>{const sc=document.createElement("script");
 sc.src=QR_URL;sc.integrity=QR_SRI;sc.crossOrigin="anonymous";sc.onload=ok;sc.onerror=()=>no(new Error("Không tải được thư viện QR (cần Internet)"));document.head.appendChild(sc)});
async function showQR(){
 const box=$("qrBox");box.textContent="Đang tạo mã QR...";
 try{const [r]=await Promise.all([api("/api/qr",{uuid:cur}),loadQR()]);
  box.innerHTML=`<div class="qr" id="qrImg" role="img" aria-label="Mã QR WiFi"></div>
   <div>SSID: <b>${esc(r.ssid)}</b></div><div>Mật khẩu: <code id="qrPw">••••••••</code> <button id="qrPwBtn">Hiện</button></div>
   <div class="tag">Quét bằng camera điện thoại để vào mạng. Ai thấy mã này cũng vào được mạng.</div>`;
  new QRCode($("qrImg"),{text:r.text,width:200,height:200,correctLevel:QRCode.CorrectLevel.M});
  $("qrPwBtn").onclick=()=>{const on=$("qrPwBtn").textContent==="Hiện";$("qrPw").textContent=on?(r.password||"(mạng mở)"):"••••••••";$("qrPwBtn").textContent=on?"Ẩn":"Hiện"};
 }catch(e){box.textContent=e.message}}
document.addEventListener("keydown",e=>{if(e.key==="Enter"&&e.target.classList?.contains("item"))e.target.click()});
loadConns();tick();setInterval(tick,POLL*1000);pingTick();setInterval(pingTick,POLL*1000);doScan();
</script></body></html>"""

if __name__ == "__main__":
    print(f"Mở http://{HOST}:{PORT}  (Ctrl+C để thoát)")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
