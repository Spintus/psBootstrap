function Export-Ini
{
    <#
        .SYNOPSIS
            Write the contents of an OrderedDictionary object to an ini file on disk.

        .DESCRIPTION
            Write OrderedDictionary content to ini file, including key/val pairs, comments,
            and sections. See Import-Ini for how this dictionary can be structured.

            Note: This function, similiarly to Export-Ini, quite obviously violates SRP. A
            refactor (or maybe rewrite, though this could break old scripts) is in order.

            Problems to fix:

                • Either break UTF8noBOM implementation into its own function or implement
                ALL encodings in a consistent way.

            ToDo: Write class for ini object to offload validation/construction.

        .PARAMETER Append
            Adds the output to the end of an existing file, instead of replacing the file
            contents.

        .PARAMETER InputObject
            Specifies the OrderedDictionary to be written to the file. Enter a variable
            that contains the objects or type a command or expression that gets the object.

        .PARAMETER FilePath
            Specifies the path to the output file.

        .PARAMETER MyEncoding
            Specifies the type of character encoding used in the file. Valid values are
            'Unicode', 'UTF7', 'UTF8', 'UTF32', 'ASCII', 'BigEndianUnicode', 'Default',
            'OEM', and 'UTF-8noBOM'. 'UTF-8noBOM' is the default.

            'Default' uses the encoding of the system's current ANSI code page
            (probably Windows-1252).

            'OEM' uses the current original equipment manufacturer code page identifier for
            the OS (probably Windows-1252).

            Note: 'UTF8noBOM' encoding is not supported in Powershell v5.1 (supported in
            Core 6+). As such, usage of this option has been implemented to avoid calling
            Add-Content, as parameter binding will fail due to invalid 'Encoding' param.
            Instead, if this encoding is specified, the file is written to by directly
            manipulating a StreamWriter object. Every other encoding is supported by
            Add-Content, and implemented using it.

        .PARAMETER Force
            Allows the cmdlet to overwrite an existing read-only file. Does not override
            access permissions.

        .PARAMETER PassThru
            Passes an object representing the location to the pipeline. By default, this
            cmdlet does not generate any output.

        .PARAMETER ExpandedPreference
            For OrderedDictionaries which contain both expanded and unexpanded versions of
            key/value pairs (See Import-Ini), specify which version(s) to write to file. By
            default only the unexpanded version is written.

            This behavior is bad for human readability, but it allows Import-Ini to extract
            all of the information stored in the file. See Import-Ini help for specifics,
            but the important part is that you can save and load values which contain
            references, and the way you do it is with unexpanded strings. This ability is
            why Import-Ini was written, and it is the primary usage of this function too.

            If the expanded version is written instead, the output file will be less useful
            for Import-Ini, as variable references can no be longer resolved (they already
            have been). It will be more human readable however.

            If both versions are written, the output file will be useless for Import-Ini,
            as there would be redundant versions of every key created, doubling the size of
            the object for nothing. Mainly used for debugging purposes.

        .Inputs
            System.String
            System.Collections.Specialized.OrderedDictionary

        .Outputs
            System.IO.FileSystemInfo

        .Example
            > Export-Ini $IniVar '.\myinifile.ini'

            Saves the content of the $IniVar OrderedDictionary to the file .\myinifile.ini.

        .Example
            > $IniVar | Export-Ini '.\myinifile.ini' -Force

            Saves the content of the $IniVar OrderedDictionary to the file .\myinifile.ini,
            overwriting the file if it is already present.

        .Example
            > $file = Export-Ini $IniVar '.\myinifile.ini' -PassThru

            Saves the content of $IniVar to the file .\myinifile.ini and also saves the
            file as $file variable. -PassThru flag will propagate the file object down the
            pipeline, if applicable.

        .Example
            > $category1 = [ordered] @{'key1'='value1';'key2'='value2'}
            > $category2 = [ordered] @{'key1'='value1';'key2'='value2'}
            > $newIniContent = [ordered] @{'category1'=$category1;'category2'=$category2}
            > Export-Ini -InputObject $newIniContent -FilePath '.\myNewFile.ini'

            Creates a custom OrderedDictionary object $newIniContent which contains
            OrderedDictionaries corresponding to ini sections. Those section
            OrderedDictionaries contain key/val pairs (and optionally comments). Finally
            saves it to .\myNewFile.ini.

        .Link
            Import-Ini
            Resolve-IniReferences
            Test-IniContents
    #>
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Ascii','BigEndianUnicode','BigEndianUTF32','Byte','Default'
        ,'Oem','String','Unicode','Unknown','UTF7','UTF8','UTF32','UTF8noBOM')]
        [string]
        # Specifies the encoding desired for output file. Default is 'UTF8noBOM'.
        $MyEncoding = 'UTF8noBOM',

        [Parameter()]
        [ValidateSet('Expanded','Unexpanded','All')]
        [string]
        # For OrderedDictionaries which contain both 'Expanded' and 'Unexpanded'
        # versions of key/value pairs, specifies which version(s) to write to file.
        $ExpandedPreference = 'Unexpanded',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([a-zA-Z]\:)?.+\.ini$')]
        [string]
        # Specifies the path to save the .ini file to.
        $FilePath,

        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Collections.Specialized.OrderedDictionary]
        # Specifies an OrderedDictionary object corresponding to an ini file to
        # be exported (See help for object requirements).
        $InputObject,

        [switch] $Append,
        [switch] $Force,
        [switch] $Passthru,

        [Parameter(DontShow)]
        [ValidatePathExists()] # Custom validator.
        [string]
        $LogFile = (New-Item -ItemType File -Path "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyyMMdd')\$(Get-Date -Format 'HHmmss')_Export-Ini.log" -Force)
    )

    process
    {
        $sw = $false

        if ($append)
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Appending to file: $FilePath" $LogFile

            $outfile = Get-Item $FilePath
        }
        else
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Creating new file: $FilePath" $LogFile

            $outFile = New-Item -ItemType file -Path $Filepath -Force:$Force
        }

        if (-not ($outFile))
        {
            throw "$($MyInvocation.MyCommand.Name): Could not create File"
        }

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Writing to file: $Filepath" $LogFile

        # For no BOM, must use .NET methods directly, as Add-Content always adds BOM.
        if ($MyEncoding -eq "UTF8noBOM")
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Encoding == UTF8noBOM. Requires use of SteamWriter; PSv5.1 only writes with BOM." $LogFile

            $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
            [System.Environment]::CurrentDirectory = (Get-Location).Path # Set-Location does not change CurrentDirectory, so do it now.
            $sw = New-Object IO.StreamWriter $FilePath, $true, $utf8NoBomEncoding
        }

        foreach ($i in $InputObject.keys)
        {
            if ($($InputObject[$i].GetType().Name) -ne "OrderedDictionary")
            {
                #No Sections
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Writing to file: $($i=$($InputObject[$i]))" $LogFile

                if ($MyEncoding -eq "UTF8noBOM")
                {
                    $sw.WriteLine("{0}", "$($i=$($InputObject[$i]))")
                }
                else
                {
                    Add-Content -Path $outFile -Value "$i=$($InputObject[$i])" -Encoding $MyEncoding
                }
            }
            else
            {
                #Sections
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Writing to file: [$i]" $LogFile

                if ($MyEncoding -eq "UTF8noBOM")
                {
                    $sw.WriteLine("{0}", "[$i]")
                }
                else
                {
                    Add-Content -Path $outFile -Value "[$i]" -Encoding $MyEncoding
                }

                foreach ($j in $($InputObject[$i].keys | Sort-Object))
                {
                    if ($j -match "^Comment[\d]+")
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Writing to file: $($InputObject[$i][$j])" $LogFile

                        if ($MyEncoding -eq "UTF8noBOM")
                        {
                            $sw.WriteLine("{0}", "$($InputObject[$i][$j])")
                        }
                        else
                        {
                            Add-Content -Path $outFile -Value "$($InputObject[$i][$j])" -Encoding $MyEncoding
                        }
                    }
                    else
                    {
                        Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Writing to file: $($j=$($InputObject[$i][$j]))" $LogFile

                        if ($MyEncoding -eq "UTF8noBOM")
                        {
                            $sw.WriteLine("{0}", "$($j=$($InputObject[$i][$j]))")
                        }
                        else
                        {
                            Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])" -Encoding $MyEncoding
                        }
                    }
                }

                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Writing to file: [newline]" $LogFile

                if ($MyEncoding -eq "UTF8noBOM")
                {
                    $sw.WriteLine("{0}", "")
                }
                else
                {
                    Add-Content -Path $outFile -Value "" -Encoding $MyEncoding
                }
            }
        }

        if ($sw)
        {
            try
            {
                Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Closing/Disposing streamwriter." $LogFile

                $sw.Close()
            }
            catch
            {
                throw "$($MyInvocation.MyCommand.Name): Could not call Close() on StreamWriter: $sw"
            }
        }

        Write-BootstrapLog 'Info' "$($MyInvocation.MyCommand.Name): Done Writing to file: $Filepath" $LogFile

        if ($PassThru)
        {
            Write-BootstrapLog 'Debug' "$($MyInvocation.MyCommand.Name): Returning file contents. (`$PassThru = `$true)" $LogFile

            return $outFile
        }
    }
}
