# Spectator to Diner: First-Reward Journey

Implementation sketch · Aaron Davis · October 2026

How I'd build one Braze journey end to end: get browse intent and the referral reward onto the profile, then send a pre-dinner nudge to referred users who haven't made a first purchase.

**Why this one:** I signed up through a referral on October 8, with a $25 reward toward my first $50+ meal. That day I zoomed in and out of San Diego's neighborhoods to see what was around. A few days later I thought of it again, searched a few more neighborhoods, and saved a restaurant or two. Then I forgot about it. About two weeks later, on a Saturday night, my wife and I were deciding on takeout and spent a while on Google Maps looking for somewhere to order. inKind never came to mind. It wasn't a lack of interest. After the welcome email I got two more emails from inKind, on October 10 and 19. Both were general brand messages, not personalized: neither mentioned my $25 or the restaurants I'd saved. I got no push notifications or texts, even though notifications are turned on in the app.

I wasn't expecting a message that particular night. But a message or two in the weeks before about my reward and the places I'd saved would have made inKind more likely to come to mind while we searched, and a message saying my $25 was waiting at a restaurant I'd saved is one I would have used. Everything that message needed was already in my account: the restaurants I saved and the reward I hadn't used. This repo is how I'd get those signals onto the Braze profile and act on them. It's the same idea behind the recency and frequency segments I've built before: message people based on what they've done and what they haven't.

The SQL running in Snowflake (4:42):

[![Watch the SQL run in Snowflake (4:42)](sql/video-thumbnail.png)](https://youtu.be/OnmBVC8vrwE)

---

## What's built here

| File | What it contains |
|---|---|
| [`01-data-contract.md`](./01-data-contract.md) | The profile fields, two sync paths (real-time `/users/track` for events, Snowflake Cloud Data Ingestion for computed attributes), sample payloads, the sync view, sync rules |
| [`02-journey.md`](./02-journey.md) | Audience rules, audience SQL, the Canvas flow, and a second Canvas for new users who browse without saving |
| [`03-message.liquid`](./03-message.liquid) | The template: saved-restaurant personalization from a Catalog, a Connected Content call for nearby picks with its own fallback, and an abort when there's no unused reward |
| [`04-qa-and-measurement.md`](./04-qa-and-measurement.md) | Pre-launch send-safety and rendering checks, how I'd ship the backend change, metrics by cohort, what I'd confirm first |
| [`sql/`](./sql/) | A runnable proof of concept: synthetic sample data, the Cloud Data Ingestion view, both audience checks, and pass/fail checks to run in a Snowflake worksheet |
| [`liquid/`](./liquid/) | `03` split into reusable Braze Content Blocks: design tokens, shared logic for push and email, then elements, components, and sections. Includes a component gallery and render tests for the QA cases |
| [`rails/`](./rails/) | The backend half of the data contract. It builds the `/users/track` events in `01` once per action (recorded, not sent), exports rows to Snowflake with their load time, and previews what Cloud Data Ingestion would sync |

With only a few minutes, start with the "Who can receive it" checks in [`04-qa-and-measurement.md`](./04-qa-and-measurement.md). They decide who can get a message before anything sends.

---

## Conventions

- **Every event, attribute, table, endpoint, and threshold name is illustrative**, to be mapped to inKind's existing schema. I don't have access to inKind's data model, so this is a best guess built from the public Braze docs and my experience as one new user, including the reward terms shown in the app. [`04-qa-and-measurement.md`](./04-qa-and-measurement.md) lists what I'd confirm first.
- Timings and thresholds (4:30 PM send, three-day wait before a Friday follow-up, 30-day re-entry, three sessions in 14 days) are starting points to test, not conclusions.
