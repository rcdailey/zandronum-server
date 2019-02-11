#!/usr/bin/env bash
set -ex

# $1    :: Repository URL
# $2    :: Repository Tag
# $3+   :: One or more tags

docker build \
    --build-arg REPO_URL="$1" \
    --build-arg REPO_TAG="$2" \
    --tag temp:temp \
    .

for tag in "${@:3}"; do
    final_tag="rcdailey/zandronum-server:$tag"
    docker tag temp:temp "$final_tag"
    test -n "$ALL_TAGS" && ALL_TAGS+=","
    ALL_TAGS+="$final_tag"
done
