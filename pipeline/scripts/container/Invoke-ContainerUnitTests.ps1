<#
.SYNOPSIS
    Runs the Actor Framework unit tests inside a LabVIEW Docker container.

.DESCRIPTION
    Single entry point with two modes.

    Host mode (default) mirrors .github/workflows/ci.yml:
      pull image -> resolve LV_YEAR from image metadata -> create/start
      container -> docker cp repository -> docker exec this same script with
      -InContainer -> collect logs -> docker rm -f.

    Container mode (-InContainer) installs test dependencies and delegates to
    the existing pipeline\scripts\unit_tests.ps1 flow.

    The repository copy is required: Tooling\Run all tests CLI.vi and
    Test\Unit Tests\** are not present in the base image.

    Dependency situation in nationalinstruments/labview:*-windows:
      Present : LabVIEW Professional, LabVIEW RTE, LabVIEWCLI,
                VI Analyzer Toolkit, NI Package Manager (+ nipkg CLI).
      Absent  : VIPM, g-cli.
    Run all tests CLI.vi needs g-cli and Caraya from
    Tooling\deployment\runner_dependencies.vipc, which only VIPM can install,

    so this script downloads and installs VIPM from the hardcoded installer URL
    before continuing.

.EXAMPLE
    .\Invoke-ContainerUnitTests.ps1 -RepoRoot $env:GITHUB_WORKSPACE
#>
[CmdletBinding(DefaultParameterSetName = 'Host')]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(ParameterSetName = 'Host')]
    [string]$Image = 'nationalinstruments/labview:latest-windows',

    [Parameter(ParameterSetName = 'Host')]
    [string]$ContainerName,

    [Parameter(ParameterSetName = 'Host')]
    [int]$KeepAliveSeconds = 7200,

    # Where collected logs and test reports land on the host.
    [Parameter(ParameterSetName = 'Host')]
    [string]$ArtifactPath = 'unit-test-logs',

    [ValidateSet('32', '64')]
    [string]$SupportedBitness = '64',

    [string]$ContainerRepoPath = 'C:\actor-framework',

    [string]$LogPath = 'C:\unit-test-logs',

    # Set only when this script is re-invoked by itself via docker exec.
    [Parameter(Mandatory = $true, ParameterSetName = 'Container')]
    [switch]$InContainer,

    [Parameter(Mandatory = $true, ParameterSetName = 'Container')]
    [string]$LvYear
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Container mode
# ---------------------------------------------------------------------------
if ($InContainer) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    Start-Transcript -Path (Join-Path $LogPath 'bootstrap.log') -Force | Out-Null
    try {
        $lvRoot = "C:\Program Files\National Instruments\LabVIEW $LvYear"
        if (-not (Test-Path $lvRoot)) { throw "LabVIEW root not found at: $lvRoot" }
        Write-Host "Using LabVIEW $LvYear ($SupportedBitness-bit) at $lvRoot"

        # Match the Docker SBOM pattern: don't assume vipm.exe is on PATH or in one
        # fixed location. Search Program Files first, then download/install silently
        # if the CLI is absent.
        $vipm = (Get-Command vipm -ErrorAction SilentlyContinue).Source
        if (-not $vipm) {
            $vipm = Get-ChildItem -Path "$env:ProgramFiles", "${env:ProgramFiles(x86)}" -Filter vipm.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        }

        if (-not $vipm) {
            $installerUrl = 'https://traffic.libsyn.com/secure/jkinc/vipm-26.3.4025-windows-setup.exe'
            $installer = Join-Path $env:TEMP 'vipm-installer.exe'
            Write-Host "Downloading VIPM installer from $installerUrl"
            Invoke-WebRequest -Uri $installerUrl -OutFile $installer -UseBasicParsing

            Write-Host 'Installing VIPM silently...'
            $proc = Start-Process -FilePath $installer -ArgumentList '/exenoui', '/qn' -Wait -PassThru
            if ($proc.ExitCode -ne 0) { throw "VIPM installer exited with code $($proc.ExitCode)" }

            $vipm = Get-ChildItem -Path "$env:ProgramFiles", "${env:ProgramFiles(x86)}" -Filter vipm.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if (-not $vipm) {
                throw 'vipm.exe was not found under Program Files after installation.'
            }
        }

        # TEMP-REVIEW: NEW BLOCK - suppress all prompts. Without this a missing or
        # wrong credential blocks on stdin and hangs the container until timeout
        # instead of failing. Documented at docs.vipm.io/latest/cli/environment-variables/
        $env:VIPM_NONINTERACTIVE = '1'
        $env:NO_COLOR = '1'

        # TEMP-REVIEW: NEW BLOCK - credentials are read from the environment (injected
        # by "docker exec -e") instead of script parameters, so the serial number
        # never appears in the container process command line.
        $vipmSerial = $env:VIPM_SERIAL_NUMBER
        $vipmName   = $env:VIPM_FULL_NAME
        $vipmEmail  = $env:VIPM_EMAIL

        if (-not $vipmSerial -or -not $vipmName -or -not $vipmEmail) {
            throw ("VIPM Pro activation credentials are missing. vipm activate requires all three of " +
                   "VIPM_SERIAL_NUMBER, VIPM_FULL_NAME and VIPM_EMAIL. Set them as repository secrets " +
                   "and let the workflow forward them. Name and email must exactly match the VIPM " +
                   "account tied to the serial number. See https://docs.vipm.io/latest/cli/docker/")
        }

        # TEMP-REVIEW: NEW BLOCK - THE ACTUAL FIX. Previously VIPM was only installed
        # and never activated, so every later CLI call would fail with exit code 6
        # (ENTITLEMENT_ERROR) or stall on an activation prompt. Argument names are
        # taken verbatim from docs.vipm.io/latest/cli/command-reference/#vipm-activate.
        # Relevant exit codes: 22 ACTIVATION_FAILED, 10 AUTHENTICATION_FAILURE.
        Write-Host "Activating VIPM Pro for $vipmEmail ..."
        & $vipm activate --serial-number $vipmSerial --name $vipmName --email $vipmEmail
        if ($LASTEXITCODE -ne 0) { throw "vipm activate failed with exit code $LASTEXITCODE" }

        # TEMP-REVIEW: NEW BLOCK - the Docker guide requires a refresh before any
        # install, otherwise a freshly created container installs against a stale or
        # entirely absent repository index.
        Write-Host 'Refreshing VIPM package sources...'
        & $vipm refresh
        if ($LASTEXITCODE -ne 0) { throw "vipm refresh failed with exit code $LASTEXITCODE" }

        $vipc = Join-Path $RepoRoot 'Tooling\deployment\runner_dependencies.vipc'
        Write-Host "Applying $vipc"
        & $vipm install -y $vipc --labview-version $LvYear --labview-bitness $SupportedBitness
        if ($LASTEXITCODE -ne 0) { throw "Applying runner_dependencies.vipc failed with exit code $LASTEXITCODE" }

        $scriptsFolder = Join-Path $RepoRoot 'pipeline\scripts'
        Push-Location $scriptsFolder
        try {
            & (Join-Path $scriptsFolder 'unit_tests.ps1') `
                -RelativePath $RepoRoot `
                -AbsolutePathScripts $scriptsFolder `
                -MinimumSupportedLVVersion $LvYear `
                -Bitnesses @($SupportedBitness)
        }
        finally {
            Pop-Location
        }
        if ($LASTEXITCODE -ne 0) { throw "unit_tests.ps1 failed with exit code $LASTEXITCODE" }

        Get-ChildItem -Path $RepoRoot -Include '*.xml', '*.html', '*.htm' -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) } |
            ForEach-Object { Copy-Item $_.FullName -Destination $LogPath -Force -ErrorAction SilentlyContinue }
    }
    finally {
        Stop-Transcript | Out-Null
    }
    return
}

