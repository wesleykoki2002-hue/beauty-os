import {
  executeHairDna,
  HAIR_DNA_ADAPTER,
  HAIR_DNA_ADAPTER_ID,
  HAIR_DNA_ADAPTER_KEY,
  HAIR_DNA_ADAPTER_VERSION,
  HAIR_DNA_CONFIG_VERSION,
  HAIR_DNA_CONTRACT_VERSION,
  type HairDnaExecutionRequest,
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
      `${message}\nExpected: ${expectedJson}\nActual: ${actualJson}`,
    );
  }
}

function assertIncludes(
  value: unknown,
  fragment: string,
  message: string,
): void {
  const serialized = JSON.stringify(value);

  assert(
    serialized.includes(fragment),
    `${message}\nMissing: ${fragment}\nOutput: ${serialized}`,
  );
}

function assertNotIncludes(
  value: unknown,
  fragment: string,
  message: string,
): void {
  const serialized = JSON.stringify(value);

  assert(
    !serialized.includes(fragment),
    `${message}\nForbidden fragment: ${fragment}`,
  );
}

function assertThrows(
  fn: () => unknown,
  expectedFragment: string,
): void {
  let threw = false;

  try {
    fn();
  } catch (error) {
    threw = true;

    const message = error instanceof Error ? error.message : String(error);

    assert(
      message.includes(expectedFragment),
      `Expected error containing "${expectedFragment}", got "${message}".`,
    );
  }

  assert(
    threw,
    "Expected function to throw.",
  );
}

function asRecord(
  value: unknown,
  label: string,
): Record<string, unknown> {
  assert(
    typeof value === "object" &&
      value !== null &&
      !Array.isArray(value),
    `${label} must be an object.`,
  );

  return value as Record<string, unknown>;
}

function baseRequest(): HairDnaExecutionRequest {
  return {
    contract_version: HAIR_DNA_CONTRACT_VERSION,

    assessment: {
      assessment_id: "bdna-hair-test-001",

      answers: {
        scalp_oiliness: "moderate",

        scalp_dryness: "low",

        scalp_sensitivity: "low",

        flaking: "none",

        hair_pattern: "wavy",

        strand_thickness: "medium",

        density: "medium",

        porosity: "medium",

        damage: "low",

        heat_exposure: "low",

        chemical_treatments: [],

        breakage: "low",

        frizz: "moderate",

        buildup: "low",

        wash_frequency_per_week: 4,

        water_hardness: "unknown",

        concerns: ["frizz"],

        priorities: ["frizz"],

        scalp_irritation_concern: false,

        shedding_concern: false,

        red_flag_present: false,
      },

      context: {
        climate: "humid",
      },
    },
  };
}

Deno.test(
  "HairDNA production identity is stable",
  () => {
    assertEquals(
      HAIR_DNA_CONTRACT_VERSION,
      "beautydna-hair-dna-contract-v1",
      "Unexpected HairDNA contract version.",
    );

    assertEquals(
      HAIR_DNA_ADAPTER_KEY,
      "hair-dna",
      "Unexpected HairDNA adapter key.",
    );

    assertEquals(
      HAIR_DNA_ADAPTER_VERSION,
      "v1",
      "Unexpected HairDNA adapter version.",
    );

    assertEquals(
      HAIR_DNA_ADAPTER_ID,
      "hair-dna@v1",
      "Unexpected HairDNA adapter identity.",
    );

    assertEquals(
      HAIR_DNA_CONFIG_VERSION,
      "beautydna-hair-dna-config-v1",
      "Unexpected HairDNA config version.",
    );
  },
);

Deno.test(
  "HairDNA normalization is deterministic",
  () => {
    const request = baseRequest();

    const first = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    const second = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    assertEquals(
      first,
      second,
      "Identical assessment input must normalize identically.",
    );
  },
);

Deno.test(
  "HairDNA executes deterministically through shared DNA Engine",
  () => {
    const first = executeHairDna(
      baseRequest(),
    );

    const second = executeHairDna(
      baseRequest(),
    );

    assertEquals(
      first,
      second,
      "Identical HairDNA engine requests must return identical results.",
    );

    assertIncludes(
      first,
      "hair-dna",
      "Engine output must retain HairDNA adapter/domain provenance.",
    );

    assertIncludes(
      first,
      "confidence",
      "Engine output must expose generic confidence.",
    );

    assertIncludes(
      first,
      "provenance",
      "Engine output must expose provenance.",
    );
  },
);

Deno.test(
  "HairDNA preserves structured domain attributes",
  () => {
    const normalized = HAIR_DNA_ADAPTER.normalize(
      baseRequest().assessment,
    );

    const attributes = asRecord(
      normalized.profile_attributes,
      "profile_attributes",
    );

    assertEquals(
      attributes.hair_dna_contract_version,
      HAIR_DNA_CONTRACT_VERSION,
      "Profile contract provenance is required.",
    );

    assertEquals(
      attributes.adapter_id,
      HAIR_DNA_ADAPTER_ID,
      "Profile adapter identity is required.",
    );

    const scalpState = asRecord(
      attributes.scalp_state,
      "scalp_state",
    );

    assertEquals(
      scalpState.oiliness,
      "moderate",
      "Scalp oiliness must be preserved.",
    );

    const hairFiber = asRecord(
      attributes.hair_fiber,
      "hair_fiber",
    );

    assertEquals(
      hairFiber.pattern,
      "wavy",
      "Hair pattern must be preserved.",
    );

    assertEquals(
      hairFiber.porosity,
      "medium",
      "Porosity must be preserved.",
    );
  },
);

