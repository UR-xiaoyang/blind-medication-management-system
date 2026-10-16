package handler

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"blind-medication-backend/internal/service"
)

var wsUpgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		// 允许任意来源（开发环境），生产应做白名单
		return true
	},
}

// WebSocketHandler 处理 WebSocket 升级请求。
// 前端连上后第一帧应发送 {"type":"register","role":"website|simulator","device_id":"..."}。
func WebSocketHandler(c *gin.Context) {
	conn, err := wsUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WS upgrade failed: %v", err)
		return
	}
	hub := service.GetHub()
	service.NewClient(hub, conn)
	log.Printf("🔗 New WS connection from %s", c.Request.RemoteAddr)
}
