function Resolve-IniReferences
{
    <#
        .SYNOPSIS
            Takes unexpanded strings in an OrderedDictionary and expands them. Returns a
            new OrderedDictionary.

        .DESCRIPTION
            Given that InputObject is a "well-formed" OrderedDictionary of .ini file
            contents (See Import-Ini and Export-Ini), this function iterates through each
            key/value pair in the object. For each key found whose name ends with
            'unexpanded', the value of that key is run through ExpandString() to resolve
            variables and sub-expressions. Both expanded and unexpanded versions of the
            key/value are rolled into a new OrderedDictionary and returned. The .ini
            sections and comments are preserved. With "well-formed" .ini objects, this
            function is idempotent.

            Note: This function is to be used ONLY with output of Import-Ini. WILL NOT
            WORK on every OrderedDictionary.

            WARNING: This function is inherently dangerous as it can execute arbitrary
            code. See Assert-StringExpansionIsSafe for how this risk is safely mitigated.

        .PARAMETER InputObject
            An object which conforms to ini file standards, loaded in Powershell as an
            OrderedDictionary. See Import-Ini.

        .PARAMETER ExpandEnvironmentVariables
            Specifies that environment variables should be expanded e.g. %HOMEDRIVE% => C:.

        .INPUTS
            System.Collections.Specialized.OrderedDictionary

        .OUTPUTS
            System.Collections.Specialized.OrderedDictionary

        .EXAMPLE
            > $expandedStringsIni = Resolve-IniReferences -InputObject $unexpandedStringsIni

            Processes the $unexpandedStringsIni object, parses the contents and expands the
            'unexpanded' strings, and saves the object to the new variable
            $expandedStringsIni. If none of the references changed, resulting object is
            identical.

        .NOTES
            WARNING: This function is inherently dangerous as it can execute arbitrary
            code. See Assert-StringExpansionIsSafe for how this risk is safely mitigated.

        .LINK
            Import-Ini
            Export-Ini
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                foreach ($section in $_.Keys)
                {
                    $_[$section] -is [Collections.Specialized.OrderedDictionary]
                }
            }
        )]
        [Collections.Specialized.OrderedDictionary]
        # Specifies the OrderedDictionary which has keys appended with
        # 'unexpanded' which require string expansion.
        $InputObject,

        [Parameter()]
        [switch]
        # Specifies that environment variables should be expanded as well as
        # PowerShell variables; e.g. '%HOMEDRIVE%' => 'C:' (or equivalent).
        $ExpandEnvironmentVariables,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator.
        [string]
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Resolve-IniReferences.log" -Force)
    )

    process
    {
        Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Testing string expansion is safe."

        # This prevents code injection. See help documentation for how and why this is necessary.
        Assert-StringExpansionIsSafe -String (
            [System.String]::Concat(
                $(
                    foreach ($section in $InputObject.Keys)
                    {
                        foreach ($key in $InputObject[$section].Keys)
                        {
                            $InputObject[$section][$key]
                        }
                    }
                )
            )
        ) -LogFile $LogFile

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Expanding strings from input object."

        $outputObject = [ordered] @{}
        $section = $false

        foreach ($section in $InputObject.Keys)
        {
            Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Parsing object: $section" $LogFile
            switch ($InputObject[$section].GetType().Name)
            {
                'OrderedDictionary' # Section title
                {
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Matched section title: $section" $LogFile
                    $section = $section
                    $outputObject[$section] = [ordered]@{}
                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Assigned: `$outputObject[`"$section`"] = [ordered]@{}" $LogFile

                    foreach ($key in $InputObject[$section].Keys)
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: $key" $LogFile
                        switch -Regex ($key)
                        {
                            '^Comment(.+)'    # Comment
                            {
                                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: Matched comment: $key" $LogFile
                                $value = $InputObject[$section][$key]
                                $name = $Matches[0]

                                $outputObject[$section][$name] = $value
                                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: Assigned: `$outputObject[`"$section`"][`"$name`"] = $value" $LogFile
                            }
                            '(.+)unexpanded$' # Key/Val pair
                            {
                                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: Matched Key/Value pair: $key" $LogFile

                                # Parse the value and get the expanded version. This function is unsafe!
                                # Be sure that Assert-StringExpansionIsSafe has been called before this!
                                $value = Get-ParsedValue -InputObject $InputObject[$section][$key] -ExpandEnvironmentVariables:$ExpandEnvironmentVariables -LogFile $LogFile

                                $outputObject[$section][$Matches[1]] = $value
                                $outputObject[$section][$key] = $InputObject[$section][$key]
                                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: Assigned: `$outputObject[`"$section`"][`"$($Matches[1])`"] = $value" $LogFile
                                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Parsing sub-object: Assigned: `$outputObject[`"$section`"][`"$section`"] = $inputObject" $LogFile
                            }
                            default { break } # Already expanded
                        }
                    }
                }
                'String'            # Comment or Key/Val pair (no sections!)
                {
                    if (-not ($section))
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: No section found; generating." $LogFile
                        $section = 'No-Section'
                        $outputObject[$section] = [ordered]@{}
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Assigned: `$outputObject[`"$section`"] = [ordered]@{}" $LogFile
                    }
                    switch -Regex ($section)
                    {
                        '^Comment(.+)'    # Comment
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Regex parse: Matched comment: $section" $LogFile
                            $value = $InputObject[$section][$key]
                            $name = $Matches[0]

                            $outputObject[$section][$name] = $value
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Section `"$($section)`": Assigned: `$outputObject[`"$section`"][`"$name`"] = $value" $LogFile
                        }
                        '(.+)unexpanded$' # Key/Val pair
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Regex parse: Matched Key/Value pair: $section" $LogFile

                            # Parse the value and get the expanded version. This function is unsafe!
                            # Be sure that Assert-StringExpansionIsSafe has been called before this!
                            $value = Get-ParsedValue -InputObject $InputObject[$section][$key] -ExpandEnvironmentVariables:$ExpandEnvironmentVariables -LogFile $LogFile

                            $outputObject[$section][$Matches[1]] = $value
                            $outputObject[$section][$section] = $InputObject[$section][$key]
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Regex parse: Assigned: `$outputObject[`"$section`"][`"$($Matches[1])`"] = $value" $LogFile
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Regex parse: Assigned: `$outputObject[`"$section`"][`"$section`"] = $inputObject" $LogFile
                        }
                        default           # Already expanded
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Parsing object: Regex parse: No match (Already expanded)." $LogFile
                            break
                        }
                    }
                }
            }

            Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Done parsing object: $section" $LogFile
        }

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done Expanding strings from input object." $LogFile
        $outputObject
    }
}
