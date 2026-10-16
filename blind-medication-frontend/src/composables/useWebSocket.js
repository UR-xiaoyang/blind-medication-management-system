import { ref, onUnmounted } from 'vue'

/**
 * Vue 3 composable: 与后端 WebSocket Hub 的双向实时通信。
 *
 * 用法：
 *   const { connected, on, send } = useWebSocket()
 *   on('dispense_command', (data) => { ... })
 *   send('register', { role: 'simulator', device_id: '...' })
 */
export function useWebSocket() {
  const connected = ref(false)
  let ws = null
  let reconnectTimer = null
  const listeners = {}
  const pendingSends = []

  const connect = () => {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const url = `${proto}://${location.host}/api/ws`
    ws = new WebSocket(url)

    ws.onopen = () => {
      connected.value = true
      if (reconnectTimer) {
        clearTimeout(reconnectTimer)
        reconnectTimer = null
      }
      // flush 暂存的消息
      while (pendingSends.length > 0) {
        const msg = pendingSends.shift()
        ws.send(msg)
      }
    }

    ws.onmessage = (evt) => {
      let msg
      try {
        msg = JSON.parse(evt.data)
      } catch {
        return
      }
      const type = msg.type
      if (type && listeners[type]) {
        listeners[type].forEach(fn => fn(msg))
      }
    }

    ws.onclose = () => {
      connected.value = false
      scheduleReconnect()
    }

    ws.onerror = () => {
      ws?.close()
    }
  }

  const scheduleReconnect = () => {
    if (reconnectTimer) return
    reconnectTimer = setTimeout(() => {
      reconnectTimer = null
      connect()
    }, 2000)
  }

  /**
   * 监听某一类型消息。
   * @param {string} type
   * @param {(msg: object) => void} callback
   */
  const on = (type, callback) => {
    if (!listeners[type]) listeners[type] = []
    listeners[type].push(callback)
  }

  /**
   * 发送消息。
   * @param {string} type
   * @param {object} data  — 放入 data 字段
   */
  const send = (type, data = {}) => {
    const payload = JSON.stringify({ type, ...data })
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(payload)
    } else {
      // 连接尚未就绪，先暂存
      pendingSends.push(payload)
    }
  }

  connect()

  onUnmounted(() => {
    if (reconnectTimer) clearTimeout(reconnectTimer)
    ws?.close()
  })

  return { connected, on, send }
}
