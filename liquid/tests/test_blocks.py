import re
import pytest
from harness import BLOCK_LAYER, BLOCKS, render, single_file_message
from build_previews import CONFIG, GALLERY, GALLERY_CONTEXT, gallery_page, render_gallery_block
from fixtures import FEATURED, NEARBY


@pytest.mark.parametrize("name", [n for n in BLOCKS if n != "ik_layout_close"])
def test_block_header_states_inputs_and_outputs(name):
    assert BLOCKS[name].startswith("{%- comment -%}")
    header = BLOCKS[name].split("{%- endcomment -%}")[0]
    assert "Inputs:" in header and "Outputs:" in header


NON_CONFIG = [n for n, layer in BLOCK_LAYER.items() if layer != "config"]


@pytest.mark.parametrize("name", NON_CONFIG)
def test_spacing_and_type_come_from_tokens(name):
    source = BLOCKS[name]
    assert not re.findall(r"(?:padding|margin)(?:-\w+)?:[^;\"]*?\b[1-9]\d*px", source)
    assert not re.findall(r"font-size:(?!1px)\d+px", source)


@pytest.mark.parametrize("name", NON_CONFIG)
def test_colors_come_from_tokens(name):
    assert not re.findall(r"(?<!&)#[0-9a-fA-F]{3,6}\b", BLOCKS[name])


@pytest.mark.parametrize("name,wrapper", [g[:2] for g in GALLERY])
def test_block_renders_alone(name, wrapper):
    out = render_gallery_block(name, wrapper)
    assert out.strip() and "{{" not in out and "{%" not in out


@pytest.mark.parametrize("name", ["ik_card_restaurant_feature", "ik_card_restaurant_compact", "ik_card_restaurant_row"])
def test_cards_include_no_blocks(name):
    # Braze renders one level of nesting only (message -> block -> block), so a card can't include blocks.
    assert not re.search(r"\{\{content_blocks\.\$\{", BLOCKS[name])


def test_nearby_call_is_cached_and_not_retried():
    # :retry makes Braze abort the message after repeated failures, which skips the Explore fallback.
    for source in (BLOCKS["ik_get_nearby"], single_file_message()):
        call = re.search(r"\{%-?\s*connected_content [^%]*-?%\}", source).group(0)
        assert ":cache_max_age 900" in call and ":retry" not in call, call


def test_card_without_image_has_no_img_tag():
    card = {**FEATURED, "image_url": None, "thumb_url": None}
    out = render(CONFIG + "{{content_blocks.${ik_card_restaurant_feature}}}", {"card": card})
    assert "<img" not in out and "Lantern Row" in out


def test_badge_hidden_without_cashback():
    out = render(CONFIG + "{{content_blocks.${ik_badge_cashback}}}", {"card": {"name": "X"}})
    assert out.strip() == ""


def test_link_falls_back_to_explore_url():
    out = render(CONFIG + "{% assign card = c %}{{content_blocks.${ik_restaurant_link}}}{{ card_link }}", {"c": {"name": "X"}})
    assert out.strip() == "https://www.inkind.com"


def test_list_limit():
    out = render(CONFIG + "{{content_blocks.${ik_section_restaurant_list}}}",
                 {"list_title": "Near you", "list_items": NEARBY, "list_limit": 2})
    assert "Ember &amp; Oak" in out and "Tidepool" not in out


def test_one_brand_block_restyles_everything():
    neutral = (BLOCKS["ik_brand"].replace("#E7B84B", "#3366FF").replace("#1b151e", "#222222")
               .replace("ik_space_md = 24", "ik_space_md = 26").replace("ik_text_display = 34", "ik_text_display = 37"))
    page = gallery_page(blocks={**BLOCKS, "ik_brand": neutral})
    assert "#3366FF" in page and "#222222" in page
    assert "#E7B84B" not in page and "#1b151e" not in page
    assert "26px" in page and "font-size:37px" in page and "font-size:34px" not in page


