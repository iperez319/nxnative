"""Join the compiled guide catalog to its reviewed tracking inventory."""

import csv
import json
from collections import Counter
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRACKING_KINDS = {"recorded", "collection", "estimate", "saved-state", "player-mark", "reference"}


def identity(row):
    if isinstance(row, dict):
        if "number" in row:
            return str(row["number"])
        return row["title"].partition(" · ")[0]
    return str(row).splitlines()[0]


def verify_printed_pickups(catalog):
    """Keep the independently reviewed printed pickup lists tied to compiled placements."""
    census = json.loads((HERE / "shield_guide_printed_pickups.json").read_text())
    rows = census["pickups"]
    assert len(rows) == 244 and len({row["id"] for row in rows}) == 244
    areas = {area["name"]: {row["key"] for row in area["activities"]} for area in catalog["areas"]}
    keys = set()
    for row in rows:
        assert row["pages"] and row["item"] and row["quantity"] > 0, row
        assert row["section"] in {"visible", "hidden"} and row["keys"], row
        assert set(row["keys"]) <= areas[row["area"]], row
        keys.update(row["keys"])
    assert len(keys) == 224 and len({row["area"] for row in rows}) == 28
    events = census["sideEvents"]
    all_keys = set().union(*areas.values())
    assert len(events) == 56 and len({row["id"] for row in events}) == 56
    assert len({row["location"] for row in events}) == 15
    for row in events:
        assert row["indexPage"] == 28 and row["walkthroughPage"] > 0 and row["keys"], row
        assert set(row["keys"]) <= all_keys, row
    print("PASS: 244 printed pickup rows map to 224 checklist IDs in 28 areas; all 56 side-index rows resolve", flush=True)


def verify_catalog(path, output=None):
    catalog = json.loads(path.read_text())
    tracking = json.loads((HERE / "shield_guide_tracking.json").read_text())
    rules = {}
    for family in tracking["activities"]:
        assert family["kind"] in TRACKING_KINDS and family["source"] and family["review"], family
        assert family["cadence"] in {"one-time", "repeatable", "possession", "daily", "respawn"}, family
        for key in family["keys"]:
            assert key not in rules, f"Duplicate tracking entry: {key}"
            rules[key] = {field: value for field, value in family.items() if field != "keys"}

    placement_areas = defaultdict(list)
    area_names = set()
    ordinary_encounters = 0
    for area in catalog["areas"]:
        name = area["name"]
        assert name not in area_names and area["directions"].strip(), name
        area_names.add(name)
        assert all(service.strip() for service in area["services"]), name
        ordinary_encounters += len(area["encounters"])
        keys = set()
        for activity in area["activities"]:
            key = activity["key"]
            assert key not in keys, f"Duplicate activity in {name}: {key}"
            assert key in rules, f"Unclassified activity in {name}: {key}"
            assert all(activity[field].strip() for field in ("title", "hint", "directions")), (name, key)
            assert activity["daily"] == (rules[key]["cadence"] == "daily"), (name, key)
            assert activity["accessWithoutSave"].strip(), (name, key)
            assert all(isinstance(index, int) and 0 <= index < 31 for index in activity["relatedAreas"]), (name, key)
            if activity["laterWithoutSave"]:
                assert activity["accessWithoutSave"].startswith("Access unknown"), (name, key)
            keys.add(key)
            placement_areas[key].append(name)
            activity["tracking"] = rules[key]
    assert not (rules.keys() - placement_areas.keys()), sorted(rules.keys() - placement_areas.keys())
    shared = {key: areas for key, areas in placement_areas.items() if len(areas) > 1}
    assert shared == tracking["sharedPlacements"], shared
    assert len(area_names) == 31 and ordinary_encounters == 74
    catalog["ordinaryEncounterTracking"] = {
        "kind": "reference", "source": "shield_guide_encounters.inc",
        "review": "Static Shield encounter groups by area and method.",
    }

    with (HERE / "shield_guide_detail_tracking.tsv").open() as file:
        detail_rules = list(csv.DictReader(file, delimiter="\t"))
    details = catalog["details"]
    families = [rule["family"] for rule in detail_rules]
    assert len(set(families)) == len(families) and set(families) == details.keys(), details.keys() ^ set(families)
    for rule in detail_rules:
        family = rule["family"]
        assert rule["kind"] in TRACKING_KINDS and rule["source"] and rule["review"], rule
        groups = details[family]
        assert len(groups) == int(rule["groups"]), (family, "groups", len(groups))
        assert sum(map(len, groups.values())) == int(rule["rows"]), (family, "rows", sum(map(len, groups.values())))
        rows_by_group = {}
        for group, rows in groups.items():
            ids = [identity(row) for row in rows]
            assert group.strip() and all(ids), (family, group)
            # Some clothing names and encounter labels recur in different rows.
            if family in {"alcremie", "galar-dex", "sparkle-spots", "raid-dens", "tm-case", "technical-records"}:
                assert len(set(ids)) == len(ids), (family, group, ids)
            if family == "alcremie":
                assert len(rows) == 9 and all("\n" in row for row in rows), group
            if family == "sparkle-spots":
                assert all(row["nearestDen"] > 0 and row["directions"].strip() for row in rows), group
            rows_by_group[group] = [
                {"row": index, "entry": row} for index, row in enumerate(rows, 1)
            ]
        details[family] = {"tracking": rule, "groups": rows_by_group}

    verify_printed_pickups(catalog)
    verify_reference(catalog)

    if output is not None:
        output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    placements = sum(map(len, placement_areas.values()))
    print(f"PASS: guide ledger covers {len(area_names)} areas, {len(rules)} activity keys, "
          f"{placements} placements and {len(details)} detail families", flush=True)


