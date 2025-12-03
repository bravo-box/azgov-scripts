#Connect to Microsoft Graph
$clientID = [System.Environment]::GetEnvironmentVariable("ClientID", "Machine")
$clientSecret = [System.Environment]::GetEnvironmentVariable("clientSecret", "Machine")
$tenantId = [System.Environment]::GetEnvironmentVariable("TenantID", "Machine")
$secureClientSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
# Define the group name for which you want to sync
$GroupName = "AD_Security_Group_Name"
# Define Active Directory target OU
$OU = "OU=sync,DC=jumpstart,DC=local"  # Change to match your AD structure

# Create a PSCredential Object Using the Client ID and Secure Client Secret
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureClientSecret
# Connect to Microsoft Graph Using the Tenant ID and Client Secret Credential
Connect-MgGraph -Environment USGov -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential

# Get the group ObjectId
$Group = Get-MgGroup -Filter "DisplayName eq '$GroupName'"
if ($Group -eq $null) {
    Write-Host "Group '$GroupName' not found!"
    exit
}

# Get members of the group
$Users = Get-MgGroupMember -GroupId $Group.Id -All | ForEach-Object {
    Get-MgUser -UserId $_.Id -Property DisplayName, UserPrincipalName, Mail, GivenName, Surname
}

# Get users from Entra ID and sync to Active Directory
foreach ($User in $Users) {
    try {
        # Debugging: Log user details
        Write-Host "Processing: $($User.DisplayName) | UPN: $($User.UserPrincipalName) | Mail: $($User.Mail)"

        # Ensure the user has required attributes
        if (-not $User.UserPrincipalName) {
            Write-Warning "Skipping user: $($User.DisplayName) (Missing UPN)"
            continue
        }

        # Use Mail if available, otherwise use UserPrincipalName for SamAccountName
        $SamAccountName = if ($User.Mail) { ($User.Mail -split "@")[0] } else { ($User.UserPrincipalName -split "@")[0] }
        $UserPrincipalName = $User.UserPrincipalName  # Ensure UPN is defined

        # **Check if the user exists in Active Directory**
        $ExistingUser = Get-ADUser -Filter {SamAccountName -eq $SamAccountName} -ErrorAction SilentlyContinue

        if ($ExistingUser) {
            Write-Host "User already exists: $SamAccountName" -ForegroundColor Yellow
        } else {
            Write-Host "Creating new user: $SamAccountName"

            # Try to create the AD user and catch any errors
            try {
                New-ADUser -SamAccountName $SamAccountName `
                           -UserPrincipalName $UserPrincipalName `
                           -Name $User.DisplayName `
                           -GivenName $User.GivenName `
                           -Surname $User.Surname `
                           -EmailAddress $User.Mail `
                           -Path $OU `
                           -AccountPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
                           -ChangePasswordAtLogon $true `
                           -Enabled $true
                Write-Host "User created successfully: $SamAccountName" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -match "The specified account already exists") {
                    Write-Host "Error: User $SamAccountName already exists." -ForegroundColor Red
                } else {
                    Write-Host "Unexpected error creating user $SamAccountName':' $_" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "Error processing user $($User.DisplayName): $_" -ForegroundColor Red
    }
}

Disconnect-MgGraph
