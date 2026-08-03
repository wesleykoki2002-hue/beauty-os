-- ============================================================
-- BDNA-ING-0004
-- Japanese Ingredient Identity Normalization and Review-Queue Processing
-- Controlled identity batch 1
--
-- Target system: Beauty OS / BeautyDNA
-- Target Supabase project: hidsyvanaipxxyyhjgmc
-- Tracking system: Athena CTO (governance only)
--
-- Governed scope:
--   - Five non-archived BeautyDNA launch products only.
--   - Create 12 verified canonical ingredient identities.
--   - Create 12 exact source-label aliases.
--   - Resolve 32 matching product-ingredient and queue rows.
--   - Preserve every original Japanese/source ingredient string.
--   - Keep two パラベン rows unresolved and move their queue rows to in_review.
--
-- Explicitly out of scope:
--   - Athena product tables and Athena lifecycle records.
--   - Archived products.
--   - beautydna_product_ingredient_matches.
--   - Compatibility rules, recommendations, assessments, passports, Shopify,
--     and unrelated systems.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0004_launch_products (
  product_id uuid primary key
) on commit drop;

insert into tmp_bdna_ing_0004_launch_products (product_id)
values
  ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid),
  ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
  ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
  ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
  ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid);

create temporary table tmp_bdna_ing_0004_identity_map (
  alias_name text primary key,
  normalized_alias_name text not null unique,
  canonical_name text,
  canonical_normalized_name text,
  ingredient_category text,
  expected_rows integer not null check (expected_rows > 0),
  governed_outcome text not null
    check (governed_outcome in ('resolve', 'hold_ambiguous')),
  check (
    (governed_outcome = 'resolve'
      and canonical_name is not null
      and canonical_normalized_name is not null)
    or
    (governed_outcome = 'hold_ambiguous'
      and canonical_name is null
      and canonical_normalized_name is null)
  )
) on commit drop;

insert into tmp_bdna_ing_0004_identity_map (
  alias_name,
  normalized_alias_name,
  canonical_name,
  canonical_normalized_name,
  ingredient_category,
  expected_rows,
  governed_outcome
)
values
  ('BG', 'bg', 'Butylene Glycol', 'butylene glycol', 'humectant_solvent', 4, 'resolve'),
  ('グリセリン', 'グリセリン', 'Glycerin', 'glycerin', 'humectant', 4, 'resolve'),
  ('フェノキシエタノール', 'フェノキシエタノール', 'Phenoxyethanol', 'phenoxyethanol', 'preservative', 4, 'resolve'),
  ('水', '水', 'Water', 'water', 'solvent', 4, 'resolve'),
  ('アセチルヒアルロン酸Na', 'アセチルヒアルロン酸na', 'Sodium Acetylated Hyaluronate', 'sodium acetylated hyaluronate', 'humectant', 2, 'resolve'),
  ('アラントイン', 'アラントイン', 'Allantoin', 'allantoin', 'skin_conditioning', 2, 'resolve'),
  ('カルボマー', 'カルボマー', 'Carbomer', 'carbomer', 'viscosity_control', 2, 'resolve'),
  ('キサンタンガム', 'キサンタンガム', 'Xanthan Gum', 'xanthan gum', 'viscosity_control', 2, 'resolve'),
  ('グリチルリチン酸2K', 'グリチルリチン酸2k', 'Dipotassium Glycyrrhizate', 'dipotassium glycyrrhizate', 'skin_conditioning', 2, 'resolve'),
  ('コハク酸', 'コハク酸', 'Succinic Acid', 'succinic acid', 'ph_adjuster', 2, 'resolve'),
  ('ジメチコン', 'ジメチコン', 'Dimethicone', 'dimethicone', 'silicone_emollient', 2, 'resolve'),
  ('水酸化K', '水酸化k', 'Potassium Hydroxide', 'potassium hydroxide', 'ph_adjuster', 2, 'resolve'),
  ('パラベン', 'パラベン', null, null, null, 2, 'hold_ambiguous');

-- ------------------------------------------------------------
-- Fail-closed preflight
-- ------------------------------------------------------------

do $$
declare
  actual_count bigint;
  mismatch_details text;
  collision_details text;
