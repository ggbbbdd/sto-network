#!/bin/bash

# 체인코드 빌드 문제 해결 스크립트 (WSL 환경용)

echo "============================================"
echo "체인코드 빌드 문제 해결 (WSL 환경)"
echo "============================================"

# 1. Docker 소켓 권한 및 상태 확인
echo ""
echo "=== 1. Docker 소켓 확인 ==="
if [ -S /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock
    echo "✓ Docker 소켓 권한 수정 완료"
    
    # Docker 소켓 접근 테스트
    if docker info > /dev/null 2>&1; then
        echo "✓ Docker 데몬 연결 성공"
    else
        echo "✗ Docker 데몬 연결 실패 - Docker 데몬을 재시작하세요"
        echo "  sudo service docker restart"
        exit 1
    fi
else
    echo "✗ Docker 소켓을 찾을 수 없습니다"
    exit 1
fi

# 2. 기존 체인코드 컨테이너 및 이미지 정리
echo ""
echo "=== 2. 기존 체인코드 정리 ==="
# xargs -r 대신 더 호환성 있는 방법 사용
DEV_PEER_CONTAINERS=$(docker ps -a 2>/dev/null | grep "dev-peer" | awk '{print $1}' 2>/dev/null)
if [ -n "$DEV_PEER_CONTAINERS" ]; then
    echo "$DEV_PEER_CONTAINERS" | while read -r container_id; do
        [ -n "$container_id" ] && docker rm -f "$container_id" 2>/dev/null || true
    done
fi

DEV_PEER_IMAGES=$(docker images 2>/dev/null | grep "dev-peer" | awk '{print $3}' 2>/dev/null)
if [ -n "$DEV_PEER_IMAGES" ]; then
    echo "$DEV_PEER_IMAGES" | while read -r image_id; do
        [ -n "$image_id" ] && docker rmi -f "$image_id" 2>/dev/null || true
    done
fi
echo "✓ 체인코드 컨테이너 및 이미지 정리 완료"

# 3. Fabric 체인코드 빌드 이미지 확인 및 다운로드
echo ""
echo "=== 3. Fabric 체인코드 빌드 이미지 확인 ==="
if docker images | grep -q "hyperledger/fabric-ccenv"; then
    echo "✓ fabric-ccenv 이미지 존재"
else
    echo "  fabric-ccenv 이미지를 다운로드 중..."
    docker pull hyperledger/fabric-ccenv:latest || echo "  경고: 이미지 다운로드 실패"
fi

if docker images | grep -q "hyperledger/fabric-baseos"; then
    echo "✓ fabric-baseos 이미지 존재"
else
    echo "  fabric-baseos 이미지를 다운로드 중..."
    docker pull hyperledger/fabric-baseos:latest || echo "  경고: 이미지 다운로드 실패"
fi

# 4. 피어 컨테이너 재시작
echo ""
echo "=== 4. 피어 컨테이너 재시작 ==="
# docker compose와 docker-compose 모두 지원
if command -v docker-compose > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "✗ 오류: docker compose를 찾을 수 없습니다"
    exit 1
fi

$DOCKER_COMPOSE_CMD restart peer0.org1.example.com peer0.org2.example.com peer0.org3.example.com peer0.org4.example.com peer0.org5.example.com 2>/dev/null || {
    echo "  경고: 일부 피어 재시작 실패 (이미 중지되었을 수 있음)"
}
echo "✓ 피어 컨테이너 재시작 완료"

# 5. 피어들이 완전히 시작될 때까지 대기
echo ""
echo "피어들이 완전히 시작될 때까지 대기 중..."
sleep 20

# 6. 피어 컨테이너에서 Docker 소켓 접근 테스트
echo ""
echo "=== 5. 피어 컨테이너 Docker 소켓 접근 테스트 ==="
for i in 1 2 3 4 5; do
    PEER_NAME="peer0.org${i}.example.com"
    if docker exec "${PEER_NAME}" ls -la /host/var/run/docker.sock > /dev/null 2>&1; then
        echo "✓ ${PEER_NAME}: Docker 소켓 접근 가능"
    else
        echo "✗ ${PEER_NAME}: Docker 소켓 접근 불가"
    fi
done

# 7. 피어 로그에서 체인코드 빌드 관련 오류 확인
echo ""
echo "=== 6. 피어 로그 확인 (최근 오류) ==="
docker logs peer0.org1.example.com --tail 20 | grep -i "chaincode\|docker\|build" || echo "  최근 체인코드 관련 로그 없음"

echo ""
echo "============================================"
echo "완료!"
echo ""
echo "다음 명령어로 체인코드 배포를 다시 시도하세요:"
echo "  docker exec -it cli ./scripts/deployCC.sh"
echo ""
echo "문제가 계속되면:"
echo "  1. Docker 데몬 재시작: sudo service docker restart"
echo "  2. WSL 재시작"
echo "  3. Docker Desktop 재시작 (Windows에서)"
echo "============================================"
