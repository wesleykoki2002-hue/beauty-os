-- ============================================================
-- BDNA-ING-0004
-- Japanese Ingredient Identity Normalization and Review-Queue Processing
-- Controlled identity batch 2A
--
-- Target system: Beauty OS / BeautyDNA
-- Target Supabase project: hidsyvanaipxxyyhjgmc
-- Tracking system: Athena CTO (governance only)
--
-- Governed scope:
--   - Five non-archived BeautyDNA launch products only.
--   - Resolve 22 exact, verified, one-row ingredient identities.
--   - Reuse the approved Water canonical for 精製水.
--   - Create 21 missing canonical identity seeds.
--   - Create 20 source-label aliases; BHT and PEG-6 are direct canonicals.
--   - Preserve every original Japanese/source ingredient string.
--   - Keep the two パラベン ambiguity holds unchanged.
--
-- Identity evidence basis:
--   - JCIA cosmetic ingredient display-name list.
--   - JCIA quasi-drug ingredient display-name list.
--   - Direct INCI source labels for BHT and PEG-6.
--
-- Detailed benefit, risk, compatibility, and customer-copy enrichment is
-- intentionally pending and is not approved by this identity-only batch.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0004_batch_2a_launch_products (
  product_id uuid primary key
) on commit drop;

insert into tmp_bdna_ing_0004_batch_2a_launch_products (product_id)
values
  ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid),
  ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
  ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
  ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
  ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid);

create temporary table tmp_bdna_ing_0004_batch_2a_identity_map (
  source_name text primary key,
  normalized_source_name text not null unique,
  canonical_name text not null,
  canonical_normalized_name text not null unique,
  ingredient_category text not null,
  alias_required boolean not null,
  evidence_class text not null,
  canonical_must_preexist boolean not null,
  expected_rows integer not null check (expected_rows = 1),
  check (
    alias_required
    or normalized_source_name = canonical_normalized_name
  )
) on commit drop;

insert into tmp_bdna_ing_0004_batch_2a_identity_map (
  source_name,
  normalized_source_name,
  canonical_name,
  canonical_normalized_name,
  ingredient_category,
  alias_required,
  evidence_class,
  canonical_must_preexist,
  expected_rows
)
values
  ('精製水', '精製水', 'Water', 'water', 'solvent', true, 'existing_canonical_alias', true, 1),
  ('酸化亜鉛', '酸化亜鉛', 'Zinc Oxide', 'zinc oxide', 'uv_filter_opacifier', true, 'verified_identity', false, 1),
  ('セバシン酸ジイソプロピル', 'セバシン酸ジイソプロピル', 'Diisopropyl Sebacate', 'diisopropyl sebacate', 'emollient', true, 'verified_identity', false, 1),
  ('サリチル酸エチルヘキシル', 'サリチル酸エチルヘキシル', 'Ethylhexyl Salicylate', 'ethylhexyl salicylate', 'uv_filter', true, 'verified_identity', false, 1),
  ('安息香酸アルキル（C12-15）', '安息香酸アルキル（c12-15）', 'C12-15 Alkyl Benzoate', 'c12-15 alkyl benzoate', 'emollient', true, 'verified_identity', false, 1),
  ('酸化チタン', '酸化チタン', 'Titanium Dioxide', 'titanium dioxide', 'uv_filter_opacifier', true, 'verified_identity', false, 1),
  ('塩化Na', '塩化na', 'Sodium Chloride', 'sodium chloride', 'viscosity_control', true, 'verified_identity', false, 1),
  ('水酸化Al', '水酸化al', 'Aluminum Hydroxide', 'aluminum hydroxide', 'surface_treatment', true, 'verified_identity', false, 1),
  ('ステアリン酸', 'ステアリン酸', 'Stearic Acid', 'stearic acid', 'fatty_acid_emollient', true, 'verified_identity', false, 1),
  ('EDTA-3Na', 'edta-3na', 'Trisodium EDTA', 'trisodium edta', 'chelating_agent', true, 'verified_identity', false, 1),
  ('PEG-6', 'peg-6', 'PEG-6', 'peg-6', 'humectant_solvent', false, 'direct_inci', false, 1),
  ('トコフェロール', 'トコフェロール', 'Tocopherol', 'tocopherol', 'antioxidant', true, 'verified_identity', false, 1),
  ('BHT', 'bht', 'BHT', 'bht', 'antioxidant', false, 'direct_inci', false, 1),
  ('ピロ亜硫酸Na', 'ピロ亜硫酸na', 'Sodium Metabisulfite', 'sodium metabisulfite', 'antioxidant_preservative', true, 'verified_identity', false, 1),
  ('安息香酸Na', '安息香酸na', 'Sodium Benzoate', 'sodium benzoate', 'preservative', true, 'verified_identity', false, 1),
  ('合成金雲母', '合成金雲母', 'Synthetic Fluorphlogopite', 'synthetic fluorphlogopite', 'bulking_agent', true, 'verified_identity', false, 1),
  ('PG', 'pg', 'Propylene Glycol', 'propylene glycol', 'humectant_solvent', true, 'verified_abbreviation', false, 1),
  ('PEG6000', 'peg6000', 'PEG-120', 'peg-120', 'viscosity_control', true, 'verified_abbreviation', false, 1),
  ('1,2-ヘキサンジオール', '1,2-ヘキサンジオール', '1,2-Hexanediol', '1,2-hexanediol', 'humectant_preservative_booster', true, 'verified_identity', false, 1),
  ('PCA-Na', 'pca-na', 'Sodium PCA', 'sodium pca', 'humectant', true, 'verified_abbreviation', false, 1),
  ('DPG', 'dpg', 'Dipropylene Glycol', 'dipropylene glycol', 'humectant_solvent', true, 'verified_abbreviation', false, 1),
  ('EDTA-2Na', 'edta-2na', 'Disodium EDTA', 'disodium edta', 'chelating_agent', true, 'verified_identity', false, 1);

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
  mismatch_details text;
  collision_details text;
