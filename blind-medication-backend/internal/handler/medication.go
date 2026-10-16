package handler

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
	"blind-medication-backend/internal/service"
	"gorm.io/gorm"
)

// ========== Medication CRUD ==========

func GetMedications(c *gin.Context) {
	patientID := c.Query("patient_id")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))

	query := model.DB.Model(&model.Medication{})
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}

	var total int64
	query.Count(&total)

	var meds []model.Medication
	query.Preload("DoseItems").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("created_at DESC").
		Find(&meds)

	c.JSON(http.StatusOK, gin.H{
		"data":      meds,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

func GetMedication(c *gin.Context) {
	id := c.Param("id")
	var med model.Medication
	if err := model.DB.Preload("DoseItems").First(&med, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "药品不存在"})
		return
	}
	c.JSON(http.StatusOK, med)
}

func CreateMedication(c *gin.Context) {
	var med model.Medication
	if err := c.ShouldBindJSON(&med); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	if err := model.DB.Create(&med).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, med)
}

func UpdateMedication(c *gin.Context) {
	id := c.Param("id")
	var med model.Medication
	if err := model.DB.First(&med, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "药品不存在"})
		return
	}

	if err := c.ShouldBindJSON(&med); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	model.DB.Save(&med)
	c.JSON(http.StatusOK, med)
}

func DeleteMedication(c *gin.Context) {
	id := c.Param("id")
	model.DB.Where("medication_id = ?", id).Delete(&model.DosePackageItem{})
	model.DB.Where("medication_id = ?", id).Delete(&model.Schedule{})
	model.DB.Delete(&model.Medication{}, id)
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

// ========== Dose Package CRUD ==========

type dosePackageItemRequest struct {
	MedicationID uint   `json:"medication_id" binding:"required"`
	Quantity     int    `json:"quantity"`
	Unit         string `json:"unit"`
	Notes        string `json:"notes"`
}

type dosePackageRequest struct {
	PatientID    uint                     `json:"patient_id" binding:"required"`
	Name         string                   `json:"name"`
	TriggerTime  string                   `json:"trigger_time" binding:"required"`
	PackageIndex int                      `json:"package_index"`
	Enabled      *bool                    `json:"enabled"`
	Status       string                   `json:"status"`
	Notes        string                   `json:"notes"`
	Items        []dosePackageItemRequest `json:"items" binding:"required"`
}

func GetDosePackages(c *gin.Context) {
	patientID := c.Query("patient_id")
	medicationID := c.Query("medication_id")
	today := c.Query("today")

	query := model.DB.Model(&model.DosePackage{})
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}
	if today == "true" {
		query = query.Where("enabled = ?", true)
	}
	if medicationID != "" {
		query = query.Joins("JOIN dose_package_items ON dose_package_items.dose_package_id = dose_packages.id").
			Where("dose_package_items.medication_id = ?", medicationID).
			Group("dose_packages.id")
	}

	var packages []model.DosePackage
	query.Preload("Items.Medication").
		Order("trigger_time ASC, package_index ASC").
		Find(&packages)

	c.JSON(http.StatusOK, gin.H{"data": packages})
}

func CreateDosePackage(c *gin.Context) {
	var req dosePackageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	pkg, err := buildDosePackage(req, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&pkg).Error; err != nil {
			return err
		}
		return tx.Preload("Items.Medication").First(&pkg, pkg.ID).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, pkg)
}

func UpdateDosePackage(c *gin.Context) {
	id := c.Param("id")
	var existing model.DosePackage
	if err := model.DB.First(&existing, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "剂次包不存在"})
		return
	}

	var req dosePackageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	pkg, err := buildDosePackage(req, &existing)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err = model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&existing).Updates(map[string]interface{}{
			"patient_id":    pkg.PatientID,
			"name":          pkg.Name,
			"trigger_time":  pkg.TriggerTime,
			"package_index": pkg.PackageIndex,
			"enabled":       pkg.Enabled,
			"status":        pkg.Status,
			"notes":         pkg.Notes,
		}).Error; err != nil {
			return err
		}
		if err := tx.Where("dose_package_id = ?", existing.ID).Delete(&model.DosePackageItem{}).Error; err != nil {
			return err
		}
		for i := range pkg.Items {
			pkg.Items[i].DosePackageID = existing.ID
		}
		if err := tx.Create(&pkg.Items).Error; err != nil {
			return err
		}
		return tx.Preload("Items.Medication").First(&existing, existing.ID).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新失败"})
		return
	}
	c.JSON(http.StatusOK, existing)
}

