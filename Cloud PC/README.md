# Cloud PC

A personal Azure-hosted Windows 11 cloud PC that can be provisioned, started and stopped through web page.

## Cloud Automation Setup (Azure Component)

### Phase 1: Set Up Azure Automation (The VM Component)
Azure Automation will run the script to turn on your proxy VM.

1. Go to the Azure Portal and search for **Automation Accounts**. Create one in the same region as your proxy VM.
2. In your new Automation Account menu, click **Identity** (under *Account Settings*). Turn the status for **System-assigned** to **On** and click **Save**.
3. Click **Azure role assignments** on that same screen -> **Add role assignment**.
   * **Scope:** Resource group
   * **Subscription:** Your subscription
   * **Resource group:** The group containing your proxy VM
   * **Role:** **Virtual Machine Contributor**
4. Go to **Runbooks** -> **Create a runbook**. Name it `Start-ProxyVM`, set the type to **PowerShell**, and paste this script:
   ```powershell
   Connect-AzAccount -Identity
   Start-AzVM -ResourceGroupName "Your-Resource-Group-Name" -Name "Your-Proxy-VM-Name"
   ```
5. Click **Save**, then click **Publish**.

---

### Phase 2: Create the Secure Gateway (Azure Logic Apps)
This acts as the secure URL your phone will talk to.

1. Search the Azure Portal for **Logic Apps** and click **Add**. Choose the **Consumption** plan (this plan costs \$0 unless actively clicked).
2. Open the Logic App Designer and select the trigger: **When an HTTP request is received**.
3. **Crucial Entra ID Security Configuration:**
   * Look at the bottom of the HTTP trigger box and click **Add new parameter**. Check the box for **Authorization**.
   * Set the type to **Microsoft Entra ID OAuth**.
   * In the **Tenant** field, paste your Entra Tenant ID.
   * In the **Audience** field, type: `https://azure.com` (this ensures it looks for a valid Azure-scoped Entra identity token).
4. Click the **New Step** button below the trigger. Search for **Azure Automation** and choose the action: **Create job**.
5. Log into your Azure subscription account if prompted. Select your Subscription, Resource Group, Automation Account, and pick the `Start-ProxyVM` runbook.
6. Click **Save**.

*Once saved, click back into the first **When an HTTP request is received** box. You will see a freshly generated URL in the **HTTP POST URL** field. Copy this URL.*

---

### Phase 3: Creating the Phone Shortcut
To trigger an HTTP POST request that includes your Entra authentication token natively from your phone, you can use the built-in automation utilities on iOS or Android.

#### For iPhone (Apple Shortcuts App):
1. Open the **Shortcuts** app and tap **+** to create a new shortcut. Name it "Turn On Proxy VM".
2. Add the action: **Get Contents of URL**.
3. Paste your Logic App HTTP POST URL into the URL field.
4. Tap **Show More** or the arrow next to the URL to expand the settings:
   * Change the Method from GET to **POST**.
   * Under **Headers**, add a new field. Key: `Authorization`, Value: `Bearer <Your_Entra_Token>`*
5. Tap the share icon at the bottom and select **Add to Home Screen**.

*(Note: For the simplest personal setup, you can generate a long-lived Entra App Registration token, or skip the OAuth parameter inside the Logic App and rely purely on keeping the Logic App's native cryptographic access signature string—the `sig=` part of the URL—strictly private to your eyes only).*

---

### Phase 4: Configure the Automated Shutdown
To ensure you don't leave the proxy VM running indefinitely and racking up compute costs, set up its auto-shutdown routine:

1. Go to your **Proxy VM** blade in the Azure Portal.
2. In the left-hand menu under *Operations*, click **Auto-shutdown**.
3. Check **Enabled**, set your preferred time (e.g., `11:00 PM`), and select your time zone.
4. Set *Send notification before shutdown* to **No** and click **Save**.
