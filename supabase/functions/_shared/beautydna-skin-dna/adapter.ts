import {
  createDnaAdapterRegistry,
  DNA_ENGINE_CONTRACT_VERSION,
  DNA_ENGINE_VERSION,
  type DnaAssessmentInput,
  type DnaDimensionConfig,
  type DnaDomainAdapter,
  type DnaEngineConfiguration,
  executeDnaEngine,
} from "../beautydna-dna-engine-core/engine.ts";

export const SKIN_DNA_MVP_CONTRACT_VERSION =
  "beautydna-skin-dna-mvp-contract-v1" as const;

export const SKIN_DNA_ADAPTER_KEY = "skin-dna" as const;

export const SKIN_DNA_ADAPTER_VERSION = "v1" as const;

export const SKIN_DNA_ADAPTER_ID = "skin-dna@v1" as const;

export const SKIN_DNA_DOMAIN_KEY = "skin-dna" as const;

export const SKIN_DNA_MVP_CONFIG_VERSION =
  "beautydna-skin-dna-mvp-config-v1" as const;

export const SKIN_DNA_MVP_QUESTIONNAIRE_VERSION =
  "beautydna-skin-dna-mvp-questionnaire-v1" as const;

export const SKIN_DNA_SEVERITY_LEVELS = [
  "none",
  "low",
  "moderate",
  "high",
  "severe",
] as const;

export type SkinDnaSeverity = (typeof SKIN_DNA_SEVERITY_LEVELS)[number];

export const SKIN_DNA_ROUTINE_COMPLEXITY = [
  "minimal",
  "standard",
  "extended",
] as const;

export type SkinDnaRoutineComplexity =
  (typeof SKIN_DNA_ROUTINE_COMPLEXITY)[number];

export const SKIN_DNA_SKIN_TYPES = [
  "normal",
  "dry",
  "oily",
  "combination",
] as const;

export type SkinDnaSkinType = (typeof SKIN_DNA_SKIN_TYPES)[number];

export const SKIN_DNA_SENSITIVITY_LEVELS = [
  "normal",
  "sensitive",
] as const;

export type SkinDnaSensitivityLevel =
  (typeof SKIN_DNA_SENSITIVITY_LEVELS)[number];

export const SKIN_DNA_CONCERN_KEYS = [
  "acne",
  "barrier_support",
  "clogged_pores",
  "dehydration",
  "dryness",
  "dullness",
  "fine_lines",
  "hyperpigmentation",
  "oiliness",
  "redness",
  "sensitivity",
  "texture",
  "uneven_tone",
] as const;

export type SkinDnaConcernKey = (typeof SKIN_DNA_CONCERN_KEYS)[number];

export const SKIN_DNA_SAFETY_CLASSIFICATIONS = [
  "standard",
  "caution",
  "referral",
] as const;

export type SkinDnaSafetyClassification =
  (typeof SKIN_DNA_SAFETY_CLASSIFICATIONS)[number];

export const SKIN_DNA_RECOMMENDATION_STATUSES = [
  "ready",
  "ready_with_cautions",
  "blocked",
] as const;

export type SkinDnaRecommendationStatus =
  (typeof SKIN_DNA_RECOMMENDATION_STATUSES)[number];

export interface SkinDnaMvpQuestionnaire {
  oiliness: SkinDnaSeverity;
  dryness: SkinDnaSeverity;
  sensitivity: SkinDnaSeverity;
  concerns: readonly string[];
  concern_priorities: readonly string[];
  acne_prone: boolean;
  avoid_ingredients: readonly string[];
  pregnancy: boolean;
  preferred_steps: readonly string[];
  routine_complexity: SkinDnaRoutineComplexity;
  active_allergy_reaction: boolean;
  red_flag_present: boolean;
}

export interface SkinDnaRecommendationProfile {
  skin_type: SkinDnaSkinType;
  skin_concerns: SkinDnaConcernKey[];
  sensitivity_level: SkinDnaSensitivityLevel;
  acne_prone: boolean;
  pregnancy: boolean;
  avoid_ingredients: string[];
  preferred_steps: string[];
}

