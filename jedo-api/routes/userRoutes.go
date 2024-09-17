package routes

import (
	"encoding/json"
	"jedo-api/tokenmanager"
	"fmt"
	"net/http"

	// Importiere die benötigten Pakete aus dem Fabric Smart Client und dem Token SDK
	view "github.com/hyperledger-labs/fabric-smart-client/platform/view"
	view2 "github.com/hyperledger-labs/fabric-smart-client/platform/view/view"
	"github.com/hyperledger-labs/fabric-token-sdk/token"
)

// Globale Variable für den Fabric Smart Client
var fabricServiceProvider view.ServiceProvider

// User Struct
type User struct {
	UUID     string `json:"uuid"`
	Password string `json:"password"`
	Balance  int    `json:"balance"`
	OTP      []string `json:"otp"`
}

// RegisterUser registers a new user and mints an NFT for them
func RegisterUser(w http.ResponseWriter, r *http.Request) {
	var user User
	err := json.NewDecoder(r.Body).Decode(&user)
	if err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	// create NFT-Data
	nftData := fmt.Sprintf(`{
		"description": "User NFT",
		"balance": %d,
		"otp": %s
	}`, user.Balance, otpArrayToString(user.OTP))

	// Mint NFT mit UUID als Besitzer und nftData als den Daten
	txID, err := tokenmanager.MintNFT(user.UUID, nftData)
	if err != nil {
		http.Error(w, "Failed to mint NFT: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Erfolgreiche Registrierung des Benutzers
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"message": "User registered successfully",
		"txID":    txID,
	})
}

// otpArrayToString konvertiert das OTP-Array in eine JSON-kompatible Zeichenkette
func otpArrayToString(otpArray []string) string {
	otpJSON, _ := json.Marshal(otpArray)
	return string(otpJSON)
}

// Diese Funktion holt den Kontext des Fabric Smart Clients
func getFabricContext() view2.Context {
	// Hole den Service Provider und nutze ihn, um den Kontext zu bekommen
	return fabricServiceProvider.Context()
}

// Initialisiere den Fabric-Client (dies muss einmal in deiner Anwendung gemacht werden)
func InitializeFabricServiceProvider(configPath string) error {
	// Erstelle und initialisiere den Fabric Service Provider
	sp, err := view.NewServiceProvider(configPath)
	if err != nil {
		return fmt.Errorf("failed to initialize Fabric Service Provider: %v", err)
	}
	fabricServiceProvider = sp
	return nil
}
