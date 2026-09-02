export const CATALOG_INTENT_VERSION = "bdna-shopify-catalog-intent-v1" as const;

export const LINKAGE_PLAN_VERSION = "bdna-shopify-linkage-plan-v1" as const;

export const BDNA_SHOP_0002_DRY_RUN_PAYLOAD_VERSION =
  "bdna-shop-0002-shopify-dry-run-payload-v1" as const;

export const BDNA_SHOP_0002_MANIFEST_VERSION =
  "beautydna-shopify-launch-linkage-contract-v1" as const;

export const BDNA_SHOP_0002_BUILD_ID = "BDNA-SHOP-0002" as const;

export const BDNA_SHOP_0002_TITLE =
  "BDNA-SHOP-0002 Hanna Launch Catalog Shopify Creation and Canonical Linkage" as const;

export const BDNA_SHOP_0002_CUREL_INGREDIENT_HOLDS = [
  {
    ingredient_id: "2bc80b34-1c9a-457b-a468-cbb53f29c53e",
    ingredient_name: "パラベン",
  },
  {
    ingredient_id: "30e352fb-9a5f-4b8b-b96f-7d224a9b1bad",
    ingredient_name: "α-オレフィンオリゴマー",
  },
  {
    ingredient_id: "e24bafb4-2917-4b1e-a7fd-c1740784e8ed",
    ingredient_name: "POE・ジメチコン共重合体",
  },
] as const;

export type BeautyDnaCatalogSource = {
  source_key: string;
  sku: string;
  brand: string;
  product_title: string;
  product_name?: string | null;
  category?: string | null;
  product_role: string;
  handle: string;
  price: number | null;
  currency: string;
  shopify_status: string;
  shopify_product_id: string | null;
  shopify_variant_id: string | null;
  product_url?: string | null;
};

export type ShopifyCatalogIntentV1 = {
  contract_version: typeof CATALOG_INTENT_VERSION;
  offline_only: true;
  operation: "create_product_with_single_variant";

  beautydna_selector: {
    source_key: string;
    sku: string;
  };

  idempotency_key: string;

  product: {
    title: string;
    handle: string;
    vendor: string;
    product_type: string;
    status: "DRAFT";
  };

  variant: {
    sku: string;
    price: string | null;
  };

  currency_context: string;

  ready_for_live_create: boolean;
  blockers: string[];

  linkage: {
    shopify_product_id: null;
    shopify_variant_id: null;
  };
};

export type ExistingShopifyLinkage = {
  beauty_product_id: string;
  shopify_product_id: string | null;
  shopify_variant_id: string | null;
  shopify_status: string;
};

export type ReturnedShopifyLinkage = {
  shopify_product_id: string;
  shopify_variant_id: string;
};

export type LinkageOwner = {
  beauty_product_id: string;
  shopify_product_id: string | null;
  shopify_variant_id: string | null;
};

export type ShopifyLinkagePlan = {
  contract_version: typeof LINKAGE_PLAN_VERSION;

  action:
    | "apply"
    | "noop"
    | "conflict"
    | "invalid";

  beauty_product_id: string;

  blockers: string[];

  patch: null | {
    shopify_product_id: string;
    shopify_variant_id: string;
    shopify_status: "linked";
  };
};

export type BdnaShop0002DryRunPayload = {
  contract_version: typeof BDNA_SHOP_0002_DRY_RUN_PAYLOAD_VERSION;
  build_id: typeof BDNA_SHOP_0002_BUILD_ID;
  build_title: typeof BDNA_SHOP_0002_TITLE;
  offline_only: true;
  live_shopify_write_authorized: false;
  may_perform_live_shopify_write: false;
  mutation_name: "productCreate";
  idempotency_key: string;
  beautydna_selector: {
    source_key: string;
    sku: string;
  };
  shopify_input: {
    title: string;
    handle: string;
    vendor: string;
    productType: string;
    status: "DRAFT";
    variants: Array<{
      sku: string;
      price: string | null;
    }>;
  };
  linkage: {
    shopify_product_id: null;
    shopify_variant_id: null;
  };
  execution: {
    ready_for_live_create: false;
    blocked_reasons: string[];
  };
};

export type BdnaShop0002DryRunManifest = {
  contract_version: typeof BDNA_SHOP_0002_MANIFEST_VERSION;
  build_id: typeof BDNA_SHOP_0002_BUILD_ID;
  build_title: typeof BDNA_SHOP_0002_TITLE;
  canonical_launch_product_count: number;
  dry_run_payload_count: number;
  offline_only: true;
  live_shopify_write_authorized: false;
  beauty_database_writes: 0;
  shopify_writes: 0;
  repository_mutation_scope:
    "source_only_offline_dry_run_payload_generation";
  product_dna_approved_count: 5;
  ingredient_ready_count: 4;
  shopify_linkage_eligible_count: 5;
  current_real_shopify_link_count: 0;
  current_unlinked_launch_products: 5;
  complete_ingredient_coverage_claimed: false;
  unresolved_ingredient_holds:
    typeof BDNA_SHOP_0002_CUREL_INGREDIENT_HOLDS;
  payloads: BdnaShop0002DryRunPayload[];
};

