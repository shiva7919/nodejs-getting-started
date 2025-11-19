# 🚀 Node.js Heroku Sample — Dockerized & Deployed on AWS EC2 with Nginx

> Complete, production-ready documentation in Markdown for building, running and operating the Node.js (Heroku sample) app in a Docker container on an Ubuntu EC2 instance with Nginx as a reverse proxy.

---

## Table of Contents

1. Project summary
2. Architecture diagram
3. Prerequisites
4. Repository layout
5. Docker: Dockerfile and image build
6. Running locally with Docker
7. Deploying to AWS EC2 (Ubuntu) — step-by-step
8. Nginx reverse-proxy configuration
9. Systemd service for container auto-start
10. HTTPS with Let's Encrypt (Certbot)
11. CI/CD — Jenkins pipeline example
12. Docker Compose (optional)
13. Security (AWS Security Groups & OS hardening)
14. Health checks and maintenance
15. Troubleshooting guide (common errors + fixes)
16. FAQ
17. Useful commands & references

---

## 1. Project Summary

This project packages a Node.js Express application (Heroku sample) into a Docker image and runs it on an Ubuntu EC2 instance. Nginx acts as the public-facing reverse proxy (port 80 → container port). The documentation covers everything from building the image and running it locally to deploying to EC2, configuring Nginx, enabling HTTPS, and automating startup via systemd.

Target audience: DevOps engineers, backend engineers, and developers who want a reproducible deployment pattern using Docker + Nginx on EC2.

---

## 2. Architecture

```
User → Nginx (port 80/443) → Docker Host (Docker daemon on EC2) → Docker Container → Node.js App (port 5006)
```

Key points:

* Nginx listens on ports 80/443 and proxies traffic to the container host port (3000 in this repo) which maps to the container's internal port (5006).
* Docker isolates the app. You can run multiple apps by varying host ports and Nginx upstream definitions.

---

## 3. Prerequisites

* An AWS account and an Ubuntu EC2 instance (Ubuntu 20.04 / 22.04 recommended).
* Security group with SSH (22) restricted to your IP, HTTP (80) open, HTTPS (443) open if using TLS.
* Docker (or Docker Engine) installed on EC2.
* Nginx installed on EC2.
* A domain name pointed to your EC2 public IP (required for Let's Encrypt TLS).
* Optional: Jenkins server for CI/CD.

Local dev machine requirements:

* Docker Engine
* Git

---

## 4. Repository layout (suggested)

```
/ (repo root)
├─ Dockerfile
├─ package.json
├─ index.js (express app)
├─ views/ (ejs files)
├─ public/ (static assets)
├─ nginx/ (optional local nginx confs)
├─ Jenkinsfile (optional)
└─ README.md
```

---

## 5. Dockerfile (example)

Below is a recommended Dockerfile that produces a small, stable image using the official Node base.

```dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .

# Stage 2: Runtime
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app /app
ENV PORT=5006
EXPOSE 5006
CMD ["node", "index.js"]
```

Notes:

* Uses multi-stage to reduce final image size (copies only production deps).
* `PORT` env config ensures the app listens on 5006 by default.
* If your app uses build steps (e.g., transpilers), run them in the builder stage.

---

## 6. Running locally with Docker

### Build image

```bash
docker build -t yourhubusername/nodeapp:latest .
```

### Run container (map host 3000 → container 5006)

```bash
docker run -d --name nodeapp -p 3000:5006 yourhubusername/nodeapp:latest
```

### Verify logs

```bash
docker logs -f nodeapp
# Expect: "Listening on 5006" (or whatever your app prints)
```

### Test

```bash
curl http://localhost:3000
```

If the app returns HTML, the container is running correctly.

---

## 7. Deploying to AWS EC2 (Ubuntu) — step-by-step

### 7.1 Provision EC2

* Create an Ubuntu 22.04 LTS instance.
* Attach a key pair for SSH, configure Security Group: allow SSH (your IP), HTTP (80), HTTPS (443 optional), and any port you need for debugging (e.g., 3000) restricted or removed in production.

### 7.2 SSH into the instance

```bash
ssh -i yourkey.pem ubuntu@<EC2_PUBLIC_IP>
```

### 7.3 Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# logout and login again for new group to take effect, or run `newgrp docker`
```

### 7.4 Pull & run your image

If you pushed image to Docker Hub or a private registry:

```bash
docker pull yourhubusername/nodeapp:latest
docker run -d --name nodeapp -p 3000:5006 --restart unless-stopped yourhubusername/nodeapp:latest
```

If building on EC2 from source, clone repo and build:

```bash
git clone <repo-url>
cd repo
docker build -t nodeapp:latest .
docker run -d --name nodeapp -p 3000:5006 --restart unless-stopped nodeapp:latest
```

---

## 8. Nginx reverse-proxy configuration

Create a site configuration at `/etc/nginx/sites-available/nodeapp`:

```nginx
server {
    listen 80;
    server_name _; # replace '_' with your domain if available

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90;
    }
}
```

Enable it and reload nginx:

```bash
sudo ln -sf /etc/nginx/sites-available/nodeapp /etc/nginx/sites-enabled/nodeapp
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

