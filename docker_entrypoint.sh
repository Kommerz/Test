#!/bin/sh
# start filebeat from root container
./entrypoints/filebeat/docker_entrypoint.sh &

# start java-based application
java -Djava.security.egd=file:/dev/./urandom -jar /app.jar