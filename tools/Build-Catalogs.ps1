#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profileDefinitions = @(
    [ordered]@{
        id = 'ubuntu-web'
        display_name = 'Ubuntu VPS Quiz – Web'
        description = 'Node/Vite-Webprofil mit gehärtetem Legacy-Preloader, Seed-Runner und UI-/Release-Gates.'
        source_root = 'D:\_Scripte\UbuntuVPS_Quiz\web'
        git_commit = '31e53354f0c50292c00dda94c30efeea46513512'
        entrypoint_sha256 = '6c7dfa9d408b879d3bf3d350f29b2182f224f91dfc058b42e85ba98339d0a54b'
        transformations = @(
            'ImmutableBaseFiles und ImmutableRequiredBaseFiles auf Runtime-Code begrenzt; mutable Projektartefakte werden nicht gepinnt.',
            'Der Legacy-Preloader und die Legacy-Pin-Autoritaet werden nur bei zentral gesetztem CI_BOOTSTRAP_PREVERIFIED=1 uebersprungen.',
            'Cmd-Bootstrap erzeugt im zentral verifizierten Modus keine Legacy-Pins.',
            'Event- und Tick-Argumente werden ueber den persistenten Dispatcher-Kontext weitergereicht.',
            'Gradle-Distributionen werden vor Cache-Nutzung und Publikation zwingend per SHA-256 verifiziert; ein zuvor verifizierter lokaler Checksum-Sidecar erhaelt den Offline-Betrieb.',
            'Self-Check und Patch-Apply delegieren die Runtime-Integritaet im zentralen Modus an den Bootstrap.',
            'Die doppelt erhaltene UI-Build-Funktion behaelt in beiden Definitionen alle drei historischen Build-Fallbacks.',
            'OPENAI_API_KEY_FILE kann den historisch erhaltenen Standardpfad portabel ueberschreiben.'
        )
    },
    [ordered]@{
        id = 'chess'
        display_name = 'Chess'
        description = 'Kotlin-Multiplatform-/Webprofil mit Android-, Viewport-, Git-ACL-, Sonar- und Roadmap-Autogrow-Funktionen.'
        source_root = 'D:\_Scripte\Chess'
        git_commit = 'fef812316c54be6d9170f7d63712b823671c4586'
        entrypoint_sha256 = '4a7f93191dd744e57f4b9b6bc915844c939cf8d8c74a481e4f86c4a168922d4e'
        transformations = @(
            'Legacy-Pin-Autoritaet wird nur bei zentral gesetztem CI_BOOTSTRAP_PREVERIFIED=1 deaktiviert.',
            'Cmd-Bootstrap erzeugt im zentral verifizierten Modus keine Legacy-Pins.',
            'Das SonarQube-Startskript wird relativ zum installierten Projekt aufgeloest.',
            'Die zwei PowerShell-7-Ternaerausdruecke der Sonar-Fehlersignatur sind verhaltensgleich fuer den dokumentierten PowerShell-5.1-Fallback formuliert.',
            'Self-Check und Patch-Apply delegieren die Runtime-Integritaet im zentralen Modus an den Bootstrap.',
            'Die doppelt erhaltene UI-Build-Funktion behaelt in beiden Definitionen alle drei historischen Build-Fallbacks.'
        )
    },
    [ordered]@{
        id = 'sound-profile'
        display_name = 'Sound Profile'
        description = 'Natives Android-Profil mit Berechtigungs-, Sonar- und Human-Visual-Supertest-Ablauf.'
        source_root = 'D:\_Scripte\Sound Profile'
        git_commit = '7d6ad8f9eb0d6de1874554e15f4234ae0ba98cfa'
        entrypoint_sha256 = 'fb095ea0b3be2d81c95e24781820d43ca89ef70e4ae97655ae8ebB51b4c6024b'.ToLowerInvariant()
        transformations = @(
            'Legacy-Pin-Autoritaet wird nur bei zentral gesetztem CI_BOOTSTRAP_PREVERIFIED=1 deaktiviert.',
            'Cmd-Bootstrap erzeugt im zentral verifizierten Modus keine Legacy-Pins.',
            'Event- und Tick-Argumente werden ueber den persistenten Dispatcher-Kontext weitergereicht.',
            'Der Android-SDK-Standardpfad wird benutzerunabhaengig aus LocalApplicationData ermittelt.',
            'Gradle-Distributionen werden vor Cache-Nutzung und Publikation zwingend per SHA-256 verifiziert; ein zuvor verifizierter lokaler Checksum-Sidecar erhaelt den Offline-Betrieb.',
            'Self-Check und Patch-Apply delegieren die Runtime-Integritaet im zentralen Modus an den Bootstrap.',
            'Die doppelt erhaltene UI-Build-Funktion behaelt in beiden Definitionen alle drei historischen Build-Fallbacks.',
            'Permission-Test, vollstaendiger STP-Handoff sowie Todo-Checkpoint-v2, Rotation, Rebuild und History-Digest entsprechen dem aktuellen Quellstand.'
        )
    }
)

