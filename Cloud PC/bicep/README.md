# bicep

* Template and documentation

## Checking deployment status

Via Azure Portal: Navigate to your Resource Group, click on Deployments under the Settings menu, select your deployment name, and click Deployment details to see step-by-step progress for every individual resource.

## Bicep build and validation

```powershell
az bicep build --file main.bicep
```

## Run command

```powershell
az deployment sub create --name MAIN --location japaneast --template-file main.bicep --parameters adminUsername="..." adminPassword="..." postgresAdministratorLogin="..." postgresAdministratorPassword="..." guacamolePostgresUsername="..." guacamolePostgresPassword="..." --verbose
```

## Check deployment outputs

```powershell
az deployment sub show --name MAIN --query properties.outputs
```

## Parameters

adminUsername is for Win11 VM
adminPassword is for Win11 VM
Others are labeled

### `main.bicep`
Main deployment file. Creates the resource group and deploys the network, PostgreSQL, Windows VM, and Guacamole modules in the correct order.

### `network.bicep`
Creates the VNet, separate ACA/Windows/PostgreSQL subnets, Windows NSG, and PostgreSQL private DNS zone.

### `postgres.bicep`
Creates the private Azure Database for PostgreSQL Flexible Server and the `guacamole_db` database.

### `win11VM.bicep`
Creates the private Windows 11 VM and runs `requirements.ps1` to install applications and configure PostgreSQL/Guacamole.

### `requirements.ps1`
Runs inside the Windows VM. Installs required applications, PostgreSQL client tools, initializes the Guacamole database schema, and creates the Guacamole PostgreSQL user.

### `guacamole.bicep`
Creates the Azure Container Apps environment and Guacamole + guacd containers, exposing Guacamole through HTTPS and connecting it to the private Windows VM and PostgreSQL server.

## ACA Networking requirement

Azure Container Apps using a custom VNet requires a dedicated subnet for the Container Apps Environment. The subnet cannot also contain your Windows VM. Microsoft explicitly documents this requirement. Microsoft Learn

```text
VNet 10.10.0.0/24
└── 10.10.0.0/24
    ├── Windows VM
    └── ACA
```
Will not work for ACA VNet integration.
Needs separate subnet

Also, the ACA subnet needs to be at least /27 for the workload-profile environment. Microsoft Learn

# Cleanup

```powershell
az group delete --name win11CPC-6411 --yes
```