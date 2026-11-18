"""Write minimal, original Shield-format snapshots for the Apple guide tests."""

from pathlib import Path
from hashlib import sha256
from struct import iter_unpack, pack, pack_into

# Fixed on-disk format constants.
HASH_PREFIX = bytes.fromhex(
    "9ec99cd70ed33c44fb9303dceb39b42a"
    "1947e9634ba2334416bf82a2ba6355b6"
    "3d9df24b5f7b6ab2621dc21b68e5c8b5"
    "3a059000e8a8103de2ecf00cb2ed4f6d"
)
HASH_SUFFIX = bytes.fromhex(
    "d6c01c598bc8b8cb46e153fc828c7575"
    "13e045df32693c75f059f8d9a25fb217"
    "e08052dbea8973997579afcb2e8007e6"
    "f126e0030ae66ff641bf7e59c2ae55fd"
)
FILE_MASK = bytes.fromhex(
    "a092d10607db32a1ae01f5c51e844fe3"
    "53ca37f4a7b04da018b7c297da5f532b"
    "75fa4816f8d48a6f6105f4e2fd04b5a3"
    "0ffc4492cb32e61bb9b12e01b0565336"
    "d2d1503dde5b2e0e52fddf2f7bca6350"
    "a4675d2317c052e1a6307c2bb670365b"
    "2a276933f5637b363f269ba3ed7a5300"
    "a448b3509e14a052de7e102b1b776e"
)

PARTY, BOXES, BAG, DEX = 0x2985FE5D, 0x0D66012C, 0x1177C2C4, 0x4716C404
SLOT_SIZE = 0x158
TRAINER = bytearray(0x110)
TRAINER[0xA4] = 45  # Shield
TRAINER[0xB0:0xB8] = "Test".encode("utf-16-le")


def next_word(word):
    word ^= (word << 2) & 0xFFFFFFFF
    word ^= word >> 15
    return word ^ ((word << 13) & 0xFFFFFFFF)


def encode_block(key, value):
    if isinstance(value, bool):
        payload = bytes([2 if value else 1])
    elif isinstance(value, int):
        payload = pack("<BI", 10, value)
    else:
        payload = pack("<BI", 4, len(value)) + value
    word = key
    for bit in bin(key):
        if bit == "1":
            word = next_word(word)
    encoded = bytearray(pack("<I", key))
    for offset, byte in enumerate(payload):
        encoded.append(byte ^ ((word >> (8 * (offset % 4))) & 0xFF))
        if offset % 4 == 3:
            word = next_word(word)
    return encoded


def snapshot(blocks):
    blocks = {0xF25C070E: TRAINER, **blocks}
    body = b"".join(encode_block(key, blocks[key]) for key in sorted(blocks))
    masked = bytes(byte ^ FILE_MASK[i % len(FILE_MASK)] for i, byte in enumerate(body))
    return masked + sha256(HASH_PREFIX + masked + HASH_SUFFIX).digest()


