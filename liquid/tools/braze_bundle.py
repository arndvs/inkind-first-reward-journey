"""Builds the files a person uploads to a Braze workspace by hand.

Output: liquid/build/braze-bundle/ (git-ignored). Run from the repo root:

    python liquid/tools/braze_bundle.py

Image paths in the Liquid point at ../images/. Braze can't read those, so they are
rewritten to ASSET_BASE_URL, which defaults to this repo's raw GitHub images folder.
"""
import csv
import os
import shutil
import sys
from pathlib import Path

LIQUID_DIR = Path(__file__).resolve().parent.parent
BLOCKS_DIR = LIQUID_DIR / "blocks"
MESSAGES_DIR = LIQUID_DIR / "messages"
OUT = LIQUID_DIR / "build" / "braze-bundle"

ASSET_BASE_URL = os.environ.get(
    "ASSET_BASE_URL",
    "https://raw.githubusercontent.com/arndvs/inkind-first-reward-journey/main/liquid/images/",
)

LAYER_ORDER = ["config", "logic", "layout", "elements", "components", "sections"]


def rewrite_assets(text):
    return text.replace("../images/", ASSET_BASE_URL)


def build_blocks(out):
    blocks_out = out / "blocks"
    blocks_out.mkdir(parents=True)
    paths = sorted(BLOCKS_DIR.glob("*/*.liquid"), key=lambda p: (LAYER_ORDER.index(p.parent.name), p.name))
    for number, path in enumerate(paths, start=1):
        name = path.stem
        target = blocks_out / f"{number:02d}_{name}.liquid"
        target.write_text(rewrite_assets(path.read_text(encoding="utf-8")) + "\n", encoding="utf-8")
    return len(paths)


def build_email_body(out):
    source = MESSAGES_DIR / "first_reward.email.liquid"
    (out / "email_body.liquid").write_text(rewrite_assets(source.read_text(encoding="utf-8")) + "\n", encoding="utf-8")


CATALOG_FIELDS = ["name", "location_id", "cuisine", "price", "rating", "cashback_pct",
                  "image_url", "thumb_url", "description"]


# Catalog keys used by sql/00_sample_data.sql and the Liquid fixtures. Each key maps to the
# fixture restaurant with the same location, so names and images can't drift from the tests.
CATALOG_KEYS = {
    "r_101": "demo-101",
    "r_201": "demo-201",
    "r_214": "demo-202",
    "r_233": "demo-203",
}


def catalog_rows():
    sys.path.insert(0, str(LIQUID_DIR / "tests"))
    from fixtures import FEATURED, NEARBY
    by_location = {FEATURED["location_id"]: FEATURED}
    by_location.update({item["location_id"]: item for item in NEARBY})
    return [(key, by_location[location]) for key, location in CATALOG_KEYS.items()]


def build_catalog(out):
    with open(out / "restaurants_catalog.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(["id"] + CATALOG_FIELDS)
        for key, item in catalog_rows():
            writer.writerow([key] + [item.get(field, "") for field in CATALOG_FIELDS])


SAMPLE_SQL = LIQUID_DIR.parent / "sql" / "00_sample_data.sql"


def _sql_tuples(section):
    """Rows of the VALUES block after `section`, as lists of raw SQL literals."""
    text = SAMPLE_SQL.read_text(encoding="utf-8")
    body = text.split(section, 1)[1].split(";", 1)[0]
    rows = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("("):
            cells = [c.strip().strip("'") for c in line.strip("(),").split(",")]
            rows.append(cells)
    return rows


def _display(amount):
    value = float(amount)
    return str(int(value)) if value == int(value) else f"{value:.2f}"


def build_users(out):
    """One row per sample user, with what braze_first_reward_attributes would send."""
    users = [r[0] for r in _sql_tuples("INSERT INTO users VALUES")]
    rewards = {r[1]: r for r in _sql_tuples("INSERT INTO rewards VALUES")}
    txns = {}
    for row in _sql_tuples("INSERT INTO transactions VALUES"):
        if row[1] not in txns or row[4] < txns[row[1]][4]:
            txns[row[1]] = row
    fields = ["external_id", "first_reward_amount", "first_reward_display",
              "first_reward_min_spend", "first_transaction_at"]
    with open(out / "users_import.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        writer.writerow(fields)
        for user in users:
            reward = rewards.get(user)
            redeemed = reward is not None and reward[5] != "NULL"
            amount = "" if (reward is None or redeemed) else reward[3]
            display = "" if amount == "" else _display(amount)
            minimum = "" if (reward is None or redeemed or reward[4] == "NULL") else _display(reward[4])
            paid = txns.get(user)
            first_paid = "" if paid is None else paid[4].replace(" ", "T") + "Z"
            writer.writerow([user, amount, display, minimum, first_paid])
        writer.writerow(["u_9001", "0", "0", "50", ""])


PREVIEW_CASES = """# Expected Braze preview results

Preview each user in the Braze composer with "Preview as". Expected output:

| User | Expected |
|---|---|
| u_1001 | "$25 toward a $50+ meal". No saved restaurant on the profile and no live recommendations endpoint, so the Explore fallback |
| u_1003 | "$12.50". If it shows "$12.5", the CSV import typed first_reward_display as a number. Record that as a finding (the warehouse sends it as a JSON string) |
| u_1002 | Abort: no unused reward |
| u_1005 | Abort: no unused reward |
| u_1008 | Abort: reward minimum missing |
| u_9001 | Abort: reward amount is zero |
| Saved-restaurant card | Needs saved_restaurants or Canvas context, which CSV import can't set. Try "Preview as, Custom user" with saved_restaurants = ["r_101"]. If the preview won't take an array, the card can't be rendered in this workspace. Note it in the checklist; don't change the message |
"""

CHECKLIST = """# Braze Live workspace: manual steps, in order

Never launch a campaign or Canvas in the Live workspace. Preview, and send tests to your own address only.

1. **Create the Catalog** named exactly `restaurants`, from `restaurants_catalog.csv`. The name can't be changed after launch.
2. **Create one Content Block per file in `blocks/`.** Name each block exactly as the file name without its number prefix (for example `01_ik_brand.liquid` becomes `ik_brand`). Names can't be changed after launch.
3. **Import users** from `users_import.csv`. Columns are external_id and the four first_reward fields. There are no emails and no saved_restaurants column; CSV import can't set arrays.
4. **Preview** u_1001, u_1003, u_1002, u_1005, u_1008 and u_9001 against `PREVIEW_CASES.md`. Record anything that differs.
5. **Keep "Auto-approve actions" off** in the BrazeAI Operator panel.
6. **Record findings** in the repo's README, including the display-type and saved_restaurants results.
"""


def build_guides(out):
    (out / "PREVIEW_CASES.md").write_text(PREVIEW_CASES, encoding="utf-8")
    (out / "CHECKLIST.md").write_text(CHECKLIST, encoding="utf-8")


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    count = build_blocks(OUT)
    build_email_body(OUT)
    build_catalog(OUT)
    build_users(OUT)
    build_guides(OUT)
    print(f"wrote {count} Content Blocks to {OUT}")


if __name__ == "__main__":
    main()
