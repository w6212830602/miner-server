package models

type Miner struct {
	IP     string `json:"ip"`
	Status string `json:"status"`
}

const (
	StatusOnline  = "online"
	StatusOffline = "offline"
)
