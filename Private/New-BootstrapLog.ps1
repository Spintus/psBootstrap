function New-BootstrapLog
{
    # This function makes a file for basic bootstrap logging.
    param
    (
        [string] $ScriptRoot
    )

    $logFile = '{0}\Logs\{1}\psBootstrap_{2}.log' -f $ScriptRoot,
    (Get-Date -Format 'yyyyMMdd'), (Get-Date -Format 'HHmmss')

    if (-not (Test-Path $logFile))
    {
        [void] (New-Item -Path $logFile -ItemType File -Force)
    }

    $logFile
}
