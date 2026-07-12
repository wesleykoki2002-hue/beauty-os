begin;

create extension if not exists pgcrypto;

-- ------------------------------------------------------------------
-- Canonical summary record: preserve the existing table and add only
-- missing columns. Existing application columns are not removed.
-- ------------------------------------------------------------------
alter table public.beautydna_ingredient_intelligence
  add column if not exists canonical_inci_name text,
  add column if not exists normalized_ingredient_name text,
  add column if not exists ingredient_slug text,
  add column if not exists preferred_display_name_en text,
  add column if not exists preferred_display_name_pt_br text,
  add column if not exists preferred_display_name_ja text,
  add column if not exists japanese_labeling_name text,
  add column if not exists ingredient_description_short text,
  add column if not exists ingredient_description_long text,
  add column if not exists ingredient_family text,
  add column if not exists ingredient_class text,
  add column if not exists ingredient_subclass text,
  add column if not exists parent_ingredient_id uuid,
  add column if not exists derivative_type text,
  add column if not exists ingredient_origin_type text,
  add column if not exists ingredient_role_type text,
  add column if not exists origin_types text[] default '{}'::text[],
  add column if not exists role_types text[] default '{}'::text[],
  add column if not exists domains text[] default '{}'::text[],
  add column if not exists is_single_substance boolean,
  add column if not exists is_mixture boolean,
  add column if not exists is_botanical boolean,
  add column if not exists is_ferment boolean,
  add column if not exists is_mineral boolean,
  add column if not exists is_polymer boolean,
  add column if not exists is_peptide boolean,
  add column if not exists is_uv_filter boolean,
  add column if not exists is_preservative boolean,
  add column if not exists is_colorant boolean,
  add column if not exists is_fragrance_component boolean,
  add column if not exists is_quasi_drug_active_japan boolean,
  add column if not exists cas_numbers text[] default '{}'::text[],
  add column if not exists ec_einecs_numbers text[] default '{}'::text[],
  add column if not exists pubchem_cid text,
  add column if not exists unii text,
  add column if not exists inci_monograph_id text,
  add column if not exists chemical_formula text,
  add column if not exists molecular_weight numeric,
  add column if not exists botanical_latin_name text,
  add column if not exists plant_part_used text,
  add column if not exists fermentation_organism text,
  add column if not exists primary_function_summary text,
  add column if not exists common_product_types text[],
  add column if not exists research_priority integer,
  add column if not exists coverage_tier text,
  add column if not exists schema_version text default 'beauty-intelligence-ingredient-v1',
  add column if not exists record_status text default 'active',
  add column if not exists review_status text default 'needs_review',
  add column if not exists customer_usable boolean default false,
  add column if not exists current_version integer default 1,
  add column if not exists research_confidence numeric(5,4),
  add column if not exists reviewed_by text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists approved_by text,
  add column if not exists approved_at timestamptz,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create index if not exists idx_bii_normalized_name
  on public.beautydna_ingredient_intelligence (normalized_ingredient_name);
create index if not exists idx_bii_canonical_inci
  on public.beautydna_ingredient_intelligence (lower(canonical_inci_name));
create index if not exists idx_bii_review_status
  on public.beautydna_ingredient_intelligence (review_status, customer_usable);
create index if not exists idx_bii_priority
  on public.beautydna_ingredient_intelligence (research_priority);

-- ------------------------------------------------------------------
-- Existing aliases table: add normalized columns without deleting
-- existing project columns.
-- ------------------------------------------------------------------
alter table public.beautydna_ingredient_aliases
  add column if not exists ingredient_id uuid,
  add column if not exists alias_name text,
  add column if not exists normalized_alias_name text,
  add column if not exists language_code text,
  add column if not exists alias_type text,
  add column if not exists source_reference text,
  add column if not exists is_official boolean default false,
  add column if not exists is_ambiguous boolean default false,
  add column if not exists refers_to_scope text default 'exact_substance',
  add column if not exists review_status text default 'needs_review',
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create index if not exists idx_bia_ingredient_id
  on public.beautydna_ingredient_aliases (ingredient_id);
create index if not exists idx_bia_normalized_alias
  on public.beautydna_ingredient_aliases (normalized_alias_name);

