import {
  createSkinDnaRecommendationProfile,
  executeSkinDnaMvp,
  normalizeSkinDnaMvpQuestionnaire,
  SKIN_DNA_ADAPTER,
  SKIN_DNA_ADAPTER_ID,
  SKIN_DNA_ADAPTER_KEY,
  SKIN_DNA_ADAPTER_VERSION,
  SKIN_DNA_MVP_CONFIG_VERSION,
  SKIN_DNA_MVP_CONTRACT_VERSION,
  SKIN_DNA_MVP_QUESTIONNAIRE_VERSION,
  type SkinDnaExecutionRequest,
} from "./adapter.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${message}\nExpected: ${e}\nActual: ${a}`);
}

function assertIncludes(
  value: unknown,
  fragment: string,
  message: string,
): void {
  const s = JSON.stringify(value);
  assert(
    s.includes(fragment),
    `${message}\nMissing: ${fragment}\nOutput: ${s}`,
  );
}

function assertThrows(fn: () => unknown, fragment: string): void {
  let threw = false;
  try {
    fn();
  } catch (error) {
    threw = true;
    const message = error instanceof Error ? error.message : String(error);
    assert(
      message.includes(fragment),
      `Expected "${fragment}", got "${message}".`,
    );
  }
  assert(threw, "Expected function to throw.");
}

function questionnaire(): Record<string, unknown> {
  return {
    oiliness: "moderate",
    dryness: "low",
    sensitivity: "low",
    concerns: ["Dullness", "Uneven Tone"],
    concern_priorities: ["dullness"],
    acne_prone: false,
    avoid_ingredients: [],
    pregnancy: false,
    preferred_steps: ["Cleanser", "Moisturizer", "SPF"],
    routine_complexity: "standard",
    active_allergy_reaction: false,
    red_flag_present: false,
  };
}

function request(): SkinDnaExecutionRequest {
  return {
    contract_version: SKIN_DNA_MVP_CONTRACT_VERSION,
    assessment: {
      assessment_id: "bdna-skin-test-001",
      answers: questionnaire(),
      context: { channel: "hanna-dna-mvp" },
    },
  };
}

Deno.test("SkinDNA production identity is stable", () => {
  assertEquals(
    SKIN_DNA_MVP_CONTRACT_VERSION,
    "beautydna-skin-dna-mvp-contract-v1",
    "contract",
  );
  assertEquals(SKIN_DNA_ADAPTER_KEY, "skin-dna", "adapter key");
  assertEquals(SKIN_DNA_ADAPTER_VERSION, "v1", "adapter version");
  assertEquals(SKIN_DNA_ADAPTER_ID, "skin-dna@v1", "adapter id");
  assertEquals(
    SKIN_DNA_MVP_CONFIG_VERSION,
    "beautydna-skin-dna-mvp-config-v1",
    "config",
  );
  assertEquals(
    SKIN_DNA_MVP_QUESTIONNAIRE_VERSION,
    "beautydna-skin-dna-mvp-questionnaire-v1",
    "questionnaire",
  );
});

Deno.test("SkinDNA questionnaire normalization is deterministic", () => {
  const input = questionnaire();
  assertEquals(
    normalizeSkinDnaMvpQuestionnaire(input),
    normalizeSkinDnaMvpQuestionnaire(input),
    "identical questionnaire must normalize identically",
  );
});

Deno.test("SkinDNA executes deterministically through shared DNA Engine", () => {
  const first = executeSkinDnaMvp(request());
  const second = executeSkinDnaMvp(request());
  assertEquals(first, second, "engine execution must be deterministic");
  assertIncludes(first, "skin-dna", "SkinDNA provenance required");
  assertIncludes(first, "confidence", "confidence required");
  assertIncludes(first, "provenance", "provenance required");
});

