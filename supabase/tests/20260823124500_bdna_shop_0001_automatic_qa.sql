-- BDNA-SHOP-0001 external automatic QA profile
--
-- Target:
--   Beauty OS / BeautyDNA
--   Supabase project ref: hidsyvanaipxxyyhjgmc
--
-- This test is machine-verifiable and fail-closed.
-- It performs no persistent write. The only attempted table mutation is
-- an explicit service_role bypass probe inside a transaction that must
-- be rejected by the linkage guard before the row changes, followed by
-- ROLLBACK.

do $qa$
declare
  v_launch_count integer;
  v_approved_product_count integer;
  v_approved_dna_count integer;
  v_needs_creation_count integer;
  v_fully_unlinked_count integer;
  v_any_shopify_id_count integer;
  v_readiness_count integer;
  v_ready_count integer;
  v_not_ready_count integer;
  v_readiness_mismatch_count integer;
begin
  if to_regclass(
    'public.idx_beautydna_products_shopify_product_id_unique'
  ) is null then
    raise exception 'missing_product_unique_index';
  end if;

  if to_regclass(
    'public.idx_beautydna_products_shopify_variant_id_unique'
  ) is null then
    raise exception 'missing_variant_unique_index';
  end if;

  if to_regclass(
    'public.idx_beautydna_products_shopify_product_id'
  ) is not null then
    raise exception 'legacy_nonunique_product_index_still_present';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_product_gid_check'
      and conrelid = 'public.beautydna_products'::regclass
      and convalidated
  ) then
    raise exception 'product_gid_constraint_not_validated';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'beautydna_products_shopify_variant_gid_check'
      and conrelid = 'public.beautydna_products'::regclass
      and convalidated
  ) then
    raise exception 'variant_gid_constraint_not_validated';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname =
      'beautydna_products_shopify_variant_requires_product_check'
      and conrelid = 'public.beautydna_products'::regclass
      and convalidated
  ) then
    raise exception 'variant_requires_product_constraint_not_validated';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname =
      'beautydna_products_shopify_linked_requires_ids_check'
      and conrelid = 'public.beautydna_products'::regclass
      and convalidated
  ) then
    raise exception 'linked_requires_ids_constraint_not_validated';
  end if;

  if not exists (
    select 1
    from pg_proc p
    where p.oid =
      'public.beautydna_v2_link_shopify_product(uuid,text,text)'::regprocedure
      and p.prosecdef
      and pg_get_userbyid(p.proowner) = 'postgres'
  ) then
    raise exception 'linkage_rpc_security_owner_mismatch';
  end if;

  if has_function_privilege(
    'anon',
    'public.beautydna_v2_link_shopify_product(uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'anon_has_linkage_rpc_execute';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.beautydna_v2_link_shopify_product(uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'authenticated_has_linkage_rpc_execute';
  end if;

  if not has_function_privilege(
    'service_role',
    'public.beautydna_v2_link_shopify_product(uuid,text,text)',
    'EXECUTE'
  ) then
    raise exception 'service_role_missing_linkage_rpc_execute';
  end if;

  if has_function_privilege(
    'service_role',
    'public.beautydna_v2_guard_shopify_linkage_write()',
    'EXECUTE'
  ) then
    raise exception 'service_role_has_trigger_helper_execute';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgname =
      'trg_beautydna_products_shopify_linkage_guard_insert'
      and tgrelid = 'public.beautydna_products'::regclass
      and not tgisinternal
      and tgenabled <> 'D'
  ) then
    raise exception 'missing_insert_linkage_guard_trigger';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgname =
      'trg_beautydna_products_shopify_linkage_guard_update'
      and tgrelid = 'public.beautydna_products'::regclass
      and not tgisinternal
      and tgenabled <> 'D'
  ) then
    raise exception 'missing_update_linkage_guard_trigger';
  end if;

  with launch(product_id) as (
    values
      ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
      ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid),
      ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
      ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
      ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid)
  )
  select
    count(*)::integer,
    count(*) filter (
      where p.approval_status = 'approved'
    )::integer,
    count(*) filter (
      where d.approval_status = 'approved'
    )::integer,
    count(*) filter (
      where p.shopify_status = 'needs_shopify_creation'
    )::integer,
    count(*) filter (
      where p.shopify_product_id is null
        and p.shopify_variant_id is null
    )::integer,
    count(*) filter (
      where p.shopify_product_id is not null
        or p.shopify_variant_id is not null
    )::integer,
    count(r.product_id)::integer,
    count(*) filter (
      where r.recommendation_ready
    )::integer,
    count(*) filter (
      where r.product_id is not null
        and not r.recommendation_ready
    )::integer,
    count(*) filter (
      where r.recommendation_ready is distinct from (
        p.approval_status = 'approved'
        and d.approval_status = 'approved'
        and p.shopify_variant_id is not null
      )
    )::integer
  into
    v_launch_count,
    v_approved_product_count,
    v_approved_dna_count,
    v_needs_creation_count,
    v_fully_unlinked_count,
    v_any_shopify_id_count,
    v_readiness_count,
    v_ready_count,
    v_not_ready_count,
    v_readiness_mismatch_count
  from launch l
  join public.beautydna_products p
    on p.id = l.product_id
  left join public.beautydna_product_dna d
    on d.product_id = p.id
  left join public.beautydna_v2_product_readiness r
    on r.product_id = p.id;

  if v_launch_count <> 5
     or v_approved_product_count <> 5
     or v_approved_dna_count <> 5
     or v_needs_creation_count <> 5
     or v_fully_unlinked_count <> 5
     or v_any_shopify_id_count <> 0
     or v_readiness_count <> 5
     or v_ready_count <> 0
     or v_not_ready_count <> 5
     or v_readiness_mismatch_count <> 0
  then
    raise exception
      'offline_launch_state_failed launch=% approved=% dna=% needs=% unlinked=% any_ids=% readiness=% ready=% not_ready=% mismatch=%',
      v_launch_count,
      v_approved_product_count,
      v_approved_dna_count,
      v_needs_creation_count,
      v_fully_unlinked_count,
      v_any_shopify_id_count,
      v_readiness_count,
      v_ready_count,
      v_not_ready_count,
      v_readiness_mismatch_count;
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_product_id is not null
      and shopify_product_id !~ '^gid://shopify/Product/[1-9][0-9]*$'
  ) then
    raise exception 'invalid_product_gid_exists';
  end if;

  if exists (
    select 1
    from public.beautydna_products
    where shopify_variant_id is not null
      and shopify_variant_id !~ '^gid://shopify/ProductVariant/[1-9][0-9]*$'
  ) then
    raise exception 'invalid_variant_gid_exists';
  end if;

  if exists (
    select shopify_product_id
    from public.beautydna_products
    where shopify_product_id is not null
    group by shopify_product_id
    having count(*) > 1
  ) then
    raise exception 'duplicate_product_gid_exists';
  end if;

  if exists (
    select shopify_variant_id
    from public.beautydna_products
    where shopify_variant_id is not null
    group by shopify_variant_id
    having count(*) > 1
  ) then
    raise exception 'duplicate_variant_gid_exists';
  end if;
