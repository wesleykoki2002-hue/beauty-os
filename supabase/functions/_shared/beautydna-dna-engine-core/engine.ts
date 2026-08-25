export const DNA_ENGINE_CONTRACT_VERSION =
  "beautydna-dna-engine-core-contract-v1" as const;

export const DNA_ENGINE_VERSION = "beautydna-dna-engine-core-v1" as const;

export type JsonPrimitive = string | number | boolean | null;

export type JsonValue =
  | JsonPrimitive
  | JsonValue[]
  | { [key: string]: JsonValue };

export type JsonObject = { [key: string]: JsonValue };

export type ThresholdOperator = "gte" | "lte";

export type DnaEngineErrorCode =
  | "MALFORMED_REQUEST"
  | "MALFORMED_INPUT"
  | "MALFORMED_CONFIGURATION"
  | "UNSUPPORTED_CONTRACT_VERSION"
  | "UNSUPPORTED_ENGINE_VERSION"
  | "UNSUPPORTED_ADAPTER"
  | "UNSUPPORTED_ADAPTER_VERSION"
  | "ADAPTER_NORMALIZATION_FAILED";

export class DnaEngineError extends Error {
  readonly code: DnaEngineErrorCode;

  constructor(code: DnaEngineErrorCode, message: string) {
    super(message);
    this.name = "DnaEngineError";
    this.code = code;
  }
}

export interface DnaAssessmentInput {
  assessment_id?: string | null;
  answers: Record<string, unknown>;
  context?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

export interface DnaEngineRequest {
  contract_version: string;
  engine_version: string;
  adapter_key: string;
  adapter_version: string;
  assessment: DnaAssessmentInput;
}

export interface DnaNormalizedDomainInput {
  signals: Record<string, number>;
  profile_attributes?: JsonObject;
  provenance?: JsonObject;
}

export interface DnaDimensionContributionConfig {
  signal_key: string;
  weight: number;
}

export interface DnaDimensionConfig {
  key: string;
  min_score: number;
  max_score: number;
  base_score: number;
  contributions: readonly DnaDimensionContributionConfig[];
}

export interface DnaConcernRuleConfig {
  key: string;
  dimension_key: string;
  operator: ThresholdOperator;
  threshold: number;
  severity: string;
}

export interface DnaPriorityRuleConfig {
  key: string;
  dimension_key: string;
  operator: ThresholdOperator;
  threshold: number;
  priority: number;
}

export interface DnaEngineConfiguration {
  config_version: string;
  required_signal_keys: readonly string[];
  dimensions: readonly DnaDimensionConfig[];
  concern_rules?: readonly DnaConcernRuleConfig[];
  priority_rules?: readonly DnaPriorityRuleConfig[];
}

export interface DnaDomainAdapter {
  adapter_key: string;
  adapter_version: string;
  domain_key: string;
  configuration: DnaEngineConfiguration;
  normalize(
    assessment: DnaAssessmentInput,
  ): DnaNormalizedDomainInput;
}

export type DnaAdapterRegistry = Readonly<Record<string, DnaDomainAdapter>>;

export interface DnaDimensionScore {
  key: string;
  score: number;
  min_score: number;
  max_score: number;
  contributions: Array<{
    signal_key: string;
    signal_value: number;
    weight: number;
    weighted_points: number;
  }>;
}

export interface DnaConcernSignal {
  key: string;
  dimension_key: string;
  score: number;
  operator: ThresholdOperator;
  threshold: number;
  severity: string;
}

export interface DnaPrioritySignal {
  key: string;
  dimension_key: string;
  score: number;
  operator: ThresholdOperator;
  threshold: number;
  priority: number;
}

export interface DnaEngineResult {
  ok: true;
  contract_version: typeof DNA_ENGINE_CONTRACT_VERSION;
  engine_version: typeof DNA_ENGINE_VERSION;
  domain: {
    domain_key: string;
    adapter_key: string;
    adapter_version: string;
    config_version: string;
  };
  assessment: {
    assessment_id: string | null;
  };
  dimension_scores: DnaDimensionScore[];
  concern_signals: DnaConcernSignal[];
  priority_signals: DnaPrioritySignal[];
  confidence: {
    score: number;
    observed_required_signals: number;
    total_required_signals: number;
  };
  provenance: {
    deterministic: true;
    input_fingerprint: string;
    contract_version: typeof DNA_ENGINE_CONTRACT_VERSION;
    engine_version: typeof DNA_ENGINE_VERSION;
    domain_key: string;
    adapter_key: string;
    adapter_version: string;
    config_version: string;
    signal_keys: string[];
    adapter_provenance: JsonObject;
  };
  profile: {
    domain_key: string;
    dimensions: Record<string, number>;
    concerns: string[];
    priorities: string[];
    confidence: number;
    attributes: JsonObject;
  };
}

function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

function requireNonEmptyString(
  value: unknown,
  label: string,
  code: DnaEngineErrorCode,
): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0
  ) {
    throw new DnaEngineError(
      code,
      `${label} must be a non-empty string.`,
    );
  }

  return value.trim();
}