function clean(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function duplicateValues(values: string[]): string[] {
  const counts = new Map<string, number>();

  for (const value of values) {
    counts.set(value, (counts.get(value) ?? 0) + 1);
  }

  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([value]) => value)
    .sort();
}

function exactPositiveMoney(value: number | null): string | null {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value <= 0
  ) {
    return null;
  }

  return value.toFixed(2);
}

export function validateOfflineFixtureCatalog(
  products: BeautyDnaCatalogSource[],
): string[] {
  if (!Array.isArray(products) || products.length === 0) {
    return ["fixture_catalog_empty"];
  }

  const blockers: string[] = [];

  for (const product of products) {
    const identity = clean(product.source_key) ||
      clean(product.sku) ||
      "unknown";

    if (!clean(product.source_key)) {
      blockers.push(`${identity}:missing_source_key`);
    }

    if (!clean(product.sku)) {
      blockers.push(`${identity}:missing_sku`);
    }

    if (!clean(product.handle)) {
      blockers.push(`${identity}:missing_handle`);
    }

    if (!clean(product.brand)) {
      blockers.push(`${identity}:missing_brand`);
    }

    if (!clean(product.product_title)) {
      blockers.push(`${identity}:missing_product_title`);
    }

    if (!clean(product.product_role)) {
      blockers.push(`${identity}:missing_product_role`);
    }

    if (clean(product.shopify_status) !== "needs_shopify_creation") {
      blockers.push(`${identity}:unexpected_shopify_status`);
    }

    if (
      product.shopify_product_id !== null ||
      product.shopify_variant_id !== null
    ) {
      blockers.push(`${identity}:fixture_contains_shopify_linkage`);
    }
  }

  for (
    const [field, values] of [
      ["source_key", products.map((product) => clean(product.source_key))],
      ["sku", products.map((product) => clean(product.sku))],
      ["handle", products.map((product) => clean(product.handle))],
    ] as const
  ) {
    for (const duplicate of duplicateValues(values.filter(Boolean))) {
      blockers.push(`duplicate_${field}:${duplicate}`);
    }
  }

  return blockers.sort();
}

export function buildOfflineCatalogIntent(
  product: BeautyDnaCatalogSource,
): ShopifyCatalogIntentV1 {
  const blockers: string[] = [];

  const sourceKey = clean(product.source_key);
  const sku = clean(product.sku);
  const title = clean(product.product_title);
  const handle = clean(product.handle);
  const vendor = clean(product.brand);
  const productType = clean(product.category) || clean(product.product_role);
  const currency = clean(product.currency).toUpperCase();
  const price = exactPositiveMoney(product.price);

  if (!sourceKey) {
    blockers.push("missing_source_key");
  }

  if (!sku) {
    blockers.push("missing_sku");
  }

  if (!title) {
    blockers.push("missing_product_title");
  }

  if (!handle) {
    blockers.push("missing_handle");
  }

  if (!vendor) {
    blockers.push("missing_brand");
  }

  if (!productType) {
    blockers.push("missing_product_type");
  }

  if (!/^[A-Z]{3}$/.test(currency)) {
    blockers.push("invalid_currency_context");
  }

  if (price === null) {
    blockers.push("price_must_be_positive");
  }

  if (clean(product.shopify_status) !== "needs_shopify_creation") {
    blockers.push("shopify_status_not_create_candidate");
  }

  if (
    product.shopify_product_id !== null ||
    product.shopify_variant_id !== null
  ) {
    blockers.push("product_already_has_shopify_linkage");
  }

  return {
    contract_version: CATALOG_INTENT_VERSION,
    offline_only: true,
    operation: "create_product_with_single_variant",

    beautydna_selector: {
      source_key: sourceKey,
      sku,
    },

    idempotency_key: `beautydna:${sourceKey}:${sku}`,

    product: {
      title,
      handle,
      vendor,
      product_type: productType,
      status: "DRAFT",
    },

    variant: {
      sku,
      price,
    },

    currency_context: currency,
    ready_for_live_create: blockers.length === 0,
    blockers: blockers.sort(),

    linkage: {
      shopify_product_id: null,
      shopify_variant_id: null,
    },
  };
}

export function buildBdnaShop0002DryRunPayload(
  product: BeautyDnaCatalogSource,
): BdnaShop0002DryRunPayload {
  const intent = buildOfflineCatalogIntent(product);

  const blockedReasons = [
    ...intent.blockers,
    "live_shopify_write_not_authorized",
  ].sort();

  return {
    contract_version: BDNA_SHOP_0002_DRY_RUN_PAYLOAD_VERSION,
    build_id: BDNA_SHOP_0002_BUILD_ID,
    build_title: BDNA_SHOP_0002_TITLE,
    offline_only: true,
    live_shopify_write_authorized: false,
    may_perform_live_shopify_write: false,
    mutation_name: "productCreate",

    idempotency_key:
      `${BDNA_SHOP_0002_BUILD_ID}:${intent.idempotency_key}`,

    beautydna_selector: intent.beautydna_selector,

    shopify_input: {
      title: intent.product.title,
      handle: intent.product.handle,
      vendor: intent.product.vendor,
      productType: intent.product.product_type,
      status: "DRAFT",
      variants: [
        {
          sku: intent.variant.sku,
          price: intent.variant.price,
        },
      ],
    },

    linkage: {
      shopify_product_id: null,
      shopify_variant_id: null,
    },

    execution: {
      ready_for_live_create: false,
      blocked_reasons: blockedReasons,
    },
  };
}

