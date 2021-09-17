function Write-BootstrapLog
{
    # This function logs all pipeline input to a file in calling scriptroot.
    # Allows logging of all initialization stream outputs with no (meta) modules.
    # The reason this isn't implemented using the *-Transcript cmdlets is that those
    # are bugged in Powershell V5.1, causing issues with preference variables.
    param
    (
        [Parameter(ValueFromPipeline, Position = 1)]
        $Message,

        [Parameter(Position = 0)]
        [ValidateSet('Error', 'Warn', 'Info', 'Verbose', 'Debug')]
        [string]
        $Level = 'Info',

        [Parameter(Position = 2)]
        [string]
        $LogFile
    )

    process
    {
        # Get calling script name. Callstack used because functions loaded NOT from files ($MyInvocation isn't fully populated).
        $saveEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Ignore'
        $scriptStackFrame = foreach ($stackFrame in Get-PSCallStack)
        {
            try
            {
                $name = $stackFrame.ScriptName

                if ($name -and $name -notmatch "Write-BootstrapLog|log4ps")
                {
                    $stackFrame
                    break
                }
            }
            catch
            {}
        }
        # Restore action preference value.
        $ErrorActionPreference = $saveEAP

        [void] ((Get-Date -Format o) -match "^(?<date>\d{4}-\d{2}-\d{2})T(?<time>\d{2}:\d{2}:\d{2})\.(?<sub>\d{3}).+$")
        $timeStamp = "{0} {1},{2} {3} [Line:{4}]" -f
        $Matches['date'],
        $Matches['time'],
        $Matches['sub'],
        $(if (Get-Member -InputObject $scriptStackFrame -Name 'ScriptName' -MemberType Properties -ErrorAction 'Ignore')
            {
                $scriptStackFrame.ScriptName.Split('\')[-1]
            }
            else
            {
                'CLI'
            }
        ).PadRight(25,' '),
        $(if (Get-Member -InputObject $scriptStackFrame -Name 'ScriptLineNumber' -MemberType Properties -ErrorAction 'Ignore')
            {
                $scriptStackFrame.ScriptLineNumber.ToString()
            }
            else
            {
                'n/a'
            }
        )

        Microsoft.PowerShell.Utility\Out-File -InputObject "$timeStamp $($Level.PadRight(7,' ')) : $Message" -FilePath $LogFile -Append

        switch ($Level)
        {
            'Error'
            {
                Microsoft.PowerShell.Utility\Out-File -InputObject "$timeStamp : Dumping all errors..." -FilePath $LogFile -Append
                Microsoft.PowerShell.Utility\Out-File -InputObject $Global:Error -FilePath $LogFile -Append
                Microsoft.PowerShell.Utility\Write-Error $Message
                break
            }
            'Warn'    {Microsoft.PowerShell.Utility\Write-Warning $Message; break}
            'Info'    {Microsoft.PowerShell.Utility\Write-Information $Message; break}
            'Verbose' {Microsoft.PowerShell.Utility\Write-Verbose $Message; break}
            'Debug'   {Microsoft.PowerShell.Utility\Write-Debug $Message; break}
        }
    }
}
