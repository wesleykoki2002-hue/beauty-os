import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VERSION = "beautydna-v2-recommendation-generate-v1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-athena-admin-key, x-beautydna-internal-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_ROUTINE_STEPS = [
  "gentle_cleanser",
  "hydrating_lotion",
  "barrier_serum",
  "moisturizer",
  "sunscreen",
];

const SCORE_WEIGHTS = {
  skin_type_match: 30,
  concern_match: 35,
  routine_step_match: 20,
  sensitivity_penalty: -20,
  comedogenic_penalty: -15,
  avoid_match_penalty: -50,
  approved_status_bonus: 10,
  needs_review_penalty: -8,
  pregnancy_penalty: -25,
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function cleanString(value) {
  if (typeof value !== "string") return "";
  return value.trim();
}

function cleanLower(value) {
  return cleanString(value).toLowerCase();
}

function cleanBoolean(value, fallback = false) {
  if (typeof value === "boolean") return value;
  return fallback;
}

function toArray(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => cleanString(item))
      .filter(Boolean);
  }

  if (typeof value === "string" && value.trim()) {
    return value
      .split(",")
      .map((item) => cleanString(item))
      .filter(Boolean);
  }

  return [];
}

function toLowerArray(value) {
  return toArray(value).map((item) => item.toLowerCase());
}

function uniqueArray(values) {
  return [...new Set((values || []).filter(Boolean))];
}

function parseJsonMaybe(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === "object") return value;
  if (typeof value !== "string") return fallback;

  try {
    return JSON.parse(value);
  } catch (_error) {
    return fallback;
  }
}

function normalizeRisk(value) {
  const cleaned = cleanLower(value);

  if (["low", "medium", "high", "unknown"].includes(cleaned)) {
    return cleaned;
  }

  return "unknown";
}

function riskRank(value) {
  const normalized = normalizeRisk(value);

  if (normalized === "low") return 1;
  if (normalized === "medium") return 2;
  if (normalized === "high") return 3;

  return 0;
}

function overlap(a, b) {
  const aSet = new Set(toLowerArray(a));
  const bSet = new Set(toLowerArray(b));

  return [...aSet].filter((item) => bSet.has(item));
}

function containsAnyText(haystackValues, needleValues) {
  const haystackText = toLowerArray(haystackValues).join(" ");
  const needles = toLowerArray(needleValues);

  if (!haystackText || needles.length === 0) return [];

  return needles.filter((needle) => needle && haystackText.includes(needle));
}

function readOptionNumber(options, key, fallback, min, max) {
  const raw = Number(options?.[key]);

  if (!Number.isFinite(raw)) return fallback;

  return Math.max(min, Math.min(max, Math.floor(raw)));
}

function normalizeProfile(inputProfile) {
  const profile = inputProfile || {};

  const skinType =
    cleanLower(profile.skin_type) ||
    cleanLower(profile.skinType) ||
    "unknown";

  const skinConcerns = uniqueArray([
    ...toLowerArray(profile.skin_concerns),
    ...toLowerArray(profile.concerns),
    ...toLowerArray(profile.main_concerns),
  ]);

  const sensitivityLevel =
    cleanLower(profile.sensitivity_level) ||
    cleanLower(profile.sensitivity) ||
    "unknown";

  return {
    skin_type: skinType,
    skin_concerns: skinConcerns,
    sensitivity_level: sensitivityLevel,
    acne_prone: cleanBoolean(profile.acne_prone, false),
    pregnancy: cleanBoolean(profile.pregnancy, false),
    avoid_ingredients: uniqueArray([
      ...toLowerArray(profile.avoid_ingredients),
      ...toLowerArray(profile.things_to_avoid),
      ...toLowerArray(profile.allergies),
    ]),
    preferred_steps: toLowerArray(profile.preferred_steps),
  };
}

function profileFromPassport(passport) {
  const payload = parseJsonMaybe(passport?.passport_payload, {});
  const faceDna = parseJsonMaybe(passport?.face_dna, {});
  const profile = parseJsonMaybe(passport?.profile, {});

  return normalizeProfile({
    skin_type:
      passport?.skin_type ||
      payload?.skin_type ||
      faceDna?.skin_type ||
      profile?.skin_type,

    skin_concerns:
      passport?.skin_concerns ||
      payload?.skin_concerns ||
      faceDna?.skin_concerns ||
      profile?.skin_concerns ||
      payload?.concerns ||
      faceDna?.concerns,

    sensitivity_level:
      passport?.sensitivity_level ||
      payload?.sensitivity_level ||
      faceDna?.sensitivity_level ||
      profile?.sensitivity_level,

    acne_prone:
      passport?.acne_prone ||
      payload?.acne_prone ||
      faceDna?.acne_prone ||
      profile?.acne_prone,

    pregnancy:
      passport?.pregnancy ||
      payload?.pregnancy ||
      faceDna?.pregnancy ||
      profile?.pregnancy,

    avoid_ingredients:
      passport?.avoid_ingredients ||
      payload?.avoid_ingredients ||
      faceDna?.avoid_ingredients ||
      profile?.avoid_ingredients,

    preferred_steps:
      passport?.preferred_steps ||
      payload?.preferred_steps ||
      faceDna?.preferred_steps ||
      profile?.preferred_steps,
  });
}

