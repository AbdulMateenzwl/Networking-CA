# Part 3 — Docker Container Deployment

## Overview

A simple HTML web application served by Nginx inside a Docker container,
running on the Azure VM provisioned in Part 1 and configured in Part 2.
The container is deployed automatically using the Ansible playbook from Part 2.

---

## Automation Flow

```
Local Machine / GitHub Actions Runner
        │
        │  Ansible deploy.yml (SSH)
        ▼
  Azure VM — test-vm (Norway East)
        │
        ├── 1. Create /opt/app directory
        ├── 2. Copy app/ folder from repo to VM
        ├── 3. Stop old container (if running)
        ├── 4. docker build -t webapp .
        ├── 5. docker run -d -p 8080:80 webapp
        └── 6. Verify app responds on port 8080
                      │
                      ▼
              Docker Container (webapp)
                      │
                      ▼
               Nginx Web Server
               (port 80 inside container)
                      │
                      ▼
               index.html ✅
```

---

## Folder Structure

```
app/
├── Dockerfile              ← Recipe to build the Docker image
├── docker-compose.yml      ← Defines how to run the container
├── nginx.conf              ← Nginx web server configuration
└── src/
    └── index.html          ← The web application page

ansible/
├── deploy.yml              ← Automates the entire deployment
└── inventory/
    └── hosts.ini           ← VM IP address (set up in Part 2)
```

---

## File Descriptions

### Dockerfile

Defines how the Docker image is built — step by step:

| Step | Instruction                                      | What it does                                            |
| ---- | ------------------------------------------------ | ------------------------------------------------------- |
| 1    | `FROM nginx:alpine`                              | Start from official Nginx — alpine version is only 23MB |
| 2    | `RUN rm -rf /usr/share/nginx/html/*`             | Remove default Nginx welcome page                       |
| 3    | `COPY src/ /usr/share/nginx/html/`               | Copy our HTML into the folder Nginx serves              |
| 4    | `COPY nginx.conf /etc/nginx/conf.d/default.conf` | Replace default Nginx config with ours                  |
| 5    | `EXPOSE 80`                                      | Tell Docker this container uses port 80                 |
| 6    | `CMD ["nginx", "-g", "daemon off;"]`             | Start Nginx when container runs                         |

### docker-compose.yml

Defines how the container is run:

- Container name: `webapp`
- Port mapping: `8080` on VM → `80` inside container
- Restart policy: `always` — container restarts automatically on VM reboot or crash

### nginx.conf

Configures the Nginx web server inside the container:

- Listens on port 80
- Serves files from `/usr/share/nginx/html`
- Default file: `index.html`
- 404 errors redirect back to `index.html`

### ansible/deploy.yml

Automates the full deployment over SSH:

- Copies `app/` from local machine or GitHub Actions runner to `/opt/app/` on VM
- Stops and removes the old container
- Builds a fresh Docker image from the Dockerfile
- Starts the new container
- Verifies the app responds on port 8080

---

## Port Mapping Explained

```
Browser
  │
  │  http://VM_PUBLIC_IP:8080
  ▼
Azure NSG — port 8080 inbound rule (set up in Part 1)
  │
  ▼
Azure VM — port 8080
  │
  │  Docker port mapping  8080 → 80
  ▼
Docker Container (webapp) — port 80
  │
  ▼
Nginx web server
  │
  ▼
/usr/share/nginx/html/index.html ✅
```

---

## How to Deploy

### Option A — Automated with Ansible (recommended)

One command deploys everything:

```bash
cd Ansible
ansible-playbook deploy.yml
```

Ansible will:

1. Copy app files from your machine to the VM
2. Stop the old container
3. Build a fresh Docker image
4. Start the new container
5. Verify the app responds
6. Print the live URL

### Option B — Manual on the VM

SSH in and run step by step:

```bash
# 1. SSH into your VM
ssh azureuser@YOUR_VM_PUBLIC_IP

# 2. Navigate to app directory
cd /opt/app

# 3. Build the image
docker build -t webapp .

# 4. Start the container
docker run -d --name webapp --restart always -p 8080:80 webapp:latest

# 5. Verify it is running
docker ps

# 6. Test it responds
curl http://localhost:8080
```

---

## Verification

After deployment open a browser and go to:

```
http://VM_PUBLIC_IP:8080
```

You should see the web application with the Live on Azure badge.

Run these on the VM to confirm everything is working:

```bash
# Container is running
docker ps

# App responds
curl http://localhost:8080

# Nginx logs — no errors
docker logs webapp

# Container resource usage
docker stats webapp --no-stream
```

---

## Updating the Web Page

1. Edit `src/index.html` on your laptop
2. Run `ansible-playbook deploy.yml` from the ansible folder
3. Ansible rebuilds the image and restarts the container
4. Refresh browser — changes are live ✅

---

## Useful Docker Commands

```bash
# See running containers
docker ps

# See all containers including stopped ones
docker ps -a

# View container logs
docker logs webapp

# Stop the container
docker stop webapp

# Remove the container
docker rm webapp

# Rebuild and restart
docker build -t webapp . && docker restart webapp

# Check disk usage
docker system df
```

---

## Architectural Diagram

See `/app/docker-flow.drawio.png` for a visual overview of how the components interact.

![Docker Flow Diagram](/app/docker-flow.drawio.png)

---

## Troubleshooting

| Problem                             | Fix                                                              |
| ----------------------------------- | ---------------------------------------------------------------- |
| Port 8080 not accessible in browser | Check Azure NSG has port 8080 inbound rule open                  |
| `docker build` fails                | Check Dockerfile path is correct — run from inside `app/` folder |
| Container exits immediately         | Run `docker logs webapp` to see the error                        |
| Old version showing in browser      | Hard refresh: Ctrl+Shift+R (Windows) Cmd+Shift+R (Mac)           |
| Permission denied on docker         | Run: `sudo usermod -aG docker azureuser` then reconnect SSH      |