begin
  select count(*)
  into actual_count
  from public.beautydna_products p
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = p.id
  where p.approval_status <> 'archived';

  if actual_count <> 5 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 5 non-archived launch products; found %.',
      actual_count;
  end if;

  select
    count(*) filter (
      where pi.ingredient_id is not null
        and pi.match_status in ('approved_match', 'alias_match')
        and pi.review_status = 'approved'
    ),
    count(*) filter (
      where pi.ingredient_id is null
        and pi.match_status = 'unmatched'
        and pi.review_status = 'needs_review'
    )
  into matched_count, unmatched_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id;

  if matched_count not in (36, 58)
     or unmatched_count not in (131, 109) then
    raise exception
      'BDNA-ING-0004 batch 2A unexpected launch baseline: matched=% unmatched=%.',
      matched_count,
      unmatched_count;
  end if;

  select
    count(*) filter (where q.status = 'open'),
    count(*) filter (where q.status = 'in_review')
  into open_queue_count, in_review_queue_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = q.product_id;

  if open_queue_count not in (129, 107)
     or in_review_queue_count <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2A unexpected queue baseline: open=% in_review=%.',
      open_queue_count,
      in_review_queue_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id;

  if actual_count <> 167 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 167 launch ingredient rows; found %.',
      actual_count;
  end if;

  -- Each governed source label must map to exactly one product row and one queue row.
  select string_agg(
    format(
      '%s expected=%s product_rows=%s queue_rows=%s',
      m.source_name,
      m.expected_rows,
      coalesce(ps.product_rows, 0),
      coalesce(qs.queue_rows, 0)
    ),
    '; '
    order by m.normalized_source_name
  )
  into mismatch_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  left join lateral (
    select count(*)::bigint as product_rows
    from public.beautydna_product_ingredients pi
    join tmp_bdna_ing_0004_batch_2a_launch_products lp
      on lp.product_id = pi.product_id
    where pi.normalized_ingredient_name = m.normalized_source_name
      and pi.ingredient_name = m.source_name
  ) ps on true
  left join lateral (
    select count(*)::bigint as queue_rows
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_batch_2a_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = m.normalized_source_name
      and q.ingredient_name = m.source_name
  ) qs on true
  where coalesce(ps.product_rows, 0) <> m.expected_rows
     or coalesce(qs.queue_rows, 0) <> m.expected_rows;

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A source-scope mismatch: %',
      mismatch_details;
  end if;

  -- Canonical identities may be absent or already correctly present. Water must
  -- already exist because Batch 1 owns that canonical identity.
  select string_agg(
    format(
      '%s canonical_matches=%s names=%s statuses=%s',
      m.canonical_normalized_name,
      c.match_count,
      coalesce(c.names, 'null'),
      coalesce(c.statuses, 'null')
    ),
    '; '
    order by m.canonical_normalized_name
  )
  into collision_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join lateral (
    select
      count(*)::bigint as match_count,
      string_agg(distinct i.ingredient_name, ',' order by i.ingredient_name) as names,
      string_agg(distinct i.review_status, ',' order by i.review_status) as statuses
    from public.beautydna_ingredient_intelligence i
    where i.normalized_name = m.canonical_normalized_name
       or i.normalized_ingredient_name = m.canonical_normalized_name
  ) c on true
  where c.match_count > 1
     or (m.canonical_must_preexist and c.match_count <> 1)
     or (
       c.match_count = 1
       and (
         c.names <> m.canonical_name
         or c.statuses <> 'approved'
       )
     );

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A canonical collision: %',
      collision_details;
  end if;

  -- Alias rows may be absent or already point to the expected approved canonical.
  select string_agg(
    format(
      '%s alias_id=%s existing_target=%s expected_target=%s',
      m.source_name,
      a.id,
      a.ingredient_id,
      coalesce(i.id::text, 'missing')
    ),
    '; '
    order by m.normalized_source_name
  )
  into collision_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name = m.normalized_source_name
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  where (
      m.alias_required
      and (
        i.id is null
        or a.ingredient_id <> i.id
      )
    )
    or not m.alias_required;

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A alias collision: %',
      collision_details;
  end if;

  -- Alias source labels cannot independently own another approved canonical.
  select string_agg(
    format(
      '%s conflicts with canonical %s (%s)',
      m.source_name,
      i.ingredient_name,
      i.id
    ),
    '; '
    order by m.normalized_source_name
  )
  into collision_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.normalized_source_name
      or i.normalized_ingredient_name = m.normalized_source_name
    )
   and i.review_status = 'approved'
  where m.alias_required
    and (
      i.normalized_name <> m.canonical_normalized_name
      or i.normalized_ingredient_name <> m.canonical_normalized_name
    );

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A source-label canonical collision: %',
      collision_details;
  end if;

  -- Product rows must be either untouched or already correctly resolved.
  select string_agg(
    format(
      '%s product=%s ingredient_id=%s match=%s review=%s',
      m.source_name,
      pi.product_id,
      coalesce(pi.ingredient_id::text, 'null'),
      pi.match_status,
      pi.review_status
    ),
    '; '
    order by m.normalized_source_name
  )
  into mismatch_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_source_name
   and pi.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  where not (
    (
      pi.ingredient_id is null
      and pi.match_status = 'unmatched'
      and pi.review_status = 'needs_review'
    )
    or
    (
      i.id is not null
      and i.review_status = 'approved'
      and pi.ingredient_id = i.id
      and pi.match_status = case
        when m.alias_required then 'alias_match'
        else 'approved_match'
      end
      and pi.review_status = 'approved'
    )
  );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A unexpected product state: %',
      mismatch_details;
  end if;

  -- Queue rows must be either open/unresolved or correctly resolved.
  select string_agg(
    format(
      '%s queue=%s status=%s resolved_id=%s',
      m.source_name,
      q.id,
      q.status,
      coalesce(q.resolved_ingredient_id::text, 'null')
    ),
    '; '
    order by m.normalized_source_name
  )
  into mismatch_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_review_queue q
    on q.normalized_ingredient_name = m.normalized_source_name
   and q.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = q.product_id
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  where not (
    (
      q.status = 'open'
      and q.resolved_ingredient_id is null
    )
    or
    (
      i.id is not null
      and i.review_status = 'approved'
      and q.status = 'resolved'
      and q.resolved_ingredient_id = i.id
    )
  );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A unexpected queue state: %',
      mismatch_details;
  end if;

  -- Non-target launch rows are a fixed boundary for this batch.
  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_batch_2a_identity_map m
    where m.normalized_source_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 36 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 36 non-target matched rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_batch_2a_identity_map m
    where m.normalized_source_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 109 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 109 non-target unmatched rows; found %.',
      actual_count;
  end if;

  -- Preserve the two governed パラベン ambiguity holds.
  if (
    select count(*)
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_batch_2a_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = 'パラベン'
      and q.status = 'in_review'
      and q.resolved_ingredient_id is null
  ) <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2A expected two unchanged パラベン ambiguity holds.';
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2A refuses to run with compatibility-rule changes.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2A refuses to use the legacy match table.';
  end if;
