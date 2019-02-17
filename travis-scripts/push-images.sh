#!/usr/bin/env bash
set -ex

image_name='rcdailey/zandronum-server'
ALL_TAGS="$(docker image ls | grep "$image_name" | tr -s ' ' | cut -d ' ' -f 2)"

# Push all tags
echo "$DOCKER_HUB_PASSWORD" | docker login -u "$DOCKER_HUB_USERNAME" --password-stdin
while read -r tag; do
    docker push "$image_name:$tag"
done <<< "$ALL_TAGS"
