# XMGoat 
[](./xmgoat.png=100x20)

## Overview
XM Goat, is XM Cyber terraform templates that can be used for educational purposes of Azure. 

By using XM Goat, you will learn about common Azure security issues.

## Requirements
* Azure tenant
* Terafform version 1.0.9 or above
* Azure CLI
* Azure User with Owner permissions on Subscription and Global Admin privileges in AAD

## Installation
```
$ az login
$ git clone https://blablalba.com
$ cd XMDGoat
$ cd scenarios
$ cd scenario_<X> -- Where <X> represents the scenario number you want to complete
$ terraform init
$ terraform plan -out <FileName> -- Where <FileName> represents an output file
Fill all the required parameters for the terraform tempalte
$ terraform apply <FileName>
```

## How to Start ?
In order to get the initial user / service principal credential run the following query :
```
$ terraform output --json
```
For Service Principals, use the application_id.value and application_secret.value

For Users, use username.value and password.value



## Cleaning out
After completing the scenario, run the following command in order to clean all the resources created in your tenant
```
$ az login
$ cd XMGoat
$ cd scenarios
$ cd scenario_<X> -- Where <X> represents the scenario number you completed
$ terraform destroy
```
