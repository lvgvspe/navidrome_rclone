FROM deluan/navidrome:latest

# Instalar dependências do Rclone e FUSE no Alpine
RUN apk update && apk add --no-cache \
    fuse3 \
    ca-certificates \
    dumb-init \
    curl \
    shadow \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /config/rclone

# Baixar e instalar Rclone pré-compilado
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    cd rclone-*-linux-amd64 && \
    cp rclone /usr/local/bin/ && \
    chmod 755 /usr/local/bin/rclone && \
    chown root:root /usr/local/bin/rclone && \
    cd .. && \
    rm -rf rclone-* && \
    rclone version

# Criar diretórios necessários
RUN mkdir -p /music /cache/rclone /data && \
    chmod 755 /music /cache/rclone /data

# Copiar criador de playlists
COPY mklist.py /data

# Copiar script de inicialização
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Configurar variáveis de ambiente
ENV RCLONE_CONFIG=/config/rclone/rclone.conf
ENV RCLONE_CACHE_DIR=/cache/rclone
ENV RCLONE_MOUNTS=google-drive:/Music:/music
ENV NAVIDROME_MUSIC_FOLDER=/music

# Expor porta do Navidrome
EXPOSE 4533

# Ponto de entrada
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/entrypoint.sh"]