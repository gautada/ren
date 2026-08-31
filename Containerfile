FROM docker.io/gautada/pi:0.84.4

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
    openssh-client gh \
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
# │ CONFIG             │
# ╰――――――――――――――――――――╯
RUN mkdir -p /home/${USER}/.kube
WORKDIR /home/${USER}/.kube
RUN ln -fsv /mnt/volumes/data/kube.config ./config

