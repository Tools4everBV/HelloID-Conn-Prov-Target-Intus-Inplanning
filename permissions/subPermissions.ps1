################################################################
# HelloID-Conn-Prov-Target-Intus-InPlanning-SubPermissions-Group
# PowerShell V2
################################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Script Mapping lookup values and permission mapping
$permissionMapping = @(
    @{
        role              = 'Planner'
        resourceGroup     = 'Planner {{LocationOwn}}'
        exchangeGroup     = 'Company'
        shiftGroup        = 'Company'
        worklocationGroup = 'Root'
        userGroup         = 'Root'
    },
    @{
        role              = 'Leidinggevende'
        resourceGroup     = '{{CostCenterOwn}}'
        exchangeGroup     = 'Company'
        shiftGroup        = 'Company'
        worklocationGroup = 'Root'
        userGroup         = 'Root'
    },
    @{
        role              = 'ADMIN'
        resourceGroup     = 'ADMIN'
        exchangeGroup     = 'ADMIN'
        shiftGroup        = 'ADMIN'
        worklocationGroup = 'Root'
        userGroup         = 'Root'
    }
)

# Lookup values which are used in the mapping to determine {{REPLACEMENT}}
$lookupValues = @{
    '{{LocationOwn}}'   = { $_.Division.Name }
    '{{CostCenterOwn}}' = { $_.Department.ExternalId }
}

#region functions
function Resolve-InPlanningError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            if ($errorDetailsObject.error_description) {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.error_description
            }
            else {
                $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}

