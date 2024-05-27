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
    [string] $AzureSshKey,
    [string] $AzureSshKeyResourceGroup = $ResourceGroupName
)

$ErrorActionPreference = "Stop"

function CheckCommandResult {
    if ($LASTEXITCODE -ne 0) {
        Write-Error "External command returned an error!"
        exit 1
    }
}




Write-Host "Verify if VMSS '$VmssName' already exists ..."
$vmss = (az vmss list --resource-group $ResourceGroupName --query "[?name=='$VmssName'].{name:name}") | ConvertFrom-Json
CheckCommandResult



$conditionalParameters = @()
$customScriptParameters = @()
$tempPath = $env:AGENT_TEMPDIRECTORY

if (!$tempPath) { $tempPath = $env:TEMP }
if (!$tempPath) { $tempPath = "./" }

if ($IsWindows) {
    $conditionalParameters += "--load-balancer='`"`"'"
} else {
    $conditionalParameters += "--load-balancer=`"`""
}

if ($ImageType.StartsWith("windows")) {
    if ($DiskSizeGb -eq 0) { $DiskSizeGb = 256 }

    if ($AdminPassword) {
        $pwValue = ConvertFrom-SecureString -SecureString $AdminPassword -AsPlainText
    } elseif ($KeyVault -and $AdminSecretName) {
        $pwValue = $(az keyvault secret show --name $AdminSecretName --vault-name $KeyVault --query value -o tsv)
    } else {
        Write-Error "Missing required parameters for Windows VM. AdminPassword parameter is empty. Alternatives KeyVault with AdminSecretName parameters are also empty"
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

    if ($AzureSshKey) {
        Write-Host "Retrieving ssh key from Azure ssh key ..."

        $sshPublicKey = $(az sshkey show --name $AzureSshKey --resource-group $AzureSshKeyResourceGroup --query publicKey -o tsv)
        CheckCommandResult

        $sshFile = Join-Path -Path $tempPath -ChildPath "ssh.pub"
        $sshFile
        Set-Content -Path $sshFile -Value $sshPublicKey -Force

        $conditionalParameters += "--ssh-key-values=$sshFile"
    }

    $conditionalParameters += "--authentication-type=ssh"

    $commandToExecute = "sudo su -c \\\`"find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name '*.sh' -exec bash {} \\;\\\`""
    $customScriptParameters += "--name=CustomScript"
    $customScriptParameters += "--publisher=Microsoft.Azure.Extensions"
    $customScriptParameters += "--version=2.0"
    $customScriptParameters += "--settings=`"{\`"commandToExecute\`":\`"$commandToExecute\`" }`""
}

Write-Host "Deploy Azure VMSS $VmssName ..."
Write-Host "Resource group: $ResourceGroupName"
Write-Host "VM sku: $VmSku"
Write-Host "OS type: $ImageType"
Write-Host "Image: $Image"
Write-Host "Disk size: $DiskSizeGb"
Write-Host "Disk type: $StorageType"
Write-Host ""

if ($vmss.Length -eq 0) {
    Write-Host "Resource doesn't exit. Creating ..."

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
        --orchestration-mode Uniform `
        --only-show-errors `
        $conditionalParameters

    Write-Host ""

} else {
    Write-Host "Resource already exists. Updating ..."

    az vmss update --name $VmssName `
        --resource-group $ResourceGroupName `
        --set virtualMachineProfile.storageProfile.imageReference.id=$Image
}

CheckCommandResult

# Write-Host "Add custom script extension ..."
# az vmss extension set --vmss-name $VmssName --resource-group $ResourceGroupName $customScriptParameters
# CheckCommandResult
