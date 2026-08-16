-- BDNA-PDNA-0001 canonical reproducible audit
-- Target: Beauty OS / BeautyDNA
-- Supabase project ref: hidsyvanaipxxyyhjgmc

with launch(product_id, dna_id) as (
  values
    (
      '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
      '02ac259e-dc07-40c8-9254-c7d22d2fc4df'::uuid
    ),
    (
      '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
      '906e61dd-654d-4086-b185-21bfc6a725b7'::uuid
    ),
    (
      '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
      '19b563e7-c8f5-4768-8e0a-fc9503a5b592'::uuid
    ),
    (
      '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
      '8deca43e-b74b-443d-9f6e-0d2c89e03272'::uuid
    ),
    (
      '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid,
      'e5d97b2f-98b2-469d-94fc-fdb0ad1cd353'::uuid
    )
)
select
  p.id as product_id,
  p.brand,
  p.product_title,
  p.product_name,
  p.category,
  p.product_role,
  p.routine_step,
  p.source_type,
  p.source_key,
  p.approval_status as product_approval_status,
  d.id as product_dna_id,
  d.approval_status as dna_approval_status,
  p.shopify_status,
  p.shopify_product_id,
  p.shopify_variant_id,
  r.ingredient_count,
  r.matched_ingredient_count,
  r.unmatched_ingredient_count,
  r.recommendation_ready,
  d.skin_type_fit,
  d.main_concerns_it_helps,
  d.key_ingredients,
  d.ingredient_flags,
  d.recommended_routine_step,
  d.usage_timing,
  d.sensitivity_risk,
  d.comedogenic_risk,
  d.fragrance_status,
  d.alcohol_status,
  d.pregnancy_caution,
  d.source_summary,
  d.dna_payload -> 'bdna_pdna_0001_review' as governed_review
from launch l
join public.beautydna_products p
  on p.id = l.product_id
join public.beautydna_product_dna d
  on d.id = l.dna_id
 and d.product_id = p.id
left join public.beautydna_v2_product_readiness r
  on r.product_id = p.id
order by p.created_at;

select
  id,
  position,
  ingredient_name,
  normalized_ingredient_name,
  match_status,
  review_status,
  metadata ->> 'held_by_build' as held_by_build,
  metadata ->> 'identity_review_status' as identity_review_status,
  metadata ->> 'ambiguity_reason' as ambiguity_reason
from public.beautydna_product_ingredients
where product_id = '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid
  and match_status = 'unmatched'
order by position;