# ---------------------------------------------------------------------------
# Host mode
# ---------------------------------------------------------------------------
$RepoRoot = (Resolve-Path -Path $RepoRoot).Path

Write-Host "Pulling $Image ..."
docker pull $Image
if ($LASTEXITCODE -ne 0) { throw "docker pull failed for $Image" }

$imageEnv = docker image inspect --format '{{json .Config.Env}}' $Image | ConvertFrom-Json
$lvYearEntry = $imageEnv | Where-Object { $_ -like 'LV_YEAR=*' } | Select-Object -First 1
if (-not $lvYearEntry) { throw "LV_YEAR was not found in image metadata for $Image" }
$lvYear = $lvYearEntry.Substring('LV_YEAR='.Length)

if (-not $ContainerName) { $ContainerName = "af-tests-lv$lvYear" }
Write-Host "Resolved LV_YEAR=$lvYear, container=$ContainerName"

# Clear a container left behind by a cancelled run.
docker rm -f $ContainerName 2>$null | Out-Null

try {
    docker create --name $ContainerName `
        $Image `
        powershell -NoLogo -NoProfile -Command "Start-Sleep -Seconds $KeepAliveSeconds"
    if ($LASTEXITCODE -ne 0) { throw "docker create failed for $ContainerName" }

    docker start $ContainerName
    if ($LASTEXITCODE -ne 0) { throw "docker start failed for $ContainerName" }

    Write-Host "Copying $RepoRoot -> $($ContainerName):$ContainerRepoPath"
    docker cp $RepoRoot "$($ContainerName):$ContainerRepoPath"
    if ($LASTEXITCODE -ne 0) { throw "Failed to copy repository into $ContainerName" }

    $self = Join-Path $ContainerRepoPath 'pipeline\scripts\container\Invoke-ContainerUnitTests.ps1'

    # TEMP-REVIEW: NEW BLOCK - VIPM Pro activation credentials are forwarded as
    # container environment variables. They are passed with -e (not as script
    # parameters) so the serial number stays out of the container's process
    # command line. The host reads them from the workflow's secret-backed env.
    docker exec `
        -e LV_YEAR="$lvYear" `
        -e VIPM_SERIAL_NUMBER="$env:VIPM_SERIAL_NUMBER" `
        -e VIPM_FULL_NAME="$env:VIPM_FULL_NAME" `
        -e VIPM_EMAIL="$env:VIPM_EMAIL" `
        $ContainerName `
        powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $self `
        -InContainer `
        -RepoRoot $ContainerRepoPath `
        -LvYear $lvYear `
        -SupportedBitness $SupportedBitness `
        -LogPath $LogPath

    if ($LASTEXITCODE -ne 0) {
        throw "Unit tests failed inside container $ContainerName with exit code $LASTEXITCODE"
    }
}
finally {
    # Best effort: never mask the original failure.
    $ErrorActionPreference = 'Continue'

    if (docker ps -a --filter "name=^/$ContainerName$" --format '{{.Names}}') {
        New-Item -ItemType Directory -Path $ArtifactPath -Force | Out-Null
        Write-Host "Collecting $LogPath from $ContainerName ..."
        docker cp "$($ContainerName):$LogPath" $ArtifactPath
        if ($LASTEXITCODE -ne 0) { Write-Warning "No artifacts found at $LogPath in $ContainerName." }

        Write-Host "Removing container $ContainerName ..."
        docker rm -f $ContainerName | Out-Null
    }
}
