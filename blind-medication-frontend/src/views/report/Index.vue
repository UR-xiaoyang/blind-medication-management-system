<template>
  <div class="page-container">
    <div class="page-header">
      <h2>📋 检测报告</h2>
      <el-button type="primary" @click="openDialog()">
        <el-icon><Plus /></el-icon>新增报告
      </el-button>
    </div>

    <el-card>
      <el-row :gutter="16" style="margin-bottom:16px">
        <el-col :span="6">
          <el-select v-model="search.patientId" placeholder="按患者筛选" clearable @change="fetchData" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-col>
        <el-col :span="6">
          <el-select v-model="search.type" placeholder="报告类型" clearable @change="fetchData" style="width:100%">
            <el-option label="血压" value="blood_pressure" />
            <el-option label="血糖" value="blood_sugar" />
            <el-option label="心率" value="heart_rate" />
            <el-option label="体温" value="temperature" />
            <el-option label="其他" value="other" />
          </el-select>
        </el-col>
      </el-row>

      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column label="报告类型" width="120">
          <template #default="{ row }">
            <el-tag size="small">{{ reportTypeMap[row.type] || row.type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="value" label="数值" width="120" />
        <el-table-column prop="unit" label="单位" width="80" />
        <el-table-column prop="source" label="来源" width="80">
          <template #default="{ row }">
            {{ row.source === 'manual' ? '手动' : '设备' }}
          </template>
        </el-table-column>
        <el-table-column prop="notes" label="备注" show-overflow-tooltip />
        <el-table-column prop="taken_at" label="检测时间" width="170">
          <template #default="{ row }">{{ formatDate(row.taken_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
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

    <!-- 新增弹窗 -->
    <el-dialog v-model="dialogVisible" title="新增检测报告" width="500px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="患者" prop="patient_id">
          <el-select v-model="form.patient_id" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="报告类型" prop="type">
          <el-select v-model="form.type" style="width:100%">
            <el-option label="血压" value="blood_pressure" />
            <el-option label="血糖" value="blood_sugar" />
            <el-option label="心率" value="heart_rate" />
            <el-option label="体温" value="temperature" />
            <el-option label="其他" value="other" />
          </el-select>
        </el-form-item>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="数值" prop="value">
              <el-input v-model="form.value" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="单位">
              <el-input v-model="form.unit" placeholder="如：mmHg, mmol/L" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="检测时间">
          <el-date-picker v-model="form.taken_at" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" style="width:100%" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.notes" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import dayjs from 'dayjs'
import { ElMessage } from 'element-plus'
import { getReports, createReport, deleteReport, getPatients } from '@/api/business'

const loading = ref(false)
const tableData = ref([])
const patients = ref([])
const dialogVisible = ref(false)
const formRef = ref(null)
const search = reactive({ patientId: '', type: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })

const reportTypeMap = {
  blood_pressure: '血压',
  blood_sugar: '血糖',
  heart_rate: '心率',
  temperature: '体温',
  other: '其他',
}

const defaultForm = { patient_id: '', type: '', value: '', unit: '', taken_at: '', notes: '' }
const form = reactive({ ...defaultForm })
const rules = {
  patient_id: [{ required: true, message: '请选择患者', trigger: 'change' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }],
  value: [{ required: true, message: '请输入数值', trigger: 'blur' }],
}

const formatDate = (d) => d ? dayjs(d).format('YYYY-MM-DD HH:mm') : '-'

const fetchData = async () => {
  loading.value = true
  try {
    const params = { page: pagination.page, page_size: pagination.pageSize }
    if (search.patientId) params.patient_id = search.patientId
    if (search.type) params.type = search.type
    const res = await getReports(params)
    tableData.value = res.data || []
    pagination.total = res.total || 0
  } finally {
    loading.value = false
  }
}

const openDialog = () => {
  Object.assign(form, defaultForm)
  dialogVisible.value = true
}

const handleSubmit = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    if (!form.taken_at) form.taken_at = dayjs().format('YYYY-MM-DD HH:mm:ss')
    await createReport(form)
    ElMessage.success('创建成功')
    dialogVisible.value = false
    fetchData()
  })
}

const handleDelete = async (id) => {
  await deleteReport(id)
  ElMessage.success('删除成功')
  fetchData()
}

onMounted(async () => {
  fetchData()
  const res = await getPatients({ page_size: 100 })
  patients.value = res.data || []
})
</script>
