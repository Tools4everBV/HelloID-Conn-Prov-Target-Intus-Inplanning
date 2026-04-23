############################################################
# HelloID-Conn-Prov-Target-Intus-Inplanning-Permissions
# PowerShell V2
############################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12


try {
    Write-Information 'Retrieving permissions'
    $permissions = @(
        @{
            RoleName = 'Planner'
        },
        @{
            RoleName = 'Leidinggevende'
        },
        @{
            RoleName = 'ADMIN'
        }
    )

    # Make sure to test with special characters and if needed; add utf8 encoding.
    foreach ($permission in $permissions) {
        $outputContext.Permissions.Add(
            @{
                DisplayName    = $permission.RoleName
                Identification = @{
                    Reference = $permission.RoleName
                }
            }
        )
    }
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
}
