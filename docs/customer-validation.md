# Customer validation

How the journey's design is tested with real people before launch. This is separate from the automated checks in [verification.md](verification.md): those confirm the messages are correct, and this plan confirms that people act on them the way the design expects.

## Why this comes before launch

The design makes predictions about behaviour: a referred user who has saved a restaurant will tap the card; the minimum will be read before the tap; a weekend nudge will be welcome. Each prediction is a hypothesis. This plan is how the hypotheses get tested.

## What counts as validated

Write each expected answer before the session. A behaviour is validated when at least 10 of 15 participants do the same thing at the same step, without being prompted. Until then, the design is not final. A pattern that repeats across sessions is the signal to change the design.

## Who to recruit

- Referral sign-ups from the last 60 days, in two groups: those who saved a restaurant and those who did not.
- Recruit from a list of real users, not from friends or colleagues.
- Target: 15 participants in three rounds of five.

## Session format

- **Length:** 30 minutes, on a live screen share. Never send the prototype by email.
- **Recording:** always, with consent.
- **Prototype:** the email previews in `liquid/previews/`, and the push text, shown in the order a user would receive them.

### Opening

Say this, in your own words:

> This is a rough draft. Anything you see can change. Tell me what doesn't work; that is the most useful thing you can do for me, and I won't be offended.

### Script

For each screen, ask the same questions in the same order. Do not explain the screen before asking.

| Step | Question | What it tests |
|---|---|---|
| Push | "What do you think this is asking you to do?" | Clarity of the call to action |
| Push | "What would make you tap it?" | Benefit |
| Email, saved | "Which part would you look at first?" | Priority of the card and button |
| Email, saved | "Tell me in your own words what the $25 is for." | Whether the minimum is read |
| Email, saved | "What would you do next?" | The intended tap, or a different path |
| Email, nearby | "What would make you pick one of these?" | Relevance of nearby picks |
| Any | "Is anything confusing or missing?" | Gaps |

### Closing

- "What was most useful?"
- "What would you change first?"
- "How likely are you to use this in the next week, from 1 to 10?"

## Recording behaviour

Log each answer in a table with these columns:

| Session | Step | Expected answer (written before) | Actual | Matched? | Note |
|---|---|---|---|---|---|

Also log any benefit the participant names that the design does not mention, and any value they put on it in their own words. Do not convert value into a price claim without a participant's own figure.

## Iteration log

| Round | Participants | Changes made | Matched expectations | Date |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

## Launch gate

The journey goes live only when:

1. The automated checks in [verification.md](verification.md) all pass.
2. Each P1 entry in [gaps.md](gaps.md) is closed or has a recorded decision.
3. At least one round of five sessions has run, with recordings and the log above filled in.
4. The saved-restaurant email meets the 10-of-15 rule on its key steps, or the change it needs is in the decisions log.
