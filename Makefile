# =========================
# CONFIG
# =========================
GCP_PROJECT_ID := prj-1001-dev
GCP_REGION := asia-south1
GCP_ZONE := asia-south1-a

# Service Accounts
GCP_SA_RUNTIME := sa-dev-runtime@$(GCP_PROJECT_ID).iam.gserviceaccount.com
GCP_SA_INFRA   := sa-dev-infra@$(GCP_PROJECT_ID).iam.gserviceaccount.com

USER_EMAIL := beheradinabandhu50@gmail.com

IMAGE_NAME := fastapi-app
IMAGE_TAG  := v1
IMAGE_URI  := $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT_ID)/fastapi-repo/$(IMAGE_NAME):$(IMAGE_TAG)

SERVICE_NAME := fastapi-service
ARTIFACT_REPO := fastapi-repo


# =========================
# PHASE 0 — BOOTSTRAP (RUN ONCE)
# =========================

bootstrap:
	@echo "🔐 Bootstrapping IAM (RUN ONCE)"
	gcloud config unset auth/impersonate_service_account || true
	gcloud config set account $(USER_EMAIL)
	gcloud config set project $(GCP_PROJECT_ID)

	# Allow user to impersonate runtime SA
	gcloud iam service-accounts add-iam-policy-binding $(GCP_SA_RUNTIME) \
	  --member="user:$(USER_EMAIL)" \
	  --role="roles/iam.serviceAccountTokenCreator"

	# Allow user to impersonate infra SA
	gcloud iam service-accounts add-iam-policy-binding $(GCP_SA_INFRA) \
	  --member="user:$(USER_EMAIL)" \
	  --role="roles/iam.serviceAccountTokenCreator"

	@echo "❗ Bootstrap complete (run once per project)"


verify_bootstrap:
	@echo "🔍 Runtime SA policy"
	gcloud iam service-accounts get-iam-policy $(GCP_SA_RUNTIME)

	@echo "🔍 Infra SA policy"
	gcloud iam service-accounts get-iam-policy $(GCP_SA_INFRA)


# =========================
# PHASE 1 — INFRA CREATION (INFRA SA)
# =========================

create_artifact_repo:
	@echo "🏗️ Creating Artifact Registry repository (infra SA)"
	gcloud artifacts repositories create $(ARTIFACT_REPO) \
	  --repository-format=docker \
	  --location=$(GCP_REGION) \
	  --description="FastAPI Docker images" \
	  --impersonate-service-account=$(GCP_SA_INFRA)


# =========================
# PHASE 2 — DOCKER AUTH (RUN ONCE PER MACHINE)
# =========================

docker_auth:
	@echo "🐳 Configuring Docker (runtime SA)"
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev \
	  --impersonate-service-account=$(GCP_SA_RUNTIME)


# =========================
# PHASE 3 — DAILY DEV WORKFLOW (RUNTIME SA)
# =========================

login:
	@echo "👤 Logging in as user"
	gcloud auth login
	gcloud config set account $(USER_EMAIL)
	gcloud config set project $(GCP_PROJECT_ID)

docker_build:
	@echo "🔨 Building Docker image"
	docker build -t $(IMAGE_NAME) .

docker_tag:
	@echo "🏷️ Tagging Docker image"
	docker tag $(IMAGE_NAME) $(IMAGE_URI)

docker_push: docker_tag
	@echo "📤 Pushing Docker image"
	docker push $(IMAGE_URI)

docker_build_push: docker_build docker_push
	@echo "✅ Docker image built & pushed"


# =========================
# PHASE 4 — DEPLOYMENT (RUNTIME SA)
# =========================

deploy:
	@echo "🚀 Deploying to Cloud Run"
	gcloud run deploy $(SERVICE_NAME) \
	  --image=$(IMAGE_URI) \
	  --region=$(GCP_REGION) \
	  --platform=managed \
	  --allow-unauthenticated \
	  --port=8080 \
	  --impersonate-service-account=$(GCP_SA_RUNTIME)


# =========================
# SAFETY / DEBUG
# =========================

whoami:
	@echo "🔍 Active identity & config"
	gcloud auth list
	gcloud config list

reset_auth:
	@echo "🧼 Resetting gcloud auth state"
	gcloud config unset auth/impersonate_service_account || true
	gcloud config set account $(USER_EMAIL)


# =========================
# CLEANUP / DESTROY (INFRA SA)
# =========================

destroy_cloudrun:
	@echo "🗑 Deleting Cloud Run service (infra SA)"
	gcloud run services delete $(SERVICE_NAME) \
	  --region=$(GCP_REGION) \
	  --platform=managed \
	  --quiet \
	  --impersonate-service-account=$(GCP_SA_INFRA)

destroy_image:
	@echo "🗑 Deleting container image (infra SA)"
	gcloud artifacts docker images delete $(IMAGE_URI) \
	  --quiet \
	  --impersonate-service-account=$(GCP_SA_INFRA)

destroy_artifact_repo:
	@echo "🗑 Deleting Artifact Registry repository (infra SA)"
	gcloud artifacts repositories delete $(ARTIFACT_REPO) \
	  --location=$(GCP_REGION) \
	  --quiet \
	  --impersonate-service-account=$(GCP_SA_INFRA)

destroy_all: destroy_cloudrun destroy_image
	@echo "🔥 Application resources destroyed"

destroy_all_infra: destroy_all destroy_artifact_repo
	@echo "🔥🔥 ALL infra destroyed (use carefully)"


# =========================
# 🏆 REMEMBER ONLY ONE THING
# =========================
# User = grant permissions
# Runtime SA = app lifecycle
# Infra SA = infra lifecycle
# Impersonation = safe bridge
