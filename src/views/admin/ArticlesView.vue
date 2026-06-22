<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase.ts'

const router = useRouter()

interface Article {
  id: string
  title: string
  published: boolean
  created_at: string
  cover_image_url: string | null
}

const articles  = ref<Article[]>([])
const loading   = ref(true)
const deletingId = ref<string | null>(null)

onMounted(async () => {
  await fetchArticles()
})

async function fetchArticles() {
  loading.value = true
  const { data, error } = await supabase
      .from('articles')
      .select('id, title, published, created_at, cover_image_url')
      .order('created_at', { ascending: false })
  if (!error) articles.value = data ?? []
  loading.value = false
}

async function togglePublished(article: Article) {
  const { error } = await supabase
      .from('articles')
      .update({ published: !article.published })
      .eq('id', article.id)
  if (!error) article.published = !article.published
}

async function deleteArticle(id: string) {
  if (!confirm('Are you sure you want to delete this article?')) return
  deletingId.value = id
  await supabase.from('articles').delete().eq('id', id)
  articles.value = articles.value.filter(a => a.id !== id)
  deletingId.value = null
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="page">

    <!-- Header -->
    <div class="page-header">
      <div>
        <h1 class="page-title">Articles</h1>
        <p class="page-sub">{{ articles.length }} article{{ articles.length !== 1 ? 's' : '' }} total</p>
      </div>
      <button class="btn-new" @click="router.push('/admin/articles/new')">
        <span>＋</span> New Article
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>Loading articles...</p>
    </div>

    <!-- Empty -->
    <div v-else-if="articles.length === 0" class="empty-state">
      <div class="empty-icon">📝</div>
      <h3>No articles yet</h3>
      <p>Start writing your first article</p>
      <button class="btn-new" @click="router.push('/admin/articles/new')">Write your first article</button>
    </div>

    <!-- Article List -->
    <div v-else class="article-list">
      <div
          v-for="article in articles"
          :key="article.id"
          class="article-row"
          :class="{ deleting: deletingId === article.id }"
      >
        <!-- Cover -->
        <div class="article-cover">
          <img v-if="article.cover_image_url" :src="article.cover_image_url" :alt="article.title" />
          <div v-else class="cover-placeholder">📄</div>
        </div>

        <!-- Info -->
        <div class="article-info">
          <h3 class="article-title">{{ article.title }}</h3>
          <span class="article-date">{{ formatDate(article.created_at) }}</span>
        </div>

        <!-- Status badge -->
        <span class="status-badge" :class="article.published ? 'published' : 'draft'">
          {{ article.published ? 'Published' : 'Draft' }}
        </span>

        <!-- Actions -->
        <div class="article-actions">
          <!-- Preview -->
          <button
              class="action-btn preview"
              title="Preview"
              @click="router.push(`/articles/${article.id}`)"
          >
            👁
          </button>

          <!-- Edit -->
          <button
              class="action-btn edit"
              title="Edit"
              @click="router.push(`/admin/articles/${article.id}`)"
          >
            ✏️
          </button>

          <!-- Toggle Published -->
          <button
              class="action-btn"
              :class="article.published ? 'unpublish' : 'publish'"
              :title="article.published ? 'Unpublish' : 'Publish'"
              @click="togglePublished(article)"
          >
            {{ article.published ? '🔒' : '🚀' }}
          </button>

          <!-- Delete -->
          <button
              class="action-btn delete"
              title="Delete"
              :disabled="deletingId === article.id"
              @click="deleteArticle(article.id)"
          >
            🗑
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page {
  min-height: 100vh;
  background: #fff;
  padding: 2rem 2.5rem;
  font-family: 'Inter', system-ui, sans-serif;
}

.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 2rem;
}
.page-title {
  font-size: 1.75rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 0.25rem;
}
.page-sub {
  font-size: 0.88rem;
  color: #94a3b8;
  margin: 0;
}

.btn-new {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: #6366f1;
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 0.6rem 1.2rem;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.18s, transform 0.15s;
}
.btn-new:hover { background: #4f46e5; transform: translateY(-1px); }

/* Loading */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 6rem 0;
  color: #94a3b8;
  gap: 1rem;
}
.spinner {
  width: 36px; height: 36px;
  border: 3px solid #e2e8f0;
  border-top-color: #6366f1;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Empty */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 6rem 0;
  gap: 0.75rem;
  color: #94a3b8;
  text-align: center;
}
.empty-icon { font-size: 3rem; }
.empty-state h3 { font-size: 1.1rem; color: #475569; margin: 0; }
.empty-state p  { font-size: 0.88rem; margin: 0; }

/* Article list */
.article-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.article-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: #fafafa;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 0.9rem 1.1rem;
  transition: box-shadow 0.18s, opacity 0.2s;
}
.article-row:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.article-row.deleting { opacity: 0.4; pointer-events: none; }

.article-cover {
  width: 52px; height: 52px;
  border-radius: 8px;
  overflow: hidden;
  flex-shrink: 0;
  background: #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
}
.article-cover img { width: 100%; height: 100%; object-fit: cover; }
.cover-placeholder { font-size: 1.4rem; }

.article-info {
  flex: 1;
  min-width: 0;
}
.article-title {
  font-size: 0.95rem;
  font-weight: 600;
  color: #0f172a;
  margin: 0 0 0.25rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.article-date {
  font-size: 0.78rem;
  color: #94a3b8;
}

.status-badge {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.25rem 0.7rem;
  border-radius: 999px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  flex-shrink: 0;
}
.status-badge.published { background: rgba(16,185,129,0.1); color: #10b981; }
.status-badge.draft     { background: rgba(148,163,184,0.1); color: #94a3b8; }

.article-actions {
  display: flex;
  gap: 0.4rem;
  flex-shrink: 0;
}
.action-btn {
  width: 36px; height: 36px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #fff;
  cursor: pointer;
  font-size: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s;
}
.action-btn:hover { transform: translateY(-1px); }
.action-btn.preview:hover  { background: rgba(99,102,241,0.08);  border-color: #6366f1; }
.action-btn.edit:hover     { background: rgba(245,158,11,0.08);  border-color: #f59e0b; }
.action-btn.publish:hover  { background: rgba(16,185,129,0.08);  border-color: #10b981; }
.action-btn.unpublish:hover{ background: rgba(148,163,184,0.08); border-color: #94a3b8; }
.action-btn.delete:hover   { background: rgba(239,68,68,0.08);   border-color: #ef4444; }
.action-btn:disabled       { opacity: 0.4; cursor: not-allowed; }

@media (max-width: 640px) {
  .page { padding: 1.25rem; }
  .page-header { flex-direction: column; gap: 1rem; }
  .article-row { flex-wrap: wrap; }
}
</style>