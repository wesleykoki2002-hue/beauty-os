# Beauty Intelligence SQL Import Pack v1

## Purpose

This pack establishes the production-ready database foundation for the first 150
Beauty Intelligence ingredients. It follows the attached complete ingredient data
specification and keeps the existing Beauty OS Supabase project as the source of truth.

## Important scope

This package contains:

- A non-destructive schema foundation.
- Controlled vocabularies.
- A 150-ingredient canonical identity seed.
- Alias and Japanese-label normalization seeds.
- A strict JSON research contract.
- A research queue containing all 150 ingredients.
- A raw-payload staging function.
- Validation and coverage queries.

This package does **not** pretend that the full evidence, safety, concentration,
regulatory and interaction research has already been completed for all 150 ingredients.
Those fields remain `needs_review` until evidence-backed research payloads are created,
validated and approved.

## Why this is not one giant SQL file

Identity data, evidence, claims, regulatory rules, concentration rules and interactions
have different review and versioning requirements. Keeping them in normalized tables
prevents accidental overwrites and makes each material claim traceable to evidence.

## Recommended execution order

1. Export a Supabase database backup.
2. Run `000_preflight_and_backup_checks.sql`.
3. Review any duplicate or incompatible-column findings.
4. Run `001_beauty_intelligence_foundation.sql`.
5. Run `002_controlled_vocabularies.sql`.
6. Run `003_core_150_identity_seed.sql`.
7. Run `004_research_payload_staging.sql`.
8. Run `005_validation_and_coverage.sql`.
9. Do not run `006_optional_rls_template.sql` until the application access model is confirmed.

## Research/import workflow

1. Research one ingredient at a time using `beauty_intelligence_ingredient_v1.schema.json`.
2. Store completed payloads through `beautydna_stage_ingredient_payload`.
3. Every generated payload defaults to `needs_review`.
4. Human review verifies identity, sources, regulations and high-impact rules.
5. Approved payloads are promoted to normalized child tables by a reviewed importer.
6. Only approved/current records are exposed to customer-facing recommendation logic.

## Safe defaults used by the seed

- `review_status = 'needs_review'`
- `customer_usable = false`
- `record_status = 'active'`
- No context-free `safe` flag
- No automatic hard compatibility exclusions
- No guessed concentration values
- No assumed regulatory approval

## Files

- `SOURCE_SPECIFICATION.txt`: canonical project specification supplied by the user.
- `000_preflight_and_backup_checks.sql`: checks existing Beauty OS tables and duplicates.
- `001_beauty_intelligence_foundation.sql`: normalized schema and safe column additions.
- `002_controlled_vocabularies.sql`: approved taxonomy terms.
- `003_core_150_identity_seed.sql`: canonical identity and alias seed.
- `004_research_payload_staging.sql`: JSON payload staging and checksum function.
- `005_validation_and_coverage.sql`: QA, completion and launch-readiness queries.
- `006_optional_rls_template.sql`: optional RLS starting point; review before use.
- `beauty_intelligence_ingredient_v1.schema.json`: strict agent/import contract.
- `core_150_identity_seed.json`: machine-readable identity seed.
- `core_150_research_queue.jsonl`: one research task per ingredient.
- `FIELD_MAPPING.md`: how JSON sections map to Supabase tables.

## Final import format

After each research batch is completed and reviewed, create an idempotent SQL batch file
containing the approved payloads. A practical batch size is 5–10 ingredients. This avoids
truncated JSON, unreviewable source lists and silently inconsistent vocabulary values.
