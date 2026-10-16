package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/config"
	"blind-medication-backend/internal/handler"
	"blind-medication-backend/internal/middleware"
	"blind-medication-backend/internal/model"
	"blind-medication-backend/internal/service"
)

func main() {
	// 加载配置
	cfgPath := "config/config.yaml"
	if envPath := os.Getenv("CONFIG_PATH"); envPath != "" {
		cfgPath = envPath
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		log.Fatalf("❌ Failed to load config: %v", err)
	}

	// 初始化数据库
	if err := model.InitDB(&cfg.Database); err != nil {
		log.Fatalf("❌ Failed to init database: %v", err)
	}

	// 初始化JWT
	middleware.InitJWT(&cfg.JWT)

	// 初始化MQTT
	if err := service.InitMQTT(&cfg.MQTT); err != nil {
		log.Printf("⚠️ MQTT init failed (continuing without MQTT): %v", err)
	} else {
		// 启动设备离线检测
		go service.CheckOverdueDevices()
	}

	// 初始化 WebSocket Hub（支持无 MQTT 时独立工作）
	service.InitHub()

	// 初始化Gin
	gin.SetMode(cfg.Server.Mode)
	r := gin.Default()

	// CORS配置
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// 健康检查
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "blind-medication-backend"})
	})

	// 注册路由
	handler.SetupRoutes(r)

	// 优雅退出
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-quit
		log.Println("🛑 Shutting down...")
		service.StopMQTT()
		os.Exit(0)
	}()

	// 启动服务
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	log.Printf("🚀 Server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("❌ Server failed: %v", err)
	}
}