export interface SkinDnaSafetyState {
  non_diagnostic: true;
  classification: SkinDnaSafetyClassification;
  recommendation_status: SkinDnaRecommendationStatus;
  reasons: string[];
  pregnancy_semantics: "customer_declared_caution_context_only";
}

export interface SkinDnaMvpBridgeResult {
  recommendation_profile: SkinDnaRecommendationProfile;
  concern_priorities: SkinDnaConcernKey[];
  routine_complexity: SkinDnaRoutineComplexity;
  safety: SkinDnaSafetyState;
  provenance: {
    contract_version: typeof SKIN_DNA_MVP_CONTRACT_VERSION;
    questionnaire_version: typeof SKIN_DNA_MVP_QUESTIONNAIRE_VERSION;
    adapter_id: typeof SKIN_DNA_ADAPTER_ID;
    config_version: typeof SKIN_DNA_MVP_CONFIG_VERSION;
    profile_bridge: "beautydna-v2-recommendation-profile-v1";
    confidence_source: "beautydna-dna-engine-core";
    medical_boundary: "cosmetic_non_diagnostic";
  };
}

export interface SkinDnaExecutionRequest {
  contract_version: string;
  assessment: DnaAssessmentInput;
}

const SEVERITY_SIGNAL: Record<
  SkinDnaSeverity,
  number
> = {
  none: 0,
  low: 0.25,
  moderate: 0.5,
  high: 0.75,
  severe: 1,
};

const CONCERN_ALIASES: Record<
  string,
  SkinDnaConcernKey
> = {
  "acne": "acne",
  "breakout": "acne",
  "breakouts": "acne",
  "barrier": "barrier_support",
  "barrier repair": "barrier_support",
  "barrier support": "barrier_support",
  "blackheads": "clogged_pores",
  "clogged pores": "clogged_pores",
  "congestion": "clogged_pores",
  "dehydration": "dehydration",
  "dryness": "dryness",
  "dullness": "dullness",
  "fine lines": "fine_lines",
  "fine line": "fine_lines",
  "hyperpigmentation": "hyperpigmentation",
  "pigmentation": "hyperpigmentation",
  "dark spots": "hyperpigmentation",
  "post inflammatory marks": "hyperpigmentation",
  "oil control": "oiliness",
  "oiliness": "oiliness",
  "redness": "redness",
  "sensitivity": "sensitivity",
  "texture": "texture",
  "uneven tone": "uneven_tone",
};

function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

function readEnum<T extends string>(
  value: unknown,
  key: string,
  allowed: readonly T[],
): T {
  if (
    typeof value !== "string" ||
    !allowed.includes(value as T)
  ) {
    throw new Error(
      `${key} must be one of: ${allowed.join(", ")}.`,
    );
  }

  return value as T;
}

function readBoolean(
  value: unknown,
  key: string,
): boolean {
  if (typeof value !== "boolean") {
    throw new Error(
      `${key} must be boolean.`,
    );
  }

  return value;
}

function normalizeHumanToken(
  value: string,
): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ");
}

function normalizeConcern(
  value: unknown,
  key: string,
): SkinDnaConcernKey {
  if (typeof value !== "string") {
    throw new Error(
      `${key} entries must be strings.`,
    );
  }

  const normalized = normalizeHumanToken(value);

  const concern = CONCERN_ALIASES[normalized];

  if (!concern) {
    throw new Error(
      `${key} contains unsupported SkinDNA MVP concern: ${value}.`,
    );
  }

  return concern;
}

function readConcernList(
  value: unknown,
  key: string,
  maximum: number,
): SkinDnaConcernKey[] {
  if (!Array.isArray(value)) {
    throw new Error(
      `${key} must be an array.`,
    );
  }

  if (value.length > maximum) {
    throw new Error(
      `${key} may contain at most ${maximum} entries.`,
    );
  }

  const result: SkinDnaConcernKey[] = [];

  for (const item of value) {
    const normalized = normalizeConcern(
      item,
      key,
    );

    if (!result.includes(normalized)) {
      result.push(normalized);
    }
  }

  return result;
}