end
$$;

-- ------------------------------------------------------------
-- Create the 21 missing canonical identity seeds.
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
  m.canonical_name,
  m.canonical_normalized_name,
  m.canonical_normalized_name,
  case
    when m.alias_required then array[m.source_name]::text[]
    else array[]::text[]
  end,
  m.ingredient_category,
  'medium',
  'Identity normalized in BDNA-ING-0004 Batch 2A. Full Ingredient Intelligence enrichment remains pending.',
  'approved',
  'beauty_os_admin',
  'beauty_os_admin',
  'beauty_os_admin',
  now(),
  jsonb_build_object(
    'build_id', 'BDNA-ING-0004',
    'batch_id', 'batch_2a',
    'record_type', 'verified_identity_seed',
    'identity_status', 'approved',
    'intelligence_enrichment_status', 'pending',
    'source_label', m.source_name,
    'normalized_source_label', m.normalized_source_name,
    'canonical_normalized_name', m.canonical_normalized_name,
    'alias_required', m.alias_required,
    'evidence_class', m.evidence_class,
    'identity_evidence_sources', jsonb_build_array(
      'JCIA cosmetic ingredient display-name list',
      'JCIA quasi-drug ingredient display-name list',
      'direct source-label INCI where applicable'
    ),
    'launch_scope_only', true,
    'original_strings_preserved', true,
    'customer_copy_scope', 'cosmetic_non_diagnostic'
  )
