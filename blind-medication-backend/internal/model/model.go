package model

import (
	"crypto/rand"
	"encoding/hex"
	"time"

	"gorm.io/gorm"
)

// GenerateDeviceToken creates a 32-byte random hex token (64 chars) for
// use as the X-Device-Token shared secret between an ESP32 and the
// backend. Cryptographically random — suitable for untrusted networks.
func GenerateDeviceToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// ========== 用户相关 ==========

// Admin 管理员账号
type Admin struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Username  string         `json:"username" gorm:"size:50;uniqueIndex;not null"`
	Password  string         `json:"-" gorm:"size:255;not null"`
	RealName  string         `json:"real_name" gorm:"size:50"`
	Phone     string         `json:"phone" gorm:"size:20"`
	Role      string         `json:"role" gorm:"size:20;default:admin"` // admin | superadmin
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`
}

// Patient 盲人患者信息
type Patient struct {
	ID             uint           `json:"id" gorm:"primaryKey"`
	Name           string         `json:"name" gorm:"size:50;not null"`
	Gender         string         `json:"gender" gorm:"size:10"`
	Age            int            `json:"age"`
	Phone          string         `json:"phone" gorm:"size:20"`
	Address        string         `json:"address" gorm:"size:255"`
	EmergencyName  string         `json:"emergency_name" gorm:"size:50"`
	EmergencyPhone string         `json:"emergency_phone" gorm:"size:20"`
	MedicalNotes   string         `json:"medical_notes" gorm:"type:text"`  // 医疗备注
	DeviceID       string         `json:"device_id" gorm:"size:100;index"` // 绑定设备ID
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	DeletedAt      gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联
	Medications  []Medication  `json:"medications,omitempty" gorm:"foreignKey:PatientID"`
	DosePackages []DosePackage `json:"dose_packages,omitempty" gorm:"foreignKey:PatientID"`
	EventLogs    []EventLog    `json:"event_logs,omitempty" gorm:"foreignKey:PatientID"`
}

// ========== 药品与用药计划 ==========

// Medication 药品信息
type Medication struct {
	ID            uint           `json:"id" gorm:"primaryKey"`
	PatientID     uint           `json:"patient_id" gorm:"index;not null"`
	Name          string         `json:"name" gorm:"size:100;not null"`
	Specification string         `json:"specification" gorm:"size:100"` // 规格
	Dosage        string         `json:"dosage" gorm:"size:50"`         // 用量 e.g. "1片"
	Frequency     string         `json:"frequency" gorm:"size:50"`      // 频率 e.g. "每日3次"
	StockTotal    int            `json:"stock_total"`                   // 总库存(粒/片)
	StockUsed     int            `json:"stock_used"`                    // 已使用数量
	SideEffects   string         `json:"side_effects" gorm:"type:text"` // 副作用
	Notes         string         `json:"notes" gorm:"type:text"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `json:"-" gorm:"index"`

	// 关联
	Schedules []Schedule        `json:"schedules,omitempty" gorm:"foreignKey:MedicationID"`
	DoseItems []DosePackageItem `json:"dose_items,omitempty" gorm:"foreignKey:MedicationID"`
}

// DosePackage 表示一次服药要取出的整包药，一包里可以包含多种药。
type DosePackage struct {
	ID              uint       `json:"id" gorm:"primaryKey"`
	PatientID       uint       `json:"patient_id" gorm:"index;not null"`
	Name            string     `json:"name" gorm:"size:100;not null"`        // 早餐后、午餐后、睡前等
	TriggerTime     string     `json:"trigger_time" gorm:"size:10;not null"` // "08:00", "12:30"
	PackageIndex    int        `json:"package_index" gorm:"index"`           // 本次药包位置/编号，不再表示药品槽
	Enabled         bool       `json:"enabled" gorm:"default:true"`
	Status          string     `json:"status" gorm:"size:20;default:pending"` // pending | taken | missed
	LastDispensedAt *time.Time `json:"last_dispensed_at"`
	Notes           string     `json:"notes" gorm:"type:text"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`

	Items   []DosePackageItem `json:"items,omitempty" gorm:"foreignKey:DosePackageID"`
	Patient Patient           `json:"patient,omitempty" gorm:"foreignKey:PatientID"`
}

// DosePackageItem 表示一次服药包里的某一种药和数量。
type DosePackageItem struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	DosePackageID uint      `json:"dose_package_id" gorm:"index;not null"`
	MedicationID  uint      `json:"medication_id" gorm:"index;not null"`
	Quantity      int       `json:"quantity" gorm:"not null;default:1"`
	Unit          string    `json:"unit" gorm:"size:20;default:片"`
	Notes         string    `json:"notes" gorm:"type:text"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`

	Medication Medication `json:"medication,omitempty" gorm:"foreignKey:MedicationID"`
}

