<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase'

interface BlogPost {
  id: string
  slug: string | null
  title: string
  excerpt: string | null
  author: string | null
  tags: string[] | null
  published: boolean
  published_at: string | null
  updated_at: string | null
  created_at: string
  cover_image_url: string | null
}

const router = useRouter()
const posts = ref<BlogPost[]>([])
const loading = ref(true)
const deletingId = ref<string | null>(null)
const search = ref('')

const filteredPosts = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return posts.value
  return posts.value.filter((post) => {
    return [
      post.title,
      post.excerpt,
      post.author,
      ...(post.tags ?? []),
    ].some((value) => value?.toLowerCase().includes(query))
  })
})

const publishedCount = computed(() => posts.value.filter((post) => post.published).length)
const draftCount = computed(() => posts.value.length - publishedCount.value)

onMounted(fetchPosts)

async function fetchPosts() {
  loading.value = true
  const { data, error } = await supabase
    .from('blog_posts')
    .select('id, slug, title, excerpt, author, tags, published, published_at, updated_at, created_at, cover_image_url')
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
  if (!confirm(`Delete "${post.title}"? This cannot be undone.`)) return
  deletingId.value = post.id
  const { error } = await supabase.from('blog_posts').delete().eq('id', post.id)
  if (error) {
    alert(`Unable to delete post: ${error.message}`)
  } else {
    posts.value = posts.value.filter((item) => item.id !== post.id)
  }
  deletingId.value = null
}

function postUrl(post: BlogPost) {
  return `/blog/${post.slug || post.id}`
}

function formatDate(iso: string | null) {
  if (!iso) return 'Not published'
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}
</script>

<template>
  <div class="blog-admin-page">
    <header class="page-header">
      <div>
        <span class="eyebrow">Blog system</span>
        <h1>Blog posts</h1>
        <p>{{ posts.length }} total, {{ publishedCount }} published, {{ draftCount }} draft</p>
      </div>
      <button class="btn-primary" type="button" @click="router.push('/admin/blog/new')">
        New post
      </button>
    </header>

    <section class="toolbar">
      <input v-model="search" type="search" placeholder="Search title, tag, author..." />
      <button type="button" @click="fetchPosts">Refresh</button>
    </section>

    <section v-if="loading" class="state">
      <div class="spinner"></div>
      <p>Loading blog posts...</p>
    </section>

    <section v-else-if="posts.length === 0" class="state empty">
      <div class="empty-mark">B</div>
      <h2>No blog posts yet</h2>
      <p>Create the first post with the Notion-style editor.</p>
      <button class="btn-primary" type="button" @click="router.push('/admin/blog/new')">Create post</button>
    </section>

    <section v-else class="post-list">
      <article
        v-for="post in filteredPosts"
        :key="post.id"
        class="post-row"
        :class="{ deleting: deletingId === post.id }"
      >
        <div class="cover">
          <img v-if="post.cover_image_url" :src="post.cover_image_url" :alt="post.title" />
          <span v-else>{{ post.title.slice(0, 1) }}</span>
        </div>

        <div class="post-main">
          <div class="title-row">
            <h2>{{ post.title }}</h2>
            <span class="status" :class="{ published: post.published }">
              {{ post.published ? 'Published' : 'Draft' }}
            </span>
          </div>
          <p>{{ post.excerpt || 'No excerpt yet.' }}</p>
          <div class="meta">
            <span>{{ post.author || 'Olimjon Makhmudov' }}</span>
            <span>{{ formatDate(post.published_at || post.created_at) }}</span>
            <span v-for="tag in post.tags?.slice(0, 4)" :key="tag" class="tag">{{ tag }}</span>
          </div>
        </div>

        <div class="actions">
          <a class="icon-btn" :href="postUrl(post)" target="_blank" rel="noopener noreferrer" title="Preview">View</a>
          <button class="icon-btn" type="button" @click="router.push(`/admin/blog/${post.id}`)">Edit</button>
          <button class="icon-btn" type="button" @click="togglePublished(post)">
            {{ post.published ? 'Unpublish' : 'Publish' }}
          </button>
          <button class="icon-btn danger" type="button" :disabled="deletingId === post.id" @click="deletePost(post)">
            Delete
          </button>
        </div>
      </article>
    </section>
  </div>
