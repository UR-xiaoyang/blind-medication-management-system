import api from './index'

// ========== 认证 ==========
export const login = (data) => api.post('/login', data)
export const initAdmin = (data) => api.post('/init-admin', data)
export const getProfile = () => api.get('/profile')

// ========== 统计 ==========
export const getStats = (params) => api.get('/stats', { params })

// ========== 患者管理 ==========
export const getPatients = (params) => api.get('/patients', { params })
export const getPatient = (id) => api.get(`/patients/${id}`)
export const createPatient = (data) => api.post('/patients', data)
export const updatePatient = (id, data) => api.put(`/patients/${id}`, data)
export const deletePatient = (id) => api.delete(`/patients/${id}`)

// ========== 药品管理 ==========
export const getMedications = (params) => api.get('/medications', { params })
export const getMedication = (id) => api.get(`/medications/${id}`)
export const createMedication = (data) => api.post('/medications', data)
export const updateMedication = (id, data) => api.put(`/medications/${id}`, data)
export const deleteMedication = (id) => api.delete(`/medications/${id}`)

// ========== 服药计划 ==========
export const getSchedules = (params) => api.get('/schedules', { params })
export const createSchedule = (data) => api.post('/schedules', data)
export const updateSchedule = (id, data) => api.put(`/schedules/${id}`, data)
export const deleteSchedule = (id) => api.delete(`/schedules/${id}`)

// ========== 按次服药包 ==========
export const getDosePackages = (params) => api.get('/dose-packages', { params })
export const createDosePackage = (data) => api.post('/dose-packages', data)
export const updateDosePackage = (id, data) => api.put(`/dose-packages/${id}`, data)
export const deleteDosePackage = (id) => api.delete(`/dose-packages/${id}`)

// ========== 出药操作 ==========
export const dispenseMedication = (data) => api.post('/dispense', data)

// ========== 服药记录 ==========
export const getMedicationLogs = (params) => api.get('/medication-logs', { params })

// ========== 设备管理 ==========
export const getDevices = (params) => api.get('/devices', { params })
export const getDevice = (id) => api.get(`/devices/${id}`)
export const createDevice = (data) => api.post('/devices', data)
export const updateDevice = (id, data) => api.put(`/devices/${id}`, data)
export const deleteDevice = (id) => api.delete(`/devices/${id}`)
export const getDeviceStatus = (deviceId) => api.get(`/devices/${deviceId}/status`)
export const getDeviceHeartbeats = (deviceId) => api.get(`/devices/${deviceId}/heartbeats`)
export const sendDeviceCommand = (deviceId, data) => api.post(`/devices/${deviceId}/command`, data)
// 设备访问 token 管理
export const getDeviceToken = (deviceId) => api.get(`/devices/${deviceId}/token`)
export const rotateDeviceToken = (deviceId) => api.post(`/devices/${deviceId}/rotate-token`)

// ========== 事件日志 ==========
export const getEventLogs = (params) => api.get('/event-logs', { params })
export const getEventLog = (id) => api.get(`/event-logs/${id}`)
export const createEventLog = (data) => api.post('/event-logs', data)
export const handleEventLog = (id, data) => api.put(`/event-logs/${id}/handle`, data)
export const deleteEventLog = (id) => api.delete(`/event-logs/${id}`)

// ========== 护理记录 ==========
export const getNursingRecords = (params) => api.get('/nursing-records', { params })
export const getNursingRecord = (id) => api.get(`/nursing-records/${id}`)
export const createNursingRecord = (data) => api.post('/nursing-records', data)
export const deleteNursingRecord = (id) => api.delete(`/nursing-records/${id}`)

// ========== 设备模拟器 ==========
export const simulatorPublish = (data) => api.post('/simulator/publish', data)
export const simulatorGetDevices = () => api.get('/simulator/devices')

// ========== 模拟器专用（无需认证） ==========
export const simulatorGetPatients = () => api.get('/simulator/patients')
export const simulatorGetDosePackages = (params) => api.get('/simulator/dose-packages', { params })
