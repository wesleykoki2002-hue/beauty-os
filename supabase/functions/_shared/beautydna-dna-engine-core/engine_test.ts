import {
  createDnaAdapterRegistry,
  DNA_ENGINE_CONTRACT_VERSION,
  DNA_ENGINE_VERSION,
  DnaDomainAdapter,
  DnaEngineConfiguration,
  DnaEngineError,
  DnaEngineRequest,
  executeDnaEngine,
} from "./engine.ts";

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

function assertEngineError(
  fn: () => unknown,
  expectedCode: string,
): void {
  let thrown: unknown = null;

  try {
    fn();
  } catch (error) {
    thrown = error;
  }

  assert(
    thrown instanceof DnaEngineError,
    `Expected DnaEngineError ${expectedCode}.`,
  );

  assertEquals(
    thrown.code,
    expectedCode,
    `Unexpected DNA Engine error code.`,
  );
}

function readZeroToTen(
  value: unknown,
  label: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 10
  ) {
    throw new Error(
      `${label} must be between 0 and 10.`,
    );
  }

  return value / 10;
}

const syntheticAlpha: DnaDomainAdapter = {
  adapter_key: "synthetic-alpha",
  adapter_version: "v1",
  domain_key: "synthetic-domain-alpha",
  configuration: {
    config_version: "synthetic-alpha-config-v1",
    required_signal_keys: [
      "signal_a",
      "signal_b",
    ],
    dimensions: [
      {
        key: "dimension_balance",
        min_score: 0,
        max_score: 100,
        base_score: 10,
        contributions: [
          {
            signal_key: "signal_a",
            weight: 60,
          },
          {
            signal_key: "signal_b",
            weight: 30,
          },
        ],
      },
      {
        key: "dimension_resilience",
        min_score: 0,
        max_score: 100,
        base_score: 0,
        contributions: [
          {
            signal_key: "signal_b",
            weight: 100,
          },
        ],
      },
    ],
    concern_rules: [
      {
        key: "alpha-low-resilience",
        dimension_key: "dimension_resilience",
        operator: "lte",
        threshold: 40,
        severity: "medium",
      },
    ],
    priority_rules: [
      {
        key: "alpha-balance-priority",
        dimension_key: "dimension_balance",
        operator: "gte",
        threshold: 50,
        priority: 1,
      },
    ],
  },
  normalize(assessment) {
    return {
      signals: {
        signal_a: readZeroToTen(
          assessment.answers.a,
          "a",
        ),
        signal_b: readZeroToTen(
          assessment.answers.b,
          "b",
        ),
      },
      profile_attributes: {
        synthetic_segment: "alpha",
      },
      provenance: {
        source: "synthetic-alpha-test-fixture",
      },
    };
  },
};

const syntheticBeta: DnaDomainAdapter = {
  adapter_key: "synthetic-beta",
  adapter_version: "v3",
  domain_key: "synthetic-domain-beta",
  configuration: {
    config_version: "synthetic-beta-config-v2",
    required_signal_keys: [
      "left",
      "right",
    ],
    dimensions: [
      {
        key: "dimension_signal",
        min_score: 0,
        max_score: 100,
        base_score: 20,
        contributions: [
          {
            signal_key: "left",
            weight: 40,
          },
          {
            signal_key: "right",
            weight: 40,
          },
        ],
      },
    ],
    concern_rules: [
      {
        key: "beta-high-signal",
        dimension_key: "dimension_signal",
        operator: "gte",
        threshold: 80,
        severity: "info",
      },
    ],
    priority_rules: [
      {
        key: "beta-low-signal-priority",
        dimension_key: "dimension_signal",
        operator: "lte",
        threshold: 40,
        priority: 2,
      },
    ],
  },
  normalize(assessment) {
    if (
      typeof assessment.answers.left !==
        "boolean" ||
      typeof assessment.answers.right !==
        "boolean"
    ) {
      throw new Error(
        "left and right must be boolean.",
      );
    }

    return {
      signals: {
        left: assessment.answers.left ? 1 : 0,
        right: assessment.answers.right ? 1 : 0,
      },
      profile_attributes: {
        synthetic_segment: "beta",
      },
      provenance: {
        source: "synthetic-beta-test-fixture",
      },
    };
  },
};

