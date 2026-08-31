# BeautyDNA SkinDNA MVP Profile Bridge Contract v1

Build: `BDNA-SKIN-0001`

Contract: `beautydna-skin-dna-mvp-contract-v1`

Production adapter: `skin-dna@v1`

Configuration: `beautydna-skin-dna-mvp-config-v1`

Questionnaire: `beautydna-skin-dna-mvp-questionnaire-v1`

## 1. Purpose

SkinDNA MVP v1 provides the smallest production profile bridge required for the
Hanna DNA launch path.

It converts a short, deterministic cosmetic skin questionnaire into profile
evidence compatible with the existing BeautyDNA recommendation and explanation
boundary.

The intended launch path is:

`short questionnaire -> SkinDNA profile -> recommendation-generate -> Product DNA + Ingredient Intelligence -> recommendation-explain -> Shopify result flow`

This build does not rebuild any downstream recommendation, ingredient, product,
explanation, Passport, or commerce component.

SkinDNA is a domain module over the existing reusable BeautyDNA DNA Engine Core.

The governing architecture rule is:

> Engines hold reusable logic. Domain modules hold domain knowledge and
> configuration.

The generic DNA Engine remains responsible for generic deterministic execution,
dimension/concern evaluation, confidence, generic provenance, validation, and
output construction.

SkinDNA owns the launch-focused questionnaire vocabulary, deterministic
normalization, skin profile derivation, safety/caution/referral semantics, and
the downstream recommendation-profile bridge.

## 2. Domain identity

Canonical production identities are:

- contract: `beautydna-skin-dna-mvp-contract-v1`
- adapter key: `skin-dna`
- adapter version: `v1`
- adapter identity: `skin-dna@v1`
- domain key: `skin-dna`
- config version: `beautydna-skin-dna-mvp-config-v1`
- questionnaire version: `beautydna-skin-dna-mvp-questionnaire-v1`

The MVP profile bridge is explicitly versioned independently from any future
long-term SkinDNA ontology.

## 3. Execution boundary

SkinDNA consumers may call `executeSkinDnaMvp()` with:

- the exact SkinDNA MVP contract version; and
- a generic DNA assessment object containing the SkinDNA questionnaire in
  `assessment.answers`.

The SkinDNA wrapper pins the shared DNA Engine contract, engine version, adapter
key, and adapter version internally.

Callers do not select arbitrary engine or adapter versions through the SkinDNA
MVP v1 boundary.

Unsupported SkinDNA contract versions fail closed.

## 4. Questionnaire contract

SkinDNA MVP v1 uses 12 launch-focused inputs.

All 12 fields are required by the current deterministic questionnaire contract:

1. `oiliness`
2. `dryness`
3. `sensitivity`
4. `concerns`
5. `concern_priorities`
6. `acne_prone`
7. `avoid_ingredients`
8. `pregnancy`
9. `preferred_steps`
10. `routine_complexity`
11. `active_allergy_reaction`
12. `red_flag_present`

Generic assessment context and metadata may still be supplied through the
existing generic DNA assessment boundary.

## 5. Severity vocabulary

The following fields use the versioned severity vocabulary:

- `oiliness`
- `dryness`
- `sensitivity`

Allowed values are:

- `none`
- `low`
- `moderate`
- `high`
- `severe`

Severity values normalize to deterministic shared-engine signals:

| Value    | Signal |
| -------- | -----: |
| none     |      0 |
| low      |   0.25 |
| moderate |   0.50 |
| high     |   0.75 |
| severe   |   1.00 |

These values are operational profile-state indexes.

They are not clinical measurements, probabilities, diagnoses, or medical
severity scores.

## 6. Skin-type derivation

Skin type is deterministically derived from the oiliness/dryness balance.

`moderate`, `high`, and `severe` count as an active state for this MVP rule.

The resulting SkinDNA profile uses one of:

- `normal`
- `dry`
- `oily`
- `combination`

Rules are:

