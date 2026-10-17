<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  Plus,
  Search,
  RefreshCw,
  ExternalLink,
  MessageSquare,
  Edit3,
  Trash2,
  CheckCircle2,
  Clock,
  Image as ImageIcon,
  Mic
} from 'lucide-vue-next'
import { supabase } from '../../lib/supabase'

interface BlogPost {
  id: string
  slug: string | null
  title: string
  excerpt: string | null
  content: string | null
  author: string | null
  tags: string[] | null
  published: boolean
  published_at: string | null
  updated_at: string | null
  created_at: string
  cover_image_url: string | null
  audio_url: string | null
}

const router = useRouter()
const posts = ref<BlogPost[]>([])
const loading = ref(true)
const deletingId = ref<string | null>(null)
const search = ref('')
const statusFilter = ref<'all' | 'published' | 'draft'>('all')

const publishedCount = computed(() => posts.value.filter((p) => p.published).length)
const draftCount = computed(() => posts.value.length - publishedCount.value)

const filteredPosts = computed(() => {
  let list = posts.value

  if (statusFilter.value === 'published') {
    list = list.filter((p) => p.published)
  } else if (statusFilter.value === 'draft') {
    list = list.filter((p) => !p.published)
  }

  const query = search.value.trim().toLowerCase()
  if (!query) return list

  return list.filter((post) => {
    return [
      post.title,
      post.content,
      post.excerpt,
      post.author,
      ...(post.tags ?? []),
    ].some((value) => value?.toLowerCase().includes(query))
  })
})

onMounted(fetchPosts)

async function fetchPosts() {
  loading.value = true
  const { data, error } = await supabase
    .from('blog_posts')
    .select('id, slug, title, excerpt, content, author, tags, published, published_at, updated_at, created_at, cover_image_url, audio_url')
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Error loading blog posts:', error)
    posts.value = []
  } else {
    posts.value = (data ?? []) as BlogPost[]
  }
  loading.value = false
}

async function togglePublished(post: BlogPost) {
  const nextPublished = !post.published
  const payload = {
    published: nextPublished,
    published_at: nextPublished ? post.published_at || new Date().toISOString() : post.published_at,
    updated_at: new Date().toISOString(),
  }
  const { error } = await supabase.from('blog_posts').update(payload).eq('id', post.id)
  if (error) {
    alert(`Unable to update post: ${error.message}`)
    return
  }
  post.published = nextPublished
  post.published_at = payload.published_at
  post.updated_at = payload.updated_at
}

async function deletePost(post: BlogPost) {
  const preview = post.title || post.content?.slice(0, 30) || 'this post'
  if (!confirm(`Delete "${preview}"? This cannot be undone.`)) return
  deletingId.value = post.id
  const { error } = await supabase.from('blog_posts').delete().eq('id', post.id)
  if (error) {
    alert(`Unable to delete post: ${error.message}`)
  } else {
    posts.value = posts.value.filter((item) => item.id !== post.id)
  }
  deletingId.value = null
}

function postPublicUrl(post: BlogPost) {
  const slugOrId = post.slug || post.id
  return `http://localhost:5173/blog/${slugOrId}`
}

function timeAgo(iso: string | null | undefined): string {
  if (!iso) return ''
  const date = new Date(iso)
  if (isNaN(date.getTime())) return ''
  const now = new Date()
  const diffSec = Math.floor((now.getTime() - date.getTime()) / 1000)

  if (diffSec < 60) return 'Just now'
  const diffMin = Math.floor(diffSec / 60)
  if (diffMin < 60) return `${diffMin}m ago`
  const diffHours = Math.floor(diffMin / 60)
  if (diffHours < 24) return `${diffHours}h ago`
  const diffDays = Math.floor(diffHours / 24)
  if (diffDays < 7) return `${diffDays}d ago`

  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
  })
}

