function Import-Items
{
    <#
        .SYNOPSIS
            Dot-Source all files whose names are found in the text file $ScriptList.

        .DESCRIPTION
            For each line in $ScriptList file, search the directory $ScriptPath and pass matching names to dot operator.

        .PARAMETER ModuleList
            The path (relative or absolute) to the text file containing the list of helper scripts to import.

        .PARAMETER ModulePath
            The path (relative or absolute) to the directory containing helper scripts and their dependencies from which to import.

        .INPUTS
            System.String

        .OUTPUTS
            None

        .EXAMPLE
            > Import-HelperScripts -ScriptList ".\psScripts.txt" -ScriptPath ".\psScripts"

            Imports all scripts listed by name in psScripts.txt.

        .NOTES
            For script modules which posess a manifest, list only that manifest and ensure that it loads the module itself.

        .LINK
            Import-Module
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePathExists()]
        [string]
        # The path to the directory which contains items for import.
        $ImportPath,

        [Parameter(DontShow)]
        [ValidatePathExists()]
        [string]
        $LogFile = (New-Item -ItemType File -Path $PSScriptRoot\lastExecute.log -Force)
    )

    process
    {
        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Searching for modules in directory: $ImportPath" $LogFile

        foreach ($moduleFile in @(Get-ChildItem -Path $ImportPath\*.psm1 -Recurse))
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Found Module: $($moduleFile.FullName)" $LogFile
            if ($manifest = Get-ChildItem -Path "$($moduleFile.PSParentPath)\$($moduleFile.BaseName).psd1" -ea 4)
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Found Manifest: $($manifest.FullName)" $LogFile
                try
                {
                    Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Importing module: $($manifest.FullName)" $LogFile
                    Microsoft.PowerShell.Core\Import-Module $manifest.FullName -Scope Global -Force *>&1 | Write-BootstrapLog -Level 'Verbose' -LogFile $LogFile
                    Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done importing module: $($manifest.FullName)" $LogFile
                }
                catch
                {
                    Write-BootstrapLog 'Error' $_.Message $LogFile
                }
            }
            else
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): No manifest found for module: $($moduleFile.FullName)" $LogFile
                try
                {
                    Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Importing module: $($moduleFile.FullName)" $LogFile
                    Microsoft.PowerShell.Core\Import-Module $moduleFile.FullName -Scope Global -Force *>&1 | Write-BootstrapLog -Level 'Verbose' -LogFile $LogFile
                    Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done importing module: $($moduleFile.FullName)" $LogFile
                }
                catch
                {
                    Write-BootstrapLog 'Error' $_.Message $LogFile
                }
            }

            # Register module for cleanup when bootstrapper is removed.
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Adding Remove-Module call for module: $($moduleFile.BaseName) to psBootstrap 'OnRemove' block." $LogFile
            $MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = [scriptblock]::Create(
                [string] $(
                    if ($MyInvocation.MyCommand.ScriptBlock.psObject.Properties['Module'].Value -and
                        $MyInvocation.MyCommand.ScriptBlock.Module.OnRemove)
                    {
                        $MyInvocation.MyCommand.ScriptBlock.Module.OnRemove.ToString()
                    }
                ) + "`n" + [scriptblock]::Create(
                    "Remove-Module $($moduleFile.BaseName) # -Force"
                ).ToString()
            )
        }

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done Importing items from directory: $ImportPath" $LogFile
    }
}
