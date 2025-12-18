# This PowerShell script is designed to set up prerequisites for deploying Azure Local clusters.
# It connects to the appropriate Azure environment, retrieves necessary context information,
# checks and registers required resource providers, and invokes the Azure Stack HCI Arc initialization.


# Enter the number for your Azure environment, Commercial(1), USGov(2)
$envChoice = Read-Host -Prompt "Select your Azure Environment: Commercial(1), USGov(2)"
switch ($envChoice) {
    "1" {
        Connect-AzAccount -Environment AzureCloud -DeviceCode
        $Region = "eastus"
    }
    "2" {
        Connect-AzAccount -Environment AzureUSGovernment -DeviceCode
        $Region = "usgovvirginia"
    }
    Default {
        Write-Host "Invalid selection. Please run the script again and select a valid option."
        exit
    }
}

# Removed redundant Connect-AzAccount and $Region assignment since it's handled in the switch statement
# Get Tenant ID and Context
$tenantId = (Get-AzContext).Tenant.Id
Write-Host "Current Tenant ID: $tenantId"

# Get Subscription ID and Context
$subscriptionId = (Get-AzContext).Subscription.Id
Write-Host "Current Subscription ID: $subscriptionId"

#Get the Account ID for the registration
$id = (Get-AzContext).Account.Id

# List the Resource Groups in the current subscription
Write-Host "======================================"
Write-Host "Resource Groups in Current Subscription"
Write-Host "======================================"
Write-Host "Listing Resource Groups in Subscription ID: $subscriptionId"
Get-AzResourceGroup | Select-Object ResourceGroupName, Location | Format-Table -AutoSize

# Prompt for Resource Group Name
$RG = Read-Host -Prompt "Enter the Resource Group Name for your Azure Local cluster nodes"

# Check if Resource Providers are registered
$providers = @("Microsoft.HybridCompute", "Microsoft.GuestConfiguration", "Microsoft.HybridConnectivity", "Microsoft.AzureStackHCI", "Microsoft.Kubernetes", "Microsoft.KubernetesConfiguration", "Microsoft.ExtendedLocation", "Microsoft.ResourceConnector", "Microsoft.HybridContainerService", "Microsoft.Attestation")
foreach ($provider in $providers) {
    $registrationState = (Get-AzResourceProvider -ProviderNamespace $provider).RegistrationState
    if ($registrationState -ne "Registered") {
        Write-Host "Registering Resource Provider: $provider"
        Register-AzResourceProvider -ProviderNamespace $provider
    } else {
        Write-Host "Resource Provider already registered: $provider"
    }
}

#Define the proxy address if your Azure Local deployment accesses the internet via proxy
#$ProxyServer = "http://proxyaddress:port"

#Get the Access Token for the registration
$ARMtoken = (Get-AzAccessToken -WarningAction SilentlyContinue).Token

#Invoke the registration script. Use a supported region.
Invoke-AzStackHciArcInitialization -SubscriptionID $subscriptionId -ResourceGroup $RG -TenantID $tenantId -Region $Region -Cloud "AzureUSGovernment" -ArmAccessToken $ARMtoken -AccountID $id