end
$qa$;

begin;

set local role service_role;

select set_config(
  'beautydna.shopify_linkage_write_authorized',
  'true',
  true
);

do $qa$
begin
  begin
    update public.beautydna_products
    set shopify_status = 'linked'
    where id =
      '5677258a-87b5-48b7-acb0-02b855e2f167'::uuid;

    raise exception
      'service_role_flag_bypass_unexpectedly_succeeded';
  exception
    when insufficient_privilege then
      if sqlerrm <>
        'shopify_linkage_write_requires_canonical_boundary'
      then
        raise;
      end if;
  end;
end
$qa$;

reset role;

rollback;

with launch(product_id) as (
  values
    ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
    ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid),
    ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
    ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
    ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid)
)
select
  true as bdna_shop_0001_automatic_qa_pass,
  count(*)::integer as launch_product_count,
  count(*) filter (
    where p.shopify_product_id is null
      and p.shopify_variant_id is null
  )::integer as fully_unlinked_count,
  count(*) filter (
    where r.recommendation_ready
  )::integer as recommendation_ready_count,
  0::integer as fabricated_shopify_id_count,
  true as service_role_flag_bypass_blocked
from launch l
join public.beautydna_products p
  on p.id = l.product_id
left join public.beautydna_v2_product_readiness r
  on r.product_id = p.id;