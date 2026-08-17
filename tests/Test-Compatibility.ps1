#requires -Version 7.4

[CmdletBinding()]
param([switch]$Quiet)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profiles = @(
    [ordered]@{
        id = 'ubuntu-web'
        source = 'D:\_Scripte\UbuntuVPS_Quiz\web'
        definitions = 305
        functions = 291
        commands = 63
        transformed = @(
            'legacy-ci.ps1',
            'modules/ci-commands-main.ps1',
            'modules/ci-core.ps1',
            'modules/toolchain-gradle.ps1',
            'modules/ui-commands.ps1',
            'modules/verify-logic.ps1'
        )
        transformed_function_bodies = @(
            'modules/ci-commands-main.ps1|cmd-bootstrap',
            'modules/ci-commands-main.ps1|cmd-openaiseedrunner',
            'modules/ci-core.ps1|cmd-patchapply',
            'modules/ci-core.ps1|read-immutablepins',
            'modules/toolchain-gradle.ps1|download-gradlezip',
            'modules/toolchain-gradle.ps1|ensure-localgradledist',
            'modules/ui-commands.ps1|ui-trywebbuild',
            'modules/verify-logic.ps1|invoke-selfcheck'
        )
    },
    [ordered]@{
        id = 'chess'
        source = 'D:\_Scripte\Chess'
        definitions = 328
        functions = 314
        commands = 67
        transformed = @(
            'legacy-ci.ps1',
            'modules/ci-commands-main.ps1',
            'modules/ci-core.ps1',
            'modules/sonar-logic.ps1',
            'modules/ui-commands.ps1',
            'modules/verify-logic.ps1',
            'start-sonar.ps1'
        )
        transformed_function_bodies = @(
            'modules/ci-commands-main.ps1|cmd-bootstrap',
            'modules/ci-core.ps1|cmd-patchapply',
            'modules/ci-core.ps1|read-immutablepins',
            'modules/sonar-logic.ps1|cmd-sonar',
            'modules/sonar-logic.ps1|resolve-sonarpreflightfailuresignature',
            'modules/ui-commands.ps1|ui-trywebbuild',
            'modules/verify-logic.ps1|invoke-selfcheck'
        )
    },
    [ordered]@{
        id = 'sound-profile'
        source = 'D:\_Scripte\Sound Profile'
        definitions = 292
        functions = 278
        commands = 59
        transformed = @(
            'legacy-ci.ps1',
            'modules/ci-commands-main.ps1',
            'modules/ci-core.ps1',
            'modules/toolchain-gradle.ps1',
            'modules/ui-commands.ps1',
            'modules/verify-logic.ps1'
        )
        transformed_function_bodies = @(
            'modules/ci-commands-main.ps1|cmd-bootstrap',
            'modules/ci-commands-main.ps1|get-defaultandroidsdkpath',
            'modules/ci-commands-main.ps1|new-tst450humanvisualreportlines',
            'modules/ci-core.ps1|cmd-patchapply',
            'modules/ci-core.ps1|read-immutablepins',
            'modules/toolchain-gradle.ps1|download-gradlezip',
            'modules/toolchain-gradle.ps1|ensure-localgradledist',
            'modules/ui-commands.ps1|ui-trywebbuild',
            'modules/verify-logic.ps1|invoke-selfcheck'
        )
    }
)

