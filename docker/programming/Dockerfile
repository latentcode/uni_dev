FROM ubuntu:24.04

ARG DEV_UID=1000
ARG DEV_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        gdb \
        git \
        lldb \
        make \
        ninja-build \
        pkg-config \
        python-is-python3 \
        python3 \
        python3-pip \
        python3-venv \
        valgrind \
    && rm -rf /var/lib/apt/lists/* \
    && set -eux; \
       if getent group "${DEV_GID}" >/dev/null; then \
           dev_group="$(getent group "${DEV_GID}" | cut -d: -f1)"; \
       else \
           dev_group=student; \
           groupadd --gid "${DEV_GID}" "${dev_group}"; \
       fi; \
       if getent passwd "${DEV_UID}" >/dev/null; then \
           existing_user="$(getent passwd "${DEV_UID}" | cut -d: -f1)"; \
           if [ "${existing_user}" != student ]; then \
               usermod --login student --home /home/student --move-home "${existing_user}"; \
           fi; \
           usermod --shell /bin/bash --gid "${dev_group}" student; \
       else \
           useradd --create-home --shell /bin/bash --uid "${DEV_UID}" --gid "${dev_group}" student; \
       fi; \
       install -d -o student -g "${dev_group}" /home/student/.venvs

USER student
WORKDIR /workspace/classes

ENV PATH=/home/student/.local/bin:${PATH}

EXPOSE 8000

CMD ["sleep", "infinity"]
