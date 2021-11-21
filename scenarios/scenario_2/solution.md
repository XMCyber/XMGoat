1. az login --service-principal -u <\ID> -p <\Secret> -t <\TenantID> --allow-no-subscriptions
2. az keyvault list
3. az keyvault secret list --vault-name <\KeyVaultName>
4. az keyvault secret show --vault-name <\KeyVaultName> --name <\SecretName>
5. az login -u <\UserName> -p <\Password>>
6. az role assignment create --role "Owner" --assignee "<\UserName>"
7. az role assignment list --all --assignee <\UserName>