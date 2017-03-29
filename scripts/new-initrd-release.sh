#!/bin/sh

cd `dirname $0`/..

# user input
initrd=${1:-github.com/scaleway/initrd}



# variables
set -x
machine_name=$(echo $initrd | tr "/" "_")
hostname=$(echo $initrd | cut -d/ -f1)
user=$(echo $initrd | cut -d/ -f2)
repo=$(echo $initrd | cut -d/ -f3)


# create build request on the repo
mkdir -p initrds/$initrd
pushd initrds/$initrd
git clean -fxd .
latest=$(ls | sort -n | tail -n 1)
latest=${latest:-0}
next_id=$(echo "$latest+1" | bc)
branch_name=build-initrd-$user-$repo-$next_id
mkdir -p $next_id
touch $next_id/.build
git branch -D $branch_name
git checkout -b $branch_name
git add $next_id/.build
git commit $next_id/.build -m "Trigger build of initrd rev$next_id :gun:"
git push $PUSH_OPTS -u origin $branch_name
git checkout master
