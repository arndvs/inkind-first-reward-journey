# Docs

Working documentation for the first-reward journey: how it is designed, what the current design says, what the repo implements, which decisions are made and which are still open, and how to check it.

## Read in this order

1. [process.md](process.md): the eight stages used to design a journey like this one, each with exit criteria and the place it lives in this repo.
2. [journey-spec.md](journey-spec.md): the current design. Problem, entities, flow, rules and where each is enforced, screen contract, attributes.
3. [decisions.md](decisions.md): decisions already made, and decisions still needed from the business.
4. [gaps.md](gaps.md): the register of gaps, with evidence, impact, the fix, and status.
5. [customer-validation.md](customer-validation.md): the plan for testing the design with real people before launch.
6. [verification.md](verification.md): how to rerun every check, the last recorded results, and what was not run.
7. [change-log.md](change-log.md): the most recent change, step by step, with the failing test for each slice and the defects found along the way.

## Status labels

- **Built**: implemented in code and covered by a check in this repo.
- **Designed**: specified here, but configured in Braze's UI or outside the repo, so this repo cannot verify it.
- **Open**: a gap or decision with no change yet.
- **Deferred**: intentionally not in the current version, with the reason recorded.

## Scope

- All data is fictional. Names, IDs, endpoints, and amounts are illustrative.
- Braze Canvases are built in Braze's UI. This repo documents them; it does not export them.
- The inKind app is outside this repo. Its screens, sign-up, and landing page are not specified here.
- Nothing in this repo sends a message. The Rails backend runs in record mode.
