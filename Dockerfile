# 1. Base 이미지 설정 (Java 21 환경)
FROM eclipse-temurin:21-jdk-jammy
# 2. 작업 디렉토리 생성
WORKDIR /app

# 3. 빌드된 JAR 파일을 이미지 내부로 복사
# Jenkins 파이프라인에서 './gradlew build'를 실행하면 build/libs 폴더에 jar가 생깁니다.
# -plain.jar가 아닌 실제 실행 가능한 jar 하나만 복사하도록 설정합니다.
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} app.jar

# 4. 컨테이너가 사용할 포트 명시 (기본 8080)
EXPOSE 8080

# 5. 애플리케이션 실행 명령어
# 구동 속도를 높이고 로그를 최적화하기 위한 옵션을 포함합니다.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
