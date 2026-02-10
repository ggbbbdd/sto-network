# STO Blockchain Network Project (Hyperledger Fabric)

부산대학교 STO(토큰 증권 발행) 플랫폼을 위한 Hyperledger Fabric 기반 블록체인 네트워크 프로젝트입니다.
이 네트워크는 5개의 조직(Org1~Org5)과 Raft 합의 알고리즘을 사용하는 오더러(Orderer)로 구성되어 있습니다.
## 📌 프로젝트 개요

- **목적**: STO 플랫폼의 분산 원장 인프라 구축 및 체인코드(스마트 컨트랙트) 테스트
- **기반 기술**: Hyperledger Fabric v2.5+
- **네트워크 구조**:
  - **Organizations**: 5개 (Org1, Org2, Org3, Org4, Org5)
  - **Consensus**: EtcdRaft
  - **State DB**: CouchDB (예정) / GoLevelDB (기본)
  - **Chaincode**: Go 언어 기반 (`sto_cc`)

## 🛠️ 필수 요구 사항 (Prerequisites)

이 프로젝트를 실행하기 위해 다음 환경이 필수적입니다. **특히 Docker Desktop 버전**에 주의해 주세요.

- **OS**: Windows 10/11 (WSL2 Ubuntu 20.04/22.04 환경 권장)
- **Docker Desktop**: **v4.49.0 권장** (최신 v4.56+ 버전은 Fabric과 호환성 문제로 'Broken pipe' 에러 발생 가능)
- **Go**: v1.20 이상
- **Hyperledger Fabric Binaries**: `bin/` 폴더에 `peer`, `orderer`, `configtxgen` 등이 포함되어 있어야 함.

## 🚀 실행 방법 (Getting Started)

### 1. 네트워크 시작 (초기화 및 실행)
기존 컨테이너와 인증서를 모두 정리하고 네트워크를 깨끗한 상태로 다시 시작합니다.
**권한 문제 방지를 위해 자동으로 `sudo`를 사용하여 아티팩트를 정리합니다.**

```bash
# 실행 권한 부여
chmod +x *.sh scripts/*.sh

# 네트워크 재시작 스크립트 실행
./restart.sh
