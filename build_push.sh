#!/usr/bin/env bash
# --------------------------------------------------------------------
# Build the Bash‑monitor image, push to Amazon ECR, and patch the
# k8s/daemonset.yaml so it points at the freshly‑pushed image.
#
# Defaults:
#   AWS Region …… value from `aws configure get region`  (fallback us‑east‑1)
#   ECR repo ……   current directory name
#   Tag …………       latest
#   Dockerfile …   collector/Dockerfile
#   Context ………    collector/
# --------------------------------------------------------------------
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-r AWS_REGION] [-n ECR_REPO_NAME] [-t IMAGE_TAG] [-d DOCKERFILE] [-c CONTEXT] [-m MANIFEST]
  -r   AWS region (default: from AWS CLI config or us-east-1)
  -n   ECR repository name (default: directory name)
  -t   Docker image tag       (default: latest)
  -d   Path to Dockerfile     (default: collector/Dockerfile)
  -c   Build context directory (default: collector)
  -m   DaemonSet manifest to patch (default: k8s/daemonset.yaml)
EOF
  exit 1
}

# ---- Defaults -------------------------------------------------------
REGION=""
REPO=""
TAG="latest"
DOCKERFILE="collector/Dockerfile"
CONTEXT="collector"
MANIFEST="k8s/daemonset.yaml"
# ---------------------------------------------------------------------

while getopts "r:n:t:d:c:m:h" opt; do
  case $opt in
    r) REGION="$OPTARG" ;;
    n) REPO="$OPTARG" ;;
    t) TAG="$OPTARG" ;;
    d) DOCKERFILE="$OPTARG" ;;
    c) CONTEXT="$OPTARG" ;;
    m) MANIFEST="$OPTARG" ;;
    h | *) usage ;;
  esac
done

# ---- Resolve defaults -----------------------------------------------
REGION=${REGION:-$(aws configure get region 2>/dev/null || echo "us-east-1")}
REPO=${REPO:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}
# ---------------------------------------------------------------------

AWS_ID=$(aws sts get-caller-identity --query Account --output text)
: "${AWS_ID:?Failed to obtain AWS account ID. Is AWS CLI configured?}"

ECR_URI="$AWS_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG"

echo "🛠️  Building Docker image $REPO:$TAG (Dockerfile: $DOCKERFILE)…"
docker build -t "$REPO:$TAG" -f "$DOCKERFILE" "$CONTEXT"

echo "📦  Ensuring ECR repo \"$REPO\" exists in $REGION…"
aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" \
  >/dev/null 2>&1 ||
  aws ecr create-repository --repository-name "$REPO" --image-scanning-configuration scanOnPush=true --region "$REGION" >/dev/null

echo "🔑  Logging into ECR…"
aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin "$AWS_ID.dkr.ecr.$REGION.amazonaws.com"

echo "🏷️   Tagging & pushing $ECR_URI…"
docker tag "$REPO:$TAG" "$ECR_URI"
docker push "$ECR_URI"

echo "✅  Image pushed successfully."

# ---- Patch manifest --------------------------------------------------
if [[ -f "$MANIFEST" ]]; then
  echo "📝  Patching $MANIFEST with new image URI…"
  if sed --version >/dev/null 2>&1; then # GNU sed
    sed -i -E "s|image: .*|image: $ECR_URI|" "$MANIFEST"
  else # BSD / macOS sed
    sed -i '' -E "s|image: .*|image: $ECR_URI|" "$MANIFEST"
  fi
  echo "✅  Manifest updated."
else
  echo "⚠️  Manifest $MANIFEST not found — skipped patch."
fi

echo "🚀  All done. Apply with:  kubectl apply -f $MANIFEST"
