"""Tests for liquid/tools/braze_bundle.py: the files a person uploads to a Braze workspace by hand."""
import csv
import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

from harness import BLOCKS, LIQUID_DIR

TOOL = LIQUID_DIR / "tools" / "braze_bundle.py"
BUILD = LIQUID_DIR / "build" / "braze-bundle"


@pytest.fixture(scope="session")
def bundle():
    subprocess.run([sys.executable, str(TOOL)], check=True)
    return BUILD


def _load_tool():
    spec = importlib.util.spec_from_file_location("braze_bundle", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_bundle_covers_every_block(bundle):
    # Every live block, plus the one trial stub that stands in for ik_get_nearby.
    written = {p.read_text() for p in (bundle / "blocks").glob("*.liquid")}
    assert len(written) == len(BLOCKS) + 1


def test_no_relative_image_paths_survive(bundle):
    # Every file in the bundle, CSVs and guides included: Braze can't resolve ../images/ anywhere.
    for path in sorted(p for p in bundle.rglob("*") if p.is_file()):
        assert "../images/" not in path.read_text(encoding="utf-8"), path.relative_to(bundle)


def test_catalog_images_point_at_the_repo_images_and_exist(bundle):
    base = _load_tool().ASSET_BASE_URL
    with open(bundle / "restaurants.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        for field in ("image_url", "thumb_url"):
            url = row[field]
            assert url.startswith(base), (row["id"], field, url)
            assert (LIQUID_DIR / "images" / url[len(base):]).exists(), url


def test_catalog_csv_has_id_first_and_four_restaurants(bundle):
    with open(bundle / "restaurants.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    assert rows[0][0] == "id"
    assert rows[0][1:] == ["name", "location_id", "cuisine", "price", "rating",
                           "cashback_pct", "image_url", "thumb_url", "description"]
    assert len(rows) - 1 == 4
    assert {r[0] for r in rows[1:]} == {"r_101", "r_201", "r_214", "r_233"}


def _users(bundle):
    with open(bundle / "users_import.csv", newline="", encoding="utf-8") as f:
        return {row["external_id"]: row for row in csv.DictReader(f)}


def test_users_csv_follows_the_view_rules(bundle):
    users = _users(bundle)
    assert list(users)[0] == "u_1001"
    # whole dollars -> "25"; two decimals -> "12.50"; redeemed -> blank (no value sent)
    assert users["u_1001"]["first_reward_display"] == "25"
    assert users["u_1003"]["first_reward_display"] == "12.50"
    assert users["u_1002"]["first_reward_amount"] == ""
    assert users["u_1002"]["first_reward_display"] == ""
    assert users["u_1002"]["first_reward_min_spend"] == ""
    # never paid -> blank first_transaction_at; paid -> ISO 8601
    assert users["u_1001"]["first_transaction_at"] == ""
    assert users["u_1002"]["first_transaction_at"].startswith("2026-10-03T19:41")
    assert "u_9001" in users and users["u_9001"]["first_reward_amount"] == "0"
    assert "saved_restaurants" not in users["u_1001"]
    assert "email" not in " ".join(users["u_1001"].keys())


def test_guides_are_written_and_name_the_live_warning(bundle):
    checklist = (bundle / "CHECKLIST.md").read_text(encoding="utf-8")
    assert "Never launch" in checklist
    assert "restaurants" in checklist
    preview = (bundle / "PREVIEW_CASES.md").read_text(encoding="utf-8")
    for user in ["u_1001", "u_1003", "u_1002", "u_1005", "u_1008", "u_9001"]:
        assert user in preview
