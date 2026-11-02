"""What the bundle gives a person doing the trial by hand: the renamed Catalog file, the trial stub for
ik_get_nearby, the preference-center swap that only the trial body gets, and the checklist order."""
import re
import subprocess
import sys

import pytest

from harness import LIQUID_DIR

TOOL = LIQUID_DIR / "tools" / "braze_bundle.py"
BUILD = LIQUID_DIR / "build" / "braze-bundle"


@pytest.fixture(scope="session")
def bundle():
    subprocess.run([sys.executable, str(TOOL)], check=True)
    return BUILD


def test_catalog_file_is_named_after_the_catalog(bundle):
    # Braze fills in a Catalog's name from its file name, so the file is named for the Catalog it becomes.
    assert (bundle / "restaurants.csv").exists()
    assert not (bundle / "restaurants_catalog.csv").exists()


def test_trial_stub_replaces_nearby_and_makes_no_call(bundle):
    stub = (bundle / "blocks" / "03_ik_get_nearby.trial.liquid").read_text(encoding="utf-8")
    assert "connected_content" not in stub.lower()
    assert "nearby" in stub  # the same output name, so the message's logic still works
    assert "trial" in stub.lower()


def test_trial_stub_is_written_only_as_an_extra_file(bundle):
    # The full block file stays as it was: the stub is a second file beside it.
    full = (bundle / "blocks" / "03_ik_get_nearby.liquid").read_text(encoding="utf-8")
    assert "connected_content" in full


def test_preference_link_is_swapped_only_in_the_trial_body(bundle):
    # The tag lives in ik_footer, which the full body includes. The live footer block keeps it.
    trial = (bundle / "email_body_trial.liquid").read_text(encoding="utf-8")
    footer = (bundle / "blocks" / "15_ik_footer.liquid").read_text(encoding="utf-8")
    assert "preference_center" not in trial
    assert "{{ explore_url }}" in trial
    assert "preference_center" in footer


def test_checklist_steps_are_in_the_order_that_worked(bundle):
    checklist = (bundle / "CHECKLIST.md").read_text(encoding="utf-8")
    steps = re.findall(r"^\d+\. \*\*(.+?)\*\*", checklist, flags=re.M)
    assert steps[0].startswith("Create the Catalog")
    assert steps[1].startswith("Import users")
    assert steps[2].startswith("Data Settings")
    step_body = checklist.split("3. **Data Settings:**", 1)[1].split("\n4. ", 1)[0]
    assert "saved_restaurants" in step_body and "Array" in step_body
    assert "Blocks" in steps[3] or "block" in steps[3].lower()
    assert steps[4].startswith("Create the email")
    assert steps[5].startswith("Preview")


def test_checklist_sets_the_display_type_and_the_array(bundle):
    checklist = (bundle / "CHECKLIST.md").read_text(encoding="utf-8")
    assert "first_reward_display" in checklist and "String" in checklist
    assert "saved_restaurants" in checklist and "Array" in checklist


def test_checklist_has_the_trial_limits(bundle):
    checklist = (bundle / "CHECKLIST.md").read_text(encoding="utf-8")
    assert "8 Content Blocks" in checklist or "eight" in checklist.lower()
    assert "email_body_trial.liquid" in checklist
    assert "Connected Content" in checklist


def test_preview_cases_give_the_subject_and_the_pinned_lookup(bundle):
    preview = (bundle / "PREVIEW_CASES.md").read_text(encoding="utf-8")
    assert "Your $25 toward a $50+ meal is waiting" in preview
    assert "$12.50" in preview and "String" in preview
    assert "r_101" in preview and "pinned" in preview.lower()
