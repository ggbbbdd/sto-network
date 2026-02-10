#!/bin/bash
CH_BLOCK="./channel-artifacts/mychannel.block"
ORDERER_ADDRESS="orderer.example.com:7050"
ORDERER_TLS_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"

# 피어들이 시작될 때까지 대기
echo ">>> Waiting for peers to be ready..."
sleep 15

for i in {1..5}; do
  ORG_NAME="org${i}.example.com"
  INTERNAL_PORT=7051
  export CORE_PEER_LOCALMSPID="Org${i}MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}/peers/peer0.${ORG_NAME}/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp
  export CORE_PEER_ADDRESS=peer0.${ORG_NAME}:${INTERNAL_PORT}
  export CORE_PEER_TLS_ENABLED=true

  echo ">>> Joining Org${i} to mychannel..."
  peer channel join -b ${CH_BLOCK} -o ${ORDERER_ADDRESS} --tls --cafile ${ORDERER_TLS_CA} || echo ">>> Failed to join Org${i}"
  sleep 2
done
