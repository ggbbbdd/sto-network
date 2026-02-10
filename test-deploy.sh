#!/bin/bash

# 체인코드 배포 테스트 스크립트

set -e

cd "$(dirname "$0")"

echo "============================================"
echo "체인코드 배포 테스트 시작"
echo "============================================"

# 1. 컨테이너 상태 확인
echo ""
echo "=== 1. 컨테이너 상태 확인 ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "NAME|peer|orderer|cli" || docker ps

# 2. 채널 목록 확인
echo ""
echo "=== 2. 채널 목록 확인 ==="
docker exec cli peer channel list 2>&1 || echo "경고: 채널 목록 조회 실패"

# 3. 체인코드 배포 시도
echo ""
echo "=== 3. 체인코드 배포 시도 ==="
docker exec -it cli ./scripts/deployCC.sh 2>&1

# 4. 배포 결과 확인
echo ""
echo "=== 4. 배포 결과 확인 ==="
if [ $? -eq 0 ]; then
    echo "✓ 체인코드 배포 성공"
    
    # 설치된 체인코드 확인
    echo ""
    echo "=== 설치된 체인코드 확인 ==="
    for i in 1 2 3 4 5; do
        ORG_NAME="org${i}.example.com"
        export CORE_PEER_LOCALMSPID="Org${i}MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}/peers/peer0.${ORG_NAME}/tls/ca.crt
        export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp
        export CORE_PEER_ADDRESS=peer0.${ORG_NAME}:7051
        export CORE_PEER_TLS_ENABLED=true
        
        echo "Org${i} 설치된 체인코드:"
        docker exec cli peer lifecycle chaincode queryinstalled \
            --peerAddresses peer0.${ORG_NAME}:7051 \
            --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}/peers/peer0.${ORG_NAME}/tls/ca.crt \
            --connTimeout 10s 2>&1 || echo "  조회 실패"
    done
else
    echo "✗ 체인코드 배포 실패"
    
    # 오류 로그 확인
    echo ""
    echo "=== 오류 로그 확인 ==="
    echo "피어 로그 (최근 30줄):"
    docker logs peer0.org1.example.com --tail 30 2>&1 | grep -i "error\|chaincode\|docker\|build" || echo "  관련 로그 없음"
fi

echo ""
echo "============================================"
echo "테스트 완료"
echo "============================================"
