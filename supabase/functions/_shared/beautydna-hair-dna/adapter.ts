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

export const HAIR_DNA_CONTRACT_VERSION =
  "beautydna-hair-dna-contract-v1" as const;

export const HAIR_DNA_ADAPTER_KEY = "hair-dna" as const;

export const HAIR_DNA_ADAPTER_VERSION = "v1" as const;

export const HAIR_DNA_ADAPTER_ID = "hair-dna@v1" as const;

export const HAIR_DNA_DOMAIN_KEY = "hair-dna" as const;

export const HAIR_DNA_CONFIG_VERSION = "beautydna-hair-dna-config-v1" as const;

export const HAIR_DNA_SEVERITY_LEVELS = [
  "none",
  "low",
  "moderate",
  "high",
  "severe",
] as const;

export type HairDnaSeverity = (typeof HAIR_DNA_SEVERITY_LEVELS)[number];

export const HAIR_DNA_HAIR_PATTERNS = [
  "straight",
  "wavy",
  "curly",
  "coily",
] as const;

export type HairDnaHairPattern = (typeof HAIR_DNA_HAIR_PATTERNS)[number];

export const HAIR_DNA_STRAND_THICKNESS = [
  "fine",
  "medium",
  "coarse",
] as const;

export type HairDnaStrandThickness = (typeof HAIR_DNA_STRAND_THICKNESS)[number];

export const HAIR_DNA_DENSITY_LEVELS = [
  "low",
  "medium",
  "high",
] as const;

export type HairDnaDensity = (typeof HAIR_DNA_DENSITY_LEVELS)[number];

export const HAIR_DNA_POROSITY_LEVELS = [
  "low",
  "medium",
  "high",
] as const;

export type HairDnaPorosity = (typeof HAIR_DNA_POROSITY_LEVELS)[number];

export const HAIR_DNA_CHEMICAL_TREATMENTS = [
  "colored",
  "bleached",
  "permed",
  "relaxed",
] as const;

export type HairDnaChemicalTreatment =
  (typeof HAIR_DNA_CHEMICAL_TREATMENTS)[number];

export const HAIR_DNA_WATER_HARDNESS = [
  "soft",
  "moderate",
  "hard",
  "unknown",
] as const;

export type HairDnaWaterHardness = (typeof HAIR_DNA_WATER_HARDNESS)[number];

export const HAIR_DNA_FOCUS_KEYS = [
  "breakage",
  "breakage_near_root",
  "damage",
  "dandruff_tendency",
  "dry_scalp",
  "flaking",
  "frizz",
  "high_porosity",
  "low_porosity",
  "oily_scalp",
  "product_buildup",
  "scalp_irritation",
  "sensitive_scalp",
  "shedding_concern",
] as const;

export type HairDnaFocusKey = (typeof HAIR_DNA_FOCUS_KEYS)[number];

export interface HairDnaExecutionRequest {
  contract_version: string;
  assessment: DnaAssessmentInput;
}

type JsonSafeValue =
  | null
  | boolean
  | number
  | string
  | JsonSafeValue[]
  | JsonSafeObject;

interface JsonSafeObject {
  [key: string]: JsonSafeValue;
}

const SEVERITY_SIGNAL: Record<
  HairDnaSeverity,
  number
> = {
  none: 0,
  low: 0.25,
  moderate: 0.5,
  high: 0.75,
  severe: 1,
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

function normalizeJsonValue(
  value: unknown,
  path: string,
): JsonSafeValue {
  if (value === null) {
    return null;
  }

  if (
    typeof value === "string" ||
    typeof value === "boolean"
  ) {
    return value;
  }

  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error(
        `${path} contains a non-finite number.`,
      );
    }

    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item, index) =>
      normalizeJsonValue(
        item,
        `${path}[${index}]`,
      )
    );
  }

  if (isRecord(value)) {
    const result: JsonSafeObject = {};

    for (
      const key of Object.keys(value).sort()
    ) {
      result[key] = normalizeJsonValue(
        value[key],
        `${path}.${key}`,
      );
    }

    return result;
  }

  throw new Error(
    `${path} contains a non-JSON-compatible value.`,
  );
}

