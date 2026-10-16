package service

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WSMessage 通用 WebSocket 消息结构。
type WSMessage struct {
	Type     string      `json:"type"`                // register | heartbeat_update | device_status_update | dispense_command | dispense_result | ack
	Role     string      `json:"role,omitempty"`      // website | simulator
	DeviceID string      `json:"device_id,omitempty"`
	From     string      `json:"from,omitempty"`      // server | simulator | website
	Data     interface{} `json:"data,omitempty"`
	// 以下字段供不同消息类型使用
	Message string `json:"message,omitempty"`
}

// WSClient 单个 WebSocket 连接。
type WSClient struct {
	hub      *Hub
	conn     *websocket.Conn
	send     chan []byte
	role     string
	deviceID string
}

// Hub 维护所有 WebSocket 客户端连接，支持注册、注销和广播。
type Hub struct {
	mu         sync.RWMutex
	clients    map[*WSClient]bool
	register   chan *WSClient
	unregister chan *WSClient
}

var hub *Hub

// InitHub 初始化全局 WebSocket Hub。
func InitHub() *Hub {
	if hub != nil {
		return hub
	}
	hub = &Hub{
		clients:    make(map[*WSClient]bool),
		register:   make(chan *WSClient, 16),
		unregister: make(chan *WSClient, 16),
	}
	go hub.run()
	log.Println("🌐 WebSocket Hub started")
	return hub
}

// GetHub 返回全局 Hub（用于在业务代码中发送消息）。
func GetHub() *Hub {
	if hub == nil {
		return InitHub()
	}
	return hub
}

func (h *Hub) run() {
	for {
		select {
		case c := <-h.register:
			h.mu.Lock()
			h.clients[c] = true
			h.mu.Unlock()
			log.Printf("🔌 WS client registered: role=%s device_id=%s (total=%d)", c.role, c.deviceID, len(h.clients))
		case c := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[c]; ok {
				delete(h.clients, c)
				close(c.send)
			}
			h.mu.Unlock()
			log.Printf("🔌 WS client unregistered (remaining=%d)", len(h.clients))
		}
	}
}

func (h *Hub) Register(c *WSClient)  { h.register <- c }
func (h *Hub) Unregister(c *WSClient) { h.unregister <- c }

// Broadcast 向所有客户端广播消息。
func (h *Hub) Broadcast(msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("❌ WS marshal error: %v", err)
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		select {
		case c.send <- data:
		default:
			log.Printf("⚠️ WS client send buffer full, dropping message")
		}
	}
}

// SendToRole 向指定角色的客户端发送消息（website / simulator）。
func (h *Hub) SendToRole(role string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		if c.role == role {
			select {
			case c.send <- data:
			default:
			}
		}
	}
}

// SendToDevice 向绑定特定 device_id 的模拟器发送消息。
func (h *Hub) SendToDevice(deviceID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		if c.role == "simulator" && c.deviceID == deviceID {
			select {
			case c.send <- data:
			default:
			}
		}
	}
}

// ClientCount 返回当前连接数。
func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// ReadPump 在客户端连接上读取消息，识别 register 命令更新角色。
func (c *WSClient) ReadPump() {
	defer func() {
		c.hub.Unregister(c)
		_ = c.conn.Close()
	}()
	c.conn.SetReadLimit(64 * 1024)
	_ = c.conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	})
	for {
		_, msg, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WS read error: %v", err)
			}
			break
		}
		var m WSMessage
		if err := json.Unmarshal(msg, &m); err != nil {
			continue
		}
		// 处理 register
		if m.Type == "register" {
			if m.Role != "" {
				c.role = m.Role
			}
			if m.DeviceID != "" {
				c.deviceID = m.DeviceID
			}
			// 重新注册以便更新角色
			c.hub.mu.Lock()
			delete(c.hub.clients, c)
			c.hub.clients[c] = true
			c.hub.mu.Unlock()
			log.Printf("📝 WS register: role=%s device_id=%s", c.role, c.deviceID)
			// 回复 ack
			ack := WSMessage{
				Type:    "ack",
				Message: "registered",
				From:    "server",
			}
			ackData, _ := json.Marshal(ack)
			select {
			case c.send <- ackData:
			default:
			}
		}
	}
}

// WritePump 在客户端连接上写入消息，并定期发送 ping 保活。
func (c *WSClient) WritePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// NewClient 创建并启动一个 WebSocket 客户端的读写循环。
func NewClient(h *Hub, conn *websocket.Conn) *WSClient {
	c := &WSClient{
		hub:  h,
		conn: conn,
		send: make(chan []byte, 64),
	}
	h.Register(c)
	go c.WritePump()
	go c.ReadPump()
	return c
}
