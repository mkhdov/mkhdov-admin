<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase'

defineProps<{
  width: number
}>()

const emit = defineEmits<{
  startResize: [event: MouseEvent]
}>()

const route = useRoute()
const router = useRouter()

const primaryNav = [
  { label: 'Dashboard', to: '/admin/dashboard' },
  { label: 'Articles', to: '/admin/articles' },
  { label: 'Blog', to: '/admin/blog' },
  { label: 'Inbox', to: '/admin/inbox' },
  { label: 'Projects', to: '/admin/projects' },
]

const secondaryNav = [
  { label: 'Skills', to: '/admin/skills' },
  { label: 'Portfolio', to: '/admin/portfolio' },
  { label: 'About', to: '/admin/about' },
  { label: 'Media', to: '/admin/media' },
  { label: 'Settings', to: '/admin/settings' },
]

const activePath = computed(() => route.path)

const isActive = (path: string) => activePath.value === path

const signOut = async () => {
  await supabase.auth.signOut()
  await router.push('/admin/login')
}
</script>

<template>
  <aside class="sidebar" :style="{ width: `${width}px` }">
    <div class="sidebar__inner">
      <header class="sidebar__brand">
        <span class="sidebar__brand-mark">PA</span>
        <div>
          <p class="sidebar__brand-title">Portfolio Admin</p>
          <p class="sidebar__brand-subtitle">Content manager</p>
        </div>
      </header>

      <nav class="sidebar__nav" aria-label="Admin navigation">
        <section class="sidebar__section">
          <p class="sidebar__section-label">Primary</p>
          <ul class="sidebar__list">
            <li v-for="item in primaryNav" :key="item.to">
              <RouterLink
                :to="item.to"
                class="sidebar__link"
                :class="{ 'sidebar__link--active': isActive(item.to) }"
              >
                {{ item.label }}
              </RouterLink>
            </li>
          </ul>
        </section>

        <div class="sidebar__divider" role="separator" />

        <section class="sidebar__section">
          <p class="sidebar__section-label">Manage</p>
          <ul class="sidebar__list">
            <li v-for="item in secondaryNav" :key="item.to">
              <RouterLink
                :to="item.to"
                class="sidebar__link"
                :class="{ 'sidebar__link--active': isActive(item.to) }"
              >
                {{ item.label }}
              </RouterLink>
            </li>
          </ul>
        </section>
      </nav>

      <footer class="sidebar__footer">
        <button class="sidebar__sign-out" type="button" @click="signOut">
          Sign out
        </button>
      </footer>
    </div>

    <div
      class="sidebar__resize-handle"
      role="separator"
      aria-orientation="vertical"
      aria-label="Resize sidebar"
      @mousedown="emit('startResize', $event)"
    />
  </aside>
</template>

<style scoped>
.sidebar {
  position: relative;
  flex-shrink: 0;
  height: 100svh;
  background: #ffffff;
  border-right: 1px solid rgba(108, 99, 255, 0.12);
  box-shadow: 4px 0 24px rgba(15, 23, 42, 0.04);
}

.sidebar__inner {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 20px 14px 16px;
  overflow: hidden;
}

.sidebar__brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 8px 18px;
}

.sidebar__brand-mark {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 12px;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 0.8125rem;
  font-weight: 700;
  color: #ffffff;
  background: linear-gradient(135deg, #6c63ff 0%, #818cf8 100%);
  box-shadow: 0 4px 16px rgba(108, 99, 255, 0.28);
}

.sidebar__brand-title {
  margin: 0;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 0.95rem;
  font-weight: 600;
  color: #1a1a2e;
  line-height: 1.2;
}

.sidebar__brand-subtitle {
  margin: 2px 0 0;
  font-size: 0.75rem;
  color: #94a3b8;
}

.sidebar__nav {
  flex: 1;
  overflow-y: auto;
  padding-right: 2px;
}

.sidebar__section-label {
  margin: 0 0 8px;
  padding: 0 10px;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #94a3b8;
}

.sidebar__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 4px;
}

.sidebar__link {
  display: block;
  padding: 10px 12px;
  border-radius: 10px;
  text-decoration: none;
  font-size: 0.9375rem;
  font-weight: 500;
  color: #64748b;
  transition: background 0.18s ease, color 0.18s ease;
}

.sidebar__link:hover {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.06);
}

.sidebar__link--active {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.1);
  box-shadow: inset 0 0 0 1px rgba(108, 99, 255, 0.14);
}

.sidebar__divider {
  height: 1px;
  margin: 16px 10px;
  background: rgba(108, 99, 255, 0.14);
}

.sidebar__footer {
  padding-top: 12px;
  border-top: 1px solid rgba(108, 99, 255, 0.1);
}

.sidebar__sign-out {
  width: 100%;
  border: 1px solid rgba(108, 99, 255, 0.22);
  background: rgba(108, 99, 255, 0.06);
  color: #6c63ff;
  border-radius: 10px;
  padding: 10px 12px;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.18s ease;
}

.sidebar__sign-out:hover {
  background: rgba(108, 99, 255, 0.1);
}

.sidebar__resize-handle {
  position: absolute;
  top: 0;
  right: -4px;
  width: 8px;
  height: 100%;
  cursor: col-resize;
  z-index: 2;
}

.sidebar__resize-handle::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 2px;
  height: 36px;
  border-radius: 999px;
  background: rgba(108, 99, 255, 0.22);
  opacity: 0;
  transition: opacity 0.18s ease;
}

.sidebar:hover .sidebar__resize-handle::after,
.sidebar__resize-handle:hover::after {
  opacity: 1;
}
</style>
