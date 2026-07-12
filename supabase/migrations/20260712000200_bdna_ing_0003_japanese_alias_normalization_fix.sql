-- ============================================================
-- BDNA-ING-0003
-- Japanese alias normalization fix
-- Target: Beauty OS Supabase hidsyvanaipxxyyhjgmc
--
-- The ingredient ingestion normalizer lowercases Latin characters:
--   ヒアルロン酸Na -> ヒアルロン酸na
--   セラミドNP     -> セラミドnp
--
-- Does not create new canonical ingredients.
-- Does not affect Athena OS.
-- ============================================================

begin;

create temporary table tmp_bdna_ing_0003_alias_fix (
  alias_name text primary key,
  corrected_normalized_alias_name text not null unique,
  canonical_normalized_name text not null
) on commit drop;

insert into tmp_bdna_ing_0003_alias_fix (
  alias_name,
  corrected_normalized_alias_name,
  canonical_normalized_name
)
values
  (
    'ヒアルロン酸Na',
    'ヒアルロン酸na',
    'hyaluronic acid'
  ),
  (
    'セラミドNP',
    'セラミドnp',
    'ceramide np'
  );

-- Confirm approved canonical records exist and that the corrected
-- normalized aliases are not assigned to another ingredient.

do $$
declare
  missing_canonical text;
  alias_collision text;
begin
  select string_agg(
    distinct m.canonical_normalized_name,
    ', '
  )
  into missing_canonical
  from tmp_bdna_ing_0003_alias_fix m
  left join public.beautydna_ingredient_intelligence i
    on i.normalized_name = m.canonical_normalized_name
   and i.review_status = 'approved'
  where i.id is null;

  if missing_canonical is not null then
    raise exception
      'Approved canonical ingredients missing: %',
      missing_canonical;
  end if;

  select string_agg(
    m.alias_name,
    ', '
  )
  into alias_collision
  from tmp_bdna_ing_0003_alias_fix m
  join public.beautydna_ingredient_aliases a
    on a.normalized_alias_name =
       m.corrected_normalized_alias_name
  join public.beautydna_ingredient_intelligence expected
    on expected.normalized_name =
       m.canonical_normalized_name
  where a.ingredient_id <> expected.id;

  if alias_collision is not null then
    raise exception
      'Corrected alias collision detected for: %',
      alias_collision;
  end if;
end
$$;

-- Correct the normalized form of the existing alias records.

update public.beautydna_ingredient_aliases a
set
  normalized_alias_name =
    m.corrected_normalized_alias_name,
  updated_at = now()
from tmp_bdna_ing_0003_alias_fix m
join public.beautydna_ingredient_intelligence i
  on i.normalized_name =
     m.canonical_normalized_name
 and i.review_status = 'approved'
where a.alias_name = m.alias_name
  and a.ingredient_id = i.id
  and a.normalized_alias_name <>
      m.corrected_normalized_alias_name;

-- Resolve the remaining launch product ingredient rows.

with resolved_map as (
  select
    m.alias_name,
    m.corrected_normalized_alias_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0003_alias_fix m
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

      'normalization_fix',
      true,

      'resolved_at',
      now()
    ),
  updated_at = now()
from resolved_map rm
where pi.normalized_ingredient_name =
      rm.corrected_normalized_alias_name
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

-- Resolve the corresponding queue rows.

with resolved_map as (
  select
    m.alias_name,
    m.corrected_normalized_alias_name,
    m.canonical_normalized_name,
    i.id as ingredient_id
  from tmp_bdna_ing_0003_alias_fix m
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

      'normalization_fix',
      true,

      'resolved_at',
      now()
    ),
  notes = concat_ws(
    E'\n',
    nullif(q.notes, ''),
    'Resolved by BDNA-ING-0003 after Japanese alias normalization correction.'
  ),
  updated_at = now()
from resolved_map rm
where q.normalized_ingredient_name =
      rm.corrected_normalized_alias_name
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