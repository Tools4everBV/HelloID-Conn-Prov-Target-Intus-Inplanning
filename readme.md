
# HelloID-Conn-Prov-Target-Intus-Inplanning

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/intus-logo.png">
</p>


## Table of contents

- [HelloID-Conn-Prov-Target-Intus-Inplanning](#helloid-conn-prov-target-intus-inplanning)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
      - [Permissions Remarks](#permissions-remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Intus-Inplanning_ is a _target_ connector. The Intus Inplanning connector facilitates the creation, updating, enabling, and disabling of user accounts in Intus Inplanning. Additionally, it grants and revokes roles as entitlements to the user account.

| Endpoint                                          | Description                                   |
| ------------------------------------------------- | --------------------------------------------- |
| /api/token                                        | Gets the Token to connect with the api (POST) |
| /api/users/AccountReference                       | get user based on the account reference (GET) |
| /api/users                                        | creates and updates the user (POST), (PUT)    |

The following lifecycle actions are available:

| Action               | Description                                                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| create.ps1           | PowerShell _create_ lifecycle action                                                                                                   |
| delete.ps1           | -                                                                                                                                      |
| disable.ps1          | PowerShell _disable_ lifecycle action                                                                                                  |
| enable.ps1           | PowerShell _enable_ lifecycle action                                                                                                   |
| update.ps1           | PowerShell _update_ lifecycle action                                                                                                   |
| subPermissions.ps1   | PowerShell _Handle all actions Script_ - lifecycle action                                                                              |
| permissions.ps1      | PowerShell _permissions_ lifecycle action                                                                                              |
| resources.ps1        | -                                                                                                                                      |
| configuration.json   | Default _[Configuration.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Intus-Inplanning/blob/main/configuration.json)_ |
| fieldMapping.json    | Default _[FieldMapping.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Intus-Inplanning/blob/main/fieldMapping.json)_   |

## Getting started

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Intus-Inplanning_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value      |
    | ------------------------- | ---------- |
    | Enable correlation        | `True`     |
    | Person correlation field  | ExternalId |
    | Account correlation field | `username` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection settings

The following settings are required to connect to the API.

| Setting       | Description                             | Mandatory   |
| ------------- | --------------------------------------- | ----------- |
| Client id     | The Client id to connect to the API     | Yes         |
| Client secret | The Client Secret to connect to the API | Yes         |
| BaseUrl       | The URL to the API                      | Yes         |

### Prerequisites
 - Before using this connector, ensure you have the appropriate Client ID and Client Secret in order to connect to the API.

### Remarks
- Set the number of concurrent actions to 1. Otherwise, the 'Get-Token' operation of one run will interfere with that of another run.
- The username cannot be modified in Intus Inplanning or HelloID since it serves as the account reference.


#### Permissions Remarks
- The "Unique Key" of the permissions is a combination of a role and a resource group. This means that you can have multiple permissions assignments with the same role and different resource groups, they will be treated as sub-permissions in HelloID based on the contracts in conditions. To accomplish this, use placeholder variables in the resource group, such as `{{CostCenterOwn}}` and `{{LocationOwn}}`, which will be replaced with actual values from the contract that is 'InConditions'.
- Updating properties of granted roles is not always possible because they may not be relevant to the role. They are ignored, which can result in the API body not being updated. This can occur when exchangeGroup, shiftGroup, workLocationGroup, or userGroup are populated with placeholders, so an actual update of granted permissions is in that case ignored. This is a limitation of the API, not the connector.

- The Permissions.ps1 script defines only the role names (Planner, Leidinggevende, ADMIN)
- The SubPermissions.ps1 script contains the permission body/mapping with the full structure for each role.
- The permission mapping in the subPermissions.ps1 script uses the following structure, whereas the 'role' attribute corresponds to the permission in HelloID.

```PowerShell
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
    }
)
```
- The placeholder values are resolved using the `$lookupValues` hashtable in the subPermissions.ps1 script:

```PowerShell
$lookupValues = @{
    '{{LocationOwn}}'   = { $_.Division.Name }
    '{{CostCenterOwn}}' = { $_.Department.ExternalId }
}
```

- The placeholder values must be existing values within Intus Inplanning before they can be used

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/1481-helloid-conn-prov-target-intus)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

