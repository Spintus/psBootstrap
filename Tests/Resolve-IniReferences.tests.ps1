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
    . (Resolve-Path "$scriptRoot\Resolve-IniReferences.ps1")

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

Describe 'Resolve-IniReferences' {

    BeforeAll {

        $value0 = 'String 0'
        $value1 = 'String 1'
        $value2 = 'String 2'
        $value3 = [System.Environment]::ExpandEnvironmentVariables("%COMSPEC%")

        # Generate valid ini object.
        $inputObject = [ordered] @{
            'No-Section' = [ordered] @{
                Comment0           = "; Comment0"
                Comment0unexpanded = '; Comment0'
                Comment1           = "; Comment1"
                Comment1unexpanded = '; Comment1'
            }
            Strings      = [ordered] @{
                Key0           = "value0 = $value0"
                Key0unexpanded = 'value0 = $value0'
                Key1           = "value0 = $value1"
                Key1unexpanded = 'value1 = $value1'
                Key2           = "value0 = $value2"
                Key2unexpanded = 'value2 = $value2'
                Key3           = "value3 = $value3"
                Key3unexpanded = 'value3 = %COMSPEC%'
            }
            Numbers      = [ordered] @{
                Key0           = '12345'
                Key0unexpanded = '12345'
                Key1           = '1.2e+3'
                Key1unexpanded = '12345'
                Key2           = '-0x10'
                Key2unexpanded = '12345'
            }
        }

        # Generate invalid ini objects.
        $badInput0 = [ordered] @{
            'No-Section' = @{
                Comment0           = "; Comment0"
                Comment0unexpanded = '; Comment0'
            }
        }

    }

    Context 'when given invalid input objects' {

        It 'should throw on parameter binding' {

            { Get-ExpandedValuesFromDictionary -InputObject $badInput0 } | Should -Throw -Because 'Input object does not pass the ValidationScript.'

        }

    }

    Context 'when expanding environment variables' {

        BeforeAll {

            $outputObject = Get-ExpandedValuesFromDictionary -InputObject $inputObject -ExpandEnvironmentVariables

        }

        It 'should expand environment variables' {

            $outputObject['Strings']['Key3'] | Should -Be "value3 = $value3"

        }

    }

    Context 'when not expanding environment variables' {

        BeforeAll {

            $outputObject = Get-ExpandedValuesFromDictionary -InputObject $inputObject

        }

        It 'should contain the same sections as before' {

            $outputObject.Keys | Should -Be @('No-Section', 'Strings', 'Numbers')

        }

        It 'should contain the same keys as before' {

            foreach ($section in $inputObject.Keys)
            {
                foreach ($key in $section)
                {
                    $outputObject[$section][$key] | Should -Be $inputObject[$section][$key]
                }
            }

        }

        It 'should not expand environment variables' {

            $outputObject['Strings']['Key3'] | Should -Be 'value3 = %COMSPEC%'

        }

    }

}