package main

import (
	"fmt"

	"github.com/gin-gonic/gin"

	"miner-server/clients"
	"miner-server/handlers"
	"miner-server/services"
)

func main() {
	r := gin.Default()

	// CORS middleware
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

	minerClient := clients.NewTCP4028Client()
	minerService := services.NewMinerService(minerClient)
	minerHandler := handlers.NewMinerHandler(minerService)

	minerHandler.Register(r)

	fmt.Println("Server running at http://localhost:8080")
	_ = r.Run(":8080")
}
