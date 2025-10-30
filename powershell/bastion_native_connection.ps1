# Connect to Azure Government and establish a Bastion native RDP connection to a VM
# Requires the Az.Accounts module and Azure CLI installed with access to Azure Government

$subid = ''
$bastionName = ''
$networkRG = ''
$vmRG = ''
$vmName = ''

Connect-AzAccount -Environment AzureUSGovernment -UseDeviceAuthentication -SubscriptionId $subid

az network bastion tunnel --name $bastionName --resource-group $networkRG --target-resource-id '/subscriptions/$subid/resourceGroups/$vmRG/providers/Microsoft.Compute/virtualMachines/$vmName' --resource-port 3389 --port 61234