| Oiliness active | Dryness active | Skin type     |
| --------------- | -------------- | ------------- |
| no              | no             | `normal`      |
| no              | yes            | `dry`         |
| yes             | no             | `oily`        |
| yes             | yes            | `combination` |

This is an operational questionnaire normalization rule, not a medical skin
classification.

## 7. Sensitivity semantics

The downstream recommendation profile currently accepts:

- `normal`
- `sensitive`

SkinDNA maps sensitivity as follows:

- `none` -> `normal`
- `low` -> `normal`
- `moderate` -> `sensitive`
- `high` -> `sensitive`
- `severe` -> `sensitive`

Moderate/high sensitivity remains recommendation-eligible with caution.

Severe sensitivity enters referral handling and blocks direct recommendation
profile creation through `createSkinDnaRecommendationProfile()`.

## 8. Canonical concern vocabulary

SkinDNA MVP accepts and normalizes to these concern keys:

- `acne`
- `barrier_support`
- `clogged_pores`
- `dehydration`
- `dryness`
- `dullness`
- `fine_lines`
- `hyperpigmentation`
- `oiliness`
- `redness`
- `sensitivity`
- `texture`
- `uneven_tone`

The MVP accepts a constrained alias layer for common questionnaire wording such
as breakouts, dark spots, blackheads, barrier repair, pigmentation, and uneven
tone.

Unsupported concern vocabulary fails closed.

## 9. Concern limits and priorities

`concerns` may contain at most five entries.

`concern_priorities` may contain at most three entries.

Every priority must also exist in the declared concern set after canonical alias
normalization.

Priority order is preserved.

The downstream `skin_concerns` list is de-duplicated and deterministically
sorted after declared and derived concerns are combined.

SkinDNA may derive:

- `dryness` from moderate-or-higher dryness;
- `oiliness` from moderate-or-higher oiliness;
- `sensitivity` from moderate-or-higher sensitivity; and
- `acne` when `acne_prone` is true.

Concern and priority rules are deterministic operational profile rules.

They do not perform product ranking or diagnosis.

## 10. Acne / breakout tendency

`acne_prone` is a required customer questionnaire boolean.

When true:

- downstream `acne_prone` is true; and
- `acne` is added to canonical SkinDNA concerns.

The field represents customer-declared breakout tendency for cosmetic
personalization.

It does not diagnose acne or assign medical severity.

## 11. Customer-declared ingredients to avoid

`avoid_ingredients` is a required array.

It may contain at most 32 entries.

Entries are:

- string-only;
- trimmed;
- lowercased;
- whitespace-normalized;
- de-duplicated;
- deterministically sorted;
- limited to 80 characters per entry; and
- rejected when they contain control characters.

A non-empty declared avoid list adds conservative caution context.

SkinDNA does not determine whether the declaration is a medically confirmed
allergy.

The normalized list is passed through to the existing downstream
`avoid_ingredients` profile field.

## 12. Pregnancy caution context

`pregnancy` is a required customer-declared boolean.

When true, it:

- passes through to the existing downstream `pregnancy` profile field; and
- adds a caution reason.

The canonical semantic marker is:

`customer_declared_caution_context_only`

Pregnancy handling in SkinDNA MVP is not medical advice, diagnosis, treatment,
or a claim that SkinDNA can establish product safety during pregnancy.

Existing downstream safety logic remains authoritative for its own governed
behavior.

## 13. Routine preferences

`preferred_steps` is a required array with at most 12 entries.

Steps are normalized to lowercase underscore tokens while preserving first-seen
order and removing duplicates.

SkinDNA does not invent additional routine steps.

`routine_complexity` is required and accepts:

- `minimal`
- `standard`
- `extended`

Routine complexity is retained as SkinDNA profile evidence.

The seven-field recommendation bridge currently passes `preferred_steps`
downstream but does not pass `routine_complexity` as a recommendation-profile
field.

## 14. Seven-field downstream recommendation bridge

