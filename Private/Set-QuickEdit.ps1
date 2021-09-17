function Set-QuickEdit
{
    <#
        .SYNOPSIS
            Enable/Disable Powershell's 'Quick Edit' mode.

        .DESCRIPTION
            Powershell's 'Quick Edit' mode is problematic when executing large scripts; clicking on script window pauses
            output. To prevent such behavior, this function disables/enables that option.

            Note: Powershell does not have the ability to do this (As of 7.0). Therefore CSharp is used to define the
            requisite class in this script.

        .EXAMPLE
            > Set-QuickEdit -Disable
            QuickEdit settings has been updated.

            Disables Quick Edit mode for the console host.

        .EXAMPLE
            > Set-QuickEdit
            QuickEdit settings has been updated.

            Enables Quick Edit mode for the console host.

        .INPUTS
            System.Management.Automation.SwitchParameter

        .OUTPUTS
            None.
    #>
    [CmdletBinding()]
    param
    (
        [switch]
        # This switch disables Console QuickEdit option.
        $Disable,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validation attribute.
        [string]
        $LogFile = (New-Item -ItemType File -Path $PSScriptRoot\lastExecute.log -Force)
    )

    if ([DisableConsoleQuickEdit]::SetQuickEdit($Disable))
    {
        Write-BootstrapLog -Level 'Info' "$($MyInvocation.MyCommand.Name): QuickEdit setting has been updated." $LogFile
    }
    else
    {
        Write-BootstrapLog -Level 'Error' "$($MyInvocation.MyCommand.Name): Something went wrong updating QuickEdit setting." $LogFile
    }
}
