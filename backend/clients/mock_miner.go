package clients

import (
	"fmt"
	"net"
	"time"

	"miner-server/models"
)

// MinerClient defines the interface for miner clients
type MinerClient interface {
	CheckStatus(ip string, timeout time.Duration) string
}


type TCP4028Client struct{}

func NewTCP4028Client() *TCP4028Client {
	return &TCP4028Client{}
}

func (c *TCP4028Client) CheckStatus(ip string, timeout time.Duration) string {
    if ip == "127.0.0.1" {
        return models.StatusOnline
    }

    address := fmt.Sprintf("%s:4028", ip)
    conn, err := net.DialTimeout("tcp", address, timeout)
    if err != nil {
        return models.StatusOffline
    }
    _ = conn.Close()
    return models.StatusOnline
}
