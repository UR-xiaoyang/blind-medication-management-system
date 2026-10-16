<template>
  <div class="page-container">
    <div class="page-header">
      <h2>💊 药品管理</h2>
    </div>

    <el-card>
      <el-row style="margin-bottom:16px">
        <el-col :span="8">
          <el-select v-model="searchPatientId" placeholder="按患者筛选" clearable @change="fetchData" style="width:100%">
            <el-option v-for="p in patients" :key="p.id" :label="p.name" :value="p.id" />
          </el-select>
        </el-col>
      </el-row>

      <el-table :data="tableData" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="药品名称" />
        <el-table-column prop="specification" label="规格" />
        <el-table-column prop="dosage" label="用量" width="100" />
        <el-table-column prop="frequency" label="频率" width="120" />
        <el-table-column label="库存" width="200">
          <template #default="{ row }">
            <div style="display:flex;align-items:center;gap:8px">
              <el-progress
                :percentage="row.stock_total > 0 ? Math.round((row.stock_total - row.stock_used) / row.stock_total * 100) : 0"
                :stroke-width="8"
                :color="stockColor(row)"
                style="flex:1"
              />
              <span style="font-size:12px;white-space:nowrap">
                {{ row.stock_total - row.stock_used }}/{{ row.stock_total }}
              </span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="side_effects" label="副作用" show-overflow-tooltip />
        <el-table-column prop="created_at" label="创建时间" width="170">
          <template #default="{ row }">{{ formatDate(row.created_at) }}</template>
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
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import dayjs from 'dayjs'
import { getMedications, getPatients } from '@/api/business'

const loading = ref(false)
const tableData = ref([])
const patients = ref([])
const searchPatientId = ref('')
const pagination = ref({ page: 1, pageSize: 10, total: 0 })

const formatDate = (d) => d ? dayjs(d).format('YYYY-MM-DD HH:mm') : '-'

const stockColor = (row) => {
  const remain = row.stock_total > 0 ? (row.stock_total - row.stock_used) / row.stock_total * 100 : 0
  if (remain > 50) return '#67c23a'
  if (remain > 20) return '#e6a23c'
  return '#f56c6c'
}

const fetchData = async () => {
  loading.value = true
  try {
    const params = {
      page: pagination.value.page,
      page_size: pagination.value.pageSize,
    }
    if (searchPatientId.value) params.patient_id = searchPatientId.value
    const res = await getMedications(params)
    tableData.value = res.data || []
    pagination.value.total = res.total || 0
  } finally {
    loading.value = false
  }
}

const fetchPatients = async () => {
  const res = await getPatients({ page_size: 100 })
  patients.value = res.data || []
}

onMounted(() => {
  fetchData()
  fetchPatients()
})
</script>
