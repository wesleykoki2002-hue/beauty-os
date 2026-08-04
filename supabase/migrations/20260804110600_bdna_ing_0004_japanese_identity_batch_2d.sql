-- ============================================================
-- BDNA-ING-0004
-- Japanese Ingredient Identity Normalization and Review-Queue Processing
-- Controlled identity batch 2D
--
-- Target system: Beauty OS / BeautyDNA
-- Target Supabase project: hidsyvanaipxxyyhjgmc
-- Tracking system: Athena CTO (governance only)
--
-- Governed scope:
--   - Five non-archived BeautyDNA launch products only.
--   - Resolve 20 exact, verified, one-row ingredient identities.
--   - Create 19 missing canonical identity seeds and reuse the approved Xylitol canonical.
--   - Create 20 exact Japanese source-label aliases.
--   - Preserve every original Japanese/source ingredient string.
--   - Keep the two パラベン ambiguity holds unchanged.
--
-- Identity evidence basis:
--   - Governed Batch 2D read-only collision gate.
--   - Verified direct Japanese-label identity mappings.
--   - No ambiguous EDTA, quasi-drug-solution, fragrance, complex PEG/PPG, or proprietary-name inference.
--
-- Detailed benefit, risk, compatibility, and customer-copy enrichment is
-- intentionally pending and is not approved by this identity-only batch.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0004_batch_2d_launch_products (
  product_id uuid primary key
) on commit drop;

insert into tmp_bdna_ing_0004_batch_2d_launch_products (product_id)
values
  ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid),
  ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
  ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
  ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
  ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid);

