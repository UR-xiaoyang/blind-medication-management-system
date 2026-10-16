package handler

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
	"blind-medication-backend/internal/service"
)

// ========== Device CRUD ==========

func GetDevices(c *gin.Context) {
	var devices []model.Device
	query := model.DB.Model(&model.Device{})

	if patientID := c.Query("patient_id"); patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}

	query.Order("created_at DESC").Find(&devices)

	// 标记在线状态
	type DeviceWithBattery struct {
		model.Device
		Battery int `json:"battery"`
	}
	onlineMap := service.GetOnlineDevices()
	var result []DeviceWithBattery
	for _, d := range devices {
		dwb := DeviceWithBattery{Device: d}
		if info, ok := onlineMap[d.DeviceID]; ok {
			dwb.Status = "online"
			dwb.Battery = info.Battery
		}
		result = append(result, dwb)
	}

	c.JSON(http.StatusOK, gin.H{"data": result})
}

func GetDevice(c *gin.Context) {
	id := c.Param("id")
	var device model.Device
	if err := model.DB.First(&device, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "设备不存在"})
		return
	}

	// 附加实时在线信息（使用扩展结构体返回电量等信息）
	onlineMap := service.GetOnlineDevices()
	result := struct {
		model.Device
		Battery int `json:"battery"`
	}{Device: device}
	if info, ok := onlineMap[device.DeviceID]; ok {
		result.Status = "online"
		result.Battery = info.Battery
	}

	c.JSON(http.StatusOK, result)
}

func CreateDevice(c *gin.Context) {
	var device model.Device
	if err := c.ShouldBindJSON(&device); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	device.Status = "offline"
	if device.DispenseMode == "" {
		device.DispenseMode = "fixed_medicine"
	}
	// 自动生成 device_token (若客户端未提供)
	if device.DeviceToken == "" {
		tok, err := model.GenerateDeviceToken()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "生成 token 失败"})
			return
		}
		device.DeviceToken = tok
	}

	if err := model.DB.Create(&device).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, device)
}

func UpdateDevice(c *gin.Context) {
	id := c.Param("id")
	var device model.Device
	if err := model.DB.First(&device, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "设备不存在"})
		return
	}

	if err := c.ShouldBindJSON(&device); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	model.DB.Save(&device)
	c.JSON(http.StatusOK, device)
}

func DeleteDevice(c *gin.Context) {
	id := c.Param("id")
	model.DB.Delete(&model.Device{}, id)
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

// ========== 设备实时状态 ==========

func GetDeviceStatus(c *gin.Context) {
	deviceID := c.Param("id")
	onlineMap := service.GetOnlineDevices()

	info, ok := onlineMap[deviceID]
	if !ok {
		c.JSON(http.StatusOK, gin.H{
			"device_id": deviceID,
			"status":    "offline",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"device_id":   info.DeviceID,
		"status":      "online",
		"last_seen":   info.LastSeen,
		"battery":     info.Battery,
		"temperature": info.Temperature,
		"slot_states": info.SlotStates,
		"ip_address":  info.IPAddress,
		"signal":      info.Signal,
	})
}

func GetDeviceHeartbeats(c *gin.Context) {
	deviceID := c.Param("id")
	limit := 50

	var heartbeats []model.DeviceHeartbeat
	model.DB.Where("device_id = ?", deviceID).
		Order("timestamp DESC").
		Limit(limit).
		Find(&heartbeats)

	c.JSON(http.StatusOK, gin.H{"data": heartbeats})
}

// SendDeviceCommand 管理员触发的"出药测试"按钮。
//
// 旧行为：把命令发布到 MQTT topic，由 broker 转发到 ESP32。
// 新行为：服务器不再向 ESP32 推送任何控制命令（ESP32 完全自治，从
// 语音/PIR/按钮等本地输入自行决定何时出药），该接口改为：
//  1. 写一条 manual_request 事件日志到数据库，供事后审计
//  2. 写一条 dispense_request 类型的 EventLog 通知志愿者/管理员
//  3. 立即返回 200，不阻塞管理 UI
//
// 这样保留了原有"出药测试"按钮的 UX（点击后会有"已记录"的反馈），
// 同时与新的"设备→服务器单向"模型保持一致。
func SendDeviceCommand(c *gin.Context) {
	deviceID := c.Param("id")
	var req struct {
		Action  string                 `json:"action" binding:"required"`
		Payload map[string]interface{} `json:"payload"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 找到设备，必要时附带患者ID
	var device model.Device
	if err := model.DB.Where("device_id = ?", deviceID).First(&device).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "设备不存在"})
		return
	}

	content := req.Action
	if pkg, ok := req.Payload["dose_package_id"]; ok {
		content = content + " (dose_package_id=" + toString(pkg) + ")"
	}

	if device.PatientID != nil {
		model.DB.Create(&model.EventLog{
			PatientID:  *device.PatientID,
			DeviceID:   deviceID,
			EventType:  "manual_request",
			Title:      "管理员请求 " + req.Action,
			Content:    content,
			Severity:   "info",
			Source:     "admin",
			Status:     "pending",
			OccurredAt: time.Now(),
		})
	}

	// 同时尝试通过 WebSocket 通知管理员界面刷新（不是给设备）
	service.GetHub().Broadcast(service.WSMessage{
		Type:     "manual_command",
		From:     "server",
		DeviceID: deviceID,
		Data: map[string]interface{}{
			"action":  req.Action,
			"payload": req.Payload,
		},
	})

	c.JSON(http.StatusOK, gin.H{
		"message": "请求已记录，设备将自行决定是否执行",
		"action":  req.Action,
	})
}

func toString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	if f, ok := v.(float64); ok {
		return fmt.Sprintf("%.0f", f)
	}
	return ""
}
