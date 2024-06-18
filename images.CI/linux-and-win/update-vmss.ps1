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

CheckCommandResult

Write-Host "Add custom script extension ..."

if ($ImageType.StartsWith("windows")) {
    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command 'Get-ChildItem C:\\post-generation -Filter *.ps1 | ForEach-Object { & `$_.FullName } '"

    # workaround to handle different escaping when running in Linux or Windows
    if ($IsWindows) {
        az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName `
            --name "CustomScriptExtension" --publisher "Microsoft.Compute" --version "1.9" `
            --settings '{\"commandToExecute\":\"\"}' `
            --protected-settings $('{\"commandToExecute\":\"' + $commandToExecute + '\" }')
    } else {
        az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName `
            --name "CustomScriptExtension" --publisher "Microsoft.Compute" --version "1.9" `
            --settings '{"commandToExecute":""}' `
            --protected-settings $('{"commandToExecute":"' + $commandToExecute + '" }')
    }
} else {
    if ($IsWindows) {
        az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName `
            --name "CustomScript" --publisher "Microsoft.Azure.Extensions" --version "2.0" `
            --settings '{ \"fileUris\":[\"https://raw.githubusercontent.com/rwerlang/runner-images/main/images/ubuntu/scripts/helpers/vm-startup.sh\"], \"commandToExecute\":\"sudo su -c ./vm-startup.sh \"}'
    } else {
        az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName `
            --name "CustomScript" --publisher "Microsoft.Azure.Extensions" --version "2.0" `
            --settings '{ "fileUris":["https://raw.githubusercontent.com/rwerlang/runner-images/main/images/ubuntu/scripts/helpers/vm-startup.sh\"], "commandToExecute":"sudo su -c ./vm-startup.sh" }'
    }
}

CheckCommandResult
