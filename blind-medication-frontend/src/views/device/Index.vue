<template>
  <div class="page-container">
    <div class="page-header">
      <h2>设备管理</h2>
      <div class="header-actions">
        <el-tag :type="wsConnected ? 'success' : 'danger'" size="small" effect="dark">
          {{ wsConnected ? '实时在线' : '实时断开' }}
        </el-tag>
        <el-button type="primary" @click="openDialog()">
          <el-icon><Plus /></el-icon>注册设备
        </el-button>
      </div>
    </div>

    <el-row :gutter="16">
      <el-col :span="16">
        <el-card>
          <el-table :data="tableData" v-loading="loading" stripe>
            <el-table-column prop="device_id" label="设备ID" min-width="170">
              <template #default="{ row }">
                <div class="device-id-cell">
                  <span
                    class="status-dot"
                    :class="row.status === 'online' ? 'dot-online' : 'dot-offline'"
                  />
                  <span>{{ row.device_id }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="device_name" label="设备名称" min-width="130" show-overflow-tooltip />
            <el-table-column label="固定出药能力" min-width="190" show-overflow-tooltip>
              <template #default="{ row }">
                <div class="capability-cell">
                  <el-tag size="small" :type="capabilityTag(row.dispense_mode)">
                    {{ capabilityModeText(row.dispense_mode) }}
                  </el-tag>
                  <span>{{ capabilitySummary(row) }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="90">
              <template #default="{ row }">
                <el-tag :type="row.status === 'online' ? 'success' : 'info'" size="small">
                  {{ row.status === 'online' ? '在线' : '离线' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="firmware" label="固件" width="120" show-overflow-tooltip />
            <el-table-column prop="ip_address" label="IP地址" width="140" />
            <el-table-column label="信号" width="90">
              <template #default="{ row }">
                <span v-if="row.signal">{{ row.signal }} dBm</span>
                <span v-else class="muted">-</span>
              </template>
            </el-table-column>
            <el-table-column prop="last_online" label="最后在线" width="170">
              <template #default="{ row }">{{ formatDate(row.last_online) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="350" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" size="small" @click="openDispense(row)" :disabled="row.status !== 'online'">
                  记录出药请求
                </el-button>
                <el-button link type="primary" size="small" @click="viewStatus(row)">
                  实时状态
                </el-button>
                <el-button link type="primary" size="small" @click="openTokenDialog(row)">
                  Token
                </el-button>
                <el-button link type="primary" size="small" @click="openDialog(row)">编辑</el-button>
                <el-popconfirm title="确定删除此设备？" @confirm="handleDelete(row.id)">
                  <template #reference>
                    <el-button link type="danger" size="small">删除</el-button>
                  </template>
                </el-popconfirm>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>

      <el-col :span="8">
        <el-card class="interaction-card">
          <template #header>
            <div class="interaction-header">
              <span>ESP 上报互动接收</span>
              <el-button size="small" text type="primary" @click="interactionLogs = []">清空</el-button>
            </div>
          </template>
          <div class="receive-box">
            <div class="receive-status">
              <el-tag :type="wsConnected ? 'success' : 'danger'" size="small">
                {{ wsConnected ? '正在接收' : '未连接' }}
              </el-tag>
              <span>实体 ESP 只负责上报，网页在这里接收心跳、结果和求助。</span>
            </div>
            <el-empty v-if="interactionLogs.length === 0" description="暂无设备上报" :image-size="60" />
            <div v-for="log in interactionLogs" :key="log.id" class="interaction-item">
              <div class="interaction-title">
                <el-tag size="small" :type="log.tagType">{{ log.type }}</el-tag>
                <span>{{ log.deviceId || '-' }}</span>
                <small>{{ log.time }}</small>
              </div>
              <p>{{ log.message }}</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑设备' : '注册设备'" width="640px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="110px">
        <el-form-item label="设备ID" prop="device_id">
          <el-input v-model="form.device_id" :disabled="isEdit" />
        </el-form-item>
        <el-form-item label="设备名称">
          <el-input v-model="form.device_name" placeholder="例如：张三的药机" />
        </el-form-item>
        <el-form-item label="固件版本">
          <el-input v-model="form.firmware" />
        </el-form-item>
        <el-divider content-position="left">固定出药能力收集</el-divider>
        <el-form-item label="出药模式">
          <el-segmented v-model="form.dispense_mode" :options="dispenseModeOptions" />
        </el-form-item>
        <el-form-item label="固定药品">
          <el-input v-model="form.fixed_medicine_name" placeholder="例如：降压药 / 一号药 / 早药包" />
        </el-form-item>
        <el-row :gutter="12">
          <el-col :span="12">
            <el-form-item label="固定号位">
              <el-input-number v-model="form.fixed_slot_index" :min="0" :max="99" style="width:100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="容量">
              <el-input-number v-model="form.fixed_capacity" :min="0" :max="999" style="width:100%" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="能力备注">
          <el-input
            v-model="form.capability_notes"
            type="textarea"
            :rows="3"
            placeholder="记录实体机器固定能出的药、机械限制、号位含义或需要人工确认的地方"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="tokenDialogVisible" title="设备访问 Token" width="560px">
      <el-alert
        type="warning"
        :closable="false"
        title="Token 是 ESP32 上报后端 API 的凭证，泄露后请立即重新生成。"
        style="margin-bottom: 12px"
      />
      <el-form label-width="80px">
        <el-form-item label="设备ID">
          <el-input :model-value="tokenDevice?.device_id" readonly />
        </el-form-item>
        <el-form-item label="API地址">
          <el-input :model-value="apiBaseUrl" readonly>
            <template #append>填入 ESP32 配置页</template>
          </el-input>
        </el-form-item>
        <el-form-item label="Token">
          <el-input
            v-model="tokenValue"
            readonly
            type="textarea"
            :autosize="{ minRows: 3, maxRows: 4 }"
            class="token-textarea"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="copyToken">复制 Token</el-button>
        <el-popconfirm title="重新生成后旧 Token 立即失效，确认？" @confirm="handleRotateToken">
          <template #reference>
            <el-button type="danger">重新生成</el-button>
          </template>
        </el-popconfirm>
        <el-button @click="tokenDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="dispenseVisible" title="记录出药请求" width="460px">
      <p class="dialog-tip">设备：{{ dispenseDevice?.device_id }}</p>
      <el-alert
        type="info"
        :closable="false"
        title="实体 ESP 不接收网页下发命令；这里会记录人工请求，最终结果以 ESP 上报为准。"
        style="margin-bottom: 12px"
      />
      <el-form label-width="90px">
        <el-form-item label="药包编号">
          <el-input-number v-model="dispensePackageIndex" :min="0" style="width:100%" />
          <div class="form-tip">填 0 时自动匹配该患者下一次待服药包。</div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dispenseVisible = false">取消</el-button>
        <el-button type="warning" :loading="dispenseLoading" @click="handleDispense">
          记录请求
        </el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="statusDrawerVisible" title="设备实时状态" size="420px">
      <div v-if="deviceStatus" class="status-panel">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="设备ID">{{ deviceStatus.device_id }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="deviceStatus.status === 'online' ? 'success' : 'danger'">
              {{ deviceStatus.status === 'online' ? '在线' : '离线' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="电量">{{ deviceStatus.battery ?? '-' }}%</el-descriptions-item>
          <el-descriptions-item label="温度">{{ deviceStatus.temperature ?? '-' }}°C</el-descriptions-item>
          <el-descriptions-item label="IP地址">{{ deviceStatus.ip_address || '-' }}</el-descriptions-item>
          <el-descriptions-item label="信号">{{ deviceStatus.signal ?? deviceStatus.wifi_rssi ?? '-' }} dBm</el-descriptions-item>
          <el-descriptions-item v-if="gravityChuteStatus" label="药道状态">
            <div class="chute-status">
              <el-tag :type="gravityChuteStatus.state === 'ready' ? 'success' : gravityChuteStatus.state === 'jammed' ? 'danger' : 'info'">
                {{ gravityChuteStatusText(gravityChuteStatus.state) }}
              </el-tag>
              <span>库存 {{ gravityChuteStatus.count }} / {{ gravityChuteStatus.capacity }}</span>
            </div>
          </el-descriptions-item>
          <el-descriptions-item v-else label="号位状态">
            <div class="slot-grid">
              <div
                v-for="(s, i) in parseSlotStates(deviceStatus.slot_states)"
                :key="i"
                class="slot-item"
                :class="s === '1' ? 'slot-filled' : 'slot-empty'"
              >
                {{ i + 1 }}: {{ s === '1' ? '有药' : '空' }}
              </div>
            </div>
          </el-descriptions-item>
        </el-descriptions>
      </div>
      <el-empty v-else description="无法获取设备状态" />
    </el-drawer>
  </div>
</template>

<script setup>
import { computed, ref, reactive, onMounted, onUnmounted } from 'vue'
import dayjs from 'dayjs'
import { ElMessage, ElNotification } from 'element-plus'
import { getDevices, createDevice, updateDevice, deleteDevice, getDeviceStatus, getDeviceToken, rotateDeviceToken, dispenseMedication } from '@/api/business'
import { useWebSocket } from '@/composables/useWebSocket'

const { connected: wsConnected, on: onWS } = useWebSocket()

const loading = ref(false)
const tableData = ref([])
const dialogVisible = ref(false)
const isEdit = ref(false)
const editId = ref(null)
const formRef = ref(null)

const dispenseVisible = ref(false)
const dispenseDevice = ref(null)
const dispensePackageIndex = ref(0)
const dispenseLoading = ref(false)

const statusDrawerVisible = ref(false)
const deviceStatus = ref(null)
let statusTimer = null
let refreshTimer = null

const interactionLogs = ref([])
let interactionSeq = 0

const defaultForm = {
  device_id: '',
  device_name: '',
  firmware: '',
  dispense_mode: 'fixed_medicine',
  fixed_medicine_name: '',
  fixed_slot_index: 1,
  fixed_capacity: 0,
  capability_notes: '',
}
const form = reactive({ ...defaultForm })
const rules = { device_id: [{ required: true, message: '请输入设备ID', trigger: 'blur' }] }

const dispenseModeOptions = [
  { label: '固定药', value: 'fixed_medicine' },
  { label: '固定号位', value: 'fixed_slot' },
  { label: '剂次包', value: 'dose_package' },
]

const formatDate = (d) => d ? dayjs(d).format('YYYY-MM-DD HH:mm:ss') : '-'

const capabilityModeText = (mode) => {
  if (mode === 'fixed_slot') return '固定号位'
  if (mode === 'dose_package') return '剂次包'
  return '固定药'
}

const capabilityTag = (mode) => {
  if (mode === 'fixed_slot') return 'warning'
  if (mode === 'dose_package') return 'success'
  return 'primary'
}

const capabilitySummary = (row) => {
  const parts = []
  if (row.fixed_medicine_name) parts.push(row.fixed_medicine_name)
  if (row.fixed_slot_index) parts.push(`${row.fixed_slot_index}号位`)
  if (row.fixed_capacity) parts.push(`容量${row.fixed_capacity}`)
  return parts.join(' / ') || '未填写'
}

const parseSlotStates = (s) => {
  if (!s) return ['0', '0', '0', '0', '0', '0', '0']
  return s.split(',').concat(Array(7).fill('0')).slice(0, 7)
}

const gravityChuteStatus = computed(() => {
  const raw = deviceStatus.value?.slot_states
  if (!raw || !raw.includes('mode=gravity_chute')) return null
  const data = Object.fromEntries(raw.split(';').map((part) => {
    const [key, value] = part.split('=')
    return [key, value]
  }))
  return {
    count: Number(data.count || 0),
    capacity: Number(data.capacity || 0),
    state: data.state || 'ready',
  }
})

const gravityChuteStatusText = (state) => {
  if (state === 'jammed') return '卡药'
  if (state === 'empty') return '空仓'
  return '可出药'
}

const addInteractionLog = (type, deviceId, message, tagType = 'info') => {
  interactionLogs.value.unshift({
    id: ++interactionSeq,
    type,
    deviceId,
    message,
    tagType,
    time: dayjs().format('HH:mm:ss'),
  })
  if (interactionLogs.value.length > 30) interactionLogs.value.length = 30
}

const tokenDialogVisible = ref(false)
const tokenDevice = ref(null)
const tokenValue = ref('')
const apiBaseUrl = window.location.origin

const openTokenDialog = async (row) => {
  tokenDevice.value = row
  tokenValue.value = ''
  tokenDialogVisible.value = true
  try {
    const res = await getDeviceToken(row.id)
    tokenValue.value = res.device_token || '(无 token，请点击“重新生成”)'
  } catch {
    tokenValue.value = '(加载失败，请重试)'
  }
}

const handleRotateToken = async () => {
  try {
    const res = await rotateDeviceToken(tokenDevice.value.id)
    tokenValue.value = res.device_token
    ElMessage.success('Token 已更新，请在 ESP32 配置页重新填写')
  } catch {
    ElMessage.error('更新失败')
  }
}

const copyToken = () => {
  if (!tokenValue.value) return
  navigator.clipboard.writeText(tokenValue.value)
    .then(() => ElMessage.success('已复制到剪贴板'))
    .catch(() => ElMessage.warning('复制失败，请手动选取'))
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await getDevices()
    tableData.value = res.data || []
  } finally {
    loading.value = false
  }
}

const openDialog = (row) => {
  isEdit.value = !!row
  editId.value = row?.id
  Object.assign(form, defaultForm, row || {})
  if (!form.dispense_mode) form.dispense_mode = 'fixed_medicine'
  dialogVisible.value = true
}

const handleSubmit = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    if (isEdit.value) {
      await updateDevice(editId.value, form)
      ElMessage.success('更新成功')
    } else {
      await createDevice(form)
      ElMessage.success('注册成功')
    }
    dialogVisible.value = false
    fetchData()
  })
}

const handleDelete = async (id) => {
  await deleteDevice(id)
  ElMessage.success('删除成功')
  fetchData()
}

const openDispense = (device) => {
  dispenseDevice.value = device
  dispensePackageIndex.value = 0
  dispenseVisible.value = true
}

const handleDispense = async () => {
  dispenseLoading.value = true
  try {
    await dispenseMedication({
      device_id: dispenseDevice.value.device_id,
      package_index: dispensePackageIndex.value || 0,
    })
    ElMessage.success('人工请求已记录，等待 ESP 上报真实出药结果')
    dispenseVisible.value = false
  } finally {
    dispenseLoading.value = false
  }
}

const viewStatus = async (device) => {
  statusDrawerVisible.value = true
  deviceStatus.value = null
  clearInterval(statusTimer)
  const fetchStatus = async () => {
    try {
      deviceStatus.value = await getDeviceStatus(device.device_id)
    } catch { /* ignore */ }
  }
  fetchStatus()
  statusTimer = setInterval(fetchStatus, 5000)
}

onWS('device_status_update', (msg) => {
  const deviceId = msg.device_id
  const statusData = msg.data || {}
  const row = tableData.value.find(r => r.device_id === deviceId)
  if (row) {
    row.status = statusData.status || row.status
    row.last_online = statusData.status === 'online' ? new Date().toISOString() : row.last_online
  }
  addInteractionLog('状态', deviceId, `设备${statusData.status === 'offline' ? '离线' : '上线'}`, statusData.status === 'offline' ? 'warning' : 'success')
})

onWS('heartbeat_update', (msg) => {
  const deviceId = msg.device_id
  const data = msg.data || {}
  const row = tableData.value.find(r => r.device_id === deviceId)
  if (row) {
    row.status = 'online'
    row.last_online = new Date().toISOString()
    if (data.wifi_rssi) row.signal = data.wifi_rssi
    if (data.ip_address) row.ip_address = data.ip_address
    if (data.firmware) row.firmware = data.firmware
  }
  if (statusDrawerVisible.value && deviceStatus.value?.device_id === deviceId) {
    deviceStatus.value = {
      ...deviceStatus.value,
      battery: data.battery ?? deviceStatus.value.battery,
      temperature: data.temperature ?? deviceStatus.value.temperature,
      slot_states: data.slot_states ?? deviceStatus.value.slot_states,
      wifi_rssi: data.wifi_rssi ?? deviceStatus.value.wifi_rssi,
      ip_address: data.ip_address ?? deviceStatus.value.ip_address,
      firmware: data.firmware ?? deviceStatus.value.firmware,
    }
  }
  addInteractionLog('心跳', deviceId, `电量 ${data.battery ?? '-'}%，信号 ${data.wifi_rssi ?? '-'} dBm`, 'success')
})

onWS('dispense_result', (msg) => {
  const data = msg.data || {}
  const success = data.success
  const errMsg = data.error || ''
  const deviceId = msg.device_id
  const title = success ? '出药成功' : '出药失败'
  const message = success ? `设备 ${deviceId} 已完成出药` : `设备 ${deviceId}: ${errMsg || '未说明原因'}`

  ElNotification({
    title,
    message,
    type: success ? 'success' : 'error',
    duration: success ? 5000 : 8000,
  })
  addInteractionLog('出药结果', deviceId, message, success ? 'success' : 'danger')
  fetchData()
})

onWS('sos', (msg) => {
  const reason = msg.data?.reason || '设备请求人工协助'
  addInteractionLog('求助', msg.device_id, reason, 'danger')
  ElNotification({
    title: '收到设备求助',
    message: `${msg.device_id}: ${reason}`,
    type: 'error',
    duration: 8000,
  })
})

onWS('manual_command', (msg) => {
  const text = msg.data?.message || '人工互动请求已记录'
  addInteractionLog('人工请求', msg.device_id, text, 'warning')
})

onMounted(() => {
  fetchData()
  refreshTimer = setInterval(fetchData, 30000)
})

onUnmounted(() => {
  clearInterval(refreshTimer)
  clearInterval(statusTimer)
})
</script>

<style scoped lang="scss">
.header-actions,
.device-id-cell,
.capability-cell,
.interaction-header,
.receive-status,
.interaction-title,
.chute-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.header-actions {
  margin-left: auto;
}

.capability-cell {
  min-width: 0;

  span:last-child {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.muted {
  color: #c0c4cc;
}

.interaction-card {
  height: 100%;
}

.receive-box {
  min-height: 360px;
}

.receive-status {
  align-items: flex-start;
  padding: 10px;
  margin-bottom: 12px;
  border-radius: 6px;
  background: #f5f7fa;
  color: #606266;
  font-size: 13px;
}

.interaction-item {
  padding: 10px 0;
  border-bottom: 1px solid #ebeef5;

  &:last-child {
    border-bottom: none;
  }

  p {
    margin: 6px 0 0;
    color: #303133;
    font-size: 13px;
    line-height: 1.5;
    word-break: break-word;
  }
}

.interaction-title {
  small {
    margin-left: auto;
    color: #909399;
  }
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;

  &.dot-online {
    background: #67c23a;
    box-shadow: 0 0 6px #67c23a;
  }

  &.dot-offline {
    background: #c0c4cc;
  }
}

.dialog-tip {
  margin: 0 0 12px;
  color: #606266;
}

.token-textarea {
  font-family: monospace;
}

.slot-grid {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.form-tip {
  width: 100%;
  margin-top: 6px;
  font-size: 12px;
  color: #909399;
}

.slot-item {
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 12px;

  &.slot-filled {
    background: #e1f3d8;
    color: #67c23a;
  }

  &.slot-empty {
    background: #f4f4f5;
    color: #999;
  }
}

@media (max-width: 1100px) {
  :deep(.el-col) {
    max-width: 100%;
    flex: 0 0 100%;
  }

  .interaction-card {
    margin-top: 16px;
  }
}
</style>