function getProductRole(product, dna) {
  return (
    cleanLower(dna?.recommended_routine_step) ||
    cleanLower(product?.product_role) ||
    cleanLower(dna?.product_role) ||
    "unknown"
  );
}

function isProductSafeForProduction(product, dna) {
  const productStatus = cleanLower(product?.shopify_status);
  const dnaStatus = cleanLower(dna?.approval_status);

  if (productStatus === "rejected") return false;
  if (dnaStatus === "rejected") return false;

  return dnaStatus === "approved";
}

function canIncludeProduct(product, dna, includeNeedsReview) {
  if (isProductSafeForProduction(product, dna)) return true;

  if (!includeNeedsReview) return false;

  const productStatus = cleanLower(product?.shopify_status);
  const dnaStatus = cleanLower(dna?.approval_status);

  if (productStatus === "rejected") return false;
  if (dnaStatus === "rejected") return false;

  return true;
}

function scoreCandidate(candidate, profile, requestedSteps, includeNeedsReview) {
  const product = candidate.product;
  const dna = candidate.product_dna;

  const role = getProductRole(product, dna);
  let score = 0;
  const reasons = [];
  const penalties = [];
  const matched = {
    skin_types: [],
    concerns: [],
    avoid_terms: [],
  };

  if (requestedSteps.includes(role)) {
    score += SCORE_WEIGHTS.routine_step_match;
    reasons.push({
      code: "routine_step_match",
      points: SCORE_WEIGHTS.routine_step_match,
      detail: `Product role matches requested step: ${role}.`,
    });
  }

  const skinTypeFit = toLowerArray(dna?.skin_type_fit);
  if (profile.skin_type && skinTypeFit.includes(profile.skin_type)) {
    score += SCORE_WEIGHTS.skin_type_match;
    matched.skin_types.push(profile.skin_type);
    reasons.push({
      code: "skin_type_match",
      points: SCORE_WEIGHTS.skin_type_match,
      detail: `Product DNA fits skin type: ${profile.skin_type}.`,
    });
  }

  const concernMatches = overlap(profile.skin_concerns, dna?.main_concerns_it_helps);
  if (concernMatches.length > 0) {
    const points = SCORE_WEIGHTS.concern_match * concernMatches.length;
    score += points;
    matched.concerns = concernMatches;
    reasons.push({
      code: "concern_match",
      points,
      detail: `Matches concerns: ${concernMatches.join(", ")}.`,
    });
  }

  const avoidTerms = uniqueArray([
    ...containsAnyText(dna?.things_to_avoid, profile.avoid_ingredients),
    ...overlap(profile.avoid_ingredients, dna?.ingredient_flags),
    ...overlap(profile.avoid_ingredients, dna?.key_ingredients),
  ]);

  if (avoidTerms.length > 0) {
    const points = SCORE_WEIGHTS.avoid_match_penalty * avoidTerms.length;
    score += points;
    matched.avoid_terms = avoidTerms;
    penalties.push({
      code: "avoid_match_penalty",
      points,
      detail: `Avoid terms matched: ${avoidTerms.join(", ")}.`,
    });
  }

  const sensitivityRisk = normalizeRisk(dna?.sensitivity_risk);
  if (
    ["sensitive", "high", "very_sensitive"].includes(profile.sensitivity_level) &&
    riskRank(sensitivityRisk) >= 3
  ) {
    score += SCORE_WEIGHTS.sensitivity_penalty;
    penalties.push({
      code: "sensitivity_penalty",
      points: SCORE_WEIGHTS.sensitivity_penalty,
      detail: "High sensitivity risk for sensitive profile.",
    });
  }

  const comedogenicRisk = normalizeRisk(dna?.comedogenic_risk);
  if (profile.acne_prone && riskRank(comedogenicRisk) >= 3) {
    score += SCORE_WEIGHTS.comedogenic_penalty;
    penalties.push({
      code: "comedogenic_penalty",
      points: SCORE_WEIGHTS.comedogenic_penalty,
      detail: "High comedogenic risk for acne-prone profile.",
    });
  }

  const pregnancyCaution = cleanLower(dna?.pregnancy_caution);
  if (
    profile.pregnancy &&
    ["avoid", "caution", "not_recommended", "doctor_only"].includes(pregnancyCaution)
  ) {
    score += SCORE_WEIGHTS.pregnancy_penalty;
    penalties.push({
      code: "pregnancy_penalty",
      points: SCORE_WEIGHTS.pregnancy_penalty,
      detail: "Pregnancy caution detected.",
    });
  }

  const approvalStatus = cleanLower(dna?.approval_status);
  if (approvalStatus === "approved") {
    score += SCORE_WEIGHTS.approved_status_bonus;
    reasons.push({
      code: "approved_status_bonus",
      points: SCORE_WEIGHTS.approved_status_bonus,
      detail: "Product DNA is approved.",
    });
  } else if (includeNeedsReview) {
    score += SCORE_WEIGHTS.needs_review_penalty;
    penalties.push({
      code: "needs_review_penalty",
      points: SCORE_WEIGHTS.needs_review_penalty,
      detail: `Product DNA is ${approvalStatus || "not approved"} and included only because debug/include_needs_review is enabled.`,
    });
  }

  return {
    product_id: product.id,
    product_dna_id: dna.id,
    product_title: product.product_title,
    brand: product.brand,
    product_role: role,
    product_url: product.product_url || null,
    product_image_url: product.product_image_url || null,
    price: product.price ?? null,
    currency: product.currency || null,
    shopify_product_id: product.shopify_product_id || null,
    shopify_variant_id: product.shopify_variant_id || null,
    shopify_status: product.shopify_status || null,
    approval_status: dna.approval_status || null,
    score,
    matched,
    reasons,
    penalties,
    product_dna: {
      skin_type_fit: toArray(dna.skin_type_fit),
      main_concerns_it_helps: toArray(dna.main_concerns_it_helps),
      things_to_avoid: toArray(dna.things_to_avoid),
      recommended_routine_step: dna.recommended_routine_step,
      usage_timing: toArray(dna.usage_timing),
      sensitivity_risk: dna.sensitivity_risk,
      comedogenic_risk: dna.comedogenic_risk,
      fragrance_status: dna.fragrance_status,
      alcohol_status: dna.alcohol_status,
      pregnancy_caution: dna.pregnancy_caution,
      beautydna_match_notes: dna.beautydna_match_notes || null,
    },
  };
}

