-- ============================================================
-- BDNA-ING-0004
-- Japanese Ingredient Identity Normalization and Review-Queue Processing
-- Final product-specific resolution and governed ambiguity holds
--
-- Target system: Beauty OS / BeautyDNA
-- Target Supabase project: hidsyvanaipxxyyhjgmc
-- Tracking system: Athena CTO (governance only)
--
-- Governed scope:
--   - Five non-archived BeautyDNA launch products only.
--   - Resolve three exact Curél Foaming Facial Wash product rows:
--       ステアリン酸POEソルビタン -> Polysorbate 60
--       エデト酸塩                 -> Disodium EDTA
--       パラベン                   -> Methylparaben
--   - Create two missing approved canonical identity seeds:
--       Polysorbate 60 and Methylparaben.
--   - Reuse the existing approved Disodium EDTA canonical.
--   - Create no global alias for any generic Japanese source label.
--   - Convert two unresolved Curél Facial Cream identities into governed holds:
--       α-オレフィンオリゴマー
--       POE・ジメチコン共重合体
--   - Preserve the existing Curél Facial Cream パラベン hold.
--   - Preserve every original Japanese/source ingredient string.
--
-- This migration is product-specific. It must not infer that the generic source
-- labels are equivalent to the selected canonicals in any other product.
-- Detailed Ingredient Intelligence enrichment remains pending.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0004_final_launch_products (
  product_id uuid primary key
) on commit drop;

insert into tmp_bdna_ing_0004_final_launch_products (product_id)
values
  ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid),
  ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
  ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
  ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
  ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid);

create temporary table tmp_bdna_ing_0004_final_actions (
  action_key text primary key,
  intended_action text not null check (
    intended_action in (
      'resolve_product_specific',
      'hold_ambiguous_identity',
      'keep_existing_hold'
    )
  ),
  product_id uuid not null,
  product_ingredient_id uuid not null unique,
  queue_id uuid not null unique,
  source_name text not null,
  normalized_source_name text not null,
  expected_queue_status text not null check (
    expected_queue_status in ('open', 'in_review')
  ),
  canonical_name text,
  canonical_normalized_name text,
  ingredient_category text,
  evidence_class text not null,
  canonical_must_preexist boolean not null,
  canonical_expected_new boolean not null,
  ambiguity_reason text,
  check (
    (
      intended_action = 'resolve_product_specific'
      and canonical_name is not null
      and canonical_normalized_name is not null
      and ingredient_category is not null
      and ambiguity_reason is null
      and canonical_must_preexist <> canonical_expected_new
    )
    or
    (
      intended_action in ('hold_ambiguous_identity', 'keep_existing_hold')
      and canonical_name is null
      and canonical_normalized_name is null
      and ingredient_category is null
      and not canonical_must_preexist
      and not canonical_expected_new
      and ambiguity_reason is not null
    )
  )
) on commit drop;