-- ------------------------------------------------------------------
-- Controlled vocabularies
-- ------------------------------------------------------------------
create table if not exists public.beautydna_taxonomy_terms (
  id uuid primary key default gen_random_uuid(),
  taxonomy_key text not null,
  term_code text not null,
  label_en text not null,
  label_pt_br text,
  label_ja text,
  description text,
  sort_order integer default 0,
  is_active boolean not null default true,
  version_no integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (taxonomy_key, term_code, version_no)
);

create table if not exists public.beautydna_rule_versions (
  id uuid primary key default gen_random_uuid(),
  rule_domain text not null,
  version_key text not null,
  version_no integer not null,
  status text not null default 'draft',
  configuration jsonb not null default '{}'::jsonb,
  effective_from timestamptz,
  effective_to timestamptz,
  approved_by text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (rule_domain, version_key, version_no)
);

-- ------------------------------------------------------------------
-- Raw payload and version history
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_research_payloads (
  id uuid primary key default gen_random_uuid(),
  schema_version text not null,
  batch_key text,
  canonical_inci_name text not null,
  normalized_ingredient_name text not null,
  payload jsonb not null,
  payload_sha256 text not null,
  validation_status text not null default 'staged',
  validation_errors jsonb not null default '[]'::jsonb,
  review_status text not null default 'needs_review',
  requires_specialist_review boolean not null default false,
  research_confidence numeric(5,4),
  source_count integer not null default 0,
  submitted_by text,
  reviewed_by text,
  reviewed_at timestamptz,
  approved_by text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(payload_sha256)
);

create index if not exists idx_birp_normalized
  on public.beautydna_ingredient_research_payloads(normalized_ingredient_name);
create index if not exists idx_birp_review
  on public.beautydna_ingredient_research_payloads(review_status, validation_status);

create table if not exists public.beautydna_ingredient_versions (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  version_no integer not null,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  snapshot jsonb not null,
  status text not null default 'needs_review',
  valid_from timestamptz not null default now(),
  valid_to timestamptz,
  approved_by text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(ingredient_id, version_no)
);

-- ------------------------------------------------------------------
-- Evidence
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_evidence (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid references public.beautydna_ingredient_intelligence(id) on delete cascade,
  source_key text not null,
  source_type text not null,
  title text not null,
  authority_or_authors text,
  publication text,
  publication_date date,
  jurisdiction text,
  url text,
  doi text,
  pmid text,
  document_identifier text,
  retrieved_at timestamptz,
  study_type text,
  study_design text,
  human_or_nonhuman text,
  sample_size integer,
  population text,
  skin_or_hair_condition text,
  ingredient_form text,
  concentration_text text,
  vehicle text,
  product_format text,
  application_area text[],
  frequency_text text,
  duration_text text,
  comparator text,
  measured_outcomes text[],
  result_summary text,
  statistical_relevance text,
  limitations text[] default '{}'::text[],
  conflicts_of_interest text,
  funding_source text,
  directness text,
  applicability text,
  quality_score numeric(5,4),
  evidence_level text,
  review_status text not null default 'needs_review',
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(ingredient_id, source_key, source_payload_id)
);

create table if not exists public.beautydna_ingredient_evidence_links (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  evidence_id uuid not null references public.beautydna_ingredient_evidence(id) on delete cascade,
  relationship_type text not null default 'supports',
  created_at timestamptz not null default now(),
  unique(entity_type, entity_id, evidence_id, relationship_type)
);

