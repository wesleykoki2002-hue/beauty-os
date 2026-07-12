-- Beauty Intelligence validation and coverage checks

-- 1. Core 150 seed coverage
select
  count(*) filter (where research_priority between 1 and 150) as seeded_core_rows,
  count(*) filter (
    where research_priority between 1 and 150
      and canonical_inci_name is not null
      and normalized_ingredient_name is not null
      and japanese_labeling_name is not null
  ) as identity_complete_rows,
  count(*) filter (
    where research_priority between 1 and 150
      and review_status = 'approved'
      and customer_usable = true
  ) as customer_ready_rows
from public.beautydna_ingredient_intelligence;

-- 2. Duplicate canonical/normalized records
select normalized_ingredient_name, count(*) as duplicate_count
from public.beautydna_ingredient_intelligence
where normalized_ingredient_name is not null
group by normalized_ingredient_name
having count(*) > 1
order by duplicate_count desc, normalized_ingredient_name;

select lower(canonical_inci_name) as canonical_key, count(*) as duplicate_count
from public.beautydna_ingredient_intelligence
where canonical_inci_name is not null
group by lower(canonical_inci_name)
having count(*) > 1
order by duplicate_count desc, canonical_key;

-- 3. Alias collisions pointing to multiple ingredients
select
  normalized_alias_name,
  count(distinct ingredient_id) as ingredient_count,
  array_agg(distinct ingredient_id) as ingredient_ids
from public.beautydna_ingredient_aliases
where normalized_alias_name is not null
group by normalized_alias_name
having count(distinct ingredient_id) > 1
order by ingredient_count desc, normalized_alias_name;

-- 4. Research payload status
select
  batch_key,
  validation_status,
  review_status,
  count(*) as payload_count,
  sum(source_count) as total_sources
from public.beautydna_ingredient_research_payloads
group by batch_key, validation_status, review_status
order by batch_key nulls last, validation_status, review_status;

-- 5. Per-ingredient normalized-data completeness
select
  i.research_priority,
  i.canonical_inci_name,
  i.review_status,
  i.customer_usable,
  count(distinct f.id) filter (where f.is_current) as function_records,
  count(distinct c.id) filter (where c.is_current) as claim_records,
  count(distinct s.id) filter (where s.is_current) as safety_records,
  count(distinct r.id) filter (where r.is_current) as regulatory_records,
  count(distinct e.id) as evidence_records,
  count(distinct l.id) filter (where l.is_current) as localization_records
from public.beautydna_ingredient_intelligence i
left join public.beautydna_ingredient_functions f on f.ingredient_id = i.id
left join public.beautydna_ingredient_claims c on c.ingredient_id = i.id
left join public.beautydna_ingredient_safety_profiles s on s.ingredient_id = i.id
left join public.beautydna_ingredient_regulatory_status r on r.ingredient_id = i.id
left join public.beautydna_ingredient_evidence e on e.ingredient_id = i.id
left join public.beautydna_ingredient_localizations l on l.ingredient_id = i.id
where i.research_priority between 1 and 150
group by i.id, i.research_priority, i.canonical_inci_name, i.review_status, i.customer_usable
order by i.research_priority;

-- 6. Invalid customer exposure
select id, canonical_inci_name, review_status, customer_usable
from public.beautydna_ingredient_intelligence
where customer_usable = true
  and review_status <> 'approved';

-- 7. Regulatory jurisdiction coverage
select
  i.canonical_inci_name,
  array_agg(distinct r.jurisdiction) filter (where r.is_current) as jurisdictions_present
from public.beautydna_ingredient_intelligence i
left join public.beautydna_ingredient_regulatory_status r on r.ingredient_id = i.id
where i.research_priority between 1 and 150
group by i.id, i.canonical_inci_name
having count(distinct r.jurisdiction) filter (where r.is_current) < 4
order by i.research_priority;

-- 8. Interaction rules that are not evidence-backed
select
  id,
  ingredient_a_id,
  ingredient_b_id,
  interaction_type,
  severity,
  review_status,
  evidence_level,
  confidence_score
from public.beautydna_ingredient_compatibility_rules
where is_current = true
  and (
    review_status <> 'approved'
    or evidence_level is null
    or confidence_score is null
  )
order by severity nulls last, interaction_type;
