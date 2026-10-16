<template>
  <div class="page-container">
    <!-- 统计卡片 -->
    <el-row :gutter="20" style="margin-bottom: 20px">
      <el-col :span="6" v-for="card in statCards" :key="card.title">
        <div class="stat-card">
          <div class="stat-icon" :style="{ background: card.color }">
            <el-icon :size="28" color="#fff"><component :is="card.icon" /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ card.value }}</div>
            <div class="stat-title">{{ card.title }}</div>
          </div>
        </div>
      </el-col>
    </el-row>

    <el-row :gutter="20">
      <!-- 今日服药概况 -->
      <el-col :span="14">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>📊 今日服药概况</span>
              <el-tag :type="complianceTag" size="small">
                依从率 {{ stats.compliance_rate?.toFixed(1) }}%
              </el-tag>
            </div>
          </template>
          <div ref="chartRef" style="height: 320px"></div>
        </el-card>
      </el-col>

      <!-- 设备状态 -->
      <el-col :span="10">
        <el-card>
          <template #header>
            <span>🔌 设备状态总览</span>
          </template>
          <div class="device-list" v-loading="loading">
            <div
              v-for="device in devices"
              :key="device.id"
              class="device-item"
            >
              <div class="device-info">
                <el-icon :size="20" :class="'status-' + device.status">
                  <Monitor />
                </el-icon>
                <div>
                  <div class="device-name">{{ device.device_name || device.device_id }}</div>
                  <div class="device-id">{{ device.device_id }}</div>
                </div>
              </div>
              <div class="device-meta">
                <el-tag
                  :type="device.status === 'online' ? 'success' : 'info'"
                  size="small"
                >
                  {{ device.status === 'online' ? '在线' : '离线' }}
                </el-tag>
                <span v-if="device.battery" class="battery">
                  🔋 {{ device.battery }}%
                </span>
              </div>
            </div>
            <el-empty v-if="!loading && devices.length === 0" description="暂无设备" :image-size="80" />
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getStats, getDevices } from '@/api/business'
import { useWebSocket } from '@/composables/useWebSocket'

const { on: onWS } = useWebSocket()

const loading = ref(false)
const stats = ref({})
const devices = ref([])
const chartRef = ref(null)

const statCards = computed(() => [
  { title: '患者总数', value: stats.value.total_patients || 0, icon: 'User', color: 'linear-gradient(135deg, #667eea, #764ba2)' },
  { title: '药品种类', value: stats.value.total_medications || 0, icon: 'FirstAidKit', color: 'linear-gradient(135deg, #f093fb, #f5576c)' },
  { title: '今日已服药', value: stats.value.today_taken || 0, icon: 'CircleCheck', color: 'linear-gradient(135deg, #4facfe, #00f2fe)' },
  { title: '在线设备', value: `${stats.value.online_devices || 0}/${stats.value.total_devices || 0}`, icon: 'Monitor', color: 'linear-gradient(135deg, #43e97b, #38f9d7)' },
])

const complianceTag = computed(() => {
  const rate = stats.value.compliance_rate || 100
  if (rate >= 90) return 'success'
  if (rate >= 70) return 'warning'
  return 'danger'
})

const initChart = () => {
  if (!chartRef.value) return
  const chart = echarts.init(chartRef.value)
  chart.setOption({
    tooltip: { trigger: 'item' },
    legend: { bottom: 0 },
    series: [
      {
        type: 'pie',
        radius: ['45%', '70%'],
        avoidLabelOverlap: false,
        itemStyle: { borderRadius: 8, borderColor: '#fff', borderWidth: 2 },
        label: { show: true, formatter: '{b}: {c}次' },
        data: [
          { value: stats.value.today_taken || 0, name: '已服药', itemStyle: { color: '#67c23a' } },
          { value: stats.value.today_missed || 0, name: '未服药', itemStyle: { color: '#f56c6c' } },
        ],
      },
    ],
  })
  window.addEventListener('resize', () => chart.resize())
}

const fetchData = async () => {
  loading.value = true
  try {
    const [statsRes, devicesRes] = await Promise.all([
      getStats(),
      getDevices(),
    ])
    stats.value = statsRes
    devices.value = devicesRes.data || []
    await nextTick()
    initChart()
  } finally {
    loading.value = false
  }
}

// ========== WebSocket 实时更新 ==========
// 设备状态变化 → 更新设备列表状态行 + 刷新在线设备统计
onWS('device_status_update', (msg) => {
  const deviceId = msg.device_id
  const data = msg.data || {}
  const row = devices.value.find(d => d.device_id === deviceId)
  if (row) {
    row.status = data.status || row.status
  }
  // 刷新统计（包含在线设备数）
  getStats().then(res => { stats.value = res })
})

// 心跳更新 → 更新设备在线状态
onWS('heartbeat_update', (msg) => {
  const deviceId = msg.device_id
  const data = msg.data || {}
  const row = devices.value.find(d => d.device_id === deviceId)
  if (row) {
    row.status = 'online'
    if (data.battery != null) row.battery = data.battery
  }
})

onMounted(fetchData)
</script>

<style scoped lang="scss">
.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;

  .stat-icon {
    width: 56px;
    height: 56px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .stat-info {
    .stat-value {
      font-size: 28px;
      font-weight: 700;
      color: #1a1a1a;
    }
    .stat-title {
      font-size: 13px;
      color: #999;
      margin-top: 4px;
    }
  }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.device-list {
  min-height: 200px;
}

.device-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 0;
  border-bottom: 1px solid #f0f0f0;

  &:last-child {
    border-bottom: none;
  }

  .device-info {
    display: flex;
    align-items: center;
    gap: 10px;

    .device-name {
      font-size: 14px;
      font-weight: 500;
    }
    .device-id {
      font-size: 12px;
      color: #999;
    }
  }

  .device-meta {
    display: flex;
    align-items: center;
    gap: 8px;

    .battery {
      font-size: 12px;
      color: #666;
    }
  }
}
</style>
