-- ============================================================
-- BDNA-ING-0003
-- Japanese labeling alias resolution — approved canonical pass 1
-- Target: Beauty OS Supabase hidsyvanaipxxyyhjgmc
--
-- Safe scope:
--   ヒアルロン酸Na       -> Hyaluronic Acid
--   加水分解ヒアルロン酸 -> Hyaluronic Acid
--   セラミドNP           -> Ceramide NP
--
-- Does not create new Ingredient Intelligence records.
-- Does not approve unresolved ingredients.
-- Does not touch Athena OS.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0003_alias_map (
  alias_name text primary key,
  normalized_alias_name text not null unique,
  canonical_normalized_name text not null
) on commit drop;

insert into tmp_bdna_ing_0003_alias_map (
  alias_name,
  normalized_alias_name,
  canonical_normalized_name
)
values
  (
    'ヒアルロン酸Na',
    'ヒアルロン酸Na',
    'hyaluronic acid'
  ),
  (
    '加水分解ヒアルロン酸',
    '加水分解ヒアルロン酸',
    'hyaluronic acid'
  ),
  (
    'セラミドNP',
    'セラミドNP',
    'ceramide np'
  );

-- ------------------------------------------------------------
-- Safety checks
-- ------------------------------------------------------------

do $$
declare
  missing_canonicals text;
  alias_collisions text;
begin
  select string_agg(
    distinct m.canonical_normalized_name,
    ', '
  )
  into missing_canonicals
  from tmp_bdna_ing_0003_alias_map m
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
   and i.review_status = 'approved'
  where i.id is null;

  if missing_canonicals is not null then
    raise exception
      'Approved canonical ingredients missing: %',
      missing_canonicals;
  end if;

  select string_agg(
    m.alias_name,
    ', '
  )
  into alias_collisions
  from tmp_bdna_ing_0003_alias_map m
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name = m.normalized_alias_name
  join public.beautydna_ingredient_intelligence expected
    on expected.normalized_name =
       m.canonical_normalized_name
  where a.ingredient_id <> expected.id;

  if alias_collisions is not null then
    raise exception
      'Alias collision detected for: %',
      alias_collisions;
  end if;
end
$$;

-- ------------------------------------------------------------
-- Add exact Japanese labeling aliases
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
from tmp_bdna_ing_0003_alias_map m
join public.beautydna_ingredient_intelligence i
  on i.normalized_name =
     m.canonical_normalized_name
 and i.review_status = 'approved'
where not exists (
  select 1
  from public.beautydna_ingredient_aliases existing
  where existing.normalized_alias_name =
        m.normalized_alias_name
);

-- ------------------------------------------------------------
-- Resolve matching launch product ingredient rows
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.alias_name,
    m.normalized_alias_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0003_alias_map m
  join public.beautydna_ingredient_intelligence i
    on i.normalized_name =
       m.canonical_normalized_name
   and i.review_status = 'approved'
)
update public.beautydna_product_ingredients pi
set
  ingredient_id = rm.ingredient_id,
  match_status = 'alias_match',
  review_status = 'approved',
  metadata =
    coalesce(pi.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'matched_via',
      'approved_japanese_label_alias',

      'alias_name',
      rm.alias_name,

      'canonical_normalized_name',
      rm.canonical_normalized_name,

      'resolved_by_build',
      'BDNA-ING-0003',

      'resolved_at',
      now()
    ),
  updated_at = now()
from resolved_map rm
where pi.normalized_ingredient_name =
      rm.normalized_alias_name
  and pi.ingredient_id is null
  and exists (
    select 1
    from public.beautydna_products p
    where p.id = pi.product_id
      and p.metadata->>'source_type' =
          'beautydna_launch_catalog'
      and p.metadata->>'source_key'
          like 'BDNA-ING-0003%'
  );

-- ------------------------------------------------------------
-- Resolve corresponding review queue rows
-- ------------------------------------------------------------

with resolved_map as (
  select
    m.alias_name,
    m.normalized_alias_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0003_alias_map m
  join public.beautydna_ingredient_intelligence i
    on i.normalized_name =
       m.canonical_normalized_name
   and i.review_status = 'approved'
)
update public.beautydna_ingredient_review_queue q
set
  status = 'resolved',
  resolved_ingredient_id = rm.ingredient_id,
  metadata =
    coalesce(q.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'action',
      'resolve_existing_approved_alias',

      'alias_name',
      rm.alias_name,

      'canonical_normalized_name',
      rm.canonical_normalized_name,

      'resolved_by_build',
      'BDNA-ING-0003',

      'resolved_at',
      now()
    ),
  notes = concat_ws(
    E'\n',
    nullif(q.notes, ''),
    'Resolved by BDNA-ING-0003 using an exact approved Japanese labeling alias.'
  ),
  updated_at = now()
from resolved_map rm
where q.normalized_ingredient_name =
      rm.normalized_alias_name
  and q.status = 'open'
  and exists (
    select 1
    from public.beautydna_products p
    where p.id = q.product_id
      and p.metadata->>'source_type' =
          'beautydna_launch_catalog'
      and p.metadata->>'source_key'
          like 'BDNA-ING-0003%'
  );

commit;