def verify_reference(catalog):
    rows = catalog['reference']
    reviewed = json.loads((HERE.parent / 'shield_guide_reference.json').read_text())
    assert rows == reviewed, 'Compiled handbook differs from reviewed content'
    assert len(rows) == 3085 and len({r['key'] for r in rows}) == len(rows)
    counts = Counter(r['category'] for r in rows)
    coverage = json.loads((HERE / 'shield_guide_reference_coverage.json').read_text())
    assert counts == coverage['categoryCounts']
    assert len(coverage['families']) == 24
    assert len({family['family'] for family in coverage['families']}) == 24
    assert set().union(*(set(family['categories']) for family in coverage['families'])) == counts.keys()
    assert all(family['pages'] and family['categories'] for family in coverage['families'])
    required = {'Moves': 547, 'Abilities': 196, 'Items': 375, 'Natures': 25,
                'Characteristics': 30, 'EV yields': 400, 'Egg Groups': 400,
                'Type matchups': 18, 'Move priority': 12, 'Max moves': 19, 'G-Max moves': 23,
                'Rental teams': 30, 'Tournament teams': 30, 'Tournament prizes': 30,
                'Poké Job offerings': 157, 'Poké Job tiers': 10, 'Pickup': 30,
                'Berry trees': 29, 'Berry flavors': 53, 'Cooking ingredients': 25,
                'Friendship tiers': 8, 'Curry quality': 5, 'NPC camps': 8,
                'Card backgrounds': 66, 'Card effects': 20, 'Card frames': 20,
                'Card expressions': 30, 'Card poses': 20, 'Card coatings': 9,
                'Salon choices': 69, 'Shops': 174, 'Ribbons and Marks': 49,
                'Digging Duo — skill brother': 21, 'Digging Duo — stamina brother': 31,
                'Hikers': 13, 'Fishers': 7}
    for category, count in required.items():
        assert counts[category] == count, (category, counts[category], count)
    assert len(counts) == 50
    def entry(category, title):
        matches = [r for r in rows if r['category'] == category and r['title'] == title]
        assert len(matches) == 1, (category, title)
        return matches[0]['body']
    assert 'Power: 20' in entry('Moves', 'Absorb')
    assert 'PP: 5' in entry('Moves', 'Dynamax Cannon')
    assert 'PP: 5' in entry('Moves', 'Pyro Ball')
    assert 'Ghost: 0×' in entry('Type matchups', 'Normal attacks')
    assert 'Fairy: 0×' in entry('Type matchups', 'Dragon attacks')
    assert 'Sp. Atk +3' in entry('EV yields', '380 — Charizard')
    assert 'Undiscovered' in entry('Egg Groups', '400 — Eternatus')
    assert 'Sp. Def +1' in entry('EV yields', '236 — Corsola')
    assert 'Attack +1' in entry('EV yields', '182 — Meowth')
    assert 'Female Indeedee' in entry('EV yields', '337 — Indeedee')
    assert 'Male Indeedee awards Sp. Atk +2' in entry('EV yields', '337 — Indeedee')
    assert '¥200' in entry('Shops', 'Common Mart — Antidote')
    assert 'Unlock: 8 badges' in entry('Shops', 'Common Mart — Full Restore')
    assert 'Attack, Speed' in entry('Rental teams', 'Basic — Cinderace')
    assert 'Sp. Atk, Speed' in entry('Rental teams', 'Basic — Togekiss').replace('Sp. Attack', 'Sp. Atk')
    assert 'Zacian' in entry('Tournament teams', 'Hop — Grookey chosen')
    assert 'Zamazenta' not in entry('Tournament teams', 'Hop — Grookey chosen')
    for category in ('EV yields', 'Egg Groups'):
        assert {int(r['title'].split(' — ')[0]) for r in rows if r['category'] == category} == set(range(1, 401))
    for row in rows:
        assert all(row[field].strip() for field in ('key', 'category', 'title', 'body', 'citation')), row
        assert 'Official Sword/Shield guide, pp.' in row['citation'], row
        assert not any(s in row['body'] for s in ('<img', 'data-bbox', '![](', '**')), row
    for row in [r for r in rows if r['category'] == 'Type matchups']:
        assert len([line for line in row['body'].splitlines() if ': ' in line and line.endswith('×')]) == 18
    print(f'PASS: {len(rows)} compiled handbook entries in {len(counts)} categories; all encyclopedia and service inventories accounted for', flush=True)
