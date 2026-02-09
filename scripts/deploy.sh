# 1. 기존 컨테이너 중지 및 삭제
# 'lunch'라는 이름의 컨테이너가 실행 중이거나 존재하는지 확인
if [ $(sudo docker ps -aq -f name=lunch) ]; then
    echo ">>> 기존 'lunch' 컨테이너를 중지 및 삭제합니다."
    sudo docker stop lunch || true
    sudo docker rm lunch || true
else
    echo ">>> 삭제할 기존 컨테이너가 없습니다."
fi

# 2. 이미지 삭제 (Clean-up)
# 새로 pull 받기 전 로컬에 있는 이전 버전 이미지를 삭제하여 용량을 확보합니다.
echo ">>> 이전 이미지를 삭제하여 환경을 정리합니다."
sudo docker rmi mch1999/cicd-project || true

# 3. 도커 허브에서 최신 이미지 Pull
echo ">>> Docker Hub로부터 최신 이미지를 받아옵니다."
sudo docker pull mch1999/cicd-project

# 4. 새 이미지로 컨테이너 실행 (Port Forwarding)
# -p 8080:8080 (외부포트:내부포트) 
echo ">>> 'lunch' 컨테이너를 실행합니다."
sudo docker run -d -p 8080:8080 --name lunch mch1999/cicd-project

# 5. 불필요한 이미지(Dangling images) 삭제
# 빌드 과정에서 생긴 이름 없는 이미지(<none>)들을 정리합니다.
echo ">>> 사용하지 않는 불필요한 이미지를 정리합니다."
sudo docker image prune -f || true

echo ">>> 모든 배포 과정이 완료되었습니다!"