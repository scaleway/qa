#!/bin/sh


# user input
image=$1


# variables
set -x
machine_name=$(echo $image | tr "/" "_")
hostname=$(echo $image | cut -d/ -f1)
user=$(echo $image | cut -d/ -f2)
repo=$(echo $image | cut -d/ -f3)
subdir=$(echo $image | cut -d/ -f4-)
repo_clean=$(echo $repo | sed 's/^scaleway-//;s/^image-//')
tag=$(echo $subdir | tr / -)
docker_name=$user/$repo_clean:$tag


# create build request on the repo
mkdir -p images/$image
pushd images/$image
git clean -fxd .
latest=$(ls | sort -n | tail -n 1)
latest=${latest:-0}
next_id=$(echo "$latest+1" | bc)
branch_name=build-image-$user-$repo_clean-$tag-$next_id
mkdir -p $next_id
touch $next_id/.build
git branch -D $branch_name
git checkout -b $branch_name
git add $next_id/.build
git commit $next_id/.build -m "Trigger build of $docker_name rev$next_id :gun:"
git push $PUSH_OPTS -u origin $branch_name
git checkout master
