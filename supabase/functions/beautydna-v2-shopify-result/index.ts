import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const VERSION = "beautydna-v2-shopify-result-v1";

type JsonRecord = Record<string, unknown>;

function jsonResponse(
  body: JsonRecord,
  status = 200,
  origin = "*",
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Vary": "Origin",
    },
  });
}

function getAllowedOrigin(request: Request): string | null {
  const origin = request.headers.get("origin") || "*";
  const rawAllowed = Deno.env.get("BEAUTYDNA_SHOPIFY_ALLOWED_ORIGINS") || "";
  const allowedOrigins = rawAllowed
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);

  if (allowedOrigins.length === 0) {
    return origin === "*" ? "*" : origin;
  }

  if (origin !== "*" && allowedOrigins.includes(origin)) {
    return origin;
  }

  return null;
}

function cleanString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function cleanStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanString(item))
    .filter(Boolean);
}

function cleanBoolean(value: unknown): boolean {
  return value === true;
}

function cleanNumber(value: unknown, fallback: number): number {
  if (typeof value !== "number" || Number.isNaN(value)) return fallback;
  return value;
}

function normalizeProfile(input: JsonRecord): JsonRecord {
  const profile = typeof input.profile === "object" && input.profile !== null
    ? input.profile as JsonRecord
    : {};

  return {
    skin_type: cleanString(profile.skin_type) || "dry",
    skin_concerns: cleanStringArray(profile.skin_concerns).length
      ? cleanStringArray(profile.skin_concerns)
      : ["dehydration", "barrier_support", "dryness"],
    sensitivity_level: cleanString(profile.sensitivity_level) || "normal",
    acne_prone: cleanBoolean(profile.acne_prone),
    pregnancy: cleanBoolean(profile.pregnancy),
    avoid_ingredients: cleanStringArray(profile.avoid_ingredients),
  };
}

function normalizeOptions(input: JsonRecord): JsonRecord {
  const options = typeof input.options === "object" && input.options !== null
    ? input.options as JsonRecord
    : {};

  const debug = cleanBoolean(options.debug);
  const includeNeedsReview = debug && cleanBoolean(options.include_needs_review);

  return {
    routine_steps: cleanStringArray(options.routine_steps).length
      ? cleanStringArray(options.routine_steps)
      : ["hydrating_lotion", "barrier_serum"],
    max_products_per_step: Math.max(1, Math.min(5, cleanNumber(options.max_products_per_step, 1))),
    include_needs_review: includeNeedsReview,
    debug,
  };
}

