package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"

	"blind-medication-backend/internal/middleware"
	"blind-medication-backend/internal/model"
)

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token    string      `json:"token"`
	Admin    model.Admin `json:"admin"`
}

// Login 管理员登录
func Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	var admin model.Admin
	if err := model.DB.Where("username = ?", req.Username).First(&admin).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}

	token, err := middleware.GenerateToken(admin.ID, admin.Username, admin.Role, 24)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "生成token失败"})
		return
	}

	c.JSON(http.StatusOK, LoginResponse{Token: token, Admin: admin})
}

// GetProfile 获取当前登录用户信息
func GetProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	var admin model.Admin
	if err := model.DB.First(&admin, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	c.JSON(http.StatusOK, admin)
}

// InitAdmin 初始化管理员（首次运行）
func InitAdmin(c *gin.Context) {
	var count int64
	model.DB.Model(&model.Admin{}).Count(&count)
	if count > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "管理员已存在，请直接登录"})
		return
	}

	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	hashedPwd, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	admin := model.Admin{
		Username: req.Username,
		Password: string(hashedPwd),
		Role:     "superadmin",
	}
	model.DB.Create(&admin)

	token, _ := middleware.GenerateToken(admin.ID, admin.Username, admin.Role, 24)
	c.JSON(http.StatusOK, LoginResponse{Token: token, Admin: admin})
}