function formatFullDate(iso: string | null) {
  if (!iso) return 'Not published'
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function plainTextPreview(text: string | null | undefined, maxLen = 180): string {
  if (!text) return ''
  const clean = text.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
  return clean.length > maxLen ? `${clean.slice(0, maxLen)}...` : clean
}
</script>

<template>
  <div class="blog-admin-page">
    <!-- Page Header -->
    <header class="page-header">
      <div>
        <span class="eyebrow">Feed &amp; Micro-Blog</span>
        <h1 class="page-title">Blog Posts</h1>
        <p class="page-sub">
          Manage quick social updates, thoughts, images, and voice notes for your feed.
        </p>
      </div>

      <button class="btn-create-post" type="button" @click="router.push('/admin/blog/new')">
        <Plus :size="18" />
        <span>Create Post</span>
      </button>
    </header>

    <!-- Quick Composer Banner (Social Media style) -->
    <section class="quick-composer-card" @click="router.push('/admin/blog/new')">
      <div class="composer-top">
        <img src="/portrait.png" alt="Olimjon" class="composer-avatar" />
        <div class="composer-fake-input">
          What's on your mind? Share an update, insight, or announcement...
        </div>
      </div>
      <div class="composer-actions">
        <div class="composer-media-hints">
          <span class="media-hint-btn">
            <ImageIcon :size="16" class="hint-icon image-hint" />
            <span>Photo / Media</span>
          </span>
          <span class="media-hint-btn">
            <Mic :size="16" class="hint-icon audio-hint" />
            <span>Voice Note</span>
          </span>
        </div>
        <button type="button" class="btn-quick-post">
          Post
        </button>
      </div>
    </section>

    <!-- Controls Toolbar (Search + Status Tabs) -->
    <section class="toolbar-card">
      <div class="status-tabs">
        <button
          type="button"
          class="tab-btn"
          :class="{ active: statusFilter === 'all' }"
          @click="statusFilter = 'all'"
        >
          All <span>{{ posts.length }}</span>
        </button>
        <button
          type="button"
          class="tab-btn"
          :class="{ active: statusFilter === 'published' }"
          @click="statusFilter = 'published'"
        >
          Published <span>{{ publishedCount }}</span>
        </button>
        <button
          type="button"
          class="tab-btn"
          :class="{ active: statusFilter === 'draft' }"
          @click="statusFilter = 'draft'"
        >
          Drafts <span>{{ draftCount }}</span>
        </button>
      </div>

      <div class="search-box">
        <Search :size="16" class="search-icon" />
        <input
          v-model="search"
          type="search"
          placeholder="Search post text, headline, tags..."
        />
        <button
          v-if="search"
          type="button"
          class="clear-search-btn"
          @click="search = ''"
        >
          ✕
        </button>
      </div>

      <button
        type="button"
        class="btn-refresh"
        title="Reload posts"
        @click="fetchPosts"
      >
        <RefreshCw :size="15" />
      </button>
    </section>

    <!-- Loading State -->
    <section v-if="loading" class="state-card loading-state">
      <div class="spinner"></div>
      <p>Loading posts...</p>
    </section>

    <!-- Empty State -->
    <section v-else-if="filteredPosts.length === 0" class="state-card empty-state">
      <div class="empty-icon-wrap">💬</div>
      <h2>No posts found</h2>
      <p v-if="search || statusFilter !== 'all'">
        No posts match your current search or filter criteria.
      </p>
      <p v-else>
        You haven't created any blog posts yet. Share your first update!
      </p>
      <button class="btn-create-post" type="button" @click="router.push('/admin/blog/new')">
        <Plus :size="17" />
        <span>Create your first post</span>
      </button>
    </section>

    <!-- Social Posts Stream List -->
    <section v-else class="posts-stream">
      <article
        v-for="post in filteredPosts"
        :key="post.id"
        class="admin-post-card"
        :class="{ deleting: deletingId === post.id }"
      >
        <!-- Post Header -->
        <header class="card-header">
          <div class="author-block">
            <img src="/portrait.png" alt="Olimjon" class="post-avatar" />
            <div class="author-details">
              <div class="name-line">
                <span class="author-name">{{ post.author || 'Olimjon Makhmudov' }}</span>
                <span class="handle">@mkhdov</span>
                <span class="dot">·</span>
                <time class="time-ago" :title="formatFullDate(post.published_at || post.created_at)">
                  {{ timeAgo(post.published_at || post.created_at) }}
                </time>
              </div>
              <span class="full-date">{{ formatFullDate(post.published_at || post.created_at) }}</span>
            </div>
          </div>

          <!-- Status Badge -->
          <div class="header-badges">
            <span
              class="status-pill"
              :class="post.published ? 'status-published' : 'status-draft'"
            >
              <component :is="post.published ? CheckCircle2 : Clock" :size="13" />
              {{ post.published ? 'Published' : 'Draft' }}
            </span>
          </div>
        </header>

        <!-- Post Content Preview -->
        <div class="card-content-preview">
          <h3 v-if="post.title && post.title !== 'Untitled'" class="post-preview-headline">
            {{ post.title }}
          </h3>
          <p class="post-preview-body">
            {{ plainTextPreview(post.content || post.excerpt) || 'No text content.' }}
          </p>
        </div>

        <!-- Media Attachment Thumbnails -->
        <div v-if="post.cover_image_url || post.audio_url" class="card-attachments-row">
          <div v-if="post.cover_image_url" class="attachment-chip image-chip">
            <img :src="post.cover_image_url" :alt="post.title" class="thumb-img" />
            <span>Image attached</span>
          </div>

          <div v-if="post.audio_url" class="attachment-chip audio-chip">
            <Mic :size="15" />
            <span>Audio note attached</span>
          </div>
        </div>

        <!-- Tags / Hashtags -->
        <div v-if="post.tags && post.tags.length" class="card-tags-row">
          <span v-for="tag in post.tags" :key="tag" class="tag-pill">
            #{{ tag }}
          </span>
        </div>

        <!-- Action Controls -->
        <footer class="card-actions">
          <div class="left-actions">
            <!-- Toggle Publish Status -->
            <button
              type="button"
              class="action-btn toggle-btn"
              :class="{ 'is-active': post.published }"
              @click="togglePublished(post)"
            >
              {{ post.published ? 'Unpublish' : 'Publish' }}
            </button>

            <!-- Edit Button -->
            <button
              type="button"
              class="action-btn"
              @click="router.push(`/admin/blog/${post.id}`)"
            >
              <Edit3 :size="15" />
              <span>Edit</span>
            </button>

            <!-- Comments Button -->
            <button
              type="button"
              class="action-btn"
              @click="router.push(`/admin/comments?type=blog&postId=${post.id}`)"
            >
              <MessageSquare :size="15" />
              <span>Comments</span>
            </button>
          </div>

          <div class="right-actions">
            <!-- Public Link -->
            <a
              class="action-btn public-link"
              :href="postPublicUrl(post)"
              target="_blank"
              rel="noopener noreferrer"
              title="Open post in portfolio"
            >
              <ExternalLink :size="15" />
              <span>View live</span>
            </a>

            <!-- Delete Button -->
            <button
              type="button"
              class="action-btn delete-btn"
              :disabled="deletingId === post.id"
              @click="deletePost(post)"
              title="Delete post"
            >
              <Trash2 :size="15" />
            </button>
          </div>
        </footer>
      </article>
    </section>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600;700&display=swap');

.blog-admin-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  font-family: 'Inter', system-ui, sans-serif;
  max-width: 860px;
  margin: 0 auto;
}

