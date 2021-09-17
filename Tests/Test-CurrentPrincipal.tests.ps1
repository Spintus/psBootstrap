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
    . (Resolve-Path "$scriptRoot\Test-CurrentPrincipal.ps1")

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

Describe 'Test-CurrentPrincipal' {

    Context 'PLACEHOLDER' {

        It 'PLACEHOLDER' {

        }

    }

}