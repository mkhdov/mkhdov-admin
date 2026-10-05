<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  MessageSquare,
  Reply,
  Trash2,
  CheckCircle,
  AlertTriangle,
  RefreshCw,
  Search,
  ExternalLink,
  Star,
  Heart,
  CornerDownRight
} from 'lucide-vue-next'
import AdminPageShell from './AdminPageShell.vue'
import { supabase } from '../../lib/supabase'

interface CommentItem {
  id: string
  post_type: 'blog' | 'article'
  post_id: string
  parent_id: string | null
  author_name: string
  author_email: string | null
  content: string
  rating: number | null
  is_admin: boolean
  status: 'approved' | 'pending' | 'spam'
  created_at: string
  updated_at: string
}

interface PostMeta {
  id: string
  title: string
  type: 'blog' | 'article'
  slug?: string | null
}

interface ReactionItem {
  post_type: string
  post_id: string
  reaction_type: string
}

const route = useRoute()

// Data
const comments = ref<CommentItem[]>([])
const posts = ref<PostMeta[]>([])
const reactions = ref<ReactionItem[]>([])
const loading = ref(true)
const refreshing = ref(false)

// Filters
const filterType = ref<'all' | 'blog' | 'article'>('all')
const filterPostId = ref<string>('all')
const filterStatus = ref<'all' | 'approved' | 'pending' | 'spam'>('all')
const searchQuery = ref('')

// Replying state
const activeReplyCommentId = ref<string | null>(null)
const replyingToComment = ref<CommentItem | null>(null)
const adminReplyName = ref('Olimjon Makhmudov')
const adminReplyContent = ref('')
const submittingReply = ref(false)
const replyTextareaRef = ref<HTMLTextAreaElement | null>(null)

// Actions
const deletingCommentId = ref<string | null>(null)

let commentsChannel: ReturnType<typeof supabase.channel> | null = null

// Posts map for quick lookup
const postsMap = computed(() => {
  const map = new Map<string, PostMeta>()
  for (const post of posts.value) {
    map.set(`${post.type}_${post.id}`, post)
  }
  return map
})

// Reactions summary by post
const reactionsSummary = computed(() => {
  const summary: Record<string, Record<string, number>> = {}
  for (const r of reactions.value) {
    const key = `${r.post_type}_${r.post_id}`
    if (!summary[key]) summary[key] = {}
    summary[key][r.reaction_type] = (summary[key][r.reaction_type] || 0) + 1
  }
  return summary
})

// Filtered comments
const filteredComments = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()

  return comments.value.filter((c) => {
    if (filterType.value !== 'all' && c.post_type !== filterType.value) return false
    if (filterPostId.value !== 'all' && c.post_id !== filterPostId.value) return false
    if (filterStatus.value !== 'all' && c.status !== filterStatus.value) return false

    if (query) {
      const post = postsMap.value.get(`${c.post_type}_${c.post_id}`)
      const postTitle = post ? post.title.toLowerCase() : ''
      const author = c.author_name.toLowerCase()
      const email = (c.author_email || '').toLowerCase()
      const content = c.content.toLowerCase()

      if (
        !author.includes(query) &&
        !email.includes(query) &&
        !content.includes(query) &&
        !postTitle.includes(query)
      ) {
        return false
      }
    }

    return true
  })
})

// Root comments and replies tree
const rootComments = computed(() => {
  return filteredComments.value
    .filter((c) => !c.parent_id)
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
})

const repliesByParent = computed(() => {
  const map: Record<string, CommentItem[]> = {}
  for (const c of filteredComments.value) {
    if (c.parent_id) {
      if (!map[c.parent_id]) map[c.parent_id] = []
      map[c.parent_id].push(c)
    }
  }
  for (const key of Object.keys(map)) {
    map[key].sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
  }
  return map
})

// Overall metrics
const totalReviews = computed(() => comments.value.filter((c) => typeof c.rating === 'number' && c.rating > 0).length)
const averageRating = computed(() => {
  const rated = comments.value.filter((c) => typeof c.rating === 'number' && c.rating > 0)
  if (!rated.length) return 0
  return rated.reduce((sum, c) => sum + (c.rating || 0), 0) / rated.length
})
const totalReactionsCount = computed(() => reactions.value.length)

