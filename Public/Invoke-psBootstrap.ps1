function Invoke-psBootStrap
{
    <#
        .SYNOPSIS
            Executes many helper functions which perform various initialization-related
            tasks e.g. importing modules and fixing host annoyances.

        .DESCRIPTION
            Invoke-psBootstrap executes many helper functions which perform various
            initialization-related tasks. These include:

                ○ Set-QuickEdit
                    Disables PowerShell console's 'QuickEdit' mode[0].

                ○ Test-CurrentPrincipal
                    Verifies that the executing user has the permissions required for
                    execution of a particular script.

                ○ Get-IniContent
                    Imports an ini file and parses it for sections, comments, and key/value
                    pairs. Values are typed*.

                    Defines an OrderedDictionary object corresponding to the file in
                    caller's session (see comment-based help for Get-IniContent.).

                ○ Test-IniContent
                    Validates the structure/content of an OrderedDictionary object
                    (obtained with Get-IniContent).

                    Given an OrderedDictionary and a HashTable (see comment-based help for
                    Test-IniContent.), ensures that the sections and keys represented by
                    the HashTable are present in the OrderedDictionary. If the
                    OrderedDictionary does not contain any of the sections or keys in the
                    HashTable, an error is written.

                ○ Import-Items
                    Automatically loads modules in a directory.

                    Given a directory path, import-module is called on every module file
                    (.psm1/.psd1) listed which is found in a recursive search of the given
                    directory.

                    All modules imported get a remove-module call for them added to the
                    psBoostrap OnRemove block. When boostrapper is removed, so are they.

                ○ Set-VerbosityLevel
                    Sets various preference variables according to a bitmap. The reason
                    this is done explicitly is that preference variable inheritance is
                    totally broken (as of Core 7.0.).

        .PARAMETER ConfigFilePath
            Specifies the path (relative or absolute) to the configuration file (normally
            located in ScriptRoot.). This must point to a well-formed ini file.

        .PARAMETER ImportPath
            Specifies the path (relative or absolute) to the directory containing modules
            for importation (normally located in ScriptRoot\Dependencies).

        .PARAMETER EnforceRole
            Specifies the WindowsBuiltInRole that the current principal must be in (See
            System.Security.Principal.WindowsBuiltInRole enum.).

        .PARAMETER MandatorySettings
            Specifies sections and keys which must be present in the config file (See
            Test-IniContent.).

        .INPUTS
            System.String
            System.Security.Principal.WindowsBuiltInRole
            System.Collections.Hashtable
            System.Management.Automation.SwitchParameter

        .OUTPUTS
            System.Collections.Specialized.OrderedDictionary

        .EXAMPLE
            >  $bootstrapHash = @{}
            >>
            >> Import-Module '.\Dependencies\psBootstrapV3.psd1'
            >>
            >> Invoke-psBootstrap @bootstrapHash

            The simplest legal call to Invoke-psBootstrap includes no parameters. Called
            thusly, Invoke-psBootstrap will do nothing.

        .EXAMPLE
            >  $mandatorySettings = @{
            >>     Settings = @(
            >>         'scriptName'
            >>         'hostLevel'
            >>         'doDryRun'
            >>         'confirmPreference'
            >>     )
            >> }
            >>
            >> $bootstrapHash = @{
            >>     ConfigFilePath     = .\config.ini
            >>     MandatorySettings  = $mandatorySettings
            >>     ImportPath         = .\importDir
            >>     EnforceRole        = 'Administrator'
            >>     DisableQuickEdit   = $true
            >>     BootstrapLogFile   = (New-Item '.\bootstrap.log' -Force).FullName
            >>     DebugBootstrap     = $false
            >> }
            >>
            >> Import-Module '.\Dependencies\psBootstrapV3.psd1'
            >>
            >> $config = Invoke-psBootstrap @bootstrapHash

            The hashtable passed to Invoke-psBootstrap supplies parameters for the helper
            functions which are automatically executed: ConfigFilePath for Import-Ini,
            MandatorySettings for Test-IniContent, ImportPath for Import-Items,
            EnforceRole for Test-CurrentPrincipal, and DisableQuickEdit for Set-QuickEdit.

            BootstrapLogFile, unboundArgs, and DebugBootstrap do not change the behavior of
            the bootstrapper for the caller. These are for debugging this module only.

        .NOTES
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
            All imported *script* modules suffer from a massive known issue in Powershell
            (All versions as of Core 7.0)!

            In short: the common parameter inheritence mechanism is fundamentally broken
            for advanced functions under certain circumstances. For reference, see:
            https://github.com/PowerShell/PowerShell/issues/4568

            For example: When $ErrorActionPreference is set to 'Stop', compiled cmdlets
            will honor that preference by terminating on most* errors. Advanced functions
            imported from a module however, which are meant to behave identically to
            compiled cmdlets, will not. For 'why', if you want brain damage, see:
            https://seeminglyscience.github.io/powershell/2017/09/30/invocation-operators-states-and-scopes

            *https://github.com/MicrosoftDocs/PowerShell-Docs/issues/1583

            This means preference variables are unreliable! For critical scripts, caution
            MUST be taken to ensure good behavior in regard to preference variables.
            # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipelineByPropertyName)]
        # [System.Collections.Specialized.OrderedDictionary]
        [ref]
        # Specifies sections and keys which must be present in the config file.
        # (See Test-IniContent.)
        $Config,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidatePattern('^([a-zA-Z]\:)?.+\.ini$')]
        [ValidatePathExists()] # Custom validator (see Classes\ValidatePathExistsAttribute.ps1).
        [string]
        # Specifies the path to the configuration file.
        $ConfigFilePath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        # Specifies that the Powershell host console's QuickEdit mode should be disabled.
        # QuickEdit allows pausing execution by clicking/selecting inside the console.
        $DisableQuickEdit,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Security.Principal.WindowsBuiltInRole]
        # Specifies the WindowsBuiltInRole that the current principal must be in.
        # (See System.Security.Principal.WindowsBuiltInRole enum.)
        $EnforceRole,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidatePathExists()] # Custom validator (see Classes\ValidatePathExistsAttribute.ps1).
        [string]
        # Specifies the path to the directory containing modules for importation.
        $ImportPath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidatePathExists()] # Custom validator (see Classes\ValidatePathExistsAttribute.ps1).
        [string]
        # Log bootstrapping output for debugging.
        $BootstrapLogPath = $(
            New-BootstrapLog -ScriptRoot $(
                if (Get-Member -InputObject $MyInvocation -Name 'PSScriptRoot' -MemberType Properties)
                {
                    $PWD.Path
                }
                else
                {
                    $MyInvocation.PSScriptRoot
                }
            )
        ),

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        # Some functions like Get-IniContent write tons of debug out.
        # Only enable this if something is hosed and you NEED that stream.
        $DebugBootstrap,

        [Parameter(ValueFromRemainingArguments, DontShow)]
        # Catch any unbound parameters.
        $UnboundArgs
    )

    begin
    {
        if ($DebugBootstrap)
        {
            $ErrorActionPreference = 'Inquire'
            $WarningPreference     = 'Continue'
            $ProgressPreference    = 'Continue'
            $InformationPreference = 'Continue'
            $VerbosePreference     = 'Continue'
            $DebugPreference       = 'Continue'
        }
        else
        {
            # Import preference variables from script scope into module scope.
            # The fact that these are not inherited is a known issue (as of Core 7.1).
            Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        }

        # Get number of calls to Write-ProgressHelper so percentages work for progress bar.
        # The Ast object is an extremely powerful and versatile tool for meta-automation.
        $ast = $MyInvocation.MyCommand.ScriptBlock.Ast
        $steps = (
            $ast.FindAll(
                {
                    $args[0] -is [System.Management.Automation.Language.CommandAst]
                },
                $true
            ) | Where-Object 'CommandElements' -Match 'Write-ProgressHelper'
        ).Count - 1

        # This function allows calls to Write-Progress to auto-populate their percentages.
        function Write-ProgressHelper
        {
            param
            (
                [int] $StepNumber,
                [string] $Message
            )

            $progSplat = @{
                Activity        = "$($MyInvocation.MyCommand.Name): Executing psBootstrap functions."
                Status          = $Message
                PercentComplete = (($StepNumber / $steps) * 100)
            }
            Write-Progress @progSplat
        }
    }

    process
    {
        # Counter for Write-ProgressHelper.
        $stepCounter = 0

        # Define function-identifying string for BootstrapLogFile entries.
        $fName = "$($MyInvocation.MyCommand.Name):"

        $activity = 'Initializing'
        Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)

        $callerScriptName = if ((Get-Member -InputObject $MyInvocation -Name 'ScriptName' -MemberType Properties) -and ($MyInvocation.ScriptName -ne ''))
        {
            $MyInvocation.ScriptName
        }
        else
        {
            'CLI'
        }
        Write-BootstrapLog 'Info' "$fName Machine: [$($env:COMPUTERNAME)] Bootstrapping script: [$callerScriptName]" $BootstrapLogPath

        # Validate no unknown arguments were passed.
        if ($unboundArgs)
        {
            Write-BootstrapLog 'Error' "Could not bind all parameters! Unknown arguments: $args" $BootstrapLogPath
        }

        #region ============================== Call bootstrapping functions ==============================

        $activity = 'Disabling console QuickEdit mode.'
        Write-ProgressHelper $activity -StepNumber ($stepCounter++)
        if ($DisableQuickEdit)
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                Set-QuickEdit -Disable -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }
        }
        else
        {
            Write-BootstrapLog 'Info' "$fName Skipping $activity" $BootstrapLogPath
        }

        $activity = "Testing current principal is in WindowsBuiltInRole: $EnforceRole."
        Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)
        if ($EnforceRole)
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                Test-CurrentPrincipal -EnforceRole $EnforceRole -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }
        }
        else
        {
            Write-BootstrapLog 'Info' "$fName Skipping $activity" $BootstrapLogPath
        }

        $activity = "Reading from config file: $ConfigFilePath"
        Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)
        if ($ConfigFilePath)
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                $configOut = Import-Ini -Path $ConfigFilePath -ExpandEnvironmentVariables -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }

            $activity = 'Testing config contains all required settings.'
            Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)
            if ($Config)
            {
                Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
                try
                {
                    Test-IniContents -ValidationHash $Config -IniContent $configOut -LogFile $BootstrapLogPath
                    Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
                }
                catch
                {
                    Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
                }
            }
            else
            {
                Write-BootstrapLog 'Info' "$fName Skipping $activity" $BootstrapLogPath
            }
        }
        else
        {
            $stepCounter++
            $configOut = $null
            Write-BootstrapLog 'Info' "$fName Skipping $activity" $BootstrapLogPath
        }

        $activity = "Importing items from directory: $ImportPath"
        Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)
        if ($ImportPath)
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                Import-Items -ImportPath $ImportPath -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }
        }
        else
        {
            Write-BootstrapLog 'Info' "$fName Skipping $activity" $BootstrapLogPath
        }

        $activity = 'Setting preference/behavior variables.'
        Write-ProgressHelper -Message $activity -StepNumber ($stepCounter++)
        if ($configOut)
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                # Set actual preference variables and extra behavior variables now that config has been loaded.
                Set-VerbosityLevel -Level $configOut['Settings']['hostLevel'] -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }
        }
        else
        {
            Write-BootstrapLog 'Verbose' "$fName $activity" $BootstrapLogPath
            try
            {
                # Set some default preference/behavior variables since config is not loaded.
                Set-VerbosityLevel -Level 'Info' -LogFile $BootstrapLogPath
                Write-BootstrapLog 'Info' "$fName Done $activity" $BootstrapLogPath
            }
            catch
            {
                Write-BootstrapLog 'Error' "$fName FAILED $activity" $BootstrapLogPath
            }
        }

        #endregion

        $progSplat = @{
            Activity        = "$fname Executing psBootstrap functions."
            Status          = 'Done.'
            PercentComplete = 100
        }
        Write-Progress @progSplat -Completed

        if ($configOut)
        {
            $Config.Value = $configOut
        }
    }

    end
    {
        Write-BootstrapLog 'Info' "$fName Bootstrapping complete. Bootstrap log file: $BootstrapLogPath" $BootstrapLogPath
    }
}
