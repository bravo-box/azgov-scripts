# Create Azure Local Logical Networks

This folder contains:

- `create-azl-lnet.ps1`: deploys or updates Azure Local logical networks.
- `create-azl-lnet.config.json`: input configuration file.

## Prerequisites

1. PowerShell 7+
2. Az Powershell modules installed and signed in (`connect-azaccount`)
3. Azure CLI extension `Az.StackHCIVM` installed
4. Permissions to read resource groups and create/update Azure Local logical networks

Optional but recommended:

- Set your Az PowerShell context before running:

```powershell
Set-AzContext -Subscription "<subscription-id-or-name>"
```

If you do not provide `subscriptionId` in config or as a parameter, the script uses the current Az PowerShell context.

## Configure Input File

Edit `create-azl-lnet.config.json` with your logical network definitions.

Example:

```json
{
  "location": "usgovvirginia",
  "logicalNetworks": [
    {
      "name": "mylocal-lnet-static-01",
      "ipAllocationMethod": "Static",
      "addressPrefixes": "192.168.180.0/24",
      "gateway": "192.168.180.1",
      "dnsServers": "192.168.180.222",
      "vlan": 201
    }
  ]
}
```

Notes:

- `resourceGroup` and `customLocationId` are optional in config and can be selected/provided interactively.
- `vmSwitchName` can be omitted; the script will try to discover it or prompt you.
- Add as many logical network objects as needed under `logicalNetworks`.

## How To Run

From this folder:

```powershell
pwsh ./create-azl-lnet.ps1
```

With explicit config path:

```powershell
pwsh ./create-azl-lnet.ps1 -ConfigPath ./create-azl-lnet.config.json
```

With explicit subscription override:

```powershell
pwsh ./create-azl-lnet.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
```

Preview only (no changes):

```powershell
pwsh ./create-azl-lnet.ps1 -WhatIf
```

Allow updates when logical network already exists:

```powershell
pwsh ./create-azl-lnet.ps1 -UpdateIfExists
```

## Runtime Prompts

During execution, the script may prompt you to:

1. Enter a resource group (if missing/invalid in config)
2. Enter a location (if missing in config)
3. Select a custom location by number
4. Select or enter `vmSwitchName` if it cannot be auto-resolved

Common Azure Local switch name example:

`ConvergedSwitch(compute_management)`