/* ── Page Header ────────────────────────────────────────── */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.eyebrow {
  color: #6c63ff;
  font-size: 0.76rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.page-title {
  margin: 4px 0 6px;
  font-family: 'Space Grotesk', sans-serif;
  font-size: 2rem;
  font-weight: 700;
  color: #0f172a;
}

.page-sub {
  margin: 0;
  color: #64748b;
  font-size: 0.95rem;
}

.btn-create-post {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #6c63ff;
  color: #ffffff;
  border: none;
  border-radius: 10px;
  padding: 10px 18px;
  font-size: 0.92rem;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(108, 99, 255, 0.28);
  transition: all 0.2s ease;
}

.btn-create-post:hover {
  background: #5a52d5;
  transform: translateY(-1px);
}

/* ── Quick Composer Banner ──────────────────────────────── */
.quick-composer-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 18px 20px;
  box-shadow: 0 2px 10px rgba(15, 23, 42, 0.04);
  cursor: pointer;
  transition: all 0.2s ease;
}

.quick-composer-card:hover {
  border-color: #6c63ff;
  box-shadow: 0 4px 18px rgba(108, 99, 255, 0.08);
}

.composer-top {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
}

.composer-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  object-fit: cover;
  border: 2px solid #6c63ff;
}

.composer-fake-input {
  flex: 1;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  padding: 11px 18px;
  color: #94a3b8;
  font-size: 0.92rem;
}

.composer-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #f1f5f9;
  padding-top: 12px;
}

.composer-media-hints {
  display: flex;
  gap: 16px;
}

.media-hint-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
  font-size: 0.85rem;
  font-weight: 600;
}

.hint-icon.image-hint {
  color: #10b981;
}

.hint-icon.audio-hint {
  color: #6c63ff;
}

.btn-quick-post {
  background: rgba(108, 99, 255, 0.1);
  color: #6c63ff;
  border: 1px solid rgba(108, 99, 255, 0.2);
  border-radius: 8px;
  padding: 6px 16px;
  font-size: 0.88rem;
  font-weight: 700;
  cursor: pointer;
}

/* ── Toolbar Card ───────────────────────────────────────── */
.toolbar-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 10px 14px;
  flex-wrap: wrap;
}

.status-tabs {
  display: flex;
  gap: 6px;
  background: #f8fafc;
  padding: 4px;
  border-radius: 10px;
}

.tab-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border: none;
  background: transparent;
  padding: 6px 12px;
  border-radius: 8px;
  font-size: 0.84rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s ease;
}

.tab-btn span {
  background: #e2e8f0;
  color: #475569;
  padding: 2px 6px;
  border-radius: 999px;
  font-size: 0.74rem;
  font-weight: 700;
}

