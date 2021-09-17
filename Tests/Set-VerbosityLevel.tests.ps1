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
    . (Resolve-Path "$scriptRoot\Set-VerbosityLevel.ps1")

    # Create temp files for output streams.
    $streams = @{
        # 1 = 'TestDrive:\stream1.txt'
        # 2 = 'TestDrive:\stream2.txt'
        # 3 = 'TestDrive:\stream3.txt'
        # 4 = 'TestDrive:\stream4.txt'
        # 5 = 'TestDrive:\stream5.txt'
        # 6 = 'TestDrive:\stream6.txt'
    }

    foreach ($key in $streams.Keys)
    {
        Set-Content $streams[$key] -Value $null
    }

}

Describe 'Set-VerbosityLevel' {

    Context 'Preference variables set to defaults' {

        BeforeAll {

            # Set preference variables to defaults.
            $ConfirmPreference = 'Medium'
            $DebugPreference = 'SilentlyContinue'
            $ErrorActionPreference = 'Continue'
            $InformationPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            $WarningPreference = 'Continue'
            $WhatIfPreference = $false

        }

        It 'Preference variables should be default' {

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Continue'
            $InformationPreference | Should -Be 'SilentlyContinue'
            $VerbosePreference | Should -Be 'SilentlyContinue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "None"' {

            Set-VerbosityLevel -Level 'None'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'SilentlyContinue'
            $VerbosePreference | Should -Be 'SilentlyContinue'
            $WarningPreference | Should -Be 'SilentlyContinue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "Error"' {

            Set-VerbosityLevel -Level 'Error'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'SilentlyContinue'
            $VerbosePreference | Should -Be 'SilentlyContinue'
            $WarningPreference | Should -Be 'SilentlyContinue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "Warn"' {

            Set-VerbosityLevel -Level 'Warn'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'SilentlyContinue'
            $VerbosePreference | Should -Be 'SilentlyContinue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "Info"' {

            Set-VerbosityLevel -Level 'Info'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'Continue'
            $VerbosePreference | Should -Be 'SilentlyContinue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "Verbose"' {

            Set-VerbosityLevel -Level 'Verbose'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'SilentlyContinue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'Continue'
            $VerbosePreference | Should -Be 'Continue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "Debug"' {

            Set-VerbosityLevel -Level 'Debug'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'Continue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'Continue'
            $VerbosePreference | Should -Be 'Continue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "DebugInquire"' {

            Set-VerbosityLevel -Level 'DebugInquire'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'Inquire'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'Continue'
            $VerbosePreference | Should -Be 'Continue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

        It -Skip 'When called with "All"' {

            Set-VerbosityLevel -Level 'All'

            $ConfirmPreference | Should -Be 'Medium'
            $DebugPreference | Should -Be 'Continue'
            $ErrorActionPreference | Should -Be 'Stop'
            $InformationPreference | Should -Be 'Continue'
            $VerbosePreference | Should -Be 'Continue'
            $WarningPreference | Should -Be 'Continue'
            $WhatIfPreference | Should -Be $false

        }

    }

}