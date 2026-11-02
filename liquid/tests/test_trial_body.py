"""email_body_trial.liquid is the email for a Braze trial workspace, which allows only eight Content Blocks.

It keeps includes for blocks 01-08 and writes blocks 09-17 inline. It must render the same HTML as the
full email body, in every fixture case, and it must not contain connected_content (the trial blocks it).
"""
import re

import pytest

from fixtures import CASES
from harness import Abort, LIQUID_DIR, render, render_or_abort

TRIAL = LIQUID_DIR / "build" / "braze-bundle" / "email_body_trial.liquid"
FULL = LIQUID_DIR / "build" / "braze-bundle" / "email_body.liquid"
INCLUDE = re.compile(r"\{\{content_blocks\.\$\{(\w+)\}\}\}")


@pytest.fixture(scope="session")
def bundle_bodies():
    import subprocess
    import sys

    subprocess.run([sys.executable, str(LIQUID_DIR / "tools" / "braze_bundle.py")], check=True)
    return TRIAL.read_text(encoding="utf-8"), FULL.read_text(encoding="utf-8")


def test_trial_body_has_no_connected_content(bundle_bodies):
    trial, _ = bundle_bodies
    assert "connected_content" not in trial


def test_trial_body_keeps_blocks_01_to_08_as_includes(bundle_bodies):
    trial, _ = bundle_bodies
    kept = set(INCLUDE.findall(trial))
    # The eight logic and layout blocks, by name; the visible ones are inline.
    assert kept == {"ik_brand", "ik_urls", "ik_get_reward", "ik_get_saved_restaurant",
                    "ik_get_nearby", "ik_restaurant_link", "ik_layout_close", "ik_layout_open"}


def normalize(html):
    # Whitespace between tags is ignored: an inlined block has different line breaks from an include,
    # but the same markup. Everything else, including every attribute and every word, must match.
    return re.sub(r">\s+<", "><", html).strip()


@pytest.mark.parametrize("case", list(CASES))
def test_trial_body_renders_the_same_html_as_the_full_body(bundle_bodies, case):
    trial, full = bundle_bodies
    context = CASES[case]
    expected = render_or_abort(full, context)
    actual = render_or_abort(trial, context)
    if expected.startswith("ABORT"):
        # Abort cases compare their reason instead of HTML; the test below checks that too.
        assert actual == expected, f"{case}: trial body aborts differently"
        return
    # The one allowed difference is the footer's preferences link, which is the link whose text is
    # "Preferences". The trial has no preference center, so that link points at the Explore page instead.
    # Anchor on the link text, so the Explore button can't be mistaken for it.
    footer_link = re.compile(r'<a href="https://www\.inkind\.com"([^>]*)>(?=[^<]*Preferences)')
    restored = footer_link.sub(r'<a href="#preferences"\1>', actual)
    assert normalize(restored) == normalize(expected), \
        f"{case}: trial body differs from the full body beyond the preferences link"


def test_trial_body_aborts_for_the_same_reasons(bundle_bodies):
    trial, full = bundle_bodies
    for case in ["reward-used", "no-minimum", "zero-amount"]:
        with pytest.raises(Abort):
            render(full, CASES[case])
        with pytest.raises(Abort):
            render(trial, CASES[case])