.tab-btn.active {
  background: #ffffff;
  color: #0f172a;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

.tab-btn.active span {
  background: rgba(108, 99, 255, 0.15);
  color: #6c63ff;
}

.search-box {
  flex: 1;
  min-width: 200px;
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 12px;
  color: #94a3b8;
  pointer-events: none;
}

.search-box input {
  width: 100%;
  padding: 8px 32px 8px 36px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.88rem;
  outline: none;
  background: #f8fafc;
}

.search-box input:focus {
  background: #ffffff;
  border-color: #6c63ff;
}

.clear-search-btn {
  position: absolute;
  right: 10px;
  border: none;
  background: transparent;
  color: #94a3b8;
  cursor: pointer;
}

.btn-refresh {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border: 1px solid #e2e8f0;
  background: #ffffff;
  border-radius: 8px;
  color: #64748b;
  cursor: pointer;
}

.btn-refresh:hover {
  color: #6c63ff;
  border-color: #6c63ff;
}

/* ── Posts Stream ───────────────────────────────────────── */
.posts-stream {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* ── Admin Post Card ────────────────────────────────────── */
.admin-post-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 18px 20px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.03);
  transition: all 0.2s ease;
}

.admin-post-card:hover {
  border-color: rgba(108, 99, 255, 0.28);
  box-shadow: 0 4px 14px rgba(108, 99, 255, 0.05);
}

.admin-post-card.deleting {
  opacity: 0.4;
  pointer-events: none;
}

/* Card Header */
.card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 12px;
}

.author-block {
  display: flex;
  align-items: center;
  gap: 10px;
}

.post-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  object-fit: cover;
  border: 1.5px solid #e2e8f0;
}

.author-details {
  display: flex;
  flex-direction: column;
}

.name-line {
  display: flex;
  align-items: center;
  gap: 6px;
}

.author-name {
  font-size: 0.92rem;
  font-weight: 700;
  color: #0f172a;
}

.handle {
  font-size: 0.82rem;
  color: #64748b;
}

.dot {
  color: #cbd5e1;
  font-size: 0.75rem;
}

.time-ago {
  font-size: 0.82rem;
  color: #64748b;
}

.full-date {
  font-size: 0.74rem;
  color: #94a3b8;
}

/* Badges */
.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 0.78rem;
  font-weight: 700;
}

.status-published {
  background: #ecfdf5;
  color: #059669;
  border: 1px solid rgba(16, 185, 129, 0.25);
}

.status-draft {
  background: #fffbeb;
  color: #d97706;
  border: 1px solid rgba(245, 158, 11, 0.25);
}

/* Card Content Preview */
.card-content-preview {
  margin-bottom: 12px;
}

.post-preview-headline {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.05rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 6px;
}

.post-preview-body {
  font-size: 0.92rem;
  color: #334155;
  line-height: 1.55;
  margin: 0;
  white-space: pre-line;
}

/* Attachments */
.card-attachments-row {
  display: flex;
  gap: 10px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.attachment-chip {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 4px 10px;
  font-size: 0.8rem;
  font-weight: 600;
  color: #475569;
}

.thumb-img {
  width: 24px;
  height: 24px;
  border-radius: 4px;
  object-fit: cover;
}

.audio-chip {
  color: #6c63ff;
  border-color: rgba(108, 99, 255, 0.2);
}

/* Tags */
.card-tags-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 14px;
}

.tag-pill {
  background: rgba(108, 99, 255, 0.06);
  border: 1px solid rgba(108, 99, 255, 0.14);
  color: #6c63ff;
  border-radius: 6px;
  padding: 2px 8px;
  font-size: 0.78rem;
  font-weight: 600;
}

/* Card Actions */
.card-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #f1f5f9;
  padding-top: 12px;
  gap: 10px;
  flex-wrap: wrap;
}

.left-actions,
.right-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.action-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #ffffff;
  color: #475569;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  transition: all 0.15s ease;
}

.action-btn:hover {
  background: #f8fafc;
  color: #6c63ff;
  border-color: #6c63ff;
}

.toggle-btn {
  color: #64748b;
}

.toggle-btn.is-active {
  background: #fef2f2;
  color: #dc2626;
  border-color: #fecaca;
}

.public-link {
  color: #0284c7;
}

.delete-btn {
  color: #ef4444;
  padding: 6px 10px;
}

.delete-btn:hover {
  background: #fee2e2;
  border-color: #f87171;
  color: #dc2626;
}

/* ── States ─────────────────────────────────────────────── */
.state-card {
  text-align: center;
  background: #ffffff;
  border: 1px dashed #cbd5e1;
  border-radius: 16px;
  padding: 48px 20px;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #e2e8f0;
  border-top-color: #6c63ff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin: 0 auto 12px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.empty-icon-wrap {
  font-size: 2.2rem;
  margin-bottom: 10px;
}

.empty-state h2 {
  font-size: 1.2rem;
  color: #0f172a;
  margin-bottom: 6px;
}

.empty-state p {
  color: #64748b;
  font-size: 0.92rem;
  margin-bottom: 16px;
}
</style>
