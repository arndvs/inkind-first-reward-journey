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


# A Braze trial workspace allows eight Content Blocks. The first eight (config, logic and layout) stay as
# includes; the visible blocks after them are written inline, so the trial email uses only those eight.
TRIAL_INCLUDE_LIMIT = 8
INCLUDE_PATTERN = r"\{\{content_blocks\.\$\{(\w+)\}\}\}"


def build_trial_body(out):
    """Writes email_body_trial.liquid: the email with blocks past the trial limit inlined."""
    import re

    source = (MESSAGES_DIR / "first_reward.email.liquid").read_text(encoding="utf-8")
    files = {p.stem: p for p in BLOCKS_DIR.glob("*/*.liquid")}
    ordered = sorted(files, key=lambda name: (LAYER_ORDER.index(files[name].parent.name), files[name].name))
    keep = set(ordered[:TRIAL_INCLUDE_LIMIT])

    def block_body(name):
        # Everything after the header comment, exactly as written. Braze strips the comment itself.
        return files[name].read_text(encoding="utf-8").split("{%- endcomment -%}", 1)[1]

    # Inlining a block can bring in its own includes, so inline those too, unless they are among the eight.
    def inline(text, depth=0):
        if depth > 10:
            raise RuntimeError("Content Blocks nested more than 10 deep")

        def replace(match):
            name = match.group(1)
            if name in keep:
                return match.group(0)
            return inline(block_body(name), depth + 1)

        return re.sub(INCLUDE_PATTERN, replace, text)

    text = inline(source)
    # The trial workspace has no preference center, so its link goes to the Explore page instead.
    text = re.sub(r"\{\{preference_center\.\$\{\w+\}\}\}", "{{ explore_url }}", text)
    (out / "email_body_trial.liquid").write_text(rewrite_assets(text) + "\n", encoding="utf-8")


TRIAL_NEARBY_STUB = """{%- comment -%}
  ik_get_nearby, trial stub. Connected Content is blocked in the Braze trial workspace, even inside a
  Liquid comment, so this version makes no call. nearby stays empty, and the message shows the Explore button.
  The live block is 03_ik_get_nearby.liquid; use it only in a workspace that allows Connected Content.
{%- endcomment -%}
"""


def build_trial_stub(out):
    (out / "blocks" / "03_ik_get_nearby.trial.liquid").write_text(TRIAL_NEARBY_STUB, encoding="utf-8")


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


def rewrite_value(value):
    return rewrite_assets(value) if isinstance(value, str) else value


def build_catalog(out):
    # Braze names a Catalog after its file, so the file is named for the Catalog it becomes.
    with open(out / "restaurants.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(["id"] + CATALOG_FIELDS)
        for key, item in catalog_rows():
            writer.writerow([key] + [rewrite_value(item.get(field, "")) for field in CATALOG_FIELDS])


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

Preview each user in the Braze composer with "Select existing user". Expected subject: "Your $25 toward a $50+ meal is waiting" for every user with an unused reward, with the offer in the hero and the button as listed.

| User | Expected |
|---|---|
| u_1001 | "$25 toward a $50+ meal". No saved restaurant on the profile and no live recommendations endpoint, so the Explore fallback |
| u_1003 | "$12.50", after first_reward_display is set to String in the import mapping. Braze guessed Number by default; with Number it shows "$12.5" |
| u_1002 | Abort: no unused reward |
| u_1005 | Abort: no unused reward |
| u_1008 | Abort: reward minimum missing |
| u_9001 | Abort: reward amount is zero |
| Saved-restaurant card | Needs saved_restaurants, which CSV import can't set. Test it with a temporary lookup pinned to r_101: add `{% assign saved_id = 'r_101' %}` at the top of the email body and the lookup `{% catalog_items restaurants {{ saved_id }} %}` before the card, then remove both lines when the test is done. Don't change the message |
"""

CHECKLIST = """# Braze Live workspace: manual steps, in order

Never launch a campaign or Canvas in the Live workspace. Preview, and send tests to your own address only.

1. **Create the Catalog** `restaurants` from `restaurants.csv`. Keep the file's name as the Catalog name. The name can't be changed after launch.
2. **Import users** from `users_import.csv`. In Column mapping, set `first_reward_display` to **String**, and leave the rest as detected. Braze guesses Number otherwise, and `12.50` would show as `12.5`.
3. **Data Settings:** add `saved_restaurants` as an **Array**. CSV import can't set arrays, so this only creates the attribute.
4. **Create the Content Blocks** from `blocks/`. Name each block as the file name without its number (`01_ik_brand.liquid` becomes `ik_brand`). Use `03_ik_get_nearby.trial.liquid` for `ik_get_nearby`, not the live file, because Connected Content is blocked in the trial. Blocks that read a custom attribute can't be saved until that attribute exists, so do step 2 and 3 first.
5. **Create the email** from `email_body_trial.liquid`, which uses at most eight Content Blocks. Set the subject to `{{content_blocks.${ik_get_reward}}}Your {{ offer }} is waiting`. The preference link is replaced with the Explore link, because the trial has no preference center. Don't launch it.
6. **Preview** with "Select existing user": u_1001, u_1003, u_1002, u_1005, u_1008 and u_9001, against `PREVIEW_CASES.md`. Then the saved-restaurant card with the pinned lookup. Record anything that differs.
7. **Keep "Auto-approve actions" off** in the BrazeAI Operator panel.

**Trial limits.** A trial workspace allows 8 Content Blocks (so use the trial body), blocks Connected Content even inside a Liquid comment (so use the trial stub), has no REST API, and has no preference center. The full body and the live blocks are for a workspace without these limits.
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
    build_trial_body(OUT)
    build_trial_stub(OUT)
    build_catalog(OUT)
    build_users(OUT)
    build_guides(OUT)
    print(f"wrote {count} Content Blocks to {OUT}")


if __name__ == "__main__":
    main()
