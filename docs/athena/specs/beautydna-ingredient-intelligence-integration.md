# BeautyDNA Ingredient Intelligence Integration

## Source

- Project: athena
- Spec key: beautydna-ingredient-intelligence-integration
- System: BeautyDNA
- GitHub issue: https://github.com/wesleykoki2002-hue/beauty-os/issues/11
- GitHub issue number: 11

## Goal

Connect BeautyDNA recommendations, Beauty Passport explanations, and product page ingredient explanations to one shared ingredient intelligence table.

## Problem

BeautyDNA already has recommendation explanations, but ingredient logic, product page ingredient education, and Beauty Passport explanations need to come from the same intelligence source.

Without one shared ingredient intelligence source, the system can create inconsistent explanations across:

- BeautyDNA recommendations
- Beauty Passport
- Shopify product pages
- product ingredient lists
- routine explanations
- ingredient compatibility guidance

## Core Principle

One ingredient intelligence table should become the shared source of truth for:

- ingredient benefits
- ingredient cautions
- skin concern matching
- skin type matching
- ingredient compatibility
- routine step compatibility
- product recommendation explanations
- Beauty Passport ingredient explanations
- product page ingredient education

## Required Integration Areas

### BeautyDNA Recommendations

BeautyDNA should use ingredient intelligence to explain why a recommended product fits the user.

Examples:

- why this product helps dryness
- why this product fits sensitive skin
- why this product supports barrier repair
- why this product should be avoided for a specific concern
- why this product fits the user's routine step

### Beauty Passport

Beauty Passport should use the same ingredient intelligence data to explain:

- important ingredients in the product
- benefits for the user's skin profile
- cautions for sensitivity, acne, pregnancy, fragrance, alcohol, or comedogenic risk
- compatibility with other products in the routine
- what should not be combined

### Product Pages

Shopify product pages should eventually display ingredient explanations from the same source.

Product pages should be able to show:

- key ingredient benefits
- concern fit
- skin type fit
- cautions
- routine compatibility
- BeautyDNA explanation snippets

## Database Direction

The shared ingredient intelligence table should support fields such as:

- ingredient_name
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

## API Direction

BeautyDNA should expose or consume ingredient intelligence through safe internal APIs.

Expected behavior:

- product DNA includes ingredients
- ingredients are matched against ingredient intelligence
- BeautyDNA recommendation explanation uses matched ingredient facts
- Beauty Passport reads the same matched facts
- product pages can reuse the same explanation snippets
- missing ingredients are flagged for review instead of invented

## Safety Rules

- Do not invent ingredient claims when ingredient intelligence is missing.
- Missing ingredient intelligence should create a review task.
- BeautyDNA, Beauty Passport, and product pages must not use conflicting explanations.
- Ingredient compatibility should be treated as guidance, not medical diagnosis.
- High-risk claims should require human review.

## Acceptance Criteria

- Athena defines the shared ingredient intelligence integration plan.
- BeautyDNA can read ingredient intelligence for recommendation explanations.
- Beauty Passport can use the same ingredient intelligence source.
- Product pages can use the same ingredient intelligence source.
- The integration plan identifies required database fields and API behavior.
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

This integration becomes the foundation for:

- better BeautyDNA recommendation explanations
- Beauty Passport ingredient intelligence
- smarter Shopify product pages
- routine compatibility logic
- ingredient conflict warnings
- future Product Analyzer
- future Beauty Coach explanations