# Cloud run deployment

## Prerequisites Checklist
```sh
gcloud version
gcloud auth list
gcloud config list

```

## Enable Required GCP Services
```sh
# Run once per project:
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com
```

## Create Artifact Registry (Docker Repo)
```sh
# Why?
# Artifact Registry = private Docker Hub inside GCP
# Create repo:
gcloud artifacts repositories create fastapi-repo \
  --repository-format=docker \
  --location=asia-south1 \
  --description="FastAPI Docker images"

# Verify:
gcloud artifacts repositories list
```

## Create a Dedicated Deployment Service Account
```sh
# Why not use your personal account?
# Because:
# Auditable
# Secure
# Industry standard
# Required for CI/CD later
# Create Service Account:
gcloud iam service-accounts create sa-dev \
  --display-name "FastAPI Cloud Run Deployer"

# Service account email:
sa-dev@PROJECT_ID.iam.gserviceaccount.com
```

## Assign IAM Roles (CRITICAL)
| Task              | Role                            |
| ----------------- | ------------------------------- |
| Push image        | `roles/artifactregistry.writer` |
| Deploy Cloud Run  | `roles/run.admin`               |
| Act as runtime SA | `roles/iam.serviceAccountUser`  |

```sh
# Assign roles:
PROJECT_ID=$(gcloud config get-value project)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:sa-dev@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:sa-dev@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:sa-dev@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

## Allow YOU to Impersonate This Service Account
```sh
# Why?
# You don’t create keys.
# You temporarily impersonate.
# Grant impersonation permission:

gcloud iam service-accounts add-iam-policy-binding \
  sa-dev@$PROJECT_ID.iam.gserviceaccount.com \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/iam.serviceAccountTokenCreator"

```

## Configure Docker Authentication (IMPERSONATED)
```sh
gcloud auth configure-docker asia-south1-docker.pkg.dev \
  --impersonate-service-account=sa-dev@$PROJECT_ID.iam.gserviceaccount.com

# Now Docker pushes as the service account
```

## Build Docker Image (Locally)
```sh
docker build -t fastapi-app .
```

## Tag Image for Artifact Registry
```sh
# Format:
LOCATION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:TAG

docker tag fastapi-app \
asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1

```

## Push Image (IMPERSONATED)
```sh
docker push asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1
```

## Deploy to Cloud Run (IMPERSONATED)
```sh
gcloud run deploy fastapi-service \
  --image=asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1 \
  --region=asia-south1 \
  --platform=managed \
  --allow-unauthenticated \
  --port=8080 \
  --impersonate-service-account=sa-dev@$PROJECT_ID.iam.gserviceaccount.com

```

## Test Deployment
```sh
gcloud run services list
```


## 🔐 Security Best Practices (Industry)
✔ DO

- Use service account impersonation
- Use separate deployer SA
- Push only to Artifact Registry
- Restrict IAM roles

❌ DON’T

- Create service account keys
- Use Owner role
- Push images to Docker Hub for prod


## Best practices
### PHASE 0 — One-Time Bootstrap (DO THIS ONCE PER MACHINE)

This is non-negotiable and must be done without impersonation.

```sh
# 0.1 Ensure user identity
gcloud config unset auth/impersonate_service_account
gcloud config set account beheradinabandhu50@gmail.com
gcloud config set project prj-1001-dev
# 0.2 Allow user → impersonate service account (ONE TIME)
make gcp_allow_impersonate
# verify
gcloud iam service-accounts get-iam-policy sa-dev@prj-1001-dev.iam.gserviceaccount.com
# 0.3 Configure Docker credential helper (ONE TIME)
gcloud auth configure-docker asia-south1-docker.pkg.dev \
  --impersonate-service-account=sa-dev@prj-1001-dev.iam.gserviceaccount.com

# ✅ This writes to ~/.docker/config.json
# ❗ You do NOT need to redo this every time.
```

### PHASE 1 — Daily Developer Workflow (SAFE ORDER)

This is what you should do every day.

```sh
# 1.1 Login + set project (USER only)
make gcp_login
make set_project
# ❗ Do NOT impersonate yet.

# 1.2 Build & Push Docker Image (Docker uses helper)
make docker_build_push

# 1.3 Deploy to Cloud Run (Flag-based impersonation)
make deploy_app

# 1.4 (Optional but Recommended) Reset State
make gcp_unimpersonate

```

## Guide to use Makefile

### Mental Model
```sh
Your Gmail / Corp User
        │
        │ (iam.serviceAccountTokenCreator)
        ▼
   sa-dev@PROJECT_ID.iam.gserviceaccount.com
        │
        │ (run.admin, artifactregistry.writer, etc.)
        ▼
   Cloud Run / Artifact Registry
```

### 🟦 ONE-TIME SETUP (VERY IMPORTANT)
```sh
# Run once per project per machine:
make bootstrap
make verify_bootstrap
make docker_auth

# ✔ Grants impersonation permission
# ✔ Configures Docker helper
# ✔ Never redo unless machine is reset
```

### 🟩 DAILY DEVELOPMENT FLOW (SAFE)
```sh
# Every time you want to deploy:
make login
make docker_build_push
make deploy
# ✔ No global impersonation
# ✔ No IAM chicken-and-egg
# ✔ Deterministic & safe
```

### 🟥 IF YOU EVER GET STUCK
```sh
make whoami
make reset_auth
# Then restart daily flow.
```
