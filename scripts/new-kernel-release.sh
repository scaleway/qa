#!/bin/sh


# user input
kernel=$1


# variables
set -x
machine_name=$(echo $kernel | tr "/" "_")
hostname=$(echo $kernel | cut -d/ -f1)
user=$(echo $kernel | cut -d/ -f2)
repo=$(echo $kernel | cut -d/ -f3)
subdir=$(echo $kernel | cut -d/ -f4-)
tag=$(echo $subdir | tr / -)


# create build request on the repo
mkdir -p kernels/$kernel
pushd kernels/$kernel
git clean -fxd .
latest=$(ls | sort -n | tail -n 1)
latest=${latest:-0}
next_id=$(echo "$latest+1" | bc)
branch_name=build-kernel-$user-$repo_clean-$tag-$next_id
mkdir -p $next_id
touch $next_id/.build
git checkout -b $branch_name
git add $next_id/.build
git commit $next_id/.build -m "Trigger build of kernel $subdir rev$next_id :gun:"
git push -u origin $branch_name
git checkout master
