# XMGoat 
<img src="https://github.com/XMCyber/XMGoat/blob/main/xmgoat.png" width="400" height="400">

## Overview
XM Goat is composed of XM Cyber terraform templates that help you learn about common Azure security issues. Each template is a vulnerable environment, with some significant misconfigurations. Your job is to attack and compromise the environments.

Here’s what to do for each environment:

1. Run installation and then get started.

2. With the initial user and service principal credentials, attack the environment based on the scenario flow (for example, XMGoat/scenarios/scenario_1/scenario1_flow.png).

3. If you need help with your attack, refer to the solution (for example, XMGoat/scenarios/scenario_1/solution.md).

4. When you’re done learning the attack, clean up.

## Requirements
* Azure tenant
* Terafform version 1.0.9 or above
* Azure CLI
* Azure User with Owner permissions on Subscription and Global Admin privileges in AAD

## Installation
Run these commands:
```
$ az login
$ git clone https://github.com/XMCyber/XMGoat.git
$ cd XMDGoat
$ cd scenarios
$ cd scenario_<\SCENARIO>
```
Where <\SCENARIO> is the scenario number you want to complete
```
$ terraform init
$ terraform plan -out <\FILENAME>
$ terraform apply <\FILENAME>
```
Where <\FILENAME> is the name of the output file

## Get started
To get the initial user and service principal credentials, run the following query:
```
$ terraform output --json
```
For Service Principals, use application_id.value and application_secret.value.

For Users, use username.value and password.value.

## Cleaning out
After completing the scenario, run the following command in order to clean all the resources created in your tenant
```
$ az login
$ cd XMGoat
$ cd scenarios
$ cd scenario_<\SCENARIO>
```
Where <\SCENARIO> is the scenario number you want to complete
```
$ terraform destroy
```
