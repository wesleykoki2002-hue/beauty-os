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

function cleanArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => cleanString(item)).filter(Boolean);
}

function cleanBoolean(value, fallback = false) {
  if (typeof value === "boolean") return value;
  return fallback;
}

function normalizeEvidenceLevel(value) {
  const allowedEvidenceLevels = new Set([
    "low",
    "medium",
    "high",
  ]);

  const cleaned = cleanString(value).toLowerCase();

  if (allowedEvidenceLevels.has(cleaned)) {
    return cleaned;
  }

  return "medium";
}

function normalizeIngredientName(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/[。．,，;；:：]+$/g, "")
    .trim();
}

function getUnknownColumnName(message) {
  if (!message) return null;

  const patterns = [
    /Could not find the '([^']+)' column/i,
    /column "([^"]+)" of relation/i,
    /column "([^"]+)" does not exist/i,
  ];

  for (const pattern of patterns) {
    const match = message.match(pattern);
    if (match?.[1]) return match[1];
  }

  return null;
}

async function insertWithColumnFallback(supabase, tableName, payload, selectColumns = "*") {
  let safePayload = { ...payload };
  const removedColumns = [];

  for (let attempt = 0; attempt < 25; attempt += 1) {
    const { data, error } = await supabase
      .from(tableName)
      .insert(safePayload)
      .select(selectColumns)
      .single();

    if (!error) {
      return {
        data,
        error: null,
        removed_columns: removedColumns,
      };
    }

    const missingColumn = getUnknownColumnName(error.message);

    if (!missingColumn || !(missingColumn in safePayload)) {
      return {
        data: null,
        error,
        removed_columns: removedColumns,
      };
    }

    delete safePayload[missingColumn];
    removedColumns.push(missingColumn);
  }

  return {
    data: null,
    error: { message: `Too many missing columns while inserting into ${tableName}.` },
    removed_columns: removedColumns,
  };
}

async function updateWithColumnFallback(supabase, tableName, id, payload, selectColumns = "*") {
  let safePayload = { ...payload };
  const removedColumns = [];

  for (let attempt = 0; attempt < 25; attempt += 1) {
    const { data, error } = await supabase
      .from(tableName)
      .update(safePayload)
      .eq("id", id)
      .select(selectColumns)
      .single();

    if (!error) {
      return {
        data,
        error: null,
        removed_columns: removedColumns,
      };
    }

    const missingColumn = getUnknownColumnName(error.message);

    if (!missingColumn || !(missingColumn in safePayload)) {
      return {
        data: null,
        error,
        removed_columns: removedColumns,
      };
    }

    delete safePayload[missingColumn];
    removedColumns.push(missingColumn);
  }

  return {
    data: null,
    error: { message: `Too many missing columns while updating ${tableName}.` },
    removed_columns: removedColumns,
  };
}

async function updateManyWithColumnFallback(queryBuilder, payload, selectColumns = "*") {
  let safePayload = { ...payload };
  const removedColumns = [];

  for (let attempt = 0; attempt < 25; attempt += 1) {
    const { data, error } = await queryBuilder(safePayload).select(selectColumns);

    if (!error) {
      return {
        data: data || [],
        error: null,
        removed_columns: removedColumns,
      };
    }

    const missingColumn = getUnknownColumnName(error.message);

    if (!missingColumn || !(missingColumn in safePayload)) {
      return {
        data: [],
        error,
        removed_columns: removedColumns,
      };
    }

    delete safePayload[missingColumn];
    removedColumns.push(missingColumn);
  }

  return {
    data: [],
    error: { message: "Too many missing columns while updating matching records." },
    removed_columns: removedColumns,
  };
}

async function findExistingIngredient(supabase, normalizedName) {
  const direct = await supabase
    .from("beautydna_ingredient_intelligence")
    .select("id, ingredient_name, normalized_name, normalized_ingredient_name, review_status")
    .eq("normalized_name", normalizedName)
    .limit(1)
    .maybeSingle();

  if (!direct.error && direct.data) {
    return { data: direct.data, error: null };
  }

  const fallback = await supabase
    .from("beautydna_ingredient_intelligence")
    .select("id, ingredient_name, normalized_name, normalized_ingredient_name, review_status")
    .eq("normalized_ingredient_name", normalizedName)
    .limit(1)
    .maybeSingle();

  if (!fallback.error && fallback.data) {
    return { data: fallback.data, error: null };
  }

  if (direct.error && !String(direct.error.message || "").includes("normalized_name")) {
    return { data: null, error: direct.error };
  }

  return { data: null, error: null };
}

