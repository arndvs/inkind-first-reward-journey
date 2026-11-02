"""The three restaurant cards must render the same HTML after they stop nesting blocks.

golden/cards.json holds the output of the cards as they were before the change, for every case
below. Whitespace between tags is ignored, because removing the nested include leaves different
line breaks but no different markup.
"""
import json
import re
from pathlib import Path

import pytest

from build_previews import CONFIG
from fixtures import FEATURED, LONG_NAMES, NEARBY
from harness import render

GOLDEN = Path(__file__).resolve().parent / "golden" / "cards.json"
CARDS = ["ik_card_restaurant_feature", "ik_card_restaurant_compact", "ik_card_restaurant_row"]


def include(name):
    return "{{content_blocks.$" + "{" + name + "}}}"


def card_cases():
    return {
        "featured": FEATURED,
        "no-image": {**FEATURED, "image_url": None, "thumb_url": None},
        "no-cashback": {**FEATURED, "cashback_pct": None},
        "no-location": {**FEATURED, "location_id": None},
        "long-name": LONG_NAMES[0],
        "nearby-0": NEARBY[0],
        "nearby-1": NEARBY[1],
        "nearby-2": NEARBY[2],
        "nearby-no-photo": {**NEARBY[0], "image_url": None, "thumb_url": None},
        "nearby-image-only": {**NEARBY[0], "thumb_url": None},
    }


def normalize(html):
    return re.sub(r">\s+<", "><", html).strip()


def rendered(name, label, card):
    return normalize(render(CONFIG + include(name), {"card": card}))


def golden_keys():
    return [f"{name}|{label}" for name in CARDS for label in card_cases()]


def test_golden_covers_every_card_and_case():
    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    assert sorted(golden) == sorted(golden_keys())


@pytest.mark.parametrize("key", golden_keys())
def test_card_html_is_unchanged(key):
    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    name, label = key.split("|")
    assert rendered(name, label, card_cases()[label]) == golden[key]
