# Beauty Intelligence JSON-to-Supabase Field Mapping

| JSON section | Primary table |
|---|---|
| `ingredient` | `beautydna_ingredient_intelligence` |
| `aliases[]` | `beautydna_ingredient_aliases` |
| `functions[]` | `beautydna_ingredient_functions` |
| `formulation_properties` | `beautydna_ingredient_formulation_properties` |
| `claims[]` | `beautydna_ingredient_claims` |
| `concentration_rules[]` | `beautydna_ingredient_concentration_rules` |
| `profile_fit[]` | `beautydna_ingredient_profile_fit` |
| `environment_fit[]` | `beautydna_ingredient_environment_fit` |
| `safety_profile[]` | `beautydna_ingredient_safety_profiles` |
| `product_role_fit[]` | `beautydna_ingredient_product_role_fit` |
| `regulatory_status[]` | `beautydna_ingredient_regulatory_status` |
| `interactions[]` | `beautydna_ingredient_compatibility_rules` |
| `sources[]` | `beautydna_ingredient_evidence` |
| customer explanations | `beautydna_ingredient_localizations` |
| full original object | `beautydna_ingredient_research_payloads.payload` |
| approved snapshots | `beautydna_ingredient_versions` |

## Promotion rule

A staged payload must not automatically make an ingredient customer-usable.

Recommended promotion gates:

1. JSON validation passes.
2. Canonical identity and aliases are verified.
3. Main functions and claims have evidence.
4. Japan, Brazil, EU and US regulatory records are dated.
5. Concentration statements are contextual, not universal.
6. Interaction rules distinguish formulation, routine and tolerability contexts.
7. Portuguese, English and Japanese explanations avoid absolute safety or efficacy language.
8. A human reviewer is recorded.
9. The approved version is snapshotted.
10. Only then set `review_status = 'approved'` and `customer_usable = true`.

## Why raw payloads are retained

The original JSON preserves the exact research output, source references and quality-control
state. Normalized tables power search and recommendations; the raw payload provides auditability
and makes it possible to reprocess records when the schema or controlled vocabulary changes.
