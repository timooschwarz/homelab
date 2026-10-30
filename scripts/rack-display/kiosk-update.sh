#!/bin/bash
# Nummeriert alle Bilder/GIFs in /home/kiosk/screen durch und baut die Slideshow neu.
# Aufruf: kiosk-update [Sekunden pro Bild]   (Standard: 10)
DIR=/home/kiosk/screen
SEK=${1:-10}
NACHT_AB=22     # ab dieser Stunde schwarz
NACHT_BIS=10    # bis zu dieser Stunde schwarz
SHELLY=192.168.2.237   # Shelly Plug fürs Rack (Live-Watt unten rechts)
cd "$DIR" || exit 1
shopt -s nullglob nocaseglob extglob
files=( *.@(gif|jpg|jpeg|png|webp) )
[ ${#files[@]} -eq 0 ] && { echo "Keine Bilder in $DIR gefunden"; exit 1; }

i=0; tmp=()
for f in "${files[@]}"; do
  i=$((i+1)); ext="${f##*.}"; ext="${ext,,}"
  mv -- "$f" ".tmp_$i.$ext"; tmp+=(".tmp_$i.$ext")
done
liste=""; i=0
for f in "${tmp[@]}"; do
  i=$((i+1)); ext="${f##*.}"; neu=$(printf "%02d.%s" "$i" "$ext")
  mv -- "$f" "$neu"; liste+="\"$neu\","
done
liste="${liste%,}"

cat > index.html <<HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  html,body{margin:0;height:100%;background:#000;overflow:hidden;cursor:none}
  .slide{position:absolute;inset:0;opacity:0;transition:opacity 1s}
  .slide.on{opacity:1}
  .bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;filter:blur(30px) brightness(.45);transform:scale(1.15)}
  .fg{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}
  #watt{position:absolute;right:14px;bottom:12px;z-index:10;display:flex;align-items:center;gap:6px;
        padding:6px 14px 6px 10px;border-radius:999px;background:rgba(0,0,0,.55);color:#fff;
        font:600 22px/1 system-ui,sans-serif;letter-spacing:.5px;backdrop-filter:blur(6px)}
  #watt svg{width:18px;height:18px;fill:#facc15}
</style></head><body>
<div class="slide" id="a"><img class="bg"><img class="fg"></div>
<div class="slide" id="b"><img class="bg"><img class="fg"></div>
<div id="watt"><svg viewBox="0 0 24 24"><path d="M13 2 3 14h7l-1 8 10-12h-7z"/></svg><span id="wert">– W</span></div>
<script>
  const bilder   = [$liste];
  const sekunden = $SEK;
  const s = [document.getElementById("a"), document.getElementById("b")];
  const watt = document.getElementById("watt"), wert = document.getElementById("wert");
  let i = 0, k = 0;
  function nacht() { const h = new Date().getHours(); return h >= $NACHT_AB || h < $NACHT_BIS; }
  function zeige() {
    if (nacht()) {
      watt.style.display = "none";
      s.forEach(x => { x.classList.remove("on"); x.querySelectorAll("img").forEach(im => im.removeAttribute("src")); });
      return;
    }
    watt.style.display = "";
    if (i >= bilder.length) { location.reload(); return; }
    const cur = k, src = bilder[i++]; k = 1 - k;
    const fg = s[cur].querySelector(".fg");
    s[cur].querySelector(".bg").src = src;
    fg.onload = () => { s[cur].classList.add("on"); s[1 - cur].classList.remove("on"); };
    fg.src = src;
  }
  function strom() {
    if (nacht()) return;
    fetch("/shelly/rpc/Switch.GetStatus?id=0")
      .then(r => r.json())
      .then(d => { wert.textContent = Math.round(d.apower) + " W"; })
      .catch(() => { wert.textContent = "– W"; });
  }
  zeige(); strom();
  setInterval(zeige, sekunden * 1000);
  setInterval(strom, 5000);
</script>
</body></html>
HTML

chown -R kiosk:kiosk "$DIR"
echo "Fertig: $i Bilder, je $SEK Sekunden, Nachtmodus $NACHT_AB-$NACHT_BIS Uhr, Live-Watt von $SHELLY."
