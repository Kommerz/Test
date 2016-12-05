FROM nexus.itgo-devops.org:18444/admin/alpine-java-8-filebeat:4

VOLUME /tmp

ADD pet-clinic-v3-0.8.0.jar app.jar
RUN sh -c 'touch /app.jar'

COPY docker_entrypoint.sh /docker_entrypoint.sh
RUN chmod +x docker_entrypoint.sh

ENTRYPOINT  ["/docker_entrypoint.sh"]