function Get-AccessToken {
    [CmdletBinding()]
    param (
    )
    process {
        try {
            $tokenHeaders = [System.Collections.Generic.Dictionary[string, string]]::new()
            $tokenHeaders.Add('Content-Type', 'application/x-www-form-urlencoded')

            $splatGetTokenParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/api/token"
                Headers = $tokenHeaders
                Method  = 'POST'
                Body    = @{
                    client_id     = $actionContext.Configuration.clientId
                    client_secret = $actionContext.Configuration.clientSecret
                    grant_type    = 'client_credentials'
                }
            }
            Write-Output (Invoke-RestMethod @splatGetTokenParams).access_token
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Resolve-ReplaceHolderValue {
    param (
        [string]
        $replaceVariable,

        [string]
        $mappedProperty,

        $desiredPermission,

        $contract
    )
    # Replace replace placeholder with actual value
    if (-not [string]::IsNullOrEmpty($mappedProperty)) {
        $keys = @($desiredPermission.Keys)
        for ($i = 0; $i -lt $keys.Count; $i++) {
            if ($desiredPermission[$keys[$i]] -like "*$($replaceVariable)*") {
                $desiredPermission[$keys[$i]] = $desiredPermission[$keys[$i]] -replace ($replaceVariable, $mappedProperty)
            }
        }
    }
    else {
        throw "Permission expects [$($replaceVariable)] to grant the permission but the specified value is empty for contract with id: [$($contract.ExternalId)]"
    }
}
#endregion

# Begin
try {
    # Verify if [AccountReference] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    if ($actionContext.Operation -ne 'revoke' ) {
        $subPermission = $permissionMapping | Where-Object { $_.role -eq $actionContext.References.Permission.Reference }
        if ($null -eq $subPermission) {
            throw "Permission [$($actionContext.References.Permission.Reference)] does not have a valid script mapping defined"
        }

        $lookupValuesToCheck = $subPermission.Values -match '\{\{[^}]+\}\}'
        foreach ($replaceVariable in $lookupValuesToCheck) {
            if ($replaceVariable -notin $lookupValues.keys ) {
                throw "Permission [$($actionContext.References.Permission.Reference)] expects a value for [$($replaceVariable)], but it was not provided as script lookup value"
            }
        }
    }

    # Set Headers for API calls
    $accessToken = Get-AccessToken
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json')
    $headers.Add('Authorization', 'Bearer ' + $accessToken)

    Write-Information 'Verifying if a InPlanning account exists'
    try {
        $splatGetUserParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/users/$($actionContext.References.Account)"
            Headers = $headers
            Method  = 'GET'
        }
        $correlatedAccount = Invoke-RestMethod @splatGetUserParams
    }
    catch {
        if ( -not ($_.ErrorDetails.Message -match '211 - Object does not exist')) {
            $correlatedAccount = $null
        }
    }

    if ($null -ne $correlatedAccount) {
        $lifecycleProcess = 'ManageSubPermissions'
        $currentRoles = [System.Collections.Generic.List[object]]::new()
        if ($null -ne $correlatedAccount.roles) {
            [System.Collections.Generic.List[object]]$currentRoles = $correlatedAccount.roles.PSObject.copy()
        }
    }
    else {
        $lifecycleProcess = 'NotFound'
    }

    switch ($lifecycleProcess) {
        'ManageSubPermissions' {
            # Collect current permissions
            $currentPermissions = @{}
            foreach ($permission in $actionContext.CurrentPermissions) {
                $currentPermissions[$permission.Reference.Id] = $subPermission
            }

            # Collect and calculate desired permissions
            $desiredPermissions = @{}
            if (-not($actionContext.Operation -eq 'revoke')) {

                # Processing Dynamic permissions body with placeholder(s)
                if ($subPermission.Values -match '\{\{[^}]+\}\}') {
                    Write-Information "Permission [$($actionContext.References.Permission.Reference)] contains placeholder values which need to be resolved"
                    foreach ($contract in $personContext.Person.Contracts) {
                        if ($contract.Context.InConditions -or ($actionContext.DryRun -eq $true)) {
                            $desiredPermission = $subPermission.PSObject.Copy()
                            foreach ($replaceVariable in $lookupValues.GetEnumerator()) {
                                # Perform lookup in HelloId contract for the correct
                                $lookupValue = $replaceVariable.Value
                                $mappedProperty = ($contract | Select-Object $lookupValue).$lookupValue
                                $null = Resolve-ReplaceHolderValue -ReplaceVariable $replaceVariable.Key -MappedProperty $mappedProperty -Contract  $contract -DesiredPermission $desiredPermission
                            }
                            $desiredPermissionUniqueKey = "$($actionContext.References.Permission.Reference)-$($desiredPermission.ResourceGroup)"
                            $desiredPermissions[$desiredPermissionUniqueKey] = $desiredPermission
                        }
                    }
                }

                # Processing Static permissions body without placeholder(s)
                else {
                    $desiredPermission = $subPermission.PSObject.Copy()
                    $desiredPermissionUniqueKey = "$($actionContext.References.Permission.Reference)-$($desiredPermission.ResourceGroup)"
                    $desiredPermissions[$desiredPermissionUniqueKey] = $desiredPermission
                }

                # Process desired permissions calculation Grant and Update
                foreach ($permission in $desiredPermissions.GetEnumerator()) {
                    $outputContext.SubPermissions.Add([PSCustomObject]@{
                            DisplayName = $permission.Name
                            Reference   = [PSCustomObject]@{
                                Id = $permission.Name
                            }
                        })
                    if (-not $currentPermissions.ContainsKey($permission.Name)) {
                        if ($actionContext.DryRun -eq $true) {
                            Write-Information "[DryRun] Grant access to permission $($permission.Name), will be executed during enforcement"
                        }
                        $existingRole = $currentRoles | Where-Object { $_.role -eq $permission.Value.role -and $_.resourceGroup -eq $permission.Value.resourceGroup }
                        if (-not $existingRole) {
                            $null = $currentRoles.Add($permission.value)
                        }
                        elseif ($existingRole.count -eq 1) {
                            $currentRoles.Remove($existingRole)
                            $currentRoles.Add($permission.value)
                        }

                        $outputContext.AuditLogs.Add([PSCustomObject]@{
                                Action  = 'GrantPermission'
                                Message = "Granted access to permission $($permission.Name)"
                                IsError = $false
                            })
                    }
                }
            }

            # Process and calculate current permissions Revoke
            foreach ($permission in $currentPermissions.GetEnumerator()) {
                $roleName = $permission.Name -split '-' | Select-Object -First 1
                $resourceGroup = $permission.Name -split '-' | Select-Object -Last 1
                if (-not $desiredPermissions.ContainsKey($permission.Name)) {
                    if ($actionContext.DryRun -eq $true) {
                        Write-Information "[DryRun] Revoke access to permission $($permission.Name), will be executed during enforcement"
                    }
                    $existingRole = $currentRoles | Where-Object { $_.role -eq $roleName -and $_.resourceGroup -eq $resourceGroup }

                    # Remove from current roles for later update
                    $null = $currentRoles.Remove($existingRole)

                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Action  = 'RevokePermission'
                            Message = "Revoked access to permission $($permission.Name)"
                            IsError = $false
                        })
                }
            }

            # Actual update InPlanning account with desired roles
            $correlatedAccount.roles = @($currentRoles)
            $body = ($correlatedAccount | ConvertTo-Json -Depth 10)
            $splatUpdateUserParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/api/users"
                Headers     = $headers
                Method      = 'PUT'
                Body        = $body
                ContentType = 'application/json;charset=utf-8'
            }
            if (-not($actionContext.DryRun -eq $true)) {
                $null = Invoke-RestMethod @splatUpdateUserParams
            }

            $outputContext.Success = $true
            break
        }

        'NotFound' {
            Write-Information "InPlanning account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "InPlanning account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
                    IsError = $true
                })
            break
        }
    }
}
catch {
    if ($outputContext.AuditLogs.Count -gt 0) {
        $null = $outputContext.AuditLogs = [System.Collections.Generic.List[object]]::new()
    }

    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-InPlanningError -ErrorObject $ex
        $auditMessage = "Could not manage InPlanning permissions. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not manage InPlanning permissions. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}