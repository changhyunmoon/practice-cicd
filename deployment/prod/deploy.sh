#!/bin/bash

# 1. 환경 설정
BASE_DIR="$HOME/deployment/prod"
NGINX_CONF_DIR="$BASE_DIR/nginx"
COMPOSE_FILE="$BASE_DIR/docker/docker-compose.yml"
APP_NAME="bam-match"

# 현재 실행 중인 컨테이너 확인 (blue가 있으면 green을 띄우고, 없으면 blue를 띄움)
IS_BLUE=$(docker ps | grep ${APP_NAME}-blue)

cd "$BASE_DIR/docker"

if [ -z "$IS_BLUE" ]; then
  echo "### 배포 시작: GREEN => BLUE (8081) ###"

  echo "1. Blue 이미지 가져오기"
  docker compose -f "$COMPOSE_FILE" pull blue

  echo "2. Blue 컨테이너 실행"
  docker compose -f "$COMPOSE_FILE" up -d blue

  while [ 1 = 1 ]; do
    echo "3. Blue 헬스체크 중... (http://127.0.0.1:8081/actuator/health)"
    sleep 3
    # 스프링 부트가 완전히 준비되었는지 확인
    REQUEST=$(curl -s http://127.0.0.1:8081/actuator/health | grep "UP")
    if [ -n "$REQUEST" ]; then
      echo "✅ 헬스체크 성공!"
      break
    fi
  done

  echo "4. Nginx 설정 교체 및 Reload (Blue로 트래픽 전환)"
  sudo cp "$NGINX_CONF_DIR/${APP_NAME}-blue.conf" /etc/nginx/conf.d/default.conf
  sudo nginx -s reload

  echo "5. 이전 컨테이너(Green) 종료"
  docker compose -f "$COMPOSE_FILE" stop green

else
  echo "### 배포 시작: BLUE => GREEN (8082) ###"

  echo "1. Green 이미지 가져오기"
  docker compose -f "$COMPOSE_FILE" pull green

  echo "2. Green 컨테이너 실행"
  docker compose -f "$COMPOSE_FILE" up -d green

  while [ 1 = 1 ]; do
    echo "3. Green 헬스체크 중... (http://127.0.0.1:8082/actuator/health)"
    sleep 3
    REQUEST=$(curl -s http://127.0.0.1:8082/actuator/health | grep "UP")
    if [ -n "$REQUEST" ]; then
      echo "✅ 헬스체크 성공!"
      break
    fi
  done

  echo "4. Nginx 설정 교체 및 Reload (Green으로 트래픽 전환)"
  sudo cp "$NGINX_CONF_DIR/${APP_NAME}-green.conf" /etc/nginx/conf.d/default.conf
  sudo nginx -s reload

  echo "5. 이전 컨테이너(Blue) 종료"
  docker compose -f "$COMPOSE_FILE" stop blue
fi

echo "🎊 배포 완료!"