from tmp_bdna_ing_0004_batch_2a_identity_map m
where not exists (
  select 1
  from public.beautydna_ingredient_intelligence existing
  where existing.normalized_name = m.canonical_normalized_name
     or existing.normalized_ingredient_name = m.canonical_normalized_name
);

-- ------------------------------------------------------------
-- Create the 20 exact source-label aliases.
-- ------------------------------------------------------------

insert into public.beautydna_ingredient_aliases (
  ingredient_id,
  alias_name,
  normalized_alias_name,
  source,
  created_at,
  updated_at
)
select
  i.id,
  m.source_name,
  m.normalized_source_name,
  'beautydna_system',
  now(),
  now()
from tmp_bdna_ing_0004_batch_2a_identity_map m
join public.beautydna_ingredient_intelligence i
  on (
    i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  )
 and i.review_status = 'approved'
where m.alias_required
  and not exists (
    select 1
    from public.beautydna_ingredient_aliases existing
    where existing.normalized_alias_name = m.normalized_source_name
  );

-- ------------------------------------------------------------
-- Resolve the 22 product-ingredient rows without changing source names.
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.source_name,
    m.normalized_source_name,
    m.canonical_name,
    m.canonical_normalized_name,
    m.alias_required,
    m.evidence_class,
    i.id as ingredient_id
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
)
update public.beautydna_product_ingredients pi
set
  ingredient_id = rm.ingredient_id,
  match_status = case
    when rm.alias_required then 'alias_match'
    else 'approved_match'
  end,
  review_status = 'approved',
  metadata =
    coalesce(pi.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'matched_via', case
        when rm.alias_required then 'approved_source_label_alias'
        else 'approved_direct_canonical'
      end,
      'source_label', rm.source_name,
      'canonical_ingredient_name', rm.canonical_name,
      'canonical_normalized_name', rm.canonical_normalized_name,
      'identity_evidence_class', rm.evidence_class,
      'resolved_by_build', 'BDNA-ING-0004',
      'resolved_by_batch', 'batch_2a',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        pi.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_batch_2a_launch_products lp
where lp.product_id = pi.product_id
  and pi.normalized_ingredient_name = rm.normalized_source_name
  and pi.ingredient_name = rm.source_name;

-- ------------------------------------------------------------
-- Resolve the matching 22 review-queue rows.
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.source_name,
    m.normalized_source_name,
    m.canonical_name,
    m.canonical_normalized_name,
    m.alias_required,
    m.evidence_class,
    i.id as ingredient_id
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
)
update public.beautydna_ingredient_review_queue q
set
  status = 'resolved',
  resolved_ingredient_id = rm.ingredient_id,
  assigned_to = 'beauty_os_admin',
  notes = case
    when position(
      'Resolved by BDNA-ING-0004 Batch 2A using a verified exact identity.'
      in coalesce(q.notes, '')
    ) > 0 then q.notes
    else concat_ws(
      E'\n',
      nullif(q.notes, ''),
      'Resolved by BDNA-ING-0004 Batch 2A using a verified exact identity.'
    )
  end,
  metadata =
    coalesce(q.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action', case
        when rm.alias_required then 'resolve_verified_source_alias'
        else 'resolve_verified_direct_canonical'
      end,
      'source_label', rm.source_name,
      'canonical_ingredient_name', rm.canonical_name,
      'canonical_normalized_name', rm.canonical_normalized_name,
      'identity_evidence_class', rm.evidence_class,
      'resolved_by_build', 'BDNA-ING-0004',
      'resolved_by_batch', 'batch_2a',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        q.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_batch_2a_launch_products lp
where lp.product_id = q.product_id
  and q.normalized_ingredient_name = rm.normalized_source_name
  and q.ingredient_name = rm.source_name;

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
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.ingredient_name = m.canonical_name
   and i.review_status = 'approved';

  if actual_count <> 22 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 22 approved canonical mappings; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_intelligence i
  where i.metadata->>'build_id' = 'BDNA-ING-0004'
    and i.metadata->>'batch_id' = 'batch_2a'
    and i.metadata->>'record_type' = 'verified_identity_seed'
    and i.review_status = 'approved';

  if actual_count <> 21 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 21 newly seeded canonicals; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name = m.normalized_source_name
   and a.alias_name = m.source_name
   and a.ingredient_id = i.id
  where m.alias_required;

  if actual_count <> 20 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 20 correctly targeted aliases; found %.',
      actual_count;
  end if;

  if exists (
    select 1
    from tmp_bdna_ing_0004_batch_2a_identity_map m
    join public.beautydna_ingredient_aliases a
      on a.normalized_alias_name = m.normalized_source_name
    where not m.alias_required
  ) then
    raise exception
      'BDNA-ING-0004 batch 2A direct canonical unexpectedly has an alias.';
  end if;

  select string_agg(
    format(
      '%s product=%s source=%s canonical_id=%s actual_id=%s status=%s/%s',
      m.source_name,
      pi.product_id,
      pi.ingredient_name,
      i.id,
      coalesce(pi.ingredient_id::text, 'null'),
      pi.match_status,
      pi.review_status
    ),
    '; '
    order by m.normalized_source_name
  )
  into mismatch_details
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_source_name
   and pi.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id <> i.id
     or pi.match_status <> case
       when m.alias_required then 'alias_match'
       else 'approved_match'
     end
     or pi.review_status <> 'approved';

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2A product-link postcheck failed: %',
      mismatch_details;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_source_name
   and pi.ingredient_name = m.source_name
   and pi.ingredient_id = i.id
   and pi.match_status = case
     when m.alias_required then 'alias_match'
     else 'approved_match'
   end
   and pi.review_status = 'approved'
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id;

  if actual_count <> 22 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 22 resolved product rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2a_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_ingredient_review_queue q
    on q.normalized_ingredient_name = m.normalized_source_name
   and q.ingredient_name = m.source_name
   and q.status = 'resolved'
   and q.resolved_ingredient_id = i.id
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = q.product_id;

  if actual_count <> 22 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 22 resolved queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 58 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 58 matched launch rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 109 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 109 unmatched launch rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = q.product_id
  where q.status = 'open';

  if actual_count <> 107 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 107 open launch queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2a_launch_products lp
    on lp.product_id = q.product_id
  where q.status = 'in_review';

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2A expected 2 unchanged in-review rows; found %.',
      actual_count;
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2A modified compatibility rules unexpectedly.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2A modified the legacy match table unexpectedly.';
  end if;

  raise notice
    'BDNA-ING-0004 batch 2A verified: 22 identities, 21 new canonicals, 20 aliases, 22 resolved rows, 58/167 matched (34.73%%).';
end
$$;

commit;
