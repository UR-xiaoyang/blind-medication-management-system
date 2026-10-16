import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as loginApi, getProfile } from '@/api/business'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const admin = ref(JSON.parse(localStorage.getItem('admin') || 'null'))

  const isLoggedIn = computed(() => !!token.value)

  async function login(username, password) {
    const res = await loginApi({ username, password })
    token.value = res.token
    admin.value = res.admin
    localStorage.setItem('token', res.token)
    localStorage.setItem('admin', JSON.stringify(res.admin))
    return res
  }

  function logout() {
    token.value = ''
    admin.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('admin')
  }

  return { token, admin, isLoggedIn, login, logout }
})
