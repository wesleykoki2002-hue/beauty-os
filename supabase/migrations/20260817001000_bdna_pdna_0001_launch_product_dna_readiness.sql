begin;

-- ============================================================
-- BDNA-PDNA-0001
-- Launch Product DNA Evidence Review, Approval Cleanup,
-- and Production Recommendation Readiness
--
-- Target: Beauty OS / BeautyDNA
-- Supabase project ref: hidsyvanaipxxyyhjgmc
--
-- No Shopify catalog creation/linkage occurs here.
-- BDNA-ING-0004 ingredient identity outcomes remain untouched.
-- ============================================================

do $bdna_preflight$
declare
  v_count integer;
begin
  select count(*)
  into v_count
  from public.beautydna_products
  where id in (
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
    '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  )
  and approval_status = 'needs_review';

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 preflight failed: expected 5 products in needs_review, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_product_dna
  where id in (
    '02ac259e-dc07-40c8-9254-c7d22d2fc4df'::uuid,
    '906e61dd-654d-4086-b185-21bfc6a725b7'::uuid,
    '19b563e7-c8f5-4768-8e0a-fc9503a5b592'::uuid,
    '8deca43e-b74b-443d-9f6e-0d2c89e03272'::uuid,
    'e5d97b2f-98b2-469d-94fc-fdb0ad1cd353'::uuid
  )
  and approval_status = 'needs_review';

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 preflight failed: expected 5 Product DNA rows in needs_review, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from (
    values
      (
        '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
        'BDNA-ING-0003-gentle-cleanser-curel-4901301269348'
      ),
      (
        '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
        'BDNA-ING-0003-hydrating-lotion-hada-labo-167012'
      ),
      (
        '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
        'BDNA-ING-0003-barrier-serum-etvos-cn10694'
      ),
      (
        '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
        'BDNA-ING-0003-moisturizer-curel-4901301236210'
      ),
      (
        '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid,
        'BDNA-ING-0003-sunscreen-anessa-h16501'
      )
  ) as expected(product_id, source_key)
  join public.beautydna_products p
    on p.id = expected.product_id
   and p.metadata ->> 'source_type' = 'beautydna_launch_catalog'
   and p.metadata ->> 'source_key' = expected.source_key;

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 preflight failed: launch provenance mismatch; expected 5 exact products, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_products
  where id in (
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
    '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  )
  and shopify_status = 'needs_shopify_creation'
  and shopify_product_id is null
  and shopify_variant_id is null;

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 preflight failed: Shopify baseline changed; expected 5 unlinked products, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_product_ingredients
  where product_id = '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid
    and match_status = 'unmatched'
    and review_status = 'needs_review';

  if v_count <> 3 then
    raise exception
      'BDNA-PDNA-0001 preflight failed: Curél cream expected 3 preserved unmatched identities, found %',
      v_count;
  end if;
end
$bdna_preflight$;


-- ============================================================
-- 1. Curél Intensive Moisture Care Foaming Facial Wash
-- ============================================================

update public.beautydna_products
set
  source_type = metadata ->> 'source_type',
  source_key = metadata ->> 'source_key',
  approval_status = 'approved',
  metadata = metadata || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'evidence_class', 'manufacturer_official',
      'manufacturer_source_url', product_url,
      'shopify_linkage_changed', false
    )
  )
where id = '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid
  and approval_status = 'needs_review';