async function callBeautyDnaFunction(
  functionName: string,
  payload: JsonRecord,
): Promise<JsonRecord> {
  const supabaseUrl =
    Deno.env.get("SUPABASE_URL") ||
    "https://hidsyvanaipxxyyhjgmc.supabase.co";

  const internalKey = Deno.env.get("BEAUTYDNA_INTERNAL_API_KEY");

  if (!internalKey) {
    throw new Error("Missing BEAUTYDNA_INTERNAL_API_KEY secret.");
  }

  const response = await fetch(`${supabaseUrl}/functions/v1/${functionName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "x-beautydna-internal-key": internalKey,
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();

  let json: JsonRecord = {};
  try {
    json = JSON.parse(text);
  } catch {
    json = {
      ok: false,
      raw_response: text,
    };
  }

  if (!response.ok) {
    throw new Error(`${functionName} failed: ${JSON.stringify(json)}`);
  }

  return json;
}

const CUSTOMER_LABEL_PT_BR: Record<string, string> = {
  "dehydration": "desidratação",
  "barrier_support": "barreira da pele",
  "barrier support": "barreira da pele",
  "dryness": "ressecamento",
  "hydration": "hidratação",
  "hydration support": "suporte de hidratação",
  "water-binding support": "retenção de água na pele",
  "plumping": "efeito de preenchimento hidratante",
  "skin comfort": "conforto da pele",
  "test_queue_resolution": "teste interno de aprovação",
  "dry": "seca",
  "oily": "oleosa",
  "normal": "normal",
  "combination": "mista",
  "sensitive": "sensível",
  "low": "baixo",
  "medium": "médio",
  "high": "alto",
  "morning_evening": "manhã e noite",
  "evening": "noite",
  "morning": "manhã",
  "generally_ok": "geralmente seguro",
  "unknown": "não informado",
  "acne": "acne",
  "pigmentation": "manchas",
  "aging": "sinais de idade",
  "oiliness": "oleosidade",
};

const INGREDIENT_DISPLAY_PT_BR: Record<string, string> = {
  "hyaluronic acid": "Ácido hialurônico",
  "sodium hyaluronate": "Hialuronato de sódio",
  "hydrolyzed hyaluronic acid": "Ácido hialurônico hidrolisado",
  "ceramide np": "Ceramida NP",
  "ceramide 3": "Ceramida 3",
  "niacinamide": "Niacinamida",
  "vitamin b3": "Vitamina B3",
};

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\function buildSafeCustomerPayload");
}

function translateCustomerText(value: unknown): string {
  if (typeof value !== "string") return "";

  let output = value;

  const orderedLabels = Object.entries(CUSTOMER_LABEL_PT_BR)
    .sort((a, b) => b[0].length - a[0].length);

  for (const [raw, translated] of orderedLabels) {
    const pattern = new RegExp(`\\b${escapeRegExp(raw)}\\b`, "gi");
    output = output.replace(pattern, translated);
  }

  for (const [raw, translated] of Object.entries(INGREDIENT_DISPLAY_PT_BR)) {
    const pattern = new RegExp(`\\b${escapeRegExp(raw)}\\b`, "gi");
    output = output.replace(pattern, `${translated} (${raw.replace(/\b\w/g, (char) => char.toUpperCase())})`);
  }

  return output;
}

function translateCustomerArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => translateCustomerText(item))
    .filter(Boolean);
}

function getIngredientDisplayName(name: unknown): string {
  const rawName = cleanString(name);
  if (!rawName) return "";

  const translated = INGREDIENT_DISPLAY_PT_BR[rawName.toLowerCase()];

  if (!translated) {
    return translateCustomerText(rawName);
  }

  return `${translated} (${rawName})`;
}

function translateProfileForCustomer(profile: unknown): JsonRecord {
  const source = typeof profile === "object" && profile !== null
    ? profile as JsonRecord
    : {};

  return {
    skin_type: translateCustomerText(source.skin_type),
    skin_concerns: translateCustomerArray(source.skin_concerns),
    sensitivity_level: translateCustomerText(source.sensitivity_level),
    acne_prone: source.acne_prone === true,
    pregnancy: source.pregnancy === true,
    avoid_ingredients: translateCustomerArray(source.avoid_ingredients),
  };
}

function translateMatchSummaryForCustomer(matchSummary: unknown): JsonRecord {
  const source = typeof matchSummary === "object" && matchSummary !== null
    ? matchSummary as JsonRecord
    : {};

  return {
    ...source,
    matched_skin_types: translateCustomerArray(source.matched_skin_types),
    matched_concerns: translateCustomerArray(source.matched_concerns),
    routine_step_purpose: translateCustomerText(source.routine_step_purpose),
    skin_type_fit: translateCustomerArray(source.skin_type_fit),
    concerns_helped: translateCustomerArray(source.concerns_helped),
  };
}

function translateExplanationForCustomer(explanation: unknown): JsonRecord {
  const source = typeof explanation === "object" && explanation !== null
    ? explanation as JsonRecord
    : {};

  return {
    ...source,
    step_label: translateCustomerText(source.step_label),
    short_explanation: translateCustomerText(source.short_explanation),
    long_explanation: translateCustomerText(source.long_explanation),
    match_summary: translateMatchSummaryForCustomer(source.match_summary),
    cautions: translateCustomerArray(source.cautions),
  };
}

function translateExplanationMapForCustomer(explanations: unknown): JsonRecord {
  if (typeof explanations !== "object" || explanations === null) return {};

  const result: JsonRecord = {};

  for (const [step, explanation] of Object.entries(explanations as JsonRecord)) {
    result[step] = translateExplanationForCustomer(explanation);
  }

  return result;
}

function translateIngredientHighlightForCustomer(ingredient: unknown): JsonRecord {
  const source = typeof ingredient === "object" && ingredient !== null
    ? ingredient as JsonRecord
    : {};

  return {
    ...source,
    display_name: getIngredientDisplayName(source.ingredient_name),
    customer_ingredient_name: getIngredientDisplayName(source.ingredient_name),
    benefits: translateCustomerArray(source.benefits),
    concerns_helped: translateCustomerArray(source.concerns_helped),
    explanation: translateCustomerText(source.explanation),
    evidence_level_label: translateCustomerText(source.evidence_level),
  };
}

function translateIngredientHighlightMapForCustomer(highlights: unknown): JsonRecord {
  if (typeof highlights !== "object" || highlights === null) return {};

  const result: JsonRecord = {};

  for (const [step, items] of Object.entries(highlights as JsonRecord)) {
    result[step] = Array.isArray(items)
      ? items.map((item) => translateIngredientHighlightForCustomer(item))
      : [];
  }

  return result;
}

function translateCautionMapForCustomer(cautions: unknown): JsonRecord {
  if (typeof cautions !== "object" || cautions === null) return {};

  const result: JsonRecord = {};

  for (const [step, items] of Object.entries(cautions as JsonRecord)) {
    result[step] = translateCustomerArray(items);
  }

  return result;
}

function translateWarningsForCustomer(warnings: unknown): string[] {
  return translateCustomerArray(warnings);
}

function buildSafeCustomerPayload(
  recommendation: JsonRecord,
  explanation: JsonRecord,
  debug: boolean,
): JsonRecord {
  const translatedExplanations = translateExplanationMapForCustomer(explanation.explanations || {});
  const translatedIngredientHighlights = translateIngredientHighlightMapForCustomer(explanation.ingredient_highlights || {});
  const translatedCautions = translateCautionMapForCustomer(explanation.cautions || {});

  const safePayload: JsonRecord = {
    ok: true,
    version: VERSION,
    profile: recommendation.profile || null,
    profile_display: translateProfileForCustomer(explanation.profile || recommendation.profile || null),
    options: {
      language: "pt-BR",
      debug,
    },
    routine: recommendation.routine || {},
    ranked_products: recommendation.ranked_products || {},
    explanations: translatedExplanations,
    ingredient_highlights: translatedIngredientHighlights,
    cautions: translatedCautions,
    missing_steps: recommendation.missing_steps || [],
    warnings: translateWarningsForCustomer([
      ...(Array.isArray(recommendation.warnings) ? recommendation.warnings : []),
      ...(Array.isArray(explanation.warnings) ? explanation.warnings : []),
    ]),
  };

  if (debug) {
    safePayload.debug = {
      recommendation_counts: recommendation.candidate_counts || null,
      explanation_counts: explanation.counts || null,
      raw_profile: recommendation.profile || null,
      customer_claim_safety_note:
        "Founder debug only. Do not show this object as customer-facing UI.",
    };
  }

  return safePayload;
}

serve(async (request: Request) => {
  const allowedOrigin = getAllowedOrigin(request);

  if (request.method === "OPTIONS") {
    return jsonResponse({ ok: true }, 200, allowedOrigin || "*");
  }

  if (!allowedOrigin) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "ORIGIN_NOT_ALLOWED",
    }, 403, "null");
  }

  if (request.method !== "POST") {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "METHOD_NOT_ALLOWED",
    }, 405, allowedOrigin);
  }

  try {
    const input = await request.json() as JsonRecord;

    const profile = normalizeProfile(input);
    const options = normalizeOptions(input);
    const debug = cleanBoolean(options.debug);

    const recommendation = await callBeautyDnaFunction(
      "beautydna-v2-recommendation-generate",
      {
        passport_id: cleanString(input.passport_id) || null,
        profile,
        options,
      },
    );

    const explanation = await callBeautyDnaFunction(
      "beautydna-v2-recommendation-explain",
      {
        profile: recommendation.profile || profile,
        routine: recommendation.routine || {},
        ranked_products: recommendation.ranked_products || {},
        options: {
          language: "pt-BR",
          explanation_style: debug ? "premium" : "simple",
          debug,
        },
      },
    );

    return jsonResponse(
      buildSafeCustomerPayload(recommendation, explanation, debug),
      200,
      allowedOrigin,
    );
  } catch (error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "SHOPIFY_RESULT_PROXY_FAILED",
      message: error instanceof Error ? error.message : String(error),
    }, 500, allowedOrigin);
  }
});