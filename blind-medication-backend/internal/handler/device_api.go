package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
	"blind-medication-backend/internal/service"
)

// deviceAPIBase 设备→后端 HTTP 入口。所有路由都需通过
// middleware.DeviceAuthMiddleware 校验 X-Device-Token。
type deviceHeartbeatReq struct {
	Battery     int     `json:"battery"`
	Temperature float64 `json:"temperature"`
	SlotStates  string  `json:"slot_states"`
	WiFiRSSI    int     `json:"wifi_rssi"`
	IPAddress   string  `json:"ip_address"`
	Firmware    string  `json:"firmware"`
}

func DeviceHeartbeat(c *gin.Context) {
	var req deviceHeartbeatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	msg := service.ESP32Message{
		DeviceID:    c.GetString("device_id"),
		Type:        "heartbeat",
		Battery:     req.Battery,
		Temperature: req.Temperature,
		SlotStates:  req.SlotStates,
		WiFiRSSI:    req.WiFiRSSI,
		IPAddress:   req.IPAddress,
		Firmware:    req.Firmware,
	}
	if err := service.ApplyHeartbeat(msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type deviceStatusReq struct {
	Status string `json:"status" binding:"required"` // online | offline
}

func DeviceStatus(c *gin.Context) {
	var req deviceStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	msg := service.ESP32Message{
		DeviceID: c.GetString("device_id"),
		Type:     req.Status,
		Status:   req.Status,
	}
	if err := service.ApplyStatus(msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type deviceSensorReq struct {
	Temperature float64 `json:"temperature"`
	Extra       string  `json:"extra,omitempty"`
}

func DeviceSensor(c *gin.Context) {
	var req deviceSensorReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	msg := service.ESP32Message{
		DeviceID:    c.GetString("device_id"),
		Type:        "sensor",
		Temperature: req.Temperature,
		SlotStates:  req.Extra,
	}
	if err := service.ApplySensor(msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type deviceDispenseResultReq struct {
	Success       bool   `json:"success"`
	Error         string `json:"error"`
	PackageIndex  int    `json:"package_index"`
	SlotIndex     int    `json:"slot_index"`
	DosePackageID uint   `json:"dose_package_id"`
	SlotStates    string `json:"slot_states"`
}

func DeviceDispenseResult(c *gin.Context) {
	var req deviceDispenseResultReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	msg := service.ESP32Message{
		DeviceID:      c.GetString("device_id"),
		Type:          "dispense_result",
		Success:       req.Success,
		Error:         req.Error,
		PackageIndex:  req.PackageIndex,
		SlotIndex:     req.SlotIndex,
		DosePackageID: req.DosePackageID,
		SlotStates:    req.SlotStates,
	}
	if err := service.ApplyDispenseResult(msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type deviceSOSReq struct {
	Reason string `json:"reason"`
}

func DeviceSOS(c *gin.Context) {
	var req deviceSOSReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	msg := service.ESP32Message{
		DeviceID: c.GetString("device_id"),
		Type:     "sos",
		Reason:   req.Reason,
		Error:    req.Reason,
	}
	if err := service.ApplySOS(msg); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ========== 管理后台用：查询/重新生成设备 token ==========

// GetDeviceToken 由管理员调用，查看/复制设备的访问 token。
func GetDeviceToken(c *gin.Context) {
	id := c.Param("id")
	var device model.Device
	if err := model.DB.First(&device, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "设备不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":           device.ID,
		"device_id":    device.DeviceID,
		"device_token": device.DeviceToken,
	})
}

// RotateDeviceToken 生成一个新的 device_token 并写回数据库。旧 token
// 立即失效，ESP32 重新烧写新 token 之前无法上报。
func RotateDeviceToken(c *gin.Context) {
	id := c.Param("id")
	var device model.Device
	if err := model.DB.First(&device, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "设备不存在"})
		return
	}
	tok, err := model.GenerateDeviceToken()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "生成 token 失败"})
		return
	}
	if err := model.DB.Model(&device).Update("device_token", tok).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":           device.ID,
		"device_id":    device.DeviceID,
		"device_token": tok,
	})
}
