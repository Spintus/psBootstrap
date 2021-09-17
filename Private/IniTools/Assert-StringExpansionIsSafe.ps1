function Assert-StringExpansionIsSafe
{
    <#
        .SYNOPSIS
            Tests if a string contains code that PowerShell will try to execute on parsing.

        .DESCRIPTION
            The common usecase for this function is to make sure some imported data is safe
            to process using PowerShell's parser. For instance, when using Import-Ini, in
            order to expand variable references to values defined at runtime, they must be
            parsed with a call to $ExecutionContext.InvokeCommand.ExpandString(). This will
            attempt to execute arbitrary code.

            In order to test whether parsing the string as code would cause execution, the
            parsing is done inside a heavily restricted runspace where any attempt at
            execution will halt and throw an exception.

        .PARAMETER String
            Specifies the string to be tested for executable code. You can also pipe a
            string to Assert-StringExpansionIsSafe.

        .INPUTS
            System.String

            You can pipe a string to Assert-StringExpansionIsSafe.

        .OUTPUTS
            None

            Assert-StringExpansionIsSafe does not generate any output.

        .EXAMPLE
            > Assert-StringExpansionIsSafe -String '$(Get-Date)'
            Assert-StringExpansionIsSafe: String expansion caught attempted code execution! This may be a security issue!
            At line:96 char:13
            +             throw "$($MyInvocation.MyCommand.Name): String expansion  ...
            +             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                + CategoryInfo          : OperationStopped: (Test-StringExpa...security issue!:String) [], RuntimeException
                + FullyQualifiedErrorId : Assert-StringExpansionIsSafe: String expansion caught attempted code execution! This may b
                e a security issue!

        .NOTES
            WARNING: This is an inherently dangerous operation! ExpandString() is a huge
            security risk if not handled properly. Calling ExpandString in an unrestricted
            runspace would allow arbitrary code injection. To prevent this, this function
            implements a test which will catch on any attempted execution. This test is
            implemented with jobs and restricted runspaces.

        .LINK
            Import-Ini
            Resolve-IniReferences

    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        # Specifies the string to test for attempted code execution.
        $String,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator.
        [string]
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Assert-StringExpansionIsSafe.log" -Force)
    )

    begin
    {
        $ErrorActionPreference = 'Stop'

        # This is the runspace restriction; make all commands/applications/scripts unavailable in job's runspace.
        $initSB = {
            $ExecutionContext.SessionState.Applications.Clear()
            $ExecutionContext.SessionState.Scripts.Clear()
            Get-Command | ForEach-Object {
                $_.Visibility = 'Private'
            }
        }

        # Expand strings (in job). Without runspace restriction, this could execute arbitrary code.
        $safeStringEvalSB = {
            param($str)
            [System.Environment]::ExpandEnvironmentVariables($str)
            $ExecutionContext.InvokeCommand.ExpandString($str)
        }
    }

    process
    {
        # This prevents code injection. See help documentation for how and why this is necessary.
        try
        {
            Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Expanding string in restricted runspace (code injection screening)." $LogFile

            $job = Start-Job -Init $initSB -ScriptBlock $safeStringEvalSB -ArgumentList $String
            [void] (Wait-Job $job)
            [void] (Receive-Job $job)

            Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): String expansion did not catch execution! Invocation is safe." $LogFile

            Remove-Job $job -Confirm:$false -WhatIf:$false
        }
        catch
        {
            throw "$($MyInvocation.MyCommand.Name): String expansion caught attempted code execution! This may be a security issue!"
        }
    }
}