function requireFiniteNumber(
  value: unknown,
  label: string,
  code: DnaEngineErrorCode,
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value)
  ) {
    throw new DnaEngineError(
      code,
      `${label} must be a finite number.`,
    );
  }

  return value;
}

function canonicalizeJson(
  value: unknown,
  path = "$",
): JsonValue {
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
      throw new DnaEngineError(
        "MALFORMED_INPUT",
        `${path} contains a non-finite number.`,
      );
    }

    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item, index) =>
      canonicalizeJson(
        item,
        `${path}[${index}]`,
      )
    );
  }

  if (isRecord(value)) {
    const canonical: JsonObject = {};

    for (
      const key of Object.keys(value).sort((a, b) => compareStrings(a, b))
    ) {
      const child = value[key];

      if (
        typeof child === "undefined" ||
        typeof child === "function" ||
        typeof child === "symbol" ||
        typeof child === "bigint"
      ) {
        throw new DnaEngineError(
          "MALFORMED_INPUT",
          `${path}.${key} is not JSON-compatible.`,
        );
      }

      canonical[key] = canonicalizeJson(
        child,
        `${path}.${key}`,
      );
    }

    return canonical;
  }

  throw new DnaEngineError(
    "MALFORMED_INPUT",
    `${path} is not JSON-compatible.`,
  );
}

function canonicalJsonObject(
  value: unknown,
  path: string,
): JsonObject {
  const canonical = canonicalizeJson(value, path);

  if (
    typeof canonical !== "object" ||
    canonical === null ||
    Array.isArray(canonical)
  ) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      `${path} must be an object.`,
    );
  }

  return canonical;
}