insert into tmp_bdna_ing_0004_final_actions (
  action_key,
  intended_action,
  product_id,
  product_ingredient_id,
  queue_id,
  source_name,
  normalized_source_name,
  expected_queue_status,
  canonical_name,
  canonical_normalized_name,
  ingredient_category,
  evidence_class,
  canonical_must_preexist,
  canonical_expected_new,
  ambiguity_reason
)
values
  (
    'resolve-cleanser-polysorbate-60',
    'resolve_product_specific',
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    'e72be638-1aaf-4efa-9eb9-b12c95fa3d6a'::uuid,
    'ebddc25f-f118-4c26-9afc-d6f701eaae72'::uuid,
    'ステアリン酸POEソルビタン',
    'ステアリン酸poeソルビタン',
    'open',
    'Polysorbate 60',
    'polysorbate 60',
    'surfactant',
    'official_curel_product_formula',
    false,
    true,
    null
  ),
  (
    'resolve-cleanser-disodium-edta',
    'resolve_product_specific',
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    'addc236c-0f78-40fe-8f7e-f2876ae67b3d'::uuid,
    'dda46e5e-bf9e-493a-b0c7-4574c8590282'::uuid,
    'エデト酸塩',
    'エデト酸塩',
    'open',
    'Disodium EDTA',
    'disodium edta',
    'chelating_agent',
    'official_curel_product_formula',
    true,
    false,
    null
  ),
  (
    'resolve-cleanser-methylparaben',
    'resolve_product_specific',
    '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid,
    'e1f51711-7fd4-4071-bbc5-f0c505dcfd9c'::uuid,
    '4381e5f9-bbc3-4a1a-b478-7f0e5fcd69cb'::uuid,
    'パラベン',
    'パラベン',
    'in_review',
    'Methylparaben',
    'methylparaben',
    'preservative',
    'official_curel_product_formula',
    false,
    true,
    null
  ),
  (
    'hold-cream-alpha-olefin-oligomer',
    'hold_ambiguous_identity',
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '30e352fb-9a5f-4b8b-b96f-7d224a9b1bad'::uuid,
    '73a910ac-fead-49c2-b5b1-c016d04e0793'::uuid,
    'α-オレフィンオリゴマー',
    'α-オレフィンオリゴマー',
    'open',
    null,
    null,
    null,
    'generic_quasi_drug_hydrocarbon_class',
    false,
    false,
    'The source label α-オレフィンオリゴマー is a generic quasi-drug hydrocarbon class and does not identify one unique canonical ingredient.'
  ),
  (
    'hold-cream-poe-dimethicone-copolymer',
    'hold_ambiguous_identity',
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    'e24bafb4-2917-4b1e-a7fd-c1740784e8ed'::uuid,
    '81d456c7-727d-497d-8fff-d9d42d5c3c66'::uuid,
    'POE・ジメチコン共重合体',
    'poe・ジメチコン共重合体',
    'open',
    null,
    null,
    null,
    'generic_quasi_drug_silicone_copolymer',
    false,
    false,
    'The source label POE・ジメチコン共重合体 is a generic silicone-copolymer class and does not identify one unique canonical ingredient.'
  ),
  (
    'keep-hold-cream-paraben',
    'keep_existing_hold',
    '41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid,
    '2bc80b34-1c9a-457b-a468-cbb53f29c53e'::uuid,
    '0a7c2b28-c210-4e84-9232-10e70e4c8c0c'::uuid,
    'パラベン',
    'パラベン',
    'in_review',
    null,
    null,
    null,
    'generic_paraben_class_label_formula_not_equivalent',
    false,
    false,
    'The Curél Facial Cream source label パラベン does not identify a specific paraben, and the available non-Japanese formula is not equivalent evidence.'
  );

-- ------------------------------------------------------------
-- Fail-closed preflight
-- ------------------------------------------------------------

do $$
declare
  actual_count bigint;
  matched_count bigint;
  unmatched_count bigint;
  open_queue_count bigint;
  in_review_queue_count bigint;
  paraben_in_review_count bigint;
  mismatch_details text;
  collision_details text;
