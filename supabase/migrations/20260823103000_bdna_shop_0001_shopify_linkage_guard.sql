-- BDNA-SHOP-0001
-- BeautyDNA Offline Shopify Catalog Adapter and Launch Product Linkage Foundation
--
-- Target database:
--   Beauty OS / BeautyDNA
--   Supabase project ref: hidsyvanaipxxyyhjgmc
--
-- Scope:
--   Add the minimum database guard required for future verified Shopify
--   returned-ID linkage. This migration performs no Shopify API call and
--   does not alter Product DNA or recommendation-readiness ownership.
--
-- Canonical write rule:
--   beautydna_products remains the product source of truth, while Shopify
--   linkage fields may change only through the guarded linkage boundary.

-- ---------------------------------------------------------------------
-- Precondition guard.
-- Fail closed if pre-existing data would make the new invariants unsafe.
-- ---------------------------------------------------------------------

do $$
begin
  if exists (
    select 1
    from public.beautydna_products
    where shopify_product_id is not null
    group by shopify_product_id
    having count(*) > 1
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: duplicate shopify_product_id values already exist.';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_variant_id is not null
    group by shopify_variant_id
    having count(*) > 1
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: duplicate shopify_variant_id values already exist.';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_product_id is not null
      and shopify_product_id !~ '^gid://shopify/Product/[1-9][0-9]*$'
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: noncanonical Shopify Product GID already exists.';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_variant_id is not null
      and shopify_variant_id !~ '^gid://shopify/ProductVariant/[1-9][0-9]*$'
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: noncanonical Shopify ProductVariant GID already exists.';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_variant_id is not null
      and shopify_product_id is null
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: variant linkage exists without product linkage.';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_status = 'linked'
      and (
        shopify_product_id is null
        or shopify_variant_id is null
      )
  ) then
    raise exception
      'BDNA-SHOP-0001 precondition failed: linked status exists without complete Shopify linkage.';
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- Database-level duplicate safety.
-- ---------------------------------------------------------------------

create unique index if not exists
  idx_beautydna_products_shopify_product_id_unique
on public.beautydna_products(shopify_product_id)
where shopify_product_id is not null;

create unique index if not exists
  idx_beautydna_products_shopify_variant_id_unique
on public.beautydna_products(shopify_variant_id)
where shopify_variant_id is not null;

drop index if exists public.idx_beautydna_products_shopify_product_id;

-- ---------------------------------------------------------------------
-- Structural linkage constraints.
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_product_gid_check'
      and conrelid = 'public.beautydna_products'::regclass
  ) then
    alter table public.beautydna_products
      add constraint beautydna_products_shopify_product_gid_check
      check (
        shopify_product_id is null
        or shopify_product_id ~ '^gid://shopify/Product/[1-9][0-9]*$'
      )
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_variant_gid_check'
      and conrelid = 'public.beautydna_products'::regclass
  ) then
    alter table public.beautydna_products
      add constraint beautydna_products_shopify_variant_gid_check
      check (
        shopify_variant_id is null
        or shopify_variant_id ~ '^gid://shopify/ProductVariant/[1-9][0-9]*$'
      )
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_variant_requires_product_check'
      and conrelid = 'public.beautydna_products'::regclass
  ) then
    alter table public.beautydna_products
      add constraint beautydna_products_shopify_variant_requires_product_check
      check (
        shopify_variant_id is null
        or shopify_product_id is not null
      )
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_linked_requires_ids_check'
      and conrelid = 'public.beautydna_products'::regclass
  ) then
    alter table public.beautydna_products
      add constraint beautydna_products_shopify_linked_requires_ids_check
      check (
        shopify_status <> 'linked'
        or (
          shopify_product_id is not null
          and shopify_variant_id is not null
        )
      )
      not valid;
  end if;
end
$$;

alter table public.beautydna_products
  validate constraint beautydna_products_shopify_product_gid_check;

alter table public.beautydna_products
  validate constraint beautydna_products_shopify_variant_gid_check;

alter table public.beautydna_products
  validate constraint beautydna_products_shopify_variant_requires_product_check;

alter table public.beautydna_products
  validate constraint beautydna_products_shopify_linked_requires_ids_check;

-- ---------------------------------------------------------------------
-- Table-level canonical linkage-write guard.
--
-- This prevents product import or any other normal application path from
-- directly changing Shopify linkage state. The linkage RPC temporarily
-- authorizes its own atomic update with a transaction-local setting.
-- ---------------------------------------------------------------------

create or replace function public.beautydna_v2_guard_shopify_linkage_write()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_authorized boolean :=
    current_user = 'postgres'
    and coalesce(
      current_setting(
        'beautydna.shopify_linkage_write_authorized',
        true
      ),
      ''
    ) = 'true';
begin
  if tg_op = 'INSERT' then
    if (
      new.shopify_product_id is not null
      or new.shopify_variant_id is not null
      or new.shopify_status <> 'needs_shopify_creation'
    ) and not v_authorized
    then
      raise exception using
        errcode = '42501',
        message = 'shopify_linkage_write_requires_canonical_boundary';
    end if;

    return new;
  end if;

  if (
    old.shopify_product_id is distinct from new.shopify_product_id
    or old.shopify_variant_id is distinct from new.shopify_variant_id
    or old.shopify_status is distinct from new.shopify_status
  ) and not v_authorized
  then
    raise exception using
      errcode = '42501',
      message = 'shopify_linkage_write_requires_canonical_boundary';
  end if;

  return new;
