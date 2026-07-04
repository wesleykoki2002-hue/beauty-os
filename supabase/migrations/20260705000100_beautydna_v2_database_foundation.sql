-- BeautyDNA v2 Database Foundation
-- Source spec: beautydna-v2-database-foundation
-- Purpose: Create the clean BeautyDNA v2 source-of-truth schema.

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- Shared updated_at trigger
-- ------------------------------------------------------------

create or replace function public.beautydna_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ------------------------------------------------------------
-- FaceDNA assessments
-- ------------------------------------------------------------

create table if not exists public.beautydna_assessments (
  id uuid primary key default gen_random_uuid(),
  customer_id text,
  shopify_customer_id text,
  session_id text,
  channel text not null default 'shopify',
  assessment_type text not null default 'face_dna',
  status text not null default 'started',
  locale text,
  country text,
  answers_payload jsonb not null default '{}'::jsonb,
  score_payload jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_assessments_status_check
    check (status in ('started', 'completed', 'abandoned', 'archived'))
);

create index if not exists idx_beautydna_assessments_customer_id
on public.beautydna_assessments(customer_id);

create index if not exists idx_beautydna_assessments_session_id
on public.beautydna_assessments(session_id);

create index if not exists idx_beautydna_assessments_status
on public.beautydna_assessments(status);

drop trigger if exists trg_beautydna_assessments_updated_at on public.beautydna_assessments;
create trigger trg_beautydna_assessments_updated_at
before update on public.beautydna_assessments
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_assessment_answers (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.beautydna_assessments(id) on delete cascade,
  section_key text,
  question_key text not null,
  question_text text,
  answer_value jsonb not null default '{}'::jsonb,
  answer_label text,
  weight numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (assessment_id, question_key)
);

create index if not exists idx_beautydna_assessment_answers_assessment_id
on public.beautydna_assessment_answers(assessment_id);

drop trigger if exists trg_beautydna_assessment_answers_updated_at on public.beautydna_assessment_answers;
create trigger trg_beautydna_assessment_answers_updated_at
before update on public.beautydna_assessment_answers
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- Beauty Passport
-- ------------------------------------------------------------

create table if not exists public.beautydna_passports (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid references public.beautydna_assessments(id) on delete set null,
  customer_id text,
  shopify_customer_id text,
  passport_version text not null default 'v2',
  primary_skin_type text,
  skin_types text[] not null default '{}'::text[],
  concerns text[] not null default '{}'::text[],
  sensitivities text[] not null default '{}'::text[],
  avoid_ingredients text[] not null default '{}'::text[],
  preferred_routine_steps text[] not null default '{}'::text[],
  climate_context jsonb not null default '{}'::jsonb,
  profile_scores jsonb not null default '{}'::jsonb,
  passport_payload jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_passports_status_check
    check (status in ('active', 'superseded', 'archived'))
);

create index if not exists idx_beautydna_passports_customer_id
on public.beautydna_passports(customer_id);

create index if not exists idx_beautydna_passports_assessment_id
on public.beautydna_passports(assessment_id);

drop trigger if exists trg_beautydna_passports_updated_at on public.beautydna_passports;
create trigger trg_beautydna_passports_updated_at
before update on public.beautydna_passports
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- Products and Product DNA
-- ------------------------------------------------------------

create table if not exists public.beautydna_products (
  id uuid primary key default gen_random_uuid(),
  shopify_product_id text,
  shopify_variant_id text,
  handle text,
  product_url text,
  image_url text,
  brand text,
  product_title text not null,
  product_name text,
  category text,
  product_role text not null,
  routine_step text,
  price numeric,
  price_cents integer,
  currency text not null default 'BRL',
  is_jbeauty boolean not null default true,
  shopify_status text not null default 'needs_shopify_creation',
  approval_status text not null default 'needs_review',
  source_type text,
  source_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_products_product_role_check
    check (product_role in (
      'gentle_cleanser',
      'hydrating_lotion',
      'barrier_serum',
      'moisturizer',
      'sunscreen',
      'treatment',
      'mask',
      'eye_care',
      'other'
    )),

  constraint beautydna_products_approval_status_check
    check (approval_status in ('draft', 'needs_review', 'approved', 'rejected', 'archived'))
);

