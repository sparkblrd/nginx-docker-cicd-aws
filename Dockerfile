FROM nginxinc/nginx-unprivileged:1.27-alpine

ARG GIT_SHA=dev

LABEL org.opencontainers.image.title="nginx-docker-cicd-aws" \
      org.opencontainers.image.description="Simple Hello World web app served by Nginx" \
      org.opencontainers.image.revision="${GIT_SHA}"

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY app/ /usr/share/nginx/html/

USER root
RUN echo "${GIT_SHA}" > /usr/share/nginx/html/version.txt
USER 101

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1
