import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

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

function cleanBoolean(value, fallback = true) {
  if (typeof value === "boolean") return value;
  return fallback;
}

function cleanNumber(value, fallback = 0) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) return fallback;
  return numberValue;
}

function getProductTitle(item) {
  return cleanString(item?.product?.product_title);
}

function getProductKey(item, index) {
  return (
    cleanString(item?.source_key) ||
    cleanString(item?.product?.sku) ||
    cleanString(item?.product?.handle) ||
    getProductTitle(item) ||
    `product-${index + 1}`
  );
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

  if (!supabaseUrl) {
    return jsonResponse({
      ok: false,
      error: "Missing SUPABASE_URL environment variable.",
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

  const products = Array.isArray(body.products) ? body.products : [];
  const continueOnError = cleanBoolean(body.continue_on_error, true);
  const requestedMaxItems = cleanNumber(body.max_items, 25);
  const maxItems = Math.min(Math.max(requestedMaxItems, 1), 50);

  const sourceType = cleanString(body.source_type) || "beautydna-v2-product-import-batch";
  const sourceKey = cleanString(body.source_key) || `batch-${new Date().toISOString()}`;

  if (products.length === 0) {
    return jsonResponse({
      ok: false,
      error: "products array is required and must contain at least one product import payload.",
    }, 400);
  }

  if (products.length > maxItems) {
    return jsonResponse({
      ok: false,
      error: `Batch size too large. Received ${products.length}, max allowed for this request is ${maxItems}.`,
      received_count: products.length,
      max_items: maxItems,
    }, 400);
  }

  const results = [];
  const errors = [];

  let successCount = 0;
  let failedCount = 0;
  let createdCount = 0;
  let updatedCount = 0;
  let ingredientSuccessCount = 0;
  let ingredientFailureCount = 0;
  let totalProductIngredientLinks = 0;
  let totalReviewQueueInserted = 0;

  for (let index = 0; index < products.length; index += 1) {
    const item = products[index];
    const itemKey = getProductKey(item, index);
    const productTitle = getProductTitle(item);

    const payload = {
      ...item,
      source_type: cleanString(item?.source_type) || sourceType,
      source_key: cleanString(item?.source_key) || `${sourceKey}-${itemKey}`,
    };

    try {
      const importResponse = await fetch(
        `${supabaseUrl}/functions/v1/beautydna-v2-product-import`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-beautydna-internal-key": expectedKey,
          },
          body: JSON.stringify(payload),
        },
      );

      let importResult;

      try {
        importResult = await importResponse.json();
      } catch (_jsonError) {
        importResult = {
          ok: false,
          error: "Product importer returned non-JSON response.",
          status: importResponse.status,
        };
      }

      if (!importResponse.ok || importResult.ok === false) {
        failedCount += 1;

        const errorRecord = {
          index,
          product_title: productTitle,
          source_key: payload.source_key,
          status: importResponse.status,
          error: importResult.error || "Product import failed.",
          details: importResult.details || null,
          result: importResult,
        };

        errors.push(errorRecord);

        results.push({
          index,
          ok: false,
          product_title: productTitle,
          source_key: payload.source_key,
          error: errorRecord.error,
          details: errorRecord.details,
        });

        if (!continueOnError) {
          return jsonResponse({
            ok: false,
            version: "beautydna-v2-product-import-batch-v1",
            error: "Batch stopped after first failed product because continue_on_error is false.",
            total_count: products.length,
            processed_count: index + 1,
            success_count: successCount,
            failed_count: failedCount,
            created_count: createdCount,
            updated_count: updatedCount,
            results,
            errors,
          }, 500);
        }

        continue;
      }

      successCount += 1;

      if (importResult.created_or_updated === "created") {
        createdCount += 1;
      }

      if (importResult.created_or_updated === "updated") {
        updatedCount += 1;
      }

      if (importResult.ingredient_ingestion?.ok === true) {
        ingredientSuccessCount += 1;
      } else if (importResult.ingredient_ingestion) {
        ingredientFailureCount += 1;
      }

      const ingestionCounts = importResult.ingredient_ingestion?.counts || {};
      totalProductIngredientLinks += Number(ingestionCounts.product_ingredient_link_count || 0);
      totalReviewQueueInserted += Number(ingestionCounts.review_queue_inserted_count || 0);

      results.push({
        index,
        ok: true,
        product_title: productTitle,
        source_key: payload.source_key,
        created_or_updated: importResult.created_or_updated,
        product_id: importResult.product_id,
        product_dna_id: importResult.product_dna_id,
        ingredient_ingestion_counts: ingestionCounts,
        removed_product_columns: importResult.removed_product_columns || [],
        removed_product_dna_columns: importResult.removed_product_dna_columns || [],
      });
    } catch (error) {
      failedCount += 1;

      const errorRecord = {
        index,
        product_title: productTitle,
        source_key: payload.source_key,
        error: error?.message || "Unexpected batch item error.",
      };

      errors.push(errorRecord);

      results.push({
        index,
        ok: false,
        product_title: productTitle,
        source_key: payload.source_key,
        error: errorRecord.error,
      });

      if (!continueOnError) {
        return jsonResponse({
          ok: false,
          version: "beautydna-v2-product-import-batch-v1",
          error: "Batch stopped after unexpected product error because continue_on_error is false.",
          total_count: products.length,
          processed_count: index + 1,
          success_count: successCount,
          failed_count: failedCount,
          created_count: createdCount,
          updated_count: updatedCount,
          results,
          errors,
        }, 500);
      }
    }
  }

  return jsonResponse({
    ok: failedCount === 0,
    version: "beautydna-v2-product-import-batch-v1",
    source_type: sourceType,
    source_key: sourceKey,
    total_count: products.length,
    processed_count: results.length,
    success_count: successCount,
    failed_count: failedCount,
    created_count: createdCount,
    updated_count: updatedCount,
    ingredient_success_count: ingredientSuccessCount,
    ingredient_failure_count: ingredientFailureCount,
    total_product_ingredient_links: totalProductIngredientLinks,
    total_review_queue_inserted: totalReviewQueueInserted,
    results,
    errors,
  }, failedCount === 0 ? 200 : 207);
});
