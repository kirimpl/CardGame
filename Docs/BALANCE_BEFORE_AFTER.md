# Balance Pass: Before/After Tracking

Use this file after each pass to keep reproducible evidence.

## Template

### Pass Name
- Date:
- Goal:
- Files changed:

### Simulation Input
- Runs per floor:
- Floors:
- Mode(s): `mixed/normal/elite`
- Seed policy: `fixed/random`

### Before
- Key metrics:
  - Early floors:
  - Mid floors:
  - Late floors:

### After
- Key metrics:
  - Early floors:
  - Mid floors:
  - Late floors:

### Decision
- Keep / Revert / Iterate
- Next pass scope:

---

## Current Notes
- Merchant now has:
  - reroll with escalating cost,
  - pin/unpin on offers,
  - purge section toggle.
- Effect handling uses shared `StatusSystem`.
- Intent and tooltip readability improved (payload + stack model).
