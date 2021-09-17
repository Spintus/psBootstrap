[Flags()]
enum ScriptVerbosityLevel
{
    None         = 0
    Error        = 1
    Warn         = 2
    Info         = 4
    Verbose      = 8
    Debug        = 16
    DebugInquire = 32
}

function Set-VerbosityLevel
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateSet('None', 'Error', 'Warn', 'Info', 'Verbose', 'Debug', 'DebugInquire', 'All')]
        [ScriptVerbosityLevel]
        # Specifies which messages get written to console. Does not affect logging.
        $Level,

        [Parameter(DontShow)]
        [ValidatePathExists()]
        [string]
        $LogFile = (New-Item -ItemType File -Path $PSScriptRoot\lastExecute.log -Force)
    )

    process
    {
        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Setting verbosity level: $Level" $LogFile

        [ScriptVerbosityLevel] $Level = switch ($Level)
        {
            'None'         { 0; break }
            'Error'        { 1; break }
            'Warn'         { 3; break }
            'Info'         { 7; break }
            'Verbose'      { 15; break }
            'Debug'        { 31; break }
            'DebugInquire' { 47; break }
            'All'          { 31; break }
        }

        $dp = if ($Level.HasFlag([ScriptVerbosityLevel]::Debug))
        {
            'Continue'
        }
        else
        {
            if ($Level.HasFlag([ScriptVerbosityLevel]::DebugInquire))
            {
                'Inquire'
            }
            else
            {
                'SilentlyContinue'
            }
        }
        $vp = if ($Level.HasFlag([ScriptVerbosityLevel]::Verbose)) {'Continue'} else {'SilentlyContinue'}
        $ip = if ($Level.HasFlag([ScriptVerbosityLevel]::Info))    {'Continue'} else {'SilentlyContinue'}
        $wp = if ($Level.HasFlag([ScriptVerbosityLevel]::Warn))    {'Continue'} else {'SilentlyContinue'}
        $ep = if ($Level.HasFlag([ScriptVerbosityLevel]::Error))   {'Stop'}     else {'SilentlyContinue'}
        # $wip = $false
        # $cp = 'High'

        Set-Variable -Scope 3 -Name DebugPreference -Value $dp
        Set-Variable -Scope 3 -Name VerbosePreference -Value $vp
        Set-Variable -Scope 3 -Name InformationPreference -Value $ip
        Set-Variable -Scope 3 -Name WarningPreference -Value $wp
        Set-Variable -Scope 3 -Name ErrorActionPreference -Value $ep
        # Set-Variable -Scope 3 -Name WhatIfPreference -Value $wip
        # Set-Variable -Scope 3 -Name ConfirmPreference -Value $cp

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done Setting verbosity level: $Level" $LogFile
    }
}
