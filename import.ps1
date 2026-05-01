#################################################
# HelloID-Conn-Prov-Target-Intus-Inplanning-Import
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
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
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Resolve-Intus-InplanningError {
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
        if ($ErrorObject.ErrorDetails) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails
            $httpErrorObj.FriendlyMessage = $ErrorObject.ErrorDetails
        }
        elseif ((-not($null -eq $ErrorObject.Exception.Response) -and $ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
            if (-not([string]::IsNullOrWhiteSpace($streamReaderResponse))) {
                $httpErrorObj.ErrorDetails = $streamReaderResponse
                $httpErrorObj.FriendlyMessage = $streamReaderResponse
            }
        }
        try {
            $httpErrorObj.FriendlyMessage = ($httpErrorObj.FriendlyMessage | ConvertFrom-Json).error_description
        }
        catch {
            #displaying the old message if an error occurs during an API call, as the error is related to the API call and not the conversion process to JSON.
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Verify if a user must be either [created ] or just [correlated]
    $accessToken = Get-AccessToken
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json')
    $headers.Add('Authorization', 'Bearer ' + $accessToken)

    try {
        $pageSize = 2000 #To-Do:  Paging did not work, but a big pagesize does.

        $splatGetUserParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/users?&limit=$pageSize"
            Headers = $headers
            Method  = 'GET'
        }

        $allUsers = Invoke-RestMethod @splatGetUserParams
        Write-Verbose "Retrieved $($allUsers.Count) users. Total: $($allUsers.Count)" -Verbose
    }
    catch {

        if (-not($_.ErrorDetails.Message -match '211 - The object does not exist.')) {
            throw "Cannot get user error: [$($_.Exception.Message)]"
        }
    }
    
    # Process each user account
    foreach ($account in $allUsers) {
        # Making sure only fieldMapping fields are imported
        $data = @{}
        foreach ($field in $actionContext.ImportFields) {
            if ($account.PSObject.Properties.Name -contains $field) {
                $data[$field] = $account.$field
            }
        }

    #write-verbose -verbose ($account | out-string)

        # Make sure the displayName has a value
        $displayName = $null
        if (-not [string]::IsNullOrEmpty($account.displayName)) {
            $displayName = $account.displayName
        }
        elseif (-not [string]::IsNullOrEmpty($account.username)) {
            $displayName = $account.username
        }

        # Return the result
        Write-Output @{
            AccountReference = $account.username
            DisplayName      = $displayName
            UserName         = $account.username
            Enabled          = $account.active
            Data             = $data
        }
    }

    Write-Information 'Intus-Inplanning account import completed'
    $outputContext.success = $true
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Intus-InplanningError -ErrorObject $ex
        $auditMessage = "Could not create or correlate Intus-Inplanning account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not create or correlate Intus-Inplanning account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
