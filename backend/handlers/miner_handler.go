package handlers

import (
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"

	"miner-server/services"
)

// MinerHandler handles miner-related HTTP requests
type MinerHandler struct {
	svc         *services.MinerService
	defaultBase string
}

func NewMinerHandler(svc *services.MinerService) *MinerHandler {
	base := os.Getenv("SCAN_BASE")
	if base == "" {
		base = "192.168.1"
	}
	return &MinerHandler{
		svc:         svc,
		defaultBase: base,
	}
}

func (h *MinerHandler) Register(r *gin.Engine) {
	r.GET("/health", h.Health)
	r.GET("/miners/scan", h.Scan)
}

func (h *MinerHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *MinerHandler) Scan(c *gin.Context) {
	base := c.Query("base")
	if base == "" {
		base = h.defaultBase
	}

	req := services.ScanRequest{
		Base:      base,
		Start:     getQueryInt(c, "start", 100),
		End:       getQueryInt(c, "end", 110),
		TimeoutMs: getQueryInt(c, "timeout_ms", 500),
		Workers:   getQueryInt(c, "workers", 30),
	}

	resp, err := h.svc.Scan(req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp)
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
