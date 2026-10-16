package service

// device_events.go: shared event ingest for the device → server channel.
// Both the in-browser simulator (via /api/simulator/publish) and the new
// HTTP device API (via /api/device/*) call into the same set of helpers
// so the rest of the system (DB writes, WebSocket broadcasts, event logs)
// behaves identically regardless of transport.

import (
	"fmt"
	"log"
	"time"

	"gorm.io/gorm"

	"blind-medication-backend/internal/model"
)

// EnsureDevice upserts a device row by device_id. The auto-created row is
// marked offline; the caller is expected to mark it online after the
// status message is processed.
func EnsureDevice(deviceID string) error {
	var device model.Device
	return model.DB.
		Where("device_id = ?", deviceID).
		Attrs(model.Device{
			DeviceID:   deviceID,
			DeviceName: "重力药道模拟器",
			Status:     "offline",
		}).
		FirstOrCreate(&device).Error
}

// ApplyHeartbeat is the canonical heartbeat ingest path. It updates the
// in-memory online cache, the DB row, writes a heartbeat row, and
// broadcasts a WS update to admin pages.
func ApplyHeartbeat(hb ESP32Message) error {
	if err := EnsureDevice(hb.DeviceID); err != nil {
		return err
	}

	now := time.Now()
	devicesMu.Lock()
	onlineDevices[hb.DeviceID] = &DeviceOnlineInfo{
		DeviceID:    hb.DeviceID,
		LastSeen:    now,
		Battery:     hb.Battery,
		Temperature: hb.Temperature,
		SlotStates:  hb.SlotStates,
		IPAddress:   hb.IPAddress,
		Signal:      hb.WiFiRSSI,
	}
	devicesMu.Unlock()

	if err := model.DB.Model(&model.Device{}).Where("device_id = ?", hb.DeviceID).Updates(map[string]interface{}{
		"status":      "online",
		"last_online": now,
		"ip_address":  hb.IPAddress,
		"signal":      hb.WiFiRSSI,
		"firmware":    hb.Firmware,
	}).Error; err != nil {
		return err
	}

	if err := model.DB.Create(&model.DeviceHeartbeat{
		DeviceID:    hb.DeviceID,
		Timestamp:   now,
		Battery:     hb.Battery,
		Temperature: hb.Temperature,
		SlotStates:  hb.SlotStates,
	}).Error; err != nil {
		return err
	}

	GetHub().Broadcast(WSMessage{
		Type:     "heartbeat_update",
		From:     "server",
		DeviceID: hb.DeviceID,
		Data: map[string]interface{}{
			"battery":     hb.Battery,
			"temperature": hb.Temperature,
			"slot_states": hb.SlotStates,
			"wifi_rssi":   hb.WiFiRSSI,
			"ip_address":  hb.IPAddress,
			"firmware":    hb.Firmware,
			"timestamp":   now.Unix(),
		},
	})
	return nil
}

// ApplyStatus handles online/offline transitions. `status` should be one
// of "online" / "offline".
func ApplyStatus(status ESP32Message) error {
	if err := EnsureDevice(status.DeviceID); err != nil {
		return err
	}

	newStatus := status.Type
	if newStatus == "" || newStatus == "status" {
		newStatus = status.Status
	}
	if newStatus != "offline" {
		newStatus = "online"
	}

	now := time.Now()
	devicesMu.Lock()
	if newStatus == "offline" {
		delete(onlineDevices, status.DeviceID)
	} else {
		info := onlineDevices[status.DeviceID]
		if info == nil {
			info = &DeviceOnlineInfo{DeviceID: status.DeviceID}
			onlineDevices[status.DeviceID] = info
		}
		info.LastSeen = now
	}
	devicesMu.Unlock()

	updates := map[string]interface{}{"status": newStatus}
	if newStatus == "online" {
		updates["last_online"] = now
	}
	if err := model.DB.Model(&model.Device{}).Where("device_id = ?", status.DeviceID).Updates(updates).Error; err != nil {
		return err
	}

	for _, sub := range subscribers {
		sub(status.DeviceID, newStatus)
	}

	GetHub().Broadcast(WSMessage{
		Type:     "device_status_update",
		From:     "server",
		DeviceID: status.DeviceID,
		Data: map[string]interface{}{
			"status":    newStatus,
			"timestamp": time.Now().Unix(),
		},
	})
	return nil
}

// ApplyDispenseResult processes a single dispense-result event. The
// patient binding is taken from the message's PatientID if provided,
// otherwise from the device's bound patient.
func ApplyDispenseResult(result ESP32Message) error {
	if err := EnsureDevice(result.DeviceID); err != nil {
		return err
	}

	var device model.Device
	if err := model.DB.Where("device_id = ?", result.DeviceID).First(&device).Error; err != nil {
		return err
	}

	// Update the in-memory slot state for the admin status drawer.
	devicesMu.Lock()
	if info, ok := onlineDevices[result.DeviceID]; ok {
		info.SlotStates = result.SlotStates
		if result.SlotStates == "" {
			info.SlotStates = fmt.Sprintf("mode=gravity_chute;count=%d;capacity=%d;state=%s",
				result.PackageIndex, 12, "ready")
		}
	}
	devicesMu.Unlock()

	now := time.Now()
	patientID := result.PatientID
	if patientID == 0 && device.PatientID != nil {
		patientID = *device.PatientID
	}
	if patientID != 0 {
		if err := ApplyDosePackageResult(patientID, result, now); err != nil {
			return err
		}
		// Auto-bind the device to the patient (helps with first-time setup).
		if device.PatientID == nil || *device.PatientID != patientID {
			pid := patientID
			model.DB.Model(&model.Device{}).Where("device_id = ?", result.DeviceID).Update("patient_id", pid)
		}
		createAutoEventLog(patientID, result.DeviceID, result)
	}

	GetHub().Broadcast(WSMessage{
		Type:     "dispense_result",
		From:     "server",
		DeviceID: result.DeviceID,
		Data: map[string]interface{}{
			"success":         result.Success,
			"error":           result.Error,
			"package_index":   result.PackageIndex,
			"dose_package_id": result.DosePackageID,
			"pill_count":      result.PackageIndex,
			"timestamp":       now.Unix(),
		},
	})

	GetHub().Broadcast(WSMessage{
		Type:     "heartbeat_update",
		From:     "server",
		DeviceID: result.DeviceID,
		Data: map[string]interface{}{
			"slot_states": InfoSlotStates(result.DeviceID, result),
			"timestamp":   now.Unix(),
		},
	})
	return nil
}

