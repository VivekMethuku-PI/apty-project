# Environment Banner

One static page that shows Dev or Prod. Same template, two paths: Terraform on AWS (S3 + CloudFront) and Helm on Docker Desktop Kubernetes. The environment name comes from a Terraform variable or a Helm value, not from a copied page.

## Live URLs

Dev: https://d256ge7kfuz3m5.cloudfront.net

Prod: https://d2w32b0ev6bl6b.cloudfront.net

Leave them up until you hear back. Destroy with:

```bash
terraform -chdir=terraform/envs/dev destroy
terraform -chdir=terraform/envs/prod destroy
```

## Prerequisites

Terraform 1.5 or newer, AWS credentials (S3, CloudFront, DynamoDB), Docker Desktop with Kubernetes enabled, Helm 3, kubectl.

## Remote state

Terraform cannot store state in a bucket that does not exist yet. terraform/tfstate is a separate root with local state. It creates the S3 state bucket and DynamoDB lock table. Do not commit its .tfstate file.

```bash
terraform -chdir=terraform/tfstate init
terraform -chdir=terraform/tfstate apply
terraform -chdir=terraform/tfstate output -raw backend_hcl \
  | tee terraform/envs/dev/backend.hcl terraform/envs/prod/backend.hcl
```

backend.hcl is gitignored. CI reads the same values from repo Variables.

## Terraform (S3 + CloudFront)

Dev and Prod call terraform/modules/static-site. The module uploads app/index.html.tmpl after replacing __ENVIRONMENT__. The bucket is private. CloudFront reads it through Origin Access Control.

```bash
cd terraform/envs/dev
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../..
terraform validate
terraform plan
terraform apply
terraform output cloudfront_url
```

Prod is the same in terraform/envs/prod (environment defaults to Prod).

## Docker + Helm

Same template. The container script replaces __ENVIRONMENT__ from a ConfigMap. Changing the Helm value does not rebuild the image.

```bash
kubectl config use-context docker-desktop
docker build -t environment-banner:local ./app
helm install banner ./charts/environment-banner --set environment=Dev
kubectl port-forward svc/banner 8080:80
```

Open http://localhost:8080

```bash
helm upgrade banner ./charts/environment-banner --set environment=Prod --reuse-values
```

The chart has a Deployment, Service, and ConfigMap, plus CPU/memory requests and limits and an HTTP readiness probe on /.

## GitHub Actions

On every PR and every push to main, .github/workflows/ci.yml runs terraform fmt -check, validate, and plan for dev and prod. The job fails on fmt or plan errors.

Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

Variables: TF_STATE_BUCKET=apty-env-banner-tfstate-053640723543, TF_LOCK_TABLE=apty-env-banner-tf-lock

Credentials are never committed.

## Trade-offs

One HTML template with two injectors (Terraform replace, container sed plus a Helm ConfigMap) keeps AWS and Kubernetes on the same page. Separate dev/prod roots with separate state keys beat workspaces so an apply cannot hit the wrong env. terraform/tfstate stays local-state because that chicken-and-egg is real. With more time: CloudFront invalidation on content change, GitHub OIDC instead of long-lived keys, and an apply job gated on main.
