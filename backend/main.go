package main

import (
	"fmt"
	"net"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// Miner 定義礦機結構
type Miner struct {
	IP     string `json:"ip"`
	Status string `json:"status"`
}

// scanMiner 嘗試連接礦機的 4028 端口
func scanMiner(ip string, timeout time.Duration) string {
	address := fmt.Sprintf("%s:4028", ip)
	conn, err := net.DialTimeout("tcp", address, timeout)
	if err != nil {
		return "Offline"
	}
	_ = conn.Close()
	return "Online"
}

func getQueryInt(c *gin.Context, key string, def int) int {
	v := c.Query(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func main() {
	r := gin.Default()

	// 更完整的 CORS（讓 Flutter Web 順利）
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// 預設值可用環境變數控制（demo 前你可以快速改）
	defaultBase := os.Getenv("SCAN_BASE") // e.g. "192.168.1"
	if defaultBase == "" {
		defaultBase = "192.168.1"
	}

r.GET("/scan", func(c *gin.Context) {
    // ✅ 用 query 或 env 決定掃描範圍（demo 現場非常需要）
    base := c.Query("base")
    if base == "" {
        base = defaultBase // 來自 SCAN_BASE env
    }

    start := getQueryInt(c, "start", 100)
    end := getQueryInt(c, "end", 110)

    timeoutMs := getQueryInt(c, "timeout_ms", 500)
    timeout := time.Duration(timeoutMs) * time.Millisecond

    workers := getQueryInt(c, "workers", 30)
    if workers < 1 {
        workers = 1
    }

    type job struct{ ip string }
    jobs := make(chan job)
    results := make(chan Miner)

    for w := 0; w < workers; w++ {
        go func() {
            for j := range jobs {
                status := scanMiner(j.ip, timeout)
                results <- Miner{IP: j.ip, Status: status}
            }
        }()
    }

    total := end - start + 1

    go func() {
        for i := start; i <= end; i++ {
            ip := fmt.Sprintf("%s.%d", base, i)
            jobs <- job{ip: ip}
        }
        close(jobs)
    }()

    miners := make([]Miner, 0, total)
    for i := 0; i < total; i++ {
        miners = append(miners, <-results)
    }

    c.JSON(200, gin.H{
        "base":       base,
        "start":      start,
        "end":        end,
        "timeout_ms": timeoutMs,
        "workers":    workers,
        "miners":     miners,
    })
})
	fmt.Println("Server 啟動於 http://localhost:8080")
	_ = r.Run(":8080")
}
