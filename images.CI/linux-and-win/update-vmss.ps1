[CmdletBinding()]
param (
    [Parameter(Mandatory)][string] $VmssName,
    [Parameter(Mandatory)][string] $ResourceGroupName,
    [Parameter(Mandatory)][string] $Image,
    [string] $ImageType = "ubuntu"
)


$ErrorActionPreference = "Stop"

function CheckCommandResult {
    if ($LASTEXITCODE -ne 0) {
        Write-Error "External command returned an error!"
        exit 1
    }
}



Write-Host "Update VMSS '$VmssName' ..."

az vmss update --name $VmssName `
    --resource-group $ResourceGroupName `
    --set virtualMachineProfile.storageProfile.imageReference.id=$Image

# CheckCommandResult

$customScriptParameters = @()

if ($ImageType.StartsWith("windows")) {
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command 'Get-ChildItem C:\\post-generation -Filter *.ps1 | ForEach-Object { & `$_.FullName } '"
    $customScriptParameters += "--name=CustomScriptExtension"
    $customScriptParameters += "--publisher=Microsoft.Compute"
    $customScriptParameters += "--version=1.9"
    $customScriptParameters += "--settings=`"{\`"commandToExecute\`":\`"\`" }`""
    $customScriptParameters += "--protected-settings=`"{\`"commandToExecute\`":\`"$commandToExecute\`" }`""

} else {
    $commandToExecute = "sudo su -c 'find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name *.sh -exec bash {} \\;'"
    $customScriptParameters += "--name=CustomScript"
    $customScriptParameters += "--publisher=Microsoft.Azure.Extensions"
    $customScriptParameters += "--version=2.0"
    $customScriptParameters += "--settings=`"{\`"commandToExecute\`":\`"\`" }`""
    $customScriptParameters += "--protected-settings=`"{\`"commandToExecute\`":\`"$commandToExecute\`" }`""
}

Write-Host "Add custom script extension ..."
az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName $customScriptParameters
CheckCommandResult
