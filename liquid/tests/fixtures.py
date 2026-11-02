"""Test data: fictional restaurants, one case per Liquid preview in
04-qa-and-measurement.md, and a few edge cases.

Every restaurant name, address, description, rating, and ID here is made up, and any
resemblance to a real restaurant is coincidental. Location IDs use a demo- prefix so a
generated link can't open a real inKind listing. Photos are AI-generated sample images
stored in liquid/images/samples/ (labeled "Sample image"), never links to someone
else's photos: a full-width JPEG for cards, and a square JPEG for row thumbnails.
"""
from collections import defaultdict

SAMPLES = "../images/samples/"


def photo(slug):
    return f"{SAMPLES}{slug}.jpg"


def thumb(slug):
    return f"{SAMPLES}{slug}-thumb.jpg"


FEATURED = {
    "id": "r_101", "location_id": "demo-101", "name": "Lantern Row",
    "cuisine": "Japanese · Small plates · Grill", "rating": 4.6, "price": "$$", "cashback_pct": 20,
    "description": "Charcoal-grilled skewers and small plates made for sharing.",
    "image_url": photo("lantern-row"), "thumb_url": thumb("lantern-row"),
}

NEARBY = [
    {"location_id": "demo-201", "name": "Nonna Pia's Kitchen", "cuisine": "Italian, pasta", "price": "$$$",
     "address": "100 Example Avenue", "distance_mi": 1.2, "cashback_pct": 15,
     "image_url": photo("nonna-pias"), "thumb_url": thumb("nonna-pias")},
    {"location_id": "demo-202", "name": "Ember & Oak", "cuisine": "Steakhouse, wood-fired grill", "price": "$$$$",
     "address": "200 Example Avenue", "distance_mi": 2.4, "cashback_pct": 20,
     "image_url": photo("ember-and-oak"), "thumb_url": thumb("ember-and-oak")},
    {"location_id": "demo-203", "name": "Tidepool Taqueria", "cuisine": "Mexican, tacos", "price": "$$",
     "address": "300 Example Avenue", "distance_mi": 3.8, "cashback_pct": 10,
     "image_url": photo("tidepool"), "thumb_url": thumb("tidepool")},
]

LONG_NAMES = [
    {"location_id": "demo-301", "name": "The Grand Coastal Kitchen and Oyster Bar at the Harbor"},
    {"location_id": "demo-302", "name": "Little Neighborhood Trattoria and Natural Wine Shop"},
    {"location_id": "demo-303", "name": "Midnight Taqueria, Mezcaleria and Rooftop Garden"},
]

CATALOG = defaultdict(list, {"r_101": [FEATURED]})


def recs(restaurants):
    return {"__http_status_code__": 200, "restaurants": restaurants}


RECS_DOWN = {"__http_status_code__": 500}
REWARD = {"first_reward_amount": 25, "first_reward_display": "25", "first_reward_min_spend": 50}
BASE = {"user_id": "u_1001", "unsubscribe_url": "#unsubscribe", "preferences_url": "#preferences", "catalog": CATALOG}


def case(entry=None, recommendations=None, **profile):
    return {**BASE, "entry": entry or {}, "recs": recommendations or recs(NEARBY), **profile}


CASES = {
    # the seven Liquid previews in 04
    "saved-restaurant":   case({"restaurant_id": "r_101"}, **REWARD),
    "saved-array-only":   case(saved_restaurants=["r_101"], **REWARD),
    "id-not-in-catalog":  case({"restaurant_id": "r_99999"}, **REWARD),
    "nearby-picks":       case(**REWARD),
    "generic":            case(recommendations=RECS_DOWN, **REWARD),
    "reward-used":        case(),
    "no-minimum":         case(first_reward_amount=25, first_reward_display="25"),
    # edge cases 04 also lists
    "non-whole-amount":   case({"restaurant_id": "r_101"}, first_reward_amount=12.5,
                               first_reward_display="12.50", first_reward_min_spend=50),
    "long-names":         case(recommendations=recs(LONG_NAMES), **REWARD),
    "zero-amount":        case(first_reward_amount=0, first_reward_display="0", first_reward_min_spend=50),
    "200-no-restaurants": case(recommendations={"__http_status_code__": 200}, **REWARD),
}

ABORTS = {
    "reward-used": "no unused reward",
    "no-minimum": "reward minimum missing",
    "zero-amount": "reward amount is zero",
}

# Illustrative: set to the push length limit the team uses.
PUSH_MAX = 140
