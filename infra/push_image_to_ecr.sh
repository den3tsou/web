set -e
set -u
set -x
set -o pipefail

# TAG=$(git rev-parse HEAD)
TAG="1"
REPO="140023405475.dkr.ecr.ap-southeast-2.amazonaws.com/web/web"

aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $REPO
docker build --platform linux/arm64 -f ../app/Dockerfile -t $REPO:$TAG ../app/
docker push $REPO:$TAG

