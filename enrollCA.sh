#!/bin/bash

# 1. 초기 환경 설정
export PATH=${PWD}/../../bin:$PATH
sudo rm -rf crypto-config/
mkdir -p crypto-config

enroll_org() {
  ORG_NUM=$1
  CA_PORT=$2
  ORG_NAME="org${ORG_NUM}.example.com"
  CA_URL="http://admin:adminpw@localhost:${CA_PORT}" 
  ORG_DIR=${PWD}/crypto-config/peerOrganizations/${ORG_NAME}
  ADMIN_DIR="${ORG_DIR}/users/Admin@${ORG_NAME}"
  
  echo "### [Org${ORG_NUM}] 발급 및 모든 MSP 교정 시작 ###"
  mkdir -p ${ORG_DIR}

  # --- 1. 관리자(Admin User) Enroll ---
  export FABRIC_CA_CLIENT_HOME=${ADMIN_DIR}
  export FABRIC_CA_CLIENT_CSR_HOSTS="${ORG_NAME},localhost,127.0.0.1"
  fabric-ca-client enroll -u ${CA_URL} --caname ca-org${ORG_NUM}

  # [중요] 관리자 유저 MSP 자체에 admincerts 생성 (CLI용)
  mkdir -p ${ADMIN_DIR}/msp/admincerts
  cp ${ADMIN_DIR}/msp/signcerts/cert.pem ${ADMIN_DIR}/msp/admincerts/

  # --- 2. 조직(Organization) MSP 구조 생성 ---
  mkdir -p ${ORG_DIR}/msp/admincerts ${ORG_DIR}/msp/tlscacerts ${ORG_DIR}/msp/cacerts
  cp ${ADMIN_DIR}/msp/signcerts/cert.pem ${ORG_DIR}/msp/admincerts/
  cp ${ADMIN_DIR}/msp/cacerts/* ${ORG_DIR}/msp/tlscacerts/
  cp ${ADMIN_DIR}/msp/cacerts/* ${ORG_DIR}/msp/cacerts/

  # --- 3. Peer0 등록 및 발급 ---
  fabric-ca-client register --caname ca-org${ORG_NUM} --id.name peer0 --id.secret peer0pw --id.type peer || true
  
  # Peer0 MSP 발급
  export FABRIC_CA_CLIENT_HOME=${ORG_DIR}/peers/peer0.${ORG_NAME}
  export FABRIC_CA_CLIENT_CSR_HOSTS="peer0.${ORG_NAME},${ORG_NAME},localhost,127.0.0.1"
  fabric-ca-client enroll -u http://peer0:peer0pw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M ${ORG_DIR}/peers/peer0.${ORG_NAME}/msp
  
  # [중요] 피어 MSP에 admincerts 생성 (Peer 실행용)
  mkdir -p ${ORG_DIR}/peers/peer0.${ORG_NAME}/msp/admincerts
  cp ${ADMIN_DIR}/msp/signcerts/cert.pem ${ORG_DIR}/peers/peer0.${ORG_NAME}/msp/admincerts/

  # Peer0 TLS 발급
  fabric-ca-client enroll -u http://peer0:peer0pw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls --enrollment.profile tls

  # TLS 파일 정리
  cp ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/signcerts/* ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/server.crt
  cp ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/keystore/* ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/server.key
  cp ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/tlscacerts/* ${ORG_DIR}/peers/peer0.${ORG_NAME}/tls/ca.crt
}

# Org1~5 순차 실행
for i in {1..5}; do enroll_org $i $((6054 + i * 1000)); done

# --- 4. Orderer 처리 ---
echo "### [Orderer] 발급 및 모든 MSP 교정 시작 ###"
ORDERER_DIR=${PWD}/crypto-config/ordererOrganizations/example.com
mkdir -p ${ORDERER_DIR}
export FABRIC_CA_CLIENT_HOME=${ORDERER_DIR}
export FABRIC_CA_CLIENT_CSR_HOSTS="orderer.example.com,localhost,127.0.0.1"

# Orderer Admin 발급
fabric-ca-client enroll -u http://admin:adminpw@localhost:7054 --caname ca-org1

# [중요] 오더러 관리자 MSP에 admincerts 생성
mkdir -p ${ORDERER_DIR}/msp/admincerts ${ORDERER_DIR}/msp/tlscacerts
cp ${ORDERER_DIR}/msp/signcerts/cert.pem ${ORDERER_DIR}/msp/admincerts/
cp ${ORDERER_DIR}/msp/cacerts/* ${ORDERER_DIR}/msp/tlscacerts/

# Orderer 등록 및 발급
fabric-ca-client register --caname ca-org1 --id.name orderer --id.secret ordererpw --id.type orderer || true
fabric-ca-client enroll -u http://orderer:ordererpw@localhost:7054 --caname ca-org1 -M ${ORDERER_DIR}/orderers/orderer.example.com/msp
fabric-ca-client enroll -u http://orderer:ordererpw@localhost:7054 --caname ca-org1 -M ${ORDERER_DIR}/orderers/orderer.example.com/tls --enrollment.profile tls

# [중요] 오더러 MSP에 admincerts 생성
mkdir -p ${ORDERER_DIR}/orderers/orderer.example.com/msp/admincerts
cp ${ORDERER_DIR}/msp/signcerts/cert.pem ${ORDERER_DIR}/orderers/orderer.example.com/msp/admincerts/

# Orderer TLS 파일 정리
cp ${ORDERER_DIR}/orderers/orderer.example.com/tls/signcerts/* ${ORDERER_DIR}/orderers/orderer.example.com/tls/server.crt
cp ${ORDERER_DIR}/orderers/orderer.example.com/tls/keystore/* ${ORDERER_DIR}/orderers/orderer.example.com/tls/server.key
cp ${ORDERER_DIR}/orderers/orderer.example.com/tls/tlscacerts/* ${ORDERER_DIR}/orderers/orderer.example.com/tls/ca.crt

# --- 최종 권한 및 소켓 설정 ---
sudo chmod -R 777 ${PWD}/crypto-config
sudo chmod 666 /var/run/docker.sock

echo "### [SUCCESS] 모든 유저/피어/오더러의 MSP 구조가 교정되었습니다! ###"