<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase'
import {
  LayoutDashboard,
  FileText,
  BookOpen,
  Inbox,
  MessageSquare,
  Briefcase,
  Code,
  FolderOpen,
  User,
  Image as ImageIcon,
  Settings,
  LogOut
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const unreadInboxCount = ref(0)
let inboxSubscription: ReturnType<typeof supabase.channel> | null = null

const navItems = [
  { label: 'Dashboard', to: '/admin/dashboard', icon: LayoutDashboard },
  { label: 'Articles', to: '/admin/articles', icon: FileText },
  { label: 'Blog', to: '/admin/blog', icon: BookOpen },
  { label: 'Inbox', to: '/admin/inbox', icon: Inbox },
  { label: 'Comments', to: '/admin/comments', icon: MessageSquare },
  { label: 'Projects', to: '/admin/projects', icon: Briefcase },
  { label: 'Skills', to: '/admin/skills', icon: Code },
  { label: 'Portfolio', to: '/admin/portfolio', icon: FolderOpen },
  { label: 'About', to: '/admin/about', icon: User },
  { label: 'Media', to: '/admin/media', icon: ImageIcon },
  { label: 'Settings', to: '/admin/settings', icon: Settings },
]

const activePath = computed(() => route.path)
const isActive = (path: string) => activePath.value === path
const hasUnreadInbox = computed(() => unreadInboxCount.value > 0)

async function loadUnreadInboxCount() {
  const { count, error } = await supabase
    .from('conversations')
    .select('*', { count: 'exact', head: true })
    .gt('unread_count_admin', 0)

  if (error) {
    console.error('Error loading unread inbox count:', error)
    return
  }

  unreadInboxCount.value = count ?? 0
}

function subscribeToInboxUnread() {
  inboxSubscription = supabase
    .channel('admin_nav_inbox_unread')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'conversations',
      },
      () => {
        void loadUnreadInboxCount()
      }
    )
    .subscribe()
}

const signOut = async () => {
  await supabase.auth.signOut()
  await router.push('/admin/login')
}

onMounted(() => {
  void loadUnreadInboxCount()
  subscribeToInboxUnread()
})

onUnmounted(() => {
  if (inboxSubscription) {
    supabase.removeChannel(inboxSubscription)
  }
})
</script>

<template>
  <nav class="bottom-nav">
    <div class="bottom-nav__container">
      <ul class="bottom-nav__list">
        <li v-for="item in navItems" :key="item.to" class="bottom-nav__item">
          <RouterLink
            :to="item.to"
            class="bottom-nav__link"
            :class="{ 'bottom-nav__link--active': isActive(item.to) }"
            :title="item.label"
          >
            <component :is="item.icon" class="bottom-nav__icon" />
            <span
              v-if="item.to === '/admin/inbox' && hasUnreadInbox"
              class="bottom-nav__unread-dot"
              aria-label="Unread inbox messages"
            />
            <span class="bottom-nav__label">{{ item.label }}</span>
          </RouterLink>
        </li>

        <!-- Divider -->
        <li class="bottom-nav__divider" role="separator"></li>

        <li class="bottom-nav__item">
          <button class="bottom-nav__link bottom-nav__link--danger" @click="signOut" title="Sign Out">
            <LogOut class="bottom-nav__icon" />
            <span class="bottom-nav__label">Logout</span>
          </button>
        </li>
      </ul>
    </div>
  </nav>
</template>

<style scoped>
.bottom-nav {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
  width: calc(100% - 48px);
  max-width: 900px;
  pointer-events: none; /* Let clicks pass through the invisible full-width wrapper */
}

.bottom-nav__container {
  pointer-events: auto; /* Re-enable clicks for the actual nav container */
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 1px solid rgba(108, 99, 255, 0.15);
  border-radius: 24px;
  box-shadow: 0 8px 32px rgba(15, 23, 42, 0.08);
  padding: 8px;
  overflow: hidden; /* For inner border-radius */
}

.bottom-nav__list {
  display: flex;
  align-items: center;
  gap: 4px;
  margin: 0;
  padding: 0;
  list-style: none;
  overflow-x: auto;
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none;  /* Internet Explorer 10+ */
}

.bottom-nav__list::-webkit-scrollbar {
  display: none; /* WebKit */
}

.bottom-nav__item {
  flex-shrink: 0;
}

.bottom-nav__link {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 8px 16px;
  border-radius: 16px;
  color: #64748b;
  text-decoration: none;
  border: none;
  background: transparent;
  cursor: pointer;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  min-width: 64px;
}

.bottom-nav__link:hover {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.06);
}

.bottom-nav__link--active {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.1);
  box-shadow: inset 0 0 0 1px rgba(108, 99, 255, 0.14);
}

.bottom-nav__link--danger:hover {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.06);
}

.bottom-nav__icon {
  width: 22px;
  height: 22px;
  stroke-width: 2;
}

.bottom-nav__unread-dot {
  position: absolute;
  top: 7px;
  right: 13px;
  width: 10px;
  height: 10px;
  border: 2px solid rgba(255, 255, 255, 0.95);
  border-radius: 50%;
  background: #ef4444;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.14);
}

.bottom-nav__label {
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
}

.bottom-nav__divider {
  width: 1px;
  height: 32px;
  background: rgba(108, 99, 255, 0.15);
  margin: 0 4px;
  flex-shrink: 0;
}

/* For smaller screens, reduce padding to fit more items easily */
@media (max-width: 768px) {
  .bottom-nav {
    width: calc(100% - 32px);
    bottom: 16px;
  }
  
  .bottom-nav__container {
    padding: 6px;
    border-radius: 20px;
  }

  .bottom-nav__link {
    padding: 8px 12px;
    min-width: 56px;
  }
  
  .bottom-nav__icon {
    width: 20px;
    height: 20px;
  }
  
  .bottom-nav__label {
    font-size: 0.65rem;
  }
}
</style>
