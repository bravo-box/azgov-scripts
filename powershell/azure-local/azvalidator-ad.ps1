$params = @{
ADOUPath = 'OU=ciu-local,DC=ciu,DC=local'
DomainFQDN = 'ciu.local'
NamingPrefix = "ciu"
ActiveDirectoryServer = 'ciu.local'
ActiveDirectoryCredentials = (Get-Credential -Message 'Active Directory Credentials')
ClusterName = 'S-Cluster'
PhysicalMachineNames = "node01, node02, node03, node04"
NodeIP=@("ip1,ip2,ip3,ip4")
ProxyServer = $null
}

# Connectivity Validation

# Are you using a proxy server?
Read-Host -Prompt "Are you using a proxy server to access the internet? (Y/N)" | ForEach-Object {
    if ($_ -eq 'Y' -or $_ -eq 'y') {
        $params.ProxyServer = Read-Host -Prompt "Enter the Proxy Server address (e.g., http://proxyaddress:port)"
    }
}
Invoke-AzStackHciConnectivityValidation -Proxy $params.ProxyServer


# Validate Hardware
Invoke-AzStackHciHardwareValidation -PhysicalMachineNames $params.PhysicalMachineNames+'.'+$params.DomainFQDN -Proxy

# Validate Active Directory
Invoke-AzStackHciExternalActiveDirectoryValidation @params

