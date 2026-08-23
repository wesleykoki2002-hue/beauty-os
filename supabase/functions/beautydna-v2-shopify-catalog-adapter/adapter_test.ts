import launchFixture from "./fixtures/launch-products.v1.json" with {
  type: "json",
};

import {
  type BeautyDnaCatalogSource,
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
      plan.patch?.shopify_status ===
        "linked",
      "linkage status must transition to linked",
    );

    assert(
      !(
        "recommendation_ready" in
          (plan.patch ?? {})
      ),
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
