<script setup lang="ts">
import AdminSidebar from '../components/admin/AdminSidebar.vue'
import { useResizableSidebar } from '../composables/useResizableSidebar'

const { sidebarWidth, isResizing, startResize } = useResizableSidebar()
</script>

<template>
  <div class="admin-layout" :class="{ 'admin-layout--resizing': isResizing }">
    <AdminSidebar :width="sidebarWidth" @start-resize="startResize" />

    <main class="admin-layout__content">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.admin-layout {
  display: flex;
  min-height: 100svh;
  background: linear-gradient(180deg, #ffffff 0%, #f8fafc 44%, #ffffff 100%);
}

.admin-layout--resizing {
  cursor: col-resize;
  user-select: none;
}

.admin-layout__content {
  flex: 1;
  min-width: 0;
  padding: 32px 28px;
  overflow-y: auto;
}

@media (max-width: 768px) {
  .admin-layout {
    flex-direction: column;
  }

  .admin-layout__content {
    padding: 24px 16px;
  }
}
</style>