async function loadPassportProfile(supabase, passportId) {
  if (!passportId) {
    return {
      passport: null,
      profile: null,
      error: null,
    };
  }

  const { data, error } = await supabase
    .from("beautydna_passports")
    .select("*")
    .eq("id", passportId)
    .maybeSingle();

  if (error) {
    return {
      passport: null,
      profile: null,
      error,
    };
  }

  if (!data) {
    return {
      passport: null,
      profile: null,
      error: {
        message: "BeautyDNA passport not found.",
      },
    };
  }

  return {
    passport: data,
    profile: profileFromPassport(data),
    error: null,
  };
}

async function loadProductDnaRows(supabase, includeNeedsReview, requestedSteps) {
  let query = supabase
    .from("beautydna_product_dna")
    .select("*");

  if (!includeNeedsReview) {
    query = query.eq("approval_status", "approved");
  } else {
    query = query.neq("approval_status", "rejected");
  }

  if (requestedSteps.length > 0) {
    query = query.in("recommended_routine_step", requestedSteps);
  }

  const { data, error } = await query.limit(500);

  return {
    data: data || [],
    error,
  };
}

async function loadProductsByIds(supabase, productIds) {
  if (!productIds.length) {
    return {
      data: [],
      error: null,
    };
  }

  const { data, error } = await supabase
    .from("beautydna_products")
    .select("*")
    .in("id", productIds)
    .limit(500);

  return {
    data: data || [],
    error,
  };
}