function buildIngredientPayload(queueRecord, ingredientInput, action, reviewedBy, notes) {
  const ingredientName =
    cleanString(ingredientInput.ingredient_name) ||
    cleanString(queueRecord.ingredient_name);

  const normalizedName =
    normalizeIngredientName(ingredientInput.normalized_name) ||
    normalizeIngredientName(ingredientName) ||
    normalizeIngredientName(queueRecord.normalized_ingredient_name);

  return {
    ingredient_name: ingredientName,
    normalized_name: normalizedName,
    normalized_ingredient_name: normalizedName,

    ingredient_category: cleanString(ingredientInput.ingredient_category) || "unknown",

    benefits: cleanArray(ingredientInput.benefits),
    concerns_helped: cleanArray(ingredientInput.concerns_helped),
    skin_type_fit: cleanArray(ingredientInput.skin_type_fit),
    avoid_for: cleanArray(ingredientInput.avoid_for),

    sensitivity_risk: cleanString(ingredientInput.sensitivity_risk) || "unknown",
    comedogenic_risk: cleanString(ingredientInput.comedogenic_risk) || "unknown",
    pregnancy_caution: cleanString(ingredientInput.pregnancy_caution) || "unknown",

    fragrance_related: cleanBoolean(ingredientInput.fragrance_related, false),
    alcohol_related: cleanBoolean(ingredientInput.alcohol_related, false),

    short_explanation: cleanString(ingredientInput.short_explanation),
    long_explanation: cleanString(ingredientInput.long_explanation),

    evidence_level: normalizeEvidenceLevel(ingredientInput.evidence_level),
    source_notes: cleanString(ingredientInput.source_notes),

    review_status: action === "approve" ? "approved" : "rejected",
    reviewed_by: reviewedBy,
    reviewed_at: new Date().toISOString(),

    metadata: {
      reviewed_from_queue: true,
      review_queue_id: queueRecord.id,
      source_type: queueRecord.source_type,
      source_key: queueRecord.source_key,
      product_id: queueRecord.product_id || null,
      admin_notes: notes,
    },
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

  const reviewQueueId = cleanString(body.review_queue_id);
  const action = cleanString(body.action) || "approve";
  const ingredientInput = body.ingredient || {};
  const reviewedBy = cleanString(body.reviewed_by) || "athena_admin";
  const notes = cleanString(body.notes);

  if (!reviewQueueId) {
    return jsonResponse({
      ok: false,
      error: "review_queue_id is required.",
    }, 400);
  }

  if (!["approve", "reject"].includes(action)) {
    return jsonResponse({
      ok: false,
      error: "action must be approve or reject.",
    }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const { data: queueRecord, error: queueError } = await supabase
    .from("beautydna_ingredient_review_queue")
    .select("*")
    .eq("id", reviewQueueId)
    .maybeSingle();

  if (queueError) {
    return jsonResponse({
      ok: false,
      error: "Failed to load review queue record.",
      details: queueError.message,
    }, 500);
  }

  if (!queueRecord) {
    return jsonResponse({
      ok: false,
      error: "Review queue record not found.",
      review_queue_id: reviewQueueId,
    }, 404);
  }

  const normalizedName =
    normalizeIngredientName(ingredientInput.normalized_name) ||
    normalizeIngredientName(ingredientInput.ingredient_name) ||
    normalizeIngredientName(queueRecord.normalized_ingredient_name) ||
    normalizeIngredientName(queueRecord.ingredient_name);

  if (!normalizedName) {
    return jsonResponse({
      ok: false,
      error: "Could not determine normalized ingredient name.",
    }, 400);
  }

  let ingredientRecord = null;
  let ingredientAction = null;
  let ingredientRemovedColumns = [];

  if (action === "approve") {
    const ingredientPayload = buildIngredientPayload(
      queueRecord,
      {
        ...ingredientInput,
        normalized_name: normalizedName,
      },
      action,
      reviewedBy,
      notes,
    );

    const existingIngredientResult = await findExistingIngredient(supabase, normalizedName);

    if (existingIngredientResult.error) {
      return jsonResponse({
        ok: false,
        error: "Failed to check existing Ingredient Intelligence record.",
        details: existingIngredientResult.error.message,
      }, 500);
    }

    if (existingIngredientResult.data?.id) {
      const updateResult = await updateWithColumnFallback(
        supabase,
        "beautydna_ingredient_intelligence",
        existingIngredientResult.data.id,
        ingredientPayload,
        "*",
      );

      if (updateResult.error) {
        return jsonResponse({
          ok: false,
          error: "Failed to update Ingredient Intelligence record.",
          details: updateResult.error.message,
          removed_columns: updateResult.removed_columns,
        }, 500);
      }

      ingredientRecord = updateResult.data;
      ingredientAction = "updated";
      ingredientRemovedColumns = updateResult.removed_columns;
    } else {
      const insertResult = await insertWithColumnFallback(
        supabase,
        "beautydna_ingredient_intelligence",
        ingredientPayload,
        "*",
      );

      if (insertResult.error) {
        return jsonResponse({
          ok: false,
          error: "Failed to create Ingredient Intelligence record.",
          details: insertResult.error.message,
          removed_columns: insertResult.removed_columns,
        }, 500);
      }

      ingredientRecord = insertResult.data;
      ingredientAction = "created";
      ingredientRemovedColumns = insertResult.removed_columns;
    }
  }

  const queueUpdatePayload =
    action === "approve"
      ? {
          status: "resolved",
          resolved_ingredient_id: ingredientRecord?.id || null,
          assigned_to: reviewedBy,
          notes: notes || queueRecord.notes || "Approved from BeautyDNA v2 review queue.",
          metadata: {
            ...(queueRecord.metadata || {}),
            resolved_by_function: "beautydna-v2-review-queue-resolve",
            reviewed_by: reviewedBy,
            action,
            resolved_at: new Date().toISOString(),
          },
        }
      : {
          status: "rejected",
          assigned_to: reviewedBy,
          notes: notes || queueRecord.notes || "Rejected from BeautyDNA v2 review queue.",
          metadata: {
            ...(queueRecord.metadata || {}),
            resolved_by_function: "beautydna-v2-review-queue-resolve",
            reviewed_by: reviewedBy,
            action,
            rejected_at: new Date().toISOString(),
          },
        };

  const queueUpdateResult = await updateWithColumnFallback(
    supabase,
    "beautydna_ingredient_review_queue",
    reviewQueueId,
    queueUpdatePayload,
    "*",
  );

  if (queueUpdateResult.error) {
    return jsonResponse({
      ok: false,
      error: "Ingredient was handled, but queue update failed.",
      details: queueUpdateResult.error.message,
      ingredient: ingredientRecord,
      removed_queue_columns: queueUpdateResult.removed_columns,
    }, 500);
  }

  let productIngredientUpdateResult = {
    data: [],
    error: null,
    removed_columns: [],
  };

  if (action === "approve" && ingredientRecord?.id) {
    const productIngredientPayload = {
      ingredient_id: ingredientRecord.id,
      ingredient_name: ingredientRecord.ingredient_name,
      normalized_ingredient_name: normalizedName,
      match_status: "approved_match",
      review_status: "approved",
      metadata: {
        resolved_from_review_queue: true,
        review_queue_id: reviewQueueId,
        resolved_ingredient_id: ingredientRecord.id,
        reviewed_by: reviewedBy,
        resolved_at: new Date().toISOString(),
      },
    };

    productIngredientUpdateResult = await updateManyWithColumnFallback(
      (safePayload) => {
        let query = supabase
          .from("beautydna_product_ingredients")
          .update(safePayload)
          .eq("normalized_ingredient_name", normalizedName);

        if (queueRecord.product_id) {
          query = query.eq("product_id", queueRecord.product_id);
        }

        return query;
      },
      productIngredientPayload,
      "*",
    );

    if (productIngredientUpdateResult.error) {
      return jsonResponse({
        ok: false,
        error: "Queue was resolved, but product ingredient link update failed.",
        details: productIngredientUpdateResult.error.message,
        ingredient: ingredientRecord,
        queue_record: queueUpdateResult.data,
        removed_product_ingredient_columns: productIngredientUpdateResult.removed_columns,
      }, 500);
    }
  }

  return jsonResponse({
    ok: true,
    version: "beautydna-v2-review-queue-resolve-v1",
    action,
    review_queue_id: reviewQueueId,
    queue_status: queueUpdateResult.data?.status || null,
    ingredient_action: ingredientAction,
    ingredient_id: ingredientRecord?.id || null,
    ingredient: ingredientRecord,
    queue_record: queueUpdateResult.data,
    updated_product_ingredient_count: productIngredientUpdateResult.data?.length || 0,
    updated_product_ingredients: productIngredientUpdateResult.data || [],
    removed_ingredient_columns: ingredientRemovedColumns,
    removed_queue_columns: queueUpdateResult.removed_columns,
    removed_product_ingredient_columns: productIngredientUpdateResult.removed_columns,
  });
});