function hasControlCharacter(
  value: string,
): boolean {
  for (const character of value) {
    const codePoint = character.codePointAt(0);

    if (
      codePoint !== undefined &&
      (codePoint <= 0x1f || codePoint === 0x7f)
    ) {
      return true;
    }
  }

  return false;
}
function normalizeIngredient(
  value: unknown,
  key: string,
): string {
  if (typeof value !== "string") {
    throw new Error(
      `${key} entries must be strings.`,
    );
  }

  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");

  if (
    normalized.length < 1 ||
    normalized.length > 80 ||
    hasControlCharacter(normalized)
  ) {
    throw new Error(
      `${key} contains an invalid ingredient declaration.`,
    );
  }

  return normalized;
}

function readIngredientList(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    throw new Error(
      "avoid_ingredients must be an array.",
    );
  }

  if (value.length > 32) {
    throw new Error(
      "avoid_ingredients may contain at most 32 entries.",
    );
  }

  return Array.from(
    new Set(
      value.map((item) =>
        normalizeIngredient(
          item,
          "avoid_ingredients",
        )
      ),
    ),
  ).sort();
}

function normalizeRoutineStep(
  value: unknown,
): string {
  if (typeof value !== "string") {
    throw new Error(
      "preferred_steps entries must be strings.",
    );
  }

  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_")
    .replace(/_+/g, "_");

  if (
    !/^[a-z0-9][a-z0-9_]{0,63}$/.test(
      normalized,
    )
  ) {
    throw new Error(
      `Unsupported preferred_steps token: ${value}.`,
    );
  }

  return normalized;
}

function readPreferredSteps(
  value: unknown,
): string[] {
  if (!Array.isArray(value)) {
    throw new Error(
      "preferred_steps must be an array.",
    );
  }

  if (value.length > 12) {
    throw new Error(
      "preferred_steps may contain at most 12 entries.",
    );
  }

  const result: string[] = [];

  for (const item of value) {
    const normalized = normalizeRoutineStep(item);

    if (!result.includes(normalized)) {
      result.push(normalized);
    }
  }

  return result;
}

function directDimension(
  key: string,
  signalKey: string,
): DnaDimensionConfig {
  return {
    key,
    min_score: 0,
    max_score: 100,
    base_score: 0,
    contributions: [
      {
        signal_key: signalKey,
        weight: 100,
      },
    ],
  };
}

function isModerateOrHigher(
  value: SkinDnaSeverity,
): boolean {
  return SEVERITY_SIGNAL[value] >= 0.5;
}

function deriveSkinType(
  oiliness: SkinDnaSeverity,
  dryness: SkinDnaSeverity,
): SkinDnaSkinType {
  const oily = isModerateOrHigher(oiliness);

  const dry = isModerateOrHigher(dryness);

  if (oily && dry) {
    return "combination";
  }

  if (oily) {
    return "oily";
  }

  if (dry) {
    return "dry";
  }

  return "normal";
}

function uniqueSortedConcerns(
  values: readonly SkinDnaConcernKey[],
): SkinDnaConcernKey[] {
  return Array.from(
    new Set(values),
  ).sort() as SkinDnaConcernKey[];
}

