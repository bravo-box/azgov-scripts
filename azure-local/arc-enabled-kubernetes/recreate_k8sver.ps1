
<#
.SYNOPSIS
    Recreates the HybridContainerService kubernetesVersions/default resource for an Arc-enabled
    custom location. Run this whenever the resource becomes stale or is missing.

.PARAMETER SubscriptionId
    The Azure subscription ID that owns the custom location. If omitted, the currently
    active subscription from 'az account show' is used after login.

.PARAMETER CustomLocationId
    The full ARM resource ID of the custom location, e.g.
    /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.ExtendedLocation/customLocations/<name>

.PARAMETER Cloud
    Target Azure cloud environment. Accepted values: AzureCloud, AzureUSGovernment (default).

.PARAMETER SkipLogin
    Skip az login (use when already authenticated in the current session).

.EXAMPLE
    # Azure public cloud
    .\recreate_k8sver.ps1 `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -CustomLocationId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ExtendedLocation/customLocations/my-cl"

.EXAMPLE
    # Azure Government
    .\recreate_k8sver.ps1 `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -CustomLocationId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ExtendedLocation/customLocations/my-cl" `
        -Cloud AzureUSGovernment
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [string] $CustomLocationId,

    [Parameter()]
    [ValidateSet('AzureCloud', 'AzureUSGovernment')]
    [string] $Cloud = 'AzureUSGovernment',

    [switch] $SkipLogin
)

$ErrorActionPreference = 'Stop'

#region Authentication
# Set the cloud environment first so all subsequent az calls target the right endpoints
Write-Host "Configuring Azure CLI for cloud: $Cloud" -ForegroundColor Cyan
az cloud set --name $Cloud

if (-not $SkipLogin) {
    Write-Host "Logging in to $Cloud..." -ForegroundColor Cyan
    az login --use-device-code
}

if (-not $SubscriptionId) {
    $SubscriptionId = az account show --query id --output tsv
    Write-Host "Using active subscription: $SubscriptionId" -ForegroundColor Cyan
} else {
    Write-Host "Setting active subscription to '$SubscriptionId'..." -ForegroundColor Cyan
    az account set --subscription $SubscriptionId
}
#endregion

#region Variables
# Get the latest stable API version for Microsoft.HybridContainerService/kubernetesVersions
$apiVersion = az provider show `
    --namespace Microsoft.HybridContainerService `
    --query "resourceTypes[?resourceType=='kubernetesVersions'].apiVersions[0]" `
    --output tsv
if (-not $apiVersion) {
    Write-Error "Could not determine API version for Microsoft.HybridContainerService/kubernetesVersions. Ensure the provider is registered in this subscription."
}
Write-Host "Using API version: $apiVersion" -ForegroundColor Cyan

# Resolve the ARM endpoint for the target cloud
$armEndpoint = (az cloud show --query 'endpoints.resourceManager' --output tsv).TrimEnd('/')
$url = "${armEndpoint}${CustomLocationId}/providers/Microsoft.HybridContainerService/kubernetesVersions/default?api-version=${apiVersion}"
#endregion

#region List current versions
Write-Host "`nCurrent Kubernetes versions available at the custom location:" -ForegroundColor Cyan
az aksarc get-versions --custom-location $CustomLocationId --output table
#endregion

#region Get a fresh access token
$token = az account get-access-token --query accessToken --output tsv
$headers = @("Authorization=Bearer $token", "Content-Type=application/json;charset=utf-8")
#endregion

#region Check whether the kubernetesVersions/default resource exists
Write-Host "`nChecking for existing kubernetesVersions/default resource..." -ForegroundColor Cyan
$getResult = az rest --headers @headers --uri $url --method GET 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource found. Deleting it so it can be recreated..." -ForegroundColor Yellow
    az rest --headers @headers --uri $url --method DELETE
    if ($LASTEXITCODE -ne 0) {
        Write-Error "DELETE request failed. Aborting."
    }
    Write-Host "Resource deleted successfully." -ForegroundColor Green
} else {
    Write-Host "Resource does not exist (or could not be retrieved) -- skipping DELETE." -ForegroundColor Yellow
}
#endregion

#region Recreate the resource via CLI
Write-Host "`nRecreating kubernetesVersions/default via 'az aksarc get-versions'..." -ForegroundColor Cyan
az aksarc get-versions --custom-location $CustomLocationId --output table
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to recreate the kubernetesVersions resource."
}
Write-Host "`nDone. The kubernetesVersions/default resource has been recreated." -ForegroundColor Green
#endregion



