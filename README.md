# Environment Banner

One static page that shows `Dev` or `Prod`. Same template, two delivery paths: **S3 + CloudFront (Terraform)** and **nginx on Docker Desktop Kubernetes (Helm)**. The environment string is a Terraform variable / Helm value — never a copied page per env.

## Live URL

**Dev:** https://d256ge7kfuz3m5.cloudfront.net

Leave it up until you hear back. Tear down with `terraform -chdir=terraform/envs/dev destroy`.

## Prerequisites

Terraform `>= 1.5`, AWS credentials (S3, CloudFront, DynamoDB), Docker Desktop with Kubernetes enabled, Helm 3, `kubectl`.

## 0. Remote state (`tfstate`)

Terraform cannot store state in a bucket that does not exist yet. `terraform/tfstate` is a separate root with **local** state. It creates the versioned S3 bucket and DynamoDB lock table. Do not commit its `.tfstate`.

```bash
terraform -chdir=terraform/tfstate init
terraform -chdir=terraform/tfstate apply
terraform -chdir=terraform/tfstate output -raw backend_hcl \
  | tee terraform/envs/dev/backend.hcl terraform/envs/prod/backend.hcl
```

`backend.hcl` is gitignored. CI uses the same values as repo Variables.

## 1. Terraform (S3 + CloudFront)

Dev and Prod are thin callers of `terraform/modules/static-site`. The module uploads `app/index.html.tmpl` after substituting `__ENVIRONMENT__`. The bucket is private; CloudFront reads it through Origin Access Control.

```bash
cd terraform/envs/dev
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../..
terraform validate
terraform plan
terraform apply
terraform output cloudfront_url
```

Prod is `terraform/envs/prod` with `environment = "Prod"`.

```bash
terraform -chdir=terraform/envs/dev destroy
```

The state bucket is versioned and has no `force_destroy` — empty object versions by hand if you ever destroy `terraform/tfstate`.

## 2. Docker + Helm (Docker Desktop Kubernetes)

Same template. The container entrypoint substitutes `__ENVIRONMENT__` from a ConfigMap. `--set environment=Prod` does not rebuild the image.

```bash
kubectl config use-context docker-desktop
docker build -t environment-banner:local ./app

helm lint ./charts/environment-banner
helm install banner ./charts/environment-banner --set environment=Dev

kubectl port-forward svc/banner 8080:80
# http://localhost:8080  → Dev

helm upgrade banner ./charts/environment-banner --set environment=Prod --reuse-values
```

The chart is a Deployment + Service + ConfigMap, with CPU/memory requests/limits and an HTTP readiness probe on `/`.

## 3. GitHub Actions

On every PR and every push to `main`, `.github/workflows/ci.yml` runs `terraform fmt -check`, `validate`, and `plan` for **dev** and **prod**. The job fails on fmt or plan errors.

**Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`  
**Variables:** `TF_STATE_BUCKET=apty-env-banner-tfstate-053640723543`, `TF_LOCK_TABLE=apty-env-banner-tf-lock`

Credentials are never committed.

## Trade-offs

One HTML template with two injectors (Terraform `replace`, container `sed` + Helm ConfigMap) keeps AWS and Kubernetes honest about “the same page.” Separate `dev`/`prod` roots with separate state keys beat workspaces so an apply cannot hit the wrong env. `terraform/tfstate` stays local-state — that chicken-and-egg is real; pretending otherwise is worse. With more time: CloudFront invalidation on content change, GitHub OIDC instead of long-lived keys, and an apply job gated on `main`.
