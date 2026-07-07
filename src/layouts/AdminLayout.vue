<script setup lang="ts">
import AdminBottomNav from '../components/admin/AdminBottomNav.vue'
</script>

<template>
  <div class="admin-layout">
    <main class="admin-layout__content">
      <RouterView />
    </main>

    <AdminBottomNav />
  </div>
</template>

<style scoped>
.admin-layout {
  display: flex;
  flex-direction: column;
  min-height: 100svh;
  background: linear-gradient(180deg, #ffffff 0%, #f8fafc 44%, #ffffff 100%);
  position: relative;
}

.admin-layout__content {
  flex: 1;
  padding: 32px 28px;
  padding-bottom: 120px; /* Leave space for bottom nav */
  overflow-y: auto;
}

@media (max-width: 768px) {
  .admin-layout__content {
    padding: 24px 16px;
    padding-bottom: 100px;
  }
}
</style>
