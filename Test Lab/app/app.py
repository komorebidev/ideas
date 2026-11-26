import os

import requests
from flask import Flask, render_template, request
from azure.identity import DefaultAzureCredential

app = Flask(__name__)

SUBSCRIPTION_ID = os.environ["AZURE_SUBSCRIPTION_ID"]
RESOURCE_GROUP = os.environ["LAB_RESOURCE_GROUP"]
VM_NAME = os.environ["VM_NAME"]
VM_USERNAME = os.getenv("VM_ADMIN_USERNAME", "Not configured")
VM_PASSWORD = os.getenv("VM_ADMIN_PASSWORD", "Not configured")

ARM_BASE = "https://management.azure.com"
API_VERSION = "2024-07-01"
NETWORK_API_VERSION = "2024-03-01"

credential = DefaultAzureCredential()


def require_authentication():
    if (
        os.getenv("WEBSITE_INSTANCE_ID")
        and not request.headers.get("X-MS-CLIENT-PRINCIPAL")
    ):
        return "Authentication required. Configure Entra ID in App Service.", 401
    return None


def vm_url(operation=None):
    url = (
        f"{ARM_BASE}/subscriptions/{SUBSCRIPTION_ID}"
        f"/resourceGroups/{RESOURCE_GROUP}"
        f"/providers/Microsoft.Compute/virtualMachines/{VM_NAME}"
    )
    if operation:
        url += f"/{operation}"
    return url


def arm_request(method, url, api_version=API_VERSION):
    token = credential.get_token(
        "https://management.azure.com/.default"
    ).token

    response = requests.request(
        method,
        url,
        headers={"Authorization": f"Bearer {token}"},
        params={"api-version": api_version},
        timeout=30,
    )

    if not response.ok:
        raise RuntimeError(
            f"Azure returned HTTP {response.status_code}: {response.text}"
        )

    return response


def get_vm_status():
    response = arm_request("GET", vm_url("instanceView"))
    statuses = response.json().get("statuses", [])

    for item in statuses:
        code = item.get("code", "")
        if code.startswith("PowerState/"):
            return item.get("displayStatus", code)

    return "Status unavailable"


def get_vm_public_ip():
    try:
        vm_resp = arm_request("GET", vm_url())
        vm_data = vm_resp.json()
        
        nic_refs = vm_data.get("properties", {}).get("networkProfile", {}).get("networkInterfaces", [])
        if not nic_refs:
            return "No NIC attached"

        nic_id = nic_refs[0]["id"]
        nic_resp = arm_request("GET", f"{ARM_BASE}{nic_id}", api_version=NETWORK_API_VERSION)
        nic_data = nic_resp.json()
        
        ip_configs = nic_data.get("properties", {}).get("ipConfigurations", [])
        if not ip_configs:
            return "No IP configurations"

        pub_ip_ref = ip_configs[0].get("properties", {}).get("publicIPAddress")
        if not pub_ip_ref:
            return "No Public IP assigned"

        pub_ip_id = pub_ip_ref["id"]
        pub_ip_resp = arm_request("GET", f"{ARM_BASE}{pub_ip_id}", api_version=NETWORK_API_VERSION)
        pub_ip_data = pub_ip_resp.json()

        return pub_ip_data.get("properties", {}).get("ipAddress", "IP unavailable")

    except Exception:
        app.logger.exception("Failed to fetch public IP")
        return "Unavailable"


def perform_vm_action(action):
    operations = {
        "start": "start",
        "stop": "deallocate",
    }
    operation = operations.get(action)
    if not operation:
        raise ValueError("Unsupported action.")

    arm_request("POST", vm_url(operation))

    if action == "stop":
        return "Stop request accepted. Azure is deallocating."
    return "Start request accepted. Azure is starting."


@app.route("/", methods=["GET", "POST"])
def index():
    auth_error = require_authentication()
    if auth_error:
        return auth_error

    message = None
    error = None

    if request.method == "POST":
        action = request.form.get("action", "")
        try:
            message = perform_vm_action(action)
        except Exception as exc:
            app.logger.exception("Operation failed")
            error = str(exc)

    try:
        status = get_vm_status()
        public_ip = get_vm_public_ip()
    except Exception:
        app.logger.exception("Could not retrieve details")
        status = "Unable to retrieve status"
        public_ip = "Unavailable"
        if not error:
            error = "Could not retrieve data. Check permissions."

    return render_template(
        "index.html",
        vm_name=VM_NAME,
        vm_status=status,
        vm_ip=public_ip,
        vm_username=VM_USERNAME,
        vm_password=VM_PASSWORD,
        message=message,
        error=error,
    )


if __name__ == "__main__":
    app.run(debug=True)