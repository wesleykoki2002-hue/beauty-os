# BeautyDNA DNA Engine Core Contract v1

Build: `BDNA-DNA-0001 — Reusable DNA Engine Core Foundation`

Canonical contract:

`beautydna-dna-engine-core-contract-v1`

Engine version:

`beautydna-dna-engine-core-v1`

## Architectural boundary

**Engines hold reusable logic. Domain modules hold domain knowledge and
configuration.**

DNA Engine Core is deliberately domain-agnostic. It validates an explicit
versioned adapter, accepts normalized domain signals, performs deterministic
configuration-driven dimension scoring, evaluates generic concern and priority
threshold rules, calculates confidence, and returns a canonical versioned
profile payload with provenance.

Production domain-specific rules do not belong in the core.

## Existing BeautyDNA boundaries reused

The existing BeautyDNA database already supplies structurally sufficient
persistence boundaries for this foundation:

- `beautydna_assessments.answers_payload`
- `beautydna_assessments.score_payload`
- `beautydna_assessment_answers`
- `beautydna_passports.profile_scores`
- `beautydna_passports.passport_payload`

BDNA-DNA-0001 does not create a second assessment/profile source of truth.

No database migration is required by the first engine-core mutation.

## Separation from Recommendation Engine

`beautydna-v2-recommendation-generate` remains the product recommendation
decision layer.

Its product candidate fit weights, routine-step fit, approval/readiness gates,
safety penalties, Product DNA behavior, ranking, and recommendation selection
are not DNA Engine Core responsibilities.

The DNA Engine produces canonical domain profile state. The Recommendation
Engine consumes canonical profile state in a later integration boundary.

## Versioned adapter contract

A domain adapter provides:

- `adapter_key`
- `adapter_version`
- `domain_key`
- `configuration.config_version`
- deterministic `normalize(assessment)` behavior
- normalized numeric signals in the inclusive range `0..1`
- optional domain profile attributes
- optional adapter provenance

The core selects adapters by the exact composite identity:

`adapter_key@adapter_version`

Unknown adapters and unsupported versions fail closed.

## Generic engine behavior

For every configured dimension the core:

1. starts from a configured base score;
2. applies configured weighted normalized signals;
3. clamps to configured minimum and maximum;
4. rounds deterministically.

Concern and priority signals are derived only from generic threshold
configuration.

Confidence is the proportion of configured required signals actually present in
normalized input.

## Deterministic provenance

Successful output contains:

- contract version
- engine version
- domain key
- adapter key/version
- configuration version
- deterministic flag
- stable input fingerprint
- normalized signal keys
- adapter provenance
- canonical profile payload

These fields provide replay/debug/audit identity without embedding production
domain rules in generic engine code.

## Fail-closed behavior

The engine rejects:

- malformed requests
- non-JSON assessment input
- non-finite values
- invalid normalized signals
- malformed configuration
- duplicate adapter identities
- unsupported contract versions
- unsupported engine versions
- unsupported adapters
- unsupported adapter versions

## Domain-agnostic proof

Automated tests use two intentionally synthetic, structurally different
adapters.

The synthetic adapters exist only to prove that the same core can execute
different domain configurations. They are not production BeautyDNA domain
knowledge.

## Out of scope for this foundation mutation

This mutation does not implement:

- production domain scoring adapters
- product recommendation ranking
- product eligibility/readiness
- routine selection
- recommendation explanation
- Passport customer UX
- Shopify commerce behavior
- a new database persistence source

Those remain separate governed module responsibilities.

## Determinism and runtime hardening

The registry captures an immutable snapshot of validated domain configuration at
registration time. Mutation of the caller-owned configuration object after
registration cannot alter engine scoring behavior.

Canonical JSON and deterministic output ordering use explicit ordinal/code-unit
string comparison rather than locale-sensitive comparison.

Optional assessment `assessment_id`, `context`, and `metadata` are validated at
runtime. `context` and `metadata` must be JSON objects when provided.

Adapter `profile_attributes` and `provenance` must be JSON objects when
provided. Malformed adapter output fails closed.

Optional concern and priority rule collections must be arrays when provided.
Malformed rule collections fail with `MALFORMED_CONFIGURATION`.
