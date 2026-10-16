package handler

import (
	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/middleware"
)

func SetupRoutes(r *gin.Engine) {
	// ========== 公开接口 ==========
	public := r.Group("/api")
	{
		public.POST("/login", Login)
		public.POST("/init-admin", InitAdmin) // 首次初始化管理员

		// 设备模拟器（无需认证，方便调试）
		public.POST("/simulator/publish", SimulatorPublish)
		public.GET("/simulator/devices", SimulatorGetDevices)
		public.GET("/simulator/patients", SimulatorGetPatients)
		public.GET("/simulator/dose-packages", SimulatorGetDosePackages)

		// 实体 ESP32 设备 → 后端 HTTP 上报通道 (X-Device-Token 鉴权)
		device := public.Group("/device")
		device.Use(middleware.DeviceAuthMiddleware())
		{
			device.POST("/heartbeat", DeviceHeartbeat)
			device.POST("/status", DeviceStatus)
			device.POST("/sensor", DeviceSensor)
			device.POST("/dispense-result", DeviceDispenseResult)
			device.POST("/sos", DeviceSOS)
		}

		// WebSocket（无需认证）
		public.GET("/ws", WebSocketHandler)
	}

	// ========== 需要认证的接口 ==========
	auth := r.Group("/api")
	auth.Use(middleware.AuthMiddleware())
	{
		// 个人信息
		auth.GET("/profile", GetProfile)

		// ---- 统计 ----
		auth.GET("/stats", GetStats)

		// ---- 患者管理 ----
		auth.GET("/patients", GetPatients)
		auth.GET("/patients/:id", GetPatient)
		auth.POST("/patients", CreatePatient)
		auth.PUT("/patients/:id", UpdatePatient)
		auth.DELETE("/patients/:id", DeletePatient)

		// ---- 药品管理 ----
		auth.GET("/medications", GetMedications)
		auth.GET("/medications/:id", GetMedication)
		auth.POST("/medications", CreateMedication)
		auth.PUT("/medications/:id", UpdateMedication)
		auth.DELETE("/medications/:id", DeleteMedication)

		// ---- 按次服药包 ----
		auth.GET("/dose-packages", GetDosePackages)
		auth.POST("/dose-packages", CreateDosePackage)
		auth.PUT("/dose-packages/:id", UpdateDosePackage)
		auth.DELETE("/dose-packages/:id", DeleteDosePackage)

		// ---- 服药计划（兼容旧路径，语义同剂次包）----
		auth.GET("/schedules", GetSchedules)
		auth.POST("/schedules", CreateSchedule)
		auth.PUT("/schedules/:id", UpdateSchedule)
		auth.DELETE("/schedules/:id", DeleteSchedule)

		// ---- 出药操作 ----
		auth.POST("/dispense", DispenseMedication)

		// ---- 服药记录 ----
		auth.GET("/medication-logs", GetMedicationLogs)

		// ---- 设备管理 ----
		auth.GET("/devices", GetDevices)
		auth.GET("/devices/:id", GetDevice)
		auth.POST("/devices", CreateDevice)
		auth.PUT("/devices/:id", UpdateDevice)
		auth.DELETE("/devices/:id", DeleteDevice)

		// ---- 设备访问 token 管理 ----
		auth.GET("/devices/:id/token", GetDeviceToken)
		auth.POST("/devices/:id/rotate-token", RotateDeviceToken)

		// ---- 设备实时状态 ----
		auth.GET("/devices/:id/status", GetDeviceStatus)
		auth.GET("/devices/:id/heartbeats", GetDeviceHeartbeats)
		auth.POST("/devices/:id/command", SendDeviceCommand)

		// ---- 事件日志 ----
		auth.GET("/event-logs", GetEventLogs)
		auth.GET("/event-logs/:id", GetEventLog)
		auth.POST("/event-logs", CreateEventLog)
		auth.PUT("/event-logs/:id/handle", HandleEventLog)
		auth.DELETE("/event-logs/:id", DeleteEventLog)

		// ---- 护理记录 ----
		auth.GET("/nursing-records", GetNursingRecords)
		auth.GET("/nursing-records/:id", GetNursingRecord)
		auth.POST("/nursing-records", CreateNursingRecord)
		auth.DELETE("/nursing-records/:id", DeleteNursingRecord)
	}
}