// Post URL
function getPublicUrl(postType: 'blog' | 'article', postId: string) {
  const post = postsMap.value.get(`${postType}_${postId}`)
  const slugOrId = post?.slug || postId
  const baseUrl = 'http://localhost:5173'
  return postType === 'blog' ? `${baseUrl}/blog/${slugOrId}` : `${baseUrl}/articles/${postId}`
}

function getPostTitle(postType: 'blog' | 'article', postId: string) {
  const post = postsMap.value.get(`${postType}_${postId}`)
  return post?.title || `${postType === 'blog' ? 'Blog' : 'Article'} #${postId.slice(0, 8)}`
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString([], {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

async function loadData() {
  refreshing.value = true

  // 1. Load Posts (Blogs & Articles)
  const [blogsRes, articlesRes, commentsRes, reactionsRes] = await Promise.all([
    supabase.from('blog_posts').select('id, title, slug'),
    supabase.from('articles').select('id, title'),
    supabase.from('post_comments').select('*').order('created_at', { ascending: false }),
    supabase.from('post_reactions').select('post_type, post_id, reaction_type'),
  ])

  const loadedPosts: PostMeta[] = []
  if (blogsRes.data) {
    for (const b of blogsRes.data) {
      loadedPosts.push({ id: b.id, title: b.title, type: 'blog', slug: b.slug })
    }
  }
  if (articlesRes.data) {
    for (const a of articlesRes.data) {
      loadedPosts.push({ id: a.id, title: a.title, type: 'article' })
    }
  }
  posts.value = loadedPosts

  if (commentsRes.data) {
    comments.value = commentsRes.data as CommentItem[]
  }
  if (reactionsRes.data) {
    reactions.value = reactionsRes.data as ReactionItem[]
  }

  loading.value = false
  refreshing.value = false
}

function openReply(comment: CommentItem) {
  activeReplyCommentId.value = comment.id
  replyingToComment.value = comment
  adminReplyContent.value = ''
  nextTick(() => {
    replyTextareaRef.value?.focus()
  })
}

function closeReply() {
  activeReplyCommentId.value = null
  replyingToComment.value = null
  adminReplyContent.value = ''
}

async function submitAdminReply() {
  const target = replyingToComment.value
  const content = adminReplyContent.value.trim()
  if (!target || !content) return

  submittingReply.value = true

  // If replying to another reply, parent can be the root comment or the direct reply
  // If target.parent_id is set, this is a reply to a reply, so we attach to target.parent_id (root)
  const parentId = target.parent_id || target.id
  const finalContent = target.parent_id ? `@${target.author_name} ${content}` : content

  const payload = {
    post_type: target.post_type,
    post_id: target.post_id,
    parent_id: parentId,
    author_name: adminReplyName.value.trim() || 'Olimjon Makhmudov',
    author_email: 'mkhdov@yahoo.com',
    content: finalContent,
    rating: null,
    is_admin: true,
    status: 'approved',
  }

  const { data, error } = await supabase
    .from('post_comments')
    .insert([payload])
    .select('*')
    .single()

  if (error) {
    alert(`Failed to post reply: ${error.message}`)
  } else if (data) {
    if (!comments.value.some((c) => c.id === data.id)) {
      comments.value.unshift(data as CommentItem)
    }
    closeReply()
  }

  submittingReply.value = false
}

async function updateCommentStatus(comment: CommentItem, newStatus: 'approved' | 'pending' | 'spam') {
  const { error } = await supabase
    .from('post_comments')
    .update({ status: newStatus })
    .eq('id', comment.id)

  if (error) {
    alert(`Failed to update status: ${error.message}`)
  } else {
    comment.status = newStatus
  }
}

async function deleteComment(comment: CommentItem) {
  if (!confirm(`Delete comment from "${comment.author_name}"? This will also remove any replies.`)) {
    return
  }

  deletingCommentId.value = comment.id
  const { error } = await supabase
    .from('post_comments')
    .delete()
    .eq('id', comment.id)

  if (error) {
    alert(`Failed to delete comment: ${error.message}`)
  } else {
    // Remove comment and any replies that had it as parent
    comments.value = comments.value.filter((c) => c.id !== comment.id && c.parent_id !== comment.id)
  }
  deletingCommentId.value = null
}

function subscribeToRealtime() {
  commentsChannel = supabase
    .channel('admin_comments_channel')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'post_comments',
      },
      (payload) => {
        if (payload.eventType === 'INSERT') {
          const incoming = payload.new as CommentItem
          if (!comments.value.some((c) => c.id === incoming.id)) {
            comments.value.unshift(incoming)
          }
        } else if (payload.eventType === 'DELETE') {
          comments.value = comments.value.filter((c) => c.id !== payload.old.id)
        } else if (payload.eventType === 'UPDATE') {
          const updated = payload.new as CommentItem
          const idx = comments.value.findIndex((c) => c.id === updated.id)
          if (idx !== -1) {
            comments.value[idx] = updated
          }
        }
      }
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'post_reactions',
      },
      () => {
        void supabase
          .from('post_reactions')
          .select('post_type, post_id, reaction_type')
          .then(({ data }) => {
            if (data) reactions.value = data as ReactionItem[]
          })
      }
    )
    .subscribe()
}