function compareStrings(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

function stableStringify(value: unknown): string {
  return JSON.stringify(
    canonicalizeJson(value),
  );
}

function fnv1a32(value: string): string {
  let hash = 0x811c9dc5;

  for (
    const byte of new TextEncoder().encode(value)
  ) {
    hash ^= byte;

    hash = Math.imul(
      hash,
      0x01000193,
    ) >>> 0;
  }

  return (
    "fnv1a32:" +
    hash.toString(16).padStart(8, "0")
  );
}

function round(value: number): number {
  return Number(value.toFixed(6));
}

function clamp(
  value: number,
  min: number,
  max: number,
): number {
  return Math.min(
    max,
    Math.max(min, value),
  );
}

function matchesThreshold(
  value: number,
  operator: ThresholdOperator,
  threshold: number,
): boolean {
  if (operator === "gte") {
    return value >= threshold;
  }

  return value <= threshold;
}

function adapterRegistryKey(
  adapterKey: string,
  adapterVersion: string,
): string {
  return `${adapterKey}@${adapterVersion}`;
}

function validateConfiguration(
  configuration: DnaEngineConfiguration,
): void {
  if (!isRecord(configuration)) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "configuration must be an object.",
    );
  }

  requireNonEmptyString(
    configuration.config_version,
    "configuration.config_version",
    "MALFORMED_CONFIGURATION",
  );

  if (
    !Array.isArray(
      configuration.required_signal_keys,
    ) ||
    configuration.required_signal_keys.length === 0
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "configuration.required_signal_keys must contain at least one signal.",
    );
  }

  const requiredSignals = new Set<string>();

  for (
    const signalKey of configuration.required_signal_keys
  ) {
    const key = requireNonEmptyString(
      signalKey,
      "required signal key",
      "MALFORMED_CONFIGURATION",
    );

    if (requiredSignals.has(key)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `Duplicate required signal key: ${key}.`,
      );
    }

    requiredSignals.add(key);
  }

  if (
    !Array.isArray(configuration.dimensions) ||
    configuration.dimensions.length === 0
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "configuration.dimensions must contain at least one dimension.",
    );
  }

  const dimensionKeys = new Set<string>();

  const dimensionRanges = new Map<
    string,
    { min: number; max: number }
  >();

  for (
    const dimension of configuration.dimensions
  ) {
    if (!isRecord(dimension)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        "Each dimension must be an object.",
      );
    }

    const key = requireNonEmptyString(
      dimension.key,
      "dimension.key",
      "MALFORMED_CONFIGURATION",
    );

    if (dimensionKeys.has(key)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `Duplicate dimension key: ${key}.`,
      );
    }

    dimensionKeys.add(key);

    const min = requireFiniteNumber(
      dimension.min_score,
      `${key}.min_score`,
      "MALFORMED_CONFIGURATION",
    );

    const max = requireFiniteNumber(
      dimension.max_score,
      `${key}.max_score`,
      "MALFORMED_CONFIGURATION",
    );

    const base = requireFiniteNumber(
      dimension.base_score,
      `${key}.base_score`,
      "MALFORMED_CONFIGURATION",
    );

    if (max <= min) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.max_score must be greater than min_score.`,
      );
    }

    if (base < min || base > max) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.base_score must be within the dimension range.`,
      );
    }

    if (!Array.isArray(dimension.contributions)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.contributions must be an array.`,
      );
    }

    const contributionSignals = new Set<string>();

    for (
      const contribution of dimension.contributions
    ) {
      if (!isRecord(contribution)) {
        throw new DnaEngineError(
          "MALFORMED_CONFIGURATION",
          `${key} contribution must be an object.`,
        );
      }

      const signalKey = requireNonEmptyString(
        contribution.signal_key,
        `${key}.contribution.signal_key`,
        "MALFORMED_CONFIGURATION",
      );

      if (
        contributionSignals.has(signalKey)
      ) {
        throw new DnaEngineError(
          "MALFORMED_CONFIGURATION",
          `${key} has duplicate contribution signal ${signalKey}.`,
        );
      }

      contributionSignals.add(signalKey);

      requireFiniteNumber(
        contribution.weight,
        `${key}.${signalKey}.weight`,
        "MALFORMED_CONFIGURATION",
      );
    }

    dimensionRanges.set(
      key,
      { min, max },
    );
  }

  if (
    configuration.concern_rules !== undefined &&
    !Array.isArray(configuration.concern_rules)
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "configuration.concern_rules must be an array when provided.",
    );
  }

  if (
    configuration.priority_rules !== undefined &&
    !Array.isArray(configuration.priority_rules)
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "configuration.priority_rules must be an array when provided.",
    );
  }

  const concernKeys = new Set<string>();

  for (
    const rule of configuration.concern_rules || []
  ) {
    if (!isRecord(rule)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        "Concern rule must be an object.",
      );
    }

    const key = requireNonEmptyString(
      rule.key,
      "concern rule key",
      "MALFORMED_CONFIGURATION",
    );

    if (concernKeys.has(key)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `Duplicate concern rule key: ${key}.`,
      );
    }

    concernKeys.add(key);

    const dimensionKey = requireNonEmptyString(
      rule.dimension_key,
      `${key}.dimension_key`,
      "MALFORMED_CONFIGURATION",
    );

    const range = dimensionRanges.get(dimensionKey);

    if (!range) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key} references unknown dimension ${dimensionKey}.`,
      );
    }

    if (
      rule.operator !== "gte" &&
      rule.operator !== "lte"
    ) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.operator is unsupported.`,
      );
    }

    const threshold = requireFiniteNumber(
      rule.threshold,
      `${key}.threshold`,
      "MALFORMED_CONFIGURATION",
    );

    if (
      threshold < range.min ||
      threshold > range.max
    ) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.threshold is outside the dimension range.`,
      );
    }

    requireNonEmptyString(
      rule.severity,
      `${key}.severity`,
      "MALFORMED_CONFIGURATION",
    );
  }

  const priorityKeys = new Set<string>();

  for (
    const rule of configuration.priority_rules || []
  ) {
    if (!isRecord(rule)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        "Priority rule must be an object.",
      );
    }

    const key = requireNonEmptyString(
      rule.key,
      "priority rule key",
      "MALFORMED_CONFIGURATION",
    );

    if (priorityKeys.has(key)) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `Duplicate priority rule key: ${key}.`,
      );
    }

    priorityKeys.add(key);

    const dimensionKey = requireNonEmptyString(
      rule.dimension_key,
      `${key}.dimension_key`,
      "MALFORMED_CONFIGURATION",
    );

    const range = dimensionRanges.get(dimensionKey);

    if (!range) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key} references unknown dimension ${dimensionKey}.`,
      );
    }

    if (
      rule.operator !== "gte" &&
      rule.operator !== "lte"
    ) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.operator is unsupported.`,
      );
    }

    const threshold = requireFiniteNumber(
      rule.threshold,
      `${key}.threshold`,
      "MALFORMED_CONFIGURATION",
    );

    if (
      threshold < range.min ||
      threshold > range.max
    ) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.threshold is outside the dimension range.`,
      );
    }

    const priority = requireFiniteNumber(
      rule.priority,
      `${key}.priority`,
      "MALFORMED_CONFIGURATION",
    );

    if (
      !Number.isInteger(priority) ||
      priority < 1
    ) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `${key}.priority must be a positive integer.`,
      );
    }
  }
}

function validateAdapter(
  adapter: DnaDomainAdapter,
): void {
  if (!isRecord(adapter)) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "Adapter must be an object.",
    );
  }

  requireNonEmptyString(
    adapter.adapter_key,
    "adapter.adapter_key",
    "MALFORMED_CONFIGURATION",
  );

  requireNonEmptyString(
    adapter.adapter_version,
    "adapter.adapter_version",
    "MALFORMED_CONFIGURATION",
  );

  requireNonEmptyString(
    adapter.domain_key,
    "adapter.domain_key",
    "MALFORMED_CONFIGURATION",
  );

  if (
    typeof adapter.normalize !== "function"
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "adapter.normalize must be a function.",
    );
  }

  validateConfiguration(
    adapter.configuration,
  );
}

function snapshotConfiguration(
  configuration: DnaEngineConfiguration,
): DnaEngineConfiguration {
  const requiredSignalKeys = [
    ...configuration.required_signal_keys,
  ];
  Object.freeze(requiredSignalKeys);

  const dimensions = configuration.dimensions.map((dimension) => {
    const contributions = dimension.contributions.map((contribution) => {
      const snapshot: DnaDimensionContributionConfig = {
        signal_key: contribution.signal_key,
        weight: contribution.weight,
      };

      Object.freeze(snapshot);
      return snapshot;
    });

    Object.freeze(contributions);

    const snapshot: DnaDimensionConfig = {
      key: dimension.key,
      min_score: dimension.min_score,
      max_score: dimension.max_score,
      base_score: dimension.base_score,
      contributions,
    };

    Object.freeze(snapshot);
    return snapshot;
  });

  Object.freeze(dimensions);

  const concernRules = configuration.concern_rules
    ? configuration.concern_rules.map((rule) => {
      const snapshot: DnaConcernRuleConfig = {
        key: rule.key,
        dimension_key: rule.dimension_key,
        operator: rule.operator,
        threshold: rule.threshold,
        severity: rule.severity,
      };

      Object.freeze(snapshot);
      return snapshot;
    })
    : undefined;

  if (concernRules) {
    Object.freeze(concernRules);
  }

  const priorityRules = configuration.priority_rules
    ? configuration.priority_rules.map((rule) => {
      const snapshot: DnaPriorityRuleConfig = {
        key: rule.key,
        dimension_key: rule.dimension_key,
        operator: rule.operator,
        threshold: rule.threshold,
        priority: rule.priority,
      };

      Object.freeze(snapshot);
      return snapshot;
    })
    : undefined;

  if (priorityRules) {
    Object.freeze(priorityRules);
  }

  const snapshot: DnaEngineConfiguration = {
    config_version: configuration.config_version,
    required_signal_keys: requiredSignalKeys,
    dimensions,
    concern_rules: concernRules,
    priority_rules: priorityRules,
  };

  Object.freeze(snapshot);
  return snapshot;
}

export function createDnaAdapterRegistry(
  adapters: readonly DnaDomainAdapter[],
): DnaAdapterRegistry {
  if (
    !Array.isArray(adapters) ||
    adapters.length === 0
  ) {
    throw new DnaEngineError(
      "MALFORMED_CONFIGURATION",
      "At least one adapter is required.",
    );
  }

  const registry: Record<string, DnaDomainAdapter> = {};

  for (const adapter of adapters) {
    validateAdapter(adapter);

    const key = adapterRegistryKey(
      adapter.adapter_key,
      adapter.adapter_version,
    );

    if (registry[key]) {
      throw new DnaEngineError(
        "MALFORMED_CONFIGURATION",
        `Duplicate adapter registration: ${key}.`,
      );
    }

    const normalize = adapter.normalize;
    const configuration = snapshotConfiguration(adapter.configuration);

    const registeredAdapter: DnaDomainAdapter = {
      adapter_key: adapter.adapter_key,
      adapter_version: adapter.adapter_version,
      domain_key: adapter.domain_key,
      configuration,
      normalize(assessment) {
        return normalize(assessment);
      },
    };

    Object.freeze(registeredAdapter);
    registry[key] = registeredAdapter;
  }

  return Object.freeze(registry);
}

function validateRequest(
  request: DnaEngineRequest,
): void {
  if (!isRecord(request)) {
    throw new DnaEngineError(
      "MALFORMED_REQUEST",
      "DNA Engine request must be an object.",
    );
  }

  if (
    request.contract_version !==
      DNA_ENGINE_CONTRACT_VERSION
  ) {
    throw new DnaEngineError(
      "UNSUPPORTED_CONTRACT_VERSION",
      `Unsupported DNA Engine contract version: ${
        String(request.contract_version)
      }.`,
    );
  }

  if (
    request.engine_version !==
      DNA_ENGINE_VERSION
  ) {
    throw new DnaEngineError(
      "UNSUPPORTED_ENGINE_VERSION",
      `Unsupported DNA Engine version: ${String(request.engine_version)}.`,
    );
  }

  requireNonEmptyString(
    request.adapter_key,
    "request.adapter_key",
    "MALFORMED_REQUEST",
  );

  requireNonEmptyString(
    request.adapter_version,
    "request.adapter_version",
    "MALFORMED_REQUEST",
  );

  if (!isRecord(request.assessment)) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "request.assessment must be an object.",
    );
  }

  if (!isRecord(request.assessment.answers)) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "request.assessment.answers must be an object.",
    );
  }

  if (
    request.assessment.assessment_id !== undefined &&
    request.assessment.assessment_id !== null
  ) {
    requireNonEmptyString(
      request.assessment.assessment_id,
      "request.assessment.assessment_id",
      "MALFORMED_INPUT",
    );
  }

  if (
    request.assessment.context !== undefined &&
    !isRecord(request.assessment.context)
  ) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "request.assessment.context must be an object when provided.",
    );
  }

  if (
    request.assessment.metadata !== undefined &&
    !isRecord(request.assessment.metadata)
  ) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "request.assessment.metadata must be an object when provided.",
    );
  }

  canonicalizeJson(
    request.assessment.answers,
    "$.assessment.answers",
  );

  canonicalizeJson(
    request.assessment.context ?? {},
    "$.assessment.context",
  );

  canonicalizeJson(
    request.assessment.metadata ?? {},
    "$.assessment.metadata",
  );
}

function validateNormalizedInput(
  normalized: DnaNormalizedDomainInput,
): DnaNormalizedDomainInput {
  if (!isRecord(normalized)) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "Adapter normalized output must be an object.",
    );
  }

  if (!isRecord(normalized.signals)) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "Adapter normalized signals must be an object.",
    );
  }

  if (
    normalized.profile_attributes !== undefined &&
    !isRecord(normalized.profile_attributes)
  ) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "Adapter profile_attributes must be an object when provided.",
    );
  }

  if (
    normalized.provenance !== undefined &&
    !isRecord(normalized.provenance)
  ) {
    throw new DnaEngineError(
      "MALFORMED_INPUT",
      "Adapter provenance must be an object when provided.",
    );
  }

  const signals: Record<string, number> = {};

  for (
    const key of Object.keys(normalized.signals).sort(
      (a, b) => compareStrings(a, b),
    )
  ) {
    const signalKey = requireNonEmptyString(
      key,
      "normalized signal key",
      "MALFORMED_INPUT",
    );

    const value = requireFiniteNumber(
      normalized.signals[key],
      `normalized signal ${signalKey}`,
      "MALFORMED_INPUT",
    );

    if (value < 0 || value > 1) {
      throw new DnaEngineError(
        "MALFORMED_INPUT",
        `Normalized signal ${signalKey} must be between 0 and 1.`,
      );
    }

    signals[signalKey] = value;
  }

  return {
    signals,
    profile_attributes: canonicalJsonObject(
      normalized.profile_attributes ?? {},
      "$.profile_attributes",
    ),
    provenance: canonicalJsonObject(
      normalized.provenance ?? {},
      "$.adapter_provenance",
    ),
  };
}

export function executeDnaEngine(
  request: DnaEngineRequest,
  registry: DnaAdapterRegistry,
): DnaEngineResult {
  validateRequest(request);

  const exactKey = adapterRegistryKey(
    request.adapter_key,
    request.adapter_version,
  );

  const adapter = registry[exactKey];

  if (!adapter) {
    const adapterKeyKnown = Object.values(registry).some(
      (candidate) =>
        candidate.adapter_key ===
          request.adapter_key,
    );

    throw new DnaEngineError(
      adapterKeyKnown ? "UNSUPPORTED_ADAPTER_VERSION" : "UNSUPPORTED_ADAPTER",
      adapterKeyKnown
        ? `Unsupported adapter version ${request.adapter_key}@${request.adapter_version}.`
        : `Unsupported adapter ${request.adapter_key}.`,
    );
  }

  let normalized: DnaNormalizedDomainInput;

  try {
    normalized = validateNormalizedInput(
      adapter.normalize(
        request.assessment,
      ),
    );
  } catch (error) {
    if (error instanceof DnaEngineError) {
      throw error;
    }

    throw new DnaEngineError(
      "ADAPTER_NORMALIZATION_FAILED",
      error instanceof Error ? error.message : String(error),
    );
  }

  const configuration = adapter.configuration;

  const dimensionScores: DnaDimensionScore[] = [];

  const scoreByDimension = new Map<string, number>();

  for (
    const dimension of [...configuration.dimensions].sort(
      (a, b) => compareStrings(a.key, b.key),
    )
  ) {
    let score = dimension.base_score;

    const contributions: DnaDimensionScore["contributions"] = [];

    for (
      const contribution of [...dimension.contributions].sort(
        (a, b) => compareStrings(a.signal_key, b.signal_key),
      )
    ) {
      const signalValue = normalized.signals[
        contribution.signal_key
      ] ?? 0;

      const weightedPoints = round(
        signalValue *
          contribution.weight,
      );

      score += weightedPoints;

      contributions.push({
        signal_key: contribution.signal_key,
        signal_value: round(signalValue),
        weight: round(contribution.weight),
        weighted_points: weightedPoints,
      });
    }

    const finalScore = round(
      clamp(
        score,
        dimension.min_score,
        dimension.max_score,
      ),
    );

    scoreByDimension.set(
      dimension.key,
      finalScore,
    );

    dimensionScores.push({
      key: dimension.key,
      score: finalScore,
      min_score: dimension.min_score,
      max_score: dimension.max_score,
      contributions,
    });
  }

  const concernSignals: DnaConcernSignal[] = [];

  for (
    const rule of [
      ...(
        configuration.concern_rules || []
      ),
    ].sort(
      (a, b) => compareStrings(a.key, b.key),
    )
  ) {
    const score = scoreByDimension.get(
      rule.dimension_key,
    );

    if (
      typeof score === "number" &&
      matchesThreshold(
        score,
        rule.operator,
        rule.threshold,
      )
    ) {
      concernSignals.push({
        key: rule.key,
        dimension_key: rule.dimension_key,
        score,
        operator: rule.operator,
        threshold: rule.threshold,
        severity: rule.severity,
      });
    }
  }

  const prioritySignals: DnaPrioritySignal[] = [];

  for (
    const rule of configuration.priority_rules || []
  ) {
    const score = scoreByDimension.get(
      rule.dimension_key,
    );

    if (
      typeof score === "number" &&
      matchesThreshold(
        score,
        rule.operator,
        rule.threshold,
      )
    ) {
      prioritySignals.push({
        key: rule.key,
        dimension_key: rule.dimension_key,
        score,
        operator: rule.operator,
        threshold: rule.threshold,
        priority: rule.priority,
      });
    }
  }

  prioritySignals.sort(
    (a, b) =>
      a.priority - b.priority ||
      compareStrings(a.key, b.key),
  );

  const observedRequiredSignals = configuration
    .required_signal_keys
    .filter(
      (key) =>
        typeof normalized.signals[key] ===
          "number",
    )
    .length;

  const totalRequiredSignals = configuration
    .required_signal_keys
    .length;

  const confidence = round(
    observedRequiredSignals /
      totalRequiredSignals,
  );

  const dimensions: Record<string, number> = {};

  for (const item of dimensionScores) {
    dimensions[item.key] = item.score;
  }

  const adapterProvenance = canonicalJsonObject(
    normalized.provenance ?? {},
    "$.adapter_provenance",
  );

  const profileAttributes = canonicalJsonObject(
    normalized.profile_attributes ?? {},
    "$.profile_attributes",
  );

  const fingerprintMaterial = {
    contract_version: request.contract_version,
    engine_version: request.engine_version,
    adapter_key: adapter.adapter_key,
    adapter_version: adapter.adapter_version,
    config_version: configuration.config_version,
    assessment: request.assessment,
    normalized_signals: normalized.signals,
  };

  return {
    ok: true,
    contract_version: DNA_ENGINE_CONTRACT_VERSION,
    engine_version: DNA_ENGINE_VERSION,
    domain: {
      domain_key: adapter.domain_key,
      adapter_key: adapter.adapter_key,
      adapter_version: adapter.adapter_version,
      config_version: configuration.config_version,
    },
    assessment: {
      assessment_id: request.assessment.assessment_id ?? null,
    },
    dimension_scores: dimensionScores,
    concern_signals: concernSignals,
    priority_signals: prioritySignals,
    confidence: {
      score: confidence,
      observed_required_signals: observedRequiredSignals,
      total_required_signals: totalRequiredSignals,
    },
    provenance: {
      deterministic: true,
      input_fingerprint: fnv1a32(
        stableStringify(
          fingerprintMaterial,
        ),
      ),
      contract_version: DNA_ENGINE_CONTRACT_VERSION,
      engine_version: DNA_ENGINE_VERSION,
      domain_key: adapter.domain_key,
      adapter_key: adapter.adapter_key,
      adapter_version: adapter.adapter_version,
      config_version: configuration.config_version,
      signal_keys: Object.keys(
        normalized.signals,
      ).sort(
        (a, b) => compareStrings(a, b),
      ),
      adapter_provenance: adapterProvenance,
    },
    profile: {
      domain_key: adapter.domain_key,
      dimensions,
      concerns: concernSignals.map(
        (item) => item.key,
      ),
      priorities: prioritySignals.map(
        (item) => item.key,
      ),
      confidence,
      attributes: profileAttributes,
    },
  };
}
