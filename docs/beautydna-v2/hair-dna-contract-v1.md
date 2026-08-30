# BeautyDNA HairDNA / ScalpDNA Contract v1

Build: `BDNA-HAIR-0001`

Contract: `beautydna-hair-dna-contract-v1`

Production adapter: `hair-dna@v1`

Configuration: `beautydna-hair-dna-config-v1`

## 1. Purpose

HairDNA / ScalpDNA v1 provides the production domain adapter and normalized
profile foundation for hair and scalp assessment data.

It is a domain module over the existing reusable BeautyDNA DNA Engine Core.

The governing architecture rule is:

> Engines hold reusable logic. Domain modules hold domain knowledge and
> configuration.

The generic DNA Engine remains responsible for generic validation, deterministic
execution, confidence, provenance, and output construction.

HairDNA owns hair/scalp vocabulary, normalization, dimensions, concern rules,
priority rules, and non-diagnostic caution/referral semantics.

## 2. Domain identity

The canonical production identities are:

- contract: `beautydna-hair-dna-contract-v1`
- adapter key: `hair-dna`
- adapter version: `v1`
- adapter identity: `hair-dna@v1`
- domain key: `hair-dna`
- config version: `beautydna-hair-dna-config-v1`

ScalpDNA is a capability inside HairDNA v1.

It is not a separate adapter, database source of truth, Athena module, or
lifecycle in this build.

## 3. Execution boundary

HairDNA consumers call `executeHairDna()` with a HairDNA contract version and a
generic DNA assessment object.

The HairDNA wrapper pins the shared DNA Engine contract, engine version, adapter
key, and adapter version internally.

Callers do not select arbitrary engine or adapter versions through the HairDNA
v1 boundary.

Unsupported HairDNA contract versions fail closed.

## 4. Required assessment answers

HairDNA v1 requires:

- `scalp_oiliness`
- `scalp_dryness`
- `scalp_sensitivity`
- `flaking`
- `hair_pattern`
- `strand_thickness`
- `density`
- `porosity`
- `damage`
- `heat_exposure`
- `chemical_treatments`
- `breakage`
- `frizz`
- `buildup`
- `wash_frequency_per_week`

Optional fields are:

- `water_hardness`
- `concerns`
- `priorities`
- `scalp_irritation_concern`
- `shedding_concern`
- `red_flag_present`
- generic assessment context
- generic assessment metadata

## 5. Controlled vocabulary

### Severity

Severity-based profile fields use:

- `none`
- `low`
- `moderate`
- `high`
- `severe`

### Hair pattern

- `straight`
- `wavy`
- `curly`
- `coily`

### Strand thickness

- `fine`
- `medium`
- `coarse`

### Density

- `low`
- `medium`
- `high`

### Porosity

- `low`
- `medium`
- `high`

### Chemical treatment history

- `colored`
- `bleached`
- `permed`
- `relaxed`

An empty array represents no declared chemical treatment.

### Water hardness

- `soft`
- `moderate`
- `hard`
- `unknown`

Omitted water hardness becomes `unknown`.

Unknown water hardness does not fabricate a hard-water concern.

## 6. Deterministic normalization

Severity values normalize as follows:

| Value    | Signal |
| -------- | -----: |
| none     |      0 |
| low      |   0.25 |
| moderate |   0.50 |
| high     |   0.75 |
| severe   |   1.00 |

HairDNA v1 uses direct normalized-signal dimensions.

Each scored dimension projects one normalized signal into the shared DNA Engine
using a contribution weight of `100`.

This intentionally avoids inventing cross-signal scientific blend weights that
are not established by the canonical source material.

The resulting 0-100 scores are deterministic profile-state indexes.

They are not clinical measurements, probabilities, diagnoses, or product
recommendation scores.

## 7. HairDNA v1 dimensions

The production configuration contains direct dimensions for:

- scalp oiliness
- scalp dryness
- scalp sensitivity
- scalp flaking
- low-porosity state
- high-porosity state
- hair damage
- heat exposure
- chemical-treatment exposure
- breakage
- frizz
- buildup
- hard-water context
- scalp-irritation safety signal
- shedding safety signal
- explicit red-flag safety signal
- severe-scalp-state safety signal

Hair pattern, strand thickness, density, treatment history, wash frequency,
water-hardness state, user concerns, user priorities, and environmental context
are retained as profile attributes.

## 8. Porosity semantics

Low and high porosity are represented as separate explicit dimensions.