onMounted(() => {
  // Read query params if routed from Blog or Articles view
  if (route.query.type === 'blog' || route.query.type === 'article') {
    filterType.value = route.query.type
  }
  if (typeof route.query.postId === 'string') {
    filterPostId.value = route.query.postId
  }

  void loadData()
  subscribeToRealtime()
})

watch(
  () => route.query,
  (q) => {
    if (q.type === 'blog' || q.type === 'article') {
      filterType.value = q.type
    } else {
      filterType.value = 'all'
    }
    if (typeof q.postId === 'string') {
      filterPostId.value = q.postId
    } else {
      filterPostId.value = 'all'
    }
  }
)

onUnmounted(() => {
  if (commentsChannel) {
    supabase.removeChannel(commentsChannel)
  }
})
</script>

<template>
  <AdminPageShell title="Comments & Reviews">
    <div class="comments-page">
      <!-- Header -->
      <header class="page-header">
        <div>
          <span class="eyebrow">Engagement</span>
          <h1>Comments &amp; Reviews</h1>
          <p class="subtitle">
            Manage feedback, replies, and reactions across your blogs and articles.
          </p>
        </div>

        <div class="header-actions">
          <button class="btn-secondary" type="button" :disabled="refreshing" @click="loadData">
            <RefreshCw class="btn-icon" :class="{ 'spin-anim': refreshing }" />
            <span>Refresh</span>
          </button>
        </div>
      </header>

      <!-- Stat Cards -->
      <section class="stat-grid">
        <div class="stat-card">
          <div class="stat-icon purple">
            <MessageSquare class="icon" />
          </div>
          <div>
            <span class="stat-label">Total Comments</span>
            <strong class="stat-value">{{ comments.length }}</strong>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon amber">
            <Star class="icon" />
          </div>
          <div>
            <span class="stat-label">Reviews &amp; Rating</span>
            <strong class="stat-value">
              {{ averageRating > 0 ? averageRating.toFixed(1) + ' ★' : 'None yet' }}
            </strong>
            <small class="stat-hint">{{ totalReviews }} total review{{ totalReviews !== 1 ? 's' : '' }}</small>
          </div>
        </div>

        <div class="stat-card">
          <div class="stat-icon rose">
            <Heart class="icon" />
          </div>
          <div>
            <span class="stat-label">Total Reactions</span>
            <strong class="stat-value">{{ totalReactionsCount }}</strong>
          </div>
        </div>
      </section>

      <!-- Filters & Search Toolbar -->
      <section class="toolbar">
        <div class="search-box">
          <Search class="search-icon" />
          <input
            v-model="searchQuery"
            type="search"
            placeholder="Search comment, author, or title..."
          />
        </div>

        <div class="filter-group">
          <!-- Type Filter -->
          <select v-model="filterType" class="select-input">
            <option value="all">All Content</option>
            <option value="blog">Blogs</option>
            <option value="article">Articles</option>
          </select>

          <!-- Post Filter -->
          <select v-model="filterPostId" class="select-input post-select">
            <option value="all">All Posts</option>
            <option
              v-for="p in posts"
              :key="p.id"
              :value="p.id"
            >
              [{{ p.type.toUpperCase() }}] {{ p.title }}
            </option>
          </select>

          <!-- Status Filter -->
          <select v-model="filterStatus" class="select-input">
            <option value="all">All Status</option>
            <option value="approved">Approved</option>
            <option value="pending">Pending</option>
            <option value="spam">Spam</option>
          </select>
        </div>
      </section>

      <!-- Loading State -->
      <div v-if="loading" class="state-box">
        <div class="spinner"></div>
        <p>Loading comments &amp; reviews...</p>
      </div>

      <!-- Empty State -->
      <div v-else-if="rootComments.length === 0" class="state-box empty">
        <div class="empty-icon">💭</div>
        <h3>No comments found</h3>
        <p>When visitors leave reviews or comments, they will appear here in real time.</p>
      </div>

      <!-- Comments Thread List -->
      <section v-else class="comments-list">
        <article
          v-for="comment in rootComments"
          :key="comment.id"
          class="comment-card"
          :class="{
            'is-admin-comment': comment.is_admin,
            'is-deleting': deletingCommentId === comment.id,
            'status-pending': comment.status === 'pending',
            'status-spam': comment.status === 'spam'
          }"
        >
          <!-- Post Context Banner -->
          <div class="post-context-banner">
            <div class="post-title-wrap">
              <span class="type-pill" :class="comment.post_type">{{ comment.post_type }}</span>
              <strong class="target-title">{{ getPostTitle(comment.post_type, comment.post_id) }}</strong>
            </div>

            <!-- Reactions on this post -->
            <div
              v-if="reactionsSummary[`${comment.post_type}_${comment.post_id}`]"
              class="post-reactions-pill"
            >
              <span v-for="(cnt, rType) in reactionsSummary[`${comment.post_type}_${comment.post_id}`]" :key="rType">
                {{ rType === 'like' ? '👍' : rType === 'love' ? '❤️' : rType === 'clap' ? '👏' : rType === 'fire' ? '🔥' : '💡' }} {{ cnt }}
              </span>
            </div>

            <a
              :href="getPublicUrl(comment.post_type, comment.post_id)"
              target="_blank"
              rel="noopener noreferrer"
              class="view-live-btn"
              title="View on live site"
            >
              <ExternalLink class="icon-sm" />
            </a>
          </div>

          <!-- Main Comment Content -->
          <div class="comment-content-area">
            <div class="author-bar">
              <div class="author-details">
                <div class="avatar" :class="{ 'admin-avatar': comment.is_admin }">
                  {{ comment.author_name.slice(0, 2).toUpperCase() }}
                </div>
                <div>
                  <div class="name-row">
                    <strong class="author-name">{{ comment.author_name }}</strong>
                    <span v-if="comment.is_admin" class="author-badge">Author / Admin</span>
                    <span v-if="comment.status !== 'approved'" class="status-badge" :class="comment.status">
                      {{ comment.status }}
                    </span>
                  </div>
                  <div class="sub-row">
                    <span v-if="comment.author_email" class="author-email">{{ comment.author_email }} • </span>
                    <span class="time-label">{{ formatDate(comment.created_at) }}</span>
                  </div>
                </div>
              </div>

              <!-- Rating if any -->
              <div v-if="comment.rating" class="rating-stars" :title="`${comment.rating} stars`">
                <span v-for="s in 5" :key="s" class="star" :class="{ active: s <= comment.rating }">★</span>
              </div>
            </div>

            <p class="comment-text">{{ comment.content }}</p>

            <!-- Actions Bar -->
            <div class="actions-bar">
              <button
                type="button"
                class="act-btn reply-btn"
                @click="openReply(comment)"
              >
                <Reply class="icon-sm" />
                <span>Reply as Admin</span>
              </button>

              <div class="moderation-btns">
                <button
                  v-if="comment.status !== 'approved'"
                  type="button"
                  class="act-btn approve-btn"
                  @click="updateCommentStatus(comment, 'approved')"
                  title="Approve comment"
                >
                  <CheckCircle class="icon-sm" />
                  <span>Approve</span>
                </button>

                <button
                  v-if="comment.status !== 'spam'"
                  type="button"
                  class="act-btn spam-btn"
                  @click="updateCommentStatus(comment, 'spam')"
                  title="Mark as spam"
                >
                  <AlertTriangle class="icon-sm" />
                  <span>Spam</span>
                </button>

                <button
                  type="button"
                  class="act-btn delete-btn"
                  :disabled="deletingCommentId === comment.id"
                  @click="deleteComment(comment)"
                  title="Delete comment and replies"
                >
                  <Trash2 class="icon-sm" />
                  <span>Delete</span>
                </button>
              </div>
            </div>

            <!-- Inline Admin Reply Composer -->
            <div v-if="activeReplyCommentId === comment.id" class="reply-composer">
              <div class="composer-header">
                <span>Replying to <strong>{{ comment.author_name }}</strong> as Admin</span>
                <button type="button" class="btn-close-composer" @click="closeReply">✕</button>
              </div>

              <div class="composer-body">
                <div class="composer-input-row">
                  <label>Display Name:</label>
                  <input
                    v-model="adminReplyName"
                    type="text"
                    placeholder="Admin Name"
                    class="composer-name-input"
                  />
                </div>
                <textarea
                  ref="replyTextareaRef"
                  v-model="adminReplyContent"
                  rows="3"
                  placeholder="Type your official reply..."
                  class="composer-textarea"
                ></textarea>
              </div>

              <div class="composer-footer">
                <button type="button" class="btn-cancel" @click="closeReply">Cancel</button>
                <button
                  type="button"
                  class="btn-send-reply"
                  :disabled="submittingReply || !adminReplyContent.trim()"
                  @click="submitAdminReply"
                >
                  <span v-if="submittingReply" class="mini-spinner"></span>
                  <span v-else>Post Reply as Admin</span>
                </button>
              </div>
            </div>
          </div>

          <!-- Nested Replies Tree -->
          <div v-if="repliesByParent[comment.id]?.length" class="nested-replies-list">
            <div
              v-for="reply in repliesByParent[comment.id]"
              :key="reply.id"
              class="reply-item"
              :class="{
                'is-admin-comment': reply.is_admin,
                'is-deleting': deletingCommentId === reply.id
              }"
            >
              <div class="reply-indicator">
                <CornerDownRight class="reply-arrow" />
              </div>

              <div class="reply-content-box">
                <div class="author-bar">
                  <div class="author-details">
                    <div class="avatar small" :class="{ 'admin-avatar': reply.is_admin }">
                      {{ reply.author_name.slice(0, 2).toUpperCase() }}
                    </div>
                    <div>
                      <div class="name-row">
                        <strong class="author-name">{{ reply.author_name }}</strong>
                        <span v-if="reply.is_admin" class="author-badge">Author / Admin</span>
                        <span v-if="reply.status !== 'approved'" class="status-badge" :class="reply.status">
                          {{ reply.status }}
                        </span>
                      </div>
                      <span class="time-label">{{ formatDate(reply.created_at) }}</span>
                    </div>
                  </div>
                </div>

                <p class="comment-text">{{ reply.content }}</p>

                <!-- Actions for Reply -->
                <div class="actions-bar">
                  <button
                    type="button"
                    class="act-btn reply-btn"
                    @click="openReply(reply)"
                  >
                    <Reply class="icon-sm" />
                    <span>Reply to this</span>
                  </button>

                  <div class="moderation-btns">
                    <button
                      type="button"
                      class="act-btn delete-btn"
                      :disabled="deletingCommentId === reply.id"
                      @click="deleteComment(reply)"
                    >
                      <Trash2 class="icon-sm" />
                      <span>Delete</span>
                    </button>
                  </div>
                </div>

                <!-- Inline Admin Reply Composer for nested reply -->
                <div v-if="activeReplyCommentId === reply.id" class="reply-composer">
                  <div class="composer-header">
                    <span>Replying to <strong>{{ reply.author_name }}</strong></span>
                    <button type="button" class="btn-close-composer" @click="closeReply">✕</button>
                  </div>

                  <div class="composer-body">
                    <div class="composer-input-row">
                      <label>Display Name:</label>
                      <input
                        v-model="adminReplyName"
                        type="text"
                        placeholder="Admin Name"
                        class="composer-name-input"
                      />
                    </div>
                    <textarea
                      ref="replyTextareaRef"
                      v-model="adminReplyContent"
                      rows="3"
                      placeholder="Type your reply..."
                      class="composer-textarea"
                    ></textarea>
                  </div>

                  <div class="composer-footer">
                    <button type="button" class="btn-cancel" @click="closeReply">Cancel</button>
                    <button
                      type="button"
                      class="btn-send-reply"
                      :disabled="submittingReply || !adminReplyContent.trim()"
                      @click="submitAdminReply"
                    >
                      <span v-if="submittingReply" class="mini-spinner"></span>
                      <span v-else>Post Reply</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </article>
      </section>
    </div>
  </AdminPageShell>
