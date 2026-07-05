import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VERSION = "beautydna-v2-recommendation-explain-v1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-athena-admin-key, x-beautydna-internal-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STEP_LABELS_PT_BR = {
  gentle_cleanser: "limpeza suave",
  hydrating_lotion: "lo\u00e7\u00e3o hidratante",
  barrier_serum: "s\u00e9rum de barreira",
  moisturizer: "hidratante",
  sunscreen: "protetor solar",
};

const STEP_PURPOSE_PT_BR = {
  gentle_cleanser: "remove impurezas sem agredir a barreira da pele",
  hydrating_lotion: "rep\u00f5e hidrata\u00e7\u00e3o leve e prepara a pele para os pr\u00f3ximos passos",
  barrier_serum: "ajuda a fortalecer a barreira e reduzir sensa\u00e7\u00e3o de ressecamento",
  moisturizer: "sela a hidrata\u00e7\u00e3o e ajuda a manter conforto ao longo do dia",
  sunscreen: "protege a pele contra radia\u00e7\u00e3o UV e ajuda a prevenir manchas e sinais de envelhecimento",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
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

function overlap(a, b) {
  const aSet = new Set(toLowerArray(a));
  const bSet = new Set(toLowerArray(b));

  return [...aSet].filter((item) => bSet.has(item));
}

function normalizeProfile(inputProfile) {
  const profile = inputProfile || {};

  return {
    skin_type:
      cleanLower(profile.skin_type) ||
      cleanLower(profile.skinType) ||
      "unknown",

    skin_concerns: uniqueArray([
      ...toLowerArray(profile.skin_concerns),
      ...toLowerArray(profile.concerns),
      ...toLowerArray(profile.main_concerns),
    ]),

    sensitivity_level:
      cleanLower(profile.sensitivity_level) ||
      cleanLower(profile.sensitivity) ||
      "unknown",

    acne_prone: cleanBoolean(profile.acne_prone, false),
    pregnancy: cleanBoolean(profile.pregnancy, false),

    avoid_ingredients: uniqueArray([
      ...toLowerArray(profile.avoid_ingredients),
      ...toLowerArray(profile.things_to_avoid),
      ...toLowerArray(profile.allergies),
    ]),
  };
}

function getStepLabel(step, language = "pt-BR") {
  if (language === "pt-BR") {
    return STEP_LABELS_PT_BR[step] || step;
  }

  return step;
}

function getStepPurpose(step, language = "pt-BR") {
  if (language === "pt-BR") {
    return STEP_PURPOSE_PT_BR[step] || "tem uma funﾃｧﾃ｣o especﾃｭfica na rotina personalizada";
  }

  return "has a specific role in the personalized routine";
}

function extractRoutineItems(routine) {
  const items = [];

  if (!routine || typeof routine !== "object") {
    return items;
  }

  for (const [step, product] of Object.entries(routine)) {
    if (!product || typeof product !== "object") continue;

    const productId =
      product.product_id ||
      product.id ||
      product.product?.id ||
      null;

    if (!productId) continue;

    items.push({
      step,
      product_id: productId,
      product,
    });
  }

  return items;
}

function extractRankedItems(rankedProducts) {
  const items = [];

  if (!rankedProducts || typeof rankedProducts !== "object") {
    return items;
  }

  for (const [step, products] of Object.entries(rankedProducts)) {
    if (!Array.isArray(products)) continue;

    for (const product of products) {
      if (!product || typeof product !== "object") continue;

      const productId =
        product.product_id ||
        product.id ||
        product.product?.id ||
        null;

      if (!productId) continue;

      items.push({
        step,
        product_id: productId,
        product,
      });
    }
  }

  return items;
}

function getProductTitle(product) {
  return (
    cleanString(product?.product_title) ||
    cleanString(product?.title) ||
    cleanString(product?.name) ||
    "Produto recomendado"
  );
}

function getProductBrand(product) {
  return cleanString(product?.brand);
}

function getProductRole(step, product, productDna) {
  return (
    cleanLower(productDna?.recommended_routine_step) ||
    cleanLower(product?.product_role) ||
    cleanLower(product?.product_dna?.recommended_routine_step) ||
    cleanLower(product?.product_dna?.product_role) ||
    cleanLower(step) ||
    "unknown"
  );
}

function getDnaArray(productDna, fieldName, fallbackProduct, fallbackFieldName) {
  const fromDna = toArray(productDna?.[fieldName]);

  if (fromDna.length) return fromDna;

  return toArray(fallbackProduct?.product_dna?.[fallbackFieldName || fieldName]);
}

function getDnaString(productDna, fieldName, fallbackProduct, fallbackFieldName) {
  return (
    cleanString(productDna?.[fieldName]) ||
    cleanString(fallbackProduct?.product_dna?.[fallbackFieldName || fieldName])
  );
}

function getIngredientBenefits(ingredient) {
  return uniqueArray([
    ...toArray(ingredient?.benefits),
    ...toArray(ingredient?.benefit_tags),
    ...toArray(ingredient?.concerns_helped),
    ...toArray(ingredient?.concern_tags),
  ]);
}

function getIngredientExplanation(ingredient) {
  return (
    cleanString(ingredient?.short_explanation) ||
    cleanString(ingredient?.explanation_short) ||
    cleanString(ingredient?.long_explanation) ||
    cleanString(ingredient?.explanation_long) ||
    cleanString(ingredient?.source_notes)
  );
}

function buildIngredientHighlights(productIngredientLinks, ingredientMap, maxHighlights = 4) {
  const highlights = [];

  for (const link of productIngredientLinks) {
    if (!link?.ingredient_id) continue;

    const ingredient = ingredientMap.get(link.ingredient_id);
    if (!ingredient) continue;

    const ingredientName =
      cleanString(ingredient.ingredient_name) ||
      cleanString(link.ingredient_name);

    if (!ingredientName) continue;

    highlights.push({
      ingredient_id: ingredient.id,
      ingredient_name: ingredientName,
      normalized_ingredient_name:
        cleanString(ingredient.normalized_name) ||
        cleanString(ingredient.normalized_ingredient_name) ||
        cleanString(link.normalized_ingredient_name),
      benefits: getIngredientBenefits(ingredient),
      explanation: getIngredientExplanation(ingredient),
      evidence_level: ingredient.evidence_level || null,
    });

    if (highlights.length >= maxHighlights) {
      break;
    }
  }

  return highlights;
}

function buildCautions(profile, productDna, ingredientHighlights) {
  const cautions = [];

  const sensitivityRisk = cleanLower(productDna?.sensitivity_risk);
  const comedogenicRisk = cleanLower(productDna?.comedogenic_risk);
  const pregnancyCaution = cleanLower(productDna?.pregnancy_caution);

  if (["sensitive", "high", "very_sensitive"].includes(profile.sensitivity_level) && sensitivityRisk === "high") {
    cautions.push("Este produto tem risco de sensibilidade alto para uma pele sens\u00edvel.");
  }

  if (profile.acne_prone && comedogenicRisk === "high") {
    cautions.push("Este produto tem risco comedog\u00eanico alto para uma pele com tend\u00eancia \u00e0 acne.");
  }

  if (profile.pregnancy && ["avoid", "caution", "not_recommended", "doctor_only"].includes(pregnancyCaution)) {
    cautions.push("Este produto tem observa\u00e7\u00e3o de cautela para gravidez.");
  }

  const avoidTerms = profile.avoid_ingredients || [];

  for (const ingredient of ingredientHighlights) {
    const normalized = cleanLower(ingredient.normalized_ingredient_name);
    const name = cleanLower(ingredient.ingredient_name);

    for (const avoidTerm of avoidTerms) {
      if (normalized.includes(avoidTerm) || name.includes(avoidTerm)) {
        cautions.push(`Aten\u00e7\u00e3o: este produto cont\u00e9m ${ingredient.ingredient_name}, que aparece na lista de ingredientes a evitar.`);
      }
    }
  }

  return uniqueArray(cautions);
}

function buildMatchSummary(profile, productDna, product, step, language) {
  const skinTypeFit = getDnaArray(productDna, "skin_type_fit", product);
  const concernsHelped = getDnaArray(productDna, "main_concerns_it_helps", product);
  const matchedSkinTypes = overlap([profile.skin_type], skinTypeFit);
  const matchedConcerns = overlap(profile.skin_concerns, concernsHelped);

  const routinePurpose = getStepPurpose(step, language);

  return {
    matched_skin_types: matchedSkinTypes,
    matched_concerns: matchedConcerns,
    routine_step_purpose: routinePurpose,
    skin_type_fit: skinTypeFit,
    concerns_helped: concernsHelped,
  };
}

function buildShortExplanation({
  productTitle,
  brand,
  stepLabel,
  matchSummary,
  ingredientHighlights,
  language,
}) {
  const brandText = brand ? ` da ${brand}` : "";
  const concernText = matchSummary.matched_concerns.length
    ? ` ajuda em ${matchSummary.matched_concerns.join(", ")}`
    : " combina com o perfil da sua rotina";

  const ingredientText = ingredientHighlights.length
    ? ` Destaque: ${ingredientHighlights.slice(0, 2).map((item) => item.ingredient_name).join(" + ")}.`
    : "";

  if (language === "pt-BR") {
    return `${productTitle}${brandText} entrou como ${stepLabel} porque${concernText} e ${matchSummary.routine_step_purpose}.${ingredientText}`;
  }

  return `${productTitle}${brandText} was selected for ${stepLabel} because it matches this routine step and profile.${ingredientText}`;
}

function buildLongExplanation({
  productTitle,
  brand,
  stepLabel,
  profile,
  productDna,
  matchSummary,
  ingredientHighlights,
  cautions,
  style,
  language,
}) {
  const brandText = brand ? ` da ${brand}` : "";

  const skinText = matchSummary.matched_skin_types.length
    ? `Ele combina com o tipo de pele ${matchSummary.matched_skin_types.join(", ")} informado no perfil.`
    : "Ele foi escolhido pela fun\u00e7\u00e3o na rotina e pelos dados de Product DNA dispon\u00edveis.";

  const concernText = matchSummary.matched_concerns.length
    ? `Tamb\u00e9m conversa com as principais necessidades detectadas: ${matchSummary.matched_concerns.join(", ")}.`
    : profile.skin_concerns.length
      ? "Ainda n\u00e3o h\u00e1 correspond\u00eancia perfeita de preocupa\u00e7\u00e3o nos dados, ent\u00e3o a escolha foi guiada principalmente pelo papel do produto na rotina."
      : "Como o perfil n\u00e3o trouxe preocupa\u00e7\u00f5es espec\u00edficas, a escolha foi guiada pelo papel do produto na rotina.";

  const ingredientText = ingredientHighlights.length
    ? `Ingredientes aprovados em destaque: ${ingredientHighlights.map((item) => {
        const explanation = item.explanation ? ` (${item.explanation})` : "";
        return `${item.ingredient_name}${explanation}`;
      }).join("; ")}.`
    : "Ainda n\u00e3o h\u00e1 ingredientes aprovados suficientes para gerar uma explica\u00e7\u00e3o de ingredientes para o cliente.";

  const cautionText = cautions.length
    ? `Pontos de aten\u00e7\u00e3o: ${cautions.join(" ")}`
    : "Nenhum ponto de aten\u00e7\u00e3o importante foi encontrado com os dados aprovados dispon\u00edveis.";

  const matchNotes =
    cleanString(productDna?.beautydna_match_notes) ||
    cleanString(productDna?.source_summary);

  const notesText = matchNotes && style !== "simple"
    ? ` Nota BeautyDNA: ${matchNotes}`
    : "";

  if (language === "pt-BR") {
    return `${productTitle}${brandText} foi recomendado como ${stepLabel} porque ${matchSummary.routine_step_purpose}. ${skinText} ${concernText} ${ingredientText} ${cautionText}${notesText}`;
  }

  return `${productTitle}${brandText} was recommended for ${stepLabel}. ${skinText} ${concernText} ${ingredientText} ${cautionText}${notesText}`;
}

async function loadProductDnaByProductIds(supabase, productIds) {
  if (!productIds.length) {
    return { data: [], error: null };
  }

  const { data, error } = await supabase
    .from("beautydna_product_dna")
    .select("*")
    .in("product_id", productIds)
    .limit(500);

  return {
    data: data || [],
    error,
  };
}

async function loadProductIngredientsByProductIds(supabase, productIds) {
  if (!productIds.length) {
    return { data: [], error: null };
  }

  const { data, error } = await supabase
    .from("beautydna_product_ingredients")
    .select("*")
    .in("product_id", productIds)
    .eq("review_status", "approved")
    .limit(1000);

  return {
    data: data || [],
    error,
  };
}

async function loadApprovedIngredientsByIds(supabase, ingredientIds) {
  if (!ingredientIds.length) {
    return { data: [], error: null };
  }

  const { data, error } = await supabase
    .from("beautydna_ingredient_intelligence")
    .select("*")
    .in("id", ingredientIds)
    .eq("review_status", "approved")
    .limit(1000);

  return {
    data: data || [],
    error,
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

  const profile = normalizeProfile(body.profile || {});
  const routine = body.routine || body.recommendation?.routine || {};
  const rankedProducts = body.ranked_products || body.recommendation?.ranked_products || {};
  const options = body.options || {};

  const debug = cleanBoolean(options.debug, false);
  const language = cleanString(options.language) || "pt-BR";
  const explanationStyle = cleanLower(options.explanation_style) || "premium";

  const routineItems = extractRoutineItems(routine);
  const rankedItems = extractRankedItems(rankedProducts);

  const allItems = [...routineItems, ...rankedItems];
  const productIds = uniqueArray(allItems.map((item) => item.product_id));

  if (!productIds.length) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "No recommended products found. Send routine or ranked_products from the recommendation engine.",
    }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const dnaResult = await loadProductDnaByProductIds(supabase, productIds);

  if (dnaResult.error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "Failed to load Product DNA.",
      details: dnaResult.error.message,
    }, 500);
  }

  const productIngredientResult = await loadProductIngredientsByProductIds(supabase, productIds);

  if (productIngredientResult.error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "Failed to load product ingredients.",
      details: productIngredientResult.error.message,
    }, 500);
  }

  const approvedIngredientIds = uniqueArray(
    productIngredientResult.data
      .map((item) => item.ingredient_id)
      .filter(Boolean),
  );

  const ingredientResult = await loadApprovedIngredientsByIds(supabase, approvedIngredientIds);

  if (ingredientResult.error) {
    return jsonResponse({
      ok: false,
      version: VERSION,
      error: "Failed to load approved Ingredient Intelligence.",
      details: ingredientResult.error.message,
    }, 500);
  }

  const dnaByProductId = new Map(
    dnaResult.data.map((dna) => [dna.product_id, dna]),
  );

  const productIngredientsByProductId = new Map();

  for (const link of productIngredientResult.data) {
    if (!productIngredientsByProductId.has(link.product_id)) {
      productIngredientsByProductId.set(link.product_id, []);
    }

    productIngredientsByProductId.get(link.product_id).push(link);
  }

  const ingredientMap = new Map(
    ingredientResult.data.map((ingredient) => [ingredient.id, ingredient]),
  );

  const explanations = {};
  const ingredientHighlightsByStep = {};
  const cautionsByStep = {};
  const warnings = [];

  for (const item of routineItems) {
    const step = item.step;
    const product = item.product;
    const productId = item.product_id;
    const productDna = dnaByProductId.get(productId) || product.product_dna || {};

    const role = getProductRole(step, product, productDna);
    const stepLabel = getStepLabel(role, language);

    const productTitle = getProductTitle(product);
    const brand = getProductBrand(product);

    const links = productIngredientsByProductId.get(productId) || [];
    const ingredientHighlights = buildIngredientHighlights(links, ingredientMap, 4);
    const matchSummary = buildMatchSummary(profile, productDna, product, role, language);
    const cautions = buildCautions(profile, productDna, ingredientHighlights);

    if (!ingredientHighlights.length) {
      warnings.push(`No approved Ingredient Intelligence highlights found for ${productTitle}.`);
    }

    explanations[step] = {
      step,
      step_label: stepLabel,
      product_id: productId,
      product_title: productTitle,
      brand: brand || null,
      short_explanation: buildShortExplanation({
        productTitle,
        brand,
        stepLabel,
        matchSummary,
        ingredientHighlights,
        language,
      }),
      long_explanation: buildLongExplanation({
        productTitle,
        brand,
        stepLabel,
        profile,
        productDna,
        matchSummary,
        ingredientHighlights,
        cautions,
        style: explanationStyle,
        language,
      }),
      match_summary: matchSummary,
      cautions,
      customer_claim_safety: {
        uses_only_approved_ingredient_intelligence: true,
        approved_ingredient_highlight_count: ingredientHighlights.length,
        unapproved_ingredient_claims_exposed: false,
      },
    };

    ingredientHighlightsByStep[step] = ingredientHighlights;
    cautionsByStep[step] = cautions;
  }

  const response = {
    ok: true,
    version: VERSION,
    profile,
    options: {
      language,
      explanation_style: explanationStyle,
      debug,
    },
    counts: {
      routine_products: routineItems.length,
      unique_products_seen: productIds.length,
      product_dna_rows_loaded: dnaResult.data.length,
      approved_product_ingredient_links_loaded: productIngredientResult.data.length,
      approved_ingredient_intelligence_rows_loaded: ingredientResult.data.length,
    },
    explanations,
    ingredient_highlights: ingredientHighlightsByStep,
    cautions: cautionsByStep,
    warnings,
  };

  if (debug) {
    response.debug = {
      product_ids: productIds,
      routine_items: routineItems,
      ranked_items_seen: rankedItems.length,
      product_dna_rows: dnaResult.data,
      approved_product_ingredient_links: productIngredientResult.data,
      approved_ingredients_loaded: ingredientResult.data,
      note: "Debug output is founder-facing only. Customer-facing claims should only use the explanations and approved ingredient highlights.",
    };
  }

  return jsonResponse(response);
});