update public.beautydna_product_dna
set
  skin_type_fit = array['dry','sensitive']::text[],
  main_concerns_it_helps =
    array['dryness','barrier_support','sensitivity']::text[],
  things_to_avoid =
    array['known_paraben_sensitivity']::text[],
  recommended_routine_step = 'gentle_cleanser',
  usage_timing = array[]::text[],
  sensitivity_risk = 'unknown',
  comedogenic_risk = 'unknown',
  fragrance_status = 'fragrance_free',
  alcohol_status = 'unknown',
  pregnancy_caution = 'unknown',
  source_summary =
    'BDNA-PDNA-0001 manufacturer-official review. Kao Curél 4901301269348. Official evidence supports dry/sensitive-skin brand positioning, ceramide/moisture-preserving cleansing, skin-roughness prevention, fragrance-free status, paraben presence, and rinse-off facial cleansing. Retrieved 2026-08-17.',
  beautydna_match_notes =
    'Governed review approved. Unsupported provisional broad skin-type fit, dehydration timing inference, low sensitivity risk, low comedogenic risk, and alcohol-free classification were removed or returned to unknown rather than guessed.',
  dna_payload = dna_payload || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'manufacturer_source_url',
        'https://www.kao-kirei.com/ja/item/kbb/curel/4901301269348/',
      'evidence_class', 'manufacturer_official',
      'unsupported_values_removed', true
    )
  ),
  approval_status = 'approved'
where id = '02ac259e-dc07-40c8-9254-c7d22d2fc4df'::uuid
  and product_id = '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid
  and approval_status = 'needs_review';


-- ============================================================
-- 2. Hada Labo Gokujyun Premium Hyaluronic Lotion
-- ============================================================

update public.beautydna_products
set
  source_type = metadata ->> 'source_type',
  source_key = metadata ->> 'source_key',
  approval_status = 'approved',
  metadata = metadata || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'evidence_class', 'manufacturer_official',
      'manufacturer_source_url', product_url,
      'shopify_linkage_changed', false
    )
  )
where id = '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid
  and approval_status = 'needs_review';

update public.beautydna_product_dna
set
  skin_type_fit = array[]::text[],
  main_concerns_it_helps =
    array['dehydration','dryness']::text[],
  things_to_avoid = array[]::text[],
  recommended_routine_step = 'hydrating_lotion',
  usage_timing = array[]::text[],
  sensitivity_risk = 'unknown',
  comedogenic_risk = 'unknown',
  fragrance_status = 'fragrance_free',
  alcohol_status = 'alcohol_free',
  pregnancy_caution = 'unknown',
  source_summary =
    'BDNA-PDNA-0001 manufacturer-official review. Rohto Hada Labo product 167012. Official evidence supports intensive long-lasting hydration, eight hyaluronic-acid moisturizing ingredients, fragrance-free and ethanol-free status, plus paraben/mineral-oil/colorant-free claims. Retrieved 2026-08-17.',
  beautydna_match_notes =
    'Governed review approved. Unsupported all-skin-type assignment, barrier-support classification, generic hyaluronic-acid avoidance rule, low sensitivity risk, low comedogenic risk, and unverified timing were removed or returned to unknown.',
  dna_payload = dna_payload || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'manufacturer_source_url',
        'https://www.shop.rohto.co.jp/category/skincare/hadalabo/gokujyun-premium/167012.html',
      'evidence_class', 'manufacturer_official',
      'unsupported_values_removed', true
    )
  ),
  approval_status = 'approved'
where id = '906e61dd-654d-4086-b185-21bfc6a725b7'::uuid
  and product_id = '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid
  and approval_status = 'needs_review';


-- ============================================================
-- 3. ETVOS Moisturizing Serum
-- ============================================================

update public.beautydna_products
set
  source_type = metadata ->> 'source_type',
  source_key = metadata ->> 'source_key',
  approval_status = 'approved',
  metadata = metadata || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'evidence_class', 'manufacturer_official',
      'manufacturer_source_url', product_url,
      'shopify_linkage_changed', false
    )
  )
where id = '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid
  and approval_status = 'needs_review';