</template>

<style scoped>
.comments-page {
  display: flex;
  flex-direction: column;
  gap: 24px;
  font-family: 'Inter', system-ui, sans-serif;
  color: #1e293b;
}

/* Header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.eyebrow {
  font-size: 0.75rem;
  font-weight: 800;
  color: #6c63ff;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.page-header h1 {
  margin: 4px 0 6px;
  font-size: clamp(1.8rem, 3.5vw, 2.4rem);
  color: #0f172a;
  letter-spacing: -0.02em;
}

.subtitle {
  margin: 0;
  color: #64748b;
  font-size: 0.95rem;
}

.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-family: inherit;
  font-size: 13px;
  font-weight: 600;
  color: #475569;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary:hover:not(:disabled) {
  border-color: #6c63ff;
  color: #6c63ff;
}

.btn-icon {
  width: 14px;
  height: 14px;
}

.spin-anim {
  animation: spin 0.8s linear infinite;
}

/* Stats */
.stat-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 18px 20px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(15, 23, 42, 0.04);
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-icon.purple {
  background: rgba(108, 99, 255, 0.1);
  color: #6c63ff;
}

.stat-icon.amber {
  background: rgba(245, 158, 11, 0.12);
  color: #d97706;
}

.stat-icon.rose {
  background: rgba(244, 63, 94, 0.1);
  color: #e11d48;
}