const registry = createDnaAdapterRegistry([
  syntheticAlpha,
  syntheticBeta,
]);

function alphaRequest(): DnaEngineRequest {
  return {
    contract_version: DNA_ENGINE_CONTRACT_VERSION,
    engine_version: DNA_ENGINE_VERSION,
    adapter_key: "synthetic-alpha",
    adapter_version: "v1",
    assessment: {
      assessment_id: "synthetic-assessment-alpha",
      answers: {
        a: 8,
        b: 3,
      },
      context: {
        locale: "test",
      },
    },
  };
}

Deno.test(
  "deterministic execution returns identical versioned output",
  () => {
    const first = executeDnaEngine(
      alphaRequest(),
      registry,
    );

    const second = executeDnaEngine(
      alphaRequest(),
      registry,
    );

    assertEquals(
      first,
      second,
      "Identical input must produce identical output.",
    );

    assertEquals(
      first.provenance.input_fingerprint,
      second.provenance.input_fingerprint,
      "Input fingerprint must be deterministic.",
    );
  },
);

Deno.test(
  "successful output exposes engine domain and provenance versions",
  () => {
    const result = executeDnaEngine(
      alphaRequest(),
      registry,
    );

    assertEquals(
      result.contract_version,
      DNA_ENGINE_CONTRACT_VERSION,
      "Contract version missing.",
    );

    assertEquals(
      result.engine_version,
      DNA_ENGINE_VERSION,
      "Engine version missing.",
    );

    assertEquals(
      result.domain.adapter_key,
      "synthetic-alpha",
      "Adapter key missing.",
    );

    assertEquals(
      result.domain.adapter_version,
      "v1",
      "Adapter version missing.",
    );

    assertEquals(
      result.domain.config_version,
      "synthetic-alpha-config-v1",
      "Configuration version missing.",
    );

    assert(
      result.provenance.deterministic,
      "Deterministic provenance flag missing.",
    );
  },
);

Deno.test(
  "synthetic adapter A executes through generic engine",
  () => {
    const result = executeDnaEngine(
      alphaRequest(),
      registry,
    );

    assertEquals(
      result.profile.domain_key,
      "synthetic-domain-alpha",
      "Wrong synthetic domain.",
    );

    assertEquals(
      result.profile.dimensions,
      {
        dimension_balance: 67,
        dimension_resilience: 30,
      },
      "Unexpected alpha dimension scores.",
    );

    assertEquals(
      result.profile.concerns,
      [
        "alpha-low-resilience",
      ],
      "Unexpected alpha concerns.",
    );

    assertEquals(
      result.profile.priorities,
      [
        "alpha-balance-priority",
      ],
      "Unexpected alpha priorities.",
    );

    assertEquals(
      result.confidence.score,
      1,
      "Alpha confidence should be complete.",
    );
  },
);

Deno.test(
  "synthetic adapter B proves a structurally different domain",
  () => {
    const result = executeDnaEngine(
      {
        contract_version: DNA_ENGINE_CONTRACT_VERSION,
        engine_version: DNA_ENGINE_VERSION,
        adapter_key: "synthetic-beta",
        adapter_version: "v3",
        assessment: {
          assessment_id: "synthetic-assessment-beta",
          answers: {
            left: true,
            right: true,
          },
        },
      },
      registry,
    );

    assertEquals(
      result.profile.domain_key,
      "synthetic-domain-beta",
      "Wrong beta domain.",
    );

    assertEquals(
      result.profile.dimensions,
      {
        dimension_signal: 100,
      },
      "Unexpected beta dimension score.",
    );

    assertEquals(
      result.profile.concerns,
      [
        "beta-high-signal",
      ],
      "Unexpected beta concern output.",
    );
  },
);