// Schedule 服药计划/提醒（旧接口兼容，新的出药单位请使用 DosePackage）
type Schedule struct {
	ID           uint       `json:"id" gorm:"primaryKey"`
	MedicationID uint       `json:"medication_id" gorm:"index;not null"`
	PatientID    uint       `json:"patient_id" gorm:"index;not null"`
	TriggerTime  string     `json:"trigger_time" gorm:"size:10;not null"` // "08:00", "12:30"
	SlotIndex    int        `json:"slot_index"`                           // 药槽编号 1-7
	Enabled      bool       `json:"enabled" gorm:"default:true"`
	LastTakenAt  *time.Time `json:"last_taken_at"`
	Status       string     `json:"status" gorm:"size:20;default:pending"` // pending | taken | missed
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

// ========== 设备相关 ==========

// Device ESP32设备信息
type Device struct {
	ID                uint       `json:"id" gorm:"primaryKey"`
	DeviceID          string     `json:"device_id" gorm:"size:100;uniqueIndex;not null"`
	DeviceName        string     `json:"device_name" gorm:"size:100"`
	PatientID         *uint      `json:"patient_id" gorm:"index"`
	Firmware          string     `json:"firmware" gorm:"size:50"`
	DispenseMode      string     `json:"dispense_mode" gorm:"size:30;default:fixed_medicine"` // fixed_medicine | fixed_slot | dose_package
	FixedMedicineName string     `json:"fixed_medicine_name" gorm:"size:100"`
	FixedSlotIndex    int        `json:"fixed_slot_index"`
	FixedCapacity     int        `json:"fixed_capacity"`
	CapabilityNotes   string     `json:"capability_notes" gorm:"type:text"`
	Status            string     `json:"status" gorm:"size:20;default:offline"` // online | offline | error
	LastOnline        *time.Time `json:"last_online"`
	IPAddress         string     `json:"ip_address" gorm:"size:50"`
	Signal            int        `json:"signal"` // WiFi信号强度 (RSSI)
	// DeviceToken 设备访问后端 API 的共享密钥。
	// ESP32 通过 X-Device-Token 头部发送，后端按该字段查表。
	// 该字段对前端不返回 (json:"-")，但管理后台用单独接口查询。
	DeviceToken string    `json:"-" gorm:"size:64;uniqueIndex"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// DeviceHeartbeat 设备心跳日志
type DeviceHeartbeat struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	DeviceID    string    `json:"device_id" gorm:"size:100;index"`
	Timestamp   time.Time `json:"timestamp"`
	Battery     int       `json:"battery"`                    // 电量百分比
	Temperature float64   `json:"temperature"`                // 设备温度
	SlotStates  string    `json:"slot_states" gorm:"size:50"` // "1,0,1,0,0,0,0" 各药槽状态
}

// ========== 报告与护理 ==========

// EventLog 事件日志
type EventLog struct {
	ID           uint       `json:"id" gorm:"primaryKey"`
	PatientID    uint       `json:"patient_id" gorm:"index;not null"`
	DeviceID     string     `json:"device_id" gorm:"size:100;index"`
	EventType    string     `json:"event_type" gorm:"size:50;not null"`    // dispense_success, dispense_fail, medication_taken, medication_missed, sensor_alert, device_error, device_online, device_offline, sos, custom
	Title        string     `json:"title" gorm:"size:200;not null"`        // 事件标题
	Content      string     `json:"content" gorm:"type:text"`              // 事件详情
	Severity     string     `json:"severity" gorm:"size:20;default:info"`  // info, warning, error, critical
	Source       string     `json:"source" gorm:"size:20;default:device"`  // device | manual
	Status       string     `json:"status" gorm:"size:20;default:pending"` // pending | processing | resolved | ignored
	HandlerID    *uint      `json:"handler_id" gorm:"index"`
	HandleNote   string     `json:"handle_note" gorm:"type:text"`
	HandleResult string     `json:"handle_result" gorm:"size:50"`
	HandledAt    *time.Time `json:"handled_at"`
	OccurredAt   time.Time  `json:"occurred_at"`
	CreatedAt    time.Time  `json:"created_at"`

	Patient Patient `json:"patient,omitempty" gorm:"foreignKey:PatientID"`
	Handler *Admin  `json:"handler,omitempty" gorm:"foreignKey:HandlerID"`
}

// NursingRecord 护理记录
type NursingRecord struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	PatientID uint      `json:"patient_id" gorm:"index;not null"`
	AdminID   uint      `json:"admin_id" gorm:"index"` // 操作员
	Type      string    `json:"type" gorm:"size:50"`   // medication_check, health_visit, phone_followup, emergency
	Content   string    `json:"content" gorm:"type:text;not null"`
	CreatedAt time.Time `json:"created_at"`
}

// MedicationLog 服药记录
type MedicationLog struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	PatientID     uint      `json:"patient_id" gorm:"index;not null"`
	MedicationID  uint      `json:"medication_id" gorm:"index"`
	ScheduleID    uint      `json:"schedule_id" gorm:"index"`
	DosePackageID uint      `json:"dose_package_id" gorm:"index"`
	Action        string    `json:"action" gorm:"size:20;not null"` // taken | missed | skipped
	TakenAt       time.Time `json:"taken_at"`
	CreatedAt     time.Time `json:"created_at"`

	// 关联
	Medication  Medication  `json:"medication,omitempty" gorm:"foreignKey:MedicationID"`
	DosePackage DosePackage `json:"dose_package,omitempty" gorm:"foreignKey:DosePackageID"`
}