Deno.test("SkinDNA emits exactly seven downstream recommendation fields", () => {
  const bridge = normalizeSkinDnaMvpQuestionnaire(questionnaire());
  assertEquals(
    Object.keys(bridge.recommendation_profile).sort(),
    [
      "acne_prone",
      "avoid_ingredients",
      "preferred_steps",
      "pregnancy",
      "sensitivity_level",
      "skin_concerns",
      "skin_type",
    ],
    "seven-field profile contract",
  );
  assertEquals(bridge.recommendation_profile.skin_type, "oily", "skin type");
  assertEquals(
    bridge.recommendation_profile.skin_concerns,
    ["dullness", "oiliness", "uneven_tone"],
    "canonical concerns",
  );
});

Deno.test("oiliness and dryness resolve the four MVP skin types", () => {
  const cases = [
    ["low", "low", "normal"],
    ["low", "moderate", "dry"],
    ["high", "low", "oily"],
    ["moderate", "moderate", "combination"],
  ];
  for (const [oiliness, dryness, expected] of cases) {
    const input = questionnaire();
    input.oiliness = oiliness;
    input.dryness = dryness;
    const result = normalizeSkinDnaMvpQuestionnaire(input);
    assertEquals(
      result.recommendation_profile.skin_type,
      expected,
      "skin-type balance",
    );
  }
});

Deno.test("moderate sensitivity becomes downstream sensitive with caution", () => {
  const input = questionnaire();
  input.sensitivity = "moderate";
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(
    result.recommendation_profile.sensitivity_level,
    "sensitive",
    "sensitivity mapping",
  );
  assertEquals(
    result.safety.classification,
    "caution",
    "caution classification",
  );
  assertEquals(
    result.safety.recommendation_status,
    "ready_with_cautions",
    "recommendation status",
  );
  assertIncludes(result, "skin-dna-caution-sensitivity", "sensitivity reason");
});

Deno.test("acne tendency maps to profile and engine concern", () => {
  const input = questionnaire();
  input.acne_prone = true;
  const bridge = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(bridge.recommendation_profile.acne_prone, true, "acne_prone");
  assert(
    bridge.recommendation_profile.skin_concerns.includes("acne"),
    "acne concern required",
  );

  const engineRequest = request();
  engineRequest.assessment.answers.acne_prone = true;
  assertIncludes(
    executeSkinDnaMvp(engineRequest),
    "skin-dna-acne-tendency",
    "engine acne concern",
  );
});

Deno.test("concern aliases and priorities normalize deterministically", () => {
  const input = questionnaire();
  input.concerns = [
    "Dark Spots",
    "hyperpigmentation",
    "Blackheads",
    "clogged pores",
  ];
  input.concern_priorities = ["dark spots", "blackheads"];
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(result.concern_priorities, [
    "hyperpigmentation",
    "clogged_pores",
  ], "priority normalization");
  assertEquals(
    result.recommendation_profile.skin_concerns,
    ["clogged_pores", "hyperpigmentation", "oiliness"],
    "concern normalization",
  );
});

Deno.test("avoid ingredients normalize and produce caution context", () => {
  const input = questionnaire();
  input.avoid_ingredients = [" Fragrance ", "alcohol denat.", "fragrance"];
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(result.recommendation_profile.avoid_ingredients, [
    "alcohol denat.",
    "fragrance",
  ], "avoid list");
  assertEquals(result.safety.classification, "caution", "avoid list caution");
  assertIncludes(
    result,
    "skin-dna-caution-customer-declared-avoid-list",
    "avoid-list reason",
  );
});

Deno.test("pregnancy is customer-declared caution context only", () => {
  const input = questionnaire();
  input.pregnancy = true;
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(
    result.recommendation_profile.pregnancy,
    true,
    "pregnancy profile",
  );
  assertEquals(result.safety.classification, "caution", "pregnancy caution");
  assertEquals(
    result.safety.pregnancy_semantics,
    "customer_declared_caution_context_only",
    "pregnancy semantics",
  );
  assertEquals(
    createSkinDnaRecommendationProfile(input).pregnancy,
    true,
    "pregnancy remains bridgeable",
  );
});

