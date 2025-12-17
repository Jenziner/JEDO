package main

import (
    "log"
    "net/http"
    "github.com/gorilla/mux"
    "path/filepath"
    "os"

    "jedo-api/routes"    
    "jedo-api/config"
)

func main() {
    configPath := "config/fabric-config.yaml"
    if len(os.Args) > 1 {
        configPath = os.Args[1]
    }

    err := InitializeFabricServiceProvider(configPath)
    if err != nil {
        log.Fatalf("Failed to initialize Fabric Smart Client: %v", err)
    }

    router := mux.NewRouter()

    router.HandleFunc("/api/user/register", routes.RegisterUser).Methods("POST")
    router.HandleFunc("/api/user/authenticate", routes.AuthenticateUser).Methods("POST")

    log.Println("Server running on port 3000")
    log.Fatal(http.ListenAndServe(":3000", router))
}
