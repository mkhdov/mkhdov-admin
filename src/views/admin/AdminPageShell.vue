<script setup lang="ts">
defineProps<{
  title: string
}>()
</script>

<template>
  <section class="admin-page">
    <h1>{{ title }}</h1>
    <slot />
  </section>
</template>

<style scoped>
.admin-page {
  min-height: 100%;
}

.admin-page h1 {
  margin: 0;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 2rem;
  line-height: 1.15;
  letter-spacing: -0.03em;
  color: #1a1a2e;
}
</style>