def pokemon(species, *, form=0, held=0, egg=False, level=0, location=0, corrupt=False):
    slot = bytearray(SLOT_SIZE)
    pack_into("<HH", slot, 8, species, held)
    slot[0x24] = form
    slot[0x8F] = 0x40 if egg else 0
    slot[0xDE] = 45
    slot[0xF8:0x100] = TRAINER[0xB0:0xB8]
    pack_into("<HBB", slot, 0x122, location, 4, level)
    words = [word for (word,) in iter_unpack("<H", slot[8:0x148])]
    pack_into("<H", slot, 6, (sum(words) + corrupt) & 0xFFFF)
    # Selector 1 swaps the last two 80-byte chunks.
    seed = 1 << 13
    pack_into("<I", slot, 0, seed)
    words[80:160] = words[120:160] + words[80:120]
    for i, word in enumerate(words):
        seed = (seed * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
        pack_into("<H", slot, 8 + 2 * i, word ^ (seed >> 16))
    return slot


def place(slots, index, **fields):
    start = index * SLOT_SIZE
    slots[start:start + SLOT_SIZE] = pokemon(**fields)


def inventory(entries):
    bag = bytearray(0x12F8)
    for offset, item, quantity in entries:
        pack_into("<I", bag, offset, item | (quantity << 15))
    return bag


def dex(*registered):
    entries = bytearray(400 * 0x30)
    for number in registered:
        entries[(number - 1) * 0x30 + 0x20] = 1
    return entries


def opening_fixtures(write):
    map_data = bytearray(0x6008)
    pack_into("<Q", map_data, 0x6000, 0x9A3DF7D37DB70B41)
    for name, phase, guidance, zone in (
        ("early", 200, 200, 0xE80BCEC03B7D6E23),
        ("later", 270, 250, 0x10355EFF1F4DB0B5),
        ("superseded", 250, 240, 0xE80BCEC03B7D6E23),
    ):
        taken = name == "later"
        write(name, {
            0x16AAA7FA: map_data, 0x7BE8A4C6: pack("<QQQQ", 0, zone, 0, 0),
            0xBB7B57FB: phase, 0xC4F35C2E: guidance, 0xED6E814D: phase != 200,
            0xA6C76681: taken,  # Route 1 Potion
        })


def gym_fixtures(write):
    missions = (0x9203329A, 0x890D1CF9, 0x626D6B24, 0x3148B754,
                0x5B946783, 0xDF3DB17F, 0xC28A76F1, 0x143E0946)
    badges = (0x299E4801, 0xFF80169D, 0x7F29D95E, 0x71BFDED1,
              0x8BCBBCDE, 0xFE5A7D5F, 0xC90B46C2, 0x375FD6A8)
    for name, phase, score in (
        ("missions", 785, 0), ("badges", 785, 0), ("mixed", 790, 6),
        ("fire-score", 785, 3), ("fire-target", 785, 6),
        ("champion", 3000, 0), ("tournament", 3000, 0),
    ):
        blocks = {0xBB7B57FB: phase, 0x32C4F443: score,
                  0x4DBE8A87: name == "champion", 0x26FE3E7E: int(name == "tournament")}
        for i, (mission, badge) in enumerate(zip(missions, badges)):
            blocks[mission] = name in ("champion", "missions") or (name == "mixed" and i % 2 == 0)
            blocks[badge] = name in ("champion", "badges") or (name == "mixed" and i % 2 == 1)
        write(name, blocks)


def postgame_fixtures(write):
    stadiums = (0x3A68EA36, 0x3A6B2A3F, 0x3F680229, 0x3F64E8A0, 0x3F6D5BBB, 0x3F6A4232)
    album = bytearray(31 * 8)
    for index in (1, 5, 7, 9, 13, 15, 19, 21, 23, 29):
        album[index * 8] = 1
    for name, phase, outcomes in (
        ("counter-and-cards", 10000, (0,) * 6),
        ("in-progress", 3060, (100, 1, 99, 101, 0, 0)),
        ("resolved", 3100, (100,) * 6),
        ("restored", 3051, (1,) * 6),
    ):
        resolved = name == "resolved"
        blocks = dict(zip(stadiums, outcomes))
        blocks.update({0xBB7B57FB: phase, 0xA8067616: 4, 0xB1C26FB0: album,
                       0x37AFE5F0: resolved, 0xE4136279: resolved})
        if resolved:
            party = bytearray(6 * SLOT_SIZE + 4)
            party[6 * SLOT_SIZE] = 1
            place(party, 0, species=890, level=60, location=66)
            boxes = bytearray(960 * SLOT_SIZE)
            place(boxes, 959, species=889, level=70, location=66)
            blocks.update({PARTY: party, BOXES: boxes})
        if resolved or name == "restored":
            blocks[DEX] = dex(399, 400)
        write(name, blocks)


def cafe_fixtures(write):
    for name, rolls in (
        ("split", (1, 72, 100)), ("boundaries", (5, 80, 72)),
        ("invalid", (6, 0, 101)), ("missing", (0, 0, 101)),
        ("restored", (96, 1, 99)),
    ):
        blocks = {}
        for i, (roll_key, flag_key) in enumerate(zip(
            (0x24F1FCA2, 0x24F1FAEF, 0x24F1F93C), (0x3E2EF9CC, 0x3E2EFEE5, 0x3E2EFD32)
        )):
            if i != 0 or name != "missing":
                blocks[roll_key] = rolls[i]
                blocks[flag_key] = i == 0 and name != "restored"
        write(name, blocks)


def gift_fixtures(write):
    flags = {0xAA077C03: True}  # Soothe Bell interaction
    # A synthetic occupied general pocket with no Soothe Bell entry.
    occupied = [(offset, 2000 + index, 1) for index, offset in enumerate(range(0x2F8, 0x0B90, 4))]
    write("full-bag", {**flags, BAG: inventory(occupied)})
    write("alternate-item-only", {BAG: inventory([(0x2F8, 218, 1)])})
    party = bytearray(6 * SLOT_SIZE + 4)
    party[6 * SLOT_SIZE] = 1
    place(party, 0, species=821, held=218)
    write("held-gift", {**flags, PARTY: party})


def hop_fixtures(write):
    for name, phase, flag in (
        ("missing", 1, None), ("initial", 1, False), ("postponed", 115, False),
        ("lost", 120, False), ("won", 120, True), ("later", 270, True),
    ):
        blocks = {0xBB7B57FB: phase}
        if flag is not None:
            blocks[0x598B8A31] = flag
        write(name, blocks)


def route2_hop_fixtures(write):
    for name, phase, flag in (
        ("missing", 290, None), ("initial", 250, False), ("postponed", 285, False),
        ("lost", 290, False), ("won", 290, True), ("later", 350, True),
    ):
        # A recorded Postwick victory is independent of the Route 2 result.
        blocks = {0xBB7B57FB: phase, 0x598B8A31: True}
        if flag is not None:
            blocks[0x12277F11] = flag
        write(name, blocks)


def field_trainer_fixtures(write):
    trainers = {
        "galar-mine.trainer-georgia": ['TRID_WORKERF_02'],
        "galar-mine.trainer-keith": ['TRID_WORKERM_01'],
        "galar-mine.trainer-russel": ['TRID_WORKERM_02'],
        "galar-mine.trainer-sandra": ['TRID_WORKERF_01'],
        "glimwood.trainer-derek": ['TRID_CHEF_02'],
        "glimwood.trainer-judy": ['TRID_MADAM_02'],
        "glimwood.trainer-robert": ['TRID_WKIMODAMESHI_01', 'TRID_WKIMODAMESHI_02'],
        "mine2.trainer-francis": ['TRID_WORKERM_03'],
        "mine2.trainer-vincent": ['TRID_RAILROADMAN_01'],
        "mine2.trainer-yvonne": ['TRID_WORKERF_03'],
        "outskirts.trainer-caroline": ['TRID_MADAM_01'],
        "outskirts.trainer-raymond": ['TRID_POLICE_01'],
        "route10.trainer-donald": ['TRID_YAMAOTOKO_02'],
        "route10.trainer-douglas": ['TRID_YAMAOTOKO_01'],
        "route10.trainer-geoffrey": ['TRID_DRIBER_02'],
        "route10.trainer-gillian": ['TRID_WREPORTERS01_03', 'TRID_WREPORTERS01_04'],
        "route10.trainer-glenn": ['TRID_GENTLEMAN_01'],
        "route10.trainer-graham": ['TRID_DOCTER_02'],
        "route10.trainer-harper": ['TRID_POSTMAN_02'],
        "route10.trainer-ronald": ['TRID_BUSINESS_01'],
        "route2.benjamin": ['TRID_TANPAN_02'],
        "route2.jake": ['TRID_TANPAN_01'],
        "route2.lauren": ['TRID_MINI_01'],
        "route3.trainer-hannah": ['TRID_SCHOOLF_01'],
        "route3.trainer-kayleigh": ['TRID_SCHOOLF_02'],
        "route3.trainer-marvin": ['TRID_SCHOOLM_01'],
        "route3.trainer-peter": ['TRID_SCHOOLM_02'],
        "route3.trainer-rei": ['TRID_MINI_02'],
        "route3.trainer-tad": ['TRID_POSTMAN_01'],
        "route4.trainer-bradley": ['TRID_BREEDERM_02'],
        "route4.trainer-jaime": ['TRID_BREEDERM_01'],
        "route4.trainer-mia": ['TRID_GOKKOF_01'],
        "route4.trainer-rhys": ['TRID_GOKKOM_02'],
        "route4.trainer-shane": ['TRID_GOKKOM_01'],
        "route4.trainer-sunny": ['TRID_GOKKOF_02'],
        "route5.trainer-adrian": ['TRID_BREEDERM_03'],
        "route5.trainer-debra": ['TRID_BREEDERF_01'],
        "route5.trainer-denise": ['TRID_BREEDERF_02'],
        "route5.trainer-gabrielle": ['TRID_OL_01'],
        "route5.trainer-gillian": ['TRID_WREPORTERS01_01', 'TRID_WREPORTERS01_02'],
        "route5.trainer-stuart": ['TRID_CHEF_01'],
        "route6.trainer-anita": ['TRID_ADULTGIRL_01'],
        "route6.trainer-diane": ['TRID_BACKPACKER_01'],
        "route6.trainer-duncan": ['TRID_ARTIST_01'],
        "route6.trainer-iwan": ['TRID_WDOCTERS_01', 'TRID_WDOCTERS_02'],
        "route6.trainer-nicola": ['TRID_MODEL_01'],
        "route6.trainer-ruth": ['TRID_BACKPACKER_02'],
        "route7.trainer-bruce": ['TRID_DRIBER_01'],
        "route7.trainer-caden": ['TRID_GENTLEMAN_02'],
        "route7.trainer-mila": ['TRID_MODEL_02'],
        "route8.trainer-barbara": ['TRID_BACKPACKER_03'],
        "route8.trainer-bobby": ['TRID_POLICE_02'],
        "route8.trainer-charles": ['TRID_MUSICIAN_01'],
        "route8.trainer-joanna": ['TRID_NURSE_01'],
        "route8.trainer-jordan": ['TRID_WCOLLEAGUE_01', 'TRID_WCOLLEAGUE_02'],
        "route9.trainer-carter": ['TRID_KARATE_02'],
        "route9.trainer-harriet": ['TRID_ANGLER_01'],
        "route9.trainer-jacob": ['TRID_KAIPAN_02'],
        "route9.trainer-layla": ['TRID_BIKINI_02'],
        "route9.trainer-logan": ['TRID_KAIPAN_01'],
        "route9.trainer-marina": ['TRID_ANGLER_02'],
        "route9.trainer-owen": ['TRID_WMUSICUNIT_01', 'TRID_WMUSICUNIT_02'],
        "route9.trainer-reece": ['TRID_KARATE_01'],
        "route9.trainer-scarlett": ['TRID_BIKINI_01'],
        "route9.trainer-zoe": ['TRID_DANCER_01'],
    }

    def trainer_flag(name):
        value = 0xCBF29CE484222645
        for byte in name.encode("ascii"):
            value = ((value ^ byte) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
        return value & 0xFFFFFFFF

    flags = {key: [trainer_flag(name) for name in names] for key, names in trainers.items()}
    # Later story phase and a different battle win provide no field Trainer flag.
    unrelated = {0xBB7B57FB: 9999, 0x12277F11: True}
    write("missing", unrelated)
    write("lost", {**unrelated, **{flag: False for group in flags.values() for flag in group}})
    write("wrong-type", {**unrelated, **{flag: 1 for group in flags.values() for flag in group}})
    for key, group in flags.items():
        write(key, {**unrelated, **{flag: True for flag in group}})
        if len(group) == 2:
            write(key + "-primary", {group[0]: True})
            write(key + "-partner", {group[1]: True})
    write("all", {flag: True for group in flags.values() for flag in group})
    write("restored", {flag: False for group in flags.values() for flag in group})


def daily_tracking_fixtures(write):
    used = {
        0x3E2EF9CC: True, 0x3E2EFEE5: True, 0x3E2EFD32: True,
        0x87C05A15: True, 0x51FA4131: True, 0x4CBC0D12: True,
        0xC5244701: True, 0x29F6FFF4: True, 0xD902B576: True,
        0xFC997003: False, 0x6C3B5E62: 9,
    }
    write("used", used)
    write("restored", {})
    for name, request in (("missing-request", None), ("zero-request", 0),
                          ("invalid-request", 11), ("wrong-type-request", True)):
        blocks = used.copy()
        blocks.pop(0x6C3B5E62)
        if request is not None:
            blocks[0x6C3B5E62] = request
        write(name, blocks)
    write("missing-outcome", {key: value for key, value in used.items() if key != 0xFC997003})
    write("wrong-type-outcome", {**used, 0xFC997003: 0})


def ambiguous_event_fixtures(write):
    boxes = bytearray(960 * SLOT_SIZE)
    place(boxes, 0, species=79, form=1, level=12, location=16)
    place(boxes, 1, species=867)  # Ownership cannot identify the arch evolution.
    place(boxes, 2, species=840, held=239)
    records = bytearray(50 * 4)
    for index in (43, 47, 48):
        pack_into("<i", records, index * 4, 99)
    for progress in (1, 2):
        write(str(progress), {
            BOXES: boxes, 0x37DA95A3: records, 0xBB7B57FB: 9999,
            0xCC45DA54: progress, 0xFFC34A5B: True, 0xFFC33E76: True,
            0x3F9F43F1: True, 0xD8BFA59C: True, 0x4DBE8A87: True,
            0x68DE4CD2: 2, 0x8AD859BF: 2,
            BAG: inventory([(0x2F8, 239, 1), (0x2FC, 249, 1), (0x300, 243, 1)]),
        })
    write("restored", {})


def tea_fixtures(write):
    bag = inventory([(0x2F8, 1253, 0), (0x2FC, 1254, 2), (0x300, 1254, 1),
                     (0xB90, 1253, 9), (0x11F8, 1254, 6)])
    party = bytearray(6 * SLOT_SIZE + 4)
    boxes = bytearray(960 * SLOT_SIZE)
    write("dex-only", {BAG: bag, PARTY: party, BOXES: boxes, DEX: dex(336)})
    party[6 * SLOT_SIZE] = 1
    place(party, 0, species=854)
    place(party, 1, species=855, form=1)  # Inactive party slot
    place(boxes, 0, species=854, form=1, held=1253)
    place(boxes, 1, species=855, form=2)
    place(boxes, 2, species=855, form=1, egg=True)
    place(boxes, 3, species=855, form=1, corrupt=True)
    write("ready", {BAG: bag, PARTY: party, BOXES: boxes})
    write("no-bag", {PARTY: party, BOXES: boxes})
    write("no-boxes", {BAG: bag, PARTY: party})
    place(boxes, 32, species=855)
    write("one-evolved", {BAG: bag, PARTY: party, BOXES: boxes})
    place(boxes, 959, species=855, form=1)
    write("both-evolved", {BAG: bag, PARTY: party, BOXES: boxes})
    write("restored", {BAG: bytearray(0x12F8), PARTY: bytearray(len(party)), BOXES: bytearray(len(boxes))})


def presentation_fixtures(write):
    write("unknown", {})
    write("locked", {0x7526A53C: False, 0x4DBE8A87: False, BAG: bytearray(0x12F8), 0x4584784A: 0})
    write("ready", {0x7526A53C: True, 0x4DBE8A87: True,
                    BAG: inventory([(0x11F8, 1266, 1)]), 0x4584784A: 2})
    write("delivered", {0x4584784A: 3})
    write("wrong-types", {0x7526A53C: 1, 0x4DBE8A87: 1, 0x4584784A: True})
    write("invalid-letter", {0x4584784A: 100})


def rehearsal_fixtures(write):
    # Original inputs exercise existing contracts; these are not gameplay captures.
    for stage in (1, 2, 3):
        write(f"minccino-{stage}", {0xAA86248B: stage})
    for stage in (2, 3, 4):
        write(f"letter-{stage}", {0x4584784A: stage})
    for name, mission, badge in (("retry", False, False), ("mission", True, False), ("badge", True, True)):
        write(f"ice-{name}", {0xBB7B57FB: 1240, 0xDF3DB17F: mission, 0xFE5A7D5F: badge})
    for name, state in (("waiting", 2), ("respawned", 1)):
        hidden = bytearray(0x810)
        pack_into("<I", hidden, 101 * 4, state)  # Rolling Fields Tiny Mushroom spot.
        write(f"sparkle-{name}", {0x6148F6AC: hidden})


def write_fixtures(root):
    root.mkdir(parents=True, exist_ok=True)
    (root / "release-journeys.json").write_bytes(Path(__file__).with_name("shield_guide_release_journeys.json").read_bytes())
    for family, generate in (
        ("rehearsal", rehearsal_fixtures), ("presentation", presentation_fixtures), ("monitor", opening_fixtures), ("gyms", gym_fixtures), ("postgame", postgame_fixtures),
        ("cafe-prizes", cafe_fixtures), ("gifts", gift_fixtures), ("first-hop", hop_fixtures),
        ("route2-hop", route2_hop_fixtures), ("field-trainers", field_trainer_fixtures), ("daily-tracking", daily_tracking_fixtures), ("ambiguous-events", ambiguous_event_fixtures), ("tea-evolutions", tea_fixtures),
    ):
        folder = root / family
        folder.mkdir(parents=True, exist_ok=True)

        def write(name, blocks):
            (folder / name).write_bytes(snapshot(blocks))

        generate(write)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    write_fixtures(parser.parse_args().output)
