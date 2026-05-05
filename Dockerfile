FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git curl wget vim jq \
    python3 python3-pip \
    openssh-client ca-certificates \
    gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI для управления docker-демоном хоста
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# gosu — drop privileges from root after entrypoint fixes
RUN curl -fsSL -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(dpkg --print-architecture)" \
    && chmod +x /usr/local/bin/gosu

# Непривилегированный пользователь (root запрещён для bypassPermissions)
RUN useradd -m -s /bin/bash claude \
    && chown -R claude:claude /home/claude

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