function Get-TextSha256 {
    param([Parameter(Mandatory)][string]$Text)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($normalized)
        return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $sha.Dispose()
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 30
    [IO.File]::WriteAllText($Path, $json + "`n", [Text.UTF8Encoding]::new($false))
}

function Get-ParsedFiles {
    param([Parameter(Mandatory)][string]$ProfileRoot)

    $runtimeRoot = Join-Path $ProfileRoot 'runtime'
    $files = @(Get-ChildItem -LiteralPath $runtimeRoot -Recurse -Filter '*.ps1' -File | Sort-Object FullName)
    $parsed = [Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )
        if (@($parseErrors).Count -gt 0) {
            $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
            throw "PowerShell-Parsefehler in $($file.FullName): $messages"
        }
        $parsed.Add([pscustomobject]@{
                File = $file
                Relative = [IO.Path]::GetRelativePath($ProfileRoot, $file.FullName).Replace('\', '/')
                Ast = $ast
            })
    }
    return @($parsed)
}

function Get-FunctionCatalog {
    param(
        [Parameter(Mandatory)][string]$ProfileId,
        [Parameter(Mandatory)][object[]]$ParsedFiles
    )

    $definitions = [Collections.Generic.List[object]]::new()
    foreach ($parsed in $ParsedFiles) {
        $nodes = $parsed.Ast.FindAll({
                param($node)
                return $node -is [Management.Automation.Language.FunctionDefinitionAst]
            }, $true)
        foreach ($node in $nodes) {
            $definitions.Add([pscustomobject]@{
                    name = [string]$node.Name
                    file = [string]$parsed.Relative
                    line = [int]$node.Extent.StartLineNumber
                    sha256 = Get-TextSha256 $node.Extent.Text
                })
        }
    }

    $functions = foreach ($group in @($definitions | Group-Object { $_.name.ToLowerInvariant() } | Sort-Object Name)) {
        $hashes = @($group.Group.sha256 | Sort-Object -Unique)
        [ordered]@{
            name = [string]$group.Group[0].name
            definition_count = $group.Count
            implementation_count = $hashes.Count
            conflicting_implementations = $hashes.Count -gt 1
            definitions = @($group.Group | Sort-Object file, line)
        }
    }

    return [ordered]@{
        schema = 'workflow-bootstrap-function-catalog/v1'
        profile = $ProfileId
        generated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        source_file_count = $ParsedFiles.Count
        definition_count = $definitions.Count
        unique_function_count = @($functions).Count
        functions = @($functions)
    }
}

function Get-CommandCatalog {
    param(
        [Parameter(Mandatory)][string]$ProfileId,
        [Parameter(Mandatory)][object[]]$ParsedFiles
    )

    $origins = [Collections.Generic.List[object]]::new()
    $registerPattern = '(?im)^\s*Register-CiCommand\s+["'']([^"'']+)["'']\s*\{([^\r\n}]*)'
    $assignmentPattern = '(?im)^\s*\$script:CiCommands\s*\[\s*["'']([^"'']+)["'']\s*\]\s*=\s*\{([^\r\n}]*)'

    foreach ($parsed in $ParsedFiles) {
        $text = [IO.File]::ReadAllText($parsed.File.FullName)
        foreach ($match in [regex]::Matches($text, $registerPattern)) {
            $line = 1 + ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count
            $origins.Add([pscustomobject]@{
                    name = $match.Groups[1].Value.ToLowerInvariant()
                    file = $parsed.Relative
                    line = $line
                    kind = 'register'
                    implementation = $match.Groups[2].Value.Trim()
                })
        }
        foreach ($match in [regex]::Matches($text, $assignmentPattern)) {
            $line = 1 + ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count
            $origins.Add([pscustomobject]@{
                    name = $match.Groups[1].Value.ToLowerInvariant()
                    file = $parsed.Relative
                    line = $line
                    kind = 'assignment'
                    implementation = $match.Groups[2].Value.Trim()
                })
        }
    }

    $commands = foreach ($group in @($origins | Group-Object name | Sort-Object Name)) {
        $orderedOrigins = @($group.Group | Sort-Object file, line, kind)
        [ordered]@{
            name = [string]$group.Name
            origin = (($orderedOrigins | ForEach-Object { "$($_.file):$($_.line)" }) -join ', ')
            implementation = (($orderedOrigins.implementation | Where-Object { $_ } | Sort-Object -Unique) -join ' | ')
            registration_count = $group.Count
            origins = $orderedOrigins
        }
    }

    return [ordered]@{
        schema = 'workflow-bootstrap-command-catalog/v1'
        profile = $ProfileId
        generated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        command_count = @($commands).Count
        commands = @($commands)
    }
}

