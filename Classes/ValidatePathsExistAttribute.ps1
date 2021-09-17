# This validation is already possible with [ValidateScript({Test-Path $_})].
# Above method works, but the validation failure message is hot garbage.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Management.Automation;

public class ValidatePathExistsAttribute : System.Management.Automation.ValidateArgumentsAttribute
{
    protected override void Validate(object path, EngineIntrinsics engineEntrinsics)
    {
        if (string.IsNullOrWhiteSpace(path.ToString()))
        {
            throw new ArgumentNullException();
        }
        if(!(System.IO.File.Exists(path.ToString()) || System.IO.Directory.Exists(path.ToString())))
        {
            throw new System.IO.FileNotFoundException();
        }
    }
}
'@ -Language CSharp -ErrorAction 'SilentlyContinue' -WarningAction 'SilentlyContinue' # Suppress no public methods/properties warning.
