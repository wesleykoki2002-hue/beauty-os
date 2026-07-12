begin;

create or replace function public.beautydna_stage_ingredient_payload(
  p_payload jsonb,
  p_batch_key text default null,
  p_submitted_by text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_schema_version text;
  v_canonical text;
  v_normalized text;
  v_review_status text;
  v_requires_specialist boolean;
  v_confidence numeric;
  v_source_count integer;
  v_hash text;
  v_errors jsonb := '[]'::jsonb;
begin
  if p_payload is null then
    raise exception 'Payload cannot be null';
  end if;

  v_schema_version := p_payload ->> 'schema_version';
  v_canonical := p_payload #>> '{ingredient,canonical_inci_name}';
  v_normalized := p_payload #>> '{ingredient,normalized_ingredient_name}';
  v_review_status := coalesce(p_payload #>> '{quality_control,review_status}', 'needs_review');
  v_requires_specialist := coalesce(
    (p_payload #>> '{quality_control,requires_specialist_review}')::boolean,
    false
  );
  v_confidence := nullif(p_payload #>> '{quality_control,research_confidence}', '')::numeric;
  v_source_count := jsonb_array_length(coalesce(p_payload -> 'sources', '[]'::jsonb));
  v_hash := encode(digest(convert_to(p_payload::text, 'UTF8'), 'sha256'), 'hex');

  if v_schema_version is distinct from 'beauty-intelligence-ingredient-v1' then
    v_errors := v_errors || jsonb_build_array('Unsupported or missing schema_version');
  end if;
  if nullif(trim(v_canonical), '') is null then
    v_errors := v_errors || jsonb_build_array('Missing ingredient.canonical_inci_name');
  end if;
  if nullif(trim(v_normalized), '') is null then
    v_errors := v_errors || jsonb_build_array('Missing ingredient.normalized_ingredient_name');
  end if;
  if v_review_status = 'approved' and v_source_count = 0 then
    v_errors := v_errors || jsonb_build_array('Approved payload cannot have zero sources');
  end if;
  if v_review_status not in ('needs_review','in_review','approved','rejected','superseded') then
    v_errors := v_errors || jsonb_build_array('Invalid quality_control.review_status');
  end if;

  insert into public.beautydna_ingredient_research_payloads (
    schema_version,
    batch_key,
    canonical_inci_name,
    normalized_ingredient_name,
    payload,
    payload_sha256,
    validation_status,
    validation_errors,
    review_status,
    requires_specialist_review,
    research_confidence,
    source_count,
    submitted_by
  )
  values (
    coalesce(v_schema_version, 'unknown'),
    p_batch_key,
    coalesce(v_canonical, 'unknown'),
    coalesce(v_normalized, 'unknown'),
    p_payload,
    v_hash,
    case when jsonb_array_length(v_errors) = 0 then 'validated' else 'invalid' end,
    v_errors,
    v_review_status,
    v_requires_specialist,
    v_confidence,
    v_source_count,
    p_submitted_by
  )
  on conflict (payload_sha256)
  do update set
    batch_key = coalesce(excluded.batch_key, public.beautydna_ingredient_research_payloads.batch_key),
    submitted_by = coalesce(excluded.submitted_by, public.beautydna_ingredient_research_payloads.submitted_by)
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.beautydna_stage_ingredient_payload(jsonb, text, text) is
'Stages a Beauty Intelligence ingredient JSON payload, calculates a SHA-256 checksum, and performs minimum structural validation. It does not approve or expose the record to customers.';

commit;

-- Example use in SQL Editor:
--
-- select public.beautydna_stage_ingredient_payload(
--   $json$
--   {
--     "schema_version": "beauty-intelligence-ingredient-v1",
--     "ingredient": {
--       "canonical_inci_name": "Example",
--       "normalized_ingredient_name": "example"
--     },
--     "sources": [],
--     "quality_control": {
--       "requires_specialist_review": false,
--       "research_confidence": 0.0,
--       "review_status": "needs_review"
--     }
--   }
--   $json$::jsonb,
--   'batch-example',
--   'research-agent'
-- );
