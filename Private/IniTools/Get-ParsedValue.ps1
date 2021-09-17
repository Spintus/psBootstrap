function Get-ParsedValue
{
    <#
        .SYNOPSIS
            Expand a string, attempt to cast it to various common types, then return it as
            whichever type it casts cleanly to.

        .DESCRIPTION
            This function uses regex to decide which type an object CAN cast to, and then
            performs the cast and returns the (now typed) value to the caller. Theoretically
            this has an identical effect to simply passing a string through the PS parser
            (at prompt), but PSv5's internal handling of this is scary voodoo magic that I
            can't reproduce.

            An additional feature is that when this is called, variable references in the
            string will be expanded/populated with their values (as the exist at call).
            A side effect is that sub-expressions also become populated with the
            corresponding values. See the comments at the top of 'EXAMPLE-config.ini' for
            examples. Of course, this seems to be completely useless, but at least it's
            there.


            WARNING: This is an inherently dangerous operation! ExpandString is a huge
            security risk if not handled properly. Calling ExpandString in an unrestricted
            runspace allows arbitrary code execution. This function should NEVER be exposed
            to users! The code-injection screening method of choice requires a huge amount
            of spin up/down to perform, and so is not implemented for every call to this
            function. For details, see 'Assert-StringExpansionIsSafe.ps1'.

        .PARAMETER InputObject
            The string which will be expanded and returned as the most applicable type.

        .PARAMETER ExpandEnvironmentVariables
            Specifies that environment variables should be expanded as well as PowerShell
            variables; e.g. '%HOMEDRIVE%' => 'C:' (or equivalent).

        .INPUTS
            System.String

            You can pipe a string to Import-Ini.

        .OUTPUTS
            System.Boolean
            System.Byte
            System.SByte
            System.Int16
            System.UInt16
            System.Int32
            System.UInt32
            System.Int64
            System.UInt64
            System.Decimal
            System.Double
            System.Numerics.BigInteger
            System.String

            This function returns the input object cast to a more applicable type.

        .EXAMPLE
            > Get-ParsedValue -InputObject '$(3 + 5), $true'
            8, True

        .LINK
            Import-Ini
            Resolve-IniReferences
            Test-IniContents
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $InputObject,

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
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Get-ParsedValue.log" -Force)
    )

    process
    {
        Write-BootstrapLog 'Verbose' "$($MyInvocation.MyCommand.Name): Parsing string: $InputObject" $LogFile

        # This line is the potentially dangerous one. See help documentation for how risk is mitigated.
        $value = $ExecutionContext.InvokeCommand.ExpandString($InputObject)
        if ($ExpandEnvironmentVariables)
        {
            $value = [System.Environment]::ExpandEnvironmentVariables($value)
        }

        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: Parsing string: $value" $LogFile
        # ExpandString always returns string, so to help avoid type errors parse and cast/convert here. List is NOT exhaustive.
        $value = switch -Regex ($value)
        {
            '^[^\s\d\w]?true$'         # [bool]
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: Matched boolean: $value" $LogFile

                [bool] $true
                break
            }
            '^[^\s\d\w]?false$'        # [bool]
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: Matched boolean: $value" $LogFile

                [bool] $false
                break
            }
            # This regex matches every well-formed numeric literal possible in PSv7. (See regex documentation!)
            '^(?<sign>[+-])?(?:0b(?<bin>[01]+)|0x(?<hex>[0-9a-f]+)|(?<dec>(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?))(?<type>u?y|u?s|u?l|u|n|d)?(?<multiplier>kb|mb|gb|tb|pb)?$'
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: Matched numeric literal: $value" $LogFile

                $match = $Matches

                [int64] $multiplier = switch ($match['multiplier'])
                {
                    'kb' { 1024; break }             # kibibyte multiplier
                    'mb' { 1048576; break }          # mebibyte multiplier
                    'gb' { 1073741824; break }       # gibibyte multiplier
                    'tb' { 1099511627776; break }    # tebibyte multiplier
                    'pb' { 1125899906842624; break } # pebibyte multiplier
                    default { 1 }                    # no multiplier
                }

                [string] $string = switch ($match)
                {
                    <# !!! Binary literals not supported in PSv5! (Introduced in core) !!!
                    { $_['bin'] } # Binary (integral)
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Key/Value pair: Numeric type: Matched binary: $value" $LogFile

                        $style = [Globalization.NumberStyles]::Integer

                        $_['bin']
                        break
                    }
                    #>
                    { $_['hex'] } # Hexadecimal (integral)
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched hexadecimal: $value" $LogFile

                        $style = [Globalization.NumberStyles]::HexNumber

                        $_['hex']
                        break
                    }
                    { $_['dec'] } # Decimal (integer/real)
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched decimal: $value" $LogFile

                        $style = switch -Regex ($_['dec'])
                        {
                            '^(\d*\.?\d*)e([+-]?\d+)$' # Sci. notation (real)
                            {
                                [Globalization.NumberStyles]::Float
                                break
                            }
                            '^\d*\.\d*$' # 'ipart.fpart' notation (real)
                            {
                                [Globalization.NumberStyles]::Number
                                break
                            }
                            '^\d+$' # integer notation (integer)
                            {
                                [Globalization.NumberStyles]::Integer
                                break
                            }
                            default # malformed
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Decimal type: Could not match any types: $value" $LogFile
                            }
                        }

                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Decimal type: Matched $($style): $value" $LogFile

                        $_['dec']
                        break
                    }
                    default
                    {
                        Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Could not match any types: $value" $LogFile
                    }
                }

                if ($match['sign'] -eq '-')
                {
                    $multiplier = $multiplier * -1
                }

                try
                {
                    # Type parsing/converting. For ordering details, see msdn:about_numeric_literals.
                    # TODO: Reduce casting/parsing steps and increase error handling specificity/coverage.
                    $ref = 0
                    $value = switch ($match['type'])
                    {
                        'y' # signed byte data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [sbyte]: $value" $LogFile

                            if ([sbyte]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [sbyte] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [sbyte] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'uy' # unsigned byte data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [byte]: $value" $LogFile

                            if ([byte]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [byte] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [byte] type: Invalid literal: $value" $LogFile
                            }
                        }
                        's' # signed short data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [int16]: $value" $LogFile

                            if ([int16]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [int16] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [int16] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'us' # unsigned short data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [uint16]: $value" $LogFile

                            if ([uint16]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [uint16] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [uint16] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'l' # signed long data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [int64]: $value" $LogFile

                            if ([int64]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [int64] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [int64] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'ul' # unsigned long data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [uint64]: $value" $LogFile

                            if ([uint64]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [uint64] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [uint64] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'n' # BigInteger data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [bigint]: $value" $LogFile

                            if ([bigint]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [bigint] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [bigint] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'd' # decimal data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [decimal]: $value" $LogFile

                            if ([decimal]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [decimal] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [decimal] type: Invalid literal: $value" $LogFile
                            }
                        }
                        'u' # unsigned int or long data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [uint32] or [uint64]: $value" $LogFile

                            if ([uint32]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [uint32] ($ref * $multiplier)
                                break
                            }
                            elseif ([uint64]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [uint64] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [uint32] or [uint64] type: Invalid literal: $value" $LogFile
                            }
                        }
                        default # no data type
                        {
                            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Matched [int32], [int64], [decimal], or [double]: $value" $LogFile

                            if ([int32]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [int32] ($ref * $multiplier)
                                break
                            }
                            elseif ([int64]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [int64] ($ref * $multiplier)
                                break
                            }
                            elseif ([decimal]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [decimal] ($ref * $multiplier)
                                break
                            }
                            elseif ([double]::TryParse($string, $style, $culture, [ref] $ref))
                            {
                                [double] ($ref * $multiplier)
                                break
                            }
                            else
                            {
                                Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: [int32], [int64], [decimal], or [double] type: Invalid literal: $value" $LogFile
                            }
                        }
                    }

                    Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Assigned to correct numeric type: $value" $LogFile

                    $value
                }
                catch
                {
                    Write-BootstrapLog 'Error' "$($MyInvocation.MyCommand.Name): Regex parse: Numeric type: Could not assign to correct type: $value. Numeric literal may be malformed!" $LogFile
                }
            }
            default
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Regex parse: Did not match any types; assuming string: $value" $LogFile

                $value
            }
        }

        # Return value.
        $value
    }
}
