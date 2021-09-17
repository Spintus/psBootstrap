function Test-CurrentPrincipal
{
    <#
        .SYNOPSIS
            Test various attributes of current principal are as expected.

        .DESCRIPTION
            Uses [Security.Principal.WindowsIdentity]::GetCurrent() method to get information about current principal. Various
            tests are then performed on that object based on chosen parameters to ensure that the current WindowsIdentity is
            as expected, and therefore that the script has correct permissions. If any tests fail, writes an error.

        .INPUTS
            System.Security.Principal.WindowsBuiltInRole
            System.Security.Principal.TokenImpersonationLevel
            System.String

        .OUTPUTS
            None

        .EXAMPLE
            >Test-CurrentPrincipal -EnforceRole "User" -EnforceIdentityName "Operator" -EnforceIsAuthenticated

            Tested that the current principal had username "Operator", WindowsBuiltInRole "User", and authenticated.
    #>
    [CmdletBinding()]
    param
    (
        [Security.Principal.WindowsBuiltInRole]
        # Specifies which WindowsBuiltInRole current principal must be in.
        # Default is 'Administrator'.
        $EnforceRole = 'Administrator',

        [string]
        # Specifies the required Username.
        $EnforceIdentityName,

        [Security.Principal.TokenImpersonationLevel]
        # Specifies the required impersonation level.
        $EnforceImpersonationLevel,

        [switch]
        # Specifies that the current principal must be authenticated.
        $EnforceIsAuthenticated,

        [switch]
        # Specifies that the current principal must be guest.
        $EnforceIsGuest,

        [switch]
        # Specifies that the current principal must be system.
        $EnforceIsSystem,

        [switch]
        # Specifies that the current principal must be anonymous.
        $EnforceIsAnonymous,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator (see Classes\ValidatePathExistsAttribute.ps1).
        [string]
        $LogFile = (New-Item -ItemType File -Path $PSScriptRoot\lastExecute.log -Force)
    )

    process
    {
        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Testing current principal identity is expected." $LogFile

        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

        if (-not ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::$EnforceRole)))
        {
            Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceRole:$EnforceRole." $LogFile
        }

        if ($EnforceIdentityName)
        {
            if (-not ($currentPrincipal.Identities.Name.Split("\")[-1] -eq $EnforceIdentityName))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceIdentityName:$EnforceIdentityName." $LogFile
            }
        }

        if ($EnforceImpersonationLevel)
        {
            if (-not ($currentPrincipal.Identities.ImpersonationLevel -eq $EnforceImpersonationLevel))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceImpersonationLevel:$EnforceImpersonationLevel." $LogFile
            }
        }

        if ($EnforceIsAuthenticated)
        {
            if (-not ($currentPrincipal.Identities.IsAuthenticated -eq $EnforceIsAuthenticated))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceIsAuthenticated:$EnforceIsAuthenticated." $LogFile
            }
        }

        if ($EnforceIsGuest)
        {
            if (-not ($currentPrincipal.Identities.IsGuest -eq $EnforceIsGuest))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceIsGuest:$EnforceIsGuest." $LogFile
            }
        }

        if ($EnforceIsSystem)
        {
            if (-not ($currentPrincipal.Identities.IsSystem -eq $EnforceIsSystem))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceIsSystem:$EnforceIsSystem." $LogFile
            }
        }

        if ($EnforceIsAnonymous)
        {
            if (-not ($currentPrincipal.Identities.IsAnonymous -eq $EnforceIsAnonymous))
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Current principal failed test: EnforceIsAnonymous:$EnforceIsAnonymous." $LogFile
            }
        }

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done testing current principal identity is expected." $LogFile
    }
}
