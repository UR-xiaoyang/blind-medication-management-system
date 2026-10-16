<template>
  <div class="page-container">
    <div class="page-header">
      <h2>📋 事件日志</h2>
      <el-button type="primary" @click="openCreateDialog()">
        <el-icon><Plus /></el-icon>手动创建事件
      </el-button>
    </div>

    <el-card>
      <el-row :gutter="16" style="margin-bottom:16px">
        <el-col :span="5">
          <el-select v-model="search.patientId" placeholder="按患者筛选" clearable @change="fetchData" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-col>
        <el-col :span="5">
          <el-select v-model="search.eventType" placeholder="事件类型" clearable @change="fetchData" style="width:100%">
            <el-option v-for="(label, key) in eventTypeMap" :key="key" :label="label" :value="key" />
          </el-select>
        </el-col>
        <el-col :span="4">
          <el-select v-model="search.severity" placeholder="严重等级" clearable @change="fetchData" style="width:100%">
            <el-option label="信息" value="info" />
            <el-option label="警告" value="warning" />
            <el-option label="错误" value="error" />
            <el-option label="严重" value="critical" />
          </el-select>
        </el-col>
        <el-col :span="4">
          <el-select v-model="search.status" placeholder="处理状态" clearable @change="fetchData" style="width:100%">
            <el-option label="待处理" value="pending" />
            <el-option label="处理中" value="processing" />
            <el-option label="已解决" value="resolved" />
            <el-option label="已忽略" value="ignored" />
          </el-select>
        </el-col>
      </el-row>

      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column label="事件类型" width="130">
          <template #default="{ row }">
            <el-tag size="small" :type="eventTypeTagType(row.event_type)">
              {{ eventTypeMap[row.event_type] || row.event_type }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="150" show-overflow-tooltip />
        <el-table-column label="患者" width="100">
          <template #default="{ row }">{{ row.patient?.name || '-' }}</template>
        </el-table-column>
        <el-table-column label="严重等级" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="severityTagType(row.severity)" effect="dark">
              {{ severityMap[row.severity] || row.severity }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="来源" width="80">
          <template #default="{ row }">{{ row.source === 'device' ? '设备' : '手动' }}</template>
        </el-table-column>
        <el-table-column label="处理状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="statusTagType(row.status)">
              {{ statusMap[row.status] || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="occurred_at" label="发生时间" width="170">
          <template #default="{ row }">{{ formatDate(row.occurred_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" size="small" @click="openHandleDialog(row)">处理</el-button>
            <el-popconfirm title="确定删除？" @confirm="handleDelete(row.id)">
              <template #reference>
                <el-button link type="danger" size="small">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        layout="total, sizes, prev, pager, next"
        style="margin-top:16px;justify-content:flex-end"
        @size-change="fetchData"
        @current-change="fetchData"
      />
    </el-card>

    <!-- 手动创建事件弹窗 -->
    <el-dialog v-model="createDialogVisible" title="手动创建事件" width="520px">
      <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="80px">
        <el-form-item label="患者" prop="patient_id">
          <el-select v-model="createForm.patient_id" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="事件类型" prop="event_type">
          <el-select v-model="createForm.event_type" style="width:100%">
            <el-option v-for="(label, key) in eventTypeMap" :key="key" :label="label" :value="key" />
          </el-select>
        </el-form-item>
        <el-form-item label="标题" prop="title">
          <el-input v-model="createForm.title" placeholder="简要描述事件" />
        </el-form-item>
        <el-form-item label="严重等级">
          <el-select v-model="createForm.severity" style="width:100%">
            <el-option label="信息" value="info" />
            <el-option label="警告" value="warning" />
            <el-option label="错误" value="error" />
            <el-option label="严重" value="critical" />
          </el-select>
        </el-form-item>
        <el-form-item label="详情">
          <el-input v-model="createForm.content" type="textarea" :rows="3" placeholder="事件详细描述" />
        </el-form-item>
        <el-form-item label="发生时间">
          <el-date-picker v-model="createForm.occurred_at" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width:100%" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleCreate">确定</el-button>
      </template>
    </el-dialog>

    <!-- 处理事件弹窗 -->
    <el-dialog v-model="handleDialogVisible" title="处理事件" width="520px">
      <div v-if="currentEvent" style="margin-bottom:16px">
        <el-descriptions :column="2" border size="small">
          <el-descriptions-item label="事件类型">{{ eventTypeMap[currentEvent.event_type] || currentEvent.event_type }}</el-descriptions-item>
          <el-descriptions-item label="严重等级">
            <el-tag :type="severityTagType(currentEvent.severity)" size="small" effect="dark">
              {{ severityMap[currentEvent.severity] || currentEvent.severity }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="标题" :span="2">{{ currentEvent.title }}</el-descriptions-item>
          <el-descriptions-item label="详情" :span="2">{{ currentEvent.content || '-' }}</el-descriptions-item>
          <el-descriptions-item label="患者">{{ currentEvent.patient?.name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="设备ID">{{ currentEvent.device_id || '-' }}</el-descriptions-item>
          <el-descriptions-item label="发生时间" :span="2">{{ formatDate(currentEvent.occurred_at) }}</el-descriptions-item>
        </el-descriptions>
      </div>
      <el-form ref="handleFormRef" :model="handleForm" :rules="handleRules" label-width="80px">
        <el-form-item label="处理状态" prop="status">
          <el-select v-model="handleForm.status" style="width:100%">
            <el-option label="已解决" value="resolved" />
            <el-option label="处理中" value="processing" />
            <el-option label="已忽略" value="ignored" />
          </el-select>
        </el-form-item>
        <el-form-item label="处理结果" prop="handle_result">
          <el-select v-model="handleForm.handle_result" style="width:100%" clearable allow-create filterable>
            <el-option label="已确认正常" value="confirmed_normal" />
            <el-option label="已通知家属" value="family_notified" />
            <el-option label="已派人上门" value="visit_dispatched" />
            <el-option label="已联系维修" value="repair_contacted" />
            <el-option label="无需处理" value="no_action" />
            <el-option label="其他" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="处理备注" prop="handle_note">
          <el-input v-model="handleForm.handle_note" type="textarea" :rows="3" placeholder="记录处理过程和备注" />
        </el-form-item>
      </el-form>
      <!-- 处理历史 -->
      <div v-if="currentEvent?.handler_id" style="margin-top:12px;padding:12px;background:#f5f7fa;border-radius:4px;">
        <p style="margin:0 0 4px;font-size:13px;color:#909399;">上次处理记录</p>
        <p style="margin:0;font-size:13px;">
          处理人: {{ currentEvent.handler?.real_name || currentEvent.handler?.username || '-' }}
          &nbsp;|&nbsp; 时间: {{ formatDate(currentEvent.handled_at) }}
          &nbsp;|&nbsp; 结果: {{ currentEvent.handle_result }}
        </p>
        <p v-if="currentEvent.handle_note" style="margin:4px 0 0;font-size:13px;color:#606266;">{{ currentEvent.handle_note }}</p>
      </div>
      <template #footer>
        <el-button @click="handleDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="submitHandle">确认处理</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import dayjs from 'dayjs'
import { ElMessage } from 'element-plus'
import { getEventLogs, createEventLog, handleEventLog, deleteEventLog, getPatients } from '@/api/business'

const loading = ref(false)
const tableData = ref([])
const patients = ref([])
const createDialogVisible = ref(false)
const handleDialogVisible = ref(false)
const currentEvent = ref(null)
const createFormRef = ref(null)
const handleFormRef = ref(null)
const search = reactive({ patientId: '', eventType: '', severity: '', status: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })

const eventTypeMap = {
  dispense_success: '出药成功',
  dispense_fail: '出药失败',
  medication_taken: '已服药',
  medication_missed: '未服药',
  sensor_alert: '传感器告警',
  device_error: '设备故障',
  device_online: '设备上线',
  device_offline: '设备离线',
  sos: 'SOS求助',
  custom: '自定义',
}

const severityMap = { info: '信息', warning: '警告', error: '错误', critical: '严重' }
const statusMap = { pending: '待处理', processing: '处理中', resolved: '已解决', ignored: '已忽略' }

const eventTypeTagType = (t) => {
  if (t === 'dispense_fail' || t === 'device_error' || t === 'medication_missed') return 'danger'
  if (t === 'sos') return 'danger'
  if (t === 'sensor_alert' || t === 'device_offline') return 'warning'
  if (t === 'dispense_success' || t === 'device_online' || t === 'medication_taken') return 'success'
  return 'info'
}

const severityTagType = (s) => {
  if (s === 'critical') return 'danger'
  if (s === 'error') return 'danger'
  if (s === 'warning') return 'warning'
  return 'info'
}

const statusTagType = (s) => {
  if (s === 'resolved') return 'success'
  if (s === 'ignored') return 'info'
  if (s === 'processing') return 'warning'
  return ''
}

const formatDate = (d) => d ? dayjs(d).format('YYYY-MM-DD HH:mm') : '-'

const defaultCreateForm = { patient_id: '', event_type: '', title: '', severity: 'info', content: '', occurred_at: '' }
const createForm = reactive({ ...defaultCreateForm })
const createRules = {
  patient_id: [{ required: true, message: '请选择患者', trigger: 'change' }],
  event_type: [{ required: true, message: '请选择事件类型', trigger: 'change' }],
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
}

const defaultHandleForm = { status: 'resolved', handle_result: '', handle_note: '' }
const handleForm = reactive({ ...defaultHandleForm })
const handleRules = {
  status: [{ required: true, message: '请选择处理状态', trigger: 'change' }],
  handle_note: [{ required: true, message: '请填写处理备注', trigger: 'blur' }],
}

const fetchData = async () => {
  loading.value = true
  try {
    const params = { page: pagination.page, page_size: pagination.pageSize }
    if (search.patientId) params.patient_id = search.patientId
    if (search.eventType) params.event_type = search.eventType
    if (search.severity) params.severity = search.severity
    if (search.status) params.status = search.status
    const res = await getEventLogs(params)
    tableData.value = res.data || []
    pagination.total = res.total || 0
  } finally {
    loading.value = false
  }
}

const openCreateDialog = () => {
  Object.assign(createForm, defaultCreateForm)
  createDialogVisible.value = true
}

const handleCreate = async () => {
  if (!createFormRef.value) return
  await createFormRef.value.validate(async (valid) => {
    if (!valid) return
    if (!createForm.occurred_at) createForm.occurred_at = dayjs().format('YYYY-MM-DD HH:mm:ss')
    await createEventLog(createForm)
    ElMessage.success('创建成功')
    createDialogVisible.value = false
    fetchData()
  })
}

const openHandleDialog = (row) => {
  currentEvent.value = row
  Object.assign(handleForm, {
    status: row.status === 'pending' ? 'resolved' : row.status,
    handle_result: row.handle_result || '',
    handle_note: '',
  })
  handleDialogVisible.value = true
}

const submitHandle = async () => {
  if (!handleFormRef.value) return
  await handleFormRef.value.validate(async (valid) => {
    if (!valid) return
    await handleEventLog(currentEvent.value.id, handleForm)
    ElMessage.success('处理成功')
    handleDialogVisible.value = false
    fetchData()
  })
}

const handleDelete = async (id) => {
  await deleteEventLog(id)
  ElMessage.success('删除成功')
  fetchData()
}

onMounted(async () => {
  fetchData()
  const res = await getPatients({ page_size: 100 })
  patients.value = res.data || []
})
</script>