func DeleteDosePackage(c *gin.Context) {
	id := c.Param("id")
	if err := model.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("dose_package_id = ?", id).Delete(&model.DosePackageItem{}).Error; err != nil {
			return err
		}
		return tx.Delete(&model.DosePackage{}, id).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

func buildDosePackage(req dosePackageRequest, existing *model.DosePackage) (model.DosePackage, error) {
	if len(req.Items) == 0 {
		return model.DosePackage{}, errors.New("一次服药至少需要包含一种药")
	}

	enabled := true
	if req.Enabled != nil {
		enabled = *req.Enabled
	} else if existing != nil {
		enabled = existing.Enabled
	}

	status := req.Status
	if status == "" {
		status = "pending"
	}

	packageIndex := req.PackageIndex
	if packageIndex <= 0 {
		packageIndex = nextPackageIndex(req.PatientID)
	}

	name := req.Name
	if name == "" {
		name = req.TriggerTime + " 服药"
	}

	pkg := model.DosePackage{
		PatientID:    req.PatientID,
		Name:         name,
		TriggerTime:  req.TriggerTime,
		PackageIndex: packageIndex,
		Enabled:      enabled,
		Status:       status,
		Notes:        req.Notes,
	}

	for _, itemReq := range req.Items {
		var count int64
		model.DB.Model(&model.Medication{}).
			Where("id = ? AND patient_id = ?", itemReq.MedicationID, req.PatientID).
			Count(&count)
		if count == 0 {
			return model.DosePackage{}, errors.New("剂次包中包含不属于该患者的药品")
		}

		quantity := itemReq.Quantity
		if quantity <= 0 {
			quantity = 1
		}
		unit := itemReq.Unit
		if unit == "" {
			unit = "片"
		}
		pkg.Items = append(pkg.Items, model.DosePackageItem{
			MedicationID: itemReq.MedicationID,
			Quantity:     quantity,
			Unit:         unit,
			Notes:        itemReq.Notes,
		})
	}

	return pkg, nil
}

func nextPackageIndex(patientID uint) int {
	var maxIndex int
	model.DB.Model(&model.DosePackage{}).
		Where("patient_id = ?", patientID).
		Select("COALESCE(MAX(package_index), 0)").
		Scan(&maxIndex)
	return maxIndex + 1
}

// ========== Schedule CRUD compatibility ==========

func GetSchedules(c *gin.Context) {
	GetDosePackages(c)
}

func CreateSchedule(c *gin.Context) {
	CreateDosePackage(c)
}

func UpdateSchedule(c *gin.Context) {
	UpdateDosePackage(c)
}

func DeleteSchedule(c *gin.Context) {
	DeleteDosePackage(c)
}

// ========== Manual Dispense 手动出药 ==========

func DispenseMedication(c *gin.Context) {
	var req struct {
		DeviceID      string `json:"device_id" binding:"required"`
		DosePackageID uint   `json:"dose_package_id"`
		PackageIndex  int    `json:"package_index"`
		SlotIndex     int    `json:"slot_index"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 检查设备是否在线
	if !service.IsDeviceOnline(req.DeviceID) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "设备不在线"})
		return
	}

	pkg, err := resolveDispensePackage(req.DeviceID, req.DosePackageID, req.PackageIndex, req.SlotIndex)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 旧行为：service.SendDispenseCommand 通过 MQTT 下发出药命令。
	// 新行为：服务器不再向设备推送控制命令。这里改为：
	//   1) 写一条 manual_request 事件日志
	//   2) WS 通知管理员 UI 与浏览器模拟器，让它们可以触发本地动作
	//   3) 真实 ESP32 不受此事件影响（由本地语音/PIR/按钮决定）
	_ = service.SendDispenseCommand // 保留旧实现以兼容可能仍在运行的 MQTT 链路
	_ = pkg

	var device model.Device
	if model.DB.Where("device_id = ?", req.DeviceID).First(&device).Error == nil && device.PatientID != nil {
		model.DB.Create(&model.EventLog{
			PatientID:  *device.PatientID,
			DeviceID:   req.DeviceID,
			EventType:  "manual_request",
			Title:      "管理员请求出药",
			Content:    fmt.Sprintf("dose_package_id=%d package_index=%d", pkg.ID, pkg.PackageIndex),
			Severity:   "info",
			Source:     "admin",
			Status:     "pending",
			OccurredAt: time.Now(),
		})
	}

	// 通过 WebSocket Hub 向绑定该设备的模拟器实时推送出药指令
	service.GetHub().SendToDevice(req.DeviceID, service.WSMessage{
		Type:     "dispense_command",
		From:     "server",
		DeviceID: req.DeviceID,
		Data: map[string]interface{}{
			"dose_package_id": pkg.ID,
			"package_index":   pkg.PackageIndex,
			"items":           formatDosePackageItems(pkg),
			"timestamp":       time.Now().Unix(),
		},
	})
	service.GetHub().Broadcast(service.WSMessage{
		Type:     "manual_command",
		From:     "server",
		DeviceID: req.DeviceID,
		Data: map[string]interface{}{
			"action":          "dispense_request",
			"dose_package_id": pkg.ID,
			"package_index":   pkg.PackageIndex,
			"message":         "已记录人工出药请求，实体 ESP 仅通过上报反馈结果",
			"timestamp":       time.Now().Unix(),
		},
	})

	c.JSON(http.StatusOK, gin.H{
		"message":        "已记录出药请求（设备将自行决定是否执行）",
		"dose_package":   pkg,
		"forwarded_mqtt": false,
	})
}

func formatDosePackageItems(pkg model.DosePackage) []map[string]interface{} {
	items := make([]map[string]interface{}, len(pkg.Items))
	for i, item := range pkg.Items {
		medName := ""
		if item.Medication.ID != 0 {
			medName = item.Medication.Name
		}
		items[i] = map[string]interface{}{
			"name":     medName,
			"quantity": item.Quantity,
			"unit":     item.Unit,
		}
	}
	_ = fmt.Sprint() // silence unused import
	return items
}

func resolveDispensePackage(deviceID string, dosePackageID uint, packageIndex int, slotIndex int) (model.DosePackage, error) {
	var pkg model.DosePackage
	query := model.DB.Preload("Items.Medication")
	if dosePackageID != 0 {
		if err := query.First(&pkg, dosePackageID).Error; err != nil {
			return pkg, errors.New("剂次包不存在")
		}
		return pkg, nil
	}

	var device model.Device
	if err := model.DB.Where("device_id = ?", deviceID).First(&device).Error; err != nil {
		return pkg, errors.New("设备不存在")
	}
	if device.PatientID == nil {
		return pkg, errors.New("设备未绑定患者，无法确定要出的剂次包")
	}

	if packageIndex == 0 {
		packageIndex = slotIndex
	}
	if packageIndex > 0 {
		err := query.Where("patient_id = ? AND package_index = ? AND status = ?",
			*device.PatientID, packageIndex, "pending").First(&pkg).Error
		if err != nil {
			return pkg, errors.New("没有找到对应编号的待出药剂次包")
		}
		return pkg, nil
	}

	err := query.Where("patient_id = ? AND enabled = ? AND status = ?",
		*device.PatientID, true, "pending").
		Order("trigger_time ASC, package_index ASC").
		First(&pkg).Error
	if err != nil {
		return pkg, errors.New("没有待出药的剂次包")
	}
	return pkg, nil
}

// ========== Medication Log ==========

func GetMedicationLogs(c *gin.Context) {
	patientID := c.Query("patient_id")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	query := model.DB.Model(&model.MedicationLog{})
	if patientID != "" {
		query = query.Where("patient_id = ?", patientID)
	}

	// 日期范围过滤
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	if startDate != "" {
		query = query.Where("taken_at >= ?", startDate)
	}
	if endDate != "" {
		query = query.Where("taken_at <= ?", endDate+" 23:59:59")
	}

	var total int64
	query.Count(&total)

	var logs []model.MedicationLog
	query.Preload("Medication").
		Preload("DosePackage.Items.Medication").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("taken_at DESC").
		Find(&logs)

	c.JSON(http.StatusOK, gin.H{
		"data":      logs,
		"total":     total,
		"page":      page,
		"page_size": pageSize,
	})
}

// ========== 统计 ==========

func GetStats(c *gin.Context) {
	patientID := c.Query("patient_id")
	today := time.Now().Format("2006-01-02")

	var totalPatients int64
	model.DB.Model(&model.Patient{}).Count(&totalPatients)

	var totalMedications int64
	medQuery := model.DB.Model(&model.Medication{})
	if patientID != "" {
		medQuery = medQuery.Where("patient_id = ?", patientID)
	}
	medQuery.Count(&totalMedications)

	var todayTaken int64
	var todayMissed int64
	logQuery := model.DB.Model(&model.MedicationLog{}).Where("DATE(taken_at) = ? AND dose_package_id > 0", today)
	if patientID != "" {
		logQuery = logQuery.Where("patient_id = ?", patientID)
	}
	logQuery.Session(&gorm.Session{}).Where("action = ?", "taken").Distinct("dose_package_id").Count(&todayTaken)
	logQuery.Session(&gorm.Session{}).Where("action = ?", "missed").Distinct("dose_package_id").Count(&todayMissed)

	var onlineDevices int64
	model.DB.Model(&model.Device{}).Where("status = ?", "online").Count(&onlineDevices)

	var totalDevices int64
	model.DB.Model(&model.Device{}).Count(&totalDevices)

	c.JSON(http.StatusOK, gin.H{
		"total_patients":    totalPatients,
		"total_medications": totalMedications,
		"today_taken":       todayTaken,
		"today_missed":      todayMissed,
		"online_devices":    onlineDevices,
		"total_devices":     totalDevices,
		"compliance_rate":   calcCompliance(todayTaken, todayMissed),
	})
}

func calcCompliance(taken, missed int64) float64 {
	total := taken + missed
	if total == 0 {
		return 100.0
	}
	return float64(taken) / float64(total) * 100
}