begin
  select count(*)
  into actual_count
  from public.beautydna_products product
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = product.id
  where product.approval_status <> 'archived';

  if actual_count <> 5 then
    raise exception
      'BDNA-ING-0004 final resolution expected 5 non-archived launch products; found %.',
      actual_count;
  end if;

  select
    count(*) filter (
      where ingredient.ingredient_id is not null
        and ingredient.match_status in ('approved_match', 'alias_match')
        and ingredient.review_status = 'approved'
    ),
    count(*) filter (
      where ingredient.ingredient_id is null
        and ingredient.match_status = 'unmatched'
        and ingredient.review_status = 'needs_review'
    )
  into matched_count, unmatched_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id;

  if not (
    (matched_count = 161 and unmatched_count = 6)
    or
    (matched_count = 164 and unmatched_count = 3)
  ) then
    raise exception
      'BDNA-ING-0004 final resolution unexpected launch baseline: matched=% unmatched=%.',
      matched_count,
      unmatched_count;
  end if;

  select
    count(*) filter (
      where queue.status = 'open'
        and queue.resolved_ingredient_id is null
    ),
    count(*) filter (
      where queue.status = 'in_review'
        and queue.resolved_ingredient_id is null
    ),
    count(*) filter (
      where queue.status = 'in_review'
        and queue.resolved_ingredient_id is null
        and queue.normalized_ingredient_name = 'パラベン'
    )
  into open_queue_count, in_review_queue_count, paraben_in_review_count
  from public.beautydna_ingredient_review_queue queue
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = queue.product_id;

  if not (
    (
      open_queue_count = 4
      and in_review_queue_count = 2
      and paraben_in_review_count = 2
    )
    or
    (
      open_queue_count = 0
      and in_review_queue_count = 3
      and paraben_in_review_count = 1
    )
  ) then
    raise exception
      'BDNA-ING-0004 final resolution unexpected queue baseline: open=% in_review=% paraben_in_review=%.',
      open_queue_count,
      in_review_queue_count,
      paraben_in_review_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id;

  if actual_count <> 167 then
    raise exception
      'BDNA-ING-0004 final resolution expected 167 launch ingredient rows; found %.',
      actual_count;
  end if;

  -- Exact product and queue identities must remain one-to-one.
  select string_agg(
    format(
      '%s product_rows=%s queue_rows=%s',
      action.action_key,
      product_state.row_count,
      queue_state.row_count
    ),
    '; '
    order by action.action_key
  )
  into mismatch_details
  from tmp_bdna_ing_0004_final_actions action
  join lateral (
    select count(*)::bigint as row_count
    from public.beautydna_product_ingredients ingredient
    where ingredient.id = action.product_ingredient_id
      and ingredient.product_id = action.product_id
      and ingredient.ingredient_name = action.source_name
      and ingredient.normalized_ingredient_name = action.normalized_source_name
  ) product_state on true
  join lateral (
    select count(*)::bigint as row_count
    from public.beautydna_ingredient_review_queue queue
    where queue.id = action.queue_id
      and queue.product_id = action.product_id
      and queue.ingredient_name = action.source_name
      and queue.normalized_ingredient_name = action.normalized_source_name
  ) queue_state on true
  where product_state.row_count <> 1
     or queue_state.row_count <> 1;

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 final resolution exact-row scope mismatch: %',
      mismatch_details;
  end if;

  -- Generic source labels must never be globally aliased.
  select string_agg(
    format(
      '%s alias=%s target=%s',
      action.normalized_source_name,
      alias.id,
      alias.ingredient_id
    ),
    '; '
    order by action.normalized_source_name, alias.id
  )
  into collision_details
  from (
    select distinct normalized_source_name
    from tmp_bdna_ing_0004_final_actions
  ) action
  join public.beautydna_ingredient_aliases alias
    on alias.normalized_alias_name = action.normalized_source_name;

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 final resolution refuses global generic aliases: %',
      collision_details;
  end if;

  -- Canonicals must match the gate: one existing Disodium EDTA, two absent
  -- seeds before first execution or exact seeds created by this migration.
  select string_agg(
    format(
      '%s count=%s names=%s statuses=%s batch_ids=%s',
      action.canonical_normalized_name,
      canonical.match_count,
      coalesce(canonical.names, 'null'),
      coalesce(canonical.statuses, 'null'),
      coalesce(canonical.batch_ids, 'null')
    ),
    '; '
    order by action.canonical_normalized_name
  )
  into collision_details
  from tmp_bdna_ing_0004_final_actions action
  join lateral (
    select
      count(*)::bigint as match_count,
      string_agg(distinct ingredient.ingredient_name, ',' order by ingredient.ingredient_name)
        as names,
      string_agg(distinct ingredient.review_status, ',' order by ingredient.review_status)
        as statuses,
      string_agg(
        distinct coalesce(ingredient.metadata->>'batch_id', 'null'),
        ','
        order by coalesce(ingredient.metadata->>'batch_id', 'null')
      ) as batch_ids
    from public.beautydna_ingredient_intelligence ingredient
    where ingredient.normalized_name = action.canonical_normalized_name
       or ingredient.normalized_ingredient_name = action.canonical_normalized_name
  ) canonical on true
  where action.intended_action = 'resolve_product_specific'
    and (
      canonical.match_count > 1
      or (
        action.canonical_must_preexist
        and (
          canonical.match_count <> 1
          or canonical.names <> action.canonical_name
          or canonical.statuses <> 'approved'
        )
      )
      or (
        action.canonical_expected_new
        and canonical.match_count = 1
        and (
          canonical.names <> action.canonical_name
          or canonical.statuses <> 'approved'
          or canonical.batch_ids <> 'final_product_specific_resolution'
        )
      )
    );

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 final resolution canonical collision: %',
      collision_details;
  end if;

  -- Each action must be either in its exact initial state or exact final state.
  select string_agg(
    format(
      '%s ingredient_id=%s match=%s review=%s queue=%s resolved_id=%s',
      action.action_key,
      coalesce(ingredient.ingredient_id::text, 'null'),
      ingredient.match_status,
      ingredient.review_status,
      queue.status,
      coalesce(queue.resolved_ingredient_id::text, 'null')
    ),
    '; '
    order by action.action_key
  )
  into mismatch_details
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_product_ingredients ingredient
    on ingredient.id = action.product_ingredient_id
   and ingredient.product_id = action.product_id
  join public.beautydna_ingredient_review_queue queue
    on queue.id = action.queue_id
   and queue.product_id = action.product_id
  left join public.beautydna_ingredient_intelligence canonical
    on action.intended_action = 'resolve_product_specific'
   and (
        canonical.normalized_name = action.canonical_normalized_name
        or canonical.normalized_ingredient_name = action.canonical_normalized_name
   )
   and canonical.review_status = 'approved'
  where not (
    (
      action.intended_action = 'resolve_product_specific'
      and (
        (
          ingredient.ingredient_id is null
          and ingredient.match_status = 'unmatched'
          and ingredient.review_status = 'needs_review'
          and queue.status = action.expected_queue_status
          and queue.resolved_ingredient_id is null
        )
        or
        (
          canonical.id is not null
          and ingredient.ingredient_id = canonical.id
          and ingredient.match_status = 'approved_match'
          and ingredient.review_status = 'approved'
          and queue.status = 'resolved'
          and queue.resolved_ingredient_id = canonical.id
        )
      )
    )
    or
    (
      action.intended_action = 'hold_ambiguous_identity'
      and ingredient.ingredient_id is null
      and ingredient.match_status = 'unmatched'
      and ingredient.review_status = 'needs_review'
      and queue.status in ('open', 'in_review')
      and queue.resolved_ingredient_id is null
    )
    or
    (
      action.intended_action = 'keep_existing_hold'
      and ingredient.ingredient_id is null
      and ingredient.match_status = 'unmatched'
      and ingredient.review_status = 'needs_review'
      and queue.status = 'in_review'
      and queue.resolved_ingredient_id is null
    )
  );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 final resolution unexpected action state: %',
      mismatch_details;
  end if;

  -- All non-target launch ingredient rows are immutable boundaries.
  select count(*)
  into actual_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_final_actions action
    where action.product_ingredient_id = ingredient.id
  )
    and ingredient.ingredient_id is not null
    and ingredient.match_status in ('approved_match', 'alias_match')
    and ingredient.review_status = 'approved';

  if actual_count <> 161 then
    raise exception
      'BDNA-ING-0004 final resolution expected 161 immutable non-target matched rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_final_actions action
    where action.product_ingredient_id = ingredient.id
  )
    and ingredient.ingredient_id is null
    and ingredient.match_status = 'unmatched'
    and ingredient.review_status = 'needs_review';

  if actual_count <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution found unexpected non-target unmatched rows: %.',
      actual_count;
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution refuses compatibility-rule changes.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution refuses the legacy match table.';
  end if;
