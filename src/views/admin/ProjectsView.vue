<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../lib/supabase.ts'

const router = useRouter()

interface Project {
  id: string
  title: string
  description: string | null
  published: boolean
  featured: boolean
  tech_stack: string[] | null
  cover_image_url: string | null
  live_url: string | null
  github_url: string | null
  order_index: number
  created_at: string
}

const projects   = ref<Project[]>([])
const loading    = ref(true)
const deletingId = ref<string | null>(null)

onMounted(async () => {
  await fetchProjects()
})

async function fetchProjects() {
  loading.value = true
  const { data, error } = await supabase
      .from('projects')
      .select('id, title, description, published, featured, tech_stack, cover_image_url, live_url, github_url, order_index, created_at')
      .order('order_index', { ascending: true })
  if (!error) projects.value = data ?? []
  loading.value = false
}

async function togglePublished(project: Project) {
  const { error } = await supabase
      .from('projects')
      .update({ published: !project.published })
      .eq('id', project.id)
  if (!error) project.published = !project.published
}

async function toggleFeatured(project: Project) {
  const { error } = await supabase
      .from('projects')
      .update({ featured: !project.featured })
      .eq('id', project.id)
  if (!error) project.featured = !project.featured
}

async function deleteProject(id: string) {
  if (!confirm('Are you sure you want to delete this project?')) return
  deletingId.value = id
  await supabase.from('projects').delete().eq('id', id)
  projects.value = projects.value.filter(p => p.id !== id)
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
        <h1 class="page-title">Projects</h1>
        <p class="page-sub">{{ projects.length }} project{{ projects.length !== 1 ? 's' : '' }} total</p>
      </div>
      <button class="btn-new" @click="router.push('/admin/projects/new')">
        <span>＋</span> New Project
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>Loading projects...</p>
    </div>

    <!-- Empty -->
    <div v-else-if="projects.length === 0" class="empty-state">
      <div class="empty-icon">🚀</div>
      <h3>No projects yet</h3>
      <p>Add your first project to showcase your work</p>
      <button class="btn-new" @click="router.push('/admin/projects/new')">Add your first project</button>
    </div>

    <!-- Project List -->
    <div v-else class="project-list">
      <div
          v-for="project in projects"
          :key="project.id"
          class="project-row"
          :class="{ deleting: deletingId === project.id }"
      >
        <!-- Cover -->
        <div class="project-cover">
          <img v-if="project.cover_image_url" :src="project.cover_image_url" :alt="project.title" />
          <div v-else class="cover-placeholder">🖥️</div>
        </div>

        <!-- Info -->
        <div class="project-info">
          <div class="project-title-row">
            <h3 class="project-title">{{ project.title }}</h3>
            <span v-if="project.featured" class="featured-pill">⭐ Featured</span>
          </div>
          <div class="project-meta">
            <span class="project-date">{{ formatDate(project.created_at) }}</span>
            <div v-if="project.tech_stack?.length" class="tech-pills">
              <span v-for="t in project.tech_stack.slice(0, 3)" :key="t" class="tech-pill">{{ t }}</span>
              <span v-if="project.tech_stack.length > 3" class="tech-pill more">+{{ project.tech_stack.length - 3 }}</span>
            </div>
          </div>
        </div>

        <!-- Status badge -->
        <span class="status-badge" :class="project.published ? 'published' : 'draft'">
          {{ project.published ? 'Published' : 'Draft' }}
        </span>

        <!-- Actions -->
        <div class="project-actions">
          <!-- External links -->
          <a
              v-if="project.live_url"
              :href="project.live_url"
              target="_blank"
              rel="noopener noreferrer"
              class="action-btn live"
              title="Live Demo"
          >🔗</a>
          <a
              v-if="project.github_url"
              :href="project.github_url"
              target="_blank"
              rel="noopener noreferrer"
              class="action-btn github"
              title="GitHub"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/>
            </svg>
          </a>
          <!-- Edit -->
          <button
              class="action-btn edit"
              title="Edit"
              @click="router.push(`/admin/projects/${project.id}`)"
          >✏️</button>

          <!-- Toggle Featured -->
          <button
              class="action-btn"
              :class="project.featured ? 'unfeatured' : 'feature'"
              :title="project.featured ? 'Unfeature' : 'Feature'"
              @click="toggleFeatured(project)"
          >{{ project.featured ? '★' : '☆' }}</button>

          <!-- Toggle Published -->
          <button
              class="action-btn"
              :class="project.published ? 'unpublish' : 'publish'"
              :title="project.published ? 'Unpublish' : 'Publish'"
              @click="togglePublished(project)"
          >{{ project.published ? '🔒' : '🚀' }}</button>

          <!-- Delete -->
          <button
              class="action-btn delete"
              title="Delete"
              :disabled="deletingId === project.id"
              @click="deleteProject(project.id)"
          >🗑</button>
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

/* Project list */
.project-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.project-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  background: #fafafa;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 0.9rem 1.1rem;
  transition: box-shadow 0.18s, opacity 0.2s;
}
.project-row:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.project-row.deleting { opacity: 0.4; pointer-events: none; }

