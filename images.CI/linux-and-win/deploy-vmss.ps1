[CmdletBinding()]
param (
    [Parameter(Mandatory)][string] $VmssName,
    [Parameter(Mandatory)][string] $ResourceGroupName,
    [Parameter(Mandatory)][string] $Image,
    [Parameter(Mandatory)][string] $SubnetId,
    [string] $VmSku = "Standard_D2s_v3",
    [string] $ImageType = "ubuntu",
    [string] $AdminUserName = "azureuser",
    [securestring] $AdminPassword,
    [string] $KeyVault,
    [string] $AdminSecretName,
    [int] $DiskSizeGb = 0,
    [string] $StorageType = "StandardSSD_LRS",
    [string] $SshPublicKey,
    [string] $AzureSshKey,
    [string] $AzureSshKeyResourceGroup = $ResourceGroupName
)

$ErrorActionPreference = "Stop"

function CheckCommandResult {
    if ($LASTEXITCODE -ne 0) {
        throw "External command returned an error!"
    }    
}


$conditionalParameters = @()
$customScriptParameters = @()

if ($ImageType.StartsWith("windows")) {
    if ($DiskSizeGb -eq 0) { $DiskSizeGb = 256 }

    if ($AdminPassword) {
        $pwValue = ConvertFrom-SecureString -SecureString $AdminPassword -AsPlainText
    } elseif ($KeyVault -and $AdminSecretName) {
        $pwValue = $(az keyvault secret show --name $AdminSecretName --vault-name $KeyVault --query value -o tsv)
    } else {
        Write-Error "Required missing parameters for Windows VM. AdminPassword parameter is empty. Alternatives KeyVault with AdminSecretName parameters are also empty"
        exit 1
    }
    
    $conditionalParameters += "--admin-password=`"$pwValue`""
    $conditionalParameters += "--authentication-type=password"

    $commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command \\\`"Get-ChildItem C:\post-generation -Filter *.ps1 | ForEach-Object { & `$_.FullName } \\\`""
    $customScriptParameters += "--name=CustomScriptExtension"
    $customScriptParameters += "--publisher=Microsoft.Compute"
    $customScriptParameters += "--version=1.9"
    $customScriptParameters += "--settings=`"{\`"commandToExecute\`":\`"$commandToExecute\`" }`""

} else {
    if ($DiskSizeGb -eq 0) { $DiskSizeGb = 128 }

    if (!$SshPublicKey -and $AzureSshKey) {
        Write-Host "Retrieving ssh key from Azure ssh key ..."

        $SshPublicKey = $(az sshkey show --name $AzureSshKey --resource-group $AzureSshKeyResourceGroup --query publicKey -o tsv)
        CheckCommandResult
    }

    $conditionalParameters += "--authentication-type=ssh"
    $conditionalParameters += "--ssh-key-values=`"$SshPublicKey`""

    $commandToExecute = "sudo su -c \\\`"find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name '*.sh' -exec bash {} \\;\\\`""
    $customScriptParameters += "--name=CustomScript"
    $customScriptParameters += "--publisher=Microsoft.Azure.Extensions"
    $customScriptParameters += "--version=2.0"
    $customScriptParameters += "--settings=`"{\`"commandToExecute\`":\`"$commandToExecute\`" }`""
}

Write-Host "Conditional parameters:"
Write-Host $conditionalParameters

Write-Host ""
Write-Host "Custom script parameters:"
Write-Host $customScriptParameters
Write-Host ""

Write-Host "Deploy Azure VMSS $VmssName ..."
Write-Host "VM sku: $VmSku"
Write-Host "OS type: $ImageType"
Write-Host "Image: $Image"
Write-Host "Disk size: $DiskSizeGb"
Write-Host "Disk type: $StorageType"

az vmss create --name $VmssName `
    --resource-group $ResourceGroupName `
    --image $Image `
    --vm-sku $VmSku `
    --instance-count 0 `
    --storage-sku $StorageType `
    --os-disk-size-gb $diskSizeGb `
    --encryption-at-host `
    --admin-username $AdminUserName `
    --assign-identity "[system]" `
    --disable-overprovision `
    --enable-auto-update false `
    --subnet $SubnetId `
    --upgrade-policy-mode manual `
    --single-placement-group false `
    --platform-fault-domain-count 1 `
    --load-balancer '""' `
    --orchestration-mode Uniform `
    --only-show-errors `
    $conditionalParameters

Write-Host ""
CheckCommandResult

Write-Host "Add custom script extension ..."
az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName $customScriptParameters
CheckCommandResult