</template>

<style scoped>
.blog-admin-page {
  display: grid;
  gap: 22px;
  font-family: 'Inter', system-ui, sans-serif;
}

.page-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: flex-start;
}

.eyebrow {
  color: #6c63ff;
  font-size: 0.75rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.page-header h1 {
  margin: 4px 0 6px;
  color: #0f172a;
  font-size: clamp(1.8rem, 4vw, 2.6rem);
  line-height: 1;
}

.page-header p {
  margin: 0;
  color: #64748b;
}

.btn-primary,
.toolbar button,
.icon-btn {
  border: 1px solid rgba(108, 99, 255, 0.22);
  border-radius: 8px;
  font: inherit;
  font-weight: 700;
  cursor: pointer;
}

.btn-primary {
  color: #ffffff;
  background: #6c63ff;
  padding: 12px 18px;
}

.toolbar {
  display: flex;
  gap: 10px;
}

.toolbar input {
  flex: 1;
  min-width: 0;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 12px 14px;
  font: inherit;
}

.toolbar button {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.06);
  padding: 0 16px;
}

.post-list {
  display: grid;
  gap: 12px;
}

.post-row {
  display: grid;
  grid-template-columns: 82px minmax(0, 1fr) auto;
  gap: 16px;
  align-items: center;
  padding: 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  box-shadow: 0 8px 28px rgba(15, 23, 42, 0.04);
}

.post-row.deleting {
  opacity: 0.45;
  pointer-events: none;
}

.cover {
  display: grid;
  place-items: center;
  width: 82px;
  height: 62px;
  overflow: hidden;
  border-radius: 8px;
  background: rgba(108, 99, 255, 0.1);
  color: #6c63ff;
  font-weight: 900;
  font-size: 1.4rem;
}

.cover img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.title-row {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 6px;
}

.title-row h2 {
  min-width: 0;
  overflow: hidden;
  color: #0f172a;
  font-size: 1rem;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin: 0;
}

.post-main p {
  margin: 0 0 8px;
  color: #64748b;
  font-size: 0.9rem;
  line-height: 1.55;
}

.status,
.tag {
  flex-shrink: 0;
  color: #94a3b8;
  background: #f1f5f9;
  border-radius: 999px;
  padding: 4px 9px;
  font-size: 0.72rem;
  font-weight: 800;
}

.status.published {
  color: #059669;
  background: rgba(16, 185, 129, 0.1);
}

.meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  color: #94a3b8;
  font-size: 0.78rem;
  font-weight: 700;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.icon-btn {
  color: #475569;
  background: #ffffff;
  padding: 8px 10px;
  text-decoration: none;
  font-size: 0.82rem;
}

.icon-btn:hover {
  color: #6c63ff;
  border-color: rgba(108, 99, 255, 0.42);
}

.icon-btn.danger:hover {
  color: #ef4444;
  border-color: rgba(239, 68, 68, 0.42);
}

.state {
  display: grid;
  place-items: center;
  gap: 12px;
  min-height: 360px;
  color: #64748b;
  text-align: center;
}

.empty h2,
.empty p {
  margin: 0;
}

.empty-mark {
  display: grid;
  place-items: center;
  width: 64px;
  height: 64px;
  color: #ffffff;
  background: #6c63ff;
  border-radius: 8px;
  font-size: 1.7rem;
  font-weight: 900;
}

.spinner {
  width: 36px;
  height: 36px;
  border: 3px solid #e2e8f0;
  border-top-color: #6c63ff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 860px) {
  .page-header,
  .toolbar {
    flex-direction: column;
  }

  .post-row {
    grid-template-columns: 64px minmax(0, 1fr);
  }

  .cover {
    width: 64px;
    height: 54px;
  }

  .actions {
    grid-column: 1 / -1;
    justify-content: flex-start;
  }
}
</style>
