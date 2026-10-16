<template>
  <div class="page-container">
    <div class="page-header">
      <h2>ESP32 重力药道模拟器</h2>
      <el-tag type="warning" size="large">模拟器用于测试管理网站真实数据交互</el-tag>
      <el-tag :type="wsConnected ? 'success' : 'danger'" size="large" effect="dark" style="margin-left: 12px">
        {{ wsConnected ? 'WS 已连接（可接收网站指令）' : 'WS 断开' }}
      </el-tag>
    </div>

    <el-row :gutter="20">
      <el-col :span="8">
        <el-card shadow="hover">
          <template #header>
            <span>模拟设备</span>
          </template>

          <!-- 绑定患者/剂次包选择 -->
          <el-divider content-position="left">测试场景绑定</el-divider>
          <el-form label-width="80px" size="default" style="margin-bottom: 12px">
            <el-form-item label="绑定患者">
              <el-select
                v-model="boundPatientId"
                placeholder="选择一个患者"
                filterable
                style="width: 100%"
                @change="onPatientChange"
              >
                <el-option
                  v-for="p in patientOptions"
                  :key="p.id"
                  :label="`${p.name}（ID: ${p.id}）`"
                  :value="p.id"
                />
              </el-select>
            </el-form-item>
            <el-form-item label="当前药包">
              <el-select
                v-model="boundDosePackageId"
                placeholder="自动：下一包 pending 药包"
                filterable
                clearable
                style="width: 100%"
              >
                <el-option label="自动（下一包 pending）" :value="0" />
                <el-option
                  v-for="dp in dosePackageOptions"
                  :key="dp.id"
                  :label="`#${dp.package_index} ${dp.name} [${dp.status}]`"
                  :value="dp.id"
                />
              </el-select>
            </el-form-item>
          </el-form>

          <el-descriptions :column="1" size="small" border>
            <el-descriptions-item label="设备 ID">{{ deviceID }}</el-descriptions-item>
            <el-descriptions-item label="药道状态">
              <el-tag :type="chuteStatusTag">{{ chuteStatusText }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="库存">{{ chuteForm.pill_count }} / {{ chuteForm.capacity }}</el-descriptions-item>
          </el-descriptions>

          <el-divider content-position="left">设备状态</el-divider>

          <div class="quick-actions">
            <el-button type="success" :loading="sending" style="width: 48%" @click="sendStatus('online')">
              上线
            </el-button>
            <el-button type="danger" :loading="sending" style="width: 48%" @click="sendStatus('offline')">
              下线
            </el-button>
          </div>

          <el-divider content-position="left">自动心跳</el-divider>

          <el-form label-width="80px" size="default">
            <el-form-item label="间隔(秒)">
              <el-input-number v-model="autoHeartbeatInterval" :min="5" :max="300" style="width: 100%" />
            </el-form-item>
            <el-form-item>
              <el-button
                :type="autoHeartbeatRunning ? 'danger' : 'primary'"
                style="width: 100%"
                @click="toggleAutoHeartbeat"
              >
                {{ autoHeartbeatRunning ? '停止自动心跳' : '启动自动心跳' }}
              </el-button>
            </el-form-item>
          </el-form>

          <div v-if="autoHeartbeatRunning" class="auto-status">
            <el-tag type="success" effect="dark" size="small">
              自动心跳运行中，每 {{ autoHeartbeatInterval }} 秒发送一次
            </el-tag>
          </div>

          <el-divider content-position="left">链路模式</el-divider>

          <el-form label-width="96px" size="default">
            <el-form-item label="转发 MQTT">
              <el-switch v-model="forwardMQTT" active-text="开启" inactive-text="关闭" />
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>

      <el-col :span="16">
        <el-card shadow="hover" class="action-card">
          <template #header>
            <span>竖直药道</span>
          </template>

          <div class="chute-panel">
            <div class="chute-view">
              <div class="chute-track">
                <div
                  v-for="pill in visiblePills"
                  :key="pill"
                  class="pill"
                  :class="{ dropping: isDropping && pill === visiblePills.length }"
                />
                <div v-if="chuteForm.jammed" class="jam-marker">卡药</div>
              </div>
              <div class="gate" :class="{ open: gateOpen }">
                <span>{{ gateOpen ? '闸门打开' : '闸门关闭' }}</span>
              </div>
              <div class="cup" :class="{ active: isDropping }">
                <span>{{ lastDropText }}</span>
              </div>
            </div>

            <el-form :model="chuteForm" label-width="96px" size="default" class="chute-form">
              <el-row :gutter="16">
                <el-col :span="8">
                  <el-form-item label="最大容量">
                    <el-input-number v-model="chuteForm.capacity" :min="1" :max="30" style="width: 100%" @change="clampPillCount" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item label="当前药片">
                    <el-input-number v-model="chuteForm.pill_count" :min="0" :max="chuteForm.capacity" style="width: 100%" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item label="下落耗时">
                    <el-input-number v-model="chuteForm.drop_ms" :min="100" :max="5000" :step="100" style="width: 100%" />
                  </el-form-item>
                </el-col>
              </el-row>
              <el-row :gutter="16">
                <el-col :span="8">
                  <el-form-item label="电量(%)">
                    <el-input-number v-model="heartbeatForm.battery" :min="0" :max="100" style="width: 100%" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item label="信号(dBm)">
                    <el-input-number v-model="heartbeatForm.wifi_rssi" :min="-100" :max="0" style="width: 100%" />
                  </el-form-item>
                </el-col>
                <el-col :span="8">
                  <el-form-item label="卡药">
                    <el-switch v-model="chuteForm.jammed" active-text="是" inactive-text="否" />
                  </el-form-item>
                </el-col>
              </el-row>
              <el-form-item>
                <div class="button-row">
                  <el-button type="primary" :loading="sending" @click="sendHeartbeat">发送心跳</el-button>
                  <el-button type="warning" :loading="sending || isDropping" @click="simulateDrop">模拟下落出药</el-button>
                  <el-button plain @click="refillChute">补满药道</el-button>
                  <el-button plain type="danger" @click="clearJam">清除卡药</el-button>
                </div>
              </el-form-item>
            </el-form>
          </div>
        </el-card>

        <el-card shadow="hover" class="action-card">
          <template #header>
            <span>求助消息</span>
          </template>

          <el-form :model="sosForm" label-width="90px" size="default">
            <el-row :gutter="16">
              <el-col :span="16">
                <el-form-item label="求助原因">
                  <el-input v-model="sosForm.reason" placeholder="例如：药片卡在竖直药道中" />
                </el-form-item>
              </el-col>
              <el-col :span="8">
                <el-form-item>
                  <el-button type="danger" :loading="sending" @click="sendSOS">发送求助</el-button>
                </el-form-item>
              </el-col>
            </el-row>
          </el-form>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="hover" class="log-card">
      <template #header>
        <div class="log-header">
          <span>消息日志</span>
          <div>
            <el-tag size="small" type="info" style="margin-right: 8px">{{ logs.length }} 条</el-tag>
            <el-button size="small" type="danger" plain @click="logs = []">清空日志</el-button>
          </div>
        </div>
      </template>

      <div class="log-container">
        <el-empty v-if="logs.length === 0" description="暂无消息记录" :image-size="60" />
        <div v-for="(log, i) in logs" :key="i" class="log-item">
          <span class="log-time">{{ log.time }}</span>
          <el-tag :type="log.tagType" size="small" class="log-tag">{{ log.topic }}</el-tag>
          <span class="log-payload">{{ log.payload }}</span>
        </div>
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { computed, ref, reactive, onMounted, onUnmounted } from 'vue'
import dayjs from 'dayjs'
import { ElMessage } from 'element-plus'
import { simulatorPublish, simulatorGetPatients, simulatorGetDosePackages, updateDevice } from '@/api/business'
import { useWebSocket } from '@/composables/useWebSocket'

const { connected: wsConnected, on: onWS, send: sendWS } = useWebSocket()

const deviceID = 'sim-gravity-001'
const sending = ref(false)
const forwardMQTT = ref(false)
const gateOpen = ref(false)
const isDropping = ref(false)
const lastDropText = ref('等待出药')

// 绑定场景：患者 + 剂次包
const patientOptions = ref([])
const dosePackageOptions = ref([])
const boundPatientId = ref(null)
const boundDosePackageId = ref(0) // 0 = 自动

const heartbeatForm = reactive({
  battery: 85,
  wifi_rssi: -65,
  ip_address: '192.168.1.100',
  firmware: 'gravity-sim-v1.0.0',
})

const chuteForm = reactive({
  capacity: 12,
  pill_count: 8,
  drop_ms: 900,
  jammed: false,
})

const sosForm = reactive({
  reason: '',
})

const logs = ref([])

const chuteState = computed(() => {
  if (chuteForm.jammed) return 'jammed'
  if (chuteForm.pill_count <= 0) return 'empty'
  return 'ready'
})

const chuteStatusText = computed(() => {
  if (chuteState.value === 'jammed') return '卡药'
  if (chuteState.value === 'empty') return '空仓'
  return '可出药'
})

const chuteStatusTag = computed(() => {
  if (chuteState.value === 'jammed') return 'danger'
  if (chuteState.value === 'empty') return 'info'
  return 'success'
})

const visiblePills = computed(() => {
  const count = Math.min(chuteForm.pill_count, 10)
  return Array.from({ length: count }, (_, i) => i + 1)
})

const slotStateText = computed(() => [
  `mode=gravity_chute`,
  `count=${chuteForm.pill_count}`,
  `capacity=${chuteForm.capacity}`,
  `state=${chuteState.value}`,
].join(';'))

const clampPillCount = () => {
  if (chuteForm.pill_count > chuteForm.capacity) {
    chuteForm.pill_count = chuteForm.capacity
  }
}

const addLog = (topicSuffix, payload) => {
  const topicMap = {
    heartbeat: { label: 'heartbeat', tagType: 'success' },
    status: { label: 'status', tagType: 'warning' },
    dispense_result: { label: 'dispense_result', tagType: 'danger' },
    dispense_command: { label: 'dispense_command', tagType: 'primary' },
    sos: { label: 'sos', tagType: '' },
  }
  const meta = topicMap[topicSuffix] || { label: topicSuffix, tagType: 'info' }
  logs.value.unshift({
    time: dayjs().format('HH:mm:ss'),
    topic: meta.label,
    tagType: meta.tagType,
    payload: typeof payload === 'string' ? payload : JSON.stringify(payload),
  })
  if (logs.value.length > 100) logs.value.length = 100
}

const publishMessage = async (topicSuffix, payloadObj) => {
  sending.value = true
  try {
    const fullPayload = {
      device_id: deviceID,
      type: topicSuffix,
      timestamp: Math.floor(Date.now() / 1000),
      ...payloadObj,
    }
    // 把当前绑定的患者/剂次包 ID 注入到 payload（让后端据此修改数据库）
    if (boundPatientId.value != null) {
      fullPayload.patient_id = boundPatientId.value
    }
    // 优先用显式选择的 dose_package_id；否则用 0（让后端通过 patient_id + package_index 自动匹配 pending 包）
    if (boundDosePackageId.value && boundDosePackageId.value > 0) {
      fullPayload.dose_package_id = boundDosePackageId.value
    } else {
      // 通过 package_index 匹配当前患者的第一个 pending 药包
      const pending = dosePackageOptions.value.find(dp => dp.status === 'pending')
      if (pending) {
        fullPayload.dose_package_id = pending.id
        fullPayload.package_index = pending.package_index
      } else {
        fullPayload.dose_package_id = 0
        fullPayload.package_index = boundDosePackageId.value || 1
      }
    }
    await simulatorPublish({
      device_id: deviceID,
      topic_suffix: topicSuffix,
      payload: fullPayload,
      forward_mqtt: forwardMQTT.value,
    })
    addLog(topicSuffix, fullPayload)
    return true
  } catch (err) {
    ElMessage.error('发送失败: ' + (err.response?.data?.error || err.message))
    return false
  } finally {
    sending.value = false
  }
}

const sendStatus = async (statusType) => {
  await publishMessage('status', { type: statusType, status: statusType })
}

const sendHeartbeat = async () => {
  await publishMessage('heartbeat', {
    battery: heartbeatForm.battery,
    wifi_rssi: heartbeatForm.wifi_rssi,
    ip_address: heartbeatForm.ip_address,
    firmware: heartbeatForm.firmware,
    slot_states: slotStateText.value,
    chute_mode: 'gravity',
    pill_count: chuteForm.pill_count,
    capacity: chuteForm.capacity,
    chute_state: chuteState.value,
    jammed: chuteForm.jammed,
  })
}

const simulateDrop = async () => {
  if (isDropping.value) return

  gateOpen.value = true
  isDropping.value = true
  lastDropText.value = '下落中'

  await new Promise(resolve => setTimeout(resolve, chuteForm.drop_ms))

  let success = true
  let error = ''
  if (chuteForm.jammed) {
    success = false
    error = '药片卡在竖直药道中'
    lastDropText.value = '卡药'
  } else if (chuteForm.pill_count <= 0) {
    success = false
    error = '药道为空'
    lastDropText.value = '空仓'
  } else {
    chuteForm.pill_count -= 1
    lastDropText.value = '已出药'
  }

  gateOpen.value = false
  isDropping.value = false

  await publishMessage('dispense_result', {
    slot_index: 1,
    package_index: 1,
    success,
    error,
    chute_mode: 'gravity',
    pill_count: chuteForm.pill_count,
    capacity: chuteForm.capacity,
    chute_state: chuteState.value,
    jammed: chuteForm.jammed,
    slot_states: slotStateText.value,
  })
  // 出药后刷新当前患者的剂次包列表
  if (boundPatientId.value) await loadDosePackages(boundPatientId.value)
  await sendHeartbeat()
}

const refillChute = () => {
  chuteForm.pill_count = chuteForm.capacity
  chuteForm.jammed = false
  lastDropText.value = '已补满'
}

const clearJam = () => {
  chuteForm.jammed = false
  lastDropText.value = '卡药已清除'
}

const sendSOS = async () => {
  await publishMessage('sos', {
    reason: sosForm.reason || '用户需要人工协助检查竖直药道',
    chute_mode: 'gravity',
    pill_count: chuteForm.pill_count,
    capacity: chuteForm.capacity,
    chute_state: chuteState.value,
    jammed: chuteForm.jammed,
  })
}

const autoHeartbeatInterval = ref(30)
const autoHeartbeatRunning = ref(false)
let autoHeartbeatTimer = null

const toggleAutoHeartbeat = () => {
  if (autoHeartbeatRunning.value) {
    clearInterval(autoHeartbeatTimer)
    autoHeartbeatTimer = null
    autoHeartbeatRunning.value = false
    ElMessage.info('自动心跳已停止')
  } else {
    autoHeartbeatRunning.value = true
    sendHeartbeat()
    autoHeartbeatTimer = setInterval(() => {
      sendHeartbeat()
    }, autoHeartbeatInterval.value * 1000)
    ElMessage.success(`自动心跳已启动，每 ${autoHeartbeatInterval.value} 秒发送一次`)
  }
}

// ========== 加载患者与剂次包选项 ==========
const loadPatients = async () => {
  try {
    const res = await simulatorGetPatients()
    patientOptions.value = res || []
    if (patientOptions.value.length > 0 && boundPatientId.value == null) {
      boundPatientId.value = patientOptions.value[0].id
      await loadDosePackages(boundPatientId.value)
    }
  } catch (e) {
    console.error('加载患者失败', e)
  }
}

const loadDosePackages = async (patientId) => {
  if (!patientId) {
    dosePackageOptions.value = []
    return
  }
  try {
    const res = await simulatorGetDosePackages({ patient_id: patientId })
    dosePackageOptions.value = res || []
  } catch (e) {
    console.error('加载剂次包失败', e)
  }
}

const onPatientChange = async (val) => {
  boundPatientId.value = val
  boundDosePackageId.value = 0
  await loadDosePackages(val)
}

// ========== WebSocket：注册为模拟器，监听出药指令 ==========
onWS('ack', () => {})
onWS('dispense_command', (msg) => {
  const data = msg.data || {}
  const pkgIndex = data.package_index ?? data.PackageIndex ?? 0
  const items = data.items || []
  const label = items.length > 0
    ? items.map(it => `${it.name}×${it.quantity}`).join('、')
    : `药包 #${pkgIndex}`

  ElMessage({ type: 'info', message: `收到网站出药指令：${label}，开始模拟下落...` })
  addLog('dispense_command', data)
  // 自动执行下落
  simulateDrop()
})

onMounted(async () => {
  // 注册 WebSocket 角色
  sendWS('register', { role: 'simulator', device_id: deviceID })
  // 加载测试场景选项
  await loadPatients()
  // 保持原有的 HTTP 通知（双通道保证）
  await sendStatus('online')
  await sendHeartbeat()
})

onUnmounted(() => {
  if (autoHeartbeatTimer) {
    clearInterval(autoHeartbeatTimer)
  }
})
</script>

<style scoped lang="scss">
.page-container {
  .page-header {
    display: flex;
    align-items: center;
    gap: 16px;
    margin-bottom: 20px;

    h2 {
      margin: 0;
    }
  }
}

.action-card {
  margin-bottom: 16px;
}

.quick-actions {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
}

.auto-status {
  text-align: center;
  margin-top: 8px;
}

.chute-panel {
  display: grid;
  grid-template-columns: 180px 1fr;
  gap: 20px;
  align-items: start;
}

.chute-view {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.chute-track {
  position: relative;
  display: flex;
  flex-direction: column-reverse;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
  width: 96px;
  height: 320px;
  padding: 12px 0;
  border: 2px solid #6b7280;
  border-radius: 6px;
  background: #f8fafc;
  overflow: hidden;
}

.pill {
  width: 48px;
  height: 18px;
  border-radius: 999px;
  background: linear-gradient(90deg, #ffffff 0 50%, #67c23a 50% 100%);
  border: 1px solid #4b5563;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.18);

  &.dropping {
    animation: drop-pill 0.9s ease-in-out infinite;
  }
}

.jam-marker {
  position: absolute;
  top: 44%;
  left: 50%;
  transform: translateX(-50%);
  padding: 2px 8px;
  border-radius: 4px;
  background: #f56c6c;
  color: #fff;
  font-size: 12px;
}

.gate {
  width: 112px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  background: #374151;
  color: #fff;
  font-size: 12px;

  &.open {
    background: #67c23a;
  }
}

.cup {
  width: 124px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid #9ca3af;
  border-top: none;
  border-radius: 0 0 8px 8px;
  color: #4b5563;
  font-size: 12px;

  &.active {
    border-color: #e6a23c;
    color: #b45309;
  }
}

.chute-form {
  min-width: 0;
}

.button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.log-card {
  margin-top: 16px;
}

.log-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.log-container {
  max-height: 320px;
  overflow-y: auto;
}

.log-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 0;
  border-bottom: 1px solid #f5f5f5;

  &:last-child {
    border-bottom: none;
  }

  .log-time {
    font-size: 12px;
    color: #999;
    flex-shrink: 0;
  }

  .log-tag {
    flex-shrink: 0;
  }

  .log-payload {
    font-size: 12px;
    color: #333;
    word-break: break-all;
  }
}

@keyframes drop-pill {
  from {
    transform: translateY(-18px);
  }

  to {
    transform: translateY(54px);
  }
}

@media (max-width: 900px) {
  .chute-panel {
    grid-template-columns: 1fr;
  }
}
</style>
