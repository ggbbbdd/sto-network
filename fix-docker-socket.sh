#!/bin/bash

# Docker 소켓 권한 수정 및 피어 컨테이너 재시작 스크립트

echo "============================================"
echo "Docker 소켓 권한 수정 및 피어 재시작"
echo "============================================"

# Docker 소켓 권한 수정
echo ""
echo "=== Docker 소켓 권한 수정 ==="
if [ -S /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock
    echo "✓ Docker 소켓 권한 수정 완료"
    
    # Docker 소켓 소유자 확인 (호환성 있는 방법)
    if command -v stat > /dev/null 2>&1; then
        if stat -c '%G' /var/run/docker.sock > /dev/null 2>&1; then
            DOCKER_GROUP=$(stat -c '%G' /var/run/docker.sock)
        elif stat -f '%Sg' /var/run/docker.sock > /dev/null 2>&1; then
            DOCKER_GROUP=$(stat -f '%Sg' /var/run/docker.sock)
        else
            DOCKER_GROUP="docker"
        fi
        echo "  Docker 소켓 그룹: $DOCKER_GROUP"
        
        # 현재 사용자를 docker 그룹에 추가 (필요한 경우)
        if ! groups | grep -q "\b$DOCKER_GROUP\b"; then
            echo "  경고: 현재 사용자가 docker 그룹에 속해있지 않습니다"
        fi
    fi
else
    echo "✗ 오류: Docker 소켓을 찾을 수 없습니다"
    exit 1
fi

# Docker 데몬 상태 확인
echo ""
echo "=== Docker 데몬 상태 확인 ==="
if docker info > /dev/null 2>&1; then
    echo "✓ Docker 데몬이 정상적으로 실행 중입니다"
else
    echo "✗ 오류: Docker 데몬에 연결할 수 없습니다"
    echo "  Docker 데몬을 재시작하세요: sudo service docker restart"
    exit 1
fi

# 기존 체인코드 컨테이너 정리
echo ""
echo "=== 기존 체인코드 컨테이너 정리 ==="
DEV_PEER_CONTAINERS=$(docker ps -a 2>/dev/null | grep "dev-peer" | awk '{print $1}' 2>/dev/null)
if [ -n "$DEV_PEER_CONTAINERS" ]; then
    echo "$DEV_PEER_CONTAINERS" | while read -r container_id; do
        [ -n "$container_id" ] && docker rm -f "$container_id" 2>/dev/null || true
    done
fi
echo "✓ 체인코드 컨테이너 정리 완료"

# 기존 체인코드 이미지 정리
echo ""
echo "=== 기존 체인코드 이미지 정리 ==="
DEV_PEER_IMAGES=$(docker images 2>/dev/null | grep "dev-peer" | awk '{print $3}' 2>/dev/null)
if [ -n "$DEV_PEER_IMAGES" ]; then
    echo "$DEV_PEER_IMAGES" | while read -r image_id; do
        [ -n "$image_id" ] && docker rmi -f "$image_id" 2>/dev/null || true
    done
fi
echo "✓ 체인코드 이미지 정리 완료"

# 피어 컨테이너 재시작
echo ""
echo "=== 피어 컨테이너 재시작 ==="
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

# 피어 컨테이너 내부에서 Docker 소켓 접근 테스트
echo ""
echo "=== 피어 컨테이너 Docker 소켓 접근 테스트 ==="
if docker exec peer0.org1.example.com ls -la /host/var/run/docker.sock > /dev/null 2>&1; then
    echo "✓ 피어 컨테이너에서 Docker 소켓 접근 가능"
else
    echo "✗ 경고: 피어 컨테이너에서 Docker 소켓 접근 불가 (피어가 아직 시작 중일 수 있음)"
fi

# 피어들이 완전히 시작될 때까지 대기
echo ""
echo "피어들이 완전히 시작될 때까지 대기 중..."
sleep 15

# 피어 상태 확인
echo ""
echo "=== 피어 상태 확인 ==="
docker ps | grep peer0.org || echo "경고: 일부 피어가 실행되지 않을 수 있습니다"

echo ""
echo "============================================"
echo "완료! 이제 체인코드 배포를 다시 시도하세요:"
echo "  docker exec -it cli ./scripts/deployCC.sh"
echo "============================================"
