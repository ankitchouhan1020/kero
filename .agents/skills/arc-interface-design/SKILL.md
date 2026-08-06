---
name: arc-interface-design
description: Applies Arc and The Browser Company’s interface-design philosophy without copying Arc’s UI. Use when designing or reviewing tabs, sidebars, navigation, command surfaces, onboarding, personalization, progressive disclosure, context switching, or interaction polish.
---

# Arc-Inspired Interface Design

Use Arc as a source of questions and tradeoffs, not as a component library. The product’s own purpose, users, platform conventions, and identity win whenever Arc’s choices conflict with them.

## Start Here

Before drawing UI, write four sentences:

1. **User goal:** what is the person trying to accomplish, independent of the current screen or content type?
2. **Emotional target:** should this moment feel calm, oriented, confident, safe, or delighted?
3. **Core promise:** what one improvement makes learning a new model worthwhile?
4. **Safety invariant:** what state, work, ordering, or identity must never be lost or changed implicitly?

If the core promise is vague, do not redesign the navigation yet.

## Design Workflow

### 1. Model the user’s world

Name the durable objects users already think in: projects, tasks, documents, conversations, sessions, collections, or another observed unit.

- Organize around goals and work, not implementation or content categories.
- Keep identity, ordering, names, and placement user-owned.
- Do not create a hierarchy merely because the data model permits one.
- A persistent object must be easy to recognize, recover, and search.

### 2. Run the Tuesday-morning test

Ask whether an existing user could adopt the proposal during active work without stopping to relearn routine actions.

Keep familiar platform behavior for ordinary selection, menus, windows, keyboard focus, close, drag, search, and accessibility. Improve these with craft rather than renaming them.

### 3. Set a novelty budget

Spend novelty only on the product’s differentiated promise. Every new gesture, hidden state, custom control, or unfamiliar noun consumes the budget.

For each novelty, require:

- a clear benefit above the familiar pattern;
- an obvious cue or a meaningful early win;
- keyboard and assistive-technology equivalents;
- evidence that it removes more complexity than it adds.

### 4. Make one route obvious

Map every route to create, find, switch, inspect, move, recover, and close.

- Keep one obvious primary route per task.
- Remove duplicate UI only when it does not serve a distinct context.
- Reveal secondary actions when hover, focus, selection, or context demonstrates intent.
- Never hide the common action or rely on hover alone.
- Search should use the same nouns and identities as visible navigation.

### 5. Preserve continuity

Treat restoration and background continuity as interface behavior.

- Never lose active work, unsaved edits, selection, or user ordering.
- Prefer reversible cleanup over destructive neatness.
- Do not automatically move, regroup, rename, archive, or focus durable work because status changed.
- Make behavior coherent across windows, devices, and contexts; avoid local fixes that create global ambiguity.

### 6. Add fingerprints deliberately

Craft should communicate purpose or care.

- Use personality at meaningful boundaries: creation, successful completion, recovery, or a rare reveal.
- Keep frequent keyboard switching immediate and unanimated.
- Let one-off moments be authored, but keep shared controls behaviorally consistent.
- Personalization should increase ownership without making defaults unclear.
- Color, motion, and materials must never carry meaning alone.

### 7. Verify in real density

Prototype with restored, messy data—not three ideal rows.

Check:

- minimum supported width and window size;
- many items, long names, and duplicate names;
- mixed content and status states;
- hidden navigation and multiple windows;
- keyboard-only use, screen readers, reduced motion, and increased contrast;
- relaunch, crash recovery, and safe close.

## Arc Patterns: Probes, Not Defaults

- **Sidebar tabs:** useful when durable items need scanning and direct manipulation; harmful when rows become anonymous or cramped.
- **Spaces:** useful only when people repeatedly maintain distinct contexts; do not assume hierarchy creates value.
- **Command bar:** useful as one mental model for finding and acting, but not as a hiding place for common actions.
- **Persistence:** valuable when the product remembers work safely; dangerous when contexts disagree about ownership.
- **Automatic archiving:** acceptable only for low-stakes, reversible clutter. Never infer that inactivity means work is disposable.
- **Split view:** an optional arrangement tool, not proof that every content type should share one cramped canvas.
- **Unboxing:** justified only when unavoidable novelty needs teaching. Teach through a useful personal result, not a tour.

## Review Questions

1. What feeling and user goal does this serve?
2. Which part spends the novelty budget?
3. What familiar behavior remains intact?
4. Is there one obvious route for the common task?
5. Can users recover every state-changing action?
6. Does the model still work with real density and narrow widths?
7. Is delight reinforcing value, or decorating confusion?
8. Are we copying Arc’s answer instead of applying its reasoning?
