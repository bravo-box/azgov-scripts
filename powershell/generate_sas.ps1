# Generate a SAS token for an Azure Storage Container with read, write, and list permissions
# Requires the Az.Storage module
# Set your variables
$resourceGroup = ""
$storageAccountName = ""
$containerName = ""
$expiry = (Get-Date).AddMinutes(10) # Token valid for 10 minutes

# Get the storage account key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName)[0].Value

# Create a storage context
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

# Generate SAS token with read, write, list permissions
$sas = New-AzStorageContainerSASToken `
    -Name $containerName `
    -Context $context `
    -Permission rwl `
    -ExpiryTime $expiry `
    -FullUri

# Output the SAS token URI
$sas