end
$$;

revoke all
on function public.beautydna_v2_guard_shopify_linkage_write()
from public;

revoke all
on function public.beautydna_v2_guard_shopify_linkage_write()
from anon;

revoke all
on function public.beautydna_v2_guard_shopify_linkage_write()
from authenticated;

revoke all
on function public.beautydna_v2_guard_shopify_linkage_write()
from service_role;

drop trigger if exists
  trg_beautydna_products_shopify_linkage_guard_insert
on public.beautydna_products;

create trigger
  trg_beautydna_products_shopify_linkage_guard_insert
before insert
on public.beautydna_products
for each row
execute function public.beautydna_v2_guard_shopify_linkage_write();

drop trigger if exists
  trg_beautydna_products_shopify_linkage_guard_update
on public.beautydna_products;

create trigger
  trg_beautydna_products_shopify_linkage_guard_update
before update of
  shopify_product_id,
  shopify_variant_id,
  shopify_status
on public.beautydna_products
for each row
execute function public.beautydna_v2_guard_shopify_linkage_write();

-- ---------------------------------------------------------------------
-- Atomic returned-ID linkage boundary.
--
-- No Shopify call occurs here. A separately governed future live Shopify
-- activation must call this only after receiving real Shopify identifiers.
--
-- The function does not write Product DNA or recommendation_ready.
-- ---------------------------------------------------------------------

create or replace function public.beautydna_v2_link_shopify_product(
  p_product_id uuid,
  p_shopify_product_id text,
  p_shopify_variant_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_product public.beautydna_products%rowtype;
  v_shopify_product_id text;
  v_shopify_variant_id text;
  v_conflicting_owner_id uuid;
begin
  if p_product_id is null then
    raise exception using
      errcode = '22023',
      message = 'beautydna_product_id_required';
  end if;

  v_shopify_product_id := btrim(coalesce(p_shopify_product_id, ''));
  v_shopify_variant_id := btrim(coalesce(p_shopify_variant_id, ''));

  if v_shopify_product_id !~ '^gid://shopify/Product/[1-9][0-9]*$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_shopify_product_id';
  end if;

  if v_shopify_variant_id !~ '^gid://shopify/ProductVariant/[1-9][0-9]*$' then
    raise exception using
      errcode = '22023',
      message = 'invalid_shopify_variant_id';
  end if;

  select *
  into v_product
  from public.beautydna_products
  where id = p_product_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'beautydna_product_not_found';
  end if;

  if v_product.shopify_product_id = v_shopify_product_id
     and v_product.shopify_variant_id = v_shopify_variant_id
     and v_product.shopify_status = 'linked'
  then
    return jsonb_build_object(
      'ok', true,
      'action', 'noop',
      'product_id', v_product.id,
      'shopify_product_id', v_product.shopify_product_id,
      'shopify_variant_id', v_product.shopify_variant_id,
      'shopify_status', v_product.shopify_status
    );
  end if;

  if v_product.shopify_product_id is not null
     and v_product.shopify_product_id <> v_shopify_product_id
  then
    raise exception using
      errcode = '23505',
      message = 'existing_shopify_product_id_conflict';
  end if;

  if v_product.shopify_variant_id is not null
     and v_product.shopify_variant_id <> v_shopify_variant_id
  then
    raise exception using
      errcode = '23505',
      message = 'existing_shopify_variant_id_conflict';
  end if;

  select p.id
  into v_conflicting_owner_id
  from public.beautydna_products p
  where p.id <> p_product_id
    and (
      p.shopify_product_id = v_shopify_product_id
      or p.shopify_variant_id = v_shopify_variant_id
    )
  limit 1;

  if found then
    raise exception using
      errcode = '23505',
      message = 'shopify_linkage_owned_by_another_beautydna_product',
      detail = v_conflicting_owner_id::text;
  end if;

  perform set_config(
    'beautydna.shopify_linkage_write_authorized',
    'true',
    true
  );

  begin
    update public.beautydna_products
    set
      shopify_product_id = v_shopify_product_id,
      shopify_variant_id = v_shopify_variant_id,
      shopify_status = 'linked'
    where id = p_product_id
    returning *
    into v_product;
  exception
    when unique_violation then
      raise exception using
        errcode = '23505',
        message = 'shopify_linkage_unique_conflict';
  end;

  return jsonb_build_object(
    'ok', true,
    'action', 'apply',
    'product_id', v_product.id,
    'shopify_product_id', v_product.shopify_product_id,
    'shopify_variant_id', v_product.shopify_variant_id,
    'shopify_status', v_product.shopify_status
  );
end
$$;

alter function public.beautydna_v2_link_shopify_product(uuid, text, text)
owner to postgres;

revoke all
on function public.beautydna_v2_link_shopify_product(uuid, text, text)
from public;

revoke all
on function public.beautydna_v2_link_shopify_product(uuid, text, text)
from anon;

revoke all
on function public.beautydna_v2_link_shopify_product(uuid, text, text)
from authenticated;

grant execute
on function public.beautydna_v2_link_shopify_product(uuid, text, text)
to service_role;

notify pgrst, 'reload schema';