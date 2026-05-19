package main

import (
	"fmt"
	"net/http"
)

const stripeKey = "sk_live_DEMO_FAKE_KEY_FOR_REMEDIATION_DEMO_DO_NOT_USE"

func chargeHandler(w http.ResponseWriter, r *http.Request) {
	req, _ := http.NewRequest("POST", "https://api.stripe.com/v1/charges", nil)
	req.Header.Set("Authorization", "Bearer "+stripeKey)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	fmt.Fprintf(w, "stripe responded: %d", resp.StatusCode)
}

func main() {
	http.HandleFunc("/charge", chargeHandler)
	http.ListenAndServe(":8080", nil)
}
