#!/usr/bin/env bash

IMAGE_NAME="glbio-shiny"
IMAGE_TAG="latest"
IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

DAEMONIZE=0

echo "* Building image ${IMAGE} and then running it..."

docker build -t ${IMAGE} ./app && \
docker run --init --rm \
    --name ${IMAGE_NAME} \
    -p 3838:3838 \
    -v "$PWD/services/shiny-server/shiny-server.conf:/etc/shiny-server/shiny-server.conf" \
    -v "$PWD/app/:/srv/shiny-server/app/" \
    $( [[ ${DAEMONIZE} -eq 1 ]] && echo ' -d ' || echo '' ) \
    ${IMAGE} && \
(
    if [[ ${DAEMONIZE} -eq 1 ]]; then
        echo "Your application is now running in the background!"
        echo "Open your browser to http://localhost:5000 to view it"
        echo "When you want to kill the app, run `docker rm --force ${IMAGE_NAME}`"
    fi
)
