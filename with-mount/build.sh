#!/bin/bash

docker build -t registry.lvgvspe.com.br/navidrome-rclone-mount:latest . && \
docker push registry.lvgvspe.com.br/navidrome-rclone-mount:latest