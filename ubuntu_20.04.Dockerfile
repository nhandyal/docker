FROM ubuntu:20.04

ARG GROUP_NAME=staff
ARG GROUP_ID=20
ARG USER_NAME=nrh
ARG USER_ID=501

ARG NODE_MAJOR=20


# https://serverfault.com/a/1016972 to ensure installing tzdata does not
# result in a prompt that hangs forever.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC


#######
# Install system packages
RUN apt-get update -y && apt-get install -y \
    ca-certificates coreutils curl \
    g++ gcc git gnupg \
    libffi-dev libssl-dev \
    openssh-client \
    pkg-config procps \
    software-properties-common sqlite3 sudo \
    vim \
    wget


#######
# Install GH CLI
RUN type -p curl >/dev/null || (apt update && apt install curl -y) && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && apt install -y gh


#######
# Install Node.js
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update -y && apt-get install -y nodejs


#######
# Install Python 3.11 and pip
RUN add-apt-repository -y ppa:deadsnakes/ppa -y && \
    apt-get update -y && apt-get install -y \
        python3.11 python3.11-dev python3.11-distutils cython3 && \
    rm /usr/bin/python3 && \
    ln -s /usr/bin/python3.11 /usr/bin/python3 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3


#######
# Install sapling
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
    amd64) URL="https://github.com/facebook/sapling/releases/download/0.2.20240718-145624%2Bf4e9df48/sapling_0.2.20240718-145624+f4e9df48_amd64.Ubuntu20.04.deb" ;; \
    arm64) URL="https://github.com/nhandyal/sapling/releases/download/0.2.20240819-142237%2B9bd0f5c1/sapling_0.2.20240819-142237+9bd0f5c1_arm64.Ubuntu20.04.deb" ;; \
    *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    curl -L -o sapling.deb "$URL" && \
    apt-get update -y && apt-get install -y dpkg-dev locales && \
    dpkg -i sapling.deb && \
    rm sapling.deb && \
    curl -L -o '/etc/default/locale' 'https://storage.googleapis.com/regulus-public/default_locale' && \
    curl -L -o '/etc/locale.gen' 'https://storage.googleapis.com/regulus-public/locale.gen' && \
    locale-gen && \
    apt-get remove -y dpkg-dev && apt-get autoremove -y


# Create a new group and user with the specified IDs and names
RUN if ! getent group $GROUP_NAME; then \
    groupadd -g $GROUP_ID $GROUP_NAME; \
    fi


RUN if ! getent passwd $USER_NAME; then \
    useradd -ms /bin/bash -g $GROUP_NAME -u $USER_ID $USER_NAME; \
    fi


# Add user to sudoers without password
RUN echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers


# Clean up to reduce the size of the Docker image.
RUN rm -rf /tmp/repo /var/lib/apt/lists/*


###########################
## USER CONFIG ##

USER $USER_NAME
COPY configs/bashrc /home/$USER_NAME/.bashrc
COPY configs/bash_profile /home/$USER_NAME/.bash_profile
COPY configs/gitconfig /home/$USER_NAME/.gitconfig

RUN sudo chown -R $USER_NAME:$GROUP_NAME /home/$USER_NAME


USER $USER_NAME
CMD ["tail", "-f", "/dev/null"]
