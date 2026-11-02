"""Write previews/: every message case, a component gallery, and an index.

  python3 tests/build_previews.py                 HTML and push text
  python3 tests/build_previews.py --screenshots   also PNGs in previews/screenshots/, at 680px and 375px wide
                                                  (needs: pip install playwright && playwright install chromium)
"""
import html
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from harness import BLOCKS, LIQUID_DIR, BLOCK_LAYER, message, render, render_or_abort  # noqa: E402
from fixtures import CASES, FEATURED, NEARBY  # noqa: E402

PREVIEWS = LIQUID_DIR / "previews"
CONFIG = "{{content_blocks.${ik_brand}}}{{content_blocks.${ik_urls}}}"

GALLERY_CONTEXT = {
    "card": FEATURED, "min_spend": 50, "unsubscribe_url": "#unsubscribe",
    "btn_label": "See Lantern Row", "btn_url": "#",
    "hero_eyebrow": "Your reward is waiting", "hero_headline": "$25 toward your<br>first $50+ meal",
    "hero_body": "It's waiting at a place you saved. Dinner tonight?", "hero_card": FEATURED,
    "list_title": "Near you", "list_items": NEARBY,
}

# Each visible block rendered alone, grouped by layer, with its variants side by side.
# Wrappers give small blocks the background of the section they sit in, read from ik_brand
# so a brand swap restyles the gallery too. Entries: (block, wrapper, optional note).
DARK = '<div style="background:{{ ik_color_dark }};padding:{{ ik_space_md }}px;text-align:center">'
LIGHT = '<div style="background:{{ ik_color_light }};padding:{{ ik_space_md }}px">'
GALLERY = [
    ("ik_button", DARK + "{% assign btn_style = 'primary' %}{{content_blocks.${ik_button}}}</div>", "btn_style: primary"),
    ("ik_button", LIGHT + "{% assign btn_style = 'dark' %}<div style=\"text-align:center\">{{content_blocks.${ik_button}}}</div></div>", "btn_style: dark"),
    ("ik_card_restaurant_feature", DARK + "{{content_blocks.${ik_card_restaurant_feature}}}</div>"),
    ("ik_card_restaurant_compact", LIGHT + "{% assign card = list_items[1] %}{{content_blocks.${ik_card_restaurant_compact}}}</div>"),
    ("ik_card_restaurant_row", LIGHT + "{% assign card = list_items[1] %}{{content_blocks.${ik_card_restaurant_row}}}</div>"),
    ("ik_callout", LIGHT + "{% assign callout_style = 'note' %}{{content_blocks.${ik_callout}}}</div>", "callout_style: note"),
    ("ik_callout", DARK + "{% assign callout_style = 'dark' %}{{content_blocks.${ik_callout}}}</div>", "callout_style: dark"),
    ("ik_how_to_use_reward", "{{content_blocks.${ik_how_to_use_reward}}}"),
    ("ik_hero_text", "{{content_blocks.${ik_hero_text}}}"),
    ("ik_section_restaurant_list", "{% assign list_style = 'row' %}{{content_blocks.${ik_section_restaurant_list}}}", "list_style: row"),
    ("ik_section_restaurant_list", "{% assign list_style = 'card' %}{{content_blocks.${ik_section_restaurant_list}}}", "list_style: card"),
    ("ik_footer", "{{content_blocks.${ik_footer}}}"),
    ("ik_footer", "{% assign tiktok_url = '#' %}{% assign facebook_url = '#' %}{% assign instagram_url = '#' %}"
                  "{{content_blocks.${ik_footer}}}", "with social URLs set"),
]
LAYER_TITLES = {"elements": "Elements", "components": "Components", "sections": "Sections"}


def token_sheet(blocks=None):
    """Swatches, spacing bars, and type samples, rendered from ik_brand itself."""
    source = (blocks or BLOCKS)["ik_brand"]
    colors = re.findall(r"assign (ik_color_\w+) =", source)
    spaces = re.findall(r"assign (ik_space_\w+) =", source)
    texts = re.findall(r"assign (ik_text_\w+) =", source)
    label = 'style="font:12px monospace;color:#444;padding:4px 8px"'
    rows = "".join(
        f'<tr><td style="padding:4px 8px"><div style="width:40px;height:24px;border:1px solid #ccc;'
        f'background:{{{{ {c} }}}}"></div></td><td {label}>{c}</td><td {label}>{{{{ {c} }}}}</td></tr>' for c in colors)
    rows += "".join(
        f'<tr><td style="padding:4px 8px"><div style="height:12px;width:{{{{ {t} }}}}px;background:{{{{ ik_color_gold }}}}"></div></td>'
        f'<td {label}>{t}</td><td {label}>{{{{ {t} }}}}px</td></tr>' for t in spaces)
    rows += "".join(
        f'<tr><td style="padding:4px 8px;font-family:{{{{ ik_font }}}};font-size:{{{{ {t} }}}}px">Dinner tonight?</td>'
        f'<td {label}>{t}</td><td {label}>{{{{ {t} }}}}px</td></tr>' for t in texts)
    return render(CONFIG + f'<table role="presentation" style="border-collapse:collapse">{rows}</table>', {},
                  **({"blocks": blocks} if blocks else {}))