### Explanation of important directives

* `proxy_pass`: forwards requests to the local Docker-mapped port.
* proxy headers: keep client IP and WebSocket compatibility.
* `proxy_read_timeout`: avoid premature timeouts for slow responses.

---

## 9. Systemd service for Docker container (auto-start)

To automatically manage the Docker container with systemd, create `/etc/systemd/system/nodeapp.service`:

```ini
[Unit]
Description=NodeApp Docker Container
After=docker.service
Requires=docker.service

[Service]
Restart=always
# If using a named container, use ExecStartPre to ensure old containers are removed
ExecStartPre=-/usr/bin/docker stop nodeapp
ExecStartPre=-/usr/bin/docker rm nodeapp
ExecStart=/usr/bin/docker run --name nodeapp -p 3000:5006 --restart no yourhubusername/nodeapp:latest
ExecStop=/usr/bin/docker stop nodeapp

[Install]
WantedBy=multi-user.target
```

Enable & start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now nodeapp.service
sudo systemctl status nodeapp.service
```

Notes:

* We use `Restart=always` and run the container directly via `ExecStart` to keep `systemd` aware of the process. Another approach is to use Docker Compose with `systemd` or rely on Docker’s `--restart unless-stopped` and not use systemd.

---

## 10. HTTPS with Let's Encrypt (Certbot)

If you have a domain pointing to your EC2 public IP, use Certbot to obtain TLS certs and auto-configure Nginx.

### Install Certbot

```bash
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### Obtain and install cert

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

Certbot will validate domain ownership and update the Nginx site to redirect HTTP → HTTPS. To test auto-renewal:

```bash
sudo certbot renew --dry-run
```

### Manual cert renewal scheduling (system cron)

Certbot sets up systemd timers or crons automatically on modern distros. Confirm `systemctl list-timers`.

---

## 11. CI/CD — Jenkins pipeline example

A simple Jenkins Declarative pipeline that builds, scans (optional), pushes to Docker Hub and deploys to EC2 using SSH.

> **NOTE:** for production use, replace plain-text credentials with Jenkins credentials store and use secure deployment mechanisms (Ansible, Terraform, or container registry + automated pull on the target).

