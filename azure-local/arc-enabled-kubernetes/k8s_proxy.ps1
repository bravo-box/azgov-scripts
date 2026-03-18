#Requires -Version 7.0
<#!
.SYNOPSIS
Starts a proxy session to an Azure Arc-enabled Kubernetes cluster.

.DESCRIPTION
PowerShell equivalent of k8s_proxy.sh.

Features:
- Checks prerequisites (az, kubectl)
- Ensures connectedk8s Azure CLI extension is installed
- Prompts for cloud selection/login when not authenticated
- Supports interactive cluster selection when -ClusterName is omitted
- Derives resource group and subscription from selected cluster
- Starts `az connectedk8s proxy` in the foreground
- Writes a timestamped log file in the script directory

.PARAMETER ClusterName
Optional Arc-enabled cluster name. If omitted, you can select from a list.

.EXAMPLE
./k8s_proxy.ps1

.EXAMPLE
./k8s_proxy.ps1 -ClusterName myCluster
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClusterName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir ("k8s_proxy_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$script:Subscription = ''
$script:ResourceGroup = ''

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$Level] $Message"

    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }

    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value "[$timestamp] $line"
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Ensure-ConnectedK8sExtension {
    Write-Log "Checking Azure CLI extension 'connectedk8s'..." 'INFO'

    $null = & az extension show --name connectedk8s --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Installing Azure CLI extension 'connectedk8s'..." 'INFO'
        & az extension add --name connectedk8s --upgrade --yes
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Azure CLI extension 'connectedk8s'."
        }
    }

    Write-Log "connectedk8s extension available." 'SUCCESS'
}

function Ensure-AzureLogin {
    Write-Log "Checking Azure authentication..." 'INFO'

    $accountJson = & az account show -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and $accountJson) {
        $account = $accountJson | ConvertFrom-Json
        Write-Log "Authenticated. Current subscription: $($account.name)" 'SUCCESS'
        return
    }

    Write-Log "No active Azure login detected." 'WARN'
    Write-Host "Select cloud environment:"
    Write-Host "  1) AzureCloud"
    Write-Host "  2) AzureUSGovernment"

    while ($true) {
        $choice = Read-Host "Select cloud environment (1-2)"
        switch ($choice) {
            '1' {
                & az cloud set --name AzureCloud | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Failed to set cloud AzureCloud.' }
                Write-Log "Set cloud to AzureCloud." 'SUCCESS'
                break
            }
            '2' {
                & az cloud set --name AzureUSGovernment | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Failed to set cloud AzureUSGovernment.' }
                Write-Log "Set cloud to AzureUSGovernment." 'SUCCESS'
                break
            }
            default {
                Write-Log "Invalid selection. Enter 1 or 2." 'WARN'
            }
        }
    }

    Write-Log "Starting Azure device-code login..." 'INFO'
    & az login --use-device-code | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Azure login failed.'
    }

    $postLoginAccount = (& az account show -o json | ConvertFrom-Json)
    Write-Log "Authenticated. Current subscription: $($postLoginAccount.name)" 'SUCCESS'
}

function Get-ArcClusters {
    Write-Log "Fetching Arc-enabled clusters..." 'INFO'

    $clustersJson = & az connectedk8s list --query "[].{name:name, resourceGroup:resourceGroup, id:id}" -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $clustersJson) {
        return @()
    }

    $clusters = $clustersJson | ConvertFrom-Json
    if ($null -eq $clusters) {
        return @()
    }

    return @($clusters)
}

function Select-Cluster {
    param([Parameter(Mandatory = $true)][array]$Clusters)

    if ($Clusters.Count -eq 1) {
        Write-Log "Auto-selected cluster: $($Clusters[0].name)" 'SUCCESS'
        return $Clusters[0]
    }

    Write-Host ""
    Write-Host "Available Arc-enabled clusters:" -ForegroundColor Cyan
    Write-Host ("{0,-4} {1,-35} {2}" -f '#', 'Name', 'Resource Group') -ForegroundColor Cyan
    Write-Host ("-" * 80) -ForegroundColor DarkGray

    for ($i = 0; $i -lt $Clusters.Count; $i++) {
        $c = $Clusters[$i]
        Write-Host ("{0,-4} {1,-35} {2}" -f ($i + 1), $c.name, $c.resourceGroup)
    }

    while ($true) {
        $selection = Read-Host "Select cluster (1-$($Clusters.Count))"
        $selectedIndex = 0
        if ([int]::TryParse($selection, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $Clusters.Count) {
            $cluster = $Clusters[$selectedIndex - 1]
            Write-Log "Selected cluster: $($cluster.name)" 'SUCCESS'
            return $cluster
        }

        Write-Log "Invalid selection. Enter a number between 1 and $($Clusters.Count)." 'WARN'
    }
}

function Initialize-ClusterContext {
    param([Parameter(Mandatory = $true)][pscustomobject]$Cluster)

    $script:ResourceGroup = [string]$Cluster.resourceGroup
    $clusterId = [string]$Cluster.id
    $idParts = $clusterId -split '/'

    if ($idParts.Count -lt 3 -or -not $idParts[2]) {
        throw "Unable to parse subscription from cluster ID: $clusterId"
    }

    $script:Subscription = $idParts[2]

    Write-Log "Cluster: $($Cluster.name)" 'SUCCESS'
    Write-Log "Resource Group: $script:ResourceGroup" 'SUCCESS'
    Write-Log "Subscription: $script:Subscription" 'SUCCESS'

    & az account set --subscription $script:Subscription 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Could not set active subscription to $script:Subscription. Continuing with current context." 'WARN'
    }
}

function Start-ArcProxy {
    param([Parameter(Mandatory = $true)][string]$Name)

    Write-Log "Starting proxy for cluster '$Name'..." 'INFO'
    Write-Log "Press Ctrl+C to stop the proxy." 'INFO'
    Write-Log "Log file: $LogFile" 'INFO'

    & az connectedk8s proxy --name $Name --resource-group $script:ResourceGroup
    if ($LASTEXITCODE -ne 0) {
        throw "Proxy command failed for cluster '$Name'."
    }
}

try {
    Write-Log "Azure Arc Kubernetes Proxy Script (PowerShell)" 'INFO'
    Write-Log "=============================================" 'INFO'

    Assert-Command -Name 'az'
    Write-Log "Azure CLI found." 'SUCCESS'

    Assert-Command -Name 'kubectl'
    Write-Log "kubectl found." 'SUCCESS'

    Ensure-ConnectedK8sExtension
    Ensure-AzureLogin

    $clusters = Get-ArcClusters
    if ($clusters.Count -eq 0) {
        throw 'No Arc-enabled clusters found in accessible subscriptions.'
    }

    $selectedCluster = $null
    if ($ClusterName) {
        $selectedCluster = @($clusters | Where-Object { $_.name -eq $ClusterName }) | Select-Object -First 1
        if (-not $selectedCluster) {
            throw "Cluster '$ClusterName' not found. Run without -ClusterName to select interactively."
        }
        Write-Log "Using provided cluster name: $ClusterName" 'SUCCESS'
    }
    else {
        $selectedCluster = Select-Cluster -Clusters $clusters
    }

    Initialize-ClusterContext -Cluster $selectedCluster
    Start-ArcProxy -Name ([string]$selectedCluster.name)
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    exit 1
}
finally {
    Write-Log 'Proxy session ended.' 'INFO'
}
