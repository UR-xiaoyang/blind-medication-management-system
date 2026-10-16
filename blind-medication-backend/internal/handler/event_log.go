package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
)

// ========== EventLog 事件日志 ==========

func GetEventLogs(c *gin.Context) {
	patientID := c.Query("patient_id")
	eventType := c.Query("event_type")
	severity := c.Query("severity")
	status := c.Query("status")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	query := model.DB.Model(&model.EventLog{})
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}
	if eventType != "" {
		query = query.Where("event_type = ?", eventType)
	}
	if severity != "" {
		query = query.Where("severity = ?", severity)
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}

	var total int64
	query.Count(&total)

	var logs []model.EventLog
	query.Preload("Patient").Preload("Handler").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("occurred_at DESC").
		Find(&logs)

	c.JSON(http.StatusOK, gin.H{
		"data":      logs,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

func GetEventLog(c *gin.Context) {
	id := c.Param("id")
	var log model.EventLog
	if err := model.DB.Preload("Patient").Preload("Handler").First(&log, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "事件不存在"})
		return
	}
	c.JSON(http.StatusOK, log)
}

func CreateEventLog(c *gin.Context) {
	var log model.EventLog
	if err := c.ShouldBindJSON(&log); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}
	if log.OccurredAt.IsZero() {
		log.OccurredAt = time.Now()
	}
	log.Source = "manual"
	if log.Status == "" {
		log.Status = "pending"
	}
	if log.Severity == "" {
		log.Severity = "info"
	}

	if err := model.DB.Create(&log).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, log)
}

func HandleEventLog(c *gin.Context) {
	id := c.Param("id")
	var log model.EventLog
	if err := model.DB.First(&log, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "事件不存在"})
		return
	}

	var input struct {
		Status       string `json:"status"`
		HandleNote   string `json:"handle_note"`
		HandleResult string `json:"handle_result"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	adminID, _ := c.Get("user_id")
	now := time.Now()
	updates := map[string]interface{}{
		"handler_id":    adminID.(uint),
		"handle_note":   input.HandleNote,
		"handle_result": input.HandleResult,
		"handled_at":    now,
	}
	if input.Status != "" {
		updates["status"] = input.Status
	} else {
		updates["status"] = "resolved"
	}

	if err := model.DB.Model(&log).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "处理失败"})
		return
	}

	model.DB.Preload("Patient").Preload("Handler").First(&log, id)
	c.JSON(http.StatusOK, log)
}

func DeleteEventLog(c *gin.Context) {
	id := c.Param("id")
	model.DB.Delete(&model.EventLog{}, id)
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}
