package routes

import (
    "encoding/json"
    "jedo-api/tokenmanager"
    "fmt"
    "net/http"

    // Verwende view2 für den Kontext und den ServiceProvider
    view2 "github.com/hyperledger-labs/fabric-smart-client/platform/view/view"
)

// Globale Variable für den Fabric Smart Client
var fabricServiceProvider view2.ServiceProvider

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

    // Hole den Fabric-Kontext
    ctx := getFabricContext()

    // Hole das IssuerWallet und die Identity
    issuerWallet := tokenmanager.GetIssuerWallet(ctx)
    userIdentity := tokenmanager.GetUserIdentity(user.UUID)

    // Ruf MintNFT mit den richtigen Parametern auf
    txID, err := tokenmanager.MintNFT(ctx, issuerWallet, userIdentity, nftData)
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
    session := fabricServiceProvider.Session() // Abrufen der Session
    return session.Context() // Den Kontext aus der Session abrufen
}

// GetNFT retrieves an NFT for a given user ID
func GetNFT(w http.ResponseWriter, r *http.Request) {
    userID := r.URL.Query().Get("userID")
    if userID == "" {
        http.Error(w, "Missing userID", http.StatusBadRequest)
        return
    }

    // Call the Fabric API to retrieve the NFT
    nft, err := tokenmanager.ReadNFT(userID)
    if err != nil {
        http.Error(w, "Failed to read NFT: "+err.Error(), http.StatusInternalServerError)
        return
    }

    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(nft)
}
