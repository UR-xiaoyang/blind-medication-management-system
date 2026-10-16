package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server   ServerConfig   `yaml:"server"`
	Database DatabaseConfig `yaml:"database"`
	JWT      JWTConfig      `yaml:"jwt"`
	MQTT     MQTTConfig     `yaml:"mqtt"`
}

type ServerConfig struct {
	Port int    `yaml:"port"`
	Mode string `yaml:"mode"`
}

type DatabaseConfig struct {
	Host         string `yaml:"host"`
	Port         int    `yaml:"port"`
	Username     string `yaml:"username"`
	Password     string `yaml:"password"`
	DBName       string `yaml:"dbname"`
	Charset      string `yaml:"charset"`
	MaxIdleConns int    `yaml:"max_idle_conns"`
	MaxOpenConns int    `yaml:"max_open_conns"`
}

type JWTConfig struct {
	Secret      string `yaml:"secret"`
	ExpireHours int    `yaml:"expire_hours"`
}

type MQTTConfig struct {
	Broker      string `yaml:"broker"`
	ClientID    string `yaml:"client_id"`
	Username    string `yaml:"username"`
	Password    string `yaml:"password"`
	TopicPrefix string `yaml:"topic_prefix"`
}

func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	cfg := &Config{}
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	// 设置默认值
	if cfg.Server.Port == 0 {
		cfg.Server.Port = 8080
	}
	if cfg.JWT.ExpireHours == 0 {
		cfg.JWT.ExpireHours = 24
	}
	if secret := os.Getenv("JWT_SECRET"); secret != "" {
		cfg.JWT.Secret = secret
	}
	if cfg.JWT.Secret == "" {
		return nil, fmt.Errorf("JWT_SECRET must be set")
	}

	return cfg, nil
}
