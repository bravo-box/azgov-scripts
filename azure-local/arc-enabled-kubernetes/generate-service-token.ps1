#!/usr/bin/env pwsh
<#
    .SYNOPSIS
    Generate a Kubernetes service token for the signed-in Azure user in the connected cluster.

    .DESCRIPTION
    This script retrieves the Azure AD object ID of the currently signed-in user,
    creates a Kubernetes token for that user in the default namespace, and attempts
    to copy the token to the system clipboard.

    .EXAMPLE
    ./generate-service-token.ps1

    .NOTES
    Requires:
    - Azure CLI (az command)
    - kubectl
    - PowerShell 7.0+ (recommended)
    - Valid Azure AD and Kubernetes context

    On macOS, token copy uses pbcopy.
    On Windows, token copy uses Set-Clipboard cmdlet.
    On Linux, pbcopy or xclip must be available for clipboard support.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Color definitions for output
$colors = @{
    Yellow = 'Yellow'
    Green  = 'Green'
    Red    = 'Red'
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor $colors.Yellow
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor $colors.Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $colors.Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Copy-ToClipboard {
    param([string]$Text)
    
    $onWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows
    $onMacOS = $IsMacOS
    $onLinux = $IsLinux
    
    try {
        if ($onWindows) {
            Set-Clipboard -Value $Text
            return $true
        }
        elseif ($onMacOS) {
            $Text | pbcopy
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        elseif ($onLinux) {
            # Try xclip first, then xsel
            if (Get-Command pbcopy -ErrorAction SilentlyContinue) {
                $Text | pbcopy
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            }
            elseif (Get-Command xclip -ErrorAction SilentlyContinue) {
                $Text | xclip -selection clipboard
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

# Main script
Write-Host "=== Generating Service Token from Connected K8s Cluster ===" -ForegroundColor Cyan
Write-Host ""

# Retrieve AAD entity object ID
Write-LogInfo "Retrieving AAD entity object ID..."

try {
    $AAD_ENTITY_OBJECT = az ad signed-in-user show --query id -o tsv
    
    if ([string]::IsNullOrWhiteSpace($AAD_ENTITY_OBJECT)) {
        Write-LogError "Failed to retrieve AAD entity object ID"
        exit 1
    }
    
    Write-LogSuccess "AAD Entity Object ID: $AAD_ENTITY_OBJECT"
    Write-Host ""
}
catch {
    Write-LogError "Failed to execute Azure CLI command: $_"
    exit 1
}

# Create the service token
Write-LogInfo "Creating service token..."

try {
    $TOKEN = kubectl create token $AAD_ENTITY_OBJECT -n default 2>&1
    
    if ([string]::IsNullOrWhiteSpace($TOKEN)) {
        Write-LogError "Failed to create service token"
        exit 1
    }
    
    Write-LogSuccess "Service token created successfully"
}
catch {
    Write-LogError "Failed to create service token: $_"
    exit 1
}

# Copy token to clipboard
Write-LogInfo "Copying token to clipboard..."
$clipboardSuccess = Copy-ToClipboard -Text $TOKEN

if ($clipboardSuccess) {
    Write-LogSuccess "Token copied to clipboard! You can now paste it in your browser."
}
else {
    Write-LogWarning "Failed to copy to clipboard. Token displayed below."
}

# Display token details
Write-Host ""
Write-Host "=== Token Details ===" -ForegroundColor Cyan
Write-Host "User ID:    $AAD_ENTITY_OBJECT"
Write-Host "Namespace:  default"
Write-Host "Token:      $TOKEN"
Write-Host ""
