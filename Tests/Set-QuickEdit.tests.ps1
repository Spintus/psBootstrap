BeforeAll {

    # if debugging, set scriptRoot to current directory
    $scriptRoot = if ($PSScriptRoot)
    {
        $PSScriptRoot
    }
    else
    {
        $PWD.Path
    }

    # Dot source script to be tested.
    . (Resolve-Path "$scriptRoot\Set-QuickEdit.ps1")

    # Load classes.
    foreach ($classFile in ("$(Split-Path $scriptRoot)\Classes\ValidatePathExistsAttribute.ps1", "$(Split-Path $scriptRoot)\Classes\DisableConsoleQuickEdit.ps1"))
    {
        try
        {
            . (
                [scriptblock]::Create(
                    [io.file]::ReadAllText($classFile)
                )
            ) -WarningAction 'SilentlyContinue'
        }
        catch
        {
            Microsoft.PowerShell.Utility\Write-Error "Failed to import class $($import.fullname): $_"
        }
    }

    # Make/Mock functions.
    function Write-BootstrapLog
    {
        param
        (
            [Parameter(ValueFromPipeline = $true, Position = 1)]
            $Message,

            [Parameter(Position = 0)]
            [ValidateSet('Error', 'Warn', 'Info', 'Verbose', 'Debug')]
            [string] $Level = 'Info',

            [Parameter(Position = 2)]
            [string] $LogFile
        )

        process
        {
            [void] ((Get-Date -Format o) -match "^(?<date>\d{4}-\d{2}-\d{2})T(?<time>\d{2}:\d{2}:\d{2})\.(?<sub>\d{3}).+$")

            $timeStamp = "{0} {1},{2} {3} [Line:{4}]" -f
            $Matches['date'],
            $Matches['time'],
            $Matches['sub'],
            $MyInvocation.ScriptName.Split('\')[-1].PadRight(25,' '),
            $MyInvocation.ScriptLineNumber.ToString().PadRight(4,' ')

            Microsoft.PowerShell.Utility\Out-File -InputObject "$timeStamp $($Level.PadRight(7,' ')) : $Message" -FilePath $LogFile -Append

            switch ($Level)
            {
                'Error' {Microsoft.PowerShell.Utility\Write-Error $Message; break}
                'Warn' {Microsoft.PowerShell.Utility\Write-Warning $Message; break}
                'Info' {Microsoft.PowerShell.Utility\Write-Information $Message; break}
                'Verbose' {Microsoft.PowerShell.Utility\Write-Verbose $Message; break}
                'Debug' {Microsoft.PowerShell.Utility\Write-Debug $Message; break}
            }
        }
    }

}

Describe 'Set-QuickEdit' {

    BeforeAll {

        # Save preference vars for after test.
        $script:infoPref = $InformationPreference
        $script:errorPref = $ErrorActionPreference

        # Set preference vars for correct output.
        $InformationPreference = 'Continue'
        $ErrorActionPreference = 'Continue'

    }

    BeforeEach {

        # Create temp files for output streams.
        $streams = @{
            # 1 = 'TestDrive:\stream1.txt'
            2 = 'TestDrive:\stream2.txt'
            # 3 = 'TestDrive:\stream3.txt'
            # 4 = 'TestDrive:\stream4.txt'
            # 5 = 'TestDrive:\stream5.txt'
            6 = 'TestDrive:\stream6.txt'
        }

        foreach ($key in $streams.Keys)
        {
            Set-Content $streams[$key] -Value $null
        }

        # Log file for Write-BootstrapLog.
        [string] $LogFile = (New-Item -ItemType File -Path 'TestDrive:\lastExecute.txt' -Force)

    }

    It 'disables QuickEdit, and outputs to information stream.' {

        Set-QuickEdit -LogFile $LogFile -Disable 6> $streams[6] 2> $streams[2] | Should -Be $null
        Get-Content $streams[6] | Should -Be 'Set-QuickEdit: QuickEdit setting has been updated.'
        Get-Content $streams[2] | Should -Be $null
        Get-Content $LogFile | Should -Match 'Set-QuickEdit: QuickEdit setting has been updated.'

    }

    It 'enables QuickEdit, and outputs to information stream.' {

        Set-QuickEdit -LogFile $LogFile 6> $streams[6] 2> $streams[2] | Should -Be $null
        Get-Content $streams[6] | Should -Be 'Set-QuickEdit: QuickEdit setting has been updated.'
        Get-Content $streams[2] | Should -Be $null
        Get-Content $LogFile | Should -Match 'Set-QuickEdit: QuickEdit setting has been updated.'

    }

    AfterAll {

        # Set preference vars back.
        $InformationPreference = $infoPref
        $ErrorActionPreference = $errorPref

    }

}