Deno.test(
  "representative oily scalp profile executes",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .scalp_oiliness = "high";

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-oily-scalp",
      "High oiliness must trigger the governed oily-scalp concern.",
    );
  },
);

Deno.test(
  "representative dry sensitive scalp profile executes conservatively",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .scalp_dryness = "high";

    request.assessment.answers
      .scalp_sensitivity = "moderate";

    const normalized = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    const attributes = asRecord(
      normalized.profile_attributes,
      "profile_attributes",
    );

    const safety = asRecord(
      attributes.safety,
      "safety",
    );

    assertEquals(
      safety.classification,
      "caution",
      "Moderate scalp sensitivity must enter caution handling.",
    );

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-dry-scalp",
      "Dry scalp concern must execute through the engine.",
    );

    assertIncludes(
      result,
      "hair-dna-sensitive-scalp",
      "Sensitive-scalp concern must execute through the engine.",
    );
  },
);

Deno.test(
  "representative damage and breakage profile executes",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .damage = "high";

    request.assessment.answers
      .breakage = "high";

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-damage",
      "Damage concern must execute.",
    );

    assertIncludes(
      result,
      "hair-dna-breakage",
      "Breakage concern must execute.",
    );
  },
);

Deno.test(
  "representative porosity and frizz profile executes",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .porosity = "high";

    request.assessment.answers
      .frizz = "high";

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-high-porosity",
      "High porosity state must execute.",
    );

    assertIncludes(
      result,
      "hair-dna-frizz",
      "Frizz concern must execute.",
    );
  },
);

Deno.test(
  "representative buildup and hard-water profile executes",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .buildup = "high";

    request.assessment.answers
      .water_hardness = "hard";

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-buildup",
      "Buildup concern must execute.",
    );

    assertIncludes(
      result,
      "hair-dna-hard-water-context",
      "Hard-water context must execute.",
    );
  },
);

Deno.test(
  "severe scalp state fails safely into referral handling",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .scalp_sensitivity = "severe";

    const normalized = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    const attributes = asRecord(
      normalized.profile_attributes,
      "profile_attributes",
    );

    const safety = asRecord(
      attributes.safety,
      "safety",
    );

    assertEquals(
      safety.classification,
      "referral",
      "Severe scalp state must become referral handling.",
    );

    const result = executeHairDna(request);

    assertIncludes(
      result,
      "hair-dna-referral-severe-scalp-state",
      "Severe scalp state must produce referral evidence.",
    );

    assertNotIncludes(
      result,
      '"diagnosis"',
      "HairDNA must not output a diagnosis.",
    );
  },
);

Deno.test(
  "shedding concern resolves to non-diagnostic referral handling",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .shedding_concern = true;

    const normalized = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    const attributes = asRecord(
      normalized.profile_attributes,
      "profile_attributes",
    );

    const safety = asRecord(
      attributes.safety,
      "safety",
    );

    assertEquals(
      safety.classification,
      "referral",
      "Shedding concern must resolve conservatively.",
    );

    assertIncludes(
      executeHairDna(request),
      "hair-dna-referral-shedding",
      "Shedding referral evidence must execute.",
    );
  },
);

Deno.test(
  "explicit red flag resolves to referral handling",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .red_flag_present = true;

    const normalized = HAIR_DNA_ADAPTER.normalize(
      request.assessment,
    );

    const attributes = asRecord(
      normalized.profile_attributes,
      "profile_attributes",
    );

    const safety = asRecord(
      attributes.safety,
      "safety",
    );

    assertEquals(
      safety.classification,
      "referral",
      "Red flag must resolve to referral handling.",
    );

    assertIncludes(
      executeHairDna(request),
      "hair-dna-referral-red-flag",
      "Red-flag referral evidence must execute.",
    );
  },
);

Deno.test(
  "unknown water hardness does not fabricate hard-water signal",
  () => {
    const normalized = HAIR_DNA_ADAPTER.normalize(
      baseRequest().assessment,
    );

    assertEquals(
      normalized.signals
        .hard_water_context,
      0,
      "Unknown water hardness must not be treated as hard.",
    );
  },
);

Deno.test(
  "unsupported HairDNA contract version fails closed",
  () => {
    const request = baseRequest();

    request.contract_version = "beautydna-hair-dna-contract-v999";

    assertThrows(
      () => executeHairDna(request),
      "Unsupported HairDNA contract version",
    );
  },
);

Deno.test(
  "malformed categorical input fails closed",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .scalp_oiliness = "extreme";

    assertThrows(
      () => executeHairDna(request),
      "scalp_oiliness",
    );
  },
);

Deno.test(
  "malformed wash frequency fails closed",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .wash_frequency_per_week = 15;

    assertThrows(
      () => executeHairDna(request),
      "wash_frequency_per_week",
    );
  },
);

Deno.test(
  "malformed treatment vocabulary fails closed",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .chemical_treatments = [
        "unknown-treatment",
      ];

    assertThrows(
      () => executeHairDna(request),
      "chemical_treatments",
    );
  },
);

Deno.test(
  "malformed safety flag fails closed",
  () => {
    const request = baseRequest();

    request.assessment.answers
      .red_flag_present = "yes";

    assertThrows(
      () => executeHairDna(request),
      "red_flag_present",
    );
  },
);

Deno.test(
  "non-JSON environmental context fails closed",
  () => {
    const request = baseRequest();

    request.assessment.context = {
      invalid: () => "not-json",
    };

    assertThrows(
      () => executeHairDna(request),
      "assessment.context.invalid",
    );
  },
);