create unique index if not exists idx_beautydna_products_handle_unique
on public.beautydna_products(handle)
where handle is not null;

create index if not exists idx_beautydna_products_role_status
on public.beautydna_products(product_role, approval_status);

create index if not exists idx_beautydna_products_shopify_product_id
on public.beautydna_products(shopify_product_id);

drop trigger if exists trg_beautydna_products_updated_at on public.beautydna_products;
create trigger trg_beautydna_products_updated_at
before update on public.beautydna_products
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_product_dna (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.beautydna_products(id) on delete cascade,
  skin_type_fit text[] not null default '{}'::text[],
  main_concerns_it_helps text[] not null default '{}'::text[],
  things_to_avoid text[] not null default '{}'::text[],
  key_ingredients text[] not null default '{}'::text[],
  ingredient_flags text[] not null default '{}'::text[],
  recommended_routine_step text,
  usage_timing text[] not null default '{}'::text[],
  sensitivity_risk text not null default 'unknown',
  comedogenic_risk text not null default 'unknown',
  fragrance_status text not null default 'unknown',
  alcohol_status text not null default 'unknown',
  pregnancy_caution text not null default 'unknown',
  beautydna_match_notes text,
  source_summary text,
  research_confidence text not null default 'medium',
  approval_status text not null default 'needs_review',
  dna_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (product_id),

  constraint beautydna_product_dna_approval_status_check
    check (approval_status in ('draft', 'needs_review', 'approved', 'rejected', 'archived'))
);

create index if not exists idx_beautydna_product_dna_product_id
on public.beautydna_product_dna(product_id);

create index if not exists idx_beautydna_product_dna_approval_status
on public.beautydna_product_dna(approval_status);

drop trigger if exists trg_beautydna_product_dna_updated_at on public.beautydna_product_dna;
create trigger trg_beautydna_product_dna_updated_at
before update on public.beautydna_product_dna
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- Ingredient Intelligence
-- ------------------------------------------------------------

create table if not exists public.beautydna_ingredient_intelligence (
  id uuid primary key default gen_random_uuid(),
  ingredient_name text not null,
  normalized_name text not null,
  ingredient_category text,
  benefits text[] not null default '{}'::text[],
  concerns_helped text[] not null default '{}'::text[],
  skin_type_fit text[] not null default '{}'::text[],
  avoid_for text[] not null default '{}'::text[],
  sensitivity_risk text not null default 'unknown',
  comedogenic_risk text not null default 'unknown',
  pregnancy_caution text not null default 'unknown',
  fragrance_related boolean not null default false,
  alcohol_related boolean not null default false,
  short_explanation text,
  long_explanation text,
  evidence_level text not null default 'unknown',
  source_notes text,
  review_status text not null default 'needs_review',
  reviewed_by text,
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (normalized_name),

  constraint beautydna_ingredient_intelligence_review_status_check
    check (review_status in ('draft', 'needs_review', 'approved', 'rejected', 'deprecated'))
);

create index if not exists idx_beautydna_ingredient_intelligence_review_status
on public.beautydna_ingredient_intelligence(review_status);

create index if not exists idx_beautydna_ingredient_intelligence_category
on public.beautydna_ingredient_intelligence(ingredient_category);

drop trigger if exists trg_beautydna_ingredient_intelligence_updated_at on public.beautydna_ingredient_intelligence;
create trigger trg_beautydna_ingredient_intelligence_updated_at
before update on public.beautydna_ingredient_intelligence
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_ingredient_aliases (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.beautydna_ingredient_intelligence(id) on delete cascade,
  alias_name text not null,
  normalized_alias_name text not null,
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (normalized_alias_name)
);

create index if not exists idx_beautydna_ingredient_aliases_ingredient_id
on public.beautydna_ingredient_aliases(ingredient_id);

