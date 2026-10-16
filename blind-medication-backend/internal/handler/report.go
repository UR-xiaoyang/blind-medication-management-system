package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
)

// ========== Nursing Record 护理记录 ==========

func GetNursingRecords(c *gin.Context) {
	patientID := c.Query("patient_id")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	query := model.DB.Model(&model.NursingRecord{})
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}

	var total int64
	query.Count(&total)

	var records []model.NursingRecord
	query.Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("created_at DESC").
		Find(&records)

	c.JSON(http.StatusOK, gin.H{
		"data":      records,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

func CreateNursingRecord(c *gin.Context) {
	var record model.NursingRecord
	if err := c.ShouldBindJSON(&record); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	// 从JWT获取操作员ID
	adminID, _ := c.Get("user_id")
	record.AdminID = adminID.(uint)

	if err := model.DB.Create(&record).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, record)
}

func GetNursingRecord(c *gin.Context) {
	id := c.Param("id")
	var record model.NursingRecord
	if err := model.DB.First(&record, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "记录不存在"})
		return
	}
	c.JSON(http.StatusOK, record)
}

func DeleteNursingRecord(c *gin.Context) {
	id := c.Param("id")
	model.DB.Delete(&model.NursingRecord{}, id)
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}