```groovy
pipeline {
  agent any

  environment {
    SONAR_TOKEN = credentials('sonar-token')    // ensure this exists in Jenkins
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/shiva7919/nodejs-getting-started.git'
      }
    }

    stage('Install Dependencies') {
      agent {
        docker {
          image 'node:22'
          args  '-u root:root -v /root/.npm:/root/.npm'
        }
      }
      steps {
        sh '''
          set -eu
          echo "Running as: $(id -u):$(id -g) $(id -un 2>/dev/null || true)"
          echo "Node: $(node -v) / NPM: $(npm -v)"
          # Ensure clean install and avoid permission issues
          rm -rf node_modules || true
          if [ -f package-lock.json ]; then
            npm ci --no-audit --no-fund --unsafe-perm
          else
            npm install --no-audit --no-fund --unsafe-perm
          fi
          # Return ownership to Jenkins user so subsequent stages (non-root) can access files
          chown -R 1000:1000 .
        '''
      }
    }

    stage('SonarQube Analysis') {
      agent {
        docker { image 'sonarsource/sonar-scanner-cli:latest' }
      }
      steps {
        sh '''
          set -eu
          echo "Running SonarQube scanner..."
          sonar-scanner \
            -Dsonar.projectKey=nodeapp \
            -Dsonar.sources=. \
            -Dsonar.host.url=http://3.85.22.198:9000 \
            -Dsonar.login=${SONAR_TOKEN}
        '''
      }
    }

    stage('Prepare Artifact') {
      agent {
        docker { image 'node:22' }
      }
      steps {
        sh '''
          set -eu
          echo "Creating artifact (excluding .git and node_modules)..."
          TAR_TMP=/tmp/nodeapp-$$.tar.gz
          # create tar outside workspace to avoid reading the file being written
          tar --exclude='.git' --exclude='node_modules' -czf "${TAR_TMP}" .
          mv "${TAR_TMP}" ./nodeapp.tar.gz
          ls -lh nodeapp.tar.gz || true
        '''
      }
    }

    stage('Upload to Nexus') {
      agent {
        docker {
          image 'debian:12-slim'
          args  '-u root:root'   // run as root so apt-get works
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh '''
            set -eu
            apt-get update -y
            apt-get install -y --no-install-recommends curl ca-certificates
            echo "Uploading artifact to Nexus RAW repo..."

            ARTIFACT_NAME="nodeapp-$(date +%Y%m%d%H%M%S).tar.gz"
            UPLOAD_URL="http://3.85.22.198:8081/repository/nodejs/${ARTIFACT_NAME}"

            echo "Uploading to ${UPLOAD_URL}"
            curl -v -u "${NEXUS_USER}:${NEXUS_PASS}" --upload-file nodeapp.tar.gz "${UPLOAD_URL}"

            echo "Upload complete: ${ARTIFACT_NAME}"
          '''
        }
      }
    }

    stage('Build Docker Image') {
      agent {
        docker {
          image 'docker:24.0.5-cli'
          args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        sh '''
          set -eu
          echo "Building Docker image..."
          docker build -t shivasarla2398/nodeapp:latest .
        '''
      }
    }

    stage('Push Docker Image') {
      agent {
        docker {
          image 'docker:24.0.5-cli'
          args  '-u root:root -v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -eu
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push shivasarla2398/nodeapp:latest
          '''
        }
      }
    }

  } // stages

  post {
    always {
      echo "Pipeline finished!"
      sh 'ls -lh nodeapp.tar.gz || true'
    }
    success {
      echo "Pipeline succeeded."
    }
    failure {
      echo "Pipeline failed — check the failing stage output."
    }
  }
}
```

**Better approaches:** use an artifact registry, immutable tags, rolling updates, blue/green or canary deployments, and orchestration (Kubernetes or ECS) for complex workloads.

---

## 12. Docker Compose (optional)

For multi-service setups (e.g., app + redis + postgres), use docker-compose. Example `docker-compose.yml`:

```yaml
version: '3.8'
services:
  nodeapp:
    image: yourhubusername/nodeapp:latest
    ports:
      - "3000:5006"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
```

Run with `docker compose up -d`.

---

## 13. Security — AWS and OS hardening

### AWS Security Group recommendations

* SSH (22): restrict to your IP.
* HTTP (80) and HTTPS (443): allow 0.0.0.0/0 (public) if you intend to serve the site.
* Remove unnecessary open ports.

### Ubuntu hardening

* Keep packages updated (`sudo apt update && sudo apt upgrade -y`).
* Configure UFW firewall (simple example):

