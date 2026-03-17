# Entra to Active Directory Sync Scripts

## Overview

This folder contains two PowerShell scripts used together:

- `entra_sync_encrypt.ps1`: one-time credential protection setup
- `entra_sync.ps1`: recurring Entra ID group-to-AD user sync

Workflow:

1. Configure and run `entra_sync_encrypt.ps1` on the sync host.
2. Configure and run `entra_sync.ps1` on the same host.
3. Schedule `entra_sync.ps1` (Task Scheduler, runbook host, etc.) as needed.

## Files

- `entra/entra_sync_encrypt.ps1`
- `entra/entra_sync.ps1`
- `entra/readme.md`

## What Each Script Does

## 1) entra_sync_encrypt.ps1

Purpose:

- stores tenant ID, client ID, and client secret in encrypted files on disk
- uses DPAPI with `LocalMachine` scope so data can only be decrypted on that machine
- hardens folder ACLs for the credential directory

Outputs:

- secure folder (default: `C:\Secure\AzureApp`)
- encrypted files:
	- `tenantId.bin`
	- `clientId.bin`
	- `clientSecret.bin`

## 2) entra_sync.ps1

Purpose:

- decrypts stored app registration credentials
- connects to Microsoft Graph (`USGov` environment is hardcoded)
- finds one Entra group by display name
- enumerates users in that group
- creates missing AD users in the configured OU
- writes text logs, JSON logs, and Event Log entries

Important behavior:

- It creates AD users only when `SamAccountName` does not already exist.
- It does not update existing AD users.
- It does not disable or remove users no longer in Entra group.

## Prerequisites

## Host requirements

- Windows host joined to domain (for AD operations)
- PowerShell 7+ recommended (Windows PowerShell also commonly works for AD module scenarios)
- Run both scripts on the same machine (required by DPAPI `LocalMachine` decryption)

## PowerShell modules

- `Microsoft.Graph` (for Graph auth and user/group retrieval)
- `ActiveDirectory` (for `Get-ADUser`, `New-ADUser`)

## Permissions

App registration (Microsoft Graph):

- must be able to read groups and users used by this script
- in practice, grant least-privileged application permissions needed for:
	- group lookup
	- group member enumeration
	- user reads

AD permissions:

- rights to create users in the target OU

Host rights:

- permission to create event log source (first run)
- permission to write to:
	- `C:\Secure\AzureApp`
	- `C:\Logs\EntraToADSync`

## Configuration

## Configure entra_sync_encrypt.ps1

Edit these values:

- `$tenantID = "YOUR-TENANT-ID"`
- `$clientID = "YOUR-CLIENT-ID"`
- `$clientSecret = "YOUR-CLIENT-SECRET"`

Optional path values:

- `$SecurePath` (default `C:\Secure\AzureApp`)

## Configure entra_sync.ps1

Edit these values:

- `$GroupName = "AD_Security_Group_Name"`
- `$OU = "OU=,DC=,DC="`
- `$Pass = ""` (default password for newly created AD users)

Optional logging/config paths:

- `$LogDirectory = "C:\Logs\EntraToADSync"`
- `$EventLogName = "EntraToADSync"`
- `$EventSource = "EntraToADSyncScript"`
- `$secureFolder = "C:\Secure\AzureApp"`

Cloud setting in script:

- `Connect-MgGraph -Environment USGov ...`
- if you are not in Azure Government, change this environment value.

## Run Instructions

## Step 1: Encrypt and store credentials

```powershell
pwsh .\entra\entra_sync_encrypt.ps1
```

Run once (or rerun when app credentials rotate).

## Step 2: Execute sync

```powershell
pwsh .\entra\entra_sync.ps1
```

## Step 3: Validate results

Check:

- AD users created in target OU
- text log in `C:\Logs\EntraToADSync\SyncLog_YYYY-MM-DD.log`
- JSON log in `C:\Logs\EntraToADSync\SyncLog_YYYY-MM-DD.json`
- Event Viewer log `EntraToADSync`

## Logging and Observability

`entra_sync.ps1` writes:

- console output
- text logs (`INFO`, `WARN`, `ERROR`)
- JSON logs with fields:
	- `timestamp`
	- `level`
	- `message`
	- `user`
	- `operation`
	- `exception`
- Windows Event Log entries:
	- Information (`EventId 1000`)
	- Warning (`EventId 2000`)
	- Error (`EventId 3000`)

## Account Mapping Rules

For each Entra user:

- UPN required; users without UPN are skipped
- `SamAccountName` rule:
	- use mail prefix if `Mail` exists
	- otherwise use UPN prefix
- if AD user with same `SamAccountName` exists, user is skipped
- otherwise, script creates the AD user with configured defaults

## Security Notes

- Do not store plaintext credentials in source control.
- Rotate app secrets regularly and rerun `entra_sync_encrypt.ps1` after rotation.
- Restrict ACLs on `C:\Secure\AzureApp` and `C:\Logs\EntraToADSync`.
- Default password (`$Pass`) should follow your AD password policy and be changed from placeholder values.
- Consider using certificates or managed identity alternatives where available.

## Scheduling Guidance

If running from Task Scheduler:

- run under a service account with:
	- AD user creation rights in target OU
	- access to encrypted credential files
	- rights to write logs and event logs
- run with highest privileges if event source creation is required
- set working directory to repo root or use absolute script paths

Recommended schedule examples:

- every 15 minutes for near-real-time onboarding
- hourly for standard enterprise cadence

## Troubleshooting

## Graph connection fails

Symptoms:

- "Failed to connect to MS Graph"

Checks:

- verify tenant/client/secret values were encrypted correctly
- ensure encrypted files exist in `C:\Secure\AzureApp`
- confirm app registration permissions and admin consent
- verify `USGov` environment setting matches your tenant cloud

## Group not found

Symptoms:

- "Group '...' not found"

Checks:

- exact `DisplayName` in `$GroupName`
- app permissions allow group reads

## AD user creation fails

Symptoms:

- "FAILED to create AD user"

Checks:

- target OU DN is valid
- account has create-user rights in OU
- default password satisfies AD policy
- generated `SamAccountName` uniqueness and format constraints

## Decryption fails

Symptoms:

- errors around `Unprotect` or unreadable credentials

Checks:

- confirm scripts run on same machine used for encryption
- confirm files were not moved from a different host
- confirm ACLs allow read access for run identity

## Event source/log issues

Symptoms:

- warnings about event source existing under another log

Checks:

- keep `$EventSource` and `$EventLogName` stable
- ensure run identity can write event logs

## Known Limitations

- Only creates missing AD users; no update, disable, or delete logic.
- Group lookup is by display name; duplicate display names can be ambiguous.
- Uses client secret flow and local DPAPI file storage instead of managed identity.

## Suggested Improvements

1. Parameterize all hardcoded values (`GroupName`, `OU`, paths, environment).
2. Add dry-run mode.
3. Add update logic for existing AD users.
4. Add disable/removal handling for users no longer in source group.
5. Replace static secret approach with cert-based auth or managed identity where possible.
