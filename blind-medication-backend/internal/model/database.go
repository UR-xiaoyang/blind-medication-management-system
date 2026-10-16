package model

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"blind-medication-backend/internal/config"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func InitDB(cfg *config.DatabaseConfig) error {
	// 使用SQLite文件数据库，无需安装MySQL
	dbPath := filepath.Join(".", "data", "blind_medication.db")
	os.MkdirAll(filepath.Dir(dbPath), 0755)

	var err error
	DB, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return fmt.Errorf("failed to connect database: %w", err)
	}

	// Auto migrate
	if err := AutoMigrate(); err != nil {
		return fmt.Errorf("auto migrate failed: %w", err)
	}
	if err := migrateLegacySchedulesToDosePackages(); err != nil {
		return fmt.Errorf("legacy schedule migration failed: %w", err)
	}

	log.Println("✅ Database connected successfully (SQLite)")
	return nil
}

func AutoMigrate() error {
	return DB.AutoMigrate(
		&Admin{},
		&Patient{},
		&Medication{},
		&DosePackage{},
		&DosePackageItem{},
		&Schedule{},
		&Device{},
		&DeviceHeartbeat{},
		&EventLog{},
		&NursingRecord{},
		&MedicationLog{},
	)
}

func migrateLegacySchedulesToDosePackages() error {
	var existing int64
	if err := DB.Model(&DosePackage{}).Count(&existing).Error; err != nil {
		return err
	}
	if existing > 0 {
		return nil
	}

	var schedules []Schedule
	if err := DB.Find(&schedules).Error; err != nil {
		return err
	}
	type legacyGroup struct {
		pkg      DosePackage
		itemSeen map[uint]bool
	}

	groups := make(map[string]*legacyGroup)
	nextIndexByPatient := make(map[uint]int)
	for _, schedule := range schedules {
		key := fmt.Sprintf("%d|%s", schedule.PatientID, schedule.TriggerTime)
		group := groups[key]
		if group == nil {
			nextIndexByPatient[schedule.PatientID]++
			packageIndex := nextIndexByPatient[schedule.PatientID]
			if schedule.SlotIndex > 0 {
				packageIndex = schedule.SlotIndex
			}
			group = &legacyGroup{
				pkg: DosePackage{
					PatientID:       schedule.PatientID,
					Name:            schedule.TriggerTime + " 服药",
					TriggerTime:     schedule.TriggerTime,
					PackageIndex:    packageIndex,
					Enabled:         schedule.Enabled,
					Status:          schedule.Status,
					LastDispensedAt: schedule.LastTakenAt,
					CreatedAt:       schedule.CreatedAt,
					UpdatedAt:       schedule.UpdatedAt,
				},
				itemSeen: make(map[uint]bool),
			}
			groups[key] = group
		}
		if !schedule.Enabled {
			group.pkg.Enabled = false
		}
		if group.pkg.LastDispensedAt == nil {
			group.pkg.LastDispensedAt = schedule.LastTakenAt
		}
		if !group.itemSeen[schedule.MedicationID] {
			group.pkg.Items = append(group.pkg.Items, DosePackageItem{
				MedicationID: schedule.MedicationID,
				Quantity:     1,
				Unit:         "片",
			})
			group.itemSeen[schedule.MedicationID] = true
		}
	}

	for _, group := range groups {
		if err := DB.Create(&group.pkg).Error; err != nil {
			return err
		}
	}
	return nil
}