.stat-icon .icon {
  width: 24px;
  height: 24px;
}

.stat-label {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.stat-value {
  display: block;
  font-size: 1.5rem;
  font-weight: 800;
  color: #0f172a;
}

.stat-hint {
  font-size: 0.78rem;
  color: #94a3b8;
}

/* Toolbar */
.toolbar {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.search-box {
  position: relative;
  flex: 1;
  min-width: 240px;
}

.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 16px;
  height: 16px;
  color: #94a3b8;
}

.search-box input {
  width: 100%;
  box-sizing: border-box;
  padding: 10px 14px 10px 38px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-family: inherit;
  font-size: 13.5px;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.search-box input:focus {
  border-color: #6c63ff;
  box-shadow: 0 0 0 3px rgba(108, 99, 255, 0.1);
}

.filter-group {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.select-input {
  padding: 10px 14px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-family: inherit;
  font-size: 13.5px;
  color: #334155;
  outline: none;
  cursor: pointer;
  transition: border-color 0.2s;
}

.select-input:focus {
  border-color: #6c63ff;
}

.post-select {
  max-width: 280px;
}

/* States */
.state-box {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 80px 20px;
  text-align: center;
  color: #64748b;
  gap: 12px;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #e2e8f0;
  border-top-color: #6c63ff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

.empty-icon {
  font-size: 40px;
}

.state-box.empty h3 {
  margin: 0;
  color: #1e293b;
  font-size: 1.1rem;
}

/* Comments List */
.comments-list {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.comment-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  overflow: hidden;
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.03);
  transition: border-color 0.2s, box-shadow 0.2s, opacity 0.2s;
}

.comment-card.is-admin-comment {
  border-color: rgba(108, 99, 255, 0.35);
}

.comment-card.status-pending {
  border-color: rgba(245, 158, 11, 0.4);
  background: #fffdfa;
}

.comment-card.status-spam {
  border-color: rgba(239, 68, 68, 0.4);
  background: #fffafa;
}

.comment-card.is-deleting {
  opacity: 0.4;
  pointer-events: none;
}

/* Post Context Banner */
.post-context-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 18px;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
  font-size: 13px;
  gap: 12px;
  flex-wrap: wrap;
}

.post-title-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.type-pill {
  font-size: 10px;
  font-weight: 800;
  padding: 2px 7px;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.type-pill.blog {
  background: rgba(108, 99, 255, 0.12);
  color: #6c63ff;
}

.type-pill.article {
  background: rgba(14, 165, 233, 0.12);
  color: #0284c7;
}

.target-title {
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.post-reactions-pill {
  display: flex;
  gap: 8px;
  font-size: 12px;
  font-weight: 700;
  color: #475569;
  background: #ffffff;
  padding: 3px 10px;
  border-radius: 999px;
  border: 1px solid #e2e8f0;
}

.view-live-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 6px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  color: #64748b;
  transition: all 0.18s;
}

.view-live-btn:hover {
  color: #6c63ff;
  border-color: #6c63ff;
}

/* Comment Content Area */
.comment-content-area {
  padding: 18px 20px;
}

.author-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.author-details {
  display: flex;
  align-items: center;
  gap: 12px;
}

.avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: #f1f5f9;
  color: #475569;
  font-size: 13px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.avatar.small {
  width: 30px;
  height: 30px;
  font-size: 11px;
}

.avatar.admin-avatar {
  background: linear-gradient(135deg, #6c63ff, #818cf8);
  color: #ffffff;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.author-name {
  font-size: 14px;
  color: #0f172a;
}

.author-badge {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 7px;
  border-radius: 999px;
  background: rgba(108, 99, 255, 0.12);
  color: #6c63ff;
  text-transform: uppercase;
}

.status-badge {
  font-size: 10px;
  font-weight: 800;
  padding: 1px 7px;
  border-radius: 999px;
  text-transform: uppercase;
}

.status-badge.pending {
  background: rgba(245, 158, 11, 0.14);
  color: #d97706;
}

.status-badge.spam {
  background: rgba(239, 68, 68, 0.14);
  color: #dc2626;
}

.sub-row {
  font-size: 12px;
  color: #94a3b8;
}

.author-email {
  color: #64748b;
}

.rating-stars {
  color: #e2e8f0;
  font-size: 15px;
  line-height: 1;
}

.rating-stars .star.active {
  color: #f59e0b;
}

.comment-text {
  font-size: 14px;
  line-height: 1.65;
  color: #334155;
  margin: 0 0 16px;
  white-space: pre-wrap;
  word-break: break-word;
}

/* Actions Bar */
.actions-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  flex-wrap: wrap;
}

.act-btn {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #ffffff;
  font-family: inherit;
  font-size: 12.5px;
  font-weight: 600;
  color: #475569;
  cursor: pointer;
  transition: all 0.18s;
}

.icon-sm {
  width: 14px;
  height: 14px;
}

.reply-btn {
  color: #6c63ff;
  border-color: rgba(108, 99, 255, 0.24);
  background: rgba(108, 99, 255, 0.04);
}

.reply-btn:hover {
  background: rgba(108, 99, 255, 0.1);
  border-color: #6c63ff;
}

.moderation-btns {
  display: flex;
  gap: 8px;
}

.approve-btn:hover {
  color: #10b981;
  border-color: #10b981;
  background: rgba(16, 185, 129, 0.05);
}

.spam-btn:hover {
  color: #f59e0b;
  border-color: #f59e0b;
  background: rgba(245, 158, 11, 0.05);
}

.delete-btn:hover {
  color: #ef4444;
  border-color: #ef4444;
  background: rgba(239, 68, 68, 0.05);
}

/* Reply Composer */
.reply-composer {
  margin-top: 14px;
  padding: 16px;
  background: #f8fafc;
  border: 1px solid rgba(108, 99, 255, 0.2);
  border-radius: 12px;
}

.composer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  font-size: 13px;
  color: #475569;
}

.composer-header strong {
  color: #6c63ff;
}

.btn-close-composer {
  background: none;
  border: none;
  color: #94a3b8;
  cursor: pointer;
  font-size: 14px;
}

.composer-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.composer-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #64748b;
}

.composer-name-input {
  padding: 6px 10px;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  font-family: inherit;
  font-size: 13px;
  color: #1e293b;
  outline: none;
}

.composer-textarea {
  width: 100%;
  box-sizing: border-box;
  padding: 10px 12px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  font-family: inherit;
  font-size: 13.5px;
  outline: none;
}

.composer-textarea:focus {
  border-color: #6c63ff;
  box-shadow: 0 0 0 2px rgba(108, 99, 255, 0.12);
}

.composer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 12px;
}

.btn-cancel {
  padding: 6px 14px;
  border: 1px solid #cbd5e1;
  background: #ffffff;
  border-radius: 8px;
  font-size: 12.5px;
  cursor: pointer;
}

.btn-send-reply {
  padding: 6px 18px;
  background: #6c63ff;
  color: #ffffff;
  border: none;
  border-radius: 8px;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
  transition: background-color 0.18s;
}

.btn-send-reply:hover:not(:disabled) {
  background: #5548eb;
}

.btn-send-reply:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Nested replies */
.nested-replies-list {
  background: #f8fafc;
  border-top: 1px solid #e2e8f0;
  padding: 12px 18px 18px 24px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.reply-item {
  display: flex;
  gap: 10px;
}

.reply-arrow {
  width: 16px;
  height: 16px;
  color: #94a3b8;
  margin-top: 8px;
  flex-shrink: 0;
}

.reply-content-box {
  flex: 1;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 12px 16px;
}

.mini-spinner {
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #ffffff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  display: inline-block;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
  .stat-grid {
    grid-template-columns: 1fr;
  }
}
</style>
