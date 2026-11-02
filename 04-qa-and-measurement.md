# 04 — QA, Shipping, and Measurement

Success is a higher first-purchase rate within 14 days of entry than the 10% control group.

---

## 1. Before launch

### Who can receive it

- [ ] Canvas built and tested in a Braze dev workspace before it exists in production
- [ ] Test sends go only to a Braze Internal Test Group
- [ ] Send Settings are "subscribed or opted-in" on every message step, so an unsubscribed user who is in the Canvas still gets nothing on that channel
- [ ] Audience previewed against known test users (opted in, opted out, unsubscribed) before launch
- [ ] Braze audience count is at or below the warehouse SQL count, and the gap matches users with no push or email permission
- [ ] Send time resolves to the user's local time, including the Friday follow-up (confirm the Day of the week delay uses each user's time zone); quiet hours respected
- [ ] Workspace frequency caps reviewed: this Canvas fits under them or has a deliberate exemption
- [ ] A second person reviews the Canvas and audience before it goes live

### What they see

- [ ] Test profile shows each event and attribute with the right type (User Search, event user log)
- [ ] Liquid preview for seven test users: saved restaurant found in the Catalog (once from the entry event, once from saved_restaurants only), saved ID missing from the Catalog, nothing saved, nothing saved with the recommendations endpoint down, reward already used (no reward fields), reward missing its minimum (last two abort). Automated in [`liquid/tests`](./liquid/tests); still previewed in Braze before launch
- [ ] The nearby call (`ik_get_nearby` and `03-message.liquid`) has no `:retry`. With it, Braze aborts the message after repeated failures instead of falling back to the Explore button, so retry only a call the message can't do without (automated in `liquid/tests`)
- [ ] Rendered push has no leading or trailing blank lines, shows "$25 toward a $50+ meal" (and "$12.50" for a non-whole amount) correctly, and stays under the push length limit with three long restaurant names (also automated)
- [ ] Cloud Data Ingestion sync run shows the expected row count, and a test user's reward fields clear from the profile after the reward is marked redeemed in Snowflake
- [ ] Links are tracked and deep-link into the app; email renders in Gmail, Outlook, and Apple Mail and includes the footer with an unsubscribe link
- [ ] A test purchase removes the test user from the Canvas
- [ ] Browsing Canvas: a test user enters on their third session within 14 days, not before; saving a restaurant moves them out of it

---

## 2. How I'd ship it

- Add the `restaurant_saved` event and the `saved_restaurants` update to the Rails backend, sent to `/users/track` from a background job so the request path never waits on Braze
- Run it locally against Postgres and the Braze dev workspace, then check the test profile in User Search
- Open a PR with the payload change and a test for the event shape
- Backfill `saved_restaurants` for existing users with a one-time batched `/users/track` job, or through the warehouse sync, before the Canvas goes live, so people who saved restaurants before this shipped get personalized and aren't mistaken for non-savers by the browsing Canvas
- Turn on the Canvas in production only after the checks in section 1 pass

---

## 3. After launch

| Metric | Type |
|---|---|
| First purchase within 14 days, journey vs. control, for each Canvas | Primary |
| Reward redemption rate (purchases with `reward_applied`) | Secondary |
| First meals under $50 (converted, reward still unused) | Secondary |
| Days from signup to first purchase | Secondary |
| Results by signup-week cohort, journey vs. control | Secondary |
| Unsubscribes and push opt-outs | Guardrail |

---

## 4. What I'd confirm first

| Question | Why it matters |
|---|---|
| Are browse and save events already reaching Braze, or only transactions? | Decides whether this is a data gap or a journey gap |
| How is the referral reward stored, and does it reach the Braze profile today? | The app keeps Rewards separate from inKind Cash and Cash Back, so the journey reads the reward record, not a wallet balance; a stale record means promoting a reward that's already used |
| Should a first meal under $50 count as converted? | It ends this journey, but the reward is still unused; that may deserve its own follow-up |
| What share of new users allow push? | Decides how much email has to carry |
| What is the session-count filter called in the Braze filter picker? | The browsing Canvas (02, section 4) depends on it; the SDK collects total sessions, but I haven't seen the filter's exact name |
| Does an existing referral or onboarding Canvas overlap with this one? | Avoids double messaging; may mean extending a Canvas instead of adding one |
| Does a "reward applied" receipt come from Rails or Braze? | The journey sends nothing after redemption; whether a receipt confirms the reward depends on which system sends it |