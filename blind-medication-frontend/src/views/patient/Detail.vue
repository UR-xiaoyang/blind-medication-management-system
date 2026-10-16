<template>
  <div class="page-container" v-loading="loading">
    <div class="page-header">
      <div style="display:flex;align-items:center;gap:12px">
        <el-button :icon="ArrowLeft" @click="router.push('/patients')">返回</el-button>
        <h2>患者详情 - {{ patient.name }}</h2>
      </div>
    </div>

    <el-row :gutter="20">
      <el-col :span="8">
        <el-card>
          <template #header><span>基本信息</span></template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="姓名">{{ patient.name }}</el-descriptions-item>
            <el-descriptions-item label="性别">{{ patient.gender }}</el-descriptions-item>
            <el-descriptions-item label="年龄">{{ patient.age }}</el-descriptions-item>
            <el-descriptions-item label="电话">{{ patient.phone }}</el-descriptions-item>
            <el-descriptions-item label="地址">{{ patient.address }}</el-descriptions-item>
            <el-descriptions-item label="紧急联系人">{{ patient.emergency_name }}</el-descriptions-item>
            <el-descriptions-item label="紧急电话">{{ patient.emergency_phone }}</el-descriptions-item>
            <el-descriptions-item label="绑定设备">
              <el-tag v-if="patient.device_id" type="success">{{ patient.device_id }}</el-tag>
              <span v-else style="color:#ccc">未绑定</span>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <el-col :span="16">
        <el-card>
          <template #header>
            <div style="display:flex;justify-content:space-between;align-items:center">
              <span>药品档案</span>
              <el-button type="primary" size="small" @click="openMedDialog()">
                <el-icon><Plus /></el-icon>新增药品
              </el-button>
            </div>
          </template>
          <el-table :data="patient.medications || []" stripe>
            <el-table-column prop="name" label="药品名称" />
            <el-table-column prop="specification" label="规格" />
            <el-table-column prop="dosage" label="常规用量" />
            <el-table-column prop="frequency" label="频率" />
            <el-table-column label="库存" width="160">
              <template #default="{ row }">
                <el-progress
                  :percentage="row.stock_total > 0 ? Math.round((row.stock_total - row.stock_used) / row.stock_total * 100) : 0"
                  :color="stockColor(row)"
                />
                <span style="font-size:12px;color:#999">
                  剩余 {{ row.stock_total - row.stock_used }} / {{ row.stock_total }}
                </span>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="160">
              <template #default="{ row }">
                <el-button link type="primary" size="small" @click="openMedDialog(row)">编辑</el-button>
                <el-button link type="danger" size="small" @click="deleteMed(row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-card>

        <el-card style="margin-top:20px">
          <template #header>
            <div style="display:flex;justify-content:space-between;align-items:center">
              <span>按次服药包</span>
              <el-button type="primary" size="small" @click="openDoseDialog()">
                <el-icon><Plus /></el-icon>新增一次
              </el-button>
            </div>
          </template>
          <el-table :data="dosePackages" stripe>
            <el-table-column prop="name" label="剂次名称" width="140" />
            <el-table-column prop="trigger_time" label="服药时间" width="100" />
            <el-table-column prop="package_index" label="药包编号" width="90" />
            <el-table-column label="本次药品">
              <template #default="{ row }">
                <div class="dose-items">
                  <el-tag
                    v-for="item in row.items || []"
                    :key="item.id || item.medication_id"
                    size="small"
                    type="info"
                  >
                    {{ item.medication?.name || medicationName(item.medication_id) }} {{ item.quantity }}{{ item.unit || '片' }}
                  </el-tag>
                </div>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="doseStatusType(row.status)" size="small">
                  {{ doseStatusText(row.status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="启用" width="70">
              <template #default="{ row }">
                <el-switch :model-value="row.enabled" size="small" disabled />
              </template>
            </el-table-column>
            <el-table-column label="操作" width="160">
              <template #default="{ row }">
                <el-button link type="primary" size="small" @click="openDoseDialog(row)">编辑</el-button>
                <el-button link type="danger" size="small" @click="deleteDose(row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <el-dialog v-model="medDialogVisible" :title="isMedEdit ? '编辑药品' : '新增药品'" width="500px">
      <el-form ref="medFormRef" :model="medForm" :rules="medRules" label-width="80px">
        <el-form-item label="药品名称" prop="name">
          <el-input v-model="medForm.name" />
        </el-form-item>
        <el-form-item label="规格">
          <el-input v-model="medForm.specification" placeholder="如：500mg/片" />
        </el-form-item>
        <el-form-item label="常规用量">
          <el-input v-model="medForm.dosage" placeholder="如：1片" />
        </el-form-item>
        <el-form-item label="频率">
          <el-input v-model="medForm.frequency" placeholder="如：每日3次" />
        </el-form-item>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="总库存">
              <el-input-number v-model="medForm.stock_total" :min="0" style="width:100%" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="已使用">
              <el-input-number v-model="medForm.stock_used" :min="0" style="width:100%" />
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="副作用">
          <el-input v-model="medForm.side_effects" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="medDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleMedSubmit">确定</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="doseDialogVisible" :title="isDoseEdit ? '编辑一次服药' : '新增一次服药'" width="720px">
      <el-form ref="doseFormRef" :model="doseForm" :rules="doseRules" label-width="90px">
        <el-row :gutter="16">
          <el-col :span="8">
            <el-form-item label="剂次名称" prop="name">
              <el-input v-model="doseForm.name" placeholder="如：早餐后" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="服药时间" prop="trigger_time">
              <el-time-picker v-model="doseForm.trigger_time" format="HH:mm" value-format="HH:mm" style="width:100%" />
            </el-form-item>
          </el-col>
          <el-col :span="8">
            <el-form-item label="药包编号">
              <el-input-number v-model="doseForm.package_index" :min="1" style="width:100%" />
            </el-form-item>
          </el-col>
        </el-row>

        <el-divider content-position="left">本次服药内容</el-divider>

        <div class="dose-item-editor">
          <div v-for="(item, index) in doseForm.items" :key="index" class="dose-item-row">
            <el-select v-model="item.medication_id" placeholder="选择药品" style="min-width:220px">
              <el-option
                v-for="m in patient.medications || []"
                :key="m.id"
                :label="m.name"
                :value="m.id"
              />
            </el-select>
            <el-input-number v-model="item.quantity" :min="1" :max="99" />
            <el-input v-model="item.unit" placeholder="单位" style="width:90px" />
            <el-button link type="danger" @click="removeDoseItem(index)" :disabled="doseForm.items.length === 1">
              删除
            </el-button>
          </div>
          <el-button plain type="primary" @click="addDoseItem">
            <el-icon><Plus /></el-icon>添加药品
          </el-button>
        </div>

        <el-form-item label="启用">
          <el-switch v-model="doseForm.enabled" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="doseForm.notes" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="doseDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleDoseSubmit">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import {
  getPatient, createMedication, updateMedication, deleteMedication,
  createDosePackage, updateDosePackage, deleteDosePackage,
} from '@/api/business'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const patient = ref({})

const medDialogVisible = ref(false)
const isMedEdit = ref(false)
const medEditId = ref(null)
const medFormRef = ref(null)
const defaultMedForm = { name: '', specification: '', dosage: '', frequency: '', stock_total: 0, stock_used: 0, side_effects: '' }
const medForm = reactive({ ...defaultMedForm })
const medRules = { name: [{ required: true, message: '请输入药品名称', trigger: 'blur' }] }

const doseDialogVisible = ref(false)
const isDoseEdit = ref(false)
const doseEditId = ref(null)
const doseFormRef = ref(null)
const defaultDoseItem = () => ({ medication_id: '', quantity: 1, unit: '片' })
const defaultDoseForm = () => ({
  name: '',
  trigger_time: '',
  package_index: 1,
  enabled: true,
  notes: '',
  items: [defaultDoseItem()],
})
const doseForm = reactive(defaultDoseForm())
const doseRules = {
  name: [{ required: true, message: '请输入剂次名称', trigger: 'blur' }],
  trigger_time: [{ required: true, message: '请选择时间', trigger: 'change' }],
}

const dosePackages = computed(() => patient.value.dose_packages || [])

const stockColor = (row) => {
  const remain = row.stock_total > 0 ? (row.stock_total - row.stock_used) / row.stock_total * 100 : 0
  if (remain > 50) return '#67c23a'
  if (remain > 20) return '#e6a23c'
  return '#f56c6c'
}

const doseStatusType = (s) => ({ taken: 'success', missed: 'danger', pending: 'info' }[s] || 'info')
const doseStatusText = (s) => ({ taken: '已出药', missed: '出药失败', pending: '待出药' }[s] || s)

const medicationName = (id) => {
  return (patient.value.medications || []).find(m => m.id === id)?.name || '未知药品'
}

const resetDoseForm = (source) => {
  const next = source || defaultDoseForm()
  Object.assign(doseForm, {
    name: next.name || '',
    trigger_time: next.trigger_time || '',
    package_index: next.package_index || 1,
    enabled: next.enabled ?? true,
    notes: next.notes || '',
    items: (next.items?.length ? next.items : [defaultDoseItem()]).map(item => ({
      medication_id: item.medication_id,
      quantity: item.quantity || 1,
      unit: item.unit || '片',
    })),
  })
}

const fetchPatient = async () => {
  loading.value = true
  try {
    patient.value = await getPatient(route.params.id)
  } finally {
    loading.value = false
  }
}

const openMedDialog = (row) => {
  isMedEdit.value = !!row
  medEditId.value = row?.id
  Object.assign(medForm, row || defaultMedForm)
  medDialogVisible.value = true
}

const handleMedSubmit = async () => {
  if (!medFormRef.value) return
  await medFormRef.value.validate(async (valid) => {
    if (!valid) return
    const data = { ...medForm, patient_id: Number(route.params.id) }
    if (isMedEdit.value) {
      await updateMedication(medEditId.value, data)
      ElMessage.success('更新成功')
    } else {
      await createMedication(data)
      ElMessage.success('创建成功')
    }
    medDialogVisible.value = false
    fetchPatient()
  })
}

const deleteMed = async (id) => {
  await deleteMedication(id)
  ElMessage.success('删除成功')
  fetchPatient()
}

const openDoseDialog = (row) => {
  isDoseEdit.value = !!row
  doseEditId.value = row?.id
  resetDoseForm(row)
  doseDialogVisible.value = true
}

const addDoseItem = () => {
  doseForm.items.push(defaultDoseItem())
}

const removeDoseItem = (index) => {
  doseForm.items.splice(index, 1)
}

const handleDoseSubmit = async () => {
  if (!doseFormRef.value) return
  await doseFormRef.value.validate(async (valid) => {
    if (!valid) return
    const items = doseForm.items
      .filter(item => item.medication_id)
      .map(item => ({
        medication_id: Number(item.medication_id),
        quantity: Number(item.quantity || 1),
        unit: item.unit || '片',
      }))
    if (items.length === 0) {
      ElMessage.warning('请至少选择一种药')
      return
    }
    const data = {
      patient_id: Number(route.params.id),
      name: doseForm.name,
      trigger_time: doseForm.trigger_time,
      package_index: Number(doseForm.package_index || 1),
      enabled: doseForm.enabled,
      notes: doseForm.notes,
      items,
    }
    if (isDoseEdit.value) {
      await updateDosePackage(doseEditId.value, data)
      ElMessage.success('更新成功')
    } else {
      await createDosePackage(data)
      ElMessage.success('创建成功')
    }
    doseDialogVisible.value = false
    fetchPatient()
  })
}

const deleteDose = async (id) => {
  await deleteDosePackage(id)
  ElMessage.success('删除成功')
  fetchPatient()
}

onMounted(fetchPatient)
</script>

<style scoped lang="scss">
.dose-items {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.dose-item-editor {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 16px;
}

.dose-item-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
</style>
