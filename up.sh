#!/bin/bash

if [ ! $1 ]; then
    echo "Missing expected argument 'private key name'"
    exit 1
fi

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

    # Build docker images
    # 'DOCKER_BUILDKIT=1' tells the docker daemon to activate experimental features.
    # Needed to enable the '--ssh' argument, which allows passing the location of the
    # private key needed to authenticate at the private GitLab repository to the docker
    # daemon, which will temporaly mount the respective file to be available during
    # the build process.
    # (More info at: https://sanderknape.com/2019/06/installing-private-git-repositories-npm-install-docker/)docker
    DOCKER_BUILDKIT=1 docker build --ssh gitlab="$HOME/.ssh/$1" -t $repo_name .

    # Go back to 'work_dir'
    cd $work_dir
    pwd
done <repositories.conf

echo "All containers up to date"
echo "Launch platform"

docker-compose up -d