drop trigger if exists trg_beautydna_ingredient_aliases_updated_at on public.beautydna_ingredient_aliases;
create trigger trg_beautydna_ingredient_aliases_updated_at
before update on public.beautydna_ingredient_aliases
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_ingredient_compatibility_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique,
  ingredient_a_id uuid references public.beautydna_ingredient_intelligence(id) on delete cascade,
  ingredient_b_id uuid references public.beautydna_ingredient_intelligence(id) on delete cascade,
  rule_type text not null,
  severity text not null default 'info',
  message text not null,
  recommendation text,
  skin_type_context text[] not null default '{}'::text[],
  concern_context text[] not null default '{}'::text[],
  review_status text not null default 'needs_review',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_ingredient_compatibility_rules_status_check
    check (review_status in ('draft', 'needs_review', 'approved', 'rejected', 'deprecated'))
);

create index if not exists idx_beautydna_ingredient_compatibility_rules_status
on public.beautydna_ingredient_compatibility_rules(review_status);

drop trigger if exists trg_beautydna_ingredient_compatibility_rules_updated_at on public.beautydna_ingredient_compatibility_rules;
create trigger trg_beautydna_ingredient_compatibility_rules_updated_at
before update on public.beautydna_ingredient_compatibility_rules
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_product_ingredients (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.beautydna_products(id) on delete cascade,
  ingredient_id uuid references public.beautydna_ingredient_intelligence(id) on delete set null,
  ingredient_name text not null,
  normalized_ingredient_name text not null,
  source_field text,
  position integer,
  match_status text not null default 'unmatched',
  review_status text not null default 'needs_review',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (product_id, normalized_ingredient_name),

  constraint beautydna_product_ingredients_match_status_check
    check (match_status in ('approved_match', 'alias_match', 'unmatched', 'rejected_match'))
);

create index if not exists idx_beautydna_product_ingredients_product_id
on public.beautydna_product_ingredients(product_id);

create index if not exists idx_beautydna_product_ingredients_ingredient_id
on public.beautydna_product_ingredients(ingredient_id);

create index if not exists idx_beautydna_product_ingredients_match_status
on public.beautydna_product_ingredients(match_status);

