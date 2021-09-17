Describe 'Import-Ini' {

    BeforeAll {

        # if debugging, set scriptRoot to current directory
        $scriptRoot = if ($MyInvocation.MyCommand.Path)
        {
            Split-Path -Path $MyInvocation.MyCommand.Path
        }
        else
        {
            $PWD.Path
        }

        # Dot source script to be tested.
        . (Resolve-Path "$scriptRoot\Import-Ini.ps1")

        # Load custom validator.
        . (
            [scriptblock]::Create(
                [io.file]::ReadAllText(
                    (
                        Split-Path (Split-Path $scriptRoot)
                    ) + '\Classes\ValidatePathExistsAttribute.ps1'
                )
            )
        )

        # Create temp files for output streams.
        $streams = @{
            # 1 = 'TestDrive:\stream1.txt'
            # 2 = 'TestDrive:\stream2.txt'
            # 3 = 'TestDrive:\stream3.txt'
            # 4 = 'TestDrive:\stream4.txt'
            # 5 = 'TestDrive:\stream5.txt'
            # 6 = 'TestDrive:\stream6.txt'
        }

        #region ========== FUNCTIONS AND MOCKS ==========

        function Get-NumericLiterals5.1
        {
            param
            (
                [string] $regex = '^(?<sign>[+-])?(?:0x(?<hex>[0-9a-f]+)|(?<dec>(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?))(?<type>l|d)?(?<multiplier>kb|mb|gb|tb|pb)?$',
                [int] $numOfTests = 100
            )

            [string[]] $sign = '+', '-'
            [string[]] $hPrefix = '0x', '0X'
            [string[]] $hex = '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'
            [string[]] $digit = '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
            [string[]] $exp = 'e', 'E'
            [string[]] $type = 'l', 'd'
            [string[]] $multiplier = 'kb', 'mb', 'gb', 'tb', 'pb'

            for ($i = 0; $i -lt $numOfTests; $i++)
            {
                [string] $hexadecimal = (Get-Random $hPrefix) + (Get-Random $hex -Count (Get-Random -Minimum 1 -Maximum 4)) -replace '\s', ''

                [bool] $r0 = $true, $false | Get-Random
                [bool] $r1 = $true, $false | Get-Random
                [bool] $r2 = ($true, $false | Get-Random) -or (-not ($r0 -and $r1))
                [bool] $r3 = $true, $false | Get-Random
                [bool] $r4 = $true, $false | Get-Random
                [bool] $r5 = $true, $false | Get-Random
                [bool] $r6 = $true, $false | Get-Random

                [string] $decimal = "$(if ($r0) {(Get-Random $digit -Count (Get-Random -Minimum 1 -Maximum 3)) -as [string]}
                    $(if ($r1) {`".`" -as [string]})
                    $(if ($r2) {(Get-Random $digit -Count (Get-Random -Minimum 1 -Maximum 3)) -as [string]})
                    $(if ($r3) {((Get-Random $exp) -as [string]) +
                    $(if ($r4) {(Get-Random $sign) -as [string]}) +
                    [string]$((Get-Random $digit -Count 1) -as [string])
                    }))" -replace '\s', ''

                [string] $out = "$(if ($true,$false | Get-Random) {(Get-Random $sign) -as [string]}
                    ($(Get-Random $hexadecimal, $decimal) -as [string])
                    $(if ($r5) {(Get-Random $type) -as [string] | Tee-Object -Variable selType})
                    $(if ($r6 -and ($selType -ne "l")) {(Get-Random $multiplier) -as [string]}))" -replace '\s', ''

                $out
            }
        }

        function Get-NumericLiterals7.1
        {
            param
            (
                [string] $regex = '^(?<sign>[+-])?(?:0b(?<bin>[01]+)|0x(?<hex>[0-9a-f]+)|(?<dec>(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?))(?<type>u?y|u?s|u?l|u|n|d)?(?<multiplier>kb|mb|gb|tb|pb)?$',
                [int] $numOfTests = 100
            )

            [string[]] $sign = '+', '-'
            [string[]] $bPrefix = '0b', '0B'
            [string[]] $bit = '0', '1'
            [string[]] $hPrefix = '0x', '0X'
            [string[]] $hex = '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'
            [string[]] $digit = '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
            [string[]] $exp = 'e', 'E'
            [string[]] $type = 'l', 'd', 'us', 's', 'ul', 'u', 'n', 'uy', 'y'
            [string[]] $multiplier = 'kb', 'mb', 'gb', 'tb', 'pb'

            for ($i = 0; $i -lt $numOfTests; $i++)
            {
                [string] $binary = (Get-Random $bPrefix) + (Get-Random $bit -Count (Get-Random -Minimum 1 -Maximum 4)) -replace '\s', ''
                [string] $hexadecimal = (Get-Random $hPrefix) + (Get-Random $hex -Count (Get-Random -Minimum 1 -Maximum 4)) -replace '\s', ''

                [bool] $r0 = $true, $false | Get-Random
                [bool] $r1 = $true, $false | Get-Random
                [bool] $r2 = ($true, $false | Get-Random) -or (-not ($r0 -and $r1))
                [bool] $r3 = $true, $false | Get-Random
                [bool] $r4 = $true, $false | Get-Random
                [bool] $r5 = $true, $false | Get-Random
                [bool] $r6 = $true, $false | Get-Random

                [string] $decimal = "$(if ($r0) {(Get-Random $digit -Count (Get-Random -Minimum 1 -Maximum 3)) -as [string]}
                    $(if ($r1) {`".`" -as [string]})
                    $(if ($r2) {(Get-Random $digit -Count (Get-Random -Minimum 1 -Maximum 2)) -as [string]})
                    $(if ($r3) {((Get-Random $exp) -as [string]) +
                    $(if ($r4) {(Get-Random $sign) -as [string]}) +
                    [string]$((Get-Random $digit -Count 1) -as [string])
                    }))" -replace '\s', ''

                [string] $out = "$(if ($true,$false | Get-Random) {(Get-Random $sign) -as [string]}
                    ($(Get-Random $binary, $hexadecimal, $decimal) -as [string])
                    $(if ($r5) {(Get-Random $type) -as [string] | Tee-Object -Variable selType})
                    $(if ($r6 -and ($selType -ne "l")) {(Get-Random $multiplier) -as [string]}))" -replace '\s', ''

                $out
            }
        }

        function Assert-StringExpansionIsSafe {}
        function Write-BootstrapLog {}
        function Get-ParsedValue
        {
            param
            (
                $InputObject,
                $LogFile,
                [switch] $ExpandEnvironmentVariables
            )

            $value = $ExecutionContext.InvokeCommand.ExpandString($InputObject)
            if ($ExpandEnvironmentVariables)
            {
                $value = [System.Environment]::ExpandEnvironmentVariables($value)
            }

            $value
        }

        #endregion

        # Provide log file for validation pass.
        $log = New-Item 'TestDrive:\boguslog.txt'

        foreach ($key in $streams.Keys)
        {
            Set-Content $streams[$key] -Value $null
        }

    }

    Context 'When config file contains nothing but (v5.1) numeric literals' {

        BeforeAll {

            # Make test config.
            $testConfig = New-Item 'TestDrive:\config.ini'
            Set-Content -Path $testConfig -Value $null -Force

            $i = 0
            foreach ($num in Get-NumericLiterals5.1)
            {
                Add-Content -Path $testConfig -Value "Value$i=$num"
                $i++
            }

            $config = Import-Ini -Path $testConfig -LogFile $log

        }

        It 'Should output an OrderedDictionary object.' {

            $config | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]

        }

        It 'Should output an object that only contains keys with numeric values' {

            for ($i = 0; $i -lt ($config['No-Section'].Count / 2); $i++)
            {
                # This "/ 1" implicitly casts the string to numeric type.
                $typed = $config['No-Section']["Value$i"] / 1

                $typed | Should -not -BeNullOrEmpty
            }

        }

        AfterAll {

            Remove-Item $testConfig

        }

    }

    Context 'When config file contains ' {

    }

    AfterAll {

        Remove-Item $log

    }

}