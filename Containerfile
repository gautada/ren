ARG DEBIAN_VERSION=13.6
ARG PI_VERSION=0.84.4

FROM docker.io/gautada/debian:${DEBIAN_VERSION} AS BUILD

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install --yes --no-install-recommends \
            git golang-go \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# flarectl: Cloudflare CLI, from the legacy v0.x line of cloudflare-go
# (the current v7.x line is a full SDK rewrite that dropped cmd/flarectl).
# https://github.com/cloudflare/cloudflare-go/tree/master/cmd/flarectl
ARG FLARECTL_VERSION=v0.118.0
WORKDIR /opt
RUN git clone --branch ${FLARECTL_VERSION} --depth 1 https://github.com/cloudflare/cloudflare-go
WORKDIR /opt/cloudflare-go/cmd/flarectl
RUN go build -o /opt/flarectl .

FROM docker.io/gautada/pi:${PI_VERSION}

# ╭――――――――――――――――――╮
# │ METADATA         │
# ╰――――――――――――――――――╯
LABEL org.opencontainers.image.title="ren"
LABEL org.opencontainers.image.description="A specific pi agent harness: Ren Nakatomi - Infrastrucutre Architect."
LABEL org.opencontainers.image.url="https://hub.docker.com/r/gautada/ren"
LABEL org.opencontainers.image.source="https://github.com/gautada/ren"
LABEL org.opencontainers.image.license="Liscense"

# ╭――――――――――――――――――╮
# │ PACKAGES         │
# ╰――――――――――――――――――╯
# hadolint ignore=DL3016
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install -y --no-install-recommends kubectl skopeo \
    openssh-client gh ansible \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# Rename the base user to this container user.
# Follows the same pattern as other gautada containers.
ARG USER=ren
RUN /usr/sbin/usermod -l $USER slice \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER slice \
 && PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)" \
 && printf '%s:%s\n' "$USER" "$PASSWORD" | /usr/sbin/chpasswd

# ╭――――――――――――――――――――╮
# │ APPLICATION        │
# ╰――――――――――――――――――――╯
COPY --from=BUILD /opt/flarectl /usr/local/bin/flarectl

# ╭――――――――――――――――――――╮
# │ CONFIG             │
# ╰――――――――――――――――――――╯
RUN mkdir -p /home/${USER}/.kube
WORKDIR /home/${USER}/.kube
RUN ln -fsv /mnt/volumes/data/kube.config ./config
WORKDIR /home/${USER}
RUN ln -fsv /mnt/volumes/configuration/.gitconfig .gitconfig \
 && ln -fsv /mnt/volumes/configuration/.cfinventory .cfinventory
WORKDIR /home/${USER}
RUN chown -R ${USER}:${USER} /home/${USER}
