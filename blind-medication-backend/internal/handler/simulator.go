package handler

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
	"blind-medication-backend/internal/service"
)

// SimulatorPublishRequest 模拟器发布请求。
type SimulatorPublishRequest struct {
	DeviceID    string          `json:"device_id" binding:"required"`
	TopicSuffix string          `json:"topic_suffix" binding:"required"` // heartbeat | status | dispense_result | sensor | sos
	Payload     json.RawMessage `json:"payload" binding:"required"`
	ForwardMQTT bool            `json:"forward_mqtt"`
}

// SimulatorPublish 接收模拟器消息并转发到 MQTT。
func SimulatorPublish(c *gin.Context) {
	var req SimulatorPublishRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	validSuffixes := map[string]bool{
		"heartbeat":       true,
		"status":          true,
		"dispense_result": true,
		"sensor":          true,
		"sos":             true,
	}
	if !validSuffixes[req.TopicSuffix] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的 topic_suffix，可选: heartbeat, status, dispense_result, sensor, sos"})
		return
	}

	if err := service.ApplySimulatedMessage(req.TopicSuffix, req.Payload); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "模拟数据写入失败: " + err.Error()})
		return
	}

	topic := "blind_medication/devices/" + req.DeviceID + "/" + req.TopicSuffix
	forwarded := false
	var mqttError string
	if req.ForwardMQTT {
		if err := service.PublishRaw(topic, req.Payload); err != nil {
			mqttError = err.Error()
		} else {
			forwarded = true
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":       "模拟数据已写入",
		"topic":         topic,
		"forwarded":     forwarded,
		"mqtt_error":    mqttError,
		"local_applied": true,
	})
}

// SimulatorGetDevices 获取已注册设备列表，供模拟器选择。
func SimulatorGetDevices(c *gin.Context) {
	var devices []model.Device
	if err := model.DB.Find(&devices).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}
	c.JSON(http.StatusOK, devices)
}

// SimulatorGetPatients 获取患者列表（供模拟器选择绑定）
func SimulatorGetPatients(c *gin.Context) {
	var patients []model.Patient
	if err := model.DB.Order("id ASC").Find(&patients).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}
	c.JSON(http.StatusOK, patients)
}

// SimulatorGetDosePackages 获取某患者的剂次包列表（供模拟器选择）
func SimulatorGetDosePackages(c *gin.Context) {
	patientID := c.Query("patient_id")
	query := model.DB.Preload("Items.Medication").Order("package_index ASC")
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}
	var pkgs []model.DosePackage
	if err := query.Find(&pkgs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}
	c.JSON(http.StatusOK, pkgs)
}
