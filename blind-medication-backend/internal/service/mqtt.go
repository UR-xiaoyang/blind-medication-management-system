package service

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"

	"blind-medication-backend/internal/config"
	"blind-medication-backend/internal/model"
)

// ESP32Message ESP32 / 模拟器上报消息。
type ESP32Message struct {
	DeviceID      string  `json:"device_id"`
	Type          string  `json:"type"`
	Status        string  `json:"status,omitempty"`
	Timestamp     int64   `json:"timestamp"`
	Battery       int     `json:"battery,omitempty"`
	Temperature   float64 `json:"temperature,omitempty"`
	SlotStates    string  `json:"slot_states,omitempty"`
	SlotIndex     int     `json:"slot_index,omitempty"`
	PackageIndex  int     `json:"package_index,omitempty"`
	DosePackageID uint    `json:"dose_package_id,omitempty"`
	PatientID     uint    `json:"patient_id,omitempty"`
	Success       bool    `json:"success,omitempty"`
	Error         string  `json:"error,omitempty"`
	WiFiRSSI      int     `json:"wifi_rssi,omitempty"`
	IPAddress     string  `json:"ip_address,omitempty"`
	Firmware      string  `json:"firmware,omitempty"`
	Reason        string  `json:"reason,omitempty"`
}

// DispenseCommand MQTT 出药指令 (legacy, 保留兼容)。
type DispenseCommand struct {
	DosePackageID uint   `json:"dose_package_id,omitempty"`
	PackageIndex  int    `json:"package_index,omitempty"`
	SlotIndex     int    `json:"slot_index,omitempty"`
	Action        string `json:"action"`
	Timestamp     int64  `json:"timestamp"`
}

// DeviceStatusSubscriber 设备状态更新回调。
type DeviceStatusSubscriber func(deviceID string, status string)

var (
	mqttClient mqtt.Client
	cfg        *config.MQTTConfig
	// 在线设备管理
	onlineDevices = make(map[string]*DeviceOnlineInfo)
	devicesMu     sync.RWMutex
	// 状态订阅者
	subscribers []DeviceStatusSubscriber
)

type DeviceOnlineInfo struct {
	DeviceID    string
	LastSeen    time.Time
	Battery     int
	Temperature float64
	SlotStates  string
	IPAddress   string
	Signal      int
}

func InitMQTT(mqttCfg *config.MQTTConfig) error {
	cfg = mqttCfg

	opts := mqtt.NewClientOptions()
	opts.AddBroker(cfg.Broker)
	opts.SetClientID(cfg.ClientID)
	if cfg.Username != "" {
		opts.SetUsername(cfg.Username)
	}
	if cfg.Password != "" {
		opts.SetPassword(cfg.Password)
	}
	opts.SetAutoReconnect(true)
	opts.SetKeepAlive(60 * time.Second)
	opts.SetOnConnectHandler(onConnect)
	opts.SetConnectionLostHandler(func(client mqtt.Client, err error) {
		log.Printf("⚠️ MQTT connection lost: %v", err)
	})

	mqttClient = mqtt.NewClient(opts)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		return fmt.Errorf("mqtt connect failed: %w", token.Error())
	}

	log.Println("✅ MQTT connected successfully")
	return nil
}

func onConnect(client mqtt.Client) {
	log.Println("🔗 MQTT connected, subscribing to topics...")

	topic := cfg.TopicPrefix + "devices/+/heartbeat"
	client.Subscribe(topic, 1, handleHeartbeat)

	topic = cfg.TopicPrefix + "devices/+/dispense_result"
	client.Subscribe(topic, 1, handleDispenseResult)

	topic = cfg.TopicPrefix + "devices/+/sensor"
	client.Subscribe(topic, 1, handleSensorData)

	topic = cfg.TopicPrefix + "devices/+/status"
	client.Subscribe(topic, 1, handleDeviceStatus)
}

func handleHeartbeat(client mqtt.Client, msg mqtt.Message) {
	var hb ESP32Message
	if err := json.Unmarshal(msg.Payload(), &hb); err != nil {
		log.Printf("❌ Parse heartbeat error: %v", err)
		return
	}
	if err := ApplyHeartbeat(hb); err != nil {
		log.Printf("❌ Apply heartbeat failed: %v", err)
	}
}

func handleDispenseResult(client mqtt.Client, msg mqtt.Message) {
	var result ESP32Message
	if err := json.Unmarshal(msg.Payload(), &result); err != nil {
		log.Printf("❌ Parse dispense result error: %v", err)
		return
	}
	now := time.Now()
	today := now.Format("2006-01-02")
	if err := ApplyDispenseResult(result); err != nil {
		log.Printf("❌ Apply dispense result failed: %v", err)
		return
	}
	log.Printf("💊 Dispense result from %s package %d dose_package=%d: success=%v date=%s",
		result.DeviceID, result.PackageIndex, result.DosePackageID, result.Success, today)
}

func handleSensorData(client mqtt.Client, msg mqtt.Message) {
	var data ESP32Message
	if err := json.Unmarshal(msg.Payload(), &data); err != nil {
		return
	}
	if err := ApplySensor(data); err != nil {
		log.Printf("❌ Apply sensor failed: %v", err)
	}
}

func handleDeviceStatus(client mqtt.Client, msg mqtt.Message) {
	var status ESP32Message
	if err := json.Unmarshal(msg.Payload(), &status); err != nil {
		return
	}
	if err := ApplyStatus(status); err != nil {
		log.Printf("❌ Apply status failed: %v", err)
	}
}

// ========== 公开接口 ==========