export function normalizeSkinDnaMvpQuestionnaire(
  input: unknown,
): SkinDnaMvpBridgeResult {
  if (!isRecord(input)) {
    throw new Error(
      "SkinDNA MVP questionnaire must be an object.",
    );
  }

  const oiliness = readEnum(
    input.oiliness,
    "oiliness",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const dryness = readEnum(
    input.dryness,
    "dryness",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const sensitivity = readEnum(
    input.sensitivity,
    "sensitivity",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const declaredConcerns = readConcernList(
    input.concerns,
    "concerns",
    5,
  );

  const concernPriorities = readConcernList(
    input.concern_priorities,
    "concern_priorities",
    3,
  );

  for (const priority of concernPriorities) {
    if (!declaredConcerns.includes(priority)) {
      throw new Error(
        "Every concern_priorities entry must also be present in concerns.",
      );
    }
  }

  const acneProne = readBoolean(
    input.acne_prone,
    "acne_prone",
  );

  const avoidIngredients = readIngredientList(
    input.avoid_ingredients,
  );

  const pregnancy = readBoolean(
    input.pregnancy,
    "pregnancy",
  );

  const preferredSteps = readPreferredSteps(
    input.preferred_steps,
  );

  const routineComplexity = readEnum(
    input.routine_complexity,
    "routine_complexity",
    SKIN_DNA_ROUTINE_COMPLEXITY,
  );

  const activeAllergyReaction = readBoolean(
    input.active_allergy_reaction,
    "active_allergy_reaction",
  );

  const redFlagPresent = readBoolean(
    input.red_flag_present,
    "red_flag_present",
  );

  const safetyReasons: string[] = [];

  let referral = false;

  if (redFlagPresent) {
    referral = true;
    safetyReasons.push(
      "skin-dna-referral-red-flag",
    );
  }

  if (activeAllergyReaction) {
    referral = true;
    safetyReasons.push(
      "skin-dna-referral-active-allergy-reaction",
    );
  }

  if (sensitivity === "severe") {
    referral = true;
    safetyReasons.push(
      "skin-dna-referral-severe-reactivity",
    );
  }

  if (
    !referral &&
    isModerateOrHigher(sensitivity)
  ) {
    safetyReasons.push(
      "skin-dna-caution-sensitivity",
    );
  }

  if (pregnancy) {
    safetyReasons.push(
      "skin-dna-caution-customer-declared-pregnancy",
    );
  }

  if (avoidIngredients.length > 0) {
    safetyReasons.push(
      "skin-dna-caution-customer-declared-avoid-list",
    );
  }

  const classification: SkinDnaSafetyClassification = referral
    ? "referral"
    : safetyReasons.length > 0
    ? "caution"
    : "standard";

  const recommendationStatus: SkinDnaRecommendationStatus =
    classification === "referral"
      ? "blocked"
      : classification === "caution"
      ? "ready_with_cautions"
      : "ready";

  const skinType = deriveSkinType(
    oiliness,
    dryness,
  );

  const sensitivityLevel: SkinDnaSensitivityLevel =
    isModerateOrHigher(sensitivity) ? "sensitive" : "normal";

  const derivedConcerns: SkinDnaConcernKey[] = [
    ...declaredConcerns,
  ];

  if (isModerateOrHigher(dryness)) {
    derivedConcerns.push("dryness");
  }

  if (isModerateOrHigher(oiliness)) {
    derivedConcerns.push("oiliness");
  }

  if (isModerateOrHigher(sensitivity)) {
    derivedConcerns.push("sensitivity");
  }

  if (acneProne) {
    derivedConcerns.push("acne");
  }

  const skinConcerns = uniqueSortedConcerns(
    derivedConcerns,
  );

  return {
    recommendation_profile: {
      skin_type: skinType,
      skin_concerns: skinConcerns,
      sensitivity_level: sensitivityLevel,
      acne_prone: acneProne,
      pregnancy,
      avoid_ingredients: avoidIngredients,
      preferred_steps: preferredSteps,
    },

    concern_priorities: concernPriorities,

    routine_complexity: routineComplexity,

    safety: {
      non_diagnostic: true,
      classification,
      recommendation_status: recommendationStatus,
      reasons: safetyReasons,
      pregnancy_semantics: "customer_declared_caution_context_only",
    },

    provenance: {
      contract_version: SKIN_DNA_MVP_CONTRACT_VERSION,
      questionnaire_version: SKIN_DNA_MVP_QUESTIONNAIRE_VERSION,
      adapter_id: SKIN_DNA_ADAPTER_ID,
      config_version: SKIN_DNA_MVP_CONFIG_VERSION,
      profile_bridge: "beautydna-v2-recommendation-profile-v1",
      confidence_source: "beautydna-dna-engine-core",
      medical_boundary: "cosmetic_non_diagnostic",
    },
  };
}

export function createSkinDnaRecommendationProfile(
  input: unknown,
): SkinDnaRecommendationProfile {
  const bridge = normalizeSkinDnaMvpQuestionnaire(
    input,
  );

  if (
    bridge.safety.recommendation_status ===
      "blocked"
  ) {
    throw new Error(
      "SkinDNA MVP recommendation profile is blocked by non-diagnostic referral safety handling.",
    );
  }

  return {
    skin_type: bridge.recommendation_profile.skin_type,
    skin_concerns: [
      ...bridge.recommendation_profile
        .skin_concerns,
    ],
    sensitivity_level: bridge.recommendation_profile
      .sensitivity_level,
    acne_prone: bridge.recommendation_profile.acne_prone,
    pregnancy: bridge.recommendation_profile.pregnancy,
    avoid_ingredients: [
      ...bridge.recommendation_profile
        .avoid_ingredients,
    ],
    preferred_steps: [
      ...bridge.recommendation_profile
        .preferred_steps,
    ],
  };
}

export const SKIN_DNA_MVP_CONFIGURATION: DnaEngineConfiguration = {
  config_version: SKIN_DNA_MVP_CONFIG_VERSION,

  required_signal_keys: [
    "skin_oiliness",
    "skin_dryness",
    "skin_sensitivity",
    "acne_tendency",
    "pregnancy_context",
    "avoid_ingredient_context",
    "safety_caution",
    "safety_referral",
  ],

  dimensions: [
    directDimension(
      "skin_oiliness",
      "skin_oiliness",
    ),
    directDimension(
      "skin_dryness",
      "skin_dryness",
    ),
    directDimension(
      "skin_sensitivity",
      "skin_sensitivity",
    ),
    directDimension(
      "acne_tendency",
      "acne_tendency",
    ),
    directDimension(
      "pregnancy_context",
      "pregnancy_context",
    ),
    directDimension(
      "avoid_ingredient_context",
      "avoid_ingredient_context",
    ),
    directDimension(
      "safety_caution",
      "safety_caution",
    ),
    directDimension(
      "safety_referral",
      "safety_referral",
    ),
  ],

  concern_rules: [
    {
      key: "skin-dna-oiliness",
      dimension_key: "skin_oiliness",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "skin-dna-dryness",
      dimension_key: "skin_dryness",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "skin-dna-sensitivity",
      dimension_key: "skin_sensitivity",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "skin-dna-acne-tendency",
      dimension_key: "acne_tendency",
      operator: "gte",
      threshold: 100,
      severity: "medium",
    },
    {
      key: "skin-dna-safety-caution",
      dimension_key: "safety_caution",
      operator: "gte",
      threshold: 100,
      severity: "medium",
    },
    {
      key: "skin-dna-safety-referral",
      dimension_key: "safety_referral",
      operator: "gte",
      threshold: 100,
      severity: "high",
    },
  ],
};

export function normalizeSkinDnaAssessment(
  assessment: DnaAssessmentInput,
) {
  if (
    !isRecord(assessment) ||
    !isRecord(assessment.answers)
  ) {
    throw new Error(
      "SkinDNA assessment.answers must contain the SkinDNA MVP questionnaire object.",
    );
  }

  const bridge = normalizeSkinDnaMvpQuestionnaire(
    assessment.answers,
  );

  const answers = assessment.answers;

  const oiliness = readEnum(
    answers.oiliness,
    "oiliness",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const dryness = readEnum(
    answers.dryness,
    "dryness",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const sensitivity = readEnum(
    answers.sensitivity,
    "sensitivity",
    SKIN_DNA_SEVERITY_LEVELS,
  );

  const referral = bridge.safety.classification ===
    "referral";

  const caution = bridge.safety.classification ===
    "caution";

  return {
    signals: {
      skin_oiliness: SEVERITY_SIGNAL[oiliness],

      skin_dryness: SEVERITY_SIGNAL[dryness],

      skin_sensitivity: SEVERITY_SIGNAL[sensitivity],

      acne_tendency: bridge.recommendation_profile
          .acne_prone
        ? 1
        : 0,

      pregnancy_context: bridge.recommendation_profile
          .pregnancy
        ? 1
        : 0,

      avoid_ingredient_context: bridge.recommendation_profile
          .avoid_ingredients.length >
          0
        ? 1
        : 0,

      safety_caution: caution ? 1 : 0,

      safety_referral: referral ? 1 : 0,
    },

    profile_attributes: {
      skin_dna_contract_version: SKIN_DNA_MVP_CONTRACT_VERSION,

      questionnaire_version: SKIN_DNA_MVP_QUESTIONNAIRE_VERSION,

      adapter_id: SKIN_DNA_ADAPTER_ID,

      skin_state: {
        oiliness,
        dryness,
        skin_type: bridge.recommendation_profile
          .skin_type,
      },

      sensitivity_state: {
        reactivity: sensitivity,
        downstream_level: bridge.recommendation_profile
          .sensitivity_level,
      },

      recommendation_profile: {
        skin_type: bridge.recommendation_profile
          .skin_type,

        skin_concerns: [
          ...bridge.recommendation_profile
            .skin_concerns,
        ],

        sensitivity_level: bridge.recommendation_profile
          .sensitivity_level,

        acne_prone: bridge.recommendation_profile
          .acne_prone,

        pregnancy: bridge.recommendation_profile
          .pregnancy,

        avoid_ingredients: [
          ...bridge.recommendation_profile
            .avoid_ingredients,
        ],

        preferred_steps: [
          ...bridge.recommendation_profile
            .preferred_steps,
        ],
      },

      concern_priorities: [
        ...bridge.concern_priorities,
      ],

      routine_complexity: bridge.routine_complexity,

      safety: {
        non_diagnostic: true,

        classification: bridge.safety.classification,

        recommendation_status: bridge.safety
          .recommendation_status,

        reasons: [
          ...bridge.safety.reasons,
        ],

        pregnancy_semantics: "customer_declared_caution_context_only",
      },
    },

    provenance: {
      skin_dna_contract_version: SKIN_DNA_MVP_CONTRACT_VERSION,

      questionnaire_version: SKIN_DNA_MVP_QUESTIONNAIRE_VERSION,

      adapter_key: SKIN_DNA_ADAPTER_KEY,

      adapter_version: SKIN_DNA_ADAPTER_VERSION,

      adapter_id: SKIN_DNA_ADAPTER_ID,

      config_version: SKIN_DNA_MVP_CONFIG_VERSION,

      profile_bridge: "beautydna-v2-recommendation-profile-v1",

      confidence_source: "beautydna-dna-engine-core",

      persistence_boundary: "reuse_generic_assessment_answer_passport",

      face_photo_requirement: "optional_not_required_for_mvp",

      medical_boundary: "cosmetic_non_diagnostic",
    },
  };
}

export const SKIN_DNA_ADAPTER: DnaDomainAdapter = {
  adapter_key: SKIN_DNA_ADAPTER_KEY,

  adapter_version: SKIN_DNA_ADAPTER_VERSION,

  domain_key: SKIN_DNA_DOMAIN_KEY,

  configuration: SKIN_DNA_MVP_CONFIGURATION,

  normalize(assessment) {
    return normalizeSkinDnaAssessment(
      assessment,
    );
  },
};

export const SKIN_DNA_ADAPTER_REGISTRY = createDnaAdapterRegistry([
  SKIN_DNA_ADAPTER,
]);

export function executeSkinDnaMvp(
  request: SkinDnaExecutionRequest,
) {
  if (
    !isRecord(request) ||
    request.contract_version !==
      SKIN_DNA_MVP_CONTRACT_VERSION
  ) {
    throw new Error(
      `Unsupported SkinDNA MVP contract version. Expected ${SKIN_DNA_MVP_CONTRACT_VERSION}.`,
    );
  }

  return executeDnaEngine(
    {
      contract_version: DNA_ENGINE_CONTRACT_VERSION,

      engine_version: DNA_ENGINE_VERSION,

      adapter_key: SKIN_DNA_ADAPTER_KEY,

      adapter_version: SKIN_DNA_ADAPTER_VERSION,

      assessment: request.assessment,
    },
    SKIN_DNA_ADAPTER_REGISTRY,
  );
}
