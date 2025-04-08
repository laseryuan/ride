FROM lasery/krypton as builder

FROM {{ARCH.images.base}}

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND noninteractive

# Install dependency
RUN \
  apt-get update && \
  apt-get install -y \
    `# system` \
      sudo gosu \
      apt-transport-https \
      ca-certificates \
      gnupg \
      locales \
    `# help` \
      man \
    `# ssh` \
      openssh-server \
      sshfs \
    `# python` \
      python3-venv \
    `# network tools` \
      curl \
      iputils-ping \
      iproute2 \
      netcat-openbsd socat \
    `# source control` \
      git \
    `# dotfiles` \
      stow \
    `# editor` \
      ack-grep \
      tmux \
      vim \
      ``
    # {{#ARCH.is_arm32}}
    # `# chiff dependency` \
      # python3-dev libffi-dev libxml2-dev libxslt1-dev gcc-arm-linux-gnueabihf \
    # {{/ARCH.is_arm32}}

# allow access to volume by different user to enable UIDs other than root when
# using volumes
RUN echo user_allow_other >> /etc/fuse.conf

# Install github action cache dependency
{{#ARCH.is_amd}}
RUN apt install zstd
{{/ARCH.is_amd}}

## Install mbuild dependency
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Run the application:
RUN pip install \
      `# mbuild dependency`\
      chevron pyyaml argparse \
      `# python codebench depencency`\
      pytest pytest-mock \
      `# others`\
      chiff \
      ``

# Install krypton
COPY --from=builder /usr/bin/kr /usr/bin/krd /usr/bin/krssh /usr/bin/krgpg /usr/local/bin/

{{#ARCH.is_amd}}
# Install akamai krypton
# RUN \
    # curl -SsL https://akamai.github.io/akr-pkg/ubuntu/KEY.gpg | apt-key add - && \
    # curl -SsL -o /etc/apt/sources.list.d/akr.list https://akamai.github.io/akr-pkg/ubuntu/akr.list && \
    # apt-get update && \
    # apt-get install -y akr pinentry-tty

# Install neovim
RUN \
    curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o /tmp/nvim.tar.gz && \
    tar -C /opt -xzf /tmp/nvim.tar.gz
ENV PATH="$PATH:/opt/nvim-linux-x86_64/bin"
{{/ARCH.is_amd}}

{{#ARCH.is_arm64}}
# Install neovim
RUN \
    curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz -o /tmp/nvim.tar.gz && \
    tar -C /opt -xzf /tmp/nvim.tar.gz

ENV PATH="$PATH:/opt/nvim-linux-arm64/bin"
{{/ARCH.is_arm64}}

# Install docker client
RUN apt-get install -yq lsb-release
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

RUN echo "deb \
{{#ARCH.is_amd}}
  [arch=amd64 \
{{/ARCH.is_amd}}
{{#ARCH.is_arm64}}
  [arch=arm64 \
{{/ARCH.is_arm64}}
{{#ARCH.is_arm32}}
  [arch=armhf \
{{/ARCH.is_arm32}}
  signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update && apt-get install -y \
      docker-ce-cli

# Config ssh server
RUN mkdir -p /var/run/sshd

# Create ride user with sudo previledge
ENV RIDE_USER=ride RIDE_USER_ID=1000 RIDE_USER_GID=1000

RUN groupadd --gid "${RIDE_USER_GID}" "${RIDE_USER}" && \
    useradd \
      --uid ${RIDE_USER_ID} \
      --gid ${RIDE_USER_GID} \
      --groups sudo \
      --create-home --home-dir /home/ride \
      --shell /bin/bash \
      ${RIDE_USER}

RUN echo "ride ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ride
RUN echo 'Defaults    env_keep += "HOME"' >> /etc/sudoers.d/ride

USER ride
WORKDIR /home/ride

# Config git
RUN git config --global user.email "{{GIT_EMAIL}}" && \
  git config --global user.name "{{GIT_NAME}}" && \
  git config --global pull.ff only

# Vim
COPY --chown=ride .dotfiles/vim .dotfiles/vim
RUN \
  cd .dotfiles && \
  stow -t ~ vim

RUN set -ex; \
    git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim; \
    vim -u NONE -S ~/.vim/vundle.vim -S ~/.vim/plugins.vim +PluginInstall +qall;

# Dotfiles
COPY --chown=ride .dotfiles .dotfiles
RUN mkdir projects .ssh .kr .akr .config && \
    rm ~/.bashrc && \
    cd .dotfiles && \
    stow -t ~ tmux bash ssh && \
    chmod a+w -R /home/ride
RUN chmod 600 .dotfiles/ssh/.ssh/config

# mbuild
COPY --chown=ride mbuild /home/ride/mbuild
RUN chmod 1777 /home/ride/mbuild
COPY --chown=ride tmpl.Dockerfile /home/ride/
COPY --chown=ride mbuild.yml /home/ride/

# copy RIDE files
COPY --chown=ride ./docker-entrypoint.sh /
COPY --chown=ride ./README.md /
COPY --chown=ride doc/ /doc/
COPY --chown=ride bin/ /usr/local/bin/

# Tests
COPY test.sh /test.sh
RUN bash -e /test.sh
RUN kr --version

USER root
ENV HOME /home/ride

ENTRYPOINT ["/docker-entrypoint.sh"]
ENV SHELL /bin/bash
CMD ["help"]
EXPOSE 22
