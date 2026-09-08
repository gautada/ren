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


FROM docker.io/gautada/debian:${DEBIAN_VERSION} AS SKILLS

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get upgrade --yes \
 && apt-get install --yes --no-install-recommends \
            git golang-go \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt
RUN git clone --depth 1 https://github.com/leunguu/pi-agent-config \
 && git clone --depth 1 https://github.com/badlogic/pi-skills \
 && git clone --depth 1 https://github.com/mattpocock/skills mattpocock-skills

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
# │ SKILLS             │
# ╰――――――――――――――――――――╯
# Bake skills into ~/.agents/skills — a global pi skill location that is NOT
# shadowed by the /mnt/volumes/data mount (unlike ~/.pi/agent/skills, which is
# a symlink into the volume). Makes these skills a permanent part of the image.
RUN mkdir -p /home/${USER}/.agents/skills
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/pi-agent-config/skills/pi-skill-developer \
     /home/${USER}/.agents/skills/pi-skill-developer
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/mattpocock-skills/skills/wayfinder \
     /home/${USER}/.agents/skills/wayfinder
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/mattpocock-skills/skills/engineering/research \
     /home/${USER}/.agents/skills/research
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/mattpocock-skills/skills/engineering/diagnosing-bugs \
     /home/${USER}/.agents/skills/diagnosing-bugs
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/mattpocock-skills/skills/productivity/writing-for-agents \
     /home/${USER}/.agents/skills/writing-for-agents
COPY --from=SKILLS --chown=${USER}:${USER} \
     /opt/mattpocock-skills/skills/productivity/handoff \
     /home/${USER}/.agents/skills/handoff

# ╭――――――――――――――――――――╮
# │ CONFIG             │
# ╰――――――――――――――――――――╯
RUN mkdir -p /home/${USER}/.kube
WORKDIR /home/${USER}/.kube
RUN ln -fsv /mnt/volumes/data/kube.config ./config \
 && mkdir -p /home/${USER}/.ssh
WORKDIR /home/${USER}/.ssh
RUN ln -fsv /mnt/volumes/secrets/.ssh_config config
WORKDIR /home/${USER}
RUN ln -fsv /mnt/volumes/configuration/.gitconfig .gitconfig \
 && ln -fsv /mnt/volumes/configuration/.cfinventory .cfinventory
WORKDIR /home/${USER}
RUN chown -R ${USER}:${USER} /home/${USER}


