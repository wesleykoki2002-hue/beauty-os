-- Beauty Intelligence preflight checks
-- Run this file first. It makes no data changes.

select current_database() as database_name, now() as checked_at;

select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'beautydna_ingredient_intelligence',
    'beautydna_ingredient_aliases',
    'beautydna_ingredient_compatibility_rules',
    'beautydna_ingredient_review_queue',
    'beautydna_product_ingredients',
    'beautydna_product_ingredient_matches'
  )
order by table_name;

select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'beautydna_ingredient_intelligence',
    'beautydna_ingredient_aliases',
    'beautydna_ingredient_compatibility_rules'
  )
order by table_name, ordinal_position;

select count(*) as ingredient_rows
from public.beautydna_ingredient_intelligence;

-- Existing duplicates by commonly used candidate name columns.
do $$
declare
  has_canonical boolean;
  has_normalized boolean;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='beautydna_ingredient_intelligence'
      and column_name='canonical_inci_name'
  ) into has_canonical;

  select exists (
    select 1 from information_schema.columns
    where table_schema='public'
      and table_name='beautydna_ingredient_intelligence'
      and column_name='normalized_ingredient_name'
  ) into has_normalized;

  if not has_canonical then
    raise notice 'canonical_inci_name does not exist yet; foundation migration will add it.';
  end if;
  if not has_normalized then
    raise notice 'normalized_ingredient_name does not exist yet; foundation migration will add it.';
  end if;
end $$;

-- Save the results from this file before applying migrations.
