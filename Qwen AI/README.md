# Qwen AI

* Local AI for practicing and studying Japanese
* RAG for inputting textbook PDF

## Architecture

- **Azure VM** hosts both **Ollama + Open WebUI**.
- Open WebUI, chat history, RAG data, and Ollama models are stored on the VM's persistent OS disk.
- **Tailscale Funnel** publishes Open WebUI to the internet without requiring a custom domain or manually managed TLS certificates.
- Access is protected through **Tailscale Funnel** and Open WebUI authentication.

## VM

The AI lab runs on an Azure VM using:

- **VM Size:** `Standard_B2as_v2`
- **vCPU:** 2
- **RAM:** 8 GB
- **Workload:** Ollama + Open WebUI + Qwen
- **Model:** Qwen 2.5 3B
- **Usage:** Interactive Japanese practice
- **Storage:** Persistent VM OS disk
- **Cost:** 月額＝約１万円


The B-series burstable VM is suitable for interactive AI usage, where there are natural pauses between questions and responses.

### Traffic Flow

`Phone / PC → HTTPS → Tailscale Funnel → Azure VM → Open WebUI → Ollama`