Deno.test("preferred routine steps normalize without invention", () => {
  const input = questionnaire();
  input.preferred_steps = [
    "Oil Cleanser",
    "Moisturizer",
    "oil-cleanser",
    "SPF",
  ];
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(
    result.recommendation_profile.preferred_steps,
    ["oil_cleanser", "moisturizer", "spf"],
    "preferred step normalization",
  );
});

Deno.test("severe sensitivity enters referral and blocks profile creation", () => {
  const input = questionnaire();
  input.sensitivity = "severe";
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(result.safety.classification, "referral", "severe referral");
  assertEquals(
    result.safety.recommendation_status,
    "blocked",
    "severe blocked",
  );
  assertIncludes(
    result,
    "skin-dna-referral-severe-reactivity",
    "severe reason",
  );
  assertThrows(() => createSkinDnaRecommendationProfile(input), "blocked");
});

Deno.test("active allergy reaction enters referral and blocks profile creation", () => {
  const input = questionnaire();
  input.active_allergy_reaction = true;
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(result.safety.classification, "referral", "allergy referral");
  assertIncludes(
    result,
    "skin-dna-referral-active-allergy-reaction",
    "allergy reason",
  );
  assertThrows(() => createSkinDnaRecommendationProfile(input), "blocked");
});

Deno.test("explicit red flag enters referral and reaches engine safety concern", () => {
  const input = questionnaire();
  input.red_flag_present = true;
  const result = normalizeSkinDnaMvpQuestionnaire(input);
  assertEquals(result.safety.classification, "referral", "red flag referral");
  assertIncludes(result, "skin-dna-referral-red-flag", "red flag reason");

  const engineRequest = request();
  engineRequest.assessment.answers.red_flag_present = true;
  assertIncludes(
    executeSkinDnaMvp(engineRequest),
    "skin-dna-safety-referral",
    "engine referral concern",
  );
});

Deno.test("unsupported SkinDNA contract version fails closed", () => {
  const input = request();
  input.contract_version = "beautydna-skin-dna-mvp-contract-v999";
  assertThrows(
    () => executeSkinDnaMvp(input),
    "Unsupported SkinDNA MVP contract version",
  );
});

Deno.test("unsupported concern and undeclared priority fail closed", () => {
  const badConcern = questionnaire();
  badConcern.concerns = ["medical-diagnosis-request"];
  badConcern.concern_priorities = [];
  assertThrows(
    () => normalizeSkinDnaMvpQuestionnaire(badConcern),
    "unsupported SkinDNA MVP concern",
  );

  const badPriority = questionnaire();
  badPriority.concern_priorities = ["acne"];
  assertThrows(
    () => normalizeSkinDnaMvpQuestionnaire(badPriority),
    "must also be present in concerns",
  );
});

Deno.test("malformed categorical and safety inputs fail closed", () => {
  const badEnum = questionnaire();
  badEnum.oiliness = "extremely-oily";
  assertThrows(
    () => normalizeSkinDnaMvpQuestionnaire(badEnum),
    "oiliness must be one of",
  );

  const badBoolean = questionnaire();
  badBoolean.red_flag_present = "no";
  assertThrows(
    () => normalizeSkinDnaMvpQuestionnaire(badBoolean),
    "red_flag_present must be boolean",
  );
});

Deno.test("SkinDNA adapter preserves provenance and bridge profile attributes", () => {
  const normalized = SKIN_DNA_ADAPTER.normalize(request().assessment);
  const attributes = normalized.profile_attributes as Record<string, unknown>;
  assertEquals(
    attributes.skin_dna_contract_version,
    SKIN_DNA_MVP_CONTRACT_VERSION,
    "contract provenance",
  );
  assertIncludes(
    attributes,
    "recommendation_profile",
    "bridge profile required",
  );
  assertIncludes(
    normalized.provenance,
    "cosmetic_non_diagnostic",
    "non-diagnostic boundary required",
  );
  assertIncludes(
    normalized.provenance,
    "reuse_generic_assessment_answer_passport",
    "persistence reuse provenance required",
  );
});
