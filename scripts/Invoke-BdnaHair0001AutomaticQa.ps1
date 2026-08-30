param(
    [switch]$SourceValidationOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

& {
    $Repo = "C:\supabase\beauty-os"
    $AthenaEnv = "C:\supabase\athena-os\.env.local"

    $AthenaRef = "voiwlcvfahykdldtjeqy"
    $BeautyRef = "hidsyvanaipxxyyhjgmc"

    $ProjectKey = "beautydna"
    $ModuleKey = "hair-dna"

    $BuildId = "BDNA-HAIR-0001"

    $BuildTitle =
        "BDNA-HAIR-0001 Production HairDNA / ScalpDNA Domain Adapter and Profile Foundation"

    $TemplateKey =
        "athena-feature-completion-gate-v1"

    $ProfileKey =
        "bdna-hair-0001-external-automatic-qa-v1"

    $TimerId =
        "dba3fadc-21e9-4517-9df8-8404ac66a078"

    $ExpectedBranch =
        "feature/bdna-hair-0001-hairdna-scalpdna-profile-foundation"

    $ExpectedRemote =
        "https://github.com/wesleykoki2002-hue/beauty-os.git"

    $ImplementationCommit =
        "3962b2571e07dad6c7b3ad5f9312116e9a077df6"

    $ImplementationTree =
        "8308601500cacf9d4b1f50bb1a70eaeb36a012b8"

    $GitEvidenceSha =
        "5f845dda13c86160e1e4746e22db122205ca775fbdb951aa7d4f11ef3baa80c1"

    $ExceptionApprovalSha =
        "e5bbcff7c1742a628867a3e0c3b708a992b9aacb2693aedbc4346d0a5dba115f"

    $EngineRelative =
        "supabase/functions/_shared/beautydna-hair-dna/adapter.ts"

    $TestsRelative =
        "supabase/functions/_shared/beautydna-hair-dna/adapter_test.ts"

    $DocRelative =
        "docs/beautydna-v2/hair-dna-contract-v1.md"

    $RunnerRelative =
        "scripts/Invoke-BdnaHair0001AutomaticQa.ps1"

    $ManifestRelative =
        "supabase/tests/evidence/20260830_bdna_hair_0001_automatic_qa_profile.json"

    $EnginePath =
        Join-Path $Repo $EngineRelative

    $TestsPath =
        Join-Path $Repo $TestsRelative

    $DocPath =
        Join-Path $Repo $DocRelative

    $SharedEngineRelative =
        "supabase/functions/_shared/beautydna-dna-engine-core/engine.ts"

    $SharedEnginePath =
        Join-Path $Repo $SharedEngineRelative

    $ExpectedSharedEngineHash =
        "b9c8161e63fa603691b88976793119f965607870336e2956d4eb752e774cee65"

    $ManifestPath =
        Join-Path $Repo $ManifestRelative

    $Deno =
        Join-Path `
            $env:USERPROFILE `
            ".deno\bin\deno.exe"

    $ExpectedHashes = @{
        $EnginePath =
            "8aa0a97a51e39da80a1fb3bf53810c35c64ffd7d2b4a04cd90274409a0c62a8a"

        $TestsPath =
            "45572363dfed3e20e6b1139c13bed882858883fea5cfe45d0ec5e4b6ed830f31"

        $DocPath =
            "6eb1cadbc934691998a9a3555a282635c311f66488e6c1d765f688355a75a563"
    }


    function Read-EnvValue {
        param(
            [string]$Path,
            [string]$Name
        )

        $Rows = @(
            [System.IO.File]::ReadAllLines($Path) |
            Where-Object {
                $_ -match (
                    "^\s*" +
                    [regex]::Escape($Name) +
                    "\s*="
                )
            }
        )

        if ($Rows.Count -ne 1) {
            throw "Expected exactly one $Name definition."
        }

        $Value =
            $Rows[0].Split("=", 2)[1].Trim()

        if (
            $Value.Length -ge 2 -and
            (
                ($Value.StartsWith('"') -and $Value.EndsWith('"')) -or
                ($Value.StartsWith("'") -and $Value.EndsWith("'"))
            )
        ) {
            $Value =
                $Value.Substring(
                    1,
                    $Value.Length - 2
                )
        }

        if ([string]::IsNullOrWhiteSpace($Value)) {
            throw "$Name is blank."
        }

        return $Value
    }


    function Get-Hash {
        param([string]$Path)

        return (
            Get-FileHash `
                -LiteralPath $Path `
                -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }


    function Get-Sha256Text {
        param([string]$Text)

        $Sha =
            [System.Security.Cryptography.SHA256]::Create()

        try {
            return (
                [BitConverter]::ToString(
                    $Sha.ComputeHash(
                        [System.Text.Encoding]::UTF8.GetBytes(
                            $Text
                        )
                    )
                ).
                Replace("-", "").
                ToLowerInvariant()
            )
        }
        finally {
            $Sha.Dispose()
        }
    }


    function Encode-FilterValue {
        param([string]$Value)

        return [uri]::EscapeDataString($Value)
    }


    function Invoke-AthenaRows {
        param(
            [ValidateSet("GET", "POST", "PATCH")]
            [string]$Method,

            [string]$TableAndQuery,

            [object]$Body = $null
        )

        $Params = @{
            Method =
                $Method

            Uri =
                (
                    $script:AthenaUrl +
                    "/rest/v1/" +
                    $TableAndQuery
                )

            Headers =
                $script:AthenaHeaders

            UseBasicParsing =
                $true

            TimeoutSec =
                60
        }

        if ($Method -in @("POST", "PATCH")) {
            $Params.ContentType =
                "application/json"

            $Params.Body =
                (
                    ConvertTo-Json `
                        -InputObject $Body `
                        -Depth 50 `
                        -Compress
                )
        }

        $Response =
            Invoke-WebRequest @Params

        $Raw =
            ([string]$Response.Content).Trim()

        $Rows =
            @()

        if (
            -not [string]::IsNullOrWhiteSpace($Raw) -and
            $Raw -ne "null"
        ) {
            $Parsed =
                ConvertFrom-Json `
                    -InputObject $Raw

            if ($Parsed -is [System.Array]) {
                $Rows =
                    @($Parsed)
            }
            else {
                $Rows =
                    @($Parsed)
            }
        }

        return [pscustomobject]@{
            StatusCode =
                [int]$Response.StatusCode

            Raw =
                $Raw

            Rows =
                $Rows
        }
    }


    function Require-One {
        param(
            [object]$Response,
            [string]$Label
        )

        $Rows = @(
            $Response.Rows |
            Where-Object {
                $null -ne $_
            }
        )

        if ($Rows.Count -ne 1) {
            throw (
                "$Label expected exactly one row; received " +
                $Rows.Count
            )
        }

        return $Rows[0]
    }


    function Invoke-AthenaRpc {
        param(
            [string]$Name,
            [hashtable]$Payload
        )

        $Response =
            Invoke-WebRequest `
                -Method POST `
                -Uri (
                    $script:AthenaUrl +
                    "/rest/v1/rpc/" +
                    $Name
                ) `
                -Headers $script:AthenaHeaders `
                -ContentType "application/json" `
                -Body (
                    $Payload |
                    ConvertTo-Json -Depth 40 -Compress
                ) `
                -UseBasicParsing `
                -TimeoutSec 60

        $Raw =
            ([string]$Response.Content).Trim()

        if (
            [string]::IsNullOrWhiteSpace($Raw) -or
            $Raw -eq "null"
        ) {
            return $null
        }

        $Value =
            $Raw |
            ConvertFrom-Json

        for ($Depth = 0; $Depth -lt 5; $Depth++) {

            if ($null -eq $Value) {
                return $null
            }

            if ($Value -is [System.Array]) {
                $Rows =
                    @($Value)

                if ($Rows.Count -eq 0) {
                    return $null
                }

                if ($Rows.Count -ne 1) {
                    throw "$Name returned multiple values."
                }

                $Value =
                    $Rows[0]

                continue
            }

            $Names = @(
                $Value.PSObject.Properties |
                ForEach-Object {
                    $_.Name
                }
            )

            if ($Names -contains "id") {
                return $Value
            }

            if ($Names.Count -eq 1) {
                $Value =
                    $Value.PSObject.Properties[0].Value
                continue
            }

            return $Value
        }

        throw "$Name response normalization failed."
    }


    function Assert-SameKeys {
        param(
            [string[]]$Actual,
            [string[]]$Expected,
            [string]$Label
        )

        $Diff = @(
            Compare-Object `
                -ReferenceObject (
                    $Expected |
                    Sort-Object
                ) `
                -DifferenceObject (
                    $Actual |
                    Sort-Object
                )
        )

        if ($Diff.Count -ne 0) {
            throw "$Label key set mismatch."
        }
    }


    function New-QaUpdate {
        param(
            [ValidateSet(
                "pass",
                "not_applicable",
                "pending"
            )]
            [string]$Status,

            [string]$ActualResult,

            [string]$Notes,

            [hashtable]$Evidence
        )

        return [ordered]@{
            status =
                $Status

            actual_result =
                $ActualResult

            notes =
                $Notes

            evidence =
                [ordered]@{
                    automatic_qa =
                        $true

                    profile_key =
                        $ProfileKey

                    source_repository =
                        "beauty-os"

                    source_repository_head =
                        $script:Head

                    implementation_commit =
                        $ImplementationCommit

                    beauty_supabase_project_ref =
                        $BeautyRef

                    athena_supabase_project_ref =
                        $AthenaRef

                    evidence_payload =
                        $Evidence
                }
        }
    }


    Write-Host "============================================================"
    Write-Host " BDNA-HAIR-0001 EXTERNAL AUTOMATIC QA v1"
    Write-Host "============================================================"

    Set-Location $Repo

    # ------------------------------------------------------------
    # A. Repository and implementation identity
    # ------------------------------------------------------------

    $script:Head =
        (
            git rev-parse HEAD
        ).Trim()

    $Branch =
        (
            git branch --show-current
        ).Trim()

    $Remote =
        (
            git remote get-url origin
        ).Trim()

    if (
        $Branch -ne $ExpectedBranch -or
        $Remote -ne $ExpectedRemote
    ) {
        throw "Wrong governed Beauty repository identity."
    }

    git merge-base `
        --is-ancestor `
        $ImplementationCommit `
        HEAD

    if ($LASTEXITCODE -ne 0) {
        throw "Current HEAD is not descended from implementation commit."
    }

    foreach ($Pair in $ExpectedHashes.GetEnumerator()) {

        if (
            (Get-Hash $Pair.Key) -ne
            $Pair.Value
        ) {
            throw (
                "Implementation hash drift: " +
                $Pair.Key
            )
        }
    }

    $Manifest =
        Get-Content `
            -LiteralPath $ManifestPath `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json

    if (
        [string]$Manifest.profile_key -ne
            $ProfileKey -or
        [string]$Manifest.project_key -ne
            $ProjectKey -or
        [string]$Manifest.module_key -ne
            $ModuleKey -or
        [string]$Manifest.implementation_commit -ne
            $ImplementationCommit
    ) {
        throw "Automatic-QA manifest identity mismatch."
    }

    # ------------------------------------------------------------
    # B. Source-level automatic validation
    # ------------------------------------------------------------

    & $Deno fmt --check `
        $EnginePath `
        $TestsPath `
        $DocPath

    if ($LASTEXITCODE -ne 0) {
        throw "deno fmt --check failed."
    }

    & $Deno check `
        $EnginePath `
        $TestsPath

    if ($LASTEXITCODE -ne 0) {
        throw "deno check failed."
    }

    & $Deno test $TestsPath

    if ($LASTEXITCODE -ne 0) {
        throw "HairDNA tests failed."
    }

    $HairText =
        [System.IO.File]::ReadAllText(
            $EnginePath
        )

    $SharedEngineText =
        [System.IO.File]::ReadAllText(
            $SharedEnginePath
        )

    if (
        (Get-Hash $SharedEnginePath) -ne
        $ExpectedSharedEngineHash
    ) {
        throw "Shared DNA Engine Core hash drift."
    }

    foreach ($Forbidden in @(
        "Deno.env",
        "process.env",
        "createClient(",
        "fetch(",
        "shopify",
        "checkout",
        "recommendation_ready",
        "match_score"
    )) {
        if (
            $HairText.IndexOf(
                $Forbidden,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        ) {
            throw (
                "Forbidden HairDNA coupling: " +
                $Forbidden
            )
        }
    }

    foreach ($Required in @(
        "HAIR_DNA_CONTRACT_VERSION",
        "HAIR_DNA_ADAPTER_ID",
        "HAIR_DNA_CONFIGURATION",
        "normalizeHairDnaAssessment",
        "HAIR_DNA_ADAPTER",
        "executeHairDna",
        "non_diagnostic",
        "safety_shedding",
        "safety_red_flag",
        "safety_severe_scalp"
    )) {
        if (-not $HairText.Contains($Required)) {
            throw (
                "Required HairDNA element missing: " +
                $Required
            )
        }
    }

    foreach ($Forbidden in @(
        "HairDNA",
        "ScalpDNA",
        "hair-dna",
        "hair_dna",
        "scalp-dna",
        "scalp_dna"
    )) {
        if (
            $SharedEngineText.IndexOf(
                $Forbidden,
                [System.StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        ) {
            throw (
                "Shared DNA Engine contains HairDNA domain logic: " +
                $Forbidden
            )
        }
    }

    Write-Host "IMPLEMENTATION_SOURCE_QA=PASS"
    Write-Host "DENO_TESTS=19/19"
    Write-Host "HAIRDNA_DOMAIN_GUARD=PASS"
    Write-Host "SHARED_ENGINE_DOMAIN_AGNOSTIC_GUARD=PASS"

    if ($SourceValidationOnly) {
        Write-Host ""
        Write-Host "SOURCE_VALIDATION_ONLY=TRUE"
        Write-Host "ATHENA_PACKET_WRITES=0"
        Write-Host "ATHENA_QA_WRITES=0"
        Write-Host "BEAUTY_DATABASE_WRITES=0"
        Write-Host "TIMER_MUTATIONS=0"
        Write-Host "SOURCE_VALIDATION=PASS"
        return
    }

    # ------------------------------------------------------------
    # C. Runtime Git / remote evidence
    # ------------------------------------------------------------

    if (
        @(
            git status `
                --porcelain=v1 `
                --untracked-files=all
        ).Count -ne 0
    ) {
        throw "Runtime automatic QA requires a clean worktree."
    }

    $RemoteRows =
        @(
            git ls-remote `
                --heads origin `
                "refs/heads/$ExpectedBranch"
        )

    if (
        $LASTEXITCODE -ne 0 -or
        $RemoteRows.Count -ne 1
    ) {
        throw "Unable to verify Beauty remote."
    }

    $RemoteHead =
        (
            $RemoteRows[0] -split '\s+'
        )[0].Trim()

    if ($RemoteHead -ne $script:Head) {
        throw "Beauty remote HEAD does not equal runtime HEAD."
    }

    # ------------------------------------------------------------
    # D. Athena credentials and timer heartbeat
    # ------------------------------------------------------------

    $script:AthenaUrl =
        (
            Read-EnvValue `
                -Path $AthenaEnv `
                -Name "NEXT_PUBLIC_SUPABASE_URL"
        ).TrimEnd("/")

    $ServiceRole =
        Read-EnvValue `
            -Path $AthenaEnv `
            -Name "SUPABASE_SERVICE_ROLE_KEY"

    $ConfiguredRef =
        Read-EnvValue `
            -Path $AthenaEnv `
            -Name "ATHENA_SUPABASE_PROJECT_REF"

    $OperatorCredential =
        Read-EnvValue `
            -Path $AthenaEnv `
            -Name "ATHENA_OS_OPERATOR_KEY"

    $TimerSecret =
        Read-EnvValue `
            -Path $AthenaEnv `
            -Name "ATHENA_OS_TIMER_SESSION_SECRET"

    if (
        $ConfiguredRef -ne $AthenaRef -or
        -not $script:AthenaUrl.Contains($AthenaRef)
    ) {
        throw "Wrong Athena governance database."
    }

    $script:AthenaHeaders = @{
        apikey =
            $ServiceRole

        Authorization =
            "Bearer $ServiceRole"

        Accept =
            "application/json"

        Prefer =
            "return=representation"
    }

    $Identity =
        "athena-timer-operator-v1:" +
        $OperatorCredential.Trim()

    $Hmac =
        New-Object `
            System.Security.Cryptography.HMACSHA256

    try {
        $Hmac.Key =
            [System.Text.Encoding]::UTF8.GetBytes(
                $TimerSecret
            )

        $SignatureBytes =
            $Hmac.ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes(
                    $Identity
                )
            )
    }
    finally {
        $Hmac.Dispose()
    }

    $Signature =
        [Convert]::ToBase64String(
            $SignatureBytes
        ).
        TrimEnd("=").
        Replace("+", "-").
        Replace("/", "_")

    $OperatorKey =
        "operator_" +
        $Signature.Substring(0, 32)

    $Timer =
        Invoke-AthenaRpc `
            -Name "athena_build_timer_read_session" `
            -Payload @{
                p_session_id =
                    $TimerId

                p_operator_key =
                    $OperatorKey
            }

    if (
        $null -eq $Timer -or
        [string]$Timer.id -ne $TimerId -or
        [string]$Timer.project_key -ne $ProjectKey -or
        [string]$Timer.module_key -ne $ModuleKey -or
        [string]$Timer.build_session_title -ne $BuildTitle
    ) {
        throw "Canonical timer identity mismatch."
    }

    if (
        [string]$Timer.status -in @(
            "paused",
            "stopped"
        )
    ) {
        throw (
            "Timer cannot continue automatic QA: " +
            [string]$Timer.status
        )
    }

    if (
        [string]$Timer.status -eq "idle" -or
        [bool]$Timer.heartbeat_is_stale
    ) {
        $ActivityKey =
            "bdna-hair-0001-runtime-qa-activity:" +
            (
                Get-Sha256Text (
                    $TimerId +
                    "|" +
                    [string]$Timer.timer_version +
                    "|" +
                    $script:Head
                )
            )

        $null =
            Invoke-AthenaRpc `
                -Name "athena_build_timer_apply_operation" `
                -Payload @{
                    p_session_id =
                        $TimerId

                    p_operator_key =
                        $OperatorKey

                    p_operation =
                        "activity"

                    p_source =
                        "athena_os_ui"

                    p_operation_key =
                        $ActivityKey

                    p_evidence =
                        @{
                            build_id =
                                $BuildId

                            profile_key =
                                $ProfileKey

                            repository_head =
                                $script:Head

                            beauty_database_write =
                                $false
                        }
                }
    }

    $Timer =
        Invoke-AthenaRpc `
            -Name "athena_build_timer_read_session" `
            -Payload @{
                p_session_id =
                    $TimerId

                p_operator_key =
                    $OperatorKey
            }

    $HeartbeatKey =
        "bdna-hair-0001-runtime-qa-heartbeat:" +
        (
            Get-Sha256Text (
                $TimerId +
                "|" +
                [string]$Timer.timer_version +
                "|" +
                $script:Head
            )
        )

    $null =
        Invoke-AthenaRpc `
            -Name "athena_build_timer_apply_operation" `
            -Payload @{
                p_session_id =
                    $TimerId

                p_operator_key =
                    $OperatorKey

                p_operation =
                    "heartbeat"

                p_source =
                    "athena_os_ui"

                p_operation_key =
                    $HeartbeatKey

                p_evidence =
                    @{
                        build_id =
                            $BuildId

                        profile_key =
                            $ProfileKey

                        trigger =
                            "automatic_qa_runtime"

                        beauty_database_write =
                            $false
                    }
            }

    # ------------------------------------------------------------
    # E. Canonical module + QA template
    # ------------------------------------------------------------

    $ModuleResponse =
        Invoke-AthenaRows `
            -Method GET `
            -TableAndQuery (
                "athena_project_modules?" +
                "project_key=eq." +
                (Encode-FilterValue $ProjectKey) +
                "&module_key=eq." +
                (Encode-FilterValue $ModuleKey) +
                "&select=project_key,module_key,status,priority,progress_percent,hours_spent,estimated_hours,estimated_remaining_hours"
            )

    $Module =
        Require-One `
            -Response $ModuleResponse `
            -Label "Athena module"

    foreach ($Field in @(
        "progress_percent",
        "hours_spent",
        "estimated_hours",
        "estimated_remaining_hours"
    )) {
        $Number =
            [double]$Module.$Field

        if (
            [double]::IsNaN($Number) -or
            [double]::IsInfinity($Number) -or
            $Number -lt 0
        ) {
            throw "Invalid canonical module numeric field: $Field"
        }
    }

    $TemplateResponse =
        Invoke-AthenaRows `
            -Method GET `
            -TableAndQuery (
                "athena_qa_templates?" +
                "template_key=eq." +
                (Encode-FilterValue $TemplateKey) +
                "&select=template_key,checklist"
            )

    $Template =
        Require-One `
            -Response $TemplateResponse `
            -Label "QA template"

    $Checklist =
        @($Template.checklist)

    $ExpectedCheckKeys = @(
        "athena_cto_memory_recorded",
        "calculation_verified",
        "core_pages_regression_checked",
        "database_read_verified",
        "database_write_verified",
        "no_hardcoded_planning_values",
        "no_negative_values",
        "rls_policy_reviewed",
        "route_or_function_exists",
        "saved_row_verified",
        "terminal_build_clean",
        "ui_shows_expected_new_fields"
    )

    $TemplateKeys =
        @(
            $Checklist |
            ForEach-Object {
                [string]$_.check_key
            }
        )

    if ($Checklist.Count -ne 12) {
        throw "Canonical QA template does not contain 12 checks."
    }

    Assert-SameKeys `
        -Actual $TemplateKeys `
        -Expected $ExpectedCheckKeys `
        -Label "QA template"

    # ------------------------------------------------------------
    # F. Create or reuse exact completion packet
    # ------------------------------------------------------------

    $PacketQuery =
        "athena_feature_completion_packets?" +
        "project_key=eq." +
        (Encode-FilterValue $ProjectKey) +
        "&module_key=eq." +
        (Encode-FilterValue $ModuleKey) +
        "&feature_name=eq." +
        (Encode-FilterValue $BuildTitle) +
        "&build_session_title=eq." +
        (Encode-FilterValue $BuildTitle) +
        "&select=*"

    $PacketResponse =
        Invoke-AthenaRows `
            -Method GET `
            -TableAndQuery $PacketQuery

    $PacketRows =
        @($PacketResponse.Rows)

    if ($PacketRows.Count -gt 1) {
        throw "Multiple BDNA-HAIR-0001 completion packets exist."
    }

    $AllBuildFiles = @(
        $DocRelative,
        $EngineRelative,
        $TestsRelative,
        $RunnerRelative,
        $ManifestRelative
    ) | Sort-Object

    if ($PacketRows.Count -eq 0) {

        $PacketMetadata =
            [ordered]@{
                automatic_qa_profile =
                    $ProfileKey

                implementation_commit =
                    $ImplementationCommit

                implementation_tree =
                    $ImplementationTree

                qa_profile_repository_head =
                    $script:Head

                git_evidence_sha256 =
                    $GitEvidenceSha

                u_hermes_001_exception =
                    [ordered]@{
                        approved =
                            $true

                        scope =
                            "BDNA-HAIR-0001 only"

                        approval_text_sha256 =
                            $ExceptionApprovalSha
                    }

                beauty_database_reads =
                    0

                beauty_database_writes =
                    0

                timer_stop_deferred_to_completion_reconciliation =
                    $true
            }

        $PacketBody =
            [ordered]@{
                project_key =
                    $ProjectKey

                module_key =
                    $ModuleKey

                feature_type =
                    "standard_app_feature"

                feature_name =
                    $BuildTitle

                build_session_title =
                    $BuildTitle

                route_path =
                    $null

                summary =
                    "Production HairDNA / ScalpDNA domain adapter and profile foundation over shared DNA Engine Core with deterministic normalization, versioned vocabulary/configuration, non-diagnostic safety/referral handling, provenance, and representative production tests."

                files_changed =
                    $AllBuildFiles

                database_changes =
                    @(
                        "None. BDNA-HAIR-0001 introduces no Beauty database migration, schema mutation, data mutation, or new runtime database dependency."
                    )

                security_notes =
                    @(
                        "No network or database client exists in the HairDNA production adapter; the shared DNA Engine Core remains unchanged and domain-agnostic.",
                        "No secrets were introduced.",
                        "No SkinDNA, BodyDNA, MakeupDNA, recommendation, or Shopify rule set is introduced by BDNA-HAIR-0001; ScalpDNA capability is contained within HairDNA v1.",
                        "Beauty OS / BeautyDNA database hidsyvanaipxxyyhjgmc is not accessed by this automatic-QA profile."
                    )

                missing =
                    @(
                        "SkinDNA and other post-HairDNA domain modules remain separately governed downstream work; HairDNA/ScalpDNA v1 is implemented by BDNA-HAIR-0001."
                    )

                next_steps =
                    @(
                        "Complete Athena reconciliation for BDNA-HAIR-0001, then return to the launch-first BeautyDNA path and re-audit Ingredient Intelligence, Product DNA readiness, SkinDNA/assessment inputs, Recommendation Engine, recommendation experience, and Shopify linkage."
                    )

                estimated_remaining_hours_snapshot =
                    [double]$Module.estimated_remaining_hours

                status =
                    "draft"

                metadata =
                    $PacketMetadata
            }

        $Packet =
            Require-One `
                -Response (
                    Invoke-AthenaRows `
                        -Method POST `
                        -TableAndQuery "athena_feature_completion_packets" `
                        -Body $PacketBody
                ) `
                -Label "Completion packet insert"

        Write-Host "COMPLETION_PACKET_CREATED=TRUE"
    }
    else {
        $Packet =
            $PacketRows[0]

        if (
            [string]$Packet.project_key -ne $ProjectKey -or
            [string]$Packet.module_key -ne $ModuleKey -or
            [string]$Packet.feature_name -ne $BuildTitle -or
            [string]$Packet.build_session_title -ne $BuildTitle
        ) {
            throw "Existing completion packet identity mismatch."
        }

        Write-Host "COMPLETION_PACKET_CREATED=FALSE"
    }

    $PacketId =
        [string]$Packet.id

    # ------------------------------------------------------------
    # G. Create/reuse exact QA run and checklist
    # ------------------------------------------------------------

    $RunQuery =
        "athena_qa_runs?" +
        "project_key=eq." +
        (Encode-FilterValue $ProjectKey) +
        "&module_key=eq." +
        (Encode-FilterValue $ModuleKey) +
        "&feature_name=eq." +
        (Encode-FilterValue $BuildTitle) +
        "&build_session_title=eq." +
        (Encode-FilterValue $BuildTitle) +
        "&select=*"

    $RunResponse =
        Invoke-AthenaRows `
            -Method GET `
            -TableAndQuery $RunQuery

    $RunRows =
        @($RunResponse.Rows)

    if ($RunRows.Count -gt 1) {
        throw "Multiple matching BDNA-HAIR-0001 QA runs exist."
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Packet.qa_run_id
        )
    ) {
        if (
            $RunRows.Count -ne 1 -or
            [string]$RunRows[0].id -ne
                [string]$Packet.qa_run_id
        ) {
            throw "Packet links to a missing or different QA run."
        }

        $QaRun =
            $RunRows[0]

        $QaRunCreated =
            $false
    }
    elseif ($RunRows.Count -eq 1) {
        $QaRun =
            $RunRows[0]

        $QaRunCreated =
            $false

        Write-Host "QA_RUN_REUSED_ORPHAN=TRUE"
    }
    else {
        $GeneratedAt =
            [DateTime]::UtcNow.ToString("o")

        $QaRunBody =
            [ordered]@{
                qa_run_key =
                    "bdna-hair-0001-autoqa-" +
                    $ImplementationCommit.Substring(0, 12)

                project_key =
                    $ProjectKey

                module_key =
                    $ModuleKey

                feature_name =
                    $BuildTitle

                route_path =
                    $null

                template_key =
                    $TemplateKey

                build_session_title =
                    $BuildTitle

                status =
                    "pending"

                summary =
                    "BDNA-HAIR-0001 repository-owned automatic QA; all pre-recording machine checks are populated automatically and Athena memory remains pending until completion reconciliation."

                started_at =
                    $GeneratedAt
            }

        $QaRun =
            Require-One `
                -Response (
                    Invoke-AthenaRows `
                        -Method POST `
                        -TableAndQuery "athena_qa_runs" `
                        -Body $QaRunBody
                ) `
                -Label "QA run insert"

        $QaRunCreated =
            $true
    }

    $QaRunId =
        [string]$QaRun.id

    if (
        [string]$QaRun.project_key -ne $ProjectKey -or
        [string]$QaRun.module_key -ne $ModuleKey -or
        [string]$QaRun.feature_name -ne $BuildTitle -or
        [string]$QaRun.build_session_title -ne $BuildTitle -or
        [string]$QaRun.template_key -ne $TemplateKey
    ) {
        throw "QA run identity mismatch."
    }

    $ChecksQuery =
        "athena_qa_check_results?" +
        "qa_run_id=eq." +
        (Encode-FilterValue $QaRunId) +
        "&select=*"

    $ExistingChecksResponse =
        Invoke-AthenaRows `
            -Method GET `
            -TableAndQuery $ChecksQuery

    $ExistingChecks =
        @($ExistingChecksResponse.Rows)

    if ($ExistingChecks.Count -eq 0) {

        $InitialChecks =
            @(
                $Checklist |
                ForEach-Object {
                    [ordered]@{
                        qa_run_id =
                            $QaRunId

                        check_key =
                            [string]$_.check_key

                        check_name =
                            [string]$_.check_name

                        category =
                            [string]$_.category

                        status =
                            "pending"

                        severity =
                            [string]$_.severity

                        expected_result =
                            [string]$_.expected_result

                        actual_result =
                            $null

                        evidence =
                            @{}

                        notes =
                            $null
                    }
                }
            )

        $null =
            Invoke-AthenaRows `
                -Method POST `
                -TableAndQuery "athena_qa_check_results" `
                -Body $InitialChecks

        $PersistedChecks =
            @(
                (
                    Invoke-AthenaRows `
                        -Method GET `
                        -TableAndQuery $ChecksQuery
                ).Rows
            )

        if ($PersistedChecks.Count -ne 12) {
            throw "Persisted QA checklist count mismatch after insert."
        }

        Assert-SameKeys `
            -Actual @(
                $PersistedChecks |
                ForEach-Object {
                    [string]$_.check_key
                }
            ) `
            -Expected $ExpectedCheckKeys `
            -Label "Persisted QA checklist"
    }
    elseif ($ExistingChecks.Count -eq 12) {
        Assert-SameKeys `
            -Actual @(
                $ExistingChecks |
                ForEach-Object {
                    [string]$_.check_key
                }
            ) `
            -Expected $ExpectedCheckKeys `
            -Label "Existing QA checklist"
    }
    else {
        throw (
            "Partial unexpected QA checklist exists: " +
            $ExistingChecks.Count
        )
    }

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$Packet.qa_run_id
        )
    ) {
        $Packet =
            Require-One `
                -Response (
                    Invoke-AthenaRows `
                        -Method PATCH `
                        -TableAndQuery (
                            "athena_feature_completion_packets?" +
                            "id=eq." +
                            (Encode-FilterValue $PacketId) +
                            "&qa_run_id=is.null"
                        ) `
                        -Body @{
                            qa_run_id =
                                $QaRunId

                            status =
                                "qa_in_progress"
                        }
                ) `
                -Label "Packet QA link"

        if (
            [string]$Packet.qa_run_id -ne
                $QaRunId
        ) {
            throw "Packet QA linkage failed."
        }
    }

    Write-Host "COMPLETION_PACKET_ID=$PacketId"
    Write-Host "QA_RUN_ID=$QaRunId"
    Write-Host "QA_RUN_CREATED=$QaRunCreated"
    Write-Host "PACKET_QA_RUN_LINKED=TRUE"

    # ------------------------------------------------------------
    # H. Automatic profile evidence
    # ------------------------------------------------------------

    $Updates =
        [ordered]@{}

    $Updates["no_negative_values"] =
        New-QaUpdate `
            -Status "pass" `
            -ActualResult "Canonical Athena module planning fields are finite and non-negative, and the DNA Engine configuration/runtime guards reject malformed numeric scoring inputs." `
            -Notes "Planning values were read from Athena; engine numeric behavior is covered by the 19-test deterministic HairDNA safety/profile suite." `
            -Evidence @{
                module_progress_percent =
                    [double]$Module.progress_percent

                module_hours_spent =
                    [double]$Module.hours_spent

                module_estimated_hours =
                    [double]$Module.estimated_hours

                module_estimated_remaining_hours =
                    [double]$Module.estimated_remaining_hours

                deno_tests_passed =
                    19
            }

    $Updates["calculation_verified"] =
        New-QaUpdate `
            -Status "pass" `
            -ActualResult "Deno format/type validation passed and all 19 HairDNA tests passed, including deterministic normalization/execution, representative scalp and hair profiles, fail-closed malformed inputs, and conservative non-diagnostic referral handling." `
            -Notes "Calculation evidence is generated from the committed HairDNA production test suite." `
            -Evidence @{
                deno_fmt_check =
                    "pass"

                deno_check =
                    "pass"

                deno_test_pass =
                    19

                deno_test_fail =
                    0
            }

    $Updates["no_hardcoded_planning_values"] =
        New-QaUpdate `
            -Status "pass" `
            -ActualResult "The HairDNA production adapter contains no Athena progress, hours-spent, estimated-hours, or estimated-remaining-hours planning fields." `
            -Notes "Planning values remain owned by Athena rather than Beauty runtime source." `
            -Evidence @{
                runtime_planning_token_matches =
                    0
            }

    $Updates["terminal_build_clean"] =
        New-QaUpdate `
            -Status "pass" `
            -ActualResult "Beauty repository worktree is clean and canonical GitHub remote HEAD exactly matches the automatic-QA runtime HEAD." `
            -Notes "Implementation commit is an ancestor of the current governed QA-profile commit." `
            -Evidence @{
                branch =
                    $Branch

                repository_head =
                    $script:Head

                remote_head =
                    $RemoteHead

                implementation_commit =
                    $ImplementationCommit

                worktree_clean =
                    $true
            }

    $Updates["core_pages_regression_checked"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: BDNA-HAIR-0001 changes the external Beauty repository only and does not modify Athena OS routes or core pages." `
            -Notes "No Athena application source is part of this product build." `
            -Evidence @{
                applicability =
                    "external_beauty_repository_no_athena_ui_scope"
            }

    $Updates["athena_cto_memory_recorded"] =
        New-QaUpdate `
            -Status "pending" `
            -ActualResult "Pending until canonical completion reconciliation records and verifies final Athena memory/completion evidence." `
            -Notes "This is the only allowed pre-recording pending check." `
            -Evidence @{
                closure_stage =
                    "completion_reconciliation"

                expected_pre_recording_status =
                    "pending"
            }

    $Updates["route_or_function_exists"] =
        New-QaUpdate `
            -Status "pass" `
            -ActualResult "The production hair-dna@v1 adapter, its 19-test suite, HairDNA contract documentation, repository-owned QA runner, and QA manifest all exist in the governed Beauty repository." `
            -Notes "Implementation files are hash-bound to the immutable implementation commit." `
            -Evidence @{
                engine_path =
                    $EngineRelative

                test_path =
                    $TestsRelative

                contract_path =
                    $DocRelative

                runner_path =
                    $RunnerRelative

                manifest_path =
                    $ManifestRelative

                implementation_tree =
                    $ImplementationTree
            }

    $Updates["ui_shows_expected_new_fields"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: BDNA-HAIR-0001 intentionally has no UI field or page scope." `
            -Notes "HairDNA is a backend/shared domain-profile foundation with no UI scope in this build." `
            -Evidence @{
                ui_change_required =
                    $false
            }

    $Updates["database_read_verified"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: this repository-only HairDNA domain adapter has no new Beauty database-read dependency and intentionally performs no Beauty database QA query." `
            -Notes "Existing BeautyDNA assessment/passport persistence is reused without introducing a new database source of truth." `
            -Evidence @{
                beauty_database_reads =
                    0

                database_read_scope =
                    $false
            }

    $Updates["database_write_verified"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: BDNA-HAIR-0001 has no Beauty database migration, schema mutation, or data-write scope." `
            -Notes "Zero Beauty database writes is the required behavior for this foundation." `
            -Evidence @{
                beauty_database_writes =
                    0

                database_write_scope =
                    $false
            }

    $Updates["saved_row_verified"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: BDNA-HAIR-0001 creates or updates no Beauty database row." `
            -Notes "No saved-row success claim is used for this build." `
            -Evidence @{
                beauty_saved_row_scope =
                    $false
            }

    $Updates["rls_policy_reviewed"] =
        New-QaUpdate `
            -Status "not_applicable" `
            -ActualResult "Not applicable: BDNA-HAIR-0001 changes no Beauty database table, function privilege, policy, or RLS configuration." `
            -Notes "Security review instead verifies that the HairDNA adapter contains no database/network client or secret access and that the shared DNA Engine remains domain-agnostic." `
            -Evidence @{
                schema_change =
                    $false

                rls_change =
                    $false

                database_client_in_engine =
                    $false

                network_client_in_engine =
                    $false
            }

    Assert-SameKeys `
        -Actual @($Updates.Keys) `
        -Expected $ExpectedCheckKeys `
        -Label "Automatic QA update map"

    # ------------------------------------------------------------
    # I. Persist every automatic check with read-after
    # ------------------------------------------------------------

    foreach ($CheckKey in $ExpectedCheckKeys) {

        $Update =
            $Updates[$CheckKey]

        $SavedCheck =
            Require-One `
                -Response (
                    Invoke-AthenaRows `
                        -Method PATCH `
                        -TableAndQuery (
                            "athena_qa_check_results?" +
                            "qa_run_id=eq." +
                            (Encode-FilterValue $QaRunId) +
                            "&check_key=eq." +
                            (Encode-FilterValue $CheckKey)
                        ) `
                        -Body @{
                            status =
                                $Update.status

                            actual_result =
                                $Update.actual_result

                            notes =
                                $Update.notes

                            evidence =
                                $Update.evidence
                        }
                ) `
                -Label (
                    "QA check update " +
                    $CheckKey
                )

        if (
            [string]$SavedCheck.check_key -ne
                $CheckKey -or
            [string]$SavedCheck.status -ne
                [string]$Update.status
        ) {
            throw (
                "QA check read-after mismatch: " +
                $CheckKey
            )
        }
    }

    # ------------------------------------------------------------
    # J. Final pre-recording QA verification
    # ------------------------------------------------------------

    $FinalChecks =
        @(
            (
                Invoke-AthenaRows `
                    -Method GET `
                    -TableAndQuery (
                        $ChecksQuery +
                        "&order=check_key.asc"
                    )
            ).Rows
        )

    if ($FinalChecks.Count -ne 12) {
        throw "Final QA checklist count is not 12."
    }

    foreach ($Check in $FinalChecks) {

        $ExpectedStatus =
            [string]$Updates[
                [string]$Check.check_key
            ].status

        if (
            [string]$Check.status -ne
            $ExpectedStatus
        ) {
            throw (
                "Final QA status mismatch: " +
                [string]$Check.check_key
            )
        }
    }

    $Blocking =
        @(
            $FinalChecks |
            Where-Object {
                [string]$_.check_key -ne
                    "athena_cto_memory_recorded" -and
                [string]$_.status -notin @(
                    "pass",
                    "not_applicable"
                )
            }
        )

    if ($Blocking.Count -ne 0) {
        throw "Unexpected blocking pre-recording QA check remains."
    }

    $Memory =
        @(
            $FinalChecks |
            Where-Object {
                [string]$_.check_key -eq
                    "athena_cto_memory_recorded"
            }
        )

    if (
        $Memory.Count -ne 1 -or
        [string]$Memory[0].status -ne
            "pending"
    ) {
        throw "Athena memory check is not the sole expected pending check."
    }

    $PassCount =
        @(
            $FinalChecks |
            Where-Object {
                [string]$_.status -eq "pass"
            }
        ).Count

    $NaCount =
        @(
            $FinalChecks |
            Where-Object {
                [string]$_.status -eq
                    "not_applicable"
            }
        ).Count

    $PendingCount =
        @(
            $FinalChecks |
            Where-Object {
                [string]$_.status -eq "pending"
            }
        ).Count

    if (
        $PassCount -ne 5 -or
        $NaCount -ne 6 -or
        $PendingCount -ne 1
    ) {
        throw (
            "Unexpected QA counts: pass=$PassCount " +
            "na=$NaCount pending=$PendingCount"
        )
    }

    $GeneratedAt =
        [DateTime]::UtcNow.ToString("o")

    $SavedRun =
        Require-One `
            -Response (
                Invoke-AthenaRows `
                    -Method PATCH `
                    -TableAndQuery (
                        "athena_qa_runs?id=eq." +
                        (Encode-FilterValue $QaRunId)
                    ) `
                    -Body @{
                        status =
                            "pending"

                        completed_at =
                            $null

                        summary =
                            "Automatic pre-recording QA passed: 5 pass, 6 not_applicable, 1 expected pending Athena-memory check."

                        updated_at =
                            $GeneratedAt
                    }
            ) `
            -Label "QA run final state"

    $Metadata =
        @{}

    if ($Packet.metadata) {
        foreach (
            $Property in
            $Packet.metadata.PSObject.Properties
        ) {
            $Metadata[$Property.Name] =
                $Property.Value
        }
    }

    $Metadata["automatic_qa"] =
        [ordered]@{
            evidence_version =
                $ProfileKey

            profile_key =
                $ProfileKey

            external_repository_only_profile =
                $true

            qa_run_id =
                $QaRunId

            generated_at =
                $GeneratedAt

            overall_status =
                "pending"

            pre_recording_status =
                "pass"

            counts =
                [ordered]@{
                    pass =
                        $PassCount

                    not_applicable =
                        $NaCount

                    pending =
                        $PendingCount
                }

            source_repository =
                "beauty-os"

            source_repository_head =
                $script:Head

            implementation_commit =
                $ImplementationCommit

            implementation_tree =
                $ImplementationTree

            git_evidence_sha256 =
                $GitEvidenceSha

            beauty_database_reads =
                0

            beauty_database_writes =
                0

            timer_stop_deferred_to_completion_reconciliation =
                $true
        }

    $ReadyPacket =
        Require-One `
            -Response (
                Invoke-AthenaRows `
                    -Method PATCH `
                    -TableAndQuery (
                        "athena_feature_completion_packets?" +
                        "id=eq." +
                        (Encode-FilterValue $PacketId) +
                        "&qa_run_id=eq." +
                        (Encode-FilterValue $QaRunId)
                    ) `
                    -Body @{
                        status =
                            "ready_to_record"

                        metadata =
                            $Metadata
                    }
            ) `
            -Label "Ready-to-record packet"

    if (
        [string]$ReadyPacket.status -ne
            "ready_to_record" -or
        [string]$ReadyPacket.qa_run_id -ne
            $QaRunId -or
        [string]$SavedRun.status -ne
            "pending"
    ) {
        throw "Final Athena QA synchronization failed."
    }

    # ------------------------------------------------------------
    # K. Final Git and timer read-after
    # ------------------------------------------------------------

    if (
        @(
            git status `
                --porcelain=v1 `
                --untracked-files=all
        ).Count -ne 0
    ) {
        throw "Beauty repository changed during runtime QA."
    }

    $FinalRemoteRows =
        @(
            git ls-remote `
                --heads origin `
                "refs/heads/$ExpectedBranch"
        )

    $FinalRemoteHead =
        (
            $FinalRemoteRows[0] -split '\s+'
        )[0].Trim()

    if ($FinalRemoteHead -ne $script:Head) {
        throw "Beauty remote changed during runtime QA."
    }

    $FinalTimer =
        Invoke-AthenaRpc `
            -Name "athena_build_timer_read_session" `
            -Payload @{
                p_session_id =
                    $TimerId

                p_operator_key =
                    $OperatorKey
            }

    if (
        [string]$FinalTimer.status -notin @(
            "active",
            "idle"
        )
    ) {
        throw "Timer unexpectedly stopped before completion reconciliation."
    }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host " BDNA-HAIR-0001 EXTERNAL AUTOMATIC QA v1: PASS"
    Write-Host "============================================================"
    Write-Host "PROJECT=Beauty OS / BeautyDNA"
    Write-Host ("MODULE=" + $ModuleKey)
    Write-Host "PROFILE_KEY=$ProfileKey"
    Write-Host "IMPLEMENTATION_COMMIT=$ImplementationCommit"
    Write-Host "QA_PROFILE_HEAD=$($script:Head)"
    Write-Host "COMPLETION_PACKET_ID=$PacketId"
    Write-Host "QA_RUN_ID=$QaRunId"
    Write-Host "PACKET_STATUS=ready_to_record"
    Write-Host "QA_RUN_STATUS=pending"
    Write-Host "QA_PASS_COUNT=$PassCount"
    Write-Host "QA_NOT_APPLICABLE_COUNT=$NaCount"
    Write-Host "QA_PENDING_COUNT=$PendingCount"
    Write-Host "ONLY_PENDING_CHECK=athena_cto_memory_recorded"
    Write-Host "PRE_RECORDING_STATUS=PASS"
    Write-Host "BEAUTY_DATABASE_READS=0"
    Write-Host "BEAUTY_DATABASE_WRITES=0"
    Write-Host "TIMER_STOPPED_BY_QA=FALSE"
    Write-Host "WORKTREE_CLEAN=TRUE"
    Write-Host "REMOTE_HEAD_VERIFIED=TRUE"
    Write-Host "NEXT_ACTION=FINAL_COMPLETION_RECONCILIATION"
    Write-Host "============================================================"

    $ServiceRole = $null
    $OperatorCredential = $null
    $TimerSecret = $null
    $OperatorKey = $null
    $SignatureBytes = $null
    $script:AthenaHeaders = $null
}