// SendDispenseCommand 发送一次服药包出药指令 (MQTT, 兼容旧设备)。
func SendDispenseCommand(deviceID string, dosePackageID uint, packageIndex int) error {
	if mqttClient == nil || !mqttClient.IsConnected() {
		return fmt.Errorf("mqtt not connected")
	}
	topic := cfg.TopicPrefix + "devices/" + deviceID + "/command"
	cmd := DispenseCommand{
		DosePackageID: dosePackageID,
		PackageIndex:  packageIndex,
		SlotIndex:     packageIndex,
		Action:        "dispense_dose_package",
		Timestamp:     time.Now().Unix(),
	}
	payload, _ := json.Marshal(cmd)

	token := mqttClient.Publish(topic, 1, false, payload)
	token.Wait()
	if token.Error() != nil {
		return fmt.Errorf("publish dispense command failed: %w", token.Error())
	}
	return nil
}

// SendDeviceCommand 通用设备命令发布 (MQTT, 兼容旧设备)。
func SendDeviceCommand(deviceID, action string, payload map[string]interface{}) error {
	if mqttClient == nil || !mqttClient.IsConnected() {
		return fmt.Errorf("mqtt not connected")
	}
	topic := cfg.TopicPrefix + "devices/" + deviceID + "/command"
	msg := map[string]interface{}{
		"action":    action,
		"timestamp": time.Now().Unix(),
	}
	for k, v := range payload {
		msg[k] = v
	}
	data, _ := json.Marshal(msg)
	token := mqttClient.Publish(topic, 1, false, data)
	token.Wait()
	return token.Error()
}

// GetOnlineDevices 获取在线设备列表
func GetOnlineDevices() map[string]*DeviceOnlineInfo {
	devicesMu.RLock()
	defer devicesMu.RUnlock()

	result := make(map[string]*DeviceOnlineInfo, len(onlineDevices))
	for k, v := range onlineDevices {
		cp := *v
		result[k] = &cp
	}
	return result
}

// IsDeviceOnline 判断设备是否在线
func IsDeviceOnline(deviceID string) bool {
	devicesMu.RLock()
	defer devicesMu.RUnlock()
	info, ok := onlineDevices[deviceID]
	if !ok {
		return false
	}
	// 超过120秒未心跳视为离线
	return time.Since(info.LastSeen) < 120*time.Second
}

// ApplySimulatedMessage 模拟器入口 (HTTP /api/simulator/publish)。
// 行为与 HTTP /api/device/* 共享 device_events.go 中的实现。
func ApplySimulatedMessage(topicSuffix string, payload []byte) error {
	var msg ESP32Message
	if err := json.Unmarshal(payload, &msg); err != nil {
		return fmt.Errorf("parse simulator payload failed: %w", err)
	}
	if msg.DeviceID == "" {
		return fmt.Errorf("device_id is required")
	}

	switch topicSuffix {
	case "heartbeat":
		return ApplyHeartbeat(msg)
	case "status":
		return ApplyStatus(msg)
	case "dispense_result":
		return ApplyDispenseResult(msg)
	case "sensor":
		return ApplySensor(msg)
	case "sos":
		return ApplySOS(msg)
	default:
		return fmt.Errorf("unsupported simulator topic_suffix: %s", topicSuffix)
	}
}

// createAutoEventLog 根据出药结果自动创建事件日志
func createAutoEventLog(patientID uint, deviceID string, result ESP32Message) {
	now := time.Now()
	if result.Success {
		model.DB.Create(&model.EventLog{
			PatientID:  patientID,
			DeviceID:   deviceID,
			EventType:  "dispense_success",
			Title:      "出药成功",
			Content:    fmt.Sprintf("药包编号: %d, 剂次包ID: %d", result.PackageIndex, result.DosePackageID),
			Severity:   "info",
			Source:     "device",
			Status:     "pending",
			OccurredAt: now,
		})
	} else {
		errMsg := result.Error
		if errMsg == "" {
			errMsg = "未知错误"
		}
		model.DB.Create(&model.EventLog{
			PatientID:  patientID,
			DeviceID:   deviceID,
			EventType:  "dispense_fail",
			Title:      "出药失败",
			Content:    fmt.Sprintf("药包编号: %d, 剂次包ID: %d, 错误: %s", result.PackageIndex, result.DosePackageID, errMsg),
			Severity:   "error",
			Source:     "device",
			Status:     "pending",
			OccurredAt: now,
		})
	}
}

// SubscribeDeviceStatus 订阅设备状态变更
func SubscribeDeviceStatus(sub DeviceStatusSubscriber) {
	subscribers = append(subscribers, sub)
}

// CheckOverdueDevices 检查超时未心跳的设备，标记为离线
func CheckOverdueDevices() {
	ticker := time.NewTicker(30 * time.Second)
	for range ticker.C {
		devicesMu.Lock()
		for id, info := range onlineDevices {
			if time.Since(info.LastSeen) > 120*time.Second {
				delete(onlineDevices, id)
				model.DB.Model(&model.Device{}).Where("device_id = ?", id).Update("status", "offline")
				log.Printf("⚠️ Device %s marked offline (no heartbeat)", id)
			}
		}
		devicesMu.Unlock()
	}
}

// PublishRaw 向指定 topic 发布原始消息（供模拟器使用）
func PublishRaw(topic string, payload []byte) error {
	if mqttClient == nil || !mqttClient.IsConnected() {
		return fmt.Errorf("mqtt client not connected")
	}
	token := mqttClient.Publish(topic, 1, false, payload)
	token.Wait()
	return token.Error()
}

// StopMQTT 停止MQTT连接
func StopMQTT() {
	if mqttClient != nil && mqttClient.IsConnected() {
		mqttClient.Disconnect(1000)
	}
}
