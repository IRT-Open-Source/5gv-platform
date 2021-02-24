#!/bin/bash

work_dir=$(pwd)
echo $work_dir

# For all reporitories specified in 'repositories.conf'
while read -r repo_url; do

    echo

    # Extract repository name from repository url
    repo_name=$(echo $repo_url | grep -oP '(?<=\/)(.*)(?=\.git)')
    echo ">>> $repo_name"

    # If directory not exists: clone repository, else: pull updates
    if [ ! -d "../$repo_name" ]; then
        echo "Cloning ${repo_name} from ${repo_url}"
        git clone $repo_url "../$repo_name"
        cd "../$repo_name"
        pwd
    else
        echo "Pull updates for ${repo_name}"
        cd "../$repo_name"
        pwd
        git pull
    fi

    # Remove potentially existing containers and respective images
    echo "Stopping potentially running Docker containers"
    docker container stop $repo_name
    echo "Removing potentially running Docker containers"
    docker rm $repo_name
    echo "Removing potentially running Docker images"
    docker rmi $repo_name

    docker build -t $repo_name .

    # Go back to 'work_dir'
    cd $work_dir
    pwd
done <repositories.conf

echo "All containers up to date"
echo "Launch platform"

docker-compose up -d
