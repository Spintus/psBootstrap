<# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
All imported *script* modules suffer from a massive known issue in Powershell
(All versions as of Core 7.1)!

In short: the common parameter inheritence mechanism is fundamentally broken
for advanced functions under certain circumstances. For reference, see:
https://github.com/PowerShell/PowerShell/issues/4568

For example: When $ErrorActionPreference is set to 'Stop', compiled cmdlets
will honor that preference by terminating on most* errors. Advanced functions
imported from a module however, which are meant to behave identically to
compiled cmdlets, will not. For 'why', if you want brain damage, see:
https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes

*https://github.com/MicrosoftDocs/PowerShell-Docs/issues/1583

This means preference variables are unreliable! For critical scripts, caution
MUST be taken to ensure good behavior in regard to preference variables.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #>

#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Microsoft.PowerShell.Core\Set-StrictMode -Version 3.0

# If debugging, set moduleRoot to current directory.
$moduleRoot = if ($MyInvocation.MyCommand.Path)
{
    Microsoft.PowerShell.Management\Split-Path -Path $MyInvocation.MyCommand.Path
}
else
{
    $PWD.Path
}

# Get all function/class scripts for dot-sourcing, and libraries for importing.
$splat = @{
    ErrorAction = 'Ignore'
    Recurse     = $true
    Exclude     = @('*.tests.ps1')
}
$public  = @(Microsoft.PowerShell.Management\Get-ChildItem -Path "$moduleRoot\Public\*.ps1" @splat)
$private = @(Microsoft.PowerShell.Management\Get-ChildItem -Path "$moduleRoot\Private\*.ps1" @splat)
$classes = @(Microsoft.PowerShell.Management\Get-ChildItem -Path "$moduleRoot\Classes\*.ps1" @splat)
$lib     = @(Microsoft.PowerShell.Management\Get-ChildItem -Path "$moduleRoot\Lib\*.dll" @splat)

# Load assemblies.
foreach ($import in @($lib))
{
    Microsoft.PowerShell.Utility\Add-Type -Path $import.FullName
}

# Dot source scripts.
# Note: This doesn't work with Powershell classes (As of PSv5.1).
# 'Class scripts' contain mostly C# which gets compiled with Add-Type calls.
foreach ($import in @($classes + $Public + $Private))
{
    . $import
}

# Export only the public functions (remember to list in manifest!).
Microsoft.PowerShell.Core\Export-ModuleMember -Function $public.BaseName

# Build the path to the manifest file for this module (whether or not it exists!).
$splat = @{
    Path      = $moduleRoot
    ChildPath = "$((Microsoft.PowerShell.Management\Get-Item $PSCommandPath).BaseName).psd1"
}
$manifestFullName = Microsoft.PowerShell.Management\Join-Path @splat

if (Microsoft.PowerShell.Management\Test-Path -Path $manifestFullName)
{
    # If manifest is found, invoke the contents and save output to variable.
    $manifest = Microsoft.PowerShell.Management\Get-Content -Raw $manifestFullName |
        Microsoft.PowerShell.Utility\Invoke-Expression

    foreach ($script in @($manifest.ScriptsToProcess))
    {
        # Get the name of the script.
        $moduleToRemove = (
            Microsoft.PowerShell.Management\Get-Item (
                Microsoft.PowerShell.Management\Join-Path -Path $moduleRoot -ChildPath $script
            )
        ).BaseName

        if (Microsoft.PowerShell.Core\Get-Module $moduleToRemove)
        {
            # Remove module imported by the script.
            Microsoft.PowerShell.Core\Remove-Module $moduleToRemove
        }
    }
}

# Cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Remove-Item -Path "$moduleRoot\lastExecute.log"
}

Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action {
    # Remove-Item -Path "$moduleRoot\lastExecute.log"
}
