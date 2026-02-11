#!/bin/bash

# 1. 환경 설정
BASE_DIR="$HOME/deployment/prod"
NGINX_CONF_DIR="$BASE_DIR/nginx"
COMPOSE_FILE="$BASE_DIR/docker/docker-compose.yml"
APP_NAME="bam-match"

# 도커 컴포즈 명령어 정의 (시스템에 따라 docker-compose 또는 docker compose 선택)
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# 현재 실행 중인 컨테이너 확인
IS_BLUE=$($DOCKER_COMPOSE -f "$COMPOSE_FILE" ps | grep "${APP_NAME}-blue" | grep "Up")

if [ -z "$IS_BLUE" ]; then
  echo "### 배포 시작: GREEN => BLUE (8081) ###"

  echo "1. Blue 이미지 가져오기"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull blue

  echo "2. Blue 컨테이너 실행"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d blue

  # 헬스체크
  for i in {1..20}; do
    echo "3. Blue 헬스체크 중... ($i/20)"
    sleep 5
    REQUEST=$(curl -s http://127.0.0.1:8081/actuator/health | grep "UP" || true)
    if [ -n "$REQUEST" ]; then
      echo "✅ 헬스체크 성공!"
      break
    fi
    if [ $i -eq 20 ]; then
      echo "❌ 헬스체크 실패! 배포를 중단합니다."
      exit 1
    fi
  done

  echo "4. Nginx 설정 교체 및 Reload"
  sudo cp "$NGINX_CONF_DIR/${APP_NAME}-blue.conf" /etc/nginx/conf.d/default.conf
  sudo nginx -s reload

  echo "5. 이전 컨테이너(Green) 종료"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop green || true

else
  echo "### 배포 시작: BLUE => GREEN (8082) ###"

  echo "1. Green 이미지 가져오기"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull green

  echo "2. Green 컨테이너 실행"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d green

  for i in {1..20}; do
    echo "3. Green 헬스체크 중... ($i/20)"
    sleep 5
    REQUEST=$(curl -s http://127.0.0.1:8082/actuator/health | grep "UP" || true)
    if [ -n "$REQUEST" ]; then
      echo "✅ 헬스체크 성공!"
      break
    fi
    if [ $i -eq 20 ]; then
      echo "❌ 헬스체크 실패! 배포를 중단합니다."
      exit 1
    fi
  done

  echo "4. Nginx 설정 교체 및 Reload"
  sudo cp "$NGINX_CONF_DIR/${APP_NAME}-green.conf" /etc/nginx/conf.d/default.conf
  sudo nginx -s reload

  echo "5. 이전 컨테이너(Blue) 종료"
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop blue || true
fi

echo "🎊 배포 완료!"