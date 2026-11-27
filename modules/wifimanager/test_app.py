import app

assert app.terse(r"*:My\:Net:100:WPA2:6") == ["*", "My:Net", "100", "WPA2", "6"]
assert app.terse(r"a\\b:") == ["a\\b", ""]

for bad in [("not-a-uuid", {}), ("f0666c9b-abef-4192-9529-f16364bbe428", {"connection.type": "x"}),
            ("f0666c9b-abef-4192-9529-f16364bbe428", {"ipv4.dns": "1.1.1.1\nx"})]:
    try:
        app.save(*bad, apply=False)
        raise AssertionError(f"should reject {bad}")
    except ValueError:
        pass
print("ok")

p = app.phy("1080.6 MBit/s 80MHz HE-MCS 10 HE-NSS 2 HE-GI 0 HE-DCM 0")
assert (p["std"], p["mod"], p["bits"], p["coding"], p["nss"], p["width"], p["gi"], p["dcm"]) == \
    ("WiFi 6 (802.11ax)", "1024-QAM", 10, "3/4", 2, "80 MHz", "0.8 µs", "tắt")
p = app.phy("144.4 MBit/s MCS 15 short GI")  # HT: index 15 = MCS 7 on 2 streams
assert (p["std"], p["mod"], p["coding"], p["nss"], p["gi"], p["width"]) == ("WiFi 4 (802.11n)", "64-QAM", "5/6", 2, "0.4 µs", "20 MHz")
p = app.phy("866.7 MBit/s VHT-MCS 9 80MHz short GI VHT-NSS 2")
assert (p["std"], p["mod"], p["nss"], p["gi"]) == ("WiFi 5 (802.11ac)", "256-QAM", 2, "0.4 µs")
p = app.phy("54.0 MBit/s")
assert (p["mod"], p["coding"], p["std"]) == ("64-QAM", "3/4", "802.11a/b/g (cũ)")
assert app.phy("5.5 MBit/s")["mod"] == "CCK"
print("phy ok")

r = app.parse_ping("3 packets transmitted, 3 received, 0% packet loss, time 401ms\nrtt min/avg/max/mdev = 26.437/27.096/27.754/0.537 ms")
assert r == dict(loss=0.0, min=26.437, avg=27.096, max=27.754, mdev=0.537), r
assert app.parse_ping("3 packets transmitted, 0 received, 100% packet loss")["avg"] is None
assert app.wifi_qr_text('My;Net', 'p:a"ss' + "\\", "wpa-psk", True) == r'WIFI:T:WPA;S:My\;Net;P:p\:a\"ss\\;H:true;;'
assert app.wifi_qr_text("Cafe", "", "", False) == "WIFI:T:nopass;S:Cafe;;"
for bad in ["", "-x.com", "a b.com", "localhost", "x.com;rm", "@1.1.1.1"]:
    try:
        app.dns_check(bad)
        raise AssertionError(bad)
    except ValueError:
        pass
print("ping/qr/dns ok")
