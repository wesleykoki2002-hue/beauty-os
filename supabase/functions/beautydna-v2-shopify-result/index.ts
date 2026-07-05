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

function buildSafeCustomerPayload(
  recommendation: JsonRecord,
  explanation: JsonRecord,
  debug: boolean,
): JsonRecord {
  const safePayload: JsonRecord = {
    ok: true,
    version: VERSION,
    profile: explanation.profile || recommendation.profile || null,
    options: {
      language: "pt-BR",
      debug,
    },
    routine: recommendation.routine || {},
    ranked_products: recommendation.ranked_products || {},
    explanations: explanation.explanations || {},
    ingredient_highlights: explanation.ingredient_highlights || {},
    cautions: explanation.cautions || {},
    missing_steps: recommendation.missing_steps || [],
    warnings: [
      ...(Array.isArray(recommendation.warnings) ? recommendation.warnings : []),
      ...(Array.isArray(explanation.warnings) ? explanation.warnings : []),
    ],
  };

  if (debug) {
    safePayload.debug = {
      recommendation_counts: recommendation.candidate_counts || null,
      explanation_counts: explanation.counts || null,
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