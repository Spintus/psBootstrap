function Test-IniContents
{
    <#
        .SYNOPSIS
            Search an OrderedDictionary object for keys listed in a hashtable. Write error if any keys are not found.

        .DESCRIPTION
            The OrderedDictionary object must contain Ini file contents (See Get-IniContent). For each array in the hashtable,
            test if the Ini contents have a section titled with the array name. For each string in that array, test if the Ini
            contents have a key under that section with that name. If any of these tests fail, write an error.

        .PARAMETER MandatorySettings
            This hashtable must only contain arrays of strings. Structure must be identical to Ini Contents.

        .PARAMETER IniContent
            This OrderedDictionary must only contain Ini file contents. See Get-IniContent for details on such objects.

        .INPUTS
            System.Collections.Hashtable
            System.Collections.Specialized.OrderedDictionary

        .OUTPUTS
            None

        .EXAMPLE
            > $config = [ordered] @{
            >>    section1 = [ordered] @{
            >>        key1 = "value1"
            >>        key2 = "value2"
            >>        key3 = "value3"
            >>    }
            >>    section2 = [ordered] @{
            >>        key2 = "value2" #    <-- This key does not match the name in the test hash.
            >>    }
            >>}

            > $myHash = @{
            >>    section1 = @(
            >>        "key1"
            >>        "key2"
            >>    )
            >>    section2 = @(
            >>        "key1"
            >>    )
            >>}

            > Test-IniContent -MandatorySettings $myHash -IniContent $config
            Error: Test-IniContent: Mandatory setting not found in config: [section2]: key1. Make sure this key exists in
            config and has a value.

        .LINK
            Import-Ini
            Export-Ini
            Resolve-IniReferences
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [hashtable]
        # Specifies a hashtable containing groups and keys which must exist in the Ini object.
        $ValidationHash,

        [Parameter(Mandatory)]
        [Collections.Specialized.OrderedDictionary]
        # Specifies an OrderedDictionary object containing Ini file contents to test.
        $IniContent,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator.
        [string]
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Test-IniContents.log" -Force)
    )

    Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Testing that Ini contents contain all mandatory keys." $LogFile

    foreach ($section in $ValidationHash.Keys)
    {
        Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Testing section: [$section]" $LogFile

        foreach ($key in $ValidationHash[$section].Keys)
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Testing key: [$section]: $key" $LogFile

            if ($null -eq $IniContent[$section][$key])
            {
                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Mandatory setting not found in config: [$section]: $key. Make sure this key exists in config and has a value." $LogFile
            }
            else
            {
                Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Found key: [$section]: $key" $LogFile
            }
        }

        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Done testing section: [$section]" $LogFile
    }

    Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done testing that Ini contents contain all mandatory keys." $LogFile
}