```bash
sudo apt install ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

* Use non-root users to run processes when possible.
* Don’t store secrets in images; use environment variables with secret management solutions.

---

## 14. Health checks & monitoring

* Add a simple `/health` route that returns 200 OK from your Node app.
* Nginx upstream health checks can be configured with `ngx_http_healthcheck_module` (third-party) or use external monitoring (CloudWatch, UptimeRobot, Pingdom).
* Log aggregation: forward stdout/stderr from Docker to a centralized system (ELK, Loki, CloudWatch).

---

## 15. Troubleshooting (common errors)

### 502 Bad Gateway

**Symptoms:** Nginx returns 502.
**Checks / Fixes:**

1. Is container running?

   ```bash
   docker ps
   ```
2. Is the app listening on the expected port inside container?

   ```bash
   docker exec -it nodeapp ss -ltnp || netstat -ltnp
   docker logs nodeapp
   ```
3. Is Nginx proxying to correct host/port? Open `/etc/nginx/sites-enabled/nodeapp` and confirm `proxy_pass http://127.0.0.1:3000;` matches the host port mapping.
4. Check Nginx error logs:

   ```bash
   sudo tail -n 200 /var/log/nginx/error.log
   ```

### Nginx default page still showing

* Remove the default site and reload Nginx:
  `sudo rm /etc/nginx/sites-enabled/default && sudo systemctl reload nginx`

### App works on host port but not via Nginx

* Check `proxy_set_header Host` and other headers.
* Check firewall / security group blocking port 80.

### Docker permission errors

* If you see permission denied for Docker, ensure user is in `docker` group or run with `sudo`.

### Certbot issues (rate limits, DNS)

* Ensure DNS A record resolves to the correct IP.
* If rate limits hit, read Let's Encrypt docs and use staging environment for testing: `--staging` flag.

---

## 16. FAQ

**Q: Why map host 3000 → container 5006 instead of 80 → 5006?**
A: Best practice is to let Nginx handle public ports (80/443) and map a non-privileged host port to the container to avoid directly exposing services and to allow multiple containers without port conflicts.

**Q: How to deploy multiple app instances?**
A: Use different host ports and update Nginx upstream configuration OR adopt Docker Swarm / Kubernetes / ECS for orchestration and load balancing.

**Q: Where to store secrets and environment variables?**
A: Use a secrets manager (AWS Secrets Manager, HashiCorp Vault) or ECS task definitions / Kubernetes secrets. Avoid baking secrets into images.

---

## 17. Useful Commands & References

### Docker

```bash
# Build
docker build -t nodeapp:latest .
# Run
docker run -d --name nodeapp -p 3000:5006 nodeapp:latest
# See logs
docker logs -f nodeapp
# Exec shell
docker exec -it nodeapp /bin/sh
```

### Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log
```

### Certbot

```bash
sudo certbot --nginx -d example.com
sudo certbot renew --dry-run
```

---

## Screenshots

(If your repo includes the screenshots linked at the top of this issue/PR, reference them here as visual aid.)

![screenshot-1](https://github.com/user-attachments/assets/3c85187a-ba1a-4980-a8bb-4cffa7bf5166)
<img width="1918" height="1079" alt="Screenshot 2025-11-19 141232" src="https://github.com/user-attachments/assets/b269dc5c-dce0-4bc2-8bb8-7c43be1bc95c" />
<img width="1917" height="1079" alt="Screenshot 2025-11-19 141212" src="https://github.com/user-attachments/assets/01530e62-ddaf-4c29-8048-51228125a6db" />
<img width="1919" height="1079" alt="Screenshot 2025-11-19 141327" src="https://github.com/user-attachments/assets/56e91766-0dc1-414e-b919-ba5a2ca9c88f" />


---

## Final notes & best practices

* Use immutable tags for Docker images (avoid `latest` in production); tag by CI build number or commit SHA.
* Automate security patching and backups.
* For scale or high availability, move beyond single EC2 instance: consider load balancer + auto-scaling group, or container services such as AWS ECS or EKS.

---

If you'd like, I can also:

* provide a ready-to-use `Jenkinsfile` with SSH deploy steps (with credentials placeholders),
* produce a `docker-compose.yml` for local development with volumes,
* convert the systemd unit to use docker-compose,
* or create an Ansible playbook to automate the entire EC2 provisioning & deployment.