function Get-ParsedInventory {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][bool]$IsSource
    )

    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.ps1' -File | Sort-Object FullName)
    $functionRecords = [Collections.Generic.List[string]]::new()
    $functionBodyRecords = [Collections.Generic.List[object]]::new()
    $commandRecords = [Collections.Generic.List[string]]::new()
    $fileRecords = [Collections.Generic.List[object]]::new()
    $registerPattern = '(?im)^\s*Register-CiCommand\s+["'']([^"'']+)["'']\s*\{'
    $assignmentPattern = '(?im)^\s*\$script:CiCommands\s*\[\s*["'']([^"'']+)["'']\s*\]\s*=\s*\{'

    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        $mappedRelative = if ($IsSource -and $relative.Equals('ci.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            'legacy-ci.ps1'
        }
        else {
            $relative
        }
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if (@($errors).Count -gt 0) {
            throw "Parsefehler in $($file.FullName): $(@($errors.Message) -join ' | ')"
        }
        foreach ($node in @($ast.FindAll({
                        param($candidate)
                        $candidate -is [Management.Automation.Language.FunctionDefinitionAst]
                    }, $true))) {
            $parentFunction = '<top-level>'
            $parent = $node.Parent
            while ($null -ne $parent) {
                if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
                    $parentFunction = [string]$parent.Name
                    break
                }
                $parent = $parent.Parent
            }
            $parameters = if ($null -eq $node.Parameters) {
                ''
            }
            else {
                @($node.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath.ToLowerInvariant() }) -join ','
            }
            $functionKey = ('{0}|{1}|{2}|{3}' -f
                    $node.Name.ToLowerInvariant(),
                    $mappedRelative.ToLowerInvariant(),
                    $parentFunction.ToLowerInvariant(),
                    $parameters)
            $functionRecords.Add($functionKey)
            $normalizedBody = $node.Extent.Text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
            $bodyBytes = [Text.UTF8Encoding]::new($false).GetBytes($normalizedBody)
            $bodySha = [Security.Cryptography.SHA256]::Create()
            try {
                $bodyHash = -join ($bodySha.ComputeHash($bodyBytes) | ForEach-Object { $_.ToString('x2') })
            }
            finally {
                $bodySha.Dispose()
            }
            $functionBodyRecords.Add([pscustomobject]@{
                    Key = $functionKey
                    Name = $node.Name.ToLowerInvariant()
                    Relative = $mappedRelative.ToLowerInvariant()
                    Hash = $bodyHash
                })
        }

        $text = [IO.File]::ReadAllText($file.FullName)
        foreach ($match in [regex]::Matches($text, $registerPattern)) {
            $commandRecords.Add(('{0}|register|{1}' -f $match.Groups[1].Value.ToLowerInvariant(), $mappedRelative.ToLowerInvariant()))
        }
        foreach ($match in [regex]::Matches($text, $assignmentPattern)) {
            $commandRecords.Add(('{0}|assignment|{1}' -f $match.Groups[1].Value.ToLowerInvariant(), $mappedRelative.ToLowerInvariant()))
        }
        $fileRecords.Add([pscustomobject]@{
                Relative = $mappedRelative
                Path = $file.FullName
                Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            })
    }

    return [pscustomobject]@{
        Files = @($fileRecords)
        Functions = @($functionRecords | Sort-Object)
        FunctionBodies = @($functionBodyRecords | Sort-Object Key, Hash)
        Commands = @($commandRecords | Sort-Object)
    }
}

function Assert-UnchangedFunctionBodies {
    param(
        [Parameter(Mandatory)]$Source,
        [Parameter(Mandatory)]$Package,
        [Parameter(Mandatory)][string[]]$AllowedTransformations,
        [Parameter(Mandatory)][string]$ProfileId
    )

    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $AllowedTransformations) { $null = $allowed.Add($item) }
    foreach ($group in @($Source.FunctionBodies | Group-Object Key)) {
        $sample = $group.Group[0]
        $allowKey = "$($sample.Relative)|$($sample.Name)"
        if ($allowed.Contains($allowKey)) { continue }
        $sourceHashes = @($group.Group.Hash | Sort-Object)
        $packageHashes = @($Package.FunctionBodies | Where-Object Key -CEQ $group.Name | ForEach-Object Hash | Sort-Object)
        if (@(Compare-Object -ReferenceObject $sourceHashes -DifferenceObject $packageHashes).Count -gt 0) {
            throw "${ProfileId}: nicht freigegebene Aenderung eines Funktionskoerpers: $($group.Name)"
        }
    }
}

function Assert-TextContains {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Fragments,
        [Parameter(Mandatory)][string]$Label
    )

    $text = [IO.File]::ReadAllText($Path)
    foreach ($fragment in $Fragments) {
        if (-not $text.Contains($fragment, [StringComparison]::Ordinal)) {
            throw "${Label}: erforderliches Verhalten fehlt in $Path`: $fragment"
        }
    }
}