begin
  select count(*)
  into actual_count
  from public.beautydna_products p
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = p.id
  where p.approval_status <> 'archived';

  if actual_count <> 5 then
    raise exception
      'BDNA-ING-0004 expected 5 non-archived launch products; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id;

  if actual_count <> 167 then
    raise exception
      'BDNA-ING-0004 expected 167 launch ingredient rows; found %.',
      actual_count;
  end if;

  select string_agg(
    format(
      '%s expected=%s product_rows=%s queue_rows=%s',
      m.alias_name,
      m.expected_rows,
      coalesce(ps.product_rows, 0),
      coalesce(qs.queue_rows, 0)
    ),
    '; '
    order by m.normalized_alias_name
  )
  into mismatch_details
  from tmp_bdna_ing_0004_identity_map m
  left join lateral (
    select count(*)::bigint as product_rows
    from public.beautydna_product_ingredients pi
    join tmp_bdna_ing_0004_launch_products lp
      on lp.product_id = pi.product_id
    where pi.normalized_ingredient_name = m.normalized_alias_name
      and pi.ingredient_name = m.alias_name
  ) ps on true
  left join lateral (
    select count(*)::bigint as queue_rows
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = m.normalized_alias_name
      and q.ingredient_name = m.alias_name
  ) qs on true
  where coalesce(ps.product_rows, 0) <> m.expected_rows
     or coalesce(qs.queue_rows, 0) <> m.expected_rows;

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 source-scope mismatch: %',
      mismatch_details;
  end if;

  -- Every resolvable product row must be either untouched/unmatched or already
  -- resolved to the expected canonical identity by this same migration.
  select string_agg(
    format(
      '%s product=%s ingredient_id=%s match_status=%s review_status=%s',
      m.alias_name,
      pi.product_id,
      coalesce(pi.ingredient_id::text, 'null'),
      pi.match_status,
      pi.review_status
    ),
    '; '
    order by m.normalized_alias_name, pi.product_id
  )
  into mismatch_details
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_alias_name
   and pi.ingredient_name = m.alias_name
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  left join public.beautydna_ingredient_intelligence i
    on m.canonical_normalized_name is not null
   and (
     i.normalized_name = m.canonical_normalized_name
     or i.normalized_ingredient_name = m.canonical_normalized_name
   )
  where m.governed_outcome = 'resolve'
    and not (
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
        and pi.match_status = 'alias_match'
        and pi.review_status = 'approved'
      )
    );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 unexpected product-ingredient state: %',
      mismatch_details;
  end if;

  -- Every resolvable queue row must be either open/unresolved or already
  -- resolved to the expected canonical identity by this same migration.
  select string_agg(
    format(
      '%s queue=%s status=%s resolved_ingredient_id=%s',
      m.alias_name,
      q.id,
      q.status,
      coalesce(q.resolved_ingredient_id::text, 'null')
    ),
    '; '
    order by m.normalized_alias_name, q.id
  )
  into mismatch_details
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_review_queue q
    on q.normalized_ingredient_name = m.normalized_alias_name
   and q.ingredient_name = m.alias_name
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = q.product_id
  left join public.beautydna_ingredient_intelligence i
    on m.canonical_normalized_name is not null
   and (
     i.normalized_name = m.canonical_normalized_name
     or i.normalized_ingredient_name = m.canonical_normalized_name
   )
  where m.governed_outcome = 'resolve'
    and not (
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
      'BDNA-ING-0004 unexpected queue state: %',
      mismatch_details;
  end if;

  -- パラベン must remain unresolved. Replays may see open or in_review.
  if exists (
    select 1
    from public.beautydna_product_ingredients pi
    join tmp_bdna_ing_0004_launch_products lp
      on lp.product_id = pi.product_id
    where pi.normalized_ingredient_name = 'パラベン'
      and (
        pi.ingredient_id is not null
        or pi.match_status <> 'unmatched'
        or pi.review_status <> 'needs_review'
      )
  ) then
    raise exception
      'BDNA-ING-0004 refuses to resolve ambiguous パラベン product rows.';
  end if;

  if exists (
    select 1
    from public.beautydna_ingredient_review_queue q
    join tmp_bdna_ing_0004_launch_products lp
      on lp.product_id = q.product_id
    where q.normalized_ingredient_name = 'パラベン'
      and (
        q.status not in ('open', 'in_review')
        or q.resolved_ingredient_id is not null
      )
  ) then
    raise exception
      'BDNA-ING-0004 found an unexpected resolved/rejected パラベン queue state.';
  end if;

  -- Block duplicate or conflicting canonical identities.
  select string_agg(
    format(
      '%s canonical_matches=%s statuses=%s names=%s',
      m.canonical_normalized_name,
      c.match_count,
      c.statuses,
      c.names
    ),
    '; '
    order by m.canonical_normalized_name
  )
  into collision_details
  from tmp_bdna_ing_0004_identity_map m
  join lateral (
    select
      count(*)::bigint as match_count,
      string_agg(distinct i.review_status, ',' order by i.review_status) as statuses,
      string_agg(distinct i.ingredient_name, ',' order by i.ingredient_name) as names
    from public.beautydna_ingredient_intelligence i
    where i.normalized_name = m.canonical_normalized_name
       or i.normalized_ingredient_name = m.canonical_normalized_name
  ) c on true
  where m.governed_outcome = 'resolve'
    and (
      c.match_count > 1
      or (
        c.match_count = 1
        and (
          c.statuses <> 'approved'
          or c.names <> m.canonical_name
        )
      )
    );

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 canonical collision: %',
      collision_details;
  end if;

  -- Block Japanese/source aliases already owned by another canonical identity,
  -- and block an alias existing before its expected canonical exists.
  select string_agg(
    format(
      '%s existing_alias_id=%s existing_target=%s expected_target=%s',
      m.alias_name,
      a.id,
      a.ingredient_id,
      coalesce(i.id::text, 'missing')
    ),
    '; '
    order by m.normalized_alias_name
  )
  into collision_details
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name = m.normalized_alias_name
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  where m.governed_outcome = 'resolve'
    and (
      i.id is null
      or a.ingredient_id <> i.id
    );

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 alias collision: %',
      collision_details;
  end if;

  -- A source alias cannot also be a different approved canonical identity.
  select string_agg(
    format(
      '%s conflicts with canonical %s (%s)',
      m.alias_name,
      i.ingredient_name,
      i.id
    ),
    '; '
    order by m.normalized_alias_name
  )
  into collision_details
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.normalized_alias_name
      or i.normalized_ingredient_name = m.normalized_alias_name
    )
   and i.review_status = 'approved'
  where m.governed_outcome = 'resolve';

  if collision_details is not null then
    raise exception
      'BDNA-ING-0004 source-label canonical collision: %',
      collision_details;
  end if;

  -- The ambiguous class label must not already be approved as a canonical or alias.
  if exists (
    select 1
    from public.beautydna_ingredient_intelligence i
    where i.review_status = 'approved'
      and (
        i.normalized_name = 'パラベン'
        or i.normalized_ingredient_name = 'パラベン'
      )
  ) or exists (
    select 1
    from public.beautydna_ingredient_aliases a
    where a.normalized_alias_name = 'パラベン'
  ) then
    raise exception
      'BDNA-ING-0004 ambiguity policy conflict: パラベン is already registered.';
  end if;

  -- Non-target launch rows must retain the known baseline. This prevents the
  -- controlled batch from hiding unrelated changes.
  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_identity_map m
    where m.normalized_alias_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 4 then
    raise exception
      'BDNA-ING-0004 expected 4 existing non-target matched rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where not exists (
    select 1
    from tmp_bdna_ing_0004_identity_map m
    where m.normalized_alias_name = pi.normalized_ingredient_name
  )
    and pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 129 then
    raise exception
      'BDNA-ING-0004 expected 129 non-target unmatched rows; found %.',
      actual_count;
  end if;