@pytest.mark.parametrize("style,background", [("primary", "#E7B84B"), ("dark", "#1b151e")])
def test_button_styles(style, background):
    out = render(CONFIG + "{{content_blocks.${ik_button}}}", {"btn_style": style, "btn_label": "Go", "btn_url": "#"})
    assert f"background-color:{background}" in out and f'fillcolor="{background}"' in out


@pytest.mark.parametrize("style,background", [("note", "#ffffff"), ("dark", "#252027")])
def test_callout_styles(style, background):
    out = render(CONFIG + "{{content_blocks.${ik_callout}}}", {"callout_style": style, "callout_text": "Terms"})
    assert f"background-color:{background}" in out and "Terms" in out


@pytest.mark.parametrize("thumb,image,expect_src", [
    ("https://example.org/t.jpg", "https://example.org/a.jpg", "t.jpg"),
    (None, "https://example.org/a.jpg", "a.jpg"),
    (None, None, None),
])
def test_row_card_prefers_square_thumb(thumb, image, expect_src):
    card = {**NEARBY[0], "thumb_url": thumb, "image_url": image}
    out = render(CONFIG + "{{content_blocks.${ik_card_restaurant_row}}}", {"card": card})
    assert ("<img" in out) == bool(expect_src)
    if expect_src:
        assert expect_src in out
        assert ('height="120"' in out) == bool(thumb), "a fixed height only for a square thumb"
    assert "Nonna Pia" in out and "location=demo-201" in out


@pytest.mark.parametrize("style,marker", [("row", 'class="ik-row"'), ("card", "font-size:19px")])
def test_list_style_switches_card_type(style, marker):
    out = render(CONFIG + "{{content_blocks.${ik_section_restaurant_list}}}",
                 {"list_title": "Near you", "list_items": NEARBY, "list_style": style})
    assert out.count(marker) == 3


def test_every_image_in_the_gallery_has_alt_text():
    page = gallery_page()
    for tag in re.findall(r"<img[^>]*>", page):
        assert re.search(r'alt="[^"]+"', tag) or 'role="presentation"' in tag, tag


def test_light_color_scheme_only():
    out = render(CONFIG + "{{content_blocks.${ik_layout_open}}}", {})
    assert '<meta name="color-scheme" content="light">' in out
    assert "color-scheme:light;" in out and "light dark" not in out


@pytest.mark.parametrize("name", ["ik_get_reward"])
def test_logic_blocks_print_nothing(name):
    ctx = {"first_reward_amount": 25, "first_reward_display": "25", "first_reward_min_spend": 50}
    assert render(BLOCKS[name], ctx).strip() == ""


def test_reward_ok_flags():
    def flags(**profile):
        out = render(BLOCKS["ik_get_reward"] + "{{ reward_ok }}|{{ reward_skip_reason }}", profile)
        return out.strip()
    assert flags(first_reward_amount=25, first_reward_min_spend=50) == "true|"
    assert flags() == "false|no_reward"
    assert flags(first_reward_amount=0, first_reward_min_spend=50) == "false|zero_amount"
    assert flags(first_reward_amount=25) == "false|no_minimum"


def test_footer_images_exist_and_have_alt_text():
    from harness import LIQUID_DIR
    out = render(CONFIG + "{{content_blocks.${ik_footer}}}", {"unsubscribe_url": "#"})
    for src in re.findall(r'src="\.\./images/([^"]+)"', out):
        assert (LIQUID_DIR / "images" / src).exists(), src
    assert all(alt for alt in re.findall(r'<img alt="([^"]*)"', out))


def test_social_icons_only_when_url_set():
    footer = "{{content_blocks.${ik_footer}}}"
    without = render(CONFIG + footer, {"unsubscribe_url": "#"})
    assert "TikTok" not in without and "website" in without
    with_urls = render(CONFIG + "{% assign instagram_url = 'https://example.org/ig' %}" + footer, {"unsubscribe_url": "#"})
    assert 'alt="Instagram"' in with_urls and "TikTok" not in with_urls
