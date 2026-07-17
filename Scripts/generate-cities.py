#!/usr/bin/env python3
"""Build the bundled city database from the GeoNames cities15000 dataset.

GeoNames (https://www.geonames.org/) is licensed CC BY 4.0 — attribution is in
README.md. This runs at development time only; the produced cities.json is
bundled so the app never needs network access.

Usage: python3 Scripts/generate-cities.py <cities15000.txt> <output.json>
"""
import sys, json, csv

src, out = sys.argv[1], sys.argv[2]

# GeoNames tab-separated columns
NAME, ASCII, LAT, LON = 1, 2, 4, 5
FEATURE_CODE, COUNTRY = 7, 8
POPULATION, DEM, TIMEZONE = 14, 16, 17

WORLD_MIN_POP = 500_000   # major world cities
CAPITAL_CODES = {"PPLC"}   # national capitals (kept regardless of population)

rows = []
with open(src, encoding="utf-8") as f:
    for c in csv.reader(f, delimiter="\t"):
        if len(c) < 18:
            continue
        country = c[COUNTRY]
        try:
            pop = int(c[POPULATION] or 0)
        except ValueError:
            pop = 0
        is_id = country == "ID"
        is_capital = c[FEATURE_CODE] in CAPITAL_CODES
        # Keep: every Indonesian city, plus major/capital cities elsewhere.
        if not (is_id or pop >= WORLD_MIN_POP or is_capital):
            continue
        try:
            alt = int(c[DEM]) if c[DEM] not in ("", "-9999") else 0
        except ValueError:
            alt = 0
        rows.append({
            "name": c[NAME] or c[ASCII],
            "country": country,
            "lat": round(float(c[LAT]), 4),
            "lon": round(float(c[LON]), 4),
            "alt": alt,
            "tz": c[TIMEZONE],
            "_pop": pop,
        })

# Dedupe by (name, country), keep the most populous.
best = {}
for r in rows:
    key = (r["name"], r["country"])
    if key not in best or r["_pop"] > best[key]["_pop"]:
        best[key] = r

cities = list(best.values())
# Indonesia first, then by population desc — nicer default ordering in search.
cities.sort(key=lambda r: (r["country"] != "ID", -r["_pop"], r["name"]))
for r in cities:
    del r["_pop"]

json.dump(cities, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
id_count = sum(1 for r in cities if r["country"] == "ID")
print(f"{len(cities)} cities ({id_count} Indonesia, {len(cities) - id_count} world) -> {out}")