function normalizeContext(
  context:
    | Record<string, unknown>
    | undefined,
): JsonSafeObject {
  if (!context) {
    return {};
  }

  return normalizeJsonValue(
    context,
    "assessment.context",
  ) as JsonSafeObject;
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

function readOptionalBoolean(
  value: unknown,
  key: string,
): boolean {
  if (value === undefined) {
    return false;
  }

  if (typeof value !== "boolean") {
    throw new Error(
      `${key} must be boolean when provided.`,
    );
  }

  return value;
}

function readWashFrequency(
  value: unknown,
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < 0 ||
    value > 14
  ) {
    throw new Error(
      "wash_frequency_per_week must be an integer from 0 through 14.",
    );
  }

  return value;
}

function readEnumSet<T extends string>(
  value: unknown,
  key: string,
  allowed: readonly T[],
): T[] {
  if (value === undefined) {
    return [];
  }

  if (!Array.isArray(value)) {
    throw new Error(
      `${key} must be an array when provided.`,
    );
  }

  const normalized = value.map((item) =>
    readEnum(
      item,
      key,
      allowed,
    )
  );

  return Array.from(
    new Set(normalized),
  ).sort();
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

function waterHardnessSignal(
  value: HairDnaWaterHardness,
): number {
  switch (value) {
    case "soft":
      return 0;

    case "moderate":
      return 0.5;

    case "hard":
      return 1;

    case "unknown":
      return 0;
  }
}

function isModerateOrHigher(
  value: HairDnaSeverity,
): boolean {
  return SEVERITY_SIGNAL[value] >= 0.5;
}

function isSevere(
  value: HairDnaSeverity,
): boolean {
  return value === "severe";
}

export const HAIR_DNA_CONFIGURATION: DnaEngineConfiguration = {
  config_version: HAIR_DNA_CONFIG_VERSION,

  required_signal_keys: [
    "scalp_oiliness",
    "scalp_dryness",
    "scalp_sensitivity",
    "scalp_flaking",
    "hair_low_porosity",
    "hair_high_porosity",
    "hair_damage",
    "heat_exposure",
    "chemical_treatment_exposure",
    "hair_breakage",
    "hair_frizz",
    "hair_buildup",
    "hard_water_context",
    "safety_irritation",
    "safety_shedding",
    "safety_red_flag",
    "safety_severe_scalp",
  ],

  dimensions: [
    directDimension(
      "scalp_oiliness",
      "scalp_oiliness",
    ),
    directDimension(
      "scalp_dryness",
      "scalp_dryness",
    ),
    directDimension(
      "scalp_sensitivity",
      "scalp_sensitivity",
    ),
    directDimension(
      "scalp_flaking",
      "scalp_flaking",
    ),
    directDimension(
      "hair_low_porosity",
      "hair_low_porosity",
    ),
    directDimension(
      "hair_high_porosity",
      "hair_high_porosity",
    ),
    directDimension(
      "hair_damage",
      "hair_damage",
    ),
    directDimension(
      "heat_exposure",
      "heat_exposure",
    ),
    directDimension(
      "chemical_treatment_exposure",
      "chemical_treatment_exposure",
    ),
    directDimension(
      "hair_breakage",
      "hair_breakage",
    ),
    directDimension(
      "hair_frizz",
      "hair_frizz",
    ),
    directDimension(
      "hair_buildup",
      "hair_buildup",
    ),
    directDimension(
      "hard_water_context",
      "hard_water_context",
    ),
    directDimension(
      "safety_irritation",
      "safety_irritation",
    ),
    directDimension(
      "safety_shedding",
      "safety_shedding",
    ),
    directDimension(
      "safety_red_flag",
      "safety_red_flag",
    ),
    directDimension(
      "safety_severe_scalp",
      "safety_severe_scalp",
    ),
  ],

  concern_rules: [
    {
      key: "hair-dna-oily-scalp",
      dimension_key: "scalp_oiliness",
      operator: "gte",
      threshold: 75,
      severity: "medium",
    },
    {
      key: "hair-dna-dry-scalp",
      dimension_key: "scalp_dryness",
      operator: "gte",
      threshold: 75,
      severity: "medium",
    },
    {
      key: "hair-dna-sensitive-scalp",
      dimension_key: "scalp_sensitivity",
      operator: "gte",
      threshold: 50,
      severity: "caution",
    },
    {
      key: "hair-dna-flaking",
      dimension_key: "scalp_flaking",
      operator: "gte",
      threshold: 50,
      severity: "caution",
    },
    {
      key: "hair-dna-low-porosity",
      dimension_key: "hair_low_porosity",
      operator: "gte",
      threshold: 100,
      severity: "info",
    },
    {
      key: "hair-dna-high-porosity",
      dimension_key: "hair_high_porosity",
      operator: "gte",
      threshold: 100,
      severity: "info",
    },
    {
      key: "hair-dna-damage",
      dimension_key: "hair_damage",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "hair-dna-high-heat-exposure",
      dimension_key: "heat_exposure",
      operator: "gte",
      threshold: 75,
      severity: "medium",
    },
    {
      key: "hair-dna-breakage",
      dimension_key: "hair_breakage",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "hair-dna-frizz",
      dimension_key: "hair_frizz",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "hair-dna-buildup",
      dimension_key: "hair_buildup",
      operator: "gte",
      threshold: 50,
      severity: "medium",
    },
    {
      key: "hair-dna-hard-water-context",
      dimension_key: "hard_water_context",
      operator: "gte",
      threshold: 100,
      severity: "info",
    },
    {
      key: "hair-dna-caution-scalp-irritation",
      dimension_key: "safety_irritation",
      operator: "gte",
      threshold: 100,
      severity: "caution",
    },
    {
      key: "hair-dna-referral-shedding",
      dimension_key: "safety_shedding",
      operator: "gte",
      threshold: 100,
      severity: "referral",
    },
    {
      key: "hair-dna-referral-red-flag",
      dimension_key: "safety_red_flag",
      operator: "gte",
      threshold: 100,
      severity: "referral",
    },
    {
      key: "hair-dna-referral-severe-scalp-state",
      dimension_key: "safety_severe_scalp",
      operator: "gte",
      threshold: 100,
      severity: "referral",
    },
  ],

  priority_rules: [
    {
      key: "hair-dna-priority-red-flag",
      dimension_key: "safety_red_flag",
      operator: "gte",
      threshold: 100,
      priority: 1,
    },
    {
      key: "hair-dna-priority-shedding",
      dimension_key: "safety_shedding",
      operator: "gte",
      threshold: 100,
      priority: 1,
    },
    {
      key: "hair-dna-priority-severe-scalp-state",
      dimension_key: "safety_severe_scalp",
      operator: "gte",
      threshold: 100,
      priority: 1,
    },
    {
      key: "hair-dna-priority-irritation",
      dimension_key: "safety_irritation",
      operator: "gte",
      threshold: 100,
      priority: 1,
    },
    {
      key: "hair-dna-priority-sensitivity",
      dimension_key: "scalp_sensitivity",
      operator: "gte",
      threshold: 50,
      priority: 1,
    },
    {
      key: "hair-dna-priority-flaking",
      dimension_key: "scalp_flaking",
      operator: "gte",
      threshold: 50,
      priority: 1,
    },
    {
      key: "hair-dna-priority-damage",
      dimension_key: "hair_damage",
      operator: "gte",
      threshold: 50,
      priority: 2,
    },
    {
      key: "hair-dna-priority-breakage",
      dimension_key: "hair_breakage",
      operator: "gte",
      threshold: 50,
      priority: 2,
    },
    {
      key: "hair-dna-priority-oiliness",
      dimension_key: "scalp_oiliness",
      operator: "gte",
      threshold: 75,
      priority: 3,
    },
    {
      key: "hair-dna-priority-dryness",
      dimension_key: "scalp_dryness",
      operator: "gte",
      threshold: 75,
      priority: 3,
    },
    {
      key: "hair-dna-priority-frizz",
      dimension_key: "hair_frizz",
      operator: "gte",
      threshold: 50,
      priority: 3,
    },
    {
      key: "hair-dna-priority-buildup",
      dimension_key: "hair_buildup",
      operator: "gte",
      threshold: 50,
      priority: 3,
    },
  ],
};

export function normalizeHairDnaAssessment(
  assessment: DnaAssessmentInput,
) {
  if (!isRecord(assessment.answers)) {
    throw new Error(
      "HairDNA assessment answers must be an object.",
    );
  }

  const answers = assessment.answers;

  const scalpOiliness = readEnum(
    answers.scalp_oiliness,
    "scalp_oiliness",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const scalpDryness = readEnum(
    answers.scalp_dryness,
    "scalp_dryness",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const scalpSensitivity = readEnum(
    answers.scalp_sensitivity,
    "scalp_sensitivity",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const flaking = readEnum(
    answers.flaking,
    "flaking",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const hairPattern = readEnum(
    answers.hair_pattern,
    "hair_pattern",
    HAIR_DNA_HAIR_PATTERNS,
  );

  const strandThickness = readEnum(
    answers.strand_thickness,
    "strand_thickness",
    HAIR_DNA_STRAND_THICKNESS,
  );

  const density = readEnum(
    answers.density,
    "density",
    HAIR_DNA_DENSITY_LEVELS,
  );

  const porosity = readEnum(
    answers.porosity,
    "porosity",
    HAIR_DNA_POROSITY_LEVELS,
  );

  const damage = readEnum(
    answers.damage,
    "damage",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const heatExposure = readEnum(
    answers.heat_exposure,
    "heat_exposure",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const breakage = readEnum(
    answers.breakage,
    "breakage",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const frizz = readEnum(
    answers.frizz,
    "frizz",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const buildup = readEnum(
    answers.buildup,
    "buildup",
    HAIR_DNA_SEVERITY_LEVELS,
  );

  const chemicalTreatments = readEnumSet(
    answers.chemical_treatments,
    "chemical_treatments",
    HAIR_DNA_CHEMICAL_TREATMENTS,
  );

  const washFrequency = readWashFrequency(
    answers.wash_frequency_per_week,
  );

  const waterHardness = answers.water_hardness === undefined
    ? "unknown"
    : readEnum(
      answers.water_hardness,
      "water_hardness",
      HAIR_DNA_WATER_HARDNESS,
    );

  const concerns = readEnumSet(
    answers.concerns,
    "concerns",
    HAIR_DNA_FOCUS_KEYS,
  );

  const priorities = readEnumSet(
    answers.priorities,
    "priorities",
    HAIR_DNA_FOCUS_KEYS,
  );

  const irritationConcern = readOptionalBoolean(
    answers.scalp_irritation_concern,
    "scalp_irritation_concern",
  );

  const sheddingConcern = readOptionalBoolean(
    answers.shedding_concern,
    "shedding_concern",
  );

  const redFlagPresent = readOptionalBoolean(
    answers.red_flag_present,
    "red_flag_present",
  );

  const severeScalpState = isSevere(scalpSensitivity) ||
    isSevere(flaking);

  const reasons: string[] = [];

  if (
    isModerateOrHigher(
      scalpSensitivity,
    )
  ) {
    reasons.push(
      "scalp_sensitivity_moderate_or_higher",
    );
  }

  if (
    isModerateOrHigher(
      flaking,
    )
  ) {
    reasons.push(
      "flaking_moderate_or_higher",
    );
  }

  if (irritationConcern) {
    reasons.push(
      "scalp_irritation_concern",
    );
  }

  if (sheddingConcern) {
    reasons.push(
      "shedding_concern",
    );
  }

  if (redFlagPresent) {
    reasons.push(
      "red_flag_present",
    );
  }

  if (severeScalpState) {
    reasons.push(
      "severe_scalp_state",
    );
  }

  const safetyClassification = (
      redFlagPresent ||
      sheddingConcern ||
      severeScalpState
    )
    ? "referral"
    : (
        irritationConcern ||
        isModerateOrHigher(
          scalpSensitivity,
        ) ||
        isModerateOrHigher(
          flaking,
        )
      )
    ? "caution"
    : "cosmetic_profile";

  return {
    signals: {
      scalp_oiliness: SEVERITY_SIGNAL[scalpOiliness],

      scalp_dryness: SEVERITY_SIGNAL[scalpDryness],

      scalp_sensitivity: SEVERITY_SIGNAL[
        scalpSensitivity
      ],

      scalp_flaking: SEVERITY_SIGNAL[flaking],

      hair_low_porosity: porosity === "low" ? 1 : 0,

      hair_high_porosity: porosity === "high" ? 1 : 0,

      hair_damage: SEVERITY_SIGNAL[damage],

      heat_exposure: SEVERITY_SIGNAL[heatExposure],

      chemical_treatment_exposure: chemicalTreatments.length > 0 ? 1 : 0,

      hair_breakage: SEVERITY_SIGNAL[breakage],

      hair_frizz: SEVERITY_SIGNAL[frizz],

      hair_buildup: SEVERITY_SIGNAL[buildup],

      hard_water_context: waterHardnessSignal(
        waterHardness,
      ),

      safety_irritation: irritationConcern ? 1 : 0,

      safety_shedding: sheddingConcern ? 1 : 0,

      safety_red_flag: redFlagPresent ? 1 : 0,

      safety_severe_scalp: severeScalpState ? 1 : 0,
    },

    profile_attributes: {
      hair_dna_contract_version: HAIR_DNA_CONTRACT_VERSION,

      adapter_id: HAIR_DNA_ADAPTER_ID,

      scalp_state: {
        oiliness: scalpOiliness,
        dryness: scalpDryness,
        sensitivity: scalpSensitivity,
        flaking,
      },

      hair_fiber: {
        pattern: hairPattern,
        strand_thickness: strandThickness,
        density,
        porosity,
        damage,
        breakage,
        frizz,
        buildup,
      },

      treatment_history: {
        chemical_treatments: chemicalTreatments,
        heat_exposure: heatExposure,
      },

      routine_context: {
        wash_frequency_per_week: washFrequency,
        water_hardness: waterHardness,
      },

      environmental_context: normalizeContext(
        assessment.context,
      ),

      user_concerns: concerns,

      user_priorities: priorities,

      safety: {
        non_diagnostic: true,
        classification: safetyClassification,
        reasons,
      },
    },

    provenance: {
      hair_dna_contract_version: HAIR_DNA_CONTRACT_VERSION,

      adapter_key: HAIR_DNA_ADAPTER_KEY,

      adapter_version: HAIR_DNA_ADAPTER_VERSION,

      adapter_id: HAIR_DNA_ADAPTER_ID,

      config_version: HAIR_DNA_CONFIG_VERSION,

      vocabulary_basis: "beauty-intelligence-source-specification",

      scoring_semantics: "direct-normalized-signal-v1",

      medical_boundary: "non-diagnostic",
    },
  };
}

export const HAIR_DNA_ADAPTER: DnaDomainAdapter = {
  adapter_key: HAIR_DNA_ADAPTER_KEY,

  adapter_version: HAIR_DNA_ADAPTER_VERSION,

  domain_key: HAIR_DNA_DOMAIN_KEY,

  configuration: HAIR_DNA_CONFIGURATION,

  normalize(assessment) {
    return normalizeHairDnaAssessment(
      assessment,
    );
  },
};

export const HAIR_DNA_ADAPTER_REGISTRY = createDnaAdapterRegistry([
  HAIR_DNA_ADAPTER,
]);

export function executeHairDna(
  request: HairDnaExecutionRequest,
) {
  if (
    !isRecord(request) ||
    request.contract_version !==
      HAIR_DNA_CONTRACT_VERSION
  ) {
    throw new Error(
      `Unsupported HairDNA contract version. Expected ${HAIR_DNA_CONTRACT_VERSION}.`,
    );
  }

  return executeDnaEngine(
    {
      contract_version: DNA_ENGINE_CONTRACT_VERSION,

      engine_version: DNA_ENGINE_VERSION,

      adapter_key: HAIR_DNA_ADAPTER_KEY,

      adapter_version: HAIR_DNA_ADAPTER_VERSION,

      assessment: request.assessment,
    },
    HAIR_DNA_ADAPTER_REGISTRY,
  );
}
