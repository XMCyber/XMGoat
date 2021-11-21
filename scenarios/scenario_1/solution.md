1. az login -u <\Username> -p <\Password> --allow-no-subscriptions
2. az ad app list --show-mine
3. az ad app list --display-name <\AppName>
4. az ad app credential reset --id <\AppObejctID>
5. az login --service-principal -u <\AppID> -p <\Secret> -t <\TenantID> --allow-no-subscriptions
6. az vm list
7. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
8. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "az login --identity --username <\UserAssignedIdentityClientID>"
9. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "az storage account list"
10. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "az storage container list --account-name <\StorageAccountName> --auth-mode login"
11. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "az storage blob list -c <\ContainerName> --account-name </StorageAccountName> --auth-mode login"
12. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "az storage blob download -n secret.txt -c <\ContainerName> --account-name </StorageAccountName> --auth-mode login -f /secret.txt"
13. az vm run-command invoke --command-id RunShellScript --name <\VMName> --resource-group <\RGName> --scripts "cat /secret.txt"
