import { onBeforeUnmount, ref } from 'vue'

const STORAGE_KEY = 'admin-sidebar-width'
const MIN_WIDTH = 200
const MAX_WIDTH = 360
const DEFAULT_WIDTH = 260

export function useResizableSidebar() {
  const sidebarWidth = ref(DEFAULT_WIDTH)
  const isResizing = ref(false)

  const savedWidth = localStorage.getItem(STORAGE_KEY)
  if (savedWidth) {
    const parsed = Number(savedWidth)
    if (!Number.isNaN(parsed)) {
      sidebarWidth.value = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, parsed))
    }
  }

  const clampWidth = (width: number) => Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, width))

  const onResizeMove = (event: MouseEvent) => {
    sidebarWidth.value = clampWidth(event.clientX)
  }

  const stopResize = () => {
    if (!isResizing.value) return

    isResizing.value = false
    document.body.style.cursor = ''
    document.body.style.userSelect = ''
    localStorage.setItem(STORAGE_KEY, String(sidebarWidth.value))
    window.removeEventListener('mousemove', onResizeMove)
    window.removeEventListener('mouseup', stopResize)
  }

  const startResize = (event: MouseEvent) => {
    event.preventDefault()
    isResizing.value = true
    document.body.style.cursor = 'col-resize'
    document.body.style.userSelect = 'none'
    window.addEventListener('mousemove', onResizeMove)
    window.addEventListener('mouseup', stopResize)
  }

  onBeforeUnmount(stopResize)

  return {
    sidebarWidth,
    isResizing,
    startResize,
    stopResize,
  }
}
