import re
import pytest
from harness import Abort, message, render
from fixtures import ABORTS, CASES, PUSH_MAX

EMAIL = message("first_reward.email.liquid")
PUSH = message("first_reward.push.liquid")


def email(case):
    return render(EMAIL, CASES[case])


def push(case):
    return render(PUSH, CASES[case]).strip()


def restaurant_links(html):
    seen = []
    for location in re.findall(r'href="https://app\.inkind\.com/map\?location=([\w-]+)"', html):
        if location not in seen:
            seen.append(location)
    return seen


@pytest.mark.parametrize("case", ["saved-restaurant", "saved-array-only"])
def test_saved_restaurant_is_featured_and_linked(case):
    out = email(case)
    assert "See Lantern Row" in out
    assert restaurant_links(out) == ["demo-101"]
    assert "Near you" not in out
    assert push(case) == "Your $25 toward a $50+ meal is waiting at Lantern Row. Dinner tonight?"


def test_nearby_list_in_order_with_escaped_names():
    out = email("nearby-picks")
    assert restaurant_links(out) == ["demo-201", "demo-202", "demo-203"]
    assert "Nonna Pia&#39;s" in out or "Nonna Pia&#x27;s" in out
    assert "Ember &amp; Oak" in out
    assert "Find a spot near you" in out
    assert push("nearby-picks").startswith("Your $25 toward a $50+ meal is waiting. Nearby: Nonna Pia's Kitchen, Ember & Oak")


def test_nearby_list_uses_rows():
    out = email("nearby-picks")
    assert out.count('class="ik-row"') == 3
    assert out.count("-thumb.jpg") == 3


def test_photos_are_local_jpegs_never_hotlinked():
    for case in [c for c in CASES if c not in ABORTS]:
        out = email(case)
        assert ".webp" not in out
        for src in re.findall(r'<img[^>]*src="([^"]+)"', out):
            assert src.startswith("../images/"), src


def test_id_missing_from_catalog_falls_back_to_nearby():
    out = email("id-not-in-catalog")
    assert "Near you" in out and "See " not in out


def test_generic_when_recommendations_fail():
    out = email("generic")
    assert "Find a spot near you" in out and "Near you" not in out
    assert 'href="https://www.inkind.com"' in out
    assert push("generic") == "Your $25 toward a $50+ meal is waiting. Find a spot near you tonight."


def test_200_without_restaurants_falls_back_like_a_failed_call():
    out = email("200-no-restaurants")
    assert "Find a spot near you" in out and "Near you" not in out
    assert push("200-no-restaurants") == "Your $25 toward a $50+ meal is waiting. Find a spot near you tonight."


@pytest.mark.parametrize("case,reason", ABORTS.items())
def test_unusable_reward_aborts_both_channels(case, reason):
    for template in (EMAIL, PUSH):
        with pytest.raises(Abort, match=reason):
            render(template, CASES[case])


def test_non_whole_amount():
    assert "$12.50 toward your<br>first $50+ meal" in email("non-whole-amount")
    assert push("non-whole-amount").startswith("Your $12.50 toward a $50+ meal is waiting")


def test_long_names_stay_under_push_limit():
    text = push("long-names")
    assert len(text) <= PUSH_MAX
    assert text.endswith("...")


@pytest.mark.parametrize("case", [c for c in CASES if c not in ABORTS])
def test_every_email_has_required_parts(case):
    out = email(case)
    for required in ["#unsubscribe", "#preferences", "https://inkind.com/privacy", "https://inkind.com/terms",
                     "[Mailing address]", "v:roundrect", "How to use it",
                     "food and beverage subtotal is <strong>$50 or more</strong>"]:
        assert required in out, required
    assert re.search(r'<div style="display:none[^>]*>Your \$[\d.]+ toward a \$50\+ meal is waiting', out), "preheader"
    assert "{{" not in out and "{%" not in out, "unrendered Liquid"
