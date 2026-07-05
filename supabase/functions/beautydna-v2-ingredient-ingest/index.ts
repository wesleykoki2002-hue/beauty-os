import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-athena-admin-key, x-beautydna-internal-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

function normalizeIngredientName(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[。．,，;；:：]+$/g, "")
    .trim();
}

function uniqueIngredients(values) {
  if (!Array.isArray(values)) return [];

  const seen = new Set();
  const result = [];

  for (const value of values) {
    const cleaned = cleanString(value);
    const normalized = normalizeIngredientName(cleaned);

    if (!cleaned || !normalized || seen.has(normalized)) continue;

    seen.add(normalized);
    result.push({
      original_name: cleaned,
      normalized_name: normalized,
    });
  }

  return result;
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
      error: "Missing Supabase environment variables.",
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

  const productId = cleanString(body.product_id);
  const sourceType = cleanString(body.source_type) || "beautydna-v2-ingredient-ingest";
  const sourceKey = cleanString(body.source_key) || productId || "manual";
  const createReviewTasksForMissing = body.create_review_tasks_for_missing !== false;
  const ingredients = uniqueIngredients(body.ingredient_names);

  if (!productId) {
    return jsonResponse({
      ok: false,
      error: "product_id is required.",
    }, 400);
  }

  if (ingredients.length === 0) {
    return jsonResponse({
      ok: false,
      error: "ingredient_names must contain at least one ingredient.",
    }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: product, error: productError } = await supabase
    .from("beautydna_products")
    .select("id, product_title, product_role")
    .eq("id", productId)
    .maybeSingle();

  if (productError) {
    return jsonResponse({
      ok: false,
      error: "Failed to load product.",
      details: productError.message,
    }, 500);
  }

  if (!product) {
    return jsonResponse({
      ok: false,
      error: "Product not found.",
      product_id: productId,
    }, 404);
  }

  const normalizedNames = ingredients.map((item) => item.normalized_name);

  const { data: directRows, error: directError } = await supabase
    .from("beautydna_ingredient_intelligence")
    .select("id, ingredient_name, normalized_name, review_status")
    .in("normalized_name", normalizedNames);

  if (directError) {
    return jsonResponse({
      ok: false,
      error: "Failed to search Ingredient Intelligence.",
      details: directError.message,
    }, 500);
  }

  const approvedByName = new Map();

  for (const row of directRows || []) {
    if (row.review_status === "approved" && row.normalized_name) {
      approvedByName.set(row.normalized_name, row);
    }
  }

  const { data: aliasRows, error: aliasError } = await supabase
    .from("beautydna_ingredient_aliases")
    .select("id, alias_name, normalized_alias_name, ingredient_id")
    .in("normalized_alias_name", normalizedNames);

  if (aliasError) {
    return jsonResponse({
      ok: false,
      error: "Failed to search ingredient aliases.",
      details: aliasError.message,
    }, 500);
  }

  const aliasIngredientIds = [
    ...new Set((aliasRows || []).map((row) => row.ingredient_id).filter(Boolean)),
  ];

  let aliasIngredientById = new Map();

  if (aliasIngredientIds.length > 0) {
    const { data: aliasIngredientRows, error: aliasIngredientError } = await supabase
      .from("beautydna_ingredient_intelligence")
      .select("id, ingredient_name, normalized_name, review_status")
      .in("id", aliasIngredientIds);

    if (aliasIngredientError) {
      return jsonResponse({
        ok: false,
        error: "Failed to load alias targets.",
        details: aliasIngredientError.message,
      }, 500);
    }

    aliasIngredientById = new Map(
      (aliasIngredientRows || []).map((row) => [row.id, row])
    );
  }

  const aliasByName = new Map();

  for (const alias of aliasRows || []) {
    const target = aliasIngredientById.get(alias.ingredient_id);

    if (!target || target.review_status !== "approved") continue;

    aliasByName.set(alias.normalized_alias_name, {
      alias,
      target,
    });
  }

  const productIngredientRows = [];
  const reviewQueueRows = [];
  const matchedIngredients = [];
  const missingIngredients = [];

  for (let index = 0; index < ingredients.length; index++) {
    const item = ingredients[index];

    const directMatch = approvedByName.get(item.normalized_name);
    const aliasMatch = aliasByName.get(item.normalized_name);

    if (directMatch) {
      productIngredientRows.push({
        product_id: productId,
        ingredient_id: directMatch.id,
        ingredient_name: item.original_name,
        normalized_ingredient_name: item.normalized_name,
        source_field: "ingredient_names",
        position: index + 1,
        match_status: "approved_match",
        review_status: "approved",
        metadata: {
          source_type: sourceType,
          source_key: sourceKey,
          match_type: "direct",
          matched_ingredient_name: directMatch.ingredient_name,
        },
      });

      matchedIngredients.push({
        input: item.original_name,
        normalized_input: item.normalized_name,
        match_type: "approved_match",
        ingredient_id: directMatch.id,
        ingredient_name: directMatch.ingredient_name,
      });

      continue;
    }

    if (aliasMatch) {
      productIngredientRows.push({
        product_id: productId,
        ingredient_id: aliasMatch.target.id,
        ingredient_name: item.original_name,
        normalized_ingredient_name: item.normalized_name,
        source_field: "ingredient_names",
        position: index + 1,
        match_status: "alias_match",
        review_status: "approved",
        metadata: {
          source_type: sourceType,
          source_key: sourceKey,
          match_type: "alias",
          alias_name: aliasMatch.alias.alias_name,
          matched_ingredient_name: aliasMatch.target.ingredient_name,
        },
      });

      matchedIngredients.push({
        input: item.original_name,
        normalized_input: item.normalized_name,
        match_type: "alias_match",
        ingredient_id: aliasMatch.target.id,
        ingredient_name: aliasMatch.target.ingredient_name,
        alias_name: aliasMatch.alias.alias_name,
      });

      continue;
    }

    productIngredientRows.push({
      product_id: productId,
      ingredient_id: null,
      ingredient_name: item.original_name,
      normalized_ingredient_name: item.normalized_name,
      source_field: "ingredient_names",
      position: index + 1,
      match_status: "unmatched",
      review_status: "needs_review",
      metadata: {
        source_type: sourceType,
        source_key: sourceKey,
        match_type: "missing",
      },
    });

    missingIngredients.push({
      input: item.original_name,
      normalized_input: item.normalized_name,
    });

    if (createReviewTasksForMissing) {
      reviewQueueRows.push({
        ingredient_name: item.original_name,
        normalized_ingredient_name: item.normalized_name,
        reason: "missing_ingredient",
        priority: "medium",
        status: "open",
        source_type: sourceType,
        source_key: sourceKey,
        product_id: productId,
        notes: "Missing ingredient found during BeautyDNA v2 ingredient ingestion.",
        metadata: {
          product_title: product.product_title,
          product_role: product.product_role,
        },
      });
    }
  }

  const { data: productLinks, error: linkError } = await supabase
    .from("beautydna_product_ingredients")
    .upsert(productIngredientRows, {
      onConflict: "product_id,normalized_ingredient_name",
    })
    .select("*");

  if (linkError) {
    return jsonResponse({
      ok: false,
      error: "Failed to save product ingredient links.",
      details: linkError.message,
    }, 500);
  }

  let queueRecords = [];

  if (reviewQueueRows.length > 0) {
    const { data: queueData, error: queueError } = await supabase
      .from("beautydna_ingredient_review_queue")
      .upsert(reviewQueueRows, {
        onConflict: "normalized_ingredient_name,source_type,source_key",
      })
      .select("*");

    if (queueError) {
      return jsonResponse({
        ok: false,
        error: "Product links were saved, but review queue insert failed.",
        details: queueError.message,
        product_ingredient_links: productLinks || [],
      }, 500);
    }

    queueRecords = queueData || [];
  }

  const approvedMatchCount = matchedIngredients.filter(
    (item) => item.match_type === "approved_match"
  ).length;

  const aliasMatchCount = matchedIngredients.filter(
    (item) => item.match_type === "alias_match"
  ).length;

  return jsonResponse({
    ok: true,
    version: "beautydna-v2-ingredient-ingest-v1-local-fix",
    product: {
      id: product.id,
      product_title: product.product_title,
      product_role: product.product_role,
    },
    counts: {
      input_ingredient_count: ingredients.length,
      matched_ingredient_count: approvedMatchCount + aliasMatchCount,
      approved_match_count: approvedMatchCount,
      alias_match_count: aliasMatchCount,
      missing_ingredient_count: missingIngredients.length,
      product_ingredient_link_count: productLinks?.length || 0,
      review_queue_inserted_count: queueRecords.length,
    },
    matched_ingredients: matchedIngredients,
    missing_ingredients: missingIngredients,
    product_ingredient_links: productLinks || [],
    review_queue_records: queueRecords,
  });
});