end
$$;

-- ------------------------------------------------------------
-- Create the 12 verified canonical identity records.
-- Detailed benefit/safety enrichment intentionally remains pending.
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
  array[m.alias_name]::text[],
  m.ingredient_category,
  'medium',
  'Identity normalization approved in BDNA-ING-0004. Full Ingredient Intelligence enrichment remains pending.',
  'approved',
  'beauty_os_admin',
  'beauty_os_admin',
  'beauty_os_admin',
  now(),
  jsonb_build_object(
    'build_id', 'BDNA-ING-0004',
    'record_type', 'verified_identity_seed',
    'identity_status', 'approved',
    'intelligence_enrichment_status', 'pending',
    'source_label', m.alias_name,
    'normalized_source_label', m.normalized_alias_name,
    'canonical_normalized_name', m.canonical_normalized_name,
    'launch_scope_only', true,
    'original_strings_preserved', true,
    'customer_copy_scope', 'cosmetic_non_diagnostic'
  )
from tmp_bdna_ing_0004_identity_map m
where m.governed_outcome = 'resolve'
  and not exists (
    select 1
    from public.beautydna_ingredient_intelligence existing
    where existing.normalized_name = m.canonical_normalized_name
       or existing.normalized_ingredient_name = m.canonical_normalized_name
  );

-- ------------------------------------------------------------
-- Create the exact source-label aliases.
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
  m.alias_name,
  m.normalized_alias_name,
  'beautydna_system',
  now(),
  now()