.project-cover {
  width: 64px; height: 48px;
  border-radius: 8px;
  overflow: hidden;
  flex-shrink: 0;
  background: #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
}
.project-cover img { width: 100%; height: 100%; object-fit: cover; }
.cover-placeholder { font-size: 1.4rem; }

.project-info {
  flex: 1;
  min-width: 0;
}

.project-title-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.35rem;
}

.project-title {
  font-size: 0.95rem;
  font-weight: 600;
  color: #0f172a;
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.featured-pill {
  font-size: 0.68rem;
  font-weight: 700;
  color: #f59e0b;
  background: rgba(245,158,11,0.1);
  border: 1px solid rgba(245,158,11,0.25);
  padding: 2px 8px;
  border-radius: 999px;
  flex-shrink: 0;
}

.project-meta {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.project-date {
  font-size: 0.78rem;
  color: #94a3b8;
}

.tech-pills {
  display: flex;
  gap: 0.35rem;
}

.tech-pill {
  font-size: 0.68rem;
  font-weight: 600;
  color: #6366f1;
  background: rgba(99,102,241,0.07);
  border: 1px solid rgba(99,102,241,0.15);
  padding: 2px 8px;
  border-radius: 999px;
}
.tech-pill.more { color: #94a3b8; background: rgba(148,163,184,0.08); border-color: rgba(148,163,184,0.2); }

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

.project-actions {
  display: flex;
  gap: 0.4rem;
  flex-shrink: 0;
  align-items: center;
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
  text-decoration: none;
  color: inherit;
}
.action-btn:hover { transform: translateY(-1px); }
.action-btn.live:hover    { background: rgba(99,102,241,0.08);  border-color: #6366f1; }
.action-btn.github:hover  { background: rgba(15,23,42,0.06);    border-color: #0f172a; }
.action-btn.edit:hover    { background: rgba(245,158,11,0.08);  border-color: #f59e0b; }
.action-btn.feature:hover { background: rgba(245,158,11,0.08);  border-color: #f59e0b; color: #f59e0b; }
.action-btn.unfeatured:hover { background: rgba(148,163,184,0.08); border-color: #94a3b8; }
.action-btn.publish:hover   { background: rgba(16,185,129,0.08);  border-color: #10b981; }
.action-btn.unpublish:hover { background: rgba(148,163,184,0.08); border-color: #94a3b8; }
.action-btn.delete:hover    { background: rgba(239,68,68,0.08);   border-color: #ef4444; }
.action-btn:disabled        { opacity: 0.4; cursor: not-allowed; }

@media (max-width: 640px) {
  .page { padding: 1.25rem; }
  .page-header { flex-direction: column; gap: 1rem; }
  .project-row { flex-wrap: wrap; }
}
</style>
