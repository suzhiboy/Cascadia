"""Fetch fixed component facts and an openly licensed Chinese font."""
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Cascadia-development"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()

source = get("https://cascadiagame.github.io/js/data.js").decode()
records = []
mapping = {"mountain":"mountain", "forest":"forest", "desert":"prairie", "swamp":"wetland", "lake":"river"}
for block in re.findall(r"\{([^{}]+)\}", source):
    number = int(re.search(r"tileNum:\s*'(\d+)'", block)[1])
    habitats = re.findall(r"'([^']+)'", re.search(r"habitats:\s*\[([^]]+)\]", block)[1])
    animals = re.findall(r"'([^']+)'", re.search(r"wildlife:\s*\[([^]]+)\]", block)[1])
    rotation = int(re.search(r"rotation:\s*(\d+)", block)[1]) // 60
    records.append({"id":number, "habitats":[mapping[h] for h in habitats], "wildlife":animals, "rotation":rotation})
assert len(records) == 100
(ROOT / "data/tiles.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
print("Fixed component catalog: 85 habitat tiles and 5 starter trios")
font = ROOT / "assets/fonts/NotoSansSC.ttf"
if not font.exists():
    font.write_bytes(get("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"))
    (font.parent / "OFL.txt").write_bytes(get("https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/OFL.txt"))
print("Chinese font ready")
