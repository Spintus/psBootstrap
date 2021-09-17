function Import-Ini
{
    <#
        .SYNOPSIS
            Parse a .ini file and return an OrderedDictionary object of file contents
            (key/value pairs, sections, and comments).

        .DESCRIPTION
            This function takes a string as filepath (absolute or relative) to some file
            which contains (ini style) key/value pairs and returns those as an ordered
            dictionary. Each value is run through ExpandString() before it is saved. This
            allows values which reference variables defined only at script execution to be
            imported and saved with the correct values. Without the ExpandString() call,
            referenced variables would not be correctly populated with their values.

            For instance, if config.ini is:
            +---------------------+
            |[reference test]     |
            |myIniVar=$myScriptVar|
            +---------------------+

            Given that $myScriptVar is defined when Import-Ini is called, the reference
            will properly resolve, like so:

            > $mySriptVar = 'script value'
            > $config = Import-Ini -Path .\config.ini
            > echo $config['reference test']['myIniVar']
            script value


            WARNING: This is an inherently dangerous operation! ExpandString is a huge
            security risk if not handled properly. Calling ExpandString in an unrestricted
            runspace would allow arbitrary code injection; anything in the config file
            could be executed as code. To prevent this possibility, this function
            implements a test which will catch on any attempted execution and halts
            immediately, throwing a scary looking exception. This test is implemented with
            jobs and restricted runspaces.

            Note: The unexpanded version of the string is also saved alongside the expanded
            version. This is memory inefficient, but allows for the implementation of
            Resolve-IniReferences, for the case where the ini content is loaded at some
            point in a script, but the variables referenced within have changed since
            Import-Ini was called. In this case, the previously expanded variables will now
            be incorrect as their references were resolved already. The other option would
            be to expand them when referenced, but that would cause massive overhead as
            they would then need JIT parsing and casting (maybe I just write c♯ for this).

            Note: This function, similiarly to Export-Ini, quite obviously violates SRP. A
            refactor (or maybe rewrite, though this could break old scripts) is in order.

            ToDo: Write class for ini object to offload validation/construction.

        .PARAMETER Path
            Specifies the path (relative or absolute) to the ini file to import. You can
            also pipe a path to Import-Ini.

        .PARAMETER ExpandEnvironmentVariables
            Specifies that environment variables should be expanded as well as PowerShell
            variables; e.g. '%HOMEDRIVE%' => 'C:' (or equivalent).

        .INPUTS
            System.String

            You can pipe a string that contains a path to Import-Ini.

        .OUTPUTS
            System.Collections.Specialized.OrderedDictionary

            This function returns the object described by the content in the Ini file.

        .EXAMPLE
            > $config = Import-Ini -Path .\config.ini

            Parses config.ini, and generates an OrderedDictionary containing two versions
            of each key/value pair:
                key           => the expanded value of the string in the ini file.
                keyunexpanded => the literal string (so references can be resolved later).

        .EXAMPLE
            config.ini:
            +-------+
            |[vars] |
            |foo=bar|
            +-------+

            > $config = Import-Ini -Path .\config.ini
            > $config['vars']['foo']
            bar

            Note: Keys or comments before the first section title (if any) will be under
            $config['No-Section']

        .LINK
            Export-Ini
            Resolve-IniReferences
            Test-IniContents
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([a-zA-Z]\:)?.+\.ini$')]
        [ValidatePathExists()] # Custom validator.
        [string]
        # Specifies the path (relative or absolute) to the ini file to import.
        # You can also pipe a path to Import-Ini.
        $Path,

        [Parameter()]
        [switch]
        # Specifies that environment variables should be expanded as well as
        # PowerShell variables; e.g. '%HOMEDRIVE%' => 'C:' (or equivalent).
        $ExpandEnvironmentVariables,

        [Parameter()]
        [ValidateScript({[CultureInfo]::GetCultureInfo($_)})]
        [string]
        # Specifies the name of the culture/locale to be used when parsing
        # numeric literals. Uses current by default. Examples: 'en-US', 'fr-CA'.
        $CultureName = $(Get-Culture).Name,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator.
        [string]
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Import-Ini.log" -Force)
    )

    process
    {
        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Getting ini content from file: $Path" $LogFile

        # This prevents code injection. See help documentation for how and why this is necessary.
        Assert-StringExpansionIsSafe -String $(Get-Content $Path -Raw) -LogFile $LogFile

        $config = [ordered] @{}
        $section = $false

        $file = Get-Content -Path $Path

        $i = 0 # Index for write-progress
        $n = $file.Count
        foreach ($line in $file)
        {
            Microsoft.PowerShell.Utility\Write-Progress -Status "$line " -PercentComplete ($i / $n * 100) -Activity "$($MyInvocation.MyCommand.Name): Importing from $Path. This may take a while."

            Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Parsing line: $line" $LogFile
            switch -Regex ($line)
            {
                '^\s*$'         # Empty/whitespace
                {
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Matched whitespace: $line" $LogFile
                    break
                }
                '^\[(.+)\]$'     # Section title
                {
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Matched section title: $line" $LogFile

                    $section = $Matches[1]
                    $config[$section] = [ordered] @{}
                    $commentCount = 0

                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Section title: Assigned: `$config[$section] = [ordered] @{}" $LogFile

                    break
                }
                '^([;#].*)$'    # Comment
                {
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Matched comment: $line" $LogFile

                    if (-not ($section))
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Comment: No section. Creating." $LogFile

                        $section = 'No-Section'
                        $config[$section] = [ordered] @{}
                        $commentCount = 0
                    }

                    $value = $Matches[1]
                    $name = 'Comment' + $commentCount
                    $config[$section][$name] = $value

                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Comment: Assigned: `$config[$section][$name] = $value" $LogFile

                    $commentCount++
                    break
                }
                '^([^;#]+?)\s*=(.*)$' # Key/Val pair
                {
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Matched Key/Value pair: $line" $LogFile

                    if (-not ($section))
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: No section. Creating." $LogFile

                        $section = 'No-Section'
                        $config[$section] = [ordered] @{}
                        $commentCount = 0
                    }

                    $key, $rawValue = $Matches[1..2]

                    # Parse the value and get the expanded version. This function is unsafe!
                    # Be sure that Assert-StringExpansionIsSafe has been called before this!
                    $value = Get-ParsedValue -InputObject $rawValue -ExpandEnvironmentVariables:$ExpandEnvironmentVariables -LogFile $LogFile

                    # Actually save the variable, both expanded and raw.
                    $config[$section][$key] = $value
                    $config[$section][$key + 'unexpanded'] = $rawValue

                    Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Regex parse: Assigned: `$config[$section][$key] = $value" $LogFile
                    Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Regex parse: Assigned: `$config[$section][$($key)unexpanded] = $rawValue" $LogFile

                    break
                }
                default         # Malformed line
                {
                    Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Could not match with any known .ini content types: $_" $LogFile
                }
            }

            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Done parsing line: $line" $LogFile

            $i++
        }

        # Call -Completed on progress bar.
        Microsoft.PowerShell.Utility\Write-Progress -Activity "$($MyInvocation.MyCommand.Name): Importing from $Path. This may take a while." -PercentComplete 100 -Completed

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done Getting ini content from file: $Path" $LogFile

        # Return the dictionary to the caller.
        $config
    }
}