update public.beautydna_product_dna
set
  skin_type_fit = array['dry','sensitive']::text[],
  main_concerns_it_helps =
    array['dehydration','dryness','barrier_support','sensitivity']::text[],
  things_to_avoid =
    array['known_lavender_sensitivity','fragrance_sensitivity']::text[],
  recommended_routine_step = 'barrier_serum',
  usage_timing = array['morning_evening']::text[],
  sensitivity_risk = 'low',
  comedogenic_risk = 'unknown',
  fragrance_status = 'essential_oil_fragrance',
  alcohol_status = 'alcohol_free',
  pregnancy_caution = 'unknown',
  source_summary =
    'BDNA-PDNA-0001 manufacturer-official review. ETVOS CN10694. Official evidence supports dry/sensitive-skin use, five human-type ceramides, concentrated moisturization/barrier support, natural lavender water/oil fragrance, alcohol-free low-irritation formulation, and morning/evening use. Retrieved 2026-08-17.',
  beautydna_match_notes =
    'Governed review approved. Normal/combination skin assignments were removed because the official page specifically identifies dry, inner-dry, and sensitive skin. Comedogenic and pregnancy status remain unknown.',
  dna_payload = dna_payload || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'manufacturer_source_url',
        'https://etvos.com/shop/g/gCN10694-000/',
      'evidence_class', 'manufacturer_official',
      'unsupported_values_removed', true
    )
  ),
  approval_status = 'approved'
where id = '19b563e7-c8f5-4768-8e0a-fc9503a5b592'::uuid
  and product_id = '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid
  and approval_status = 'needs_review';


-- ============================================================
-- 4. Curél Intensive Moisture Facial Cream
-- ============================================================

update public.beautydna_products
set
  source_type = metadata ->> 'source_type',
  source_key = metadata ->> 'source_key',
  approval_status = 'approved',
  metadata = metadata || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'evidence_class', 'manufacturer_official',
      'manufacturer_source_url', product_url,
      'shopify_linkage_changed', false,
      'preserved_unmatched_ingredient_count', 3
    )
  )
where id = '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid
  and approval_status = 'needs_review';

update public.beautydna_product_dna
set
  skin_type_fit = array['dry','sensitive']::text[],
  main_concerns_it_helps =
    array['dryness','barrier_support','sensitivity']::text[],
  things_to_avoid =
    array['known_paraben_sensitivity']::text[],
  recommended_routine_step = 'moisturizer',
  usage_timing = array['morning_evening']::text[],
  sensitivity_risk = 'low',
  comedogenic_risk = 'unknown',
  fragrance_status = 'fragrance_free',
  alcohol_status = 'alcohol_free',
  pregnancy_caution = 'unknown',
  source_summary =
    'BDNA-PDNA-0001 manufacturer-official review. Kao Curél 4901301236210. Official evidence supports moisturization/barrier support, dry/sensitive-skin low-irritation positioning, fragrance-free and ethanol-free formulation, paraben presence, and use after lotion or emulsion. Three intentionally unresolved BDNA-ING-0004 generic ingredient identities are preserved. Retrieved 2026-08-17.',
  beautydna_match_notes =
    'Governed review approved without reopening Ingredient Intelligence. Normal/combination skin assignments, dehydration classification, and unsupported low comedogenic-risk value were removed. Three BDNA-ING-0004 ambiguous class identities remain needs_review exactly as governed.',
  dna_payload = dna_payload || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'manufacturer_source_url',
        'https://www.kao-kirei.com/ja/item/kbb/curel/4901301236210/',
      'evidence_class', 'manufacturer_official',
      'preserved_unmatched_ingredient_count', 3,
      'ingredient_intelligence_reopened', false,
      'unsupported_values_removed', true
    )
  ),
  approval_status = 'approved'
where id = '8deca43e-b74b-443d-9f6e-0d2c89e03272'::uuid
  and product_id = '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid
  and approval_status = 'needs_review';


-- ============================================================
-- 5. ANESSA Perfect UV Sunscreen Skincare Milk NA
-- ============================================================

update public.beautydna_products
set
  source_type = metadata ->> 'source_type',
  source_key = metadata ->> 'source_key',
  approval_status = 'approved',
  metadata = metadata || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'evidence_class', 'manufacturer_official',
      'manufacturer_source_url', product_url,
      'shopify_linkage_changed', false
    )
  )
where id = '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  and approval_status = 'needs_review';

