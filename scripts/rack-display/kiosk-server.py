#!/usr/bin/env python3
# Kiosk-Webserver fürs Rack-Display
# - liefert /home/kiosk/screen aus
# - /shelly/...   -> Shelly-Steckdose (Watt)
# - /api/beszel   -> Systeme aus Beszel (read-only Benutzer)
# - /api/pihole   -> Pi-hole-Statistik (App-Passwort), /api/pihole/details -> Top-Domains + Clients
# - /api/beszel/verlauf/<id> -> CPU/RAM der letzten 60 Minuten
# - /api/kuma     -> Monitore der Uptime-Kuma-Statusseite
# - /api/backup   -> letzte vzdump-Backups von Proxmox (Token nur mit PVEAuditor)
# Zugangsdaten stehen in /etc/kiosk-dashboard.json (nur root + kiosk lesbar)
import http.server, urllib.request, urllib.error, urllib.parse, json, os, threading, time, ssl

CONF = json.load(open(os.environ.get("KIOSK_CONF", "/etc/kiosk-dashboard.json")))
SHELLY = CONF.get("shelly", "http://192.168.2.237")
BESZEL = CONF.get("beszel_url", "http://192.168.2.21:8090")
PIHOLE = CONF.get("pihole_url", "http://127.0.0.1:8080")
KUMA   = CONF.get("kuma_url", "http://127.0.0.1:3001")
KUMA_SLUG = CONF.get("kuma_slug", "rack")
PVE    = CONF.get("pve_url", "https://192.168.2.20:8006")
PVE_NODE = CONF.get("pve_node", "pve01")
# Proxmox nutzt ein selbstsigniertes Zertifikat (nur im Heimnetz, nur lesender Token)
PVE_SSL = ssl.create_default_context(); PVE_SSL.check_hostname = False; PVE_SSL.verify_mode = ssl.CERT_NONE
os.chdir(os.environ.get("KIOSK_DIR", "/home/kiosk/screen"))

lock = threading.Lock()
state = {"bz_token": None, "bz_time": 0, "ph_sid": None}

def hol(url, data=None, headers=None, method=None, timeout=5, ctx=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
        return r.read()

def beszel_token(force=False):
    if force or not state["bz_token"] or time.time() - state["bz_time"] > 6 * 3600:
        body = json.dumps({"identity": CONF["beszel_user"], "password": CONF["beszel_password"]}).encode()
        r = json.loads(hol(BESZEL + "/api/collections/users/auth-with-password", body,
                            {"Content-Type": "application/json"}))
        state["bz_token"], state["bz_time"] = r["token"], time.time()
    return state["bz_token"]

def beszel_systems():
    raw = beszel_get("/api/collections/systems/records?perPage=100&sort=name&fields=id,name,status,info")
    out = []
    for s in json.loads(raw)["items"]:
        i = s.get("info") or {}
        out.append({"id": s["id"], "name": s["name"], "status": s["status"], "cpu": i.get("cpu"), "ram": i.get("mp"),
                    "disk": i.get("dp"), "temp": i.get("dt"), "uptime": i.get("u"), "info": i})
    return out

def beszel_verlauf(sid):
    f = urllib.parse.quote(f"system='{sid}' && type='1m'")
    raw = beszel_get(f"/api/collections/system_stats/records?filter={f}&sort=-created&perPage=60&fields=created,stats")
    return [{"t": r["created"], "s": r.get("stats") or {}} for r in json.loads(raw)["items"]][::-1]

def beszel_get(pfad):
    url = BESZEL + pfad
    for versuch in (0, 1):
        try:
            raw = hol(url, headers={"Authorization": beszel_token(force=versuch == 1)})
            break
        except urllib.error.HTTPError as e:
            if e.code not in (401, 403) or versuch: raise
    return raw

def pihole_sid(force=False):
    if force or not state["ph_sid"]:
        r = json.loads(hol(PIHOLE + "/api/auth", json.dumps({"password": CONF["pihole_password"]}).encode(),
                            {"Content-Type": "application/json"}))
        state["ph_sid"] = r["session"]["sid"]
    return state["ph_sid"]

def pihole_get(pfad):
    for versuch in (0, 1):
        try:
            return json.loads(hol(PIHOLE + pfad, headers={"X-FTL-SID": pihole_sid(force=versuch == 1)}))
        except urllib.error.HTTPError as e:
            if e.code != 401 or versuch: raise

def pihole_details():
    top = pihole_get("/api/stats/top_domains?blocked=true&count=6").get("domains", [])
    clients = pihole_get("/api/stats/top_clients?count=5").get("clients", [])
    try: blocking = pihole_get("/api/dns/blocking").get("blocking")
    except Exception: blocking = None
    return {"top": top, "clients": clients, "blocking": blocking}

def kuma():
    seite = json.loads(hol(f"{KUMA}/api/status-page/{KUMA_SLUG}"))
    hb = json.loads(hol(f"{KUMA}/api/status-page/heartbeat/{KUMA_SLUG}"))
    out = []
    for gruppe in seite.get("publicGroupList", []):
        for m in gruppe.get("monitorList", []):
            liste = hb.get("heartbeatList", {}).get(str(m["id"]), [])
            letzter = liste[-1] if liste else {}
            out.append({"name": m["name"], "status": letzter.get("status"), "ping": letzter.get("ping"),
                        "uptime": hb.get("uptimeList", {}).get(f'{m["id"]}_24')})
    return out

def backup():
    url = f"{PVE}/api2/json/nodes/{PVE_NODE}/tasks?typefilter=vzdump&limit=5"
    daten = json.loads(hol(url, headers={"Authorization": "PVEAPIToken=" + CONF["pve_token"]}, ctx=PVE_SSL))["data"]
    return [{"start": t.get("starttime"), "ende": t.get("endtime"), "status": t.get("status")} for t in daten]

def pihole_stats():
    q = pihole_get("/api/stats/summary")["queries"]
    return {"total": q["total"], "blocked": q["blocked"], "percent": q["percent_blocked"]}

class H(http.server.SimpleHTTPRequestHandler):
    def antwort(self, data, code=200, typ="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", typ)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        try:
            if self.path.startswith("/shelly/"):
                return self.antwort(hol(SHELLY + self.path[7:], timeout=3))
            if self.path == "/api/beszel":
                with lock: return self.antwort(json.dumps(beszel_systems()).encode())
            if self.path == "/api/pihole":
                with lock: return self.antwort(json.dumps(pihole_stats()).encode())
            if self.path == "/api/kuma":
                return self.antwort(json.dumps(kuma()).encode())
            if self.path == "/api/backup":
                return self.antwort(json.dumps(backup()).encode())
            if self.path == "/api/pihole/details":
                with lock: return self.antwort(json.dumps(pihole_details()).encode())
            if self.path.startswith("/api/beszel/verlauf/"):
                sid = self.path.rsplit("/", 1)[1]
                if not sid.isalnum(): return self.antwort(b'{"fehler":"id"}', 400)
                with lock: return self.antwort(json.dumps(beszel_verlauf(sid)).encode())
        except Exception as e:
            return self.antwort(json.dumps({"fehler": str(e)}).encode(), 502)
        super().do_GET()

    def log_message(self, *a):
        pass

http.server.ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("KIOSK_PORT", 8099))), H).serve_forever()