from tmp_bdna_ing_0004_identity_map m
join public.beautydna_ingredient_intelligence i
  on (
    i.normalized_name = m.canonical_normalized_name
    or i.normalized_ingredient_name = m.canonical_normalized_name
  )
 and i.review_status = 'approved'
where m.governed_outcome = 'resolve'
  and not exists (
    select 1
    from public.beautydna_ingredient_aliases existing
    where existing.normalized_alias_name = m.normalized_alias_name
  );

-- ------------------------------------------------------------
-- Deterministically resolve the 32 launch product ingredient rows.
-- ingredient_name is intentionally not updated, preserving source strings.
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.alias_name,
    m.normalized_alias_name,
    m.canonical_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  where m.governed_outcome = 'resolve'
)
update public.beautydna_product_ingredients pi
set
  ingredient_id = rm.ingredient_id,
  match_status = 'alias_match',
  review_status = 'approved',
  metadata =
    coalesce(pi.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'matched_via', 'approved_japanese_label_alias',
      'alias_name', rm.alias_name,
      'canonical_ingredient_name', rm.canonical_name,
      'canonical_normalized_name', rm.canonical_normalized_name,
      'resolved_by_build', 'BDNA-ING-0004',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        pi.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_launch_products lp
where lp.product_id = pi.product_id
  and pi.normalized_ingredient_name = rm.normalized_alias_name
  and pi.ingredient_name = rm.alias_name;

-- ------------------------------------------------------------
-- Resolve the matching 32 review-queue rows.
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.alias_name,
    m.normalized_alias_name,
    m.canonical_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  where m.governed_outcome = 'resolve'
)
update public.beautydna_ingredient_review_queue q
set
  status = 'resolved',
  resolved_ingredient_id = rm.ingredient_id,
  assigned_to = 'beauty_os_admin',
  notes = case
    when position(
      'Resolved by BDNA-ING-0004 using a verified exact source-label alias.'
      in coalesce(q.notes, '')
    ) > 0 then q.notes
    else concat_ws(
      E'\n',
      nullif(q.notes, ''),
      'Resolved by BDNA-ING-0004 using a verified exact source-label alias.'
    )
  end,
  metadata =
    coalesce(q.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action', 'resolve_verified_existing_or_created_alias',
      'alias_name', rm.alias_name,
      'canonical_ingredient_name', rm.canonical_name,
      'canonical_normalized_name', rm.canonical_normalized_name,
      'resolved_by_build', 'BDNA-ING-0004',
      'original_ingredient_name_preserved', true,
      'resolved_at', coalesce(
        q.metadata->>'resolved_at',
        now()::text
      )
    ),
  updated_at = now()
from resolved_map rm,
     tmp_bdna_ing_0004_launch_products lp
where lp.product_id = q.product_id
  and q.normalized_ingredient_name = rm.normalized_alias_name
  and q.ingredient_name = rm.alias_name;

-- ------------------------------------------------------------
-- Preserve パラベン as unresolved ambiguity.
-- ------------------------------------------------------------

update public.beautydna_product_ingredients pi
set
  metadata =
    coalesce(pi.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'identity_review_status', 'ambiguous_class_label',
      'ambiguity_reason', 'The source label パラベン does not identify a specific paraben.',
      'held_by_build', 'BDNA-ING-0004',
      'original_ingredient_name_preserved', true,
      'held_at', coalesce(
        pi.metadata->>'held_at',
        now()::text
      )
    ),
  updated_at = now()
from tmp_bdna_ing_0004_launch_products lp
where lp.product_id = pi.product_id
  and pi.normalized_ingredient_name = 'パラベン'
  and pi.ingredient_name = 'パラベン'
  and pi.ingredient_id is null
  and pi.match_status = 'unmatched'
  and pi.review_status = 'needs_review';

update public.beautydna_ingredient_review_queue q
set
  status = 'in_review',
  assigned_to = 'beauty_os_admin',
  notes = case
    when position(
      'BDNA-ING-0004 ambiguity hold: パラベン is a generic class label.'
      in coalesce(q.notes, '')
    ) > 0 then q.notes
    else concat_ws(
      E'\n',
      nullif(q.notes, ''),
      'BDNA-ING-0004 ambiguity hold: パラベン is a generic class label. Verify the exact paraben from authoritative product evidence before resolution.'
    )
  end,
  metadata =
    coalesce(q.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action', 'hold_ambiguous_identity',
      'ambiguity_reason', 'The source label パラベン does not identify a specific paraben.',
      'held_by_build', 'BDNA-ING-0004',
      'requires_exact_product_evidence', true,
      'original_ingredient_name_preserved', true,
      'held_at', coalesce(
        q.metadata->>'held_at',
        now()::text
      )
    ),
  updated_at = now()