update public.beautydna_product_dna
set
  skin_type_fit = array[]::text[],
  main_concerns_it_helps =
    array['sun_protection','pigmentation']::text[],
  things_to_avoid =
    array[
      'alcohol_sensitivity',
      'fragrance_sensitivity',
      'known_uv_filter_sensitivity'
    ]::text[],
  recommended_routine_step = 'sunscreen',
  usage_timing = array['morning']::text[],
  sensitivity_risk = 'medium',
  comedogenic_risk = 'low',
  fragrance_status = 'fragranced',
  alcohol_status = 'contains_ethanol',
  pregnancy_caution = 'unknown',
  source_summary =
    'BDNA-PDNA-0001 manufacturer-official review. Shiseido ANESSA H16501. Official evidence supports SPF50+/PA++++ UV protection, morning final-step facial use, fruity-floral fragrance, ethanol and multiple UV filters in the formula, and a formulation described as less likely to cause acne. Retrieved 2026-08-17.',
  beautydna_match_notes =
    'Governed review approved. Unsupported normal/combination/oily skin-type assignment, photoaging classification, and eye-area sensitivity classification were removed. Medium sensitivity risk is a BeautyDNA inference from manufacturer-declared ethanol, fragrance and multiple UV filters, not a manufacturer risk rating.',
  dna_payload = dna_payload || jsonb_build_object(
    'bdna_pdna_0001_review',
    jsonb_build_object(
      'build_id', 'BDNA-PDNA-0001',
      'review_outcome', 'approved',
      'reviewed_by', 'Wesley Kato',
      'reviewed_at', now(),
      'manufacturer_source_url',
        'https://www.shiseido.co.jp/sw/onlinestore/products/H16501.html',
      'evidence_class', 'manufacturer_official',
      'internal_inference_fields',
        jsonb_build_array('sensitivity_risk','things_to_avoid'),
      'unsupported_values_removed', true
    )
  ),
  approval_status = 'approved'
where id = 'e5d97b2f-98b2-469d-94fc-fdb0ad1cd353'::uuid
  and product_id = '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  and approval_status = 'needs_review';


-- ============================================================
-- Postconditions
-- ============================================================

do $bdna_postconditions$
declare
  v_count integer;
begin
  select count(*)
  into v_count
  from public.beautydna_products
  where id in (
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
    '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  )
  and approval_status = 'approved'
  and source_type = 'beautydna_launch_catalog'
  and source_key is not null;

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 postcondition failed: expected 5 approved launch products, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_product_dna
  where id in (
    '02ac259e-dc07-40c8-9254-c7d22d2fc4df'::uuid,
    '906e61dd-654d-4086-b185-21bfc6a725b7'::uuid,
    '19b563e7-c8f5-4768-8e0a-fc9503a5b592'::uuid,
    '8deca43e-b74b-443d-9f6e-0d2c89e03272'::uuid,
    'e5d97b2f-98b2-469d-94fc-fdb0ad1cd353'::uuid
  )
  and approval_status = 'approved';

  if v_count <> 5 then
    raise exception
      'BDNA-PDNA-0001 postcondition failed: expected 5 approved Product DNA rows, found %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_v2_product_readiness
  where product_id in (
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    '48faa3de-bfe6-4e4c-9958-754088754f50'::uuid,
    '349821be-6f9a-4e4f-bf84-b922986547ca'::uuid,
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid
  )
  and recommendation_ready = true;

  if v_count <> 0 then
    raise exception
      'BDNA-PDNA-0001 postcondition failed: Shopify-unlinked products unexpectedly became recommendation_ready; count %',
      v_count;
  end if;

  select count(*)
  into v_count
  from public.beautydna_product_ingredients
  where product_id = '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid
    and match_status = 'unmatched'
    and review_status = 'needs_review';

  if v_count <> 3 then
    raise exception
      'BDNA-PDNA-0001 postcondition failed: Curél cream unmatched identity count changed; expected 3, found %',
      v_count;
  end if;
end
$bdna_postconditions$;

commit;