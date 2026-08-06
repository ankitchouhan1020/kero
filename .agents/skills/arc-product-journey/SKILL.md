---
name: arc-product-journey
description: Uses Arc and The Browser Company’s product journey to guide high-risk UX redesigns, prototypes, migrations, feedback interpretation, and rollout decisions. Use when rethinking a core mental model, choosing between familiar and novel navigation, evaluating feedback or metrics, planning migration, or deciding whether to evolve, reverse, or remove a feature.
---

# Arc-Inspired Product Journey

This skill governs how to reach a redesign decision, not what Arc-shaped UI to ship. The product’s own purpose, users, constraints, and evidence remain authoritative.

Keep hypotheses, decisions, evidence, blockers, and follow-up work in the project’s durable tracking system so a long redesign survives context resets.

## The Core Posture

Hold these together:

- **Start with “what could be?”** Question inherited assumptions and explore materially different models.
- **Assume you do not know.** Prior expertise informs hypotheses, not conclusions.
- **Optimize for a feeling.** Choose a human outcome as the north star.
- **Use behavior to stay honest.** Metrics and observation can invalidate a beloved answer.
- **Protect coherence.** A local complaint is not permission to break the whole mental model.

## Redesign Process

### Phase 1: Establish the truth

Create or claim a durable work item before implementation. Record:

- the observed user problem, not the requested widget;
- the current mental model and its invariants;
- real density and restoration behavior;
- duplicate routes, accidental loss, and common confusion;
- which users are fresh, occasional, or expert;
- baseline signals: time to find or switch, recovery failures, feature use, and qualitative feeling.

Distinguish direct observation, user report, analytics, and team intuition.

### Phase 2: Define the bet

Write:

- **Emotional target** — calm, confident, oriented, safe, joyful, or another precise feeling.
- **Differentiated promise** — the step-function value worth changing behavior for.
- **Tuesday-morning familiarity** — routine behavior that must remain recognizable.
- **Novelty budget** — the small set of new concepts users must learn.
- **Safety invariants** — state and agency the redesign cannot violate.

If the differentiated promise is only “cleaner,” “more scalable,” or “like Arc,” stop.

### Phase 3: Go wide, concretely

Prototype at least three genuinely different mental models before polishing one. Include the familiar or obvious solution as a serious candidate.

Prototype with working interactions and realistic restored data. Static ideal-state mockups hide switching, focus, overflow, and recovery failures.

For each model, document:

- primary object and hierarchy;
- create, find, switch, close, and recover flows;
- multi-context and relaunch semantics;
- novice cost and expert ceiling;
- what it deletes from the current model;
- what can fail or be misunderstood.

### Phase 4: Test the system, not one screen

Test fresh and expert users on end-to-end tasks. Ask them to explain where work lives and what closing or switching will do before they act.

Evaluate:

- recognition and orientation;
- speed after first use and after repetition;
- accidental state loss;
- ability to recover;
- context-switching confidence;
- narrow and high-density behavior;
- whether the intended feeling is actually present.

Watch what people do. Treat praise, complaints, and feature requests as clues to underlying needs.

### Phase 5: Decide with tensions visible

Use evidence without voting by metric.

- Metrics test whether the product works; they do not generate the vision.
- Vocal experts can identify deep system value but may not represent first-day comprehension.
- Low feature usage may indicate weak value, poor discovery, excess novelty, or a niche expert job. Investigate before deleting.
- A familiar fix can lower onboarding cost while destroying differentiation or coherence.
- A delightful feature can still be the wrong product foundation.

Record the decision and rejected alternatives, including what evidence would reverse it.

### Phase 6: Migrate safely

A core model redesign needs:

- deterministic migration preserving IDs, names, order, selection, layouts, history, and unsaved work;
- a rollback path while the model is still uncertain;
- compatibility for integrations and restored state;
- explicit handling for old and partial state;
- communication timed to usable details, not aspiration alone.

Do not force people to reconstruct their workspace to experience the redesign.

### Phase 7: Roll out and stop adding

Release the smallest coherent model, not a scaffold for every imagined extension. Measure comprehension and continuity before adding taxonomy, groups, automation, or customization.

Once the core works, prefer papercut removal, speed, safety, and stability over a stream of novelty. Mature users often value software that stops changing underneath them.

## Lessons From Arc’s Journey

- Arc proved that a strong point of view can create devotion and expand what a browser can feel like.
- It also accumulated a novelty tax and feature breadth without one sufficiently clear mass-market value.
- Its Today-tab sync reversal shows why complaint-driven familiarity can weaken an interconnected model. Evaluate the whole system, including restore and data-loss behavior.
- Arc Search showed the power of narrowing a job and removing taps and clutter.
- Dia’s reset preserved familiar mechanics so novelty could be spent on immediate differentiated value.
- Beloved features should be translated through current principles, not copied into a new architecture.
- The team’s retrospective emphasizes admitting revealed behavior sooner, communicating truth with useful detail, and treating performance and security as foundations.

## Required Decision Output

When proposing a redesign, produce:

1. problem and evidence;
2. emotional target and differentiated promise;
3. candidate mental models;
4. novelty budget and familiar anchors;
5. safety invariants;
6. prototype and test results;
7. chosen model and rejected alternatives;
8. migration, rollback, and validation plan;
9. open work and dependencies.

Do not jump from inspiration to implementation.