from tmp_bdna_ing_0004_launch_products lp
where lp.product_id = q.product_id
  and q.normalized_ingredient_name = 'パラベン'
  and q.ingredient_name = 'パラベン'
  and q.resolved_ingredient_id is null
  and q.status in ('open', 'in_review');

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
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.ingredient_name = m.canonical_name
   and i.review_status = 'approved'
  where m.governed_outcome = 'resolve';

  if actual_count <> 12 then
    raise exception
      'BDNA-ING-0004 expected 12 approved canonical identities; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name = m.normalized_alias_name
   and a.alias_name = m.alias_name
   and a.ingredient_id = i.id
  where m.governed_outcome = 'resolve';

  if actual_count <> 12 then
    raise exception
      'BDNA-ING-0004 expected 12 correctly targeted aliases; found %.',
      actual_count;
  end if;

  select string_agg(
    format(
      '%s product=%s ingredient_name=%s canonical_id=%s actual_id=%s status=%s/%s',
      m.alias_name,
      pi.product_id,
      pi.ingredient_name,
      i.id,
      coalesce(pi.ingredient_id::text, 'null'),
      pi.match_status,
      pi.review_status
    ),
    '; '
    order by m.normalized_alias_name, pi.product_id
  )
  into mismatch_details
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_alias_name
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where m.governed_outcome = 'resolve'
    and (
      pi.ingredient_name <> m.alias_name
      or pi.ingredient_id <> i.id
      or pi.match_status <> 'alias_match'
      or pi.review_status <> 'approved'
    );

  if mismatch_details is not null then
    raise exception
      'BDNA-ING-0004 product-link postcheck failed: %',
      mismatch_details;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_product_ingredients pi
    on pi.normalized_ingredient_name = m.normalized_alias_name
   and pi.ingredient_name = m.alias_name
   and pi.ingredient_id = i.id
   and pi.match_status = 'alias_match'
   and pi.review_status = 'approved'
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where m.governed_outcome = 'resolve';

  if actual_count <> 32 then
    raise exception
      'BDNA-ING-0004 expected 32 resolved launch product rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from tmp_bdna_ing_0004_identity_map m
  join public.beautydna_ingredient_intelligence i
    on (
      i.normalized_name = m.canonical_normalized_name
      or i.normalized_ingredient_name = m.canonical_normalized_name
    )
   and i.review_status = 'approved'
  join public.beautydna_ingredient_review_queue q
    on q.normalized_ingredient_name = m.normalized_alias_name
   and q.ingredient_name = m.alias_name
   and q.status = 'resolved'
   and q.resolved_ingredient_id = i.id
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = q.product_id
  where m.governed_outcome = 'resolve';

  if actual_count <> 32 then
    raise exception
      'BDNA-ING-0004 expected 32 resolved launch queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where pi.normalized_ingredient_name = 'パラベン'
    and pi.ingredient_name = 'パラベン'
    and pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 expected 2 unresolved パラベン product rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = q.product_id
  where q.normalized_ingredient_name = 'パラベン'
    and q.ingredient_name = 'パラベン'
    and q.status = 'in_review'
    and q.resolved_ingredient_id is null;

  if actual_count <> 2 then
    raise exception
      'BDNA-ING-0004 expected 2 in-review パラベン queue rows; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is not null
    and pi.match_status in ('approved_match', 'alias_match')
    and pi.review_status = 'approved';

  if actual_count <> 36 then
    raise exception
      'BDNA-ING-0004 expected 36 matched launch rows after batch 1; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_product_ingredients pi
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = pi.product_id
  where pi.ingredient_id is null
    and pi.match_status = 'unmatched'
    and pi.review_status = 'needs_review';

  if actual_count <> 131 then
    raise exception
      'BDNA-ING-0004 expected 131 unmatched launch rows after batch 1; found %.',
      actual_count;
  end if;

  select count(*)
  into actual_count
  from public.beautydna_ingredient_review_queue q
  join tmp_bdna_ing_0004_launch_products lp
    on lp.product_id = q.product_id
  where q.status = 'open';

  if actual_count <> 129 then
    raise exception
      'BDNA-ING-0004 expected 129 open launch queue rows after batch 1; found %.',
      actual_count;
  end if;

  raise notice
    'BDNA-ING-0004 batch 1 verified: 12 canonicals, 12 aliases, 32 resolved rows, 2 ambiguous holds, 36/167 matched (21.56%%).';
end
$$;

commit;