end
$$;

-- ------------------------------------------------------------
-- Create only the two missing product-specific canonical seeds.
-- No generic Japanese aliases are created.
-- ------------------------------------------------------------

insert into public.beautydna_ingredient_intelligence (
  ingredient_name,
  normalized_ingredient_name,
  normalized_name,
  ingredient_aliases,
  ingredient_category,
  evidence_level,
  source_notes,
  review_status,
  created_by,
  updated_by,
  reviewed_by,
  reviewed_at,
  metadata
)
select
  action.canonical_name,
  action.canonical_normalized_name,
  action.canonical_normalized_name,
  array[]::text[],
  action.ingredient_category,
  'medium',
  'Product-specific identity resolution in BDNA-ING-0004. Global alias creation is prohibited; full Ingredient Intelligence enrichment remains pending.',
  'approved',
  'beauty_os_admin',
  'beauty_os_admin',
  'beauty_os_admin',
  now(),
  jsonb_build_object(
    'build_id', 'BDNA-ING-0004',
    'batch_id', 'final_product_specific_resolution',
    'record_type', 'product_specific_verified_identity_seed',
    'identity_status', 'approved',
    'intelligence_enrichment_status', 'pending',
    'canonical_normalized_name', action.canonical_normalized_name,
    'source_label', action.source_name,
    'normalized_source_label', action.normalized_source_name,
    'evidence_class', action.evidence_class,
    'product_id', action.product_id,
    'product_ingredient_id', action.product_ingredient_id,
    'queue_id', action.queue_id,
    'product_specific_resolution_only', true,
    'global_alias_created', false,
    'original_strings_preserved', true,
    'customer_copy_scope', 'cosmetic_non_diagnostic'
  )