// InfoSlotStates returns the current slot-state string for a device, or
// a synthesized one if no heartbeat is cached.
func InfoSlotStates(deviceID string, result ESP32Message) string {
	devicesMu.RLock()
	defer devicesMu.RUnlock()
	if info, ok := onlineDevices[deviceID]; ok {
		return info.SlotStates
	}
	return fmt.Sprintf("mode=gravity_chute;count=%d;capacity=12;state=ready", result.PackageIndex)
}

// ApplySensor stores a sensor-data reading and creates an event log on
// temperature anomalies.
func ApplySensor(data ESP32Message) error {
	log.Printf("🌡️ Sensor data from %s: temp=%.1f", data.DeviceID, data.Temperature)
	if err := EnsureDevice(data.DeviceID); err != nil {
		return err
	}
	if data.Temperature > 50 || data.Temperature < 0 {
		var device model.Device
		if err := model.DB.Where("device_id = ?", data.DeviceID).First(&device).Error; err == nil && device.PatientID != nil {
			sev := "warning"
			if data.Temperature > 60 || data.Temperature < -10 {
				sev = "error"
			}
			model.DB.Create(&model.EventLog{
				PatientID:  *device.PatientID,
				DeviceID:   data.DeviceID,
				EventType:  "sensor_alert",
				Title:      "设备温度异常",
				Content:    fmt.Sprintf("温度: %.1f°C", data.Temperature),
				Severity:   sev,
				Source:     "device",
				Status:     "pending",
				OccurredAt: time.Now(),
			})
		}
	}
	return nil
}

// ApplySOS records an SOS event from a device.
func ApplySOS(msg ESP32Message) error {
	reason := msg.Reason
	if reason == "" {
		reason = msg.Error
	}
	log.Printf("SOS from %s: %s", msg.DeviceID, reason)
	if err := EnsureDevice(msg.DeviceID); err != nil {
		return err
	}
	var device model.Device
	if err := model.DB.Where("device_id = ?", msg.DeviceID).First(&device).Error; err == nil && device.PatientID != nil {
		model.DB.Create(&model.EventLog{
			PatientID:  *device.PatientID,
			DeviceID:   msg.DeviceID,
			EventType:  "sos",
			Title:      "SOS紧急求助",
			Content:    reason,
			Severity:   "critical",
			Source:     "device",
			Status:     "pending",
			OccurredAt: time.Now(),
		})
	}
	GetHub().Broadcast(WSMessage{
		Type:     "sos",
		From:     "server",
		DeviceID: msg.DeviceID,
		Data: map[string]interface{}{
			"reason":    reason,
			"timestamp": time.Now().Unix(),
		},
	})
	return nil
}

// ApplyDosePackageResult moves a DosePackage from pending → taken/missed
// and writes the per-medication MedicationLog rows.
func ApplyDosePackageResult(patientID uint, result ESP32Message, now time.Time) error {
	var pkg model.DosePackage
	query := model.DB.Preload("Items").Where("patient_id = ?", patientID)
	if result.DosePackageID != 0 {
		query = query.Where("id = ?", result.DosePackageID)
	} else {
		packageIndex := result.PackageIndex
		if packageIndex == 0 {
			packageIndex = result.SlotIndex
		}
		query = query.Where("package_index = ? AND status = ?", packageIndex, "pending")
	}
	if err := query.First(&pkg).Error; err != nil {
		return nil
	}

	action := "missed"
	if result.Success {
		action = "taken"
	}
	if err := model.DB.Model(&pkg).Updates(map[string]interface{}{
		"status":            action,
		"last_dispensed_at": now,
	}).Error; err != nil {
		return err
	}

	if len(pkg.Items) == 0 {
		return model.DB.Create(&model.MedicationLog{
			PatientID:     patientID,
			DosePackageID: pkg.ID,
			Action:        action,
			TakenAt:       now,
		}).Error
	}

	for _, item := range pkg.Items {
		if action == "taken" {
			model.DB.Model(&model.Medication{}).
				Where("id = ?", item.MedicationID).
				UpdateColumn("stock_used", gorm.Expr("stock_used + ?", item.Quantity))
		}
		if err := model.DB.Create(&model.MedicationLog{
			PatientID:     patientID,
			MedicationID:  item.MedicationID,
			DosePackageID: pkg.ID,
			Action:        action,
			TakenAt:       now,
		}).Error; err != nil {
			return err
		}
	}
	return nil
}
