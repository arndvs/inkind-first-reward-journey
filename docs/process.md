# Journey design process

The steps used to design a customer journey like this one, in the order they should run. Each stage has an input, an output, exit criteria, and a pointer to where its output lives in this repo. A stage is not done until its exit criteria pass.

Two rules apply across every stage:

- **Record decisions when they are made.** Each choice that changes behaviour goes in [decisions.md](decisions.md) with its reason. Choices recorded afterwards are reconstructions.
- **Log every gap.** Anything a stage cannot close goes in [gaps.md](gaps.md) with its evidence and an owner.

## Stage 1: Problem statement

**Input:** one or more real customer situations (interviews, support tickets, the team's own experience).
**Output:** one pain statement per user type, written in the present tense, describing the situation before any solution.
**Exit criteria:**
- Each user type has a statement.
- No statement describes the product. Solution language moves to the decisions log.
- Each statement says what the person was trying to do, where they were, and what got in the way.

**Repo location:** [journey-spec.md](journey-spec.md) §1.

## Stage 2: Entities and relationships

**Input:** the pain statements.
**Output:** a list of entities (people, places, money, signals, deliveries) and the verbs that connect them.
**Exit criteria:**
- Every verb in the pain statements maps to a relationship or an event. A verb with no producer is flagged.
- Every entity that can be created can also be changed and removed, or the record says why it cannot.
- Every entity is owned by exactly one system for each field.

**Repo location:** [journey-spec.md](journey-spec.md) §2; schema in `rails/db/schema.rb`.

## Stage 3: Flow

**Input:** the entities and the pain statements.
**Output:** the paths a person takes from first contact to the goal, including each branch, each wait, and each exit.
**Exit criteria:**
- Each pain statement can be traced from its first step to its goal through the flow.
- Each branch has a condition and an owner.
- A step that gives value comes before a step that asks for something.
- Timing rules (waits, send times, windows) are written down, with the system that enforces each one.

**Repo location:** [journey-spec.md](journey-spec.md) §3 and §4.

## Stage 4: Attributes

**Input:** the entities and the flow.
**Output:** the attributes each entity needs, each with a type, a source, a V1 or later flag, and the system that holds it.
**Exit criteria:**
- Each entity has a list. Lists are long enough to show what was considered, and deferred attributes are kept.
- Each single-value assumption (one of something per user, one per payment) is confirmed or logged as a decision.
- Attributes that carry personal data are listed, with the decision about whether they leave the warehouse.

**Repo location:** [journey-spec.md](journey-spec.md) §6; [decisions.md](decisions.md).

## Stage 5: Screen contract

**Input:** the flow and the attributes.
**Output:** for each screen or message, three things: what it shows, what the person can do on it, and where each action leads.
**Exit criteria:**
- Every screen answers all three questions.
- Every call to action has a destination. A destination that lives outside the repo is written down.
- The most important action is the most prominent one, and the order is stated.
- Each list item has a short snippet definition: three to five fields that let a person recognise it.

**Repo location:** [journey-spec.md](journey-spec.md) §5.

## Stage 6: Build in chunks

**Input:** the screen contract.
**Output:** the smallest reusable pieces first (tokens, elements, components), then sections and layouts, then the assembled messages.
**Exit criteria:**
- Each piece renders on its own.
- Each control type has one pattern. A new variant is an input, not a copy.
- Each piece states its inputs and outputs.
- Build order is recorded in the decisions log when it departs from this list.

**Repo location:** `liquid/blocks/`, `liquid/README.md`.

## Stage 7: Validate

Validation has three parts. All three must pass before launch.

**7a. Automated checks.** They confirm the build is correct, not that it is wanted.
- Render, parity, and golden tests for each message (`liquid/tests`).
- Payload, outbox, and export tests for the backend (`rails/test`).
- Audience and data-quality checks in the warehouse (`sql/03_checks.sql`).

**7b. Send safety.** Before any send, confirm who can receive it.
- The audience matches the warehouse count, and the gap is explained by missing channel permissions.
- Test sends go only to an internal test group.
- Each message has an abort for missing data.
- Frequency caps and quiet hours are checked.

**7d. Walk the change.** After each build slice, trace the change through the flow in [journey-spec.md](journey-spec.md) section 3. For each message the change touches, check what it says at each step, including any context that was set before the change (a Canvas in its delay, for example). Write a failing test for each gap the walk finds.

**7c. People.** Test the design with prospective customers before launch, following [customer-validation.md](customer-validation.md).
- Each scripted question has a written expected answer before the session.
- The design is treated as validated when enough sessions match the expected behaviour.

**Repo location:** [verification.md](verification.md); [customer-validation.md](customer-validation.md).

## Stage 8: Ship and measure

**Input:** a validated design and a passing check list.
**Output:** a launch with a control group, a named metric, and guardrails.
**Exit criteria:**
- The control group is in place before the first send.
- The primary metric and the guardrails are written down before launch.
- A rollback path is named: how to stop the journey, and what happens to users already in it.

**Repo location:** [journey-spec.md](journey-spec.md) §4 (control group, exit rules); [verification.md](verification.md).

## Running this process on a new journey

1. Write the pain statements from real situations. Do not start from a feature.
2. Build the entity list from the statements. Check every verb.
3. Draw the flow. Trace every statement through it.
4. Fill in attributes. Confirm every single-value assumption.
5. Write the screen contract for each message and screen.
6. Build the smallest reusable pieces first, and render each one.
7. Run the three validation parts. Log each gap.
8. Launch behind a control group. Record the decision and its reason.

Expect to repeat stages 2 to 5 several times. Each repeat should shrink the gap register.

## Worked example: removing a saved restaurant

The clearest example so far is the removal of a saved restaurant. The stage 2 check (every entity that can be created must be changeable and removable) found that saved restaurants could be added but never removed. The steps below follow the stages above; the full record is in [change-log.md](change-log.md).

1. **Stage 2** flagged the gap, and it was recorded as G-01 with a decision (D-03) before any code changed.
2. **Stage 3** traced the removal through the flow: a removal must reach Braze, and it must stop the restaurant from being named later.
3. **Stage 5** wrote the screen contract for the Remove action: one action per saved restaurant, a confirmation message, and a return to the user page.
4. **Stage 6** built the change one slice at a time, each starting with a failing test.
5. **Stage 7** found three problems the design had not covered: a queued job crashed when its record had been removed, a removed restaurant could still be named by a Canvas already in progress, and the CI gem audit failed for a reason unrelated to the change.

The takeaway for the process: the stage 2 check is cheap and catches a whole class of gaps. The stage 7 checks catch what the design missed, so they should run after every build slice, not only at the end.