export function buildBdnaShop0002DryRunManifest(
  products: BeautyDnaCatalogSource[],
): BdnaShop0002DryRunManifest {
  return {
    contract_version: BDNA_SHOP_0002_MANIFEST_VERSION,
    build_id: BDNA_SHOP_0002_BUILD_ID,
    build_title: BDNA_SHOP_0002_TITLE,
    canonical_launch_product_count: products.length,
    dry_run_payload_count: products.length,
    offline_only: true,
    live_shopify_write_authorized: false,
    beauty_database_writes: 0,
    shopify_writes: 0,
    repository_mutation_scope:
      "source_only_offline_dry_run_payload_generation",
    product_dna_approved_count: 5,
    ingredient_ready_count: 4,
    shopify_linkage_eligible_count: 5,
    current_real_shopify_link_count: 0,
    current_unlinked_launch_products: 5,
    complete_ingredient_coverage_claimed: false,
    unresolved_ingredient_holds:
      BDNA_SHOP_0002_CUREL_INGREDIENT_HOLDS,
    payloads: products.map((product) =>
      buildBdnaShop0002DryRunPayload(product)
    ),
  };
}

export function isCanonicalShopifyGid(
  value: unknown,
  resource: "Product" | "ProductVariant",
): boolean {
  const candidate = clean(value);

  const pattern = resource === "Product"
    ? /^gid:\/\/shopify\/Product\/[1-9][0-9]*$/
    : /^gid:\/\/shopify\/ProductVariant\/[1-9][0-9]*$/;

  return pattern.test(candidate);
}

export function validateReturnedShopifyLinkage(
  returned: ReturnedShopifyLinkage,
): string[] {
  const blockers: string[] = [];

  if (!isCanonicalShopifyGid(returned.shopify_product_id, "Product")) {
    blockers.push("invalid_shopify_product_id");
  }

  if (!isCanonicalShopifyGid(returned.shopify_variant_id, "ProductVariant")) {
    blockers.push("invalid_shopify_variant_id");
  }

  return blockers.sort();
}

export function planShopifyLinkage(
  existing: ExistingShopifyLinkage,
  returned: ReturnedShopifyLinkage,
  occupied: LinkageOwner[] = [],
): ShopifyLinkagePlan {
  const blockers = validateReturnedShopifyLinkage(returned);

  const beautyProductId = clean(existing.beauty_product_id);

  if (!beautyProductId) {
    blockers.push("missing_beauty_product_id");
  }

  if (blockers.length > 0) {
    return {
      contract_version: LINKAGE_PLAN_VERSION,
      action: "invalid",
      beauty_product_id: beautyProductId,
      blockers: blockers.sort(),
      patch: null,
    };
  }

  const currentProductId = clean(existing.shopify_product_id);
  const currentVariantId = clean(existing.shopify_variant_id);
  const returnedProductId = clean(returned.shopify_product_id);
  const returnedVariantId = clean(returned.shopify_variant_id);

  if (currentProductId && currentProductId !== returnedProductId) {
    blockers.push("existing_shopify_product_id_conflict");
  }

  if (currentVariantId && currentVariantId !== returnedVariantId) {
    blockers.push("existing_shopify_variant_id_conflict");
  }

  for (const owner of occupied) {
    const ownerBeautyProductId = clean(owner.beauty_product_id);

    if (ownerBeautyProductId === beautyProductId) {
      continue;
    }

    if (clean(owner.shopify_product_id) === returnedProductId) {
      blockers.push(`shopify_product_id_owned_by:${ownerBeautyProductId}`);
    }

    if (clean(owner.shopify_variant_id) === returnedVariantId) {
      blockers.push(`shopify_variant_id_owned_by:${ownerBeautyProductId}`);
    }
  }

  if (blockers.length > 0) {
    return {
      contract_version: LINKAGE_PLAN_VERSION,
      action: "conflict",
      beauty_product_id: beautyProductId,
      blockers: blockers.sort(),
      patch: null,
    };
  }

  if (
    currentProductId === returnedProductId &&
    currentVariantId === returnedVariantId &&
    clean(existing.shopify_status) === "linked"
  ) {
    return {
      contract_version: LINKAGE_PLAN_VERSION,
      action: "noop",
      beauty_product_id: beautyProductId,
      blockers: [],
      patch: null,
    };
  }

  return {
    contract_version: LINKAGE_PLAN_VERSION,
    action: "apply",
    beauty_product_id: beautyProductId,
    blockers: [],
    patch: {
      shopify_product_id: returnedProductId,
      shopify_variant_id: returnedVariantId,
      shopify_status: "linked",
    },
  };
}