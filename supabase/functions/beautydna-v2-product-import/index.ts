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

function cleanNumber(value, fallback = 0) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) return fallback;
  return numberValue;
}

function cleanArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => cleanString(item))
    .filter(Boolean);
}

function normalizeKey(value) {
  return cleanString(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
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

  for (let attempt = 0; attempt < 20; attempt += 1) {
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
    error: {
      message: `Too many missing columns while inserting into ${tableName}.`,
    },
    removed_columns: removedColumns,
  };
}

async function updateWithColumnFallback(supabase, tableName, id, payload, selectColumns = "*") {
  let safePayload = { ...payload };
  const removedColumns = [];

  for (let attempt = 0; attempt < 20; attempt += 1) {
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
    error: {
      message: `Too many missing columns while updating ${tableName}.`,
    },
    removed_columns: removedColumns,
  };
}

async function findExistingProduct(supabase, productTitle, brand) {
  let query = supabase
    .from("beautydna_products")
    .select("id, product_title, brand, product_role")
    .eq("product_title", productTitle)
    .limit(1);

  if (brand) {
    query = query.eq("brand", brand);
  }

  const { data, error } = await query.maybeSingle();

  if (error) {
    return {
      product: null,
      error,
    };
  }

  return {
    product: data,
    error: null,
  };
}

async function saveProductDna(supabase, productId, productDna, sourceType, sourceKey) {
  const payload = {
    product_id: productId,
    skin_type_fit: cleanArray(productDna.skin_type_fit),
    main_concerns_it_helps: cleanArray(productDna.main_concerns_it_helps),
    things_to_avoid: cleanArray(productDna.things_to_avoid),
    recommended_routine_step: cleanString(productDna.recommended_routine_step),
    usage_timing: Array.isArray(productDna.usage_timing)
      ? cleanArray(productDna.usage_timing)
      : (cleanString(productDna.usage_timing) ? [cleanString(productDna.usage_timing)] : []),
    sensitivity_risk: cleanString(productDna.sensitivity_risk) || "unknown",
    comedogenic_risk: cleanString(productDna.comedogenic_risk) || "unknown",
    fragrance_status: cleanString(productDna.fragrance_status) || "unknown",
    alcohol_status: cleanString(productDna.alcohol_status) || "unknown",
    pregnancy_caution: cleanString(productDna.pregnancy_caution) || "unknown",
    beautydna_match_notes: cleanString(productDna.beautydna_match_notes),
    metadata: {
      source_type: sourceType,
      source_key: sourceKey,
      imported_by: "beautydna-v2-product-import",
    },
  };

  const { data: existing, error: existingError } = await supabase
    .from("beautydna_product_dna")
    .select("id, product_id")
    .eq("product_id", productId)
    .maybeSingle();

  if (existingError && !existingError.message?.includes("multiple")) {
    return {
      data: null,
      error: existingError,
      action: "lookup_failed",
      removed_columns: [],
    };
  }

  if (existing?.id) {
    const result = await updateWithColumnFallback(
      supabase,
      "beautydna_product_dna",
      existing.id,
      payload,
      "*",
    );

    return {
      ...result,
      action: "updated",
    };
  }

  const result = await insertWithColumnFallback(
    supabase,
    "beautydna_product_dna",
    payload,
    "*",
  );

  return {
    ...result,
    action: "created",
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

  const product = body.product || {};
  const productDna = body.product_dna || {};

  const productTitle = cleanString(product.product_title);
  const brand = cleanString(product.brand);
  const productRole = cleanString(product.product_role);

  const sourceType = cleanString(body.source_type) || "beautydna-v2-product-import";
  const sourceKey =
    cleanString(body.source_key) ||
    cleanString(product.sku) ||
    cleanString(product.handle) ||
    normalizeKey(`${brand}-${productTitle}`) ||
    "manual";

  const ingredientNames = cleanArray(product.ingredient_names);

  if (!productTitle) {
    return jsonResponse({
      ok: false,
      error: "product.product_title is required.",
    }, 400);
  }

  if (!brand) {
    return jsonResponse({
      ok: false,
      error: "product.brand is required.",
    }, 400);
  }

  if (!productRole) {
    return jsonResponse({
      ok: false,
      error: "product.product_role is required.",
    }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const productPayload = {
    product_title: productTitle,
    brand,
    product_role: productRole,
    shopify_status: cleanString(product.shopify_status) || "needs_shopify_creation",
    price: cleanNumber(product.price, 0),
    currency: cleanString(product.currency) || "BRL",
    handle: cleanString(product.handle) || normalizeKey(`${brand}-${productTitle}`),
    sku: cleanString(product.sku),
    shopify_product_id: cleanString(product.shopify_product_id) || null,
    shopify_variant_id: cleanString(product.shopify_variant_id) || null,
    product_url: cleanString(product.product_url),
    product_image_url: cleanString(product.product_image_url),
    image_url: cleanString(product.product_image_url),
    metadata: {
      source_type: sourceType,
      source_key: sourceKey,
      imported_by: "beautydna-v2-product-import",
      raw_product: product,
    },
  };

  const existingProductResult = await findExistingProduct(supabase, productTitle, brand);

  if (existingProductResult.error) {
    return jsonResponse({
      ok: false,
      error: "Failed to check existing product.",
      details: existingProductResult.error.message,
    }, 500);
  }

  let productSaveResult;
  let productAction;

  if (existingProductResult.product?.id) {
    productSaveResult = await updateWithColumnFallback(
      supabase,
      "beautydna_products",
      existingProductResult.product.id,
      productPayload,
      "id, product_title, brand, product_role",
    );
    productAction = "updated";
  } else {
    productSaveResult = await insertWithColumnFallback(
      supabase,
      "beautydna_products",
      productPayload,
      "id, product_title, brand, product_role",
    );
    productAction = "created";
  }

  if (productSaveResult.error) {
    return jsonResponse({
      ok: false,
      error: "Failed to save BeautyDNA product.",
      details: productSaveResult.error.message,
      removed_columns: productSaveResult.removed_columns,
    }, 500);
  }

  const savedProduct = productSaveResult.data;

  const productDnaResult = await saveProductDna(
    supabase,
    savedProduct.id,
    productDna,
    sourceType,
    sourceKey,
  );

  if (productDnaResult.error) {
    return jsonResponse({
      ok: false,
      error: "Product was saved, but Product DNA save failed.",
      details: productDnaResult.error.message,
      product: savedProduct,
      removed_product_columns: productSaveResult.removed_columns,
      removed_product_dna_columns: productDnaResult.removed_columns,
    }, 500);
  }

  let ingredientIngestion = null;

  if (ingredientNames.length > 0) {
    const ingestResponse = await fetch(
      `${supabaseUrl}/functions/v1/beautydna-v2-ingredient-ingest`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-beautydna-internal-key": expectedKey,
        },
        body: JSON.stringify({
          product_id: savedProduct.id,
          ingredient_names: ingredientNames,
          source_type: sourceType,
          source_key: sourceKey,
          create_review_tasks_for_missing: true,
        }),
      },
    );

    ingredientIngestion = await ingestResponse.json();

    if (!ingestResponse.ok || ingredientIngestion.ok === false) {
      return jsonResponse({
        ok: false,
        error: "Product and Product DNA were saved, but ingredient ingestion failed.",
        product: savedProduct,
        product_dna: productDnaResult.data,
        ingredient_ingestion: ingredientIngestion,
        removed_product_columns: productSaveResult.removed_columns,
        removed_product_dna_columns: productDnaResult.removed_columns,
      }, 500);
    }
  }

  return jsonResponse({
    ok: true,
    version: "beautydna-v2-product-import-v1",
    created_or_updated: productAction,
    product_id: savedProduct.id,
    product_dna_id: productDnaResult.data?.id || null,
    product: savedProduct,
    product_dna: productDnaResult.data,
    ingredient_ingestion: ingredientIngestion,
    removed_product_columns: productSaveResult.removed_columns,
    removed_product_dna_columns: productDnaResult.removed_columns,
  });
});

