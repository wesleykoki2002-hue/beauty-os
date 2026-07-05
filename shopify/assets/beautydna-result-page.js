(function () {
  const root = document.querySelector("[data-beautydna-result-page]");
  if (!root) return;

  const endpoint = root.getAttribute("data-endpoint");
  const debugMode = root.getAttribute("data-debug") === "true";

  const statusEl = root.querySelector("[data-beautydna-status]");
  const profileEl = root.querySelector("[data-beautydna-profile]");
  const routineEl = root.querySelector("[data-beautydna-routine]");
  const cartActionsEl = root.querySelector("[data-beautydna-cart-actions]");
  const addAllButton = root.querySelector("[data-beautydna-add-all]");

  const stepOrder = [
    "gentle_cleanser",
    "hydrating_lotion",
    "barrier_serum",
    "moisturizer",
    "sunscreen"
  ];

  const customerLabelTranslations = {
    dehydration: "desidratação",
    barrier_support: "barreira da pele",
    "barrier support": "barreira da pele",
    dryness: "ressecamento",
    hydration: "hidratação",
    "hydration support": "suporte de hidratação",
    "water-binding support": "retenção de água na pele",
    plumping: "efeito de preenchimento hidratante",
    "skin comfort": "conforto da pele",
    dry: "seca",
    oily: "oleosa",
    normal: "normal",
    combination: "mista",
    sensitive: "sensível",
    low: "baixo",
    medium: "médio",
    high: "alto",
    morning_evening: "manhã e noite",
    evening: "noite",
    morning: "manhã",
    generally_ok: "geralmente seguro",
    unknown: "não informado"
  };

  const ingredientDisplayNames = {
    "hyaluronic acid": "Ácido hialurônico",
    "sodium hyaluronate": "Hialuronato de sódio",
    "hydrolyzed hyaluronic acid": "Ácido hialurônico hidrolisado",
    "ceramide np": "Ceramida NP",
    "ceramide 3": "Ceramida 3",
    niacinamide: "Niacinamida",
    "vitamin b3": "Vitamina B3"
  };

  function translateCustomerLabel(value) {
    const raw = String(value == null ? "" : value);
    const direct = customerLabelTranslations[raw.toLowerCase()];
    return direct || raw;
  }

  function getIngredientDisplayName(ingredient) {
    if (!ingredient) return "";
    if (ingredient.display_name) return ingredient.display_name;
    if (ingredient.customer_ingredient_name) return ingredient.customer_ingredient_name;

    const rawName = String(ingredient.ingredient_name || "");
    const translated = ingredientDisplayNames[rawName.toLowerCase()];

    return translated ? `${translated} (${rawName})` : rawName;
  }

  const fallbackProfile = {
    skin_type: "dry",
    skin_concerns: ["dehydration", "barrier_support", "dryness"],
    sensitivity_level: "sensitive",
    acne_prone: false,
    pregnancy: false,
    avoid_ingredients: []
  };

  function setStatus(message, isError) {
    if (!statusEl) return;
    statusEl.hidden = false;
    statusEl.textContent = message;
    statusEl.style.color = isError ? "#b42318" : "#5d5d5d";
  }

  function hideStatus() {
    if (statusEl) statusEl.hidden = true;
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatMoney(price, currency) {
    if (typeof price !== "number") return "";
    try {
      return new Intl.NumberFormat("pt-BR", {
        style: "currency",
        currency: currency || "BRL"
      }).format(price);
    } catch {
      return `${price} ${currency || ""}`.trim();
    }
  }

  function readProfile() {
    const params = new URLSearchParams(window.location.search);

    const storedProfileRaw =
      localStorage.getItem("beautydna_profile") ||
      sessionStorage.getItem("beautydna_profile");

    if (storedProfileRaw) {
      try {
        return Object.assign({}, fallbackProfile, JSON.parse(storedProfileRaw));
      } catch {
        // Continue with query string or fallback profile.
      }
    }

    const concerns = params.get("concerns")
      ? params.get("concerns").split(",").map((item) => item.trim()).filter(Boolean)
      : fallbackProfile.skin_concerns;

    return {
      skin_type: params.get("skin_type") || fallbackProfile.skin_type,
      skin_concerns: concerns,
      sensitivity_level: params.get("sensitivity_level") || fallbackProfile.sensitivity_level,
      acne_prone: params.get("acne_prone") === "true",
      pregnancy: params.get("pregnancy") === "true",
      avoid_ingredients: params.get("avoid")
        ? params.get("avoid").split(",").map((item) => item.trim()).filter(Boolean)
        : []
    };
  }

  function renderProfile(profile) {
    if (!profileEl) return;

    const concerns = Array.isArray(profile.skin_concerns) ? profile.skin_concerns : [];

    profileEl.innerHTML = `
      <h2>Seu perfil BeautyDNA</h2>
      <p>Tipo de pele: <strong>${escapeHtml(translateCustomerLabel(profile.skin_type || "nao informado"))}</strong></p>
      <p>Sensibilidade: <strong>${escapeHtml(translateCustomerLabel(profile.sensitivity_level || "normal"))}</strong></p>
      <div class="beautydna-profile-tags">
        ${concerns.map((concern) => `<span class="beautydna-tag">${escapeHtml(translateCustomerLabel(concern))}</span>`).join("")}
      </div>
    `;

    profileEl.hidden = false;
  }

  function getRoutineItems(payload) {
    const routine = payload.routine || {};
    return stepOrder
      .filter((step) => routine[step])
      .map((step) => ({
        step,
        product: routine[step],
        explanation: payload.explanations && payload.explanations[step],
        highlights: payload.ingredient_highlights && payload.ingredient_highlights[step],
        cautions: payload.cautions && payload.cautions[step]
      }));
  }

  function renderProductCard(item) {
    const product = item.product || {};
    const explanation = item.explanation || {};
    const highlights = Array.isArray(item.highlights) ? item.highlights : [];
    const cautions = Array.isArray(item.cautions) ? item.cautions : [];

    const imageHtml = product.product_image_url
      ? `<img src="${escapeHtml(product.product_image_url)}" alt="${escapeHtml(product.product_title || "BeautyDNA product")}" loading="lazy">`
      : `<span>BeautyDNA</span>`;

    const variantId = product.shopify_variant_id;
    const canAddToCart = Boolean(variantId);

    return `
      <article class="beautydna-product-card" data-beautydna-product-card data-variant-id="${escapeHtml(variantId || "")}">
        <div class="beautydna-product-image">
          ${imageHtml}
        </div>

        <div class="beautydna-product-body">
          <div class="beautydna-step-label">${escapeHtml(explanation.step_label || product.product_role || item.step)}</div>

          <h3>${escapeHtml(product.product_title || "Produto BeautyDNA")}</h3>

          ${product.brand ? `<div class="beautydna-product-brand">${escapeHtml(product.brand)}</div>` : ""}

          ${product.price ? `<div class="beautydna-product-price">${escapeHtml(formatMoney(product.price, product.currency))}</div>` : ""}

          ${explanation.short_explanation ? `<p class="beautydna-explanation">${escapeHtml(explanation.short_explanation)}</p>` : ""}

          ${
            highlights.length
              ? `<div class="beautydna-ingredient-tags">
                  ${highlights.slice(0, 4).map((ingredient) => `<span class="beautydna-tag">${escapeHtml(getIngredientDisplayName(ingredient))}</span>`).join("")}
                </div>`
              : ""
          }

          ${
            cautions.length
              ? `<div class="beautydna-caution">${cautions.map(escapeHtml).join("<br>")}</div>`
              : ""
          }

          ${
            canAddToCart
              ? `<button type="button" class="beautydna-add-button" data-beautydna-add-one data-variant-id="${escapeHtml(variantId)}">Adicionar ao carrinho</button>`
              : `<div class="beautydna-unavailable">Produto ainda nao conectado ao carrinho Shopify.</div>`
          }
        </div>
      </article>
    `;
  }

  function renderRoutine(payload) {
    const items = getRoutineItems(payload);

    if (!routineEl) return;

    if (!items.length) {
      routineEl.innerHTML = "";
      setStatus("Ainda nao encontramos uma rotina disponivel para esse perfil.", true);
      return;
    }

    routineEl.innerHTML = items.map(renderProductCard).join("");
    routineEl.hidden = false;

    const hasVariant = items.some((item) => item.product && item.product.shopify_variant_id);
    if (cartActionsEl) cartActionsEl.hidden = !hasVariant;
  }

  async function addVariantToCart(variantId, quantity) {
    const response = await fetch("/cart/add.js", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        id: variantId,
        quantity: quantity || 1
      })
    });

    if (!response.ok) {
      throw new Error("Nao foi possivel adicionar ao carrinho.");
    }

    return response.json();
  }

  function bindCartActions() {
    root.addEventListener("click", async function (event) {
      const oneButton = event.target.closest("[data-beautydna-add-one]");
      if (oneButton) {
        const variantId = oneButton.getAttribute("data-variant-id");
        if (!variantId) return;

        oneButton.disabled = true;
        oneButton.textContent = "Adicionando...";

        try {
          await addVariantToCart(variantId, 1);
          oneButton.textContent = "Adicionado";
        } catch (error) {
          oneButton.disabled = false;
          oneButton.textContent = "Tentar novamente";
          setStatus(error.message || "Erro ao adicionar ao carrinho.", true);
        }
      }
    });

    if (addAllButton) {
      addAllButton.addEventListener("click", async function () {
        const buttons = Array.from(root.querySelectorAll("[data-beautydna-add-one]"));
        const variantIds = buttons
          .map((button) => button.getAttribute("data-variant-id"))
          .filter(Boolean);

        if (!variantIds.length) return;

        addAllButton.disabled = true;
        addAllButton.textContent = "Adicionando rotina...";

        try {
          for (const variantId of variantIds) {
            await addVariantToCart(variantId, 1);
          }

          addAllButton.textContent = "Rotina adicionada";
        } catch (error) {
          addAllButton.disabled = false;
          addAllButton.textContent = "Tentar novamente";
          setStatus(error.message || "Erro ao adicionar rotina.", true);
        }
      });
    }
  }

  async function loadResult() {
    if (!endpoint) {
      setStatus("Endpoint BeautyDNA nao configurado.", true);
      return;
    }

    const profile = readProfile();

    renderProfile(profile);
    setStatus("Gerando sua rotina BeautyDNA...");

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        profile,
        options: {
          routine_steps: ["hydrating_lotion", "barrier_serum"],
          max_products_per_step: 1,
          include_needs_review: debugMode,
          debug: debugMode
        }
      })
    });

    const payload = await response.json();

    if (!response.ok || !payload.ok) {
      throw new Error(payload.message || payload.error || "Erro ao gerar resultado BeautyDNA.");
    }

    renderProfile(payload.profile_display || profile);
    hideStatus();
    renderRoutine(payload);
  }

  bindCartActions();

  loadResult().catch(function (error) {
    setStatus(error.message || "Nao foi possivel carregar seu resultado BeautyDNA.", true);
  });
})();