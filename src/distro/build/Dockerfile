FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN userdel -r ubuntu 2>/dev/null || true

RUN rm -f /etc/dpkg/dpkg.cfg.d/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    gnupg \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list \
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    adduser \
    sudo \
    tzdata \
    whiptail \
    zsh \
    nano \
    git \
    openssh-client \
    strace \
    lsof \
    make \
    less \
    iputils-ping \
    tree \
    tar \
    unzip \
    bzip2 \
    unrar \
    p7zip-full \
    gzip \
    xz-utils \
    zstd \
    bat \
    direnv \
    eza \
    fd-find \
    fzf \
    gh \
    jq \
    ripgrep \
    rlwrap \
    shellcheck \
    zoxide \
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 fr_FR.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN ln -s $(which fdfind) /usr/local/bin/fd \
    && ln -s $(which batcat) /usr/local/bin/bat

RUN if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh.gz ]; then \
        gunzip -f /usr/share/doc/fzf/examples/key-bindings.zsh.gz; \
    fi

RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then STARSHIP_ARCH="x86_64"; else STARSHIP_ARCH="aarch64"; fi \
    && curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${STARSHIP_ARCH}-unknown-linux-gnu.tar.gz" -o starship.tar.gz \
    && tar -xzf starship.tar.gz -C /usr/local/bin \
    && rm starship.tar.gz \
    && curl -fsSL "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${STARSHIP_ARCH}-musl" -o /usr/local/bin/tldr \
    && chmod +x /usr/local/bin/tldr

RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.local/share/oh-my-zsh \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting

RUN touch /etc/skel/.zshrc \
    && rm -f /etc/skel/.bashrc /etc/skel/.bash_logout /etc/skel/.profile \
    && mkdir -p /etc/skel/.ssh \
    && mkdir -p /etc/skel/projects \
    && chmod 700 /etc/skel/.ssh \
    && chown -R root:root /etc/skel

CMD ["/bin/bash"]