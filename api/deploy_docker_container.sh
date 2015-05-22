#!/bin/bash

LOCK="/var/lock/docker.lock"
LOG="/var/log/docker.log"
START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
APP_HOME="/root/fluentapi"

exec 1>>${LOG} 2>&1
echo "Docker Deployment Script | START: ($START_TIME)"

if [ -f "$LOCK" ]
then
    if [ `find "$LOCK" -mmin +60` ]
      then
        echo "$LOCK file is more than 60minutes old, overriding and continue..."
      else
        echo "$LOCK file exists, exiting..."
        quit
    fi
fi

echo "Creating $LOCK file..."
touch $LOCK


# Setup our swap / container variables. First, check and see which image is current (1 or 2).
if docker images | grep -q "app_swap_image_1"; then
    CURRENT_SWAP_IMAGE="app_swap_image_1"
    CURRENT_SWAP_CONT="app_swap_cont_1"
    NEXT_SWAP_IMAGE="app_swap_image_2"
    NEXT_SWAP_CONT="app_swap_cont_2"
else
    CURRENT_SWAP_IMAGE="app_swap_image_2"
    CURRENT_SWAP_CONT="app_swap_cont_2"
    NEXT_SWAP_IMAGE="app_swap_image_1"
    NEXT_SWAP_CONT="app_swap_cont_1"
fi

echo ""
echo "current swap image:     $CURRENT_SWAP_IMAGE"
echo "current swap container: $CURRENT_SWAP_CONT"
echo ""
echo "next swap image:        $NEXT_SWAP_IMAGE"
echo "next swap container:    $NEXT_SWAP_CONT"
echo ""

# Function to start the container if there are changes in git repo or no containers are running
function startContainer {
    echo "there are no running containers, need to start the one..."
    if docker images | grep -q "$CURRENT_SWAP_IMAGE";then
       echo "image exists, proceeding to start..."
     else
       echo "image $CURRENT_SWAP_IMAGE doesn't exist, need to build the one..."
       cd $APP_HOME

       echo ""
       echo "building the swap image: $CURRENT_SWAP_IMAGE"
       echo ""
       npm install -g bower
       bower --allow-root install
       npm install
       docker build -t $CURRENT_SWAP_IMAGE .
    fi
    echo "starting new container based on $CURRENT_SWAP_IMAGE..."
    docker run --name $CURRENT_SWAP_CONT -p 3000:3000 --net=host -d -t $CURRENT_SWAP_IMAGE
}


function noChangeNeeded {
    echo "deployment is up-to-date, current HEAD:"
    git log -1
}

# Function that carries out an actual deployment if needed
function update {
    echo "deployment is needed, starting..."
    echo "current HEAD:"
    git log -1
    git pull
    echo "new HEAD:"
    git log -1

    #Build new docker image
    cd $APP_HOME

    echo ""
    echo "building next swap image: $NEXT_SWAP_IMAGE"
    echo ""
    npm install -g bower
    bower --allow-root install
    npm install
    docker build -t $NEXT_SWAP_IMAGE .

    echo ""
    echo "stopping current container: $CURRENT_SWAP_CONT"
    echo ""
    docker stop $CURRENT_SWAP_CONT

    echo ""
    echo "running next image: $NEXT_SWAP_IMAGE in container: $NEXT_SWAP_CONT"
    echo ""
    docker run --name $NEXT_SWAP_CONT -p 3000:3000 --net=host -d -t $NEXT_SWAP_IMAGE

    #Cleanup old image and container to free space
    echo ""
    echo "cleaning up previous swap container: $CURRENT_SWAP_CONT"
    echo ""
    docker rm $CURRENT_SWAP_CONT

    echo ""
    echo "cleaning up previous swap image: $CURRENT_SWAP_IMAGE"
    echo ""
    docker rmi $CURRENT_SWAP_IMAGE
}

# Change to the app locally cloned repo's folder
cd $APP_HOME

# Check to see if we're in sync with remote master
git fetch origin
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base @ @{u})

if [ $LOCAL = $REMOTE ]; then
    noChangeNeeded
elif [ $LOCAL = $BASE ]; then
    update
elif [ $REMOTE = $BASE ]; then
    echo "ERROR: local change on server detected"
else
    echo "ERROR: repo diverged"
fi

if [ `docker ps|wc -l` -eq 1 ]
then 
   startContainer
fi

END_TIME=$(date "+%Y-%m-%d %H:%M:%S")
echo ""
echo "Deployment Script | END: ($END_TIME)"
rm -rf $LOCK