$profileResults = [Collections.Generic.List[object]]::new()
foreach ($definition in $profileDefinitions) {
    $profileRoot = Join-Path $bootstrapRoot ("profiles\" + $definition.id)
    $profileManifestPath = Join-Path $profileRoot 'profile.json'
    if ((Test-Path -LiteralPath $profileManifestPath -PathType Leaf) -and -not $Force) {
        throw "Profil-Release existiert bereits und wird nicht ueberschrieben: $profileManifestPath. Bewusst mit -Force neu bauen."
    }
    $parsedFiles = @(Get-ParsedFiles $profileRoot)
    $functionCatalog = Get-FunctionCatalog -ProfileId $definition.id -ParsedFiles $parsedFiles
    $commandCatalog = Get-CommandCatalog -ProfileId $definition.id -ParsedFiles $parsedFiles
    Write-JsonFile -Path (Join-Path $profileRoot 'catalog\functions.json') -Value $functionCatalog
    Write-JsonFile -Path (Join-Path $profileRoot 'catalog\commands.json') -Value $commandCatalog

    $payload = [Collections.Generic.List[object]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $profileRoot 'runtime') -Recurse -File | Sort-Object FullName)) {
        $source = [IO.Path]::GetRelativePath($profileRoot, $file.FullName).Replace('\', '/')
        $runtimeRelative = [IO.Path]::GetRelativePath((Join-Path $profileRoot 'runtime'), $file.FullName).Replace('\', '/')
        $destination = '.ci/' + $runtimeRelative
        $role = if ($file.Name -eq 'legacy-ci.ps1') {
            'profile-entrypoint'
        }
        elseif ($source -match '/modules/') {
            'profile-module'
        }
        else {
            'profile-helper'
        }
        $payload.Add([ordered]@{
                source = $source
                destination = $destination
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                size = [long]$file.Length
                role = $role
            })
    }

    $profile = [ordered]@{
        schema = 'workflow-bootstrap-profile/v1'
        id = $definition.id
        version = '1.0.0'
        display_name = $definition.display_name
        description = $definition.description
        source = [ordered]@{
            project_root = $definition.source_root
            git_commit = $definition.git_commit
            captured_utc = [DateTimeOffset]::UtcNow.ToString('o')
            entrypoint_sha256 = $definition.entrypoint_sha256
        }
        transformations = @($definition.transformations)
        default_config = 'config.default.json'
        function_catalog = 'catalog/functions.json'
        command_catalog = 'catalog/commands.json'
        payload = @($payload)
    }
    Write-JsonFile -Path (Join-Path $profileRoot 'profile.json') -Value $profile
    $profileResults.Add([pscustomobject]@{
            Definition = $definition
            Functions = $functionCatalog
            Commands = $commandCatalog
            Profile = $profile
        })
}

$unionFunctions = foreach ($group in @(
        $profileResults | ForEach-Object {
            $profileId = $_.Definition.id
            foreach ($function in $_.Functions.functions) {
                [pscustomobject]@{
                    name = [string]$function.name
                    profile = $profileId
                    implementation_hashes = @($function.definitions.sha256 | Sort-Object -Unique)
                }
            }
        } | Group-Object { $_.name.ToLowerInvariant() } | Sort-Object Name
    )) {
    $allHashes = @($group.Group.implementation_hashes | ForEach-Object { $_ } | Sort-Object -Unique)
    [ordered]@{
        name = [string]$group.Group[0].name
        profiles = @($group.Group.profile | Sort-Object -Unique)
        implementation_count = $allHashes.Count
        profile_specific = $allHashes.Count -gt 1
    }
}

$unionCommands = foreach ($group in @(
        $profileResults | ForEach-Object {
            $profileId = $_.Definition.id
            foreach ($command in $_.Commands.commands) {
                [pscustomobject]@{
                    name = [string]$command.name
                    profile = $profileId
                }
            }
        } | Group-Object { $_.name.ToLowerInvariant() } | Sort-Object Name
    )) {
    [ordered]@{
        name = [string]$group.Group[0].name
        profiles = @($group.Group.profile | Sort-Object -Unique)
    }
}

$compatibility = [ordered]@{
    schema = 'workflow-bootstrap-compatibility-catalog/v1'
    generated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    guarantee = 'Jede statisch definierte Legacy-Funktion und jeder statisch registrierte Legacy-Befehl ist in mindestens einem unverkuerzten Profilpaket enthalten.'
    profiles = @($profileResults | ForEach-Object {
            [ordered]@{
                id = $_.Definition.id
                source_function_definitions = $_.Functions.definition_count
                unique_functions = $_.Functions.unique_function_count
                commands = $_.Commands.command_count
                payload_files = @($_.Profile.payload).Count
            }
        })
    union_function_count = @($unionFunctions).Count
    union_command_count = @($unionCommands).Count
    divergent_function_implementation_count = @($unionFunctions | Where-Object profile_specific).Count
    functions = @($unionFunctions)
    commands = @($unionCommands)
}
Write-JsonFile -Path (Join-Path $bootstrapRoot 'catalog\compatibility.json') -Value $compatibility

[pscustomobject]@{
    profiles = $profileResults.Count
    union_functions = @($unionFunctions).Count
    union_commands = @($unionCommands).Count
    divergent_function_implementations = @($unionFunctions | Where-Object profile_specific).Count
} | Format-List
