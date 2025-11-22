#!/bin/sh
set -e

echo "=== Iniciando Navidrome + Rclone ==="

# Verificar se o arquivo de configuração do Rclone existe
if [ ! -f "$RCLONE_CONFIG" ]; then
    echo "ERRO: Arquivo de configuração do Rclone não encontrado em $RCLONE_CONFIG"
    echo "Por favor, monte o arquivo rclone.conf no caminho especificado"
    exit 1
fi

# Verificar versão do Rclone
echo "Versão do Rclone:"
rclone version

# Array de montagens no formato: REMOTE_NAME:REMOTE_PATH:MOUNT_POINT
MONTAGENS="${RCLONE_MOUNTS:-zbminio:/82vy/Músicas:/music}"
MUSIC_FOLDER="${NAVIDROME_MUSIC_FOLDER:-/music}"

echo "Configurando montagens: $MONTAGENS"

# Método compatível com /bin/sh para split da string
OLDIFS="$IFS"
IFS=','
set -- $MONTAGENS
IFS="$OLDIFS"

for montagem in "$@"; do
    OLDIFS="$IFS"
    IFS=':'
    set -- $montagem
    REMOTE_NAME="$1"
    REMOTE_PATH="${2:-/}"
    MOUNT_POINT="${3:-/mnt/$REMOTE_NAME}"
    IFS="$OLDIFS"
    
    # Criar diretório de montagem
    mkdir -p "$MOUNT_POINT"
    
    # Verificar se o remote existe
    if ! rclone listremotes --config "$RCLONE_CONFIG" | grep -q "^${REMOTE_NAME}:"; then
        echo "ERRO: Remote '$REMOTE_NAME' não encontrado na configuração"
        echo "Remotes disponíveis:"
        rclone listremotes --config "$RCLONE_CONFIG"
        exit 1
    fi
    
    echo "Montando $REMOTE_NAME:$REMOTE_PATH em $MOUNT_POINT..."
    
    # Comando de montagem
    rclone mount \
        --allow-other \
        --allow-non-empty \
        --vfs-cache-mode full \
        --vfs-cache-max-age ${RCLONE_MAX_CACHE_AGE:-1h} \
        --vfs-cache-max-size ${RCLONE_MAX_CACHE_SIZE:-1G} \
        --cache-dir "$RCLONE_CACHE_DIR" \
        --daemon \
        --config "$RCLONE_CONFIG" \
        "$REMOTE_NAME:$REMOTE_PATH" "$MOUNT_POINT"
    
    # Aguardar estabilização
    sleep 5
    
    # Verificar se a montagem foi bem sucedida
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Montagem $MOUNT_POINT bem sucedida!"
    else
        echo "Falha na montagem $MOUNT_POINT"
        exit 1
    fi
done

echo "Todas as montagens realizadas com sucesso!"
echo "Iniciando Navidrome com pasta: $MUSIC_FOLDER"
exec /app/navidrome --musicfolder "$MUSIC_FOLDER" --datafolder /data