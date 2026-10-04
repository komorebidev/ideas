# Cloud PC

A personal Azure-hosted Windows 11 cloud PC that can be provisioned, started, stopped, and rebuilt from a simple web dashboard.

The web dashboard is only responsible for controlling the VM and displaying its status/public IP. The actual Windows desktop is accessed separately using RDP.

## Architecture
                         ┌──────────────────────┐
                         │       Browser        │
                         │                      │
                         │    My Cloud PC UI    │
                         └──────────┬───────────┘
                                    │
                                  HTTPS
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │     Azure App        │
                         │       Service        │
                         │                      │
                         │  Website + API       │
                         │                      │
                         │  Managed Identity    │
                         └──────────┬───────────┘
                                    │
                          Azure SDK / ARM API
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Azure Resource       │
                         │ Manager              │
                         └──────────┬───────────┘
                                    │
                               Bicep deployment
                                    │
                                    ▼
                 ┌────────────────────────────────────┐
                 │       my-cloud-pc-resource-group   │
                 │                                    │
                 │  ┌──────────────────────────────┐  │
                 │  │       Windows 11 VM          │  │
                 │  │                              │  │
                 │  │  Public IP                   │  │
                 │  │  Network                     │  │
                 │  │  OS Disk                     │  │
                 │  └──────────────────────────────┘  │
                 └────────────────────────────────────┘
                                    │
                                    │ RDP
                                    ▼
                              User's Computer

## User Experience
The web dashboard should look roughly like this:

```text
╔══════════════════════════════════════════════╗
║              MY CLOUD PC                     ║
╠══════════════════════════════════════════════╣
║                                              ║
║  Windows 11                                  ║
║                                              ║
║  Status       ● RUNNING                      ║
║  Region       Japan East                     ║
║  Size         Standard_D4s_v6                ║
║  Public IP    20.xxx.xxx.xxx                 ║
║  Uptime       02:34:12                       ║
║                                              ║
║       [ START ]       [ STOP ]               ║
║                                              ║
║              [ REBUILD ]                     ║
║                                              ║
╚══════════════════════════════════════════════╝
```

The dashboard does not provide browser-based remote desktop access.
Once the VM is running, the public IP is displayed and the user connects to Windows using RDP.

API
The application will expose a small API:
GET  /api/desktop/status
POST /api/desktop/start
POST /api/desktop/stop
POST /api/desktop/rebuild

GET /api/desktop/status
Returns the current state of the VM.
Example:

{
  "status": "running",
  "vmName": "my-cloud-pc",
  "region": "Japan East",
  "size": "Standard_D4s_v6",
  "publicIp": "20.xxx.xxx.xxx",
  "uptime": "02:34:12"
}

POST /api/desktop/start
Starts an existing, deallocated VM.
The VM and its OS disk remain intact.

POST /api/desktop/stop
Deallocates the VM so compute resources are no longer running.
The VM's disks and configuration remain available for the next start.

POST /api/desktop/rebuild
Performs a full provisioning/rebuild operation using the Bicep template.
Conceptually:

POST /api/desktop/rebuild
        │
        ▼
Azure Resource Manager
        │
        ▼
Bicep deployment
        │
        ▼
Windows 11 VM
        │
        ▼
Networking + Public IP
        │
        ▼
VM ready

REBUILD is intended to be the destructive/fresh-provisioning operation.
START should be used for normal daily use.

##  Azure Authentication
The application should use an Azure Managed Identity.
No Azure passwords, client secrets, or credentials should be stored in the application.