function Assert-MultisetEqual {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string[]]$Actual
    )

    $difference = @(Compare-Object -ReferenceObject @($Expected) -DifferenceObject @($Actual))
    if ($difference.Count -gt 0) {
        $sample = @($difference | Select-Object -First 20 | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join '; '
        throw "$Label stimmt nicht. Differenzen: $sample"
    }
}

try {
    $results = [Collections.Generic.List[object]]::new()
    foreach ($definition in $profiles) {
        $sourceBin = Join-Path ([string]$definition.source) '.ci\bin'
        $packageRoot = Join-Path $bootstrapRoot ("profiles\$($definition.id)\runtime\bin")
        if (-not (Test-Path -LiteralPath $sourceBin -PathType Container)) { throw "Quellruntime fehlt: $sourceBin" }
        if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) { throw "Profilruntime fehlt: $packageRoot" }

        $source = Get-ParsedInventory -Root $sourceBin -IsSource $true
        $package = Get-ParsedInventory -Root $packageRoot -IsSource $false
        Assert-MultisetEqual -Label "$($definition.id): Dateien" -Expected @($source.Files.Relative | Sort-Object) -Actual @($package.Files.Relative | Sort-Object)
        Assert-MultisetEqual -Label "$($definition.id): Funktionsdefinitionen/Topologie" -Expected $source.Functions -Actual $package.Functions
        Assert-MultisetEqual -Label "$($definition.id): Commandregistrierungen" -Expected $source.Commands -Actual $package.Commands
        Assert-UnchangedFunctionBodies -Source $source -Package $package -AllowedTransformations @($definition.transformed_function_bodies) -ProfileId ([string]$definition.id)

        $uiPath = Join-Path $packageRoot 'modules\ui-commands.ps1'
        $legacyPath = Join-Path $packageRoot 'legacy-ci.ps1'
        $allWebBuildFallbacks = @(
            ':ui-web:jsBrowserProductionWebpack',
            ':ui-web:browserProductionWebpack',
            ':ui-web:jsBrowserDevelopmentWebpack'
        )
        Assert-TextContains -Path $uiPath -Fragments $allWebBuildFallbacks -Label "$($definition.id): UI-Modul"
        Assert-TextContains -Path $legacyPath -Fragments $allWebBuildFallbacks -Label "$($definition.id): Legacy-Entrypoint"
        Assert-TextContains -Path (Join-Path $packageRoot 'modules\ci-core.ps1') -Fragments @(
            'CI_BOOTSTRAP_PREVERIFIED',
            'Cmd-PatchApply'
        ) -Label "$($definition.id): zentrale Integritaetsdelegation"
        Assert-TextContains -Path (Join-Path $packageRoot 'modules\verify-logic.ps1') -Fragments @(
            'immutable_runtime: central-preverified'
        ) -Label "$($definition.id): Self-Check"
        if ([string]$definition.id -in @('ubuntu-web', 'sound-profile')) {
            Assert-TextContains -Path (Join-Path $packageRoot 'modules\ci-commands-main.ps1') -Fragments @(
                'Cmd-Event $script:CiCommandArgs',
                'Cmd-Tick $script:CiCommandArgs'
            ) -Label "$($definition.id): Dispatcher-Argumente"
            Assert-TextContains -Path (Join-Path $packageRoot 'modules\toolchain-gradle.ps1') -Fragments @(
                '$dst + ".sha256"',
                'checksum service unavailable; using cached checksum',
                'Gradle inbox checksum mismatch'
            ) -Label "$($definition.id): Gradle-Verifikation"
        }
        if ([string]$definition.id -eq 'sound-profile') {
            Assert-TextContains -Path (Join-Path $packageRoot 'modules\ci-commands-main.ps1') -Fragments @(
                'function Cmd-PermissionTest',
                'Register-CiCommand "permission-test"',
                '$lane = if ($serial.StartsWith("emulator-"',
                'GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)',
                'Test-Tst450AdbTarget ([string]$env:ANDROID_SERIAL)'
            ) -Label 'sound-profile: aktueller Android-/Permission-Umfang'
        }

        $uniqueFunctions = @($package.Functions | ForEach-Object { ($_ -split '\|', 2)[0] } | Sort-Object -Unique)
        $uniqueCommands = @($package.Commands | ForEach-Object { ($_ -split '\|', 2)[0] } | Sort-Object -Unique)
        if ($package.Functions.Count -ne [int]$definition.definitions -or
            $uniqueFunctions.Count -ne [int]$definition.functions -or
            $uniqueCommands.Count -ne [int]$definition.commands) {
            throw "$($definition.id): erwartete Inventarzaehler wurden veraendert."
        }

        $transformed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($relative in @($definition.transformed)) { $null = $transformed.Add([string]$relative) }
        foreach ($sourceFile in $source.Files) {
            $packageFile = @($package.Files | Where-Object Relative -EQ $sourceFile.Relative)
            if ($packageFile.Count -ne 1) { throw "$($definition.id): Dateizuordnung ist nicht eindeutig: $($sourceFile.Relative)" }
            if (-not $transformed.Contains([string]$sourceFile.Relative) -and $sourceFile.Sha256 -ne $packageFile[0].Sha256) {
                throw "$($definition.id): nicht freigegebene Dateitransformation: $($sourceFile.Relative)"
            }
        }

        $profilePath = Join-Path $bootstrapRoot ("profiles\$($definition.id)\profile.json")
        $profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json
        $sourceEntry = Join-Path $sourceBin 'ci.ps1'
        if ((Get-FileHash -LiteralPath $sourceEntry -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$profile.source.entrypoint_sha256) {
            throw "$($definition.id): Quell-Entry-Point weicht von der erfassten Provenienz ab."
        }
        $sourceHeadLines = @(& git -C ([string]$definition.source) rev-parse HEAD 2>$null)
        $gitSucceeded = $?
        $sourceHead = @($sourceHeadLines | Select-Object -First 1)
        if (-not $gitSucceeded -or [string]$sourceHead -ne [string]$profile.source.git_commit) {
            throw "$($definition.id): Git-HEAD weicht von der erfassten Provenienz ab."
        }

        $catalog = Get-Content -Raw -LiteralPath (Join-Path $bootstrapRoot ("profiles\$($definition.id)\catalog\functions.json")) | ConvertFrom-Json
        $commandCatalog = Get-Content -Raw -LiteralPath (Join-Path $bootstrapRoot ("profiles\$($definition.id)\catalog\commands.json")) | ConvertFrom-Json
        if ([int]$catalog.definition_count -ne $package.Functions.Count -or
            [int]$catalog.unique_function_count -ne $uniqueFunctions.Count -or
            [int]$commandCatalog.command_count -ne $uniqueCommands.Count) {
            throw "$($definition.id): gespeicherte Katalogzaehler stimmen nicht mit dem Paket ueberein."
        }
        $results.Add([pscustomobject]@{
                profile = $definition.id
                definitions = $package.Functions.Count
                functions = $uniqueFunctions.Count
                commands = $uniqueCommands.Count
                topology = 'equal'
            })
    }

    $compatibility = Get-Content -Raw -LiteralPath (Join-Path $bootstrapRoot 'catalog\compatibility.json') | ConvertFrom-Json
    if ([int]$compatibility.union_function_count -ne 487 -or [int]$compatibility.union_command_count -ne 76) {
        throw 'Globale Vereinigungszaehler stimmen nicht (erwartet: 487 Funktionen, 76 Commands).'
    }
    if (-not $Quiet) {
        [pscustomobject]@{
            status = 'ok'
            union_functions = 487
            union_commands = 76
            profiles = @($results)
        } | ConvertTo-Json -Depth 8
    }
}
catch {
    [Console]::Error.WriteLine("[COMPATIBILITY] $($_.Exception.Message)")
    [Console]::Error.WriteLine($_.ScriptStackTrace)
    exit 1
}
