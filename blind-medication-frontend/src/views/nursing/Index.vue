<template>
  <div class="page-container">
    <div class="page-header">
      <h2>📓 护理记录</h2>
      <el-button type="primary" @click="openDialog()">
        <el-icon><Plus /></el-icon>新增记录
      </el-button>
    </div>

    <el-card>
      <el-row style="margin-bottom:16px">
        <el-col :span="6">
          <el-select v-model="searchPatientId" placeholder="按患者筛选" clearable @change="fetchData" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-col>
      </el-row>

      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column label="记录类型" width="130">
          <template #default="{ row }">
            <el-tag :type="nursingTypeTag(row.type)" size="small">
              {{ nursingTypeMap[row.type] || row.type }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="content" label="内容" show-overflow-tooltip />
        <el-table-column prop="created_at" label="记录时间" width="170">
          <template #default="{ row }">{{ formatDate(row.created_at) }}</template>
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
    <el-dialog v-model="dialogVisible" title="新增护理记录" width="500px">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="80px">
        <el-form-item label="患者" prop="patient_id">
          <el-select v-model="form.patient_id" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="记录类型" prop="type">
          <el-select v-model="form.type" style="width:100%">
            <el-option label="用药检查" value="medication_check" />
            <el-option label="健康走访" value="health_visit" />
            <el-option label="电话随访" value="phone_followup" />
            <el-option label="紧急事件" value="emergency" />
          </el-select>
        </el-form-item>
        <el-form-item label="内容" prop="content">
          <el-input v-model="form.content" type="textarea" :rows="4" placeholder="请输入护理记录内容..." />
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
import { getNursingRecords, createNursingRecord, deleteNursingRecord, getPatients } from '@/api/business'

const loading = ref(false)
const tableData = ref([])
const patients = ref([])
const searchPatientId = ref('')
const dialogVisible = ref(false)
const formRef = ref(null)
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })

const nursingTypeMap = {
  medication_check: '用药检查',
  health_visit: '健康走访',
  phone_followup: '电话随访',
  emergency: '紧急事件',
}
const nursingTypeTag = (t) => ({
  medication_check: 'primary',
  health_visit: 'success',
  phone_followup: 'info',
  emergency: 'danger',
}[t] || 'info')

const defaultForm = { patient_id: '', type: 'medication_check', content: '' }
const form = reactive({ ...defaultForm })
const rules = {
  patient_id: [{ required: true, message: '请选择患者', trigger: 'change' }],
  type: [{ required: true, message: '请选择类型', trigger: 'change' }],
  content: [{ required: true, message: '请输入内容', trigger: 'blur' }],
}

const formatDate = (d) => d ? dayjs(d).format('YYYY-MM-DD HH:mm') : '-'

const fetchData = async () => {
  loading.value = true
  try {
    const params = { page: pagination.page, page_size: pagination.pageSize }
    if (searchPatientId.value) params.patient_id = searchPatientId.value
    const res = await getNursingRecords(params)
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
    await createNursingRecord(form)
    ElMessage.success('创建成功')
    dialogVisible.value = false
    fetchData()
  })
}

const handleDelete = async (id) => {
  await deleteNursingRecord(id)
  ElMessage.success('删除成功')
  fetchData()
}

onMounted(async () => {
  fetchData()
  const res = await getPatients({ page_size: 100 })
  patients.value = res.data || []
})
</script>