function groupRankedByStep(scoredCandidates, requestedSteps, maxProductsPerStep) {
  const grouped = {};
  const routine = {};

  for (const step of requestedSteps) {
    const rankedForStep = scoredCandidates
      .filter((candidate) => candidate.product_role === step)
      .sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return String(a.product_title || "").localeCompare(String(b.product_title || ""));
      })
      .slice(0, maxProductsPerStep);

    grouped[step] = rankedForStep;
    routine[step] = rankedForStep[0] || null;
  }

  return {
    ranked_products: grouped,
    routine,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({
      ok: false,
      error: "Method not allowed. Use POST.",
    }, 405);
  }

  const expectedKey =
    Deno.env.get("BEAUTYDNA_INTERNAL_API_KEY") ||
    Deno.env.get("ATHENA_ADMIN_KEY") ||
    "";

  const suppliedKey =
    req.headers.get("x-beautydna-internal-key") ||
    req.headers.get("x-athena-admin-key") ||
    "";

  if (expectedKey && suppliedKey !== expectedKey) {
    return jsonResponse({
      ok: false,
      error: "Unauthorized.",
    }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    Deno.env.get("SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({
      ok: false,
      error: "Missing Supabase service configuration.",
    }, 500);
  }

  let body;

  try {
    body = await req.json();
  } catch (_error) {
    return jsonResponse({
      ok: false,
      error: "Invalid JSON body.",
    }, 400);
  }

  const passportId = cleanString(body.passport_id);
  const options = body.options || {};
  const debug = cleanBoolean(options.debug, false);
  const includeNeedsReview = cleanBoolean(options.include_needs_review, false) || debug;
  const maxProductsPerStep = readOptionNumber(options, "max_products_per_step", 3, 1, 10);

  const requestedSteps = uniqueArray(
    toLowerArray(options.routine_steps).length
      ? toLowerArray(options.routine_steps)
      : DEFAULT_ROUTINE_STEPS,
  );

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const warnings = [];

  let passport = null;
  let profile = normalizeProfile(body.profile || {});

  if (passportId) {
    const passportResult = await loadPassportProfile(supabase, passportId);

    if (passportResult.error) {
      return jsonResponse({
        ok: false,
        version: VERSION,
        error: "Failed to load BeautyDNA passport.",
        details: passportResult.error.message,
        passport_id: passportId,
      }, passportResult.error.message === "BeautyDNA passport not found." ? 404 : 500);
    }

    passport = passportResult.passport;
    profile = passportResult.profile;
  }

  if (!profile || profile.skin_type === "unknown") {
    warnings.push("Profile skin_type is missing or unknown. Scoring will rely more on concerns and routine role.");
  }

  if (!profile.skin_concerns.length) {
    warnings.push("Profile has no skin_concerns. Concern scoring will be limited.");
  }

  const dnaResult = await loadProductDnaRows(supabase, includeNeedsReview, requestedSteps);

  if (dnaResult.error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "Failed to load BeautyDNA Product DNA rows.",
      details: dnaResult.error.message,
    }, 500);
  }

  const productIds = uniqueArray(
    dnaResult.data
      .map((dna) => dna.product_id)
      .filter(Boolean),
  );

  const productsResult = await loadProductsByIds(supabase, productIds);

  if (productsResult.error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "Failed to load BeautyDNA products.",
      details: productsResult.error.message,
    }, 500);
  }

  const productMap = new Map(
    productsResult.data.map((product) => [product.id, product]),
  );

  const candidates = dnaResult.data
    .map((dna) => ({
      product: productMap.get(dna.product_id),
      product_dna: dna,
    }))
    .filter((candidate) => candidate.product)
    .filter((candidate) => canIncludeProduct(candidate.product, candidate.product_dna, includeNeedsReview));

  const scoredCandidates = candidates
    .map((candidate) => scoreCandidate(candidate, profile, requestedSteps, includeNeedsReview))
    .filter((candidate) => candidate.product_role !== "unknown");

  const grouped = groupRankedByStep(scoredCandidates, requestedSteps, maxProductsPerStep);

  const missingSteps = requestedSteps.filter((step) => !grouped.routine[step]);

  if (missingSteps.length > 0) {
    warnings.push(`No recommendation found for steps: ${missingSteps.join(", ")}.`);
  }

  if (includeNeedsReview) {
    warnings.push("include_needs_review/debug mode is enabled. Do not use this output as production customer-facing recommendation without approval filtering.");
  }

  const response = {
    ok: true,
    version: VERSION,
    passport_id: passportId || null,
    profile,
    options: {
      requested_steps: requestedSteps,
      max_products_per_step: maxProductsPerStep,
      include_needs_review: includeNeedsReview,
      debug,
    },
    candidate_counts: {
      product_dna_rows_loaded: dnaResult.data.length,
      products_loaded: productsResult.data.length,
      candidates_scored: scoredCandidates.length,
      missing_steps: missingSteps.length,
    },
    routine: grouped.routine,
    ranked_products: grouped.ranked_products,
    missing_steps: missingSteps,
    warnings,
  };

  if (debug) {
    response.debug = {
      score_weights: SCORE_WEIGHTS,
      passport_loaded: Boolean(passport),
      all_scored_candidates: scoredCandidates,
    };
  }

  return jsonResponse(response);
});
