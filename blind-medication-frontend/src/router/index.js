import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/Login.vue'),
    meta: { title: '登录', noAuth: true },
  },
  {
    path: '/',
    component: () => import('@/views/Layout.vue'),
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/dashboard/Index.vue'),
        meta: { title: '仪表盘', icon: 'Odometer' },
      },
      {
        path: 'patients',
        name: 'Patients',
        component: () => import('@/views/patient/Index.vue'),
        meta: { title: '患者管理', icon: 'User' },
      },
      {
        path: 'patients/:id',
        name: 'PatientDetail',
        component: () => import('@/views/patient/Detail.vue'),
        meta: { title: '患者详情', hidden: true },
      },
      {
        path: 'medications',
        name: 'Medications',
        component: () => import('@/views/medication/Index.vue'),
        meta: { title: '药品管理', icon: 'FirstAidKit' },
      },
      {
        path: 'devices',
        name: 'Devices',
        component: () => import('@/views/device/Index.vue'),
        meta: { title: '设备管理', icon: 'Monitor' },
      },
      {
        path: 'event-logs',
        name: 'EventLogs',
        component: () => import('@/views/event-log/Index.vue'),
        meta: { title: '事件日志', icon: 'Bell' },
      },
      {
        path: 'nursing',
        name: 'Nursing',
        component: () => import('@/views/nursing/Index.vue'),
        meta: { title: '护理记录', icon: 'Notebook' },
      },
      {
        path: 'simulator',
        name: 'Simulator',
        component: () => import('@/views/simulator/Index.vue'),
        meta: { title: '设备模拟器', icon: 'Cpu' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 路由守卫
router.beforeEach((to, from, next) => {
  document.title = `${to.meta.title || ''} - 盲人智能用药管理系统`
  const token = localStorage.getItem('token')
  if (!to.meta.noAuth && !token) {
    next('/login')
  } else if (to.path === '/login' && token) {
    next('/dashboard')
  } else {
    next()
  }
})

export default router