create temporary table tmp_bdna_ing_0004_batch_2d_identity_map (
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

insert into tmp_bdna_ing_0004_batch_2d_identity_map (
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
  ('エチルヘキシルトリアゾン', 'エチルヘキシルトリアゾン', 'Ethylhexyl Triazone', 'ethylhexyl triazone', 'uv_filter', true, 'direct_uv_filter', false, 1),
  ('ジエチルアミノヒドロキシベンゾイル安息香酸ヘキシル', 'ジエチルアミノヒドロキシベンゾイル安息香酸ヘキシル', 'Diethylamino Hydroxybenzoyl Hexyl Benzoate', 'diethylamino hydroxybenzoyl hexyl benzoate', 'uv_filter', true, 'direct_uv_filter', false, 1),
  ('ビスエチルヘキシルオキシフェノールメトキシフェニルトリアジン', 'ビスエチルヘキシルオキシフェノールメトキシフェニルトリアジン', 'Bis-Ethylhexyloxyphenol Methoxyphenyl Triazine', 'bis-ethylhexyloxyphenol methoxyphenyl triazine', 'uv_filter', true, 'direct_uv_filter', false, 1),
  ('キシリチルグルコシド', 'キシリチルグルコシド', 'Xylitylglucoside', 'xylitylglucoside', 'humectant_sugar_derivative', true, 'direct_identity', false, 1),
  ('グリコシルトレハロース', 'グリコシルトレハロース', 'Glycosyl Trehalose', 'glycosyl trehalose', 'humectant_sugar', true, 'direct_identity', false, 1),
  ('コーンスターチ', 'コーンスターチ', 'Zea Mays (Corn) Starch', 'zea mays (corn) starch', 'starch_absorbent', true, 'direct_starch', false, 1),
  ('シア脂', 'シア脂', 'Butyrospermum Parkii (Shea) Butter', 'butyrospermum parkii (shea) butter', 'botanical_lipid', true, 'direct_botanical_lipid', false, 1),
  ('ジステアルジモニウムヘクトライト', 'ジステアルジモニウムヘクトライト', 'Disteardimonium Hectorite', 'disteardimonium hectorite', 'rheology_modifier', true, 'direct_identity', false, 1),
  ('ステアロイルラクチレートNa', 'ステアロイルラクチレートna', 'Sodium Stearoyl Lactylate', 'sodium stearoyl lactylate', 'emulsifier_surfactant', true, 'direct_salt', false, 1),
  ('ラウロイルラクチレートNa', 'ラウロイルラクチレートna', 'Sodium Lauroyl Lactylate', 'sodium lauroyl lactylate', 'emulsifier_surfactant', true, 'direct_salt', false, 1),
  ('パルミチン酸デキストリン', 'パルミチン酸デキストリン', 'Dextrin Palmitate', 'dextrin palmitate', 'texture_modifier', true, 'direct_identity', false, 1),
  ('フィトステロールズ', 'フィトステロールズ', 'Phytosterols', 'phytosterols', 'barrier_lipid', true, 'direct_barrier_lipid', false, 1),
  ('ペンタステアリン酸ポリグリセリル-10', 'ペンタステアリン酸ポリグリセリル-10', 'Polyglyceryl-10 Pentastearate', 'polyglyceryl-10 pentastearate', 'emulsifier', true, 'direct_identity', false, 1),
  ('ホホバ種子油', 'ホホバ種子油', 'Simmondsia Chinensis (Jojoba) Seed Oil', 'simmondsia chinensis (jojoba) seed oil', 'botanical_lipid', true, 'direct_botanical_lipid', false, 1),
  ('ポリクオタニウム-51', 'ポリクオタニウム-51', 'Polyquaternium-51', 'polyquaternium-51', 'film_forming_humectant_polymer', true, 'direct_polymer', false, 1),
  ('マルチトール', 'マルチトール', 'Maltitol', 'maltitol', 'humectant_sugar_alcohol', true, 'direct_identity', false, 1),
  ('メドウフォーム種子油', 'メドウフォーム種子油', 'Limnanthes Alba (Meadowfoam) Seed Oil', 'limnanthes alba (meadowfoam) seed oil', 'botanical_lipid', true, 'direct_botanical_lipid', false, 1),
  ('加水分解水添デンプン', '加水分解水添デンプン', 'Hydrogenated Starch Hydrolysate', 'hydrogenated starch hydrolysate', 'humectant_sugar_derivative', true, 'direct_identity', false, 1),
  ('水溶性コラーゲン', '水溶性コラーゲン', 'Soluble Collagen', 'soluble collagen', 'film_forming_humectant', true, 'direct_identity', false, 1),
  ('無水キシリトール', '無水キシリトール', 'Xylitol', 'xylitol', 'humectant_sugar_alcohol', true, 'existing_canonical_alias', true, 1);

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
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = p.id
  where p.approval_status <> 'archived';

  if actual_count <> 5 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 5 non-archived launch products; found %.',
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
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id;

  if matched_count not in (96, 116)
     or unmatched_count not in (71, 51) then
    raise exception
      'BDNA-ING-0004 batch 2D unexpected launch baseline: matched=% unmatched=%.',
      matched_count,
      unmatched_count;
  end if;

  select
    count(*) filter (where q.status = 'open'),
    count(*) filter (where q.status = 'in_review')
  into open_queue_count, in_review_queue_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = q.product_id;

  if open_queue_count not in (69, 49)
     or in_review_queue_count <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2D unexpected queue baseline: open=% in_review=%.',
      open_queue_count,
      in_review_queue_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id;

  if actual_count <> 167 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 167 launch ingredient rows; found %.',
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
  left join lateral (
    select count(*)::bigint as product_rows
    from public.beautydna_product_ingredients pi
    join tmp_bdna_ing_0004_batch_2d_launch_products lp
      on lp.product_id = pi.product_id
    where pi.normalized_ingredient_name = m.normalized_source_name
      and pi.ingredient_name = m.source_name
  ) ps on true
  left join lateral (
    select count(*)::bigint as queue_rows
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_batch_2d_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = m.normalized_source_name
      and q.ingredient_name = m.source_name
  ) qs on true
  where coalesce(ps.product_rows, 0) <> m.expected_rows
     or coalesce(qs.queue_rows, 0) <> m.expected_rows;

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2D source-scope mismatch: %',
      mismatch_details;
  end if;

  -- Canonical identities may be absent or already correctly present.
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'BDNA-ING-0004 batch 2D canonical collision: %',
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'BDNA-ING-0004 batch 2D alias collision: %',
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'BDNA-ING-0004 batch 2D source-label canonical collision: %',
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_source_name
   and pi.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
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
      'BDNA-ING-0004 batch 2D unexpected product state: %',
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
  join public.beautydna_ingredient_review_queue q
    on q.normalized_ingredient_name = m.normalized_source_name
   and q.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
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
      'BDNA-ING-0004 batch 2D unexpected queue state: %',
      mismatch_details;
  end if;

  -- Non-target launch rows are a fixed boundary for this batch.
  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_batch_2d_identity_map m
    where m.normalized_source_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 96 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 96 non-target matched rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_batch_2d_identity_map m
    where m.normalized_source_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 51 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 51 non-target unmatched rows; found %.',
      actual_count;
  end if;

  -- Preserve the two governed パラベン ambiguity holds.
  if (
    select count(*)
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_batch_2d_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = 'パラベン'
      and q.status = 'in_review'
      and q.resolved_ingredient_id is null
  ) <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2D expected two unchanged パラベン ambiguity holds.';
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2D refuses to run with compatibility-rule changes.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2D refuses to use the legacy match table.';
  end if;
end
$$;

-- ------------------------------------------------------------
-- Create 19 missing canonical identity seeds and reuse approved Xylitol.
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
  'Identity normalized in BDNA-ING-0004 Batch 2D. Full Ingredient Intelligence enrichment remains pending.',
  'approved',
  'beauty_os_admin',
  'beauty_os_admin',
  'beauty_os_admin',
  now(),
  jsonb_build_object(
    'build_id', 'BDNA-ING-0004',
    'batch_id', 'batch_2d',
    'record_type', 'verified_identity_seed',
    'identity_status', 'approved',
    'intelligence_enrichment_status', 'pending',
    'source_label', m.source_name,
    'normalized_source_label', m.normalized_source_name,
    'canonical_normalized_name', m.canonical_normalized_name,
    'alias_required', m.alias_required,
    'evidence_class', m.evidence_class,
    'identity_evidence_sources', jsonb_build_array(
      'governed Batch 2D collision gate',
      'verified Japanese source-label identity mapping',
      'identity-only normalization; enrichment pending'
    ),
    'launch_scope_only', true,
    'original_strings_preserved', true,
    'customer_copy_scope', 'cosmetic_non_diagnostic'
  )
from tmp_bdna_ing_0004_batch_2d_identity_map m
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
from tmp_bdna_ing_0004_batch_2d_identity_map m
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
-- Resolve the 20 product-ingredient rows without changing source names.
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'resolved_by_batch', 'batch_2d',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        pi.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_batch_2d_launch_products lp
where lp.product_id = pi.product_id
  and pi.normalized_ingredient_name = rm.normalized_source_name
  and pi.ingredient_name = rm.source_name;

-- ------------------------------------------------------------
-- Resolve the matching 20 review-queue rows.
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'Resolved by BDNA-ING-0004 Batch 2D using a verified exact identity.'
      in coalesce(q.notes, '')
    ) > 0 then q.notes
    else concat_ws(
      E'\n',
      nullif(q.notes, ''),
      'Resolved by BDNA-ING-0004 Batch 2D using a verified exact identity.'
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
      'resolved_by_batch', 'batch_2d',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        q.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_batch_2d_launch_products lp
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.ingredient_name = m.canonical_name
   and i.review_status = 'approved';

  if actual_count <> 20 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 20 approved canonical mappings; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_intelligence i
  where i.metadata->>'build_id' = 'BDNA-ING-0004'
    and i.metadata->>'batch_id' = 'batch_2d'
    and i.metadata->>'record_type' = 'verified_identity_seed'
    and i.review_status = 'approved';

  if actual_count <> 19 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 19 newly seeded canonicals; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
      'BDNA-ING-0004 batch 2D expected 20 correctly targeted aliases; found %.',
      actual_count;
  end if;

  if exists (
    select 1
    from tmp_bdna_ing_0004_batch_2d_identity_map m
    join public.beautydna_ingredient_aliases a
      on a.normalized_alias_name = m.normalized_source_name
    where not m.alias_required
  ) then
    raise exception
      'BDNA-ING-0004 batch 2D direct canonical unexpectedly has an alias.';
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
  from tmp_bdna_ing_0004_batch_2d_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_source_name
   and pi.ingredient_name = m.source_name
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id <> i.id
     or pi.match_status <> case
       when m.alias_required then 'alias_match'
       else 'approved_match'
     end
     or pi.review_status <> 'approved';

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 batch 2D product-link postcheck failed: %',
      mismatch_details;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id;

  if actual_count <> 20 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 20 resolved product rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_batch_2d_identity_map m
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
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = q.product_id;

  if actual_count <> 20 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 20 resolved queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 116 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 116 matched launch rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 51 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 51 unmatched launch rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = q.product_id
  where q.status = 'open';

  if actual_count <> 49 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 49 open launch queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_batch_2d_launch_products lp
    on lp.product_id = q.product_id
  where q.status = 'in_review';

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 batch 2D expected 2 unchanged in-review rows; found %.',
      actual_count;
  end if;

  if (
    select count(*)
    from public.beautydna_ingredient_compatibility_rules
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2D modified compatibility rules unexpectedly.';
  end if;

  if (
    select count(*)
    from public.beautydna_product_ingredient_matches
  ) <> 0 then
    raise exception
      'BDNA-ING-0004 batch 2D modified the legacy match table unexpectedly.';
  end if;

  raise notice
    'BDNA-ING-0004 batch 2D verified: 20 identities, 19 new canonicals, 20 aliases, 20 resolved rows, 116/167 matched (69.46%%).';
end
$$;

commit;
