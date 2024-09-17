package main

import (
	"fmt"
	"encoding/json"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// NFT struct
type NFT struct {
	ID     string `json:"id"`
	Owner  string `json:"owner"`
	Data   string `json:"data"`
}

// SmartContract provides functions for managing NFTs
type SmartContract struct {
	contractapi.Contract
}

// CreateNFT (Mint) creates a new NFT
func (s *SmartContract) CreateNFT(ctx contractapi.TransactionContextInterface, id string, owner string, data string) error {
	// Prüfen, ob NFT mit dieser ID bereits existiert
	exists, err := s.NFTExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the NFT with ID %s already exists", id)
	}

	// Neues NFT-Objekt erstellen
	nft := NFT{
		ID:    id,
		Owner: owner,
		Data:  data,
	}

	// NFT-Objekt in JSON serialisieren
	nftAsBytes, err := json.Marshal(nft)
	if err != nil {
		return err
	}

	// NFT in die Blockchain schreiben
	return ctx.GetStub().PutState(id, nftAsBytes)
}

// TransferNFT transfers ownership of an NFT
func (s *SmartContract) TransferNFT(ctx contractapi.TransactionContextInterface, id string, newOwner string) error {
	// Prüfen, ob das NFT existiert
	nft, err := s.ReadNFT(ctx, id)
	if err != nil {
		return err
	}

	// Besitzer aktualisieren
	nft.Owner = newOwner

	// NFT-Objekt in JSON serialisieren
	nftAsBytes, err := json.Marshal(nft)
	if err != nil {
		return err
	}

	// Aktualisiertes NFT in die Blockchain schreiben
	return ctx.GetStub().PutState(id, nftAsBytes)
}

// ReadNFT queries an NFT by its ID
func (s *SmartContract) ReadNFT(ctx contractapi.TransactionContextInterface, id string) (*NFT, error) {
	// NFT aus der Blockchain holen
	nftAsBytes, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read NFT with ID %s: %v", id, err)
	}
	if nftAsBytes == nil {
		return nil, fmt.Errorf("NFT with ID %s does not exist", id)
	}

	// NFT deserialisieren
	var nft NFT
	err = json.Unmarshal(nftAsBytes, &nft)
	if err != nil {
		return nil, err
	}

	return &nft, nil
}

// NFTExists checks if an NFT exists
func (s *SmartContract) NFTExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	// Prüfen, ob das NFT existiert
	nftAsBytes, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, err
	}
	return nftAsBytes != nil, nil
}

func main() {
	// Chaincode-Instanz starten
	chaincode, err := contractapi.NewChaincode(new(SmartContract))
	if err != nil {
		fmt.Printf("Error creating NFT chaincode: %s", err)
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting NFT chaincode: %s", err)
	}
}