-- ------------------------------------------------------------------
-- Functions and claims
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_functions (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  function_code text not null,
  function_type text not null,
  primary_or_secondary text,
  description text,
  evidence_level text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_bif_ingredient
  on public.beautydna_ingredient_functions(ingredient_id, is_current);

create table if not exists public.beautydna_ingredient_claims (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  domain text not null,
  target_concern_code text,
  benefit_name text not null,
  benefit_category text,
  mechanism_summary text,
  mechanism_detailed text,
  expected_visible_outcome text,
  expected_functional_outcome text,
  onset_time_min numeric,
  onset_time_max numeric,
  onset_time_unit text,
  maintenance_required boolean,
  benefit_strength text,
  population_studied text,
  application_area text[],
  product_format text[],
  concentration_context text,
  frequency_context text,
  formulation_context text,
  evidence_level text,
  confidence_score numeric(5,4),
  evidence_consistency text,
  limitations text[] default '{}'::text[],
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_bic_ingredient
  on public.beautydna_ingredient_claims(ingredient_id, is_current);
create index if not exists idx_bic_concern
  on public.beautydna_ingredient_claims(target_concern_code);

-- ------------------------------------------------------------------
-- Formulation and concentration
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_formulation_properties (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  physical_form text,
  ionic_character text,
  water_solubility text,
  oil_solubility text,
  alcohol_solubility text,
  dispersibility text,
  log_p_or_log_kow numeric,
  pka_text text,
  molecular_weight numeric,
  charge_at_skin_ph text,
  optimal_ph_min numeric,
  optimal_ph_max numeric,
  acceptable_ph_min numeric,
  acceptable_ph_max numeric,
  ph_dependency_notes text,
  heat_stability text,
  light_stability text,
  oxygen_stability text,
  water_stability text,
  hydrolysis_risk text,
  oxidation_risk text,
  metal_ion_sensitivity text,
  electrolyte_sensitivity text,
  freeze_thaw_sensitivity text,
  recommended_storage_conditions text,
  packaging_sensitivity text,
  airless_packaging_preferred boolean,
  opaque_packaging_preferred boolean,
  delivery_system_relevance text,
  encapsulation_relevance text,
  nanoform_possible boolean,
  particle_size_relevance text,
  penetration_context text,
  formulation_notes text[],
  manufacturing_notes jsonb not null default '{}'::jsonb,
  evidence_level text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beautydna_ingredient_concentration_rules (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  concentration_rule_type text not null,
  minimum_concentration numeric,
  maximum_concentration numeric,
  concentration_unit text default 'percent',
  typical_use_min numeric,
  typical_use_max numeric,
  evidence_effective_min numeric,
  evidence_effective_max numeric,
  regulatory_max numeric,
  product_category text,
  application_area text,
  leave_on_or_rinse_off text,
  delivery_system text,
  ph_min numeric,
  ph_max numeric,
  frequency text,
  jurisdiction text,
  user_population text,
  benefit_claim_id uuid references public.beautydna_ingredient_claims(id) on delete set null,
  safety_context text,
  evidence_level text,
  confidence_score numeric(5,4),
  effective_from date,
  effective_to date,
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- Safety, profile fit, environment and product role
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_safety_profiles (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  endpoint text not null,
  hazard_status text,
  exposure_route text,
  relevant_concentration text,
  product_format text,
  population text,
  evidence_level text,
  conflicting_evidence text,
  regulatory_conclusion text,
  practical_recommendation text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beautydna_ingredient_profile_fit (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  domain text not null,
  profile_dimension text not null,
  profile_value text not null,
  fit_classification text not null,
  fit_score numeric(6,3),
  benefit_relevance text,
  tolerability_risk text,
  benefit_reason text,
  risk_reason text,
  conditions text[] default '{}'::text[],
  exceptions text[] default '{}'::text[],
  application_guidance text,
  evidence_level text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beautydna_ingredient_environment_fit (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  environment_factor text not null,
  environment_band text not null,
  fit_effect text,
  fit_score numeric(6,3),
  benefit_reason text,
  risk_reason text,
  recommended_product_format text[],
  frequency_adjustment text,
  layering_adjustment text,
  recommended_adjustments text[] default '{}'::text[],
  exceptions text[] default '{}'::text[],
  evidence_level text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.beautydna_ingredient_product_role_fit (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  product_role text not null,
  fit_classification text not null,
  expected_function text,
  contact_time_relevance text,
  leave_on_or_rinse_off text,
  typical_concentration_context text,
  user_profile_relevance text,
  evidence_level text,
  confidence_score numeric(5,4),
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- Regulatory and localization
-- ------------------------------------------------------------------
create table if not exists public.beautydna_ingredient_regulatory_status (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  jurisdiction text not null,
  regulatory_category text,
  status text,
  legal_reference text,
  annex_or_list text,
  permitted_product_types text[],
  prohibited_product_types text[],
  maximum_concentration numeric,
  concentration_basis text,
  leave_on_restriction text,
  rinse_off_restriction text,
  application_area_restriction text,
  age_restriction text,
  required_warning text[],
  labeling_requirement text[],
  purity_requirement text,
  impurity_limit text,
  quasi_drug_status text,
  otc_drug_status text,
  nanoform_requirement text,
  effective_from date,
  effective_to date,
  last_verified_at timestamptz,
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_birs_ingredient_jurisdiction
  on public.beautydna_ingredient_regulatory_status(ingredient_id, jurisdiction, is_current);

create table if not exists public.beautydna_ingredient_localizations (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  language_code text not null,
  one_line_definition text,
  short_customer_explanation text,
  detailed_customer_explanation text,
  main_benefits text[],
  who_may_benefit text,
  who_should_be_cautious text,
  normal_use text,
  performance_factors text,
  common_misconceptions text[],
  interaction_summary text,
  weather_relevance text,
  skin_relevance text,
  scalp_relevance text,
  hair_relevance text,
  evidence_summary text,
  uncertainty_statement text,
  review_status text not null default 'needs_review',
  version_no integer not null default 1,
  is_current boolean not null default true,
  source_payload_id uuid references public.beautydna_ingredient_research_payloads(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------------
-- Expand the existing compatibility-rules table into a contextual
-- interaction table without deleting existing columns.
-- ------------------------------------------------------------------
alter table public.beautydna_ingredient_compatibility_rules
  add column if not exists ingredient_a_id uuid,
  add column if not exists ingredient_b_id uuid,
  add column if not exists interaction_type text,
  add column if not exists directionality text default 'symmetric',
  add column if not exists mechanism text,
  add column if not exists affected_benefit text,
  add column if not exists affected_safety_endpoint text,
  add column if not exists same_formula_status text,
  add column if not exists same_routine_status text,
  add column if not exists leave_on_status text,
  add column if not exists rinse_off_status text,
  add column if not exists am_status text,
  add column if not exists pm_status text,
  add column if not exists concentration_a_min numeric,
  add column if not exists concentration_a_max numeric,
  add column if not exists concentration_b_min numeric,
  add column if not exists concentration_b_max numeric,
  add column if not exists ph_context text,
  add column if not exists delivery_system_context text,
  add column if not exists application_area text,
  add column if not exists user_risk_modifiers text[] default '{}'::text[],
  add column if not exists environment_modifiers text[] default '{}'::text[],
  add column if not exists severity text,
  add column if not exists recommendation_action text,
  add column if not exists spacing_recommendation text,
  add column if not exists frequency_recommendation text,
  add column if not exists exceptions text[] default '{}'::text[],
  add column if not exists customer_explanation_short text,
  add column if not exists professional_explanation text,
  add column if not exists evidence_level text,
  add column if not exists confidence_score numeric(5,4),
  add column if not exists review_status text default 'needs_review',
  add column if not exists reviewed_by text,
  add column if not exists reviewed_at timestamptz,
  add column if not exists version_no integer default 1,
  add column if not exists is_current boolean default true,
  add column if not exists source_payload_id uuid,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create index if not exists idx_bicr_pair
  on public.beautydna_ingredient_compatibility_rules(ingredient_a_id, ingredient_b_id);
create index if not exists idx_bicr_current_review
  on public.beautydna_ingredient_compatibility_rules(is_current, review_status);

create table if not exists public.beautydna_ingredient_interaction_evidence (
  id uuid primary key default gen_random_uuid(),
  interaction_id uuid not null,
  evidence_id uuid not null references public.beautydna_ingredient_evidence(id) on delete cascade,
  relationship_type text not null default 'supports',
  created_at timestamptz not null default now(),
  unique(interaction_id, evidence_id, relationship_type)
);

-- ------------------------------------------------------------------
-- Generic updated_at trigger
-- ------------------------------------------------------------------
create or replace function public.beautydna_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'beautydna_ingredient_intelligence',
    'beautydna_ingredient_aliases',
    'beautydna_taxonomy_terms',
    'beautydna_ingredient_evidence',
    'beautydna_ingredient_functions',
    'beautydna_ingredient_claims',
    'beautydna_ingredient_formulation_properties',
    'beautydna_ingredient_concentration_rules',
    'beautydna_ingredient_safety_profiles',
    'beautydna_ingredient_profile_fit',
    'beautydna_ingredient_environment_fit',
    'beautydna_ingredient_product_role_fit',
    'beautydna_ingredient_regulatory_status',
    'beautydna_ingredient_localizations',
    'beautydna_ingredient_compatibility_rules'
  ]
  loop
    execute format('drop trigger if exists trg_%I_updated_at on public.%I', t, t);
    execute format(
      'create trigger trg_%I_updated_at before update on public.%I
       for each row execute function public.beautydna_set_updated_at()',
      t, t
    );
  end loop;
end $$;

commit;
