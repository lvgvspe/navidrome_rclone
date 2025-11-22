#!/bin/sh
set -e

echo "=== Iniciando Navidrome + Rclone Sync ==="

# Configurações
CONFIG_RETRIES=30
CONFIG_DELAY=10
CONFIG_FILE="$RCLONE_CONFIG"

# Função para verificar e aguardar o arquivo de configuração
wait_for_rclone_config() {
    local retries=$CONFIG_RETRIES
    local delay=$CONFIG_DELAY
    
    echo "Aguardando arquivo de configuração do Rclone: $CONFIG_FILE"
    echo "Você tem $(($retries * $delay / 60)) minutos para copiar o arquivo..."
    
    while [ $retries -gt 0 ]; do
        if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
            # Verificar se a configuração é válida
            if rclone config file --config "$CONFIG_FILE" >/dev/null 2>&1; then
                echo "✅ Arquivo de configuração encontrado e válido!"
                return 0
            else
                echo "⚠️ Arquivo encontrado mas configuração inválida, aguardando..."
            fi
        fi
        
        echo "⏳ Arquivo não encontrado ou inválido. Tentativas restantes: $retries. Aguardando ${delay}s..."
        retries=$((retries - 1))
        sleep $delay
    done
    
    echo "❌ Timeout: Arquivo de configuração não encontrado ou inválido"
    return 1
}

# Aguardar o arquivo de configuração do Rclone
if ! wait_for_rclone_config; then
    echo "🚨 Iniciando sem Rclone - apenas Navidrome"
    echo "Iniciando Navidrome com pasta local: $MUSIC_FOLDER"
    exec /app/navidrome --musicfolder "$MUSIC_FOLDER" --datafolder /data
fi

# O restante do script permanece igual...
# Verificar versão do Rclone
echo "Versão do Rclone:"
rclone version

# Array de montagens no formato: REMOTE_NAME:REMOTE_PATH:MOUNT_POINT
MONTAGENS="${RCLONE_MOUNTS:-zbminio:/82vy/Músicas:/music}"
MUSIC_FOLDER="${NAVIDROME_MUSIC_FOLDER:-/music}"
SYNC_INTERVAL="${SYNC_INTERVAL:-3600}"  # 1 hora padrão

echo "Configurando sincronizações: $MONTAGENS"

# Função de sincronização
sync_remotes() {
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
        LOCAL_FOLDER="${3:-/music}"
        IFS="$OLDIFS"
        
        # Criar diretório local
        mkdir -p "$LOCAL_FOLDER"
        
        # Verificar se o remote existe
        if ! rclone listremotes --config "$RCLONE_CONFIG" | grep -q "^${REMOTE_NAME}:"; then
            echo "ERRO: Remote '$REMOTE_NAME' não encontrado na configuração"
            echo "Remotes disponíveis:"
            rclone listremotes --config "$RCLONE_CONFIG"
            exit 1
        fi
        
        echo "Sincronizando $REMOTE_NAME:$REMOTE_PATH para $LOCAL_FOLDER..."
        
        # Comando de sincronização
        rclone sync \
            --config "$RCLONE_CONFIG" \
            --progress \
            --verbose \
            "$REMOTE_NAME:$REMOTE_PATH" "$LOCAL_FOLDER"
        
        echo "✅ Sincronização $LOCAL_FOLDER bem sucedida!"
    done
}

# Sincronização inicial
sync_remotes

echo "Sincronização inicial concluída!"
echo "Iniciando Navidrome com pasta: $MUSIC_FOLDER"

sync_playlists() {
    while true; do
        sleep "${MKLIST_INTERVAL:-10}"
        cd /data
        python3 mklist.py
    done
}

# Iniciar Navidrome em background e sync periódico em foreground
if [ "$SYNC_INTERVAL" != "0" ]; then
    echo "🔄 Sincronização contínua ativada (intervalo: ${SYNC_INTERVAL}s)"
    
    # Iniciar Navidrome em background
    /app/navidrome --musicfolder "$MUSIC_FOLDER" --datafolder /data &

    # Iniciar sync playlists em background
    if [ "$MKLIST_RUN" == "true" ]; then
        sync_playlists &
    fi  
    
    # Manter sync periódico em foreground
    while true; do
        sleep "$SYNC_INTERVAL"
        echo "=== Sincronização periódica ==="
        sync_remotes
    done
else
    echo "🔒 Modo sincronização única"
    exec /app/navidrome --musicfolder "$MUSIC_FOLDER" --datafolder /data
fi