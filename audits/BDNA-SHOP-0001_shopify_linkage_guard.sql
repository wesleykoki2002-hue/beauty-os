-- BDNA-SHOP-0001 canonical reproducible audit
--
-- Target:
--   Beauty OS / BeautyDNA
--
-- Supabase project ref:
--   hidsyvanaipxxyyhjgmc
--
-- Read-only. This file performs no writes.
--
-- Purpose:
--   Verify BDNA-SHOP-0001's offline launch state, canonical linkage
--   guards, and the product-by-product fail-closed readiness contract.

with launch(product_id) as (
  values
    ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
    ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid),
    ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
    ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
    ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid)
),
launch_state as (
  select
    count(*)::integer as launch_product_count,

    count(*) filter (
      where p.approval_status = 'approved'
    )::integer as approved_product_count,

    count(*) filter (
      where d.approval_status = 'approved'
    )::integer as approved_dna_count,

    count(*) filter (
      where p.shopify_status = 'needs_shopify_creation'
    )::integer as needs_shopify_creation_count,

    count(*) filter (
      where p.shopify_product_id is null
        and p.shopify_variant_id is null
    )::integer as fully_unlinked_count,

    count(*) filter (
      where p.shopify_product_id is not null
         or p.shopify_variant_id is not null
    )::integer as any_shopify_id_count,

    count(r.product_id)::integer as launch_readiness_count,

    count(*) filter (
      where r.recommendation_ready
    )::integer as recommendation_ready_count,

    count(*) filter (
      where r.product_id is not null
        and not r.recommendation_ready
    )::integer as recommendation_not_ready_count,

    count(*) filter (
      where r.recommendation_ready is distinct from (
        p.approval_status = 'approved'
        and d.approval_status = 'approved'
        and p.shopify_variant_id is not null
      )
    )::integer as readiness_linkage_mismatch_count

  from launch l

  join public.beautydna_products p
    on p.id = l.product_id

  left join public.beautydna_product_dna d
    on d.product_id = p.id

  left join public.beautydna_v2_product_readiness r
    on r.product_id = p.id
),
global_linkage_health as (
  select
    (
      select count(*)::integer
      from (
        select shopify_product_id
        from public.beautydna_products
        where shopify_product_id is not null
        group by shopify_product_id
        having count(*) > 1
      ) d
    ) as duplicate_shopify_product_id_count,

    (
      select count(*)::integer
      from (
        select shopify_variant_id
        from public.beautydna_products
        where shopify_variant_id is not null
        group by shopify_variant_id
        having count(*) > 1
      ) d
    ) as duplicate_shopify_variant_id_count,

    count(*) filter (
      where shopify_product_id is not null
        and shopify_product_id !~ '^gid://shopify/Product/[1-9][0-9]*$'
    )::integer as invalid_shopify_product_gid_count,

    count(*) filter (
      where shopify_variant_id is not null
        and shopify_variant_id !~ '^gid://shopify/ProductVariant/[1-9][0-9]*$'
    )::integer as invalid_shopify_variant_gid_count,

    count(*) filter (
      where shopify_variant_id is not null
        and shopify_product_id is null
    )::integer as variant_without_product_count,

    count(*) filter (
      where shopify_status = 'linked'
        and (
          shopify_product_id is null
          or shopify_variant_id is null
        )
    )::integer as linked_status_without_complete_ids_count

  from public.beautydna_products
),
schema_guard as (
  select
    to_regclass(
      'public.idx_beautydna_products_shopify_product_id_unique'
    ) is not null as product_unique_index_present,

    to_regclass(
      'public.idx_beautydna_products_shopify_variant_id_unique'
    ) is not null as variant_unique_index_present,

    exists (
      select 1
      from pg_constraint
      where conname = 'beautydna_products_shopify_product_gid_check'
        and conrelid = 'public.beautydna_products'::regclass
        and convalidated
    ) as product_gid_constraint_validated,

    exists (
      select 1
      from pg_constraint
      where conname = 'beautydna_products_shopify_variant_gid_check'
        and conrelid = 'public.beautydna_products'::regclass
        and convalidated
    ) as variant_gid_constraint_validated,

    exists (
      select 1
      from pg_constraint
      where conname = 'beautydna_products_shopify_variant_requires_product_check'
        and conrelid = 'public.beautydna_products'::regclass
        and convalidated
    ) as variant_requires_product_constraint_validated,

    exists (
      select 1
      from pg_constraint
      where conname = 'beautydna_products_shopify_linked_requires_ids_check'
        and conrelid = 'public.beautydna_products'::regclass
        and convalidated
    ) as linked_requires_ids_constraint_validated,

    to_regprocedure(
      'public.beautydna_v2_guard_shopify_linkage_write()'
    ) is not null as linkage_guard_function_present,

    to_regprocedure(
      'public.beautydna_v2_link_shopify_product(uuid,text,text)'
    ) is not null as linkage_function_present,

    exists (
      select 1
      from pg_proc p
      where p.oid =
        'public.beautydna_v2_link_shopify_product(uuid,text,text)'::regprocedure
        and p.prosecdef
        and pg_get_userbyid(p.proowner) = 'postgres'
    ) as linkage_function_security_definer_postgres_owned,

    exists (
      select 1
      from pg_trigger
      where tgname = 'trg_beautydna_products_shopify_linkage_guard_insert'
        and tgrelid = 'public.beautydna_products'::regclass
        and not tgisinternal
        and tgenabled <> 'D'
    ) as linkage_insert_guard_trigger_present,

    exists (
      select 1
      from pg_trigger
      where tgname = 'trg_beautydna_products_shopify_linkage_guard_update'
        and tgrelid = 'public.beautydna_products'::regclass
        and not tgisinternal
        and tgenabled <> 'D'
    ) as linkage_update_guard_trigger_present
),
privilege_guard as (
  select
    not has_function_privilege(
      'anon',
      'public.beautydna_v2_link_shopify_product(uuid,text,text)',
      'EXECUTE'
    ) as anon_link_execute_denied,

    not has_function_privilege(
      'authenticated',
      'public.beautydna_v2_link_shopify_product(uuid,text,text)',
      'EXECUTE'
    ) as authenticated_link_execute_denied,

    has_function_privilege(
      'service_role',
      'public.beautydna_v2_link_shopify_product(uuid,text,text)',
      'EXECUTE'
    ) as service_role_link_execute_granted,

    not has_function_privilege(
      'anon',
      'public.beautydna_v2_guard_shopify_linkage_write()',
      'EXECUTE'
    ) as anon_guard_execute_denied,

    not has_function_privilege(
      'authenticated',
      'public.beautydna_v2_guard_shopify_linkage_write()',
      'EXECUTE'
    ) as authenticated_guard_execute_denied,

    not has_function_privilege(
      'service_role',
      'public.beautydna_v2_guard_shopify_linkage_write()',
      'EXECUTE'
    ) as service_role_guard_execute_denied
),
result as (
  select
    l.*,
    g.*,
    s.*,
    p.*,

    (
      l.launch_product_count = 5
      and l.approved_product_count = 5
      and l.approved_dna_count = 5
      and l.needs_shopify_creation_count = 5
      and l.fully_unlinked_count = 5
      and l.any_shopify_id_count = 0
      and l.launch_readiness_count = 5
      and l.recommendation_ready_count = 0
      and l.recommendation_not_ready_count = 5
      and l.readiness_linkage_mismatch_count = 0
    ) as offline_launch_state_pass,

    (
      g.duplicate_shopify_product_id_count = 0
      and g.duplicate_shopify_variant_id_count = 0
      and g.invalid_shopify_product_gid_count = 0
      and g.invalid_shopify_variant_gid_count = 0
      and g.variant_without_product_count = 0
      and g.linked_status_without_complete_ids_count = 0

      and s.product_unique_index_present
      and s.variant_unique_index_present
      and s.product_gid_constraint_validated
      and s.variant_gid_constraint_validated
      and s.variant_requires_product_constraint_validated
      and s.linked_requires_ids_constraint_validated
      and s.linkage_guard_function_present
      and s.linkage_function_present
      and s.linkage_function_security_definer_postgres_owned
      and s.linkage_insert_guard_trigger_present
      and s.linkage_update_guard_trigger_present

      and p.anon_link_execute_denied
      and p.authenticated_link_execute_denied
      and p.service_role_link_execute_granted
      and p.anon_guard_execute_denied
      and p.authenticated_guard_execute_denied
      and p.service_role_guard_execute_denied
    ) as linkage_guard_schema_pass

  from launch_state l
  cross join global_linkage_health g
  cross join schema_guard s
  cross join privilege_guard p
)
select
  *,
  (
    offline_launch_state_pass
    and linkage_guard_schema_pass
  ) as bdna_shop_0001_linkage_guard_qa_pass
from result;

-- Governed five-product detail.
with launch(product_id) as (
  values
    ('5677258a-87b5-48b7-acb0-02b855e2f167'::uuid),
    ('48faa3de-bfe6-4e4c-9958-754088754f50'::uuid),
    ('349821be-6f9a-4e4f-bf84-b922986547ca'::uuid),
    ('41f6385a-0d61-4cb3-ac7a-fdaf9c294031'::uuid),
    ('976f45a3-a673-4dc7-b6a7-2e4a24b32e35'::uuid)
)
select
  p.id as product_id,
  p.brand,
  p.product_title,
  p.product_role,
  p.approval_status as product_approval_status,
  d.approval_status as dna_approval_status,
  p.shopify_status,
  p.shopify_product_id,
  p.shopify_variant_id,
  r.recommendation_ready,

  (
    r.recommendation_ready is not distinct from (
      p.approval_status = 'approved'
      and d.approval_status = 'approved'
      and p.shopify_variant_id is not null
    )
  ) as readiness_contract_matches

from launch l

join public.beautydna_products p
  on p.id = l.product_id

left join public.beautydna_product_dna d
  on d.product_id = p.id

left join public.beautydna_v2_product_readiness r
  on r.product_id = p.id

order by p.created_at;