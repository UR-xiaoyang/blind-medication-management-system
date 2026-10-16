package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
)

// ========== Patient CRUD ==========

func GetPatients(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	keyword := c.Query("keyword")

	if page < 1 {
		page = 1
	}

	query := model.DB.Model(&model.Patient{})
	if keyword != "" {
		query = query.Where("name LIKE ? OR phone LIKE ?", "%"+keyword+"%", "%"+keyword+"%")
	}

	var total int64
	query.Count(&total)

	var patients []model.Patient
	query.Preload("Medications").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("created_at DESC").
		Find(&patients)

	c.JSON(http.StatusOK, gin.H{
		"data":      patients,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

func GetPatient(c *gin.Context) {
	id := c.Param("id")
	var patient model.Patient
	if err := model.DB.Preload("Medications").
		Preload("DosePackages.Items.Medication").
		Preload("Reports").
		First(&patient, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "患者不存在"})
		return
	}
	c.JSON(http.StatusOK, patient)
}

func CreatePatient(c *gin.Context) {
	var patient model.Patient
	if err := c.ShouldBindJSON(&patient); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	if err := model.DB.Create(&patient).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}

	// 如果绑定了设备，更新设备关联
	if patient.DeviceID != "" {
		model.DB.Model(&model.Device{}).Where("device_id = ?", patient.DeviceID).
			Update("patient_id", patient.ID)
	}

	c.JSON(http.StatusOK, patient)
}

func UpdatePatient(c *gin.Context) {
	id := c.Param("id")
	var patient model.Patient
	if err := model.DB.First(&patient, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "患者不存在"})
		return
	}

	var input model.Patient
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	model.DB.Model(&patient).Updates(map[string]interface{}{
		"name":            input.Name,
		"gender":          input.Gender,
		"age":             input.Age,
		"phone":           input.Phone,
		"address":         input.Address,
		"emergency_name":  input.EmergencyName,
		"emergency_phone": input.EmergencyPhone,
		"medical_notes":   input.MedicalNotes,
		"device_id":       input.DeviceID,
	})

	c.JSON(http.StatusOK, patient)
}

func DeletePatient(c *gin.Context) {
	id := c.Param("id")
	if err := model.DB.Delete(&model.Patient{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}
