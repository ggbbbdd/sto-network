#!/bin/bash

# Hyperledger Fabric 네트워크 완전 초기화 및 재시작 스크립트
# 사용법: ./restart.sh

set -e

echo "========================================================="
echo "🔥 Hyperledger Fabric 네트워크 완전 초기화 및 재시작 🔥"
echo "========================================================="

# 1. 정리
docker compose down -v --remove-orphans || true
docker rm -f $(docker ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
sudo rm -rf channel-artifacts/ crypto-config/ fabric-ca/org*
rm -f chaincode/*.tar.gz
rm -rf chaincode/vendor
rm -f *.tar.gz

# 2. 폴더 생성
mkdir -p channel-artifacts crypto-config
sudo chown -R $USER:$USER .

# 3. 소켓 권한
if [ -S /var/run/docker.sock ]; then
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
fi

# 4. CA 시작
docker compose up -d ca.org1.example.com ca.org2.example.com ca.org3.example.com ca.org4.example.com ca.org5.example.com
echo "⏳ CA 서버 대기 중..."
sleep 5

# 5. 인증서 발급
if [ -f "./enrollCA.sh" ]; then
    ./enrollCA.sh
    echo "✓ 인증서 발급 완료"
else
    echo "❌ 오류: enrollCA.sh 없음"
    exit 1
fi

# 5.5 인증서 파일명 표준화
echo ""
echo "=== [5.5/8] 인증서 파일명 표준화 ==="
for KEY_DIR in $(find crypto-config -type d -name "keystore"); do
    TLS_DIR=$(dirname "$KEY_DIR")
    PRIV_KEY=$(ls "$KEY_DIR"/*_sk 2>/dev/null | head -n 1)
    if [ -f "$PRIV_KEY" ]; then cp "$PRIV_KEY" "$TLS_DIR/server.key"; fi
    CERT_FILE=$(ls "$TLS_DIR/signcerts/"*.pem 2>/dev/null | head -n 1)
    if [ -f "$CERT_FILE" ]; then cp "$CERT_FILE" "$TLS_DIR/server.crt"; fi
    CA_FILE=$(ls "$TLS_DIR/tlscacerts/"*.pem 2>/dev/null | head -n 1)
    if [ -f "$CA_FILE" ]; then cp "$CA_FILE" "$TLS_DIR/ca.crt"; fi
done
sudo chmod -R 777 crypto-config/
echo "✓ 인증서 표준화 완료"

# 6. 노드 시작
echo ""
echo "=== [6/8] 노드 시작 ==="
docker compose up -d
echo "⏳ 노드 실행 대기 중 (10초)..."
sleep 10

# 7. 채널 블록 생성
export FABRIC_CFG_PATH=${PWD}
./bin/configtxgen -profile FiveOrgsChannel -outputBlock ./channel-artifacts/mychannel.block -channelID mychannel

# 8. 채널 조인 (경로 강제 지정 버전)
echo ""
echo "=== [8/8] 채널 조인 ==="

echo ">>> Orderer 조인 시도..."
# [수정] find 쓰지 않고 표준화된 경로(ca.crt, server.crt, server.key)를 직접 지정
docker exec cli osnadmin channel join \
    --channelID mychannel \
    --config-block /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/mychannel.block \
    -o orderer.example.com:7053 \
    --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt \
    --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt \
    --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

# 결과 확인
if docker exec cli osnadmin channel list -o orderer.example.com:7053 --ca-file /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt --client-cert /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt --client-key /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key | grep -q "mychannel"; then
    echo "✓ Orderer 채널 조인 성공"
else
    echo "⚠️  Orderer 조인 실패 가능성 있음"
fi

echo ">>> Peer 조인 시도..."
docker exec cli ./scripts/joinChannel.sh

echo ""
echo "✅ 네트워크 재시작 완료!"