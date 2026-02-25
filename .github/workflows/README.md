# Part 4 - CI/CD Pipeline with GitHub Actions

## Overview

A CI/CD pipeline built with GitHub Actions that automatically deploys
the web application to the Azure VM every time code is pushed to the
main branch. The pipeline installs Ansible on a free GitHub-hosted runner
and uses the existing Ansible deploy playbook - no deployment logic is
duplicated.

---

## Automation Flow

```
Developer pushes code to GitHub (main branch)
              │
              ▼
    GitHub Actions Runner starts (free Ubuntu machine)
              │
              ├── 1. Checkout full repository
              ├── 2. Install Ansible
              ├── 3. Write SSH private key to runner
              ├── 4. Add VM to known hosts (ssh-keyscan)
              ├── 5. Generate Ansible inventory from secrets
              │
              │  SSH (Port 22) using private key
              ▼
        Azure VM - test-vm (Norway East)
              │
              └── Ansible deploy.yml runs:
                    ├── Create /opt/app directory
                    ├── Copy app/ files from runner to VM
                    ├── Tear down old containers and images
                    ├── docker-compose build (fresh image)
                    ├── docker-compose up (start container)
                    ├── Wait 5 seconds
                    ├── Verify container is running
                    └── Test app responds on port 8080 ✅
```

---

## Pipeline File Location

```
📁 docker-ca-project/
└── 📁 .github/
    └── 📁 workflows/
        └── 📄 deploy.yml     ← GitHub reads this automatically
```

GitHub detects any `.yml` file inside `.github/workflows/` and treats
it as a pipeline. No registration or configuration needed.

---

## Trigger Events

| Trigger                 | When it runs                     |
| ----------------------- | -------------------------------- |
| `push` to `main` branch | Automatically on every code push |
| `workflow_dispatch`     | Manually from GitHub Actions UI  |

---

## Pipeline Steps Explained

### Step 1 - Checkout repository

Downloads the full repository onto the GitHub runner machine.
Gives the runner access to both `Ansible/deploy.yml` and `app/` files
that Ansible will copy to the VM.

### Step 2 - Install Ansible

Installs Ansible on the GitHub runner using `apt-get`.
The runner is a fresh Ubuntu machine every time - nothing is pre-installed.

### Step 3 - Configure SSH key

Writes the private SSH key from GitHub secrets to `~/.ssh/id_rsa` on the runner.
`ssh-keyscan` adds the VM to known hosts so SSH does not ask for manual confirmation.
`chmod 600` sets correct permissions - SSH rejects keys with open permissions.

### Step 4 - Create Ansible inventory

Generates `Ansible/inventory/hosts.ini` dynamically using secrets.
The VM IP is never hardcoded in the repository - pulled from `VM_HOST` secret.
This means the inventory file is always up to date with the correct VM IP.

### Step 5 - Run Ansible deploy playbook

Runs `Ansible/deploy.yml` using the generated inventory.
Ansible connects to the VM over SSH and handles all deployment steps.
All Docker logic lives in the Ansible playbook - not duplicated in the pipeline.

### Step 6 - Print live URL

Prints the application URL to the pipeline log for quick access.

---

## GitHub Secrets Required

Go to: GitHub repo → Settings → Secrets and variables → Actions → New repository secret

| Secret Name   | Value                            | How to get it                     |
| ------------- | -------------------------------- | --------------------------------- |
| `VM_HOST`     | Azure VM public IP               | Azure Portal → test-vm → Overview |
| `VM_USERNAME` | `azureuser`                      | Fixed value - type as shown       |
| `VM_SSH_KEY`  | Private SSH key (base64 encoded) | See below                         |

### Getting the SSH key (base64 encoded)

Mac/Linux:

```bash
base64 -w 0 ~/.ssh/id_rsa
```

Windows (WSL):

```bash
base64 -w 0 ~/.ssh/id_rsa
```

Copy the entire output - one long line - and paste as `VM_SSH_KEY` secret.

In the pipeline the key is decoded before use:

```bash
echo "$SSH_KEY" | base64 -d > ~/.ssh/id_rsa
```

---

## How to Trigger the Pipeline

### Automatically - push any change:

```bash
git add .
git commit -m "update web page"
git push
```

### Manually - from GitHub UI:

```
GitHub repo → Actions tab → Build and Deploy to Azure VM → Run workflow → Run workflow
```

---

## Reading the Pipeline Log

Go to: GitHub repo → Actions tab → click the running workflow

```
✅ Checkout repository
✅ Install Ansible
✅ Configure SSH key
✅ Create Ansible inventory
✅ Run Ansible deploy playbook
      PLAY [Deploy Docker web application]
      TASK [Create app directory on VM]    ok
      TASK [Copy app files to VM]          changed
      TASK [Tear down existing containers] changed
      TASK [Build and start containers]    changed
      TASK [Wait for container]            ok
      TASK [Verify container is running]   ok
      TASK [Test app is responding]        ok
      PLAY RECAP: ok=7 changed=3
✅ App is live
      🌐 http://YOUR_VM_IP:8080
```

---

## Troubleshooting

| Problem                         | Fix                                                                            |
| ------------------------------- | ------------------------------------------------------------------------------ |
| `Load key: error in libcrypto`  | SSH key not base64 encoded correctly - re-run base64 command and update secret |
| `UNREACHABLE`                   | Port 22 blocked in NSG or VM is stopped - check Azure Portal                   |
| `Permission denied (publickey)` | Wrong SSH key - check VM_SSH_KEY secret matches the key on the VM              |
| `No hosts matched`              | Inventory file indentation issue - check hosts.ini was generated correctly     |
| Pipeline not triggering         | Check file is at `.github/workflows/deploy.yml` and push was to `main` branch  |