The SkinDNA MVP bridge emits exactly these existing downstream-compatible
fields:

1. `skin_type`
2. `skin_concerns`
3. `sensitivity_level`
4. `acne_prone`
5. `pregnancy`
6. `avoid_ingredients`
7. `preferred_steps`

`createSkinDnaRecommendationProfile()` returns this seven-field object only when
the SkinDNA safety state is not referral-blocked.

This function does not execute product ranking itself.

## 15. Safety classification

SkinDNA MVP uses three non-diagnostic safety classifications:

- `standard`
- `caution`
- `referral`

Recommendation statuses are:

- `ready`
- `ready_with_cautions`
- `blocked`

### Standard

No configured caution or referral condition is present.

### Caution

Caution may be added for:

- moderate or high sensitivity;
- customer-declared pregnancy context; or
- a non-empty customer-declared avoid-ingredient list.

### Referral

Referral is triggered by:

- `red_flag_present = true`;
- `active_allergy_reaction = true`; or
- `sensitivity = severe`.

Referral always resolves recommendation status to `blocked`.

The generic DNA Engine can still execute the versioned assessment so referral
evidence remains deterministic and machine-visible.

Direct recommendation-profile creation is blocked for referral-class input.

## 16. Safety boundary

SkinDNA MVP is cosmetic and non-diagnostic.

It does not:

- diagnose a skin disease;
- identify a medical cause;
- determine whether a reaction is an allergy;
- prescribe treatment;
- establish pregnancy safety;
- establish whether a symptom requires emergency care;
- infer a medical condition from questionnaire answers.

`active_allergy_reaction` and `red_flag_present` are conservative
caller/customer inputs that force limitation/referral behavior.

The calling customer-assessment experience is responsible for wording and
collecting those flags safely.

A referral result means the SkinDNA cosmetic recommendation bridge is blocked.

It is not itself a medical diagnosis.

## 17. DNA Engine dimensions

The SkinDNA MVP adapter projects direct normalized signals into the shared DNA
Engine for:

- skin oiliness;
- skin dryness;
- skin sensitivity;
- acne tendency;
- pregnancy caution context;
- avoid-ingredient caution context;
- safety caution; and
- safety referral.

Direct dimensions use the generic engine with contribution weight `100`.

This avoids inventing unsupported cross-signal scientific blend weights.

The shared DNA Engine remains domain-agnostic.

## 18. Profile attributes

SkinDNA retains structured profile attributes for:

- contract version;
- questionnaire version;
- adapter identity;
- oiliness/dryness state;
- derived skin type;
- sensitivity/reactivity state;
- downstream recommendation profile;
- concern priorities;
- routine complexity; and
- safety classification/status/reasons.

These attributes are profile evidence for later governed consumers.

They are not a second recommendation engine.

## 19. Provenance

SkinDNA normalization records provenance for:

- SkinDNA contract version;
- questionnaire version;
- adapter key;
- adapter version;
- adapter identity;
- configuration version;
- downstream profile bridge version;
- confidence source;
- generic persistence-reuse boundary;
- FaceDNA/photo requirement boundary; and
- cosmetic non-diagnostic boundary.

The current provenance markers include:

- `beautydna-v2-recommendation-profile-v1`
- `beautydna-dna-engine-core`
- `reuse_generic_assessment_answer_passport`
- `optional_not_required_for_mvp`
- `cosmetic_non_diagnostic`

The shared DNA Engine adds its own generic engine-level provenance and
confidence information.

## 20. Persistence boundary

BDNA-SKIN-0001 introduces:

- no database migration;
- no dedicated SkinDNA table;
- no new RPC;
- no dedicated SkinDNA database source of truth.

The implementation explicitly reuses the existing generic BeautyDNA persistence
boundary:

- `beautydna_assessments`
- `beautydna_assessment_answers`
- `beautydna_passports`

This build does not implement new persistence write-path code.