drop trigger if exists trg_beautydna_product_ingredients_updated_at on public.beautydna_product_ingredients;
create trigger trg_beautydna_product_ingredients_updated_at
before update on public.beautydna_product_ingredients
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_ingredient_review_queue (
  id uuid primary key default gen_random_uuid(),
  ingredient_name text not null,
  normalized_ingredient_name text not null,
  reason text not null default 'missing_ingredient',
  priority text not null default 'medium',
  status text not null default 'open',
  source_type text,
  source_key text,
  product_id uuid references public.beautydna_products(id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  resolved_ingredient_id uuid references public.beautydna_ingredient_intelligence(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (normalized_ingredient_name, source_type, source_key),

  constraint beautydna_ingredient_review_queue_status_check
    check (status in ('open', 'in_review', 'resolved', 'rejected', 'archived'))
);

create index if not exists idx_beautydna_ingredient_review_queue_status
on public.beautydna_ingredient_review_queue(status);

drop trigger if exists trg_beautydna_ingredient_review_queue_updated_at on public.beautydna_ingredient_review_queue;
create trigger trg_beautydna_ingredient_review_queue_updated_at
before update on public.beautydna_ingredient_review_queue
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- Recommendations
-- ------------------------------------------------------------

create table if not exists public.beautydna_recommendations (
  id uuid primary key default gen_random_uuid(),
  passport_id uuid references public.beautydna_passports(id) on delete set null,
  assessment_id uuid references public.beautydna_assessments(id) on delete set null,
  customer_id text,
  recommendation_version text not null default 'v2',
  tier text not null default 'recommended',
  status text not null default 'generated',
  recommendation_summary text,
  input_profile jsonb not null default '{}'::jsonb,
  scoring_payload jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_recommendations_status_check
    check (status in ('generated', 'shown', 'converted', 'archived'))
);

create index if not exists idx_beautydna_recommendations_passport_id
on public.beautydna_recommendations(passport_id);

create index if not exists idx_beautydna_recommendations_customer_id
on public.beautydna_recommendations(customer_id);

drop trigger if exists trg_beautydna_recommendations_updated_at on public.beautydna_recommendations;
create trigger trg_beautydna_recommendations_updated_at
before update on public.beautydna_recommendations
for each row execute function public.beautydna_set_updated_at();

create table if not exists public.beautydna_recommended_products (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.beautydna_recommendations(id) on delete cascade,
  product_id uuid not null references public.beautydna_products(id) on delete restrict,
  routine_step text not null,
  product_role text not null,
  position integer not null,
  match_score numeric not null default 0,
  customer_safe_status text not null default 'needs_review',
  recommendation_summary text,
  why_it_matches text[] not null default '{}'::text[],
  ingredient_highlights jsonb not null default '[]'::jsonb,
  caution_flags jsonb not null default '[]'::jsonb,
  explanation_payload jsonb not null default '{}'::jsonb,
  add_to_cart_payload jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (recommendation_id, product_role),
  unique (recommendation_id, position),

  constraint beautydna_recommended_products_customer_safe_status_check
    check (customer_safe_status in ('ready', 'needs_review', 'blocked'))
);

create index if not exists idx_beautydna_recommended_products_recommendation_id
on public.beautydna_recommended_products(recommendation_id);

create index if not exists idx_beautydna_recommended_products_product_id
on public.beautydna_recommended_products(product_id);

drop trigger if exists trg_beautydna_recommended_products_updated_at on public.beautydna_recommended_products;
create trigger trg_beautydna_recommended_products_updated_at
before update on public.beautydna_recommended_products
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- General BeautyDNA review queue
-- ------------------------------------------------------------

create table if not exists public.beautydna_review_queue (
  id uuid primary key default gen_random_uuid(),
  review_type text not null,
  target_type text not null,
  target_id uuid,
  title text not null,
  description text,
  priority text not null default 'medium',
  status text not null default 'open',
  assigned_to text,
  source_type text,
  source_key text,
  metadata jsonb not null default '{}'::jsonb,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint beautydna_review_queue_status_check
    check (status in ('open', 'in_review', 'resolved', 'rejected', 'archived'))
);

create index if not exists idx_beautydna_review_queue_status
on public.beautydna_review_queue(status);

create index if not exists idx_beautydna_review_queue_target
on public.beautydna_review_queue(target_type, target_id);

drop trigger if exists trg_beautydna_review_queue_updated_at on public.beautydna_review_queue;
create trigger trg_beautydna_review_queue_updated_at
before update on public.beautydna_review_queue
for each row execute function public.beautydna_set_updated_at();

-- ------------------------------------------------------------
-- Starter approved ingredients
-- ------------------------------------------------------------

insert into public.beautydna_ingredient_intelligence (
  ingredient_name,
  normalized_name,
  ingredient_category,
  benefits,
  concerns_helped,
  skin_type_fit,
  sensitivity_risk,
  comedogenic_risk,
  pregnancy_caution,
  short_explanation,
  long_explanation,
  evidence_level,
  source_notes,
  review_status,
  reviewed_at
)
values
(
  'Hyaluronic Acid',
  'hyaluronic acid',
  'humectant',
  array['hydration support', 'water-binding support'],
  array['dryness', 'dehydration'],
  array['dry', 'normal', 'combination', 'oily', 'sensitive'],
  'low',
  'low',
  'generally_ok',
  'Helps attract and hold water in the skin surface.',
  'Hyaluronic Acid is a humectant commonly used to support hydration and improve the feel of dehydrated skin.',
  'medium',
  'Starter approved ingredient for BeautyDNA v2 foundation.',
  'approved',
  now()
),
(
  'Ceramide NP',
  'ceramide np',
  'barrier lipid',
  array['barrier support', 'moisture retention support'],
  array['barrier repair', 'dryness', 'sensitivity'],
  array['dry', 'sensitive', 'normal', 'combination'],
  'low',
  'low',
  'generally_ok',
  'Supports the skin barrier and moisture retention.',
  'Ceramide NP is a skin-identical lipid used to support barrier function and reduce dryness-related discomfort.',
  'medium',
  'Starter approved ingredient for BeautyDNA v2 foundation.',
  'approved',
  now()
),
(
  'Niacinamide',
  'niacinamide',
  'vitamin',
  array['barrier support', 'tone support', 'oil balance support'],
  array['redness', 'barrier repair', 'uneven tone', 'oiliness'],
  array['normal', 'combination', 'oily', 'dry'],
  'medium',
  'low',
  'generally_ok',
  'Supports barrier function, tone, and oil balance.',
  'Niacinamide is a form of vitamin B3 commonly used for barrier support, redness appearance, uneven tone, and oil balance.',
  'medium',
  'Starter approved ingredient for BeautyDNA v2 foundation.',
  'approved',
  now()
)
on conflict (normalized_name)
do update set
  ingredient_name = excluded.ingredient_name,
  ingredient_category = excluded.ingredient_category,
  benefits = excluded.benefits,
  concerns_helped = excluded.concerns_helped,
  skin_type_fit = excluded.skin_type_fit,
  sensitivity_risk = excluded.sensitivity_risk,
  comedogenic_risk = excluded.comedogenic_risk,
  pregnancy_caution = excluded.pregnancy_caution,
  short_explanation = excluded.short_explanation,
  long_explanation = excluded.long_explanation,
  evidence_level = excluded.evidence_level,
  source_notes = excluded.source_notes,
  review_status = excluded.review_status,
  reviewed_at = excluded.reviewed_at,
  updated_at = now();

insert into public.beautydna_ingredient_aliases (
  ingredient_id,
  alias_name,
  normalized_alias_name,
  source
)
select id, 'Sodium Hyaluronate', 'sodium hyaluronate', 'starter_seed'
from public.beautydna_ingredient_intelligence
where normalized_name = 'hyaluronic acid'
on conflict (normalized_alias_name) do nothing;

insert into public.beautydna_ingredient_aliases (
  ingredient_id,
  alias_name,
  normalized_alias_name,
  source
)
select id, 'Ceramide 3', 'ceramide 3', 'starter_seed'
from public.beautydna_ingredient_intelligence
where normalized_name = 'ceramide np'
on conflict (normalized_alias_name) do nothing;

insert into public.beautydna_ingredient_aliases (
  ingredient_id,
  alias_name,
  normalized_alias_name,
  source
)
select id, 'Vitamin B3', 'vitamin b3', 'starter_seed'
from public.beautydna_ingredient_intelligence
where normalized_name = 'niacinamide'
on conflict (normalized_alias_name) do nothing;

-- ------------------------------------------------------------
-- Readiness view
-- ------------------------------------------------------------

create or replace view public.beautydna_v2_product_readiness as
select
  p.id as product_id,
  p.product_title,
  p.product_role,
  p.shopify_product_id,
  p.shopify_variant_id,
  p.approval_status as product_approval_status,
  d.approval_status as dna_approval_status,
  count(pi.id) as ingredient_count,
  count(pi.id) filter (where pi.match_status in ('approved_match', 'alias_match')) as matched_ingredient_count,
  count(pi.id) filter (where pi.match_status = 'unmatched') as unmatched_ingredient_count,
  case
    when p.approval_status = 'approved'
      and d.approval_status = 'approved'
      and p.shopify_variant_id is not null
    then true
    else false
  end as recommendation_ready
from public.beautydna_products p
left join public.beautydna_product_dna d
  on d.product_id = p.id
left join public.beautydna_product_ingredients pi
  on pi.product_id = p.id
group by
  p.id,
  p.product_title,
  p.product_role,
  p.shopify_product_id,
  p.shopify_variant_id,
  p.approval_status,
  d.approval_status;

notify pgrst, 'reload schema';
