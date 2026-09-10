# .\Build.ps1 -RelativePath "C:\labview-icon-editor" -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts"
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    
    [Parameter(Mandatory = $true)]
    [string]$AbsolutePathScripts,

    # TEMP-REVIEW: NEW PARAM - was hardcoded to 2021. The container resolves its
    # LabVIEW year from image metadata (LV_YEAR), so the caller must be able to
    # pass it in.
    [string]$MinimumSupportedLVVersion = '2021',

    # TEMP-REVIEW: NEW PARAM - was two hardcoded passes (32 then 64). The LabVIEW
    # container image ships a single bitness, so container callers pass one value.
    # Default preserves the original host behaviour.
    [string[]]$Bitnesses = @('32', '64')
)

# Helper function to check for file or directory existence
function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Host "The $Description does not exist: $Path" -ForegroundColor Red
        exit 1
    }
}

# Helper function to execute scripts sequentially
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string]$Arguments
    )
    Write-Host "Executing: $ScriptPath $Arguments" -ForegroundColor Cyan
    try {
        # Build and execute the command
        $command = "& `"$ScriptPath`" $Arguments"
        Invoke-Expression $command

        # Check for errors in the script execution
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error occurred while executing: $ScriptPath with arguments: $Arguments. Exit code: $LASTEXITCODE" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } catch {
        Write-Host "Error occurred while executing: $ScriptPath with arguments: $Arguments. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Main script logic
try {
    # Validate required paths
    Assert-PathExists $RelativePath "RelativePath"
    Assert-PathExists $AbsolutePathScripts "Scripts folder"

    # TEMP-REVIEW: the "resource\plugins" assertion and .lvlibp cleanup that used to
    # sit here were removed. They are labview-icon-editor leftovers; that folder does
    # not exist in actor-framework, so this script exited 1 before running any test.
    # TEMP-REVIEW: loop replaces the two copy-pasted 32/64-bit blocks. Same calls,
    # same order, now driven by $Bitnesses.
    foreach ($bitness in $Bitnesses) {
        # Run Unit Tests
        Execute-Script "$($AbsolutePathScripts)\RunUnitTests.ps1" `
            "-MinimumSupportedLVVersion $MinimumSupportedLVVersion -SupportedBitness $bitness -RelativePath `"$RelativePath`""

        # Close LabVIEW
        Execute-Script "$($AbsolutePathScripts)\Close_LabVIEW.ps1" `
            "-MinimumSupportedLVVersion $MinimumSupportedLVVersion -SupportedBitness $bitness"
    }

    Write-Host "All scripts executed successfully!" -ForegroundColor Green
} catch {
    Write-Host "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
