import launchFixture from "./fixtures/launch-products.v1.json" with {
  type: "json",
};

import {
  type BeautyDnaCatalogSource,
  buildBdnaShop0002DryRunManifest,
  buildBdnaShop0002DryRunPayload,
  buildOfflineCatalogIntent,
  planShopifyLinkage,
  validateOfflineFixtureCatalog,
  validateReturnedShopifyLinkage,
} from "./adapter.ts";

function assert(
  condition: unknown,
  message: string,
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);

  if (actualJson !== expectedJson) {
    throw new Error(
      `${message}
expected=${expectedJson}
actual=${actualJson}`,
    );
  }
}

const products = launchFixture.products as BeautyDnaCatalogSource[];

Deno.test(
  "canonical launch fixture contains exactly five unique unlinked products",
  () => {
    assert(
      products.length === 5,
      "fixture must contain exactly five launch products",
    );

    assert(
      launchFixture.offline_only === true,
      "fixture must be offline-only",
    );

    assert(
      launchFixture.contains_production_shopify_ids === false,
      "fixture must not claim production Shopify IDs",
    );

    assertEquals(
      validateOfflineFixtureCatalog(products),
      [],
      "fixture catalog validation should pass",
    );
  },
);

Deno.test(
  "all five intents are deterministic and fail closed on zero price",
  () => {
    for (const product of products) {
      const first = buildOfflineCatalogIntent(product);
      const second = buildOfflineCatalogIntent(product);

      assertEquals(
        first,
        second,
        `${product.source_key}: intent must be deterministic`,
      );

      assert(
        first.offline_only === true,
        `${product.source_key}: intent must remain offline-only`,
      );

      assert(
        first.ready_for_live_create === false,
        `${product.source_key}: canonical zero price cannot be live-ready`,
      );

      assertEquals(
        first.blockers,
        ["price_must_be_positive"],
        `${product.source_key}: expected price blocker`,
      );

      assert(
        first.linkage.shopify_product_id === null,
        `${product.source_key}: product ID must remain null`,
      );

      assert(
        first.linkage.shopify_variant_id === null,
        `${product.source_key}: variant ID must remain null`,
      );
    }
  },
);

Deno.test(
  "BDNA-SHOP-0002 dry-run manifest preserves governance boundaries",
  () => {
    const manifest = buildBdnaShop0002DryRunManifest(products);

    assert(
      manifest.build_id === "BDNA-SHOP-0002",
      "manifest must use the governed SHOP-0002 build ID",
    );

    assert(
      manifest.build_title ===
        "BDNA-SHOP-0002 Hanna Launch Catalog Shopify Creation and Canonical Linkage",
      "manifest must use the governed SHOP-0002 title",
    );

    assert(
      manifest.canonical_launch_product_count === 5,
      "manifest must cover exactly five launch products",
    );

    assert(
      manifest.dry_run_payload_count === 5,
      "manifest must produce exactly five dry-run payloads",
    );

    assert(
      manifest.offline_only === true,
      "manifest must remain offline-only",
    );

    assert(
      manifest.live_shopify_write_authorized === false,
      "live Shopify writes must remain unauthorized",
    );

    assert(
      manifest.beauty_database_writes === 0,
      "manifest must not represent Beauty database writes",
    );

    assert(
      manifest.shopify_writes === 0,
      "manifest must not represent Shopify writes",
    );

    assert(
      manifest.ingredient_ready_count === 4,
      "manifest must not claim complete ingredient coverage",
    );

    assert(
      manifest.complete_ingredient_coverage_claimed === false,
      "manifest must explicitly avoid complete ingredient coverage claim",
    );

    assertEquals(
      manifest.unresolved_ingredient_holds,
      [
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
      ],
      "three Curél ingredient holds must remain unchanged",
    );
  },
);