Deno.test(
  "unsupported adapter fails closed",
  () => {
    const request = alphaRequest();

    request.adapter_key = "missing-adapter";

    assertEngineError(
      () =>
        executeDnaEngine(
          request,
          registry,
        ),
      "UNSUPPORTED_ADAPTER",
    );
  },
);

Deno.test(
  "unsupported adapter version fails closed",
  () => {
    const request = alphaRequest();

    request.adapter_version = "v999";

    assertEngineError(
      () =>
        executeDnaEngine(
          request,
          registry,
        ),
      "UNSUPPORTED_ADAPTER_VERSION",
    );
  },
);

Deno.test(
  "unsupported engine version fails closed",
  () => {
    const request = alphaRequest();

    request.engine_version = "beautydna-dna-engine-core-v999";

    assertEngineError(
      () =>
        executeDnaEngine(
          request,
          registry,
        ),
      "UNSUPPORTED_ENGINE_VERSION",
    );
  },
);

Deno.test(
  "unsupported contract version fails closed",
  () => {
    const request = alphaRequest();

    request.contract_version = "beautydna-dna-engine-core-contract-v999";

    assertEngineError(
      () =>
        executeDnaEngine(
          request,
          registry,
        ),
      "UNSUPPORTED_CONTRACT_VERSION",
    );
  },
);

Deno.test(
  "malformed input fails closed",
  () => {
    const request = alphaRequest();

    request.assessment.answers.a = Number.NaN;

    assertEngineError(
      () =>
        executeDnaEngine(
          request,
          registry,
        ),
      "MALFORMED_INPUT",
    );
  },
);

Deno.test(
  "adapter malformed normalized signal fails closed",
  () => {
    const malformedAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "malformed-normalized-output",
      normalize() {
        return {
          signals: {
            impossible: 2,
          },
        };
      },
    };

    const malformedRegistry = createDnaAdapterRegistry([
      malformedAdapter,
    ]);

    assertEngineError(
      () =>
        executeDnaEngine(
          {
            contract_version: DNA_ENGINE_CONTRACT_VERSION,
            engine_version: DNA_ENGINE_VERSION,
            adapter_key: "malformed-normalized-output",
            adapter_version: "v1",
            assessment: {
              answers: {},
            },
          },
          malformedRegistry,
        ),
      "MALFORMED_INPUT",
    );
  },
);

Deno.test(
  "malformed configuration fails closed",
  () => {
    const malformedAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "malformed-config",
      configuration: {
        ...syntheticAlpha.configuration,
        dimensions: [
          {
            key: "broken",
            min_score: 100,
            max_score: 0,
            base_score: 50,
            contributions: [],
          },
        ],
      },
    };

    assertEngineError(
      () =>
        createDnaAdapterRegistry([
          malformedAdapter,
        ]),
      "MALFORMED_CONFIGURATION",
    );
  },
);
Deno.test(
  "canonical execution ignores object insertion order",
  () => {
    const first = alphaRequest();
    const second = alphaRequest();

    first.assessment.context = {
      zeta: 1,
      alpha: 2,
    };

    second.assessment.context = {
      alpha: 2,
      zeta: 1,
    };

    assertEquals(
      executeDnaEngine(first, registry),
      executeDnaEngine(second, registry),
      "Semantically identical JSON must ignore object insertion order.",
    );
  },
);

Deno.test(
  "malformed optional assessment fields fail closed",
  () => {
    const badId = alphaRequest();
    (
      badId.assessment as unknown as Record<string, unknown>
    ).assessment_id = 42;

    assertEngineError(
      () => executeDnaEngine(badId, registry),
      "MALFORMED_INPUT",
    );

    const badContext = alphaRequest();
    (
      badContext.assessment as unknown as Record<string, unknown>
    ).context = "invalid";

    assertEngineError(
      () => executeDnaEngine(badContext, registry),
      "MALFORMED_INPUT",
    );

    const badMetadata = alphaRequest();
    (
      badMetadata.assessment as unknown as Record<string, unknown>
    ).metadata = false;

    assertEngineError(
      () => executeDnaEngine(badMetadata, registry),
      "MALFORMED_INPUT",
    );
  },
);