Porosity is not modeled as a single good-to-bad continuum.

Medium porosity therefore does not imply either a low-porosity or high-porosity
concern.

## 9. Concern and priority rules

Concern and priority thresholds are deterministic operational rules for HairDNA
v1.

They exist so equivalent versioned inputs produce equivalent profile evidence.

They are not clinical thresholds.

They do not authorize recommendation ranking, product eligibility, diagnosis, or
medical treatment.

## 10. Safety boundary

HairDNA / ScalpDNA is non-diagnostic.

Moderate-or-higher scalp sensitivity or flaking enters conservative `caution`
handling.

An explicit scalp-irritation concern enters `caution` handling.

An explicit shedding concern enters `referral` handling.

An explicit red flag enters `referral` handling.

A severe scalp-sensitivity or flaking state enters `referral` handling.

These states represent conservative profile evidence only.

HairDNA does not:

- diagnose a disease
- determine a medical cause
- prescribe treatment
- make a hair-loss diagnosis
- convert dandruff/flaking into medical certainty
- infer a disease from a cosmetic profile

The calling assessment layer is responsible for deciding whether its own
evidence should set `red_flag_present`.

## 11. User concerns and priorities

User-declared concerns and priorities are:

- vocabulary constrained
- de-duplicated
- deterministically sorted
- preserved in profile attributes

They do not directly select products in BDNA-HAIR-0001.

They do not modify recommendation eligibility or ranking in this build.

## 12. Environmental context

Generic assessment context is preserved after validation as JSON-safe data.

Non-JSON-compatible values fail closed.

The HairDNA adapter does not itself calculate external weather conditions, fetch
environmental data, or call another service.

## 13. Provenance

Normalized HairDNA data records:

- HairDNA contract version
- adapter key
- adapter version
- adapter identity
- HairDNA configuration version
- vocabulary basis
- scoring semantics
- non-diagnostic boundary

The shared DNA Engine adds its own generic engine-level provenance and
confidence information.

## 14. Persistence boundary

BDNA-HAIR-0001 introduces:

- no database migration
- no dedicated HairDNA table
- no dedicated ScalpDNA table
- no new database source of truth

Existing generic BeautyDNA assessment, answer, profile, score, and Passport
persistence boundaries remain authoritative for later integration.

This module is domain logic only.

## 15. Recommendation separation

BDNA-HAIR-0001 does not implement or modify:

- Recommendation Engine ranking
- Recommendation Engine eligibility
- product matching
- Routine Builder
- recommendation explanations
- recommendation customer experience

HairDNA profile evidence may be consumed by those systems later under their own
governed contracts.

## 16. Commerce separation

BDNA-HAIR-0001 does not implement or modify:

- Shopify
- carts
- checkout
- product linkage
- live commerce
- recommendation-ready product state

## 17. Customer-experience separation

BDNA-HAIR-0001 does not implement:

- HairDNA assessment UI
- customer dashboard
- Passport UX
- SkinDNA
- FaceDNA
- BodyDNA
- MakeupDNA

## 18. Database impact

Beauty database access for this implementation package is:

`NONE`

Beauty database writes are:

`0`

Database migrations are:

`0`

## 19. Production source

Production adapter:

`supabase/functions/_shared/beautydna-hair-dna/adapter.ts`

Production tests:

`supabase/functions/_shared/beautydna-hair-dna/adapter_test.ts`

## 20. Acceptance proof

The HairDNA production tests must prove:

- stable production identity
- deterministic normalization
- deterministic execution through DNA Engine Core
- profile attribute preservation
- oily-scalp behavior
- dry/sensitive-scalp behavior
- damage/breakage behavior
- porosity/frizz behavior
- buildup/hard-water behavior
- severe-scalp referral handling
- shedding referral handling
- explicit red-flag referral handling
- unknown-water-hardness safety
- unsupported contract failure
- malformed categorical input failure
- malformed wash-frequency failure
- malformed treatment-vocabulary failure
- malformed safety-flag failure
- non-JSON environmental-context failure

The generic DNA Engine Core remains domain-agnostic and unchanged.

## 21. Governing interpretation

The HairDNA / ScalpDNA vocabulary is grounded in the canonical Beauty
Intelligence source specification.

Operational normalization and thresholds introduced in this contract are
versioned implementation semantics.

They must not be represented as clinical scoring cutoffs or medical claims.

The module exists to provide stable, deterministic hair/scalp profile evidence
for later governed BeautyDNA capabilities.