Deno.test(
  "BDNA-SHOP-0002 creates exactly five offline dry-run Shopify payloads",
  () => {
    const payloads = products.map((product) =>
      buildBdnaShop0002DryRunPayload(product)
    );

    assert(
      payloads.length === 5,
      "must create exactly five dry-run payloads",
    );

    assertEquals(
      payloads.map((payload) => payload.beautydna_selector.source_key),
      products.map((product) => product.source_key),
      "payload order must match canonical launch manifest order",
    );

    assertEquals(
      payloads.map((payload) => payload.idempotency_key),
      products.map((product) =>
        `BDNA-SHOP-0002:beautydna:${product.source_key}:${product.sku}`
      ),
      "payload idempotency keys must be deterministic",
    );

    for (const payload of payloads) {
      assert(
        payload.offline_only === true,
        "payload must remain offline-only",
      );

      assert(
        payload.live_shopify_write_authorized === false,
        "payload must preserve false live Shopify authorization",
      );

      assert(
        payload.may_perform_live_shopify_write === false,
        "payload must never authorize direct Shopify mutation",
      );

      assert(
        payload.mutation_name === "productCreate",
        "payload should model Shopify productCreate only as a dry run",
      );

      assert(
        payload.linkage.shopify_product_id === null,
        "dry-run payload must not include a product ID",
      );

      assert(
        payload.linkage.shopify_variant_id === null,
        "dry-run payload must not include a variant ID",
      );

      assert(
        payload.execution.ready_for_live_create === false,
        "payload cannot be live-ready without live Shopify authorization",
      );

      assertEquals(
        payload.execution.blocked_reasons,
        [
          "live_shopify_write_not_authorized",
          "price_must_be_positive",
        ],
        "payload must fail closed on authorization and price blockers",
      );
    }
  },
);

Deno.test(
  "fixture and placeholder Shopify IDs are rejected",
  () => {
    assertEquals(
      validateReturnedShopifyLinkage({
        shopify_product_id: "fixture://shopify/Product/100",
        shopify_variant_id: "gid://shopify/ProductVariant/0",
      }),
      [
        "invalid_shopify_product_id",
        "invalid_shopify_variant_id",
      ],
      "noncanonical IDs must fail closed",
    );
  },
);

Deno.test(
  "structurally valid returned Shopify GIDs produce only a linkage patch",
  () => {
    const plan = planShopifyLinkage(
      {
        beauty_product_id: "test-beauty-product-a",
        shopify_product_id: null,
        shopify_variant_id: null,
        shopify_status: "needs_shopify_creation",
      },
      {
        shopify_product_id: "gid://shopify/Product/1001",
        shopify_variant_id: "gid://shopify/ProductVariant/2001",
      },
    );

    assert(
      plan.action === "apply",
      "valid unoccupied linkage should be applicable",
    );

    assert(
      plan.patch !== null,
      "apply action must produce a linkage patch",
    );

    assert(
      plan.patch?.shopify_status === "linked",
      "linkage status must transition to linked",
    );

    assert(
      !("recommendation_ready" in (plan.patch ?? {})),
      "adapter must not mutate recommendation readiness",
    );
  },
);

Deno.test(
  "repeating identical verified linkage is idempotent",
  () => {
    const plan = planShopifyLinkage(
      {
        beauty_product_id: "test-beauty-product-a",
        shopify_product_id: "gid://shopify/Product/1001",
        shopify_variant_id: "gid://shopify/ProductVariant/2001",
        shopify_status: "linked",
      },
      {
        shopify_product_id: "gid://shopify/Product/1001",
        shopify_variant_id: "gid://shopify/ProductVariant/2001",
      },
    );

    assert(
      plan.action === "noop",
      "same verified linkage must be a no-op",
    );

    assert(
      plan.patch === null,
      "idempotent no-op must not write",
    );
  },
);

Deno.test(
  "different existing linkage fails closed",
  () => {
    const plan = planShopifyLinkage(
      {
        beauty_product_id: "test-beauty-product-a",
        shopify_product_id: "gid://shopify/Product/9999",
        shopify_variant_id: null,
        shopify_status: "needs_shopify_creation",
      },
      {
        shopify_product_id: "gid://shopify/Product/1001",
        shopify_variant_id: "gid://shopify/ProductVariant/2001",
      },
    );

    assert(
      plan.action === "conflict",
      "existing different linkage must conflict",
    );

    assert(
      plan.patch === null,
      "conflict must not produce a patch",
    );
  },
);

Deno.test(
  "Shopify IDs already owned by another BeautyDNA product fail closed",
  () => {
    const plan = planShopifyLinkage(
      {
        beauty_product_id: "test-beauty-product-a",
        shopify_product_id: null,
        shopify_variant_id: null,
        shopify_status: "needs_shopify_creation",
      },
      {
        shopify_product_id: "gid://shopify/Product/1001",
        shopify_variant_id: "gid://shopify/ProductVariant/2001",
      },
      [
        {
          beauty_product_id: "test-beauty-product-b",
          shopify_product_id: "gid://shopify/Product/1001",
          shopify_variant_id: null,
        },
      ],
    );

    assert(
      plan.action === "conflict",
      "duplicate ownership must fail closed",
    );

    assert(
      plan.patch === null,
      "duplicate ownership must not produce a patch",
    );
  },
);
