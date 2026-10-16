package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"blind-medication-backend/internal/model"
)

// DeviceAuthMiddleware validates the X-Device-Token header against the
// `device_token` column on the `devices` table. The matching device's
// device_id (the human-facing string, not the integer primary key) is
// stored in the gin context as "device_id".
//
// Unlike the JWT AuthMiddleware used by admins, this middleware is
// intended for the ESP32 fleet. Tokens are long random hex strings, the
// same scheme as a bearer token but conveyed as a custom header so it
// can't be confused with user JWTs.
func DeviceAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := strings.TrimSpace(c.GetHeader("X-Device-Token"))
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "缺少 X-Device-Token"})
			c.Abort()
			return
		}

		var device model.Device
		if err := model.DB.Where("device_token = ?", token).First(&device).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "设备令牌无效"})
			c.Abort()
			return
		}

		c.Set("device_id", device.DeviceID)
		c.Set("device_db_id", device.ID)
		c.Next()
	}
}