Later integration may persist SkinDNA evidence through those existing generic
boundaries under the appropriate governed caller.

## 21. Recommendation and explanation separation

BDNA-SKIN-0001 does not rewrite or replace:

- `beautydna-v2-recommendation-generate`
- `beautydna-v2-recommendation-explain`
- Product DNA
- Ingredient Intelligence

The SkinDNA MVP exists to provide the existing recommendation/explanation flow
with the profile fields it already understands.

Product eligibility, ranking, ingredient conflict logic, and explanation logic
remain owned by their existing governed components.

## 22. FaceDNA / photo separation

FaceDNA/photo analysis is not mandatory for SkinDNA MVP v1.

The provenance boundary records:

`optional_not_required_for_mvp`

BDNA-SKIN-0001 does not rebuild FaceDNA, perform image analysis, or require a
customer photo before the questionnaire profile can execute.

Future FaceDNA evidence may be governed separately.

## 23. Commerce separation

BDNA-SKIN-0001 does not implement or modify:

- Shopify product creation;
- live Shopify product linkage;
- catalog synchronization;
- cart behavior;
- checkout behavior; or
- recommendation-ready commerce state.

The existing Shopify result flow remains downstream.

Real Shopify product linkage is a separate governed commerce concern.

## 24. Customer-experience separation

BDNA-SKIN-0001 does not implement:

- the final customer questionnaire UI;
- Passport/dashboard UX;
- a full customer dashboard;
- full User & Context Intelligence;
- BodyDNA;
- MakeupDNA; or
- HairDNA changes.

This build is the production profile bridge required before those broader UX
surfaces.

## 25. Database impact

Beauty OS / BeautyDNA project ref:

`hidsyvanaipxxyyhjgmc`

Beauty database access during this implementation package:

`NONE`

Beauty database writes:

`0`

Dedicated SkinDNA database objects:

`0`

Database RPCs added:

`0`

Database migrations added:

`0`

Athena remains the governance/control-plane database only.

## 26. Production source

Production adapter:

`supabase/functions/_shared/beautydna-skin-dna/adapter.ts`

Production tests:

`supabase/functions/_shared/beautydna-skin-dna/adapter_test.ts`

Repository-owned contract documentation:

`docs/beautydna-v2/skin-dna-mvp-contract-v1.md`

## 27. Acceptance proof

The SkinDNA production tests prove:

- stable production identity;
- deterministic questionnaire normalization;
- deterministic execution through the shared DNA Engine;
- exactly seven downstream recommendation fields;
- all four MVP skin-type balance outcomes;
- sensitivity-to-downstream-profile mapping;
- caution handling for moderate sensitivity;
- acne-prone mapping and acne concern derivation;
- concern alias normalization;
- concern-priority preservation;
- avoid-ingredient normalization and caution context;
- pregnancy customer-declared caution semantics;
- preferred-routine-step normalization;
- severe-sensitivity referral blocking;
- active-allergy-reaction referral blocking;
- explicit-red-flag referral handling;
- machine-visible referral evidence through the DNA Engine;
- unsupported contract failure;
- unsupported concern failure;
- undeclared priority failure;
- malformed categorical input failure;
- malformed safety boolean failure;
- provenance/profile-attribute preservation.

The current SkinDNA suite contains 18 Deno tests.

The generic DNA Engine Core regression suite contains 16 Deno tests.

Both suites must pass before commit authorization.

## 28. Governing interpretation

SkinDNA MVP v1 is intentionally narrow.

It exists to make the launch-critical Hanna DNA path work with the components
already present in BeautyDNA.

Its normalization rules, thresholds, aliases, limits, safety states, and
downstream bridge are versioned implementation semantics.

They must not be represented as clinical scoring cutoffs, medical diagnoses, or
medical advice.

Future expansion of SkinDNA vocabulary, FaceDNA/photo inputs, User & Context
Intelligence, recommendation behavior, persistence structures, or customer UX
requires separate governed evidence and scope.
