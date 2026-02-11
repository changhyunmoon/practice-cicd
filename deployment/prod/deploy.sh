#!/bin/bash
set -Eeuo pipefail

# 1. 기본 경로 및 설정
BASE_DIR="$HOME/deployment/prod"
NGINX_DIR="$BASE_DIR/nginx"
COMPOSE="$BASE_DIR/docker/docker-compose.yml"
APP_ENV_FILE="$BASE_DIR/.env"

MAX_RETRY=20 # 조금 넉넉하게 수정 (Spring Boot 기동 시간 고려)
INTERVAL=5
APP_NAME="mam"

log() { echo "[$(date +"%T")] $1"; }

rollback() {
    log "❌ 에러 발생! 롤백을 시작합니다."
    # 현재 실행 중이던 원본 포트로 Nginx 다시 고정
    if [ -f "$NGINX_DIR/$APP_NAME-$CURRENT.conf" ]; then
        sudo cp "$NGINX_DIR/$APP_NAME-$CURRENT.conf" /etc/nginx/conf.d/default.conf
        sudo nginx -s reload
    fi
    # 실패한 NEXT 컨테이너는 삭제
    docker compose -f "$COMPOSE" --env-file "$APP_ENV_FILE" rm -f -s "$NEXT" || true
    exit 1
}

trap rollback ERR

cd "$BASE_DIR"

# 2. 현재 상태 확인 및 타겟 설정
if docker ps --filter "name=$APP_NAME-blue" --filter "status=running" | grep "$APP_NAME-blue" >/dev/null; then
    CURRENT="blue"
    NEXT="green"
    HEALTH_PORT=8082  # Green이 뜰 때 체크할 포트
else
    CURRENT="green"
    NEXT="blue"
    HEALTH_PORT=8081  # Blue가 뜰 때 체크할 포트
fi

log "🚀 배포 전환: $CURRENT → $NEXT (Health Check Port: $HEALTH_PORT)"

# 3. 새로운 버전(NEXT) 실행
log "1. 새로운 이미지 Pull ($NEXT)..."
docker compose -f "$COMPOSE" --env-file "$APP_ENV_FILE" pull "$NEXT"

log "2. 컨테이너 실행 ($NEXT)..."
docker compose -f "$COMPOSE" --env-file "$APP_ENV_FILE" up -d "$NEXT"

# 4. 헬스체크
log "3. 헬스체크 시작: http://127.0.0.1:$HEALTH_PORT/actuator/health"

COUNT=0
until curl -sf "http://127.0.0.1:$HEALTH_PORT/actuator/health" | grep "UP" >/dev/null; do
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRY ]; then
        log "❌ $NEXT 서버 기동 실패 (타임아웃)"
        exit 1
    fi
    log "서버 응답 대기 중... ($COUNT/$MAX_RETRY)"
    sleep $INTERVAL
done

log "✅ $NEXT 서버 정상 확인!"

# 5. Nginx 트래픽 전환
log "4. Nginx 설정 교체 및 Reload"
sudo cp "$NGINX_DIR/$APP_NAME-$NEXT.conf" /etc/nginx/conf.d/default.conf
sudo nginx -t
sudo nginx -s reload

# 6. 이전 버전 정리
log "5. 이전 버전($CURRENT) 종료"
# 바로 종료하지 않고 5초 정도 대기 (기존 요청 처리 마무리 유도)
sleep 5
docker compose -f "$COMPOSE" --env-file "$APP_ENV_FILE" stop "$CURRENT" || true
docker compose -f "$COMPOSE" --env-file "$APP_ENV_FILE" rm -f "$CURRENT" || true

log "🎊 배포 성공! 현재 라이브 서버: $NEXT"