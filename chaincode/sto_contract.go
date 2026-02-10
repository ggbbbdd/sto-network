package main

import (
	"log"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type STOContract struct {
	contractapi.Contract
}

func (s *STOContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	log.Println("STO Ledger Initialized")
	return nil
}

func main() {
	assetChaincode, err := contractapi.NewChaincode(&STOContract{})
	if err != nil {
		log.Panicf("Error creating STO chaincode: %v", err)
	}

	if err := assetChaincode.Start(); err != nil {
		log.Panicf("Error starting STO chaincode: %v", err)
	}
}