Deno.test(
  "malformed optional rule collections fail closed",
  () => {
    const malformedConcernAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "malformed-concern-collection",
      configuration: {
        ...syntheticAlpha.configuration,
        concern_rules: {},
      } as unknown as DnaEngineConfiguration,
    };

    assertEngineError(
      () => createDnaAdapterRegistry([malformedConcernAdapter]),
      "MALFORMED_CONFIGURATION",
    );

    const malformedPriorityAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "malformed-priority-collection",
      configuration: {
        ...syntheticAlpha.configuration,
        priority_rules: {},
      } as unknown as DnaEngineConfiguration,
    };

    assertEngineError(
      () => createDnaAdapterRegistry([malformedPriorityAdapter]),
      "MALFORMED_CONFIGURATION",
    );
  },
);

Deno.test(
  "registry snapshots configuration against later caller mutation",
  () => {
    const mutableConfiguration: DnaEngineConfiguration = {
      config_version: "snapshot-config-v1",
      required_signal_keys: ["signal"],
      dimensions: [
        {
          key: "snapshot_dimension",
          min_score: 0,
          max_score: 100,
          base_score: 0,
          contributions: [
            {
              signal_key: "signal",
              weight: 50,
            },
          ],
        },
      ],
    };

    const mutableAdapter: DnaDomainAdapter = {
      adapter_key: "snapshot-adapter",
      adapter_version: "v1",
      domain_key: "snapshot-domain",
      configuration: mutableConfiguration,
      normalize() {
        return {
          signals: {
            signal: 1,
          },
        };
      },
    };

    const snapshotRegistry = createDnaAdapterRegistry([mutableAdapter]);

    mutableConfiguration.dimensions[0].base_score = 100;
    mutableConfiguration.dimensions[0].contributions[0].weight = 100;

    const result = executeDnaEngine(
      {
        contract_version: DNA_ENGINE_CONTRACT_VERSION,
        engine_version: DNA_ENGINE_VERSION,
        adapter_key: "snapshot-adapter",
        adapter_version: "v1",
        assessment: {
          answers: {},
        },
      },
      snapshotRegistry,
    );

    assertEquals(
      result.profile.dimensions,
      {
        snapshot_dimension: 50,
      },
      "Registered configuration must be isolated from later mutation.",
    );
  },
);

Deno.test(
  "malformed adapter metadata objects fail closed",
  () => {
    const badProfileAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "bad-profile-metadata",
      normalize() {
        return {
          signals: {
            signal_a: 0.5,
            signal_b: 0.5,
          },
          profile_attributes: [] as unknown as Record<string, never>,
        };
      },
    };

    const badProfileRegistry = createDnaAdapterRegistry([badProfileAdapter]);

    assertEngineError(
      () =>
        executeDnaEngine(
          {
            contract_version: DNA_ENGINE_CONTRACT_VERSION,
            engine_version: DNA_ENGINE_VERSION,
            adapter_key: "bad-profile-metadata",
            adapter_version: "v1",
            assessment: {
              answers: {},
            },
          },
          badProfileRegistry,
        ),
      "MALFORMED_INPUT",
    );

    const badProvenanceAdapter: DnaDomainAdapter = {
      ...syntheticAlpha,
      adapter_key: "bad-provenance-metadata",
      normalize() {
        return {
          signals: {
            signal_a: 0.5,
            signal_b: 0.5,
          },
          provenance: "invalid" as unknown as Record<string, never>,
        };
      },
    };

    const badProvenanceRegistry = createDnaAdapterRegistry([
      badProvenanceAdapter,
    ]);

    assertEngineError(
      () =>
        executeDnaEngine(
          {
            contract_version: DNA_ENGINE_CONTRACT_VERSION,
            engine_version: DNA_ENGINE_VERSION,
            adapter_key: "bad-provenance-metadata",
            adapter_version: "v1",
            assessment: {
              answers: {},
            },
          },
          badProvenanceRegistry,
        ),
      "MALFORMED_INPUT",
    );
  },
);
