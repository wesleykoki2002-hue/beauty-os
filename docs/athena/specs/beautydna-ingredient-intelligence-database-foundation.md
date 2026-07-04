# BeautyDNA Ingredient Intelligence Database Foundation

## Source

- Project: athena
- Spec key: beautydna-ingredient-intelligence-database-foundation
- System: BeautyDNA
- GitHub issue: https://github.com/wesleykoki2002-hue/beauty-os/issues/13
- GitHub issue number: 13

## Goal

Build the core ingredient intelligence database foundation that becomes the shared source of truth for BeautyDNA explanations, Beauty Passport, product pages, and compatibility logic.

## Problem

BeautyDNA needs a real ingredient intelligence table before recommendations, product pages, and Beauty Passport can produce consistent ingredient-based explanations.

Without this foundation, ingredient logic can become scattered across:

- BeautyDNA recommendation explanations
- Beauty Passport
- Shopify product pages
- Product DNA
- Product Analyzer
- Beauty Coach
- manual product research notes

## Core Database Direction

The shared ingredient intelligence schema should support:

- ingredient names
- aliases
- ingredient categories
- benefit tags
- concern tags
- skin type fit
- sensitivity cautions
- comedogenic risk
- fragrance relevance
- alcohol relevance
- pregnancy caution
- compatibility logic
- explanation text
- evidence level
- human review status

## Suggested Table

Main table:

- beautydna_ingredient_intelligence

Suggested supporting tables later:

- beautydna_ingredient_aliases
- beautydna_ingredient_compatibility_rules
- beautydna_ingredient_review_queue
- beautydna_product_ingredient_matches

## Required Fields

Recommended foundation fields:

- id
- ingredient_name
- normalized_ingredient_name
- ingredient_aliases
- ingredient_category
- benefit_tags
- concern_tags
- skin_type_fit
- avoid_for_concerns
- sensitivity_risk
- comedogenic_risk
- fragrance_related
- alcohol_related
- pregnancy_caution
- barrier_support
- acne_relevance
- pigmentation_relevance
- aging_relevance
- dryness_relevance
- oiliness_relevance
- compatibility_notes
- avoid_combining_with
- explanation_short
- explanation_long
- evidence_level
- source_notes
- review_status
- created_at
- updated_at

## Review Status Logic

Every ingredient should have a review status.

Recommended statuses:

- draft
- needs_review
- approved
- rejected
- deprecated

BeautyDNA should only use approved ingredient intelligence for customer-facing explanations unless an admin explicitly enables review mode.

## Safety Rules

- Do not invent ingredient claims when ingredient intelligence is missing.
- Missing ingredient intelligence should create a review task.
- High-risk claims should require human review.
- Compatibility warnings should be educational guidance, not medical diagnosis.
- Pregnancy-related caution should be conservative.
- Ingredient explanations should not conflict across BeautyDNA, Beauty Passport, and product pages.

## Future API Direction

BeautyDNA APIs should eventually be able to:

- read product ingredient lists
- normalize ingredient names
- match ingredients to ingredient intelligence
- return benefits and cautions
- return concern-based explanations
- return compatibility warnings
- flag missing ingredient intelligence
- support Beauty Passport explanations
- support Shopify product page snippets

## Acceptance Criteria

- Athena defines the ingredient intelligence database foundation.
- The schema supports benefits, cautions, compatibility, concern matching, and explanation text.
- The schema can be used by BeautyDNA recommendation explanations.
- The schema can be used by Beauty Passport and product pages.
- Missing or uncertain ingredient intelligence can be flagged for human review.
- The spec can complete the full Athena GitHub loop.

## Definition of Done

- GitHub issue is created and linked.
- Branch is created.
- Spec documentation is committed.
- PR is created, synced, merged, and logged.
- Issue is closed.
- Branch is deleted or synced as deleted.
- Full loop summary returns completed.

## Long-Term Direction

This database foundation becomes the base for:

- Product DNA
- Ingredient Intelligence
- BeautyDNA recommendation explanations
- Beauty Passport
- Shopify ingredient explanations
- Product Analyzer
- Beauty Coach
- routine compatibility checks
- product safety and caution flags