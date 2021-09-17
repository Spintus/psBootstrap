Describe 'Assert-StringExpansionIsSafe' {

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
        . (Resolve-Path "$scriptRoot\Assert-StringExpansionIsSafe.ps1")

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

        # Mock functions.
        function Write-BootstrapLog {}

        # Provide log file for validation pass.
        $log = New-Item 'TestDrive:\boguslog.txt'

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

    Context 'always' {

        It 'should reject null input' {

            {Assert-StringExpansionIsSafe -String '' -LogFile $log} | Should -Throw "Cannot validate argument on parameter 'String'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."

        }

        It 'should reject input which includes cmdlets' {

            {Assert-StringExpansionIsSafe -String '$(Get-Date)' -LogFile $log} | Should -Throw 'Assert-StringExpansionIsSafe: String expansion caught attempted code execution! This may be a security issue!'
            {Assert-StringExpansionIsSafe -String '$(Write-Host "")' -LogFile $log} | Should -Throw 'Assert-StringExpansionIsSafe: String expansion caught attempted code execution! This may be a security issue!'
            {Assert-StringExpansionIsSafe -String '$(Add-Type "")' -LogFile $log} | Should -Throw 'Assert-StringExpansionIsSafe: String expansion caught attempted code execution! This may be a security issue!'

        }

        It 'should allow references to automatic variables' {

            {Assert-StringExpansionIsSafe -String '$PSVersionTable' -LogFile $log} | Should -Not -Throw

        }

        It 'should allow references to system variables' {

            {Assert-StringExpansionIsSafe -String '%HOMEDRIVE%' -LogFile $log} | Should -Not -Throw

        }

        It 'should allow references to normal variables' {

            $test = 'Test String'
            {Assert-StringExpansionIsSafe -String '$test' -LogFile $log} | Should -Not -Throw

        }

    }

    AfterAll {

        # Remove bogus log.
        Remove-Item $log

    }

}
