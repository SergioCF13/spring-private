#!/usr/bin/env bash
set -euo pipefail

APP_NAME="spring-boot-app"
APP_DIR="/opt/spring-boot-app"
JAVA_OPTS="-Xms512m -Xmx1024m"
SPRING_PROFILE="prod"

# ARGUMENTOS
# $1 puede ser la ruta del nuevo JAR o la palabra "rollback"
INPUT_ARG="$1"
TARGET_PORT="$2"

if [[ -z "${INPUT_ARG:-}" ]] || [[ -z "${TARGET_PORT:-}" ]]; then
  echo "Usage: deploy.sh <path-to-new-jar|rollback> <target-port>"
  exit 1
fi

cd "$APP_DIR"
INSTANCE_JAR="app-${TARGET_PORT}.jar"
LOG_FILE="logs/app-${TARGET_PORT}.log"

# --- 0. LÓGICA DE ROLLBACK ---
# Si el primer argumento es "rollback", buscamos el backup más reciente y lo restauramos
if [[ "$INPUT_ARG" == "rollback" ]]; then
  echo "🔙 Iniciando Rollback en puerto ${TARGET_PORT}..."
  
  # Busca el archivo más nuevo en la carpeta versions que coincida con el puerto
  LAST_BACKUP=$(ls -t versions/app-${TARGET_PORT}-*.jar | head -n 1)
  
  if [[ -z "$LAST_BACKUP" ]]; then
    echo "❌ No hay backups para hacer rollback en puerto ${TARGET_PORT}"
    exit 1
  fi
  
  echo "♻️  Restaurando ${LAST_BACKUP}..."
  cp "$LAST_BACKUP" "$INSTANCE_JAR"
  
  # Una vez restaurado, seguimos el flujo normal para reiniciar la app
  echo "✅ Rollback aplicado. Reiniciando servicio..."

else
  # --- SI ES UN DEPLOY NORMAL ---
  echo "🚀 Deploying ${APP_NAME} on PORT ${TARGET_PORT}"
  
  # 1. BACKUP (Solo si ya existe una versión anterior corriendo)
  if [[ -f "$INSTANCE_JAR" ]]; then
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    echo "💾 Guardando backup en versions/app-${TARGET_PORT}-${TIMESTAMP}.jar"
    cp "$INSTANCE_JAR" "versions/app-${TARGET_PORT}-${TIMESTAMP}.jar"
  fi

  # 2. COPIAR NUEVO JAR
  echo "📦 Copying new jar to ${INSTANCE_JAR}"
  cp "$INPUT_ARG" "$INSTANCE_JAR"
fi

# --- 3. DETENER PROCESO ACTUAL ---
# Buscamos el proceso Java que esté usando explícitamente ese puerto y lo matamos.
PID=$(ps aux | grep java | grep "server.port=${TARGET_PORT}" | awk '{print $2}' || true)

if [[ -n "$PID" ]]; then
  echo "🛑 Stopping app on port ${TARGET_PORT} (PID=$PID)"
  kill "$PID"
  sleep 5
  if ps -p "$PID" > /dev/null; then
    echo "⚠️  Force killing..."
    kill -9 "$PID"
  fi
else
  echo "ℹ️  No running app found on port ${TARGET_PORT}"
fi

# --- 4. INICIAR APP ---
chmod 755 "$INSTANCE_JAR"
echo "▶️  Starting app on port ${TARGET_PORT}"
nohup java $JAVA_OPTS \
  -jar "$INSTANCE_JAR" \
  --spring.profiles.active="$SPRING_PROFILE" \
  --server.port="$TARGET_PORT" \
  > "$LOG_FILE" 2>&1 &

# --- 5. HEALTH CHECK ---
echo "🔍 Waiting for app on port ${TARGET_PORT}..."
for i in {1..20}; do
  if curl -sf "http://localhost:${TARGET_PORT}/health" > /dev/null; then
    echo "✅ Deployment successful on port ${TARGET_PORT}"
    exit 0
  fi
  sleep 3
done

echo "❌ App failed to start on port ${TARGET_PORT}"
exit 1