def render_gallery_block(name, wrapper, blocks=None, context=None):
    kwargs = {"blocks": blocks} if blocks else {}
    return render(CONFIG + wrapper, context or GALLERY_CONTEXT, **kwargs)


def gallery_page(blocks=None):
    heading = '<tr><td style="padding:40px 16px 0;font:800 20px Arial;border-top:2px solid #eee">{}</td></tr>'
    label_row = '<tr><td style="padding:24px 16px 8px;font:600 13px Arial;color:#555;letter-spacing:1px">{}</td></tr>'
    rows = [heading.format("Tokens (config / ik_brand)"), f"<tr><td style=\"padding:8px\">{token_sheet(blocks)}</td></tr>"]
    layer = None
    for name, wrapper, *note in GALLERY:
        if BLOCK_LAYER[name] != layer:
            layer = BLOCK_LAYER[name]
            rows.append(heading.format(LAYER_TITLES[layer]))
        rows.append(label_row.format(name + (f" ({note[0]})" if note else "")))
        rows.append(f"<tr><td>{render_gallery_block(name, wrapper, blocks)}</td></tr>")
    return ('<!DOCTYPE html><html><head><meta charset="utf-8"><title>Component gallery</title></head>'
            '<body style="margin:0;background:#fff"><table role="presentation" width="100%" style="max-width:640px;margin:0 auto">'
            '<tr><td style="padding:24px 16px 0;font:800 24px Arial">Component gallery</td></tr>'
            '<tr><td style="padding:8px 16px 0;font:14px Arial;color:#555">Every visible block rendered alone, by layer, with its variants. '
            'Built from blocks/ by tests/build_previews.py.</td></tr>'
            + "".join(rows) + "</table></body></html>")


def build(screenshots=False):
    PREVIEWS.mkdir(exist_ok=True)
    email, push = message("first_reward.email.liquid"), message("first_reward.push.liquid")
    items = []
    for name, context in CASES.items():
        email_out = render_or_abort(email, context)
        push_out = render_or_abort(push, context).strip()
        (PREVIEWS / f"push-{name}.txt").write_text(push_out + "\n")
        if email_out.startswith("ABORT"):
            items.append(f"<li><b>{name}</b>: {html.escape(email_out)}</li>")
        else:
            (PREVIEWS / f"email-{name}.html").write_text(email_out)
            items.append(f'<li><a href="email-{name}.html"><b>{name}</b></a>: push &ldquo;{html.escape(push_out)}&rdquo;</li>')
    (PREVIEWS / "component-gallery.html").write_text(gallery_page())
    (PREVIEWS / "index.html").write_text(
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Previews</title></head>'
        '<body style="font:16px/1.6 Arial;max-width:760px;margin:32px auto;padding:0 16px">'
        '<h1>First-reward previews</h1><p><a href="component-gallery.html">Component gallery</a>: each block rendered alone.</p>'
        "<h2>Cases</h2><ul>" + "".join(items) + "</ul></body></html>")
    if screenshots:
        from playwright.sync_api import sync_playwright
        out = PREVIEWS / "screenshots"
        out.mkdir(exist_ok=True)
        with sync_playwright() as p:
            browser = p.chromium.launch()
            page = browser.new_page(viewport={"width": 680, "height": 900})
            for name in ["email-saved-restaurant", "email-nearby-picks", "email-generic"]:
                page.goto((PREVIEWS / f"{name}.html").as_uri(), wait_until="networkidle")
                page.screenshot(path=str(out / f"{name}.png"), full_page=True)
            page.set_viewport_size({"width": 375, "height": 812})
            for name in ["email-saved-restaurant", "email-nearby-picks"]:
                page.goto((PREVIEWS / f"{name}.html").as_uri(), wait_until="networkidle")
                page.screenshot(path=str(out / f"{name}-mobile.png"), full_page=True)
            browser.close()
    print(f"Wrote previews to {PREVIEWS}")


if __name__ == "__main__":
    build(screenshots="--screenshots" in sys.argv)
