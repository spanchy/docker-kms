# Saving 11notes depencies
FROM alpine/git AS build
ARG APP_VERSION=next
ARG BUILD_SRC=https://github.com/11notes/fork-py-kms.git
ARG BUILD_ROOT=/git/fork-py-kms

RUN set -ex; \
    git clone --branch "${APP_VERSION}" --depth 1 "${BUILD_SRC}" "${BUILD_ROOT}"

# Using official python image
FROM python:3.13-slim

# default arguments
ARG APP_IMAGE
ARG APP_NAME
ARG APP_VERSION
ARG APP_ROOT=/app
ARG APP_UID=1000
ARG APP_GID=1000

# environment
ENV APP_IMAGE=${APP_IMAGE} \
    APP_NAME=${APP_NAME} \
    APP_VERSION=${APP_VERSION} \
    APP_ROOT=${APP_ROOT} \
    KMS_ADDRESS=:: \
    KMS_PORT=1688 \
    KMS_LOCALE=1033 \
    KMS_ACTIVATIONINTERVAL=120 \
    KMS_RENEWALINTERVAL=259200 \
    PIP_ROOT_USER_ACTION=ignore \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# install system deps
RUN set -ex; \
    apt-get update && apt-get install -y --no-install-recommends \
      tini \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# copy sources from build
COPY --from=build /git/fork-py-kms/py-kms /opt/py-kms

# :: install python dependencies
WORKDIR /opt/py-kms
RUN set -ex; \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi; \
    pip install pytz

# create app directories and user
RUN set -ex; \
    mkdir -p ${APP_ROOT}/var; \
    groupadd -g ${APP_GID} kmsgroup; \
    useradd -u ${APP_UID} -g ${APP_GID} -d ${APP_ROOT} -s /bin/sh kmsuser; \
    chown -R kmsuser:kmsgroup ${APP_ROOT} /opt/py-kms

# copy root filesystem
COPY ./rootfs /
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN chown kmsuser:kmsgroup /usr/local/bin/entrypoint.sh

# volumes and healthcheck
VOLUME ["${APP_ROOT}/var"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD nc -z localhost 1688 || exit 1

# entrypoint
USER kmsuser
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
