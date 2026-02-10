#!/bin/bash

# 에러 발생 시 즉시 중단
set -e

CHANNEL_NAME="mychannel"
CC_NAME="sto_cc"
CC_SRC_PATH="./chaincode"
CC_RUNTIME_LANGUAGE="golang"
CC_VERSION="1.0"
CC_SEQUENCE="1"

# CLI 컨테이너 내부 설정
export FABRIC_CFG_PATH=/etc/hyperledger/fabric/

echo ">>> [Search] Orderer TLS 인증서 자동 탐색 중..."
# Orderer TLS CA 찾기
ORDERER_CA=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations -type f -name "*tls*ca*.pem" | head -n 1)

echo ">>> [INFO] Found Orderer CA: $ORDERER_CA"

if [ -z "$ORDERER_CA" ] || [ ! -f "$ORDERER_CA" ]; then
    echo "❌ [CRITICAL] Orderer TLS CA 파일을 찾을 수 없습니다!"
    exit 1
fi

setGlobals() {
  ORG=$1
  PEER_PORT=7051
  
  export CORE_PEER_LOCALMSPID="Org${ORG}MSP"
  # TLS Root Cert 경로도 자동으로 찾기
  PEER_TLS_ROOT=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org${ORG}.example.com -name "ca.crt" | head -n 1)
  export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLS_ROOT
  export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org${ORG}.example.com/users/Admin@org${ORG}.example.com/msp
  export CORE_PEER_ADDRESS=peer0.org${ORG}.example.com:${PEER_PORT}
  export CORE_PEER_TLS_ENABLED=true
}

# 1. 패키징
echo ">>> [1/5] Chaincode Packaging..."
setGlobals 1
if [ ! -f "${CC_NAME}.tar.gz" ]; then
    peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION}
    echo "✓ Packaging Success"
else
    echo "✓ Package already exists, skipping."
fi

# 2. 설치
echo ">>> [2/5] Installing Chaincode on All Peers..."
for i in 1 2 3 4 5; do
  echo "Installing on Org${i}..."
  setGlobals $i
  # 이미 설치되었으면 에러 무시
  peer lifecycle chaincode install ${CC_NAME}.tar.gz || echo "⚠️  Already installed on Org${i}, skipping..."
done
echo "✓ Install Success"

# 3. 승인 (Approve) - 타임아웃 대폭 증가
echo ">>> [3/5] Approving Chaincode..."
setGlobals 1
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled -O json | jq -r ".installed_chaincodes | .[] | select(.label==\"${CC_NAME}_${CC_VERSION}\") | .package_id")
echo "Package ID: ${PACKAGE_ID}"

for i in 1 2 3 4 5; do
  echo "Approving for Org${i}..."
  setGlobals $i
  # [핵심 수정] --waitForEventTimeout 300s 추가
  peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} --init-required --waitForEventTimeout 300s
done
echo "✓ Approve Success"

# 4. 커밋 (Commit) - 타임아웃 대폭 증가
echo ">>> [4/5] Committing Chaincode..."
setGlobals 1
# Peer TLS Root Certs 경로 자동화 변수
ROOT_ORG1=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com -name "ca.crt" | head -n 1)
ROOT_ORG2=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com -name "ca.crt" | head -n 1)
ROOT_ORG3=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com -name "ca.crt" | head -n 1)
ROOT_ORG4=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org4.example.com -name "ca.crt" | head -n 1)
ROOT_ORG5=$(find /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org5.example.com -name "ca.crt" | head -n 1)

# [핵심 수정] --waitForEventTimeout 300s 추가
peer lifecycle chaincode commit -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles $ROOT_ORG1 --peerAddresses peer0.org2.example.com:7051 --tlsRootCertFiles $ROOT_ORG2 --peerAddresses peer0.org3.example.com:7051 --tlsRootCertFiles $ROOT_ORG3 --peerAddresses peer0.org4.example.com:7051 --tlsRootCertFiles $ROOT_ORG4 --peerAddresses peer0.org5.example.com:7051 --tlsRootCertFiles $ROOT_ORG5 --version ${CC_VERSION} --sequence ${CC_SEQUENCE} --init-required --waitForEventTimeout 300s
echo "✓ Commit Success"

# 5. 초기화 (Init)
echo ">>> [5/5] Invoking Init..."
peer chaincode invoke -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" -C $CHANNEL_NAME -n ${CC_NAME} --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles $ROOT_ORG1 --isInit -c '{"function":"Init","Args":[]}' --waitForEventTimeout 300s
echo "✓ Init Success! Deployment Complete!"