from tmp_bdna_ing_0004_final_actions action
where action.intended_action = 'resolve_product_specific'
  and action.canonical_expected_new
  and not exists (
    select 1
    from public.beautydna_ingredient_intelligence existing
    where existing.normalized_name = action.canonical_normalized_name
       or existing.normalized_ingredient_name = action.canonical_normalized_name
  );

-- ------------------------------------------------------------
-- Resolve exactly three product rows by explicit IDs.
-- ------------------------------------------------------------

with resolved_actions as (
  select
    action.*,
    canonical.id as canonical_id
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_ingredient_intelligence canonical
    on (
      canonical.normalized_name = action.canonical_normalized_name
      or canonical.normalized_ingredient_name = action.canonical_normalized_name
    )
   and canonical.ingredient_name = action.canonical_name
   and canonical.review_status = 'approved'
  where action.intended_action = 'resolve_product_specific'
)
update public.beautydna_product_ingredients ingredient
set
  ingredient_id = action.canonical_id,
  match_status = 'approved_match',
  review_status = 'approved',
  metadata =
    coalesce(ingredient.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'matched_via', 'product_specific_authoritative_formula',
      'source_label', action.source_name,
      'canonical_ingredient_name', action.canonical_name,
      'canonical_normalized_name', action.canonical_normalized_name,
      'identity_evidence_class', action.evidence_class,
      'resolved_by_build', 'BDNA-ING-0004',
      'resolved_by_batch', 'final_product_specific_resolution',
      'product_specific_resolution_only', true,
      'global_alias_created', false,
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        ingredient.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_actions action
where ingredient.id = action.product_ingredient_id
  and ingredient.product_id = action.product_id
  and ingredient.ingredient_name = action.source_name
  and ingredient.normalized_ingredient_name = action.normalized_source_name;

-- ------------------------------------------------------------
-- Resolve exactly three queue rows by explicit IDs.
-- ------------------------------------------------------------

with resolved_actions as (
  select
    action.*,
    canonical.id as canonical_id
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_ingredient_intelligence canonical
    on (
      canonical.normalized_name = action.canonical_normalized_name
      or canonical.normalized_ingredient_name = action.canonical_normalized_name
    )
   and canonical.ingredient_name = action.canonical_name
   and canonical.review_status = 'approved'
  where action.intended_action = 'resolve_product_specific'
)
update public.beautydna_ingredient_review_queue queue
set
  status = 'resolved',
  resolved_ingredient_id = action.canonical_id,
  assigned_to = 'beauty_os_admin',
  notes = case
    when position(
      'Resolved by BDNA-ING-0004 final product-specific evidence review.'
      in coalesce(queue.notes, '')
    ) > 0 then queue.notes
    else concat_ws(
      E'\n',
      nullif(queue.notes, ''),
      'Resolved by BDNA-ING-0004 final product-specific evidence review. This decision does not create a global alias for the generic Japanese source label.'
    )
  end,
  metadata =
    coalesce(queue.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action', 'resolve_product_specific_authoritative_formula',
      'source_label', action.source_name,
      'canonical_ingredient_name', action.canonical_name,
      'canonical_normalized_name', action.canonical_normalized_name,
      'identity_evidence_class', action.evidence_class,
      'resolved_by_build', 'BDNA-ING-0004',
      'resolved_by_batch', 'final_product_specific_resolution',
      'product_specific_resolution_only', true,
      'global_alias_created', false,
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        queue.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_actions action
where queue.id = action.queue_id
  and queue.product_id = action.product_id
  and queue.ingredient_name = action.source_name
  and queue.normalized_ingredient_name = action.normalized_source_name;

-- ------------------------------------------------------------
-- Convert two still-open cream identities into governed holds.
-- ------------------------------------------------------------

update public.beautydna_product_ingredients ingredient
set
  metadata =
    coalesce(ingredient.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'identity_review_status', 'ambiguous_product_specific_identity',
      'ambiguity_reason', action.ambiguity_reason,
      'identity_evidence_class', action.evidence_class,
      'held_by_build', 'BDNA-ING-0004',
      'held_by_batch', 'final_product_specific_resolution',
      'requires_exact_product_evidence', true,
      'product_specific_evidence_reviewed', true,
      'original_ingredient_name_preserved', true,
      'held_at', coalesce(
        ingredient.metadata->>'held_at',
        now()::text
      )
    ),
  updated_at = now()
from tmp_bdna_ing_0004_final_actions action
where action.intended_action = 'hold_ambiguous_identity'
  and ingredient.id = action.product_ingredient_id
  and ingredient.product_id = action.product_id
  and ingredient.ingredient_id is null
  and ingredient.match_status = 'unmatched'
  and ingredient.review_status = 'needs_review';

update public.beautydna_ingredient_review_queue queue
set
  status = 'in_review',
  assigned_to = 'beauty_os_admin',
  notes = case
    when position(
      'BDNA-ING-0004 final ambiguity hold:'
      in coalesce(queue.notes, '')
    ) > 0 then queue.notes
    else concat_ws(
      E'\n',
      nullif(queue.notes, ''),
      'BDNA-ING-0004 final ambiguity hold: the product label does not support one unique canonical identity. Preserve the source string until exact authoritative product evidence becomes available.'
    )
  end,
  metadata =
    coalesce(queue.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action', 'hold_ambiguous_identity',
      'ambiguity_reason', action.ambiguity_reason,
      'identity_evidence_class', action.evidence_class,
      'held_by_build', 'BDNA-ING-0004',
      'held_by_batch', 'final_product_specific_resolution',
      'requires_exact_product_evidence', true,
      'product_specific_evidence_reviewed', true,
      'original_ingredient_name_preserved', true,
      'held_at', coalesce(
        queue.metadata->>'held_at',
        now()::text
      )
    ),
  updated_at = now()
from tmp_bdna_ing_0004_final_actions action
where action.intended_action = 'hold_ambiguous_identity'
  and queue.id = action.queue_id
  and queue.product_id = action.product_id
  and queue.resolved_ingredient_id is null
  and queue.status in ('open', 'in_review');

-- ------------------------------------------------------------
-- Fail-closed post-verification
-- ------------------------------------------------------------

do $$
declare
  actual_count bigint;
  mismatch_details text;
begin
  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_ingredient_intelligence canonical
    on (
      canonical.normalized_name = action.canonical_normalized_name
      or canonical.normalized_ingredient_name = action.canonical_normalized_name
    )
   and canonical.ingredient_name = action.canonical_name
   and canonical.review_status = 'approved'
  where action.intended_action = 'resolve_product_specific';

  if actual_count <> 3 then
    raise exception
      'BDNA-ING-0004 final resolution expected 3 approved canonical mappings; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_intelligence canonical
  where canonical.metadata->>'build_id' = 'BDNA-ING-0004'
    and canonical.metadata->>'batch_id' = 'final_product_specific_resolution'
    and canonical.metadata->>'record_type' = 'product_specific_verified_identity_seed'
    and canonical.review_status = 'approved';

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 final resolution expected 2 newly seeded canonicals; found %.',
      actual_count;
  end if;

  if exists (
    select 1
    from (
      select distinct normalized_source_name
      from tmp_bdna_ing_0004_final_actions
    ) action
    join public.beautydna_ingredient_aliases alias
      on alias.normalized_alias_name = action.normalized_source_name
  ) then
    raise exception
      'BDNA-ING-0004 final resolution unexpectedly created or found a global generic alias.';
  end if;

  select string_agg(
    format(
      '%s product=%s expected=%s actual=%s status=%s/%s',
      action.action_key,
      ingredient.product_id,
      canonical.id,
      coalesce(ingredient.ingredient_id::text, 'null'),
      ingredient.match_status,
      ingredient.review_status
    ),
    '; '
    order by action.action_key
  )
  into mismatch_details
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_ingredient_intelligence canonical
    on (
      canonical.normalized_name = action.canonical_normalized_name
      or canonical.normalized_ingredient_name = action.canonical_normalized_name
    )
   and canonical.ingredient_name = action.canonical_name
   and canonical.review_status = 'approved'
  join public.beautydna_product_ingredients ingredient
    on ingredient.id = action.product_ingredient_id
   and ingredient.product_id = action.product_id
  where action.intended_action = 'resolve_product_specific'
    and (
      ingredient.ingredient_name <> action.source_name
      or ingredient.normalized_ingredient_name <> action.normalized_source_name
      or ingredient.ingredient_id <> canonical.id
      or ingredient.match_status <> 'approved_match'
      or ingredient.review_status <> 'approved'
      or ingredient.metadata->>'resolved_by_batch'
           <> 'final_product_specific_resolution'
      or ingredient.metadata->>'product_specific_resolution_only'
           <> 'true'
      or ingredient.metadata->>'global_alias_created'
           <> 'false'
      or ingredient.metadata->>'original_ingredient_name_preserved'
           <> 'true'
    );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 final resolution product-link postcheck failed: %',
      mismatch_details;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_product_ingredients ingredient
    on ingredient.id = action.product_ingredient_id
   and ingredient.product_id = action.product_id
  where action.intended_action = 'resolve_product_specific'
    and ingredient.ingredient_id is not null
    and ingredient.match_status = 'approved_match'
    and ingredient.review_status = 'approved';

  if actual_count <> 3 then
    raise exception
      'BDNA-ING-0004 final resolution expected 3 resolved product rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_ingredient_intelligence canonical
    on (
      canonical.normalized_name = action.canonical_normalized_name
      or canonical.normalized_ingredient_name = action.canonical_normalized_name
    )
   and canonical.ingredient_name = action.canonical_name
   and canonical.review_status = 'approved'
  join public.beautydna_ingredient_review_queue queue
    on queue.id = action.queue_id
   and queue.product_id = action.product_id
   and queue.status = 'resolved'
   and queue.resolved_ingredient_id = canonical.id
  where action.intended_action = 'resolve_product_specific'
    and queue.metadata->>'resolved_by_batch'
          = 'final_product_specific_resolution'
    and queue.metadata->>'product_specific_resolution_only'
          = 'true'
    and queue.metadata->>'global_alias_created'
          = 'false';

  if actual_count <> 3 then
    raise exception
      'BDNA-ING-0004 final resolution expected 3 resolved queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_product_ingredients ingredient
    on ingredient.id = action.product_ingredient_id
   and ingredient.product_id = action.product_id
  join public.beautydna_ingredient_review_queue queue
    on queue.id = action.queue_id
   and queue.product_id = action.product_id
  where action.intended_action = 'hold_ambiguous_identity'
    and ingredient.ingredient_id is null
    and ingredient.match_status = 'unmatched'
    and ingredient.review_status = 'needs_review'
    and ingredient.metadata->>'held_by_batch'
          = 'final_product_specific_resolution'
    and ingredient.metadata->>'identity_review_status'
          = 'ambiguous_product_specific_identity'
    and queue.status = 'in_review'
    and queue.resolved_ingredient_id is null
    and queue.metadata->>'action' = 'hold_ambiguous_identity'
    and queue.metadata->>'held_by_batch'
          = 'final_product_specific_resolution';

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 final resolution expected 2 newly governed ambiguity holds; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_final_actions action
  join public.beautydna_product_ingredients ingredient
    on ingredient.id = action.product_ingredient_id
   and ingredient.product_id = action.product_id
  join public.beautydna_ingredient_review_queue queue
    on queue.id = action.queue_id
   and queue.product_id = action.product_id
  where action.intended_action = 'keep_existing_hold'
    and ingredient.ingredient_id is null
    and ingredient.match_status = 'unmatched'
    and ingredient.review_status = 'needs_review'
    and queue.status = 'in_review'
    and queue.resolved_ingredient_id is null
    and queue.metadata->>'action' = 'hold_ambiguous_identity'
    and queue.metadata->>'held_by_build' = 'BDNA-ING-0004';

  if actual_count <> 1 then
    raise exception
      'BDNA-ING-0004 final resolution expected 1 preserved existing hold; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id
  where ingredient.ingredient_id is not null
    and ingredient.match_status in ('approved_match', 'alias_match')
    and ingredient.review_status = 'approved';

  if actual_count <> 164 then
    raise exception
      'BDNA-ING-0004 final resolution expected 164 matched launch rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients ingredient
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = ingredient.product_id
  where ingredient.ingredient_id is null
    and ingredient.match_status = 'unmatched'
    and ingredient.review_status = 'needs_review';

  if actual_count <> 3 then
    raise exception
      'BDNA-ING-0004 final resolution expected 3 governed unmatched rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue queue
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = queue.product_id
  where queue.status = 'open'
    and queue.resolved_ingredient_id is null;

  if actual_count <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution expected zero open queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue queue
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = queue.product_id
  where queue.status = 'in_review'
    and queue.resolved_ingredient_id is null;

  if actual_count <> 3 then
    raise exception
      'BDNA-ING-0004 final resolution expected 3 in-review queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue queue
  join tmp_bdna_ing_0004_final_launch_products launch
    on launch.product_id = queue.product_id
  where queue.status = 'in_review'
    and queue.resolved_ingredient_id is null
    and queue.normalized_ingredient_name = 'パラベン';

  if actual_count <> 1 then
    raise exception
      'BDNA-ING-0004 final resolution expected 1 unresolved パラベン hold; found %.',
      actual_count;
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution changed compatibility rules.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 final resolution used the legacy match table.';
  end if;

  raise notice
    'BDNA-ING-0004 final resolution verified: 3 product-specific resolutions, 2 new canonical seeds, 2 new holds, 1 preserved hold, 164/167 matched (98.20%%), zero open queue rows.';
end
$$;

commit;
