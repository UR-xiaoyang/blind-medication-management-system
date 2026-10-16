<template>
  <div class="page-container">
    <div class="page-header">
      <h2>👤 患者管理</h2>
      <el-button type="primary" @click="openDialog()">
        <el-icon><Plus /></el-icon>新增患者
      </el-button>
    </div>

    <!-- 搜索栏 -->
    <el-card style="margin-bottom: 16px">
      <el-row :gutter="16">
        <el-col :span="8">
          <el-input
            v-model="search.keyword"
            placeholder="搜索姓名或电话"
            :prefix-icon="Search"
            clearable
            @keyup.enter="fetchData"
          />
        </el-col>
        <el-col :span="4">
          <el-button type="primary" @click="fetchData">查询</el-button>
        </el-col>
      </el-row>
    </el-card>

    <!-- 数据表格 -->
    <el-card>
      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="姓名" width="100" />
        <el-table-column prop="gender" label="性别" width="70" />
        <el-table-column prop="age" label="年龄" width="70" />
        <el-table-column prop="phone" label="电话" width="130" />
        <el-table-column prop="device_id" label="绑定设备" width="160">
          <template #default="{ row }">
            <el-tag v-if="row.device_id" type="info" size="small">{{ row.device_id }}</el-tag>
            <span v-else style="color:#ccc">未绑定</span>
          </template>
        </el-table-column>
        <el-table-column prop="emergency_name" label="紧急联系人" width="120" />
        <el-table-column prop="emergency_phone" label="紧急电话" width="130" />
        <el-table-column label="操作" width="220" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="router.push(`/patients/${row.id}`)">详情</el-button>
            <el-button link type="primary" @click="openDialog(row)">编辑</el-button>
            <el-popconfirm title="确定删除此患者？" @confirm="handleDelete(row.id)">
              <template #reference>
                <el-button link type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        :page-sizes="[10, 20, 50]"
        layout="total, sizes, prev, pager, next"
        style="margin-top: 16px; justify-content: flex-end"
        @size-change="fetchData"
        @current-change="fetchData"
      />
    </el-card>

    <!-- 新增/编辑弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? '编辑患者' : '新增患者'"
      width="600px"
    >
      <el-form ref="formRef" :model="form" :rules="rules" label-width="100px">
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="姓名" prop="name">
              <el-input v-model="form.name" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="性别" prop="gender">
              <el-select v-model="form.gender" style="width: 100%">
                <el-option label="男" value="男" />
                <el-option label="女" value="女" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="年龄">
              <el-input-number v-model="form.age" :min="0" :max="150" style="width: 100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="电话">
              <el-input v-model="form.phone" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="地址">
          <el-input v-model="form.address" />
        </el-form-item>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="紧急联系人">
              <el-input v-model="form.emergency_name" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="紧急电话">
              <el-input v-model="form.emergency_phone" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="绑定设备">
          <el-input v-model="form.device_id" placeholder="ESP32设备ID" />
        </el-form-item>
        <el-form-item label="医疗备注">
          <el-input v-model="form.medical_notes" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="handleSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import { getPatients, createPatient, updatePatient, deletePatient } from '@/api/business'

const router = useRouter()
const loading = ref(false)
const submitting = ref(false)
const dialogVisible = ref(false)
const isEdit = ref(false)
const editId = ref(null)
const formRef = ref(null)
const tableData = ref([])

const search = reactive({ keyword: '' })
const pagination = reactive({ page: 1, pageSize: 10, total: 0 })

const defaultForm = {
  name: '', gender: '男', age: 0, phone: '', address: '',
  emergency_name: '', emergency_phone: '', device_id: '', medical_notes: '',
}
const form = reactive({ ...defaultForm })
const rules = {
  name: [{ required: true, message: '请输入姓名', trigger: 'blur' }],
}

const fetchData = async () => {
  loading.value = true
  try {
    const res = await getPatients({
      page: pagination.page,
      page_size: pagination.pageSize,
      keyword: search.keyword,
    })
    tableData.value = res.data || []
    pagination.total = res.total || 0
  } finally {
    loading.value = false
  }
}

const openDialog = (row) => {
  isEdit.value = !!row
  editId.value = row?.id
  Object.assign(form, row || defaultForm)
  dialogVisible.value = true
}

const handleSubmit = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    submitting.value = true
    try {
      if (isEdit.value) {
        await updatePatient(editId.value, form)
        ElMessage.success('更新成功')
      } else {
        await createPatient(form)
        ElMessage.success('创建成功')
      }
      dialogVisible.value = false
      fetchData()
    } finally {
      submitting.value = false
    }
  })
}

const handleDelete = async (id) => {
  await deletePatient(id)
  ElMessage.success('删除成功')
  fetchData()
}

onMounted(fetchData)
</script>
