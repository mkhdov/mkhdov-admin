<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ArrowLeft,
  Image as ImageIcon,
  Mic,
  Hash,
  Link as LinkIcon,
  Bold,
  Italic,
  Code,
  List,
  Quote,
  Send,
  Sparkles,
  X
} from 'lucide-vue-next'
import { supabase } from '../../lib/supabase'

const route = useRoute()
const router = useRouter()

const isEdit = computed(() => Boolean(route.params.id))
const postId = computed(() => route.params.id as string | undefined)

// Form states
const title = ref('') // Optional headline / topic
const content = ref('') // Main post content
const coverImageUrl = ref('')
const audioUrl = ref('')
const author = ref('Olimjon Makhmudov')
const tags = ref<string[]>([])
const tagInput = ref('')
const slug = ref('')
const published = ref(true) // Default to publish for social posts
const publishedAt = ref('')
const slugTouched = ref(false)

// UI states
const saving = ref(false)
const uploadingImage = ref(false)
const uploadingAudio = ref(false)
const saveMsg = ref('')
const activeTab = ref<'compose' | 'preview'>('compose')
const textareaRef = ref<HTMLTextAreaElement | null>(null)

// Character & word counters
const charCount = computed(() => content.value.length)
const wordCount = computed(() => {
  const clean = content.value.trim()
  return clean ? clean.split(/\s+/).length : 0
})

// Auto slug generation
watch(title, (newTitle) => {
  if (!slugTouched.value && !isEdit.value && newTitle.trim()) {
    slug.value = makeSlug(newTitle)
  }
})

watch(content, (newContent) => {
  if (!slugTouched.value && !isEdit.value && !title.value.trim() && newContent.trim()) {
    const firstLine = newContent.split('\n')[0].slice(0, 40)
    slug.value = makeSlug(firstLine)
  }
})

onMounted(async () => {
  if (isEdit.value && postId.value) {
    await loadPost()
  } else {
    // Default publish time to now
    publishedAt.value = toDatetimeLocal(new Date().toISOString())
  }
})

async function loadPost() {
  if (!postId.value) return
  const { data, error } = await supabase
    .from('blog_posts')
    .select('*')
    .eq('id', postId.value)
    .single()

  if (error || !data) {
    alert(`Unable to load post: ${error?.message || 'Not found'}`)
    await router.push('/admin/blog')
    return
  }

  title.value = data.title && data.title !== 'Untitled' ? data.title : ''
  content.value = data.content ?? ''
  coverImageUrl.value = data.cover_image_url ?? ''
  audioUrl.value = data.audio_url ?? ''
  author.value = data.author ?? 'Olimjon Makhmudov'
  tags.value = Array.isArray(data.tags) ? data.tags : []
  slug.value = data.slug ?? ''
  published.value = Boolean(data.published)
  publishedAt.value = toDatetimeLocal(data.published_at || data.created_at)
  slugTouched.value = Boolean(data.slug)
}

function makeSlug(value: string) {
  return value
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
    .slice(0, 60)
}

function onSlugInput() {
  slugTouched.value = true
  slug.value = makeSlug(slug.value)
}

function toDatetimeLocal(iso: string | null) {
  if (!iso) return ''
  const date = new Date(iso)
  const offset = date.getTimezoneOffset()
  const localDate = new Date(date.getTime() - offset * 60_000)
  return localDate.toISOString().slice(0, 16)
}

function fromDatetimeLocal(value: string) {
  if (!value) return null
  return new Date(value).toISOString()
}

// ── Text Formatting Helpers ─────────────────────────────────
function insertFormat(prefix: string, suffix = '') {
  const el = textareaRef.value
  if (!el) return
  const start = el.selectionStart
  const end = el.selectionEnd
  const text = content.value
  const selected = text.slice(start, end)
  const replacement = prefix + (selected || 'text') + suffix
  content.value = text.slice(0, start) + replacement + text.slice(end)

  nextTick(() => {
    el.focus()
    el.setSelectionRange(start + prefix.length, start + prefix.length + (selected ? selected.length : 4))
  })
}

function addLinkPrompt() {
  const url = prompt('Enter URL:')
  if (!url) return
  const text = prompt('Link text (optional):') || url
  insertFormat(`[${text}](${url})`)
}

// ── Media Upload Handlers ───────────────────────────────────
async function handleImageUpload(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploadingImage.value = true

  const safeName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_')
  const path = `blog/images/${Date.now()}-${safeName}`
  const { error } = await supabase.storage.from('article-images').upload(path, file)

  if (error) {
    alert(`Image upload failed: ${error.message}`)
    uploadingImage.value = false
    return
  }

  const { data } = supabase.storage.from('article-images').getPublicUrl(path)
  coverImageUrl.value = data.publicUrl
  uploadingImage.value = false
}

async function handleAudioUpload(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploadingAudio.value = true

  const safeName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_')
  const path = `blog/audio/${Date.now()}-${safeName}`
  const { error } = await supabase.storage.from('article-images').upload(path, file)

  if (error) {
    alert(`Audio upload failed: ${error.message}`)
    uploadingAudio.value = false
    return
  }

  const { data } = supabase.storage.from('article-images').getPublicUrl(path)
  audioUrl.value = data.publicUrl
  uploadingAudio.value = false
}

// ── Tags Handlers ───────────────────────────────────────────
function handleTagKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' || e.key === ',') {
    e.preventDefault()
    addTag()
  }
}

function addTag() {
  const clean = tagInput.value.replace(/^[#\s]+|[,\s]+$/g, '').trim()
  if (clean && !tags.value.includes(clean)) {
    tags.value.push(clean)
  }
  tagInput.value = ''
}

function removeTag(tagToRemove: string) {
  tags.value = tags.value.filter((t) => t !== tagToRemove)
}

function addSuggestedTag(tag: string) {
  if (!tags.value.includes(tag)) {
    tags.value.push(tag)
  }
}

// ── Save / Publish ──────────────────────────────────────────
async function savePost() {
  const rawText = content.value.trim()

  if (!rawText && !coverImageUrl.value && !audioUrl.value && !title.value.trim()) {
    alert('Please enter some post content or attach media.')
    return
  }

  saving.value = true
  saveMsg.value = ''

  // PostgreSQL schema requires `title text not null`
  // If user didn't enter a headline, auto-derive one from first words
  let derivedTitle = title.value.trim()
  if (!derivedTitle) {
    const firstLine = rawText.split('\n')[0].replace(/<[^>]+>/g, '').trim()
    derivedTitle = firstLine ? firstLine.slice(0, 80) : `Post ${new Date().toLocaleDateString()}`
  }

  const finalSlug = slug.value.trim() || makeSlug(derivedTitle) || `post-${Date.now().toString(36)}`
  const now = new Date().toISOString()
  const publishTime = published.value
    ? fromDatetimeLocal(publishedAt.value) || now
    : fromDatetimeLocal(publishedAt.value)

  // Derive simple plain-text excerpt for previews/fallback
  const excerpt = rawText.slice(0, 160)

  const payload = {
    title: derivedTitle,
    slug: finalSlug,
    content: content.value,
    excerpt: excerpt || null,
    cover_image_url: coverImageUrl.value || null,
    audio_url: audioUrl.value || null,
    author: author.value.trim() || 'Olimjon Makhmudov',
    tags: tags.value,
    published: published.value,
    published_at: publishTime,
    updated_at: now,
  }

  const res = isEdit.value && postId.value
    ? await supabase.from('blog_posts').update(payload).eq('id', postId.value)
    : await supabase.from('blog_posts').insert(payload)

  if (res.error) {
    alert(`Save failed: ${res.error.message}`)
    saving.value = false
    return
  }

  saving.value = false
  saveMsg.value = 'Saved!'
  setTimeout(() => {
    void router.push('/admin/blog')
  }, 400)
}

// ── Live Preview Formatters ─────────────────────────────────
function formatPreviewContent(text: string): string {
  if (!text) return ''
  // Convert markdown links [text](url)
  let formatted = text.replace(
    /\[([^\]]+)\]\(([^)]+)\)/g,
    '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>'
  )
  // Convert **bold**
  formatted = formatted.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  // Convert *italic*
  formatted = formatted.replace(/\*([^*]+)\*/g, '<em>$1</em>')
  // Convert `code`
  formatted = formatted.replace(/`([^`]+)`/g, '<code>$1</code>')
  // Highlight #hashtags
  formatted = formatted.replace(/(^|\s)(#[a-zA-Z0-9_\u0080-\uffff]+)/g, '$1<span class="preview-hashtag">$2</span>')

  // Wrap paragraphs
  return formatted
    .split(/\n\s*\n/)
    .map((p) => `<p>${p.replace(/\n/g, '<br>')}</p>`)
    .join('')
}
</script>

<template>
  <div class="blog-composer-page">
    <!-- Top Action Bar -->
    <header class="composer-header">
      <div class="header-left">
        <button type="button" class="btn-back" @click="router.push('/admin/blog')">
          <ArrowLeft :size="17" />
          <span>Posts</span>
        </button>
        <div class="header-title-block">
          <span class="eyebrow">{{ isEdit ? 'Edit Post' : 'New Post' }}</span>
          <h1 class="header-title">{{ isEdit ? 'Edit Social Post' : 'Compose Social Post' }}</h1>
        </div>
      </div>

      <div class="header-right">
        <!-- Draft / Published Toggle -->
        <label class="publish-switch-wrap" title="Toggle publication status">
          <input v-model="published" type="checkbox" class="publish-checkbox" />
          <span class="switch-slider"></span>
          <span class="switch-label" :class="{ 'is-published': published }">
            {{ published ? 'Published' : 'Draft' }}
          </span>
        </label>

        <!-- Save Button -->
        <button
          type="button"
          class="btn-save"
          :disabled="saving"
          @click="savePost"
        >
          <Send :size="15" />
          <span>{{ saving ? 'Saving...' : saveMsg || (published ? 'Publish Post' : 'Save Draft') }}</span>
        </button>
      </div>
    </header>

    <!-- Mobile Tab Switcher -->
    <div class="mobile-tab-nav">
      <button
        type="button"
        class="tab-btn"
        :class="{ active: activeTab === 'compose' }"
        @click="activeTab = 'compose'"
      >
        Compose
      </button>
      <button
        type="button"
        class="tab-btn"
        :class="{ active: activeTab === 'preview' }"
        @click="activeTab = 'preview'"
      >
        Live Preview
      </button>
    </div>

    <!-- Main Two-Column Layout -->
    <div class="composer-layout">
      <!-- ── Left Column: Composer Form ──────────────────── -->
      <section
        class="composer-column"
        :class="{ 'mobile-hidden': activeTab === 'preview' }"
      >
        <!-- Headline / Topic (Optional) -->
        <div class="composer-card">
          <label class="field-label" for="post-headline">
            Headline / Topic <span class="label-optional">(Optional)</span>
          </label>
          <input
            id="post-headline"
            v-model="title"
            type="text"
            placeholder="e.g. Milestone update, Quick tip, or Leave blank"
            class="input-headline"
          />
        </div>

        <!-- Main Content Area -->
        <div class="composer-card content-card">
          <div class="content-toolbar">
            <button
              type="button"
              class="tool-btn"
              title="Bold (**text**)"
              @click="insertFormat('**', '**')"
            >
              <Bold :size="15" />
            </button>
            <button
              type="button"
              class="tool-btn"
              title="Italic (*text*)"
              @click="insertFormat('*', '*')"
            >
              <Italic :size="15" />
            </button>
            <button
              type="button"
              class="tool-btn"
              title="Link"
              @click="addLinkPrompt"
            >
              <LinkIcon :size="15" />
            </button>
            <button
              type="button"
              class="tool-btn"
              title="Code snippet (`code`)"
              @click="insertFormat('`', '`')"
            >
              <Code :size="15" />
            </button>
            <button
              type="button"
              class="tool-btn"
              title="List (- item)"
              @click="insertFormat('\n- ')"
            >
              <List :size="15" />
            </button>
            <button
              type="button"
              class="tool-btn"
              title="Quote (> quote)"
              @click="insertFormat('\n> ')"
            >
              <Quote :size="15" />
            </button>

            <div class="toolbar-counters">
              <span>{{ wordCount }} words</span>
              <span>·</span>
              <span>{{ charCount }} chars</span>
            </div>
          </div>

          <textarea
            ref="textareaRef"
            v-model="content"
            rows="8"
            placeholder="What's on your mind? Share an update, insight, or announcement..."
            class="composer-textarea"
          ></textarea>
        </div>

        <!-- Attachments Card (Image + Audio) -->
        <div class="composer-card media-card">
          <h2 class="card-subtitle">Media Attachments</h2>

          <!-- Image Attachment -->
          <div class="media-row">
            <div class="media-slot">
              <span class="media-slot-title">Photo / Image</span>

              <div v-if="coverImageUrl" class="media-preview-box image-preview">
                <img :src="coverImageUrl" alt="Attached preview" />
                <button
                  type="button"
                  class="btn-remove-media"
                  title="Remove image"
                  @click="coverImageUrl = ''"
                >
                  <X :size="15" />
                </button>
              </div>

              <div v-else class="upload-controls">
                <label class="btn-upload-file">
                  <ImageIcon :size="16" />
                  <span>{{ uploadingImage ? 'Uploading...' : 'Upload Image' }}</span>
                  <input
                    type="file"
                    accept="image/*"
                    hidden
                    :disabled="uploadingImage"
                    @change="handleImageUpload"
                  />
                </label>
                <input
                  v-model="coverImageUrl"
                  type="url"
                  placeholder="Or paste image URL"
                  class="input-url"
                />
              </div>
            </div>

            <!-- Voice / Audio Attachment -->
            <div class="media-slot">
              <span class="media-slot-title">Voice / Audio Note</span>

              <div v-if="audioUrl" class="media-preview-box audio-preview">
                <audio :src="audioUrl" controls class="preview-audio-player"></audio>
                <button
                  type="button"
                  class="btn-remove-media"
                  title="Remove audio"
                  @click="audioUrl = ''"
                >
                  <X :size="15" />
                </button>
              </div>

              <div v-else class="upload-controls">
                <label class="btn-upload-file audio-upload-btn">
                  <Mic :size="16" />
                  <span>{{ uploadingAudio ? 'Uploading...' : 'Upload Audio' }}</span>
                  <input
                    type="file"
                    accept="audio/*"
                    hidden
                    :disabled="uploadingAudio"
                    @change="handleAudioUpload"
                  />
                </label>
                <input
                  v-model="audioUrl"
                  type="url"
                  placeholder="Or paste audio URL"
                  class="input-url"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Hashtags / Tags Card -->
        <div class="composer-card tags-card">
          <h2 class="card-subtitle">Hashtags &amp; Topics</h2>

          <div class="tags-input-wrap">
            <Hash :size="16" class="hash-icon" />
            <input
              v-model="tagInput"
              type="text"
              placeholder="Add tag and press Enter or comma..."
              class="input-tag"
              @keydown="handleTagKeydown"
              @blur="addTag"
            />
          </div>

          <!-- Existing Tags -->
          <div v-if="tags.length" class="tag-chips-row">
            <span v-for="tag in tags" :key="tag" class="tag-chip">
              #{{ tag }}
              <button type="button" @click="removeTag(tag)" aria-label="Remove tag">×</button>
            </span>
          </div>

          <!-- Suggestions -->
          <div class="tag-suggestions">
            <span class="suggestion-label">Suggestions:</span>
            <button
              v-for="s in ['engineering', 'typescript', 'vue', 'architecture', 'webdev']"
              :key="s"
              type="button"
              class="suggestion-btn"
              @click="addSuggestedTag(s)"
            >
              + #{{ s }}
            </button>
          </div>
        </div>

        <!-- Details & Publishing Options -->
        <div class="composer-card options-card">
          <h2 class="card-subtitle">Post Details</h2>

          <div class="options-grid">
            <div class="option-field">
              <label for="post-slug">Slug (URL)</label>
              <input
                id="post-slug"
                v-model="slug"
                type="text"
                placeholder="auto-generated-slug"
                class="input-detail"
                @input="onSlugInput"
              />
            </div>

            <div class="option-field">
              <label for="post-publish-date">Publish Date</label>
              <input
                id="post-publish-date"
                v-model="publishedAt"
                type="datetime-local"
                class="input-detail"
              />
            </div>
          </div>
        </div>
      </section>

      <!-- ── Right Column: Live Feed Preview ─────────────── -->
      <aside
        class="preview-column"
        :class="{ 'mobile-hidden': activeTab === 'compose' }"
      >
        <div class="preview-sticky-wrap">
          <div class="preview-header-bar">
            <span class="preview-badge">
              <Sparkles :size="14" />
              Live Feed Preview
            </span>
            <span class="preview-hint">Matches portfolio feed</span>
          </div>

          <!-- The Live Social Post Card Preview -->
          <div class="mock-feed-shell">
            <article class="mock-post-card">
              <!-- Author Header -->
              <header class="mock-header">
                <img src="/portrait.png" alt="Olimjon" class="mock-avatar" />
                <div class="mock-author-info">
                  <div class="mock-name-line">
                    <span class="mock-author-name">{{ author || 'Olimjon Makhmudov' }}</span>
                    <span class="mock-verified">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1.2 14.2l-3.5-3.5 1.41-1.41 2.09 2.09 5.69-5.69 1.41 1.41-7.1 7.1z"/>
                      </svg>
                    </span>
                    <span class="mock-handle">@mkhdov</span>
                    <span class="mock-dot">·</span>
                    <span class="mock-time">Just now</span>
                  </div>
                </div>
              </header>

              <!-- Optional Headline -->
              <h3 v-if="title.trim()" class="mock-headline">
                {{ title }}
              </h3>

              <!-- Post Body Content -->
              <div
                class="mock-body"
                v-html="formatPreviewContent(content) || '<p class=\'placeholder-text\'>Your post text will appear here...</p>'"
              ></div>

              <!-- Media Preview -->
              <div v-if="coverImageUrl" class="mock-media-image">
                <img :src="coverImageUrl" alt="Attached media" />
              </div>

              <!-- Audio Preview -->
              <div v-if="audioUrl" class="mock-media-audio">
                <audio :src="audioUrl" controls class="mock-audio-player"></audio>
              </div>

              <!-- Hashtags -->
              <div v-if="tags.length" class="mock-tags-row">
                <span v-for="tag in tags" :key="tag" class="mock-tag-pill">
                  #{{ tag }}
                </span>
              </div>

              <!-- Mock Social Action Bar -->
              <footer class="mock-footer">
                <div class="mock-reactions">
                  <span class="mock-reaction-btn">👍 1</span>
                  <span class="mock-reaction-btn">❤️</span>
                  <span class="mock-reaction-btn">🔥</span>
                </div>
                <div class="mock-actions">
                  <span class="mock-action-link">💬 Comment</span>
                  <span class="mock-action-link">↗ Share</span>
                </div>
              </footer>
            </article>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600;700&display=swap');

.blog-composer-page {
  display: flex;
  flex-direction: column;
  gap: 20px;
  font-family: 'Inter', system-ui, sans-serif;
  max-width: 1200px;
  margin: 0 auto;
}

/* ── Top Header ─────────────────────────────────────────── */
.composer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 14px;
}

.btn-back {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 8px 12px;
  color: #64748b;
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
}

.btn-back:hover {
  color: #6c63ff;
  border-color: #6c63ff;
}

.eyebrow {
  color: #6c63ff;
  font-size: 0.74rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  display: block;
}

.header-title {
  margin: 2px 0 0;
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.6rem;
  font-weight: 700;
  color: #0f172a;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 14px;
}

/* Switch */
.publish-switch-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  user-select: none;
}

.publish-checkbox {
  display: none;
}

.switch-slider {
  width: 38px;
  height: 22px;
  background: #cbd5e1;
  border-radius: 999px;
  position: relative;
  transition: background 0.2s ease;
}

.switch-slider::after {
  content: '';
  position: absolute;
  top: 3px;
  left: 3px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #ffffff;
  transition: transform 0.2s ease;
}

.publish-checkbox:checked + .switch-slider {
  background: #10b981;
}

.publish-checkbox:checked + .switch-slider::after {
  transform: translateX(16px);
}

.switch-label {
  font-size: 0.88rem;
  font-weight: 600;
  color: #64748b;
}

.switch-label.is-published {
  color: #059669;
}

.btn-save {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: #6c63ff;
  color: #ffffff;
  border: none;
  border-radius: 10px;
  padding: 10px 20px;
  font-size: 0.92rem;
  font-weight: 700;
  cursor: pointer;
  box-shadow: 0 4px 14px rgba(108, 99, 255, 0.28);
  transition: all 0.2s ease;
}

.btn-save:hover {
  background: #5a52d5;
  transform: translateY(-1px);
}

/* ── Mobile Tab Nav ─────────────────────────────────────── */
.mobile-tab-nav {
  display: none;
  gap: 8px;
  background: #f1f5f9;
  padding: 4px;
  border-radius: 10px;
}

.tab-btn {
  flex: 1;
  padding: 8px;
  border: none;
  background: transparent;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
}

.tab-btn.active {
  background: #ffffff;
  color: #0f172a;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.05);
}

/* ── Two-Column Layout ──────────────────────────────────── */
.composer-layout {
  display: grid;
  grid-template-columns: 1.15fr 0.85fr;
  gap: 24px;
  align-items: start;
}

.composer-column {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.composer-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 18px 20px;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.02);
}

.card-subtitle {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 12px;
}

.field-label {
  display: block;
  font-size: 0.85rem;
  font-weight: 700;
  color: #334155;
  margin-bottom: 6px;
}

.label-optional {
  color: #94a3b8;
  font-weight: 400;
}

.input-headline {
  width: 100%;
  padding: 10px 14px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.05rem;
  font-weight: 600;
  outline: none;
  color: #0f172a;
}

.input-headline:focus {
  border-color: #6c63ff;
  box-shadow: 0 0 0 3px rgba(108, 99, 255, 0.1);
}

/* Content Area */
.content-toolbar {
  display: flex;
  align-items: center;
  gap: 6px;
  border-bottom: 1px solid #f1f5f9;
  padding-bottom: 10px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.tool-btn {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: #ffffff;
  color: #475569;
  cursor: pointer;
  transition: all 0.15s ease;
}

.tool-btn:hover {
  background: #f8fafc;
  color: #6c63ff;
  border-color: #6c63ff;
}

.toolbar-counters {
  margin-left: auto;
  display: flex;
  gap: 6px;
  font-size: 0.78rem;
  color: #94a3b8;
  font-weight: 600;
}

.composer-textarea {
  width: 100%;
  border: none;
  outline: none;
  resize: vertical;
  font-family: inherit;
  font-size: 0.98rem;
  line-height: 1.6;
  color: #0f172a;
  min-height: 180px;
}

/* Media Cards */
.media-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.media-slot {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.media-slot-title {
  font-size: 0.82rem;
  font-weight: 700;
  color: #475569;
}

.media-preview-box {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}

.image-preview img {
  width: 100%;
  height: 140px;
  object-fit: cover;
  display: block;
}

.audio-preview {
  padding: 10px;
}

.preview-audio-player {
  width: 100%;
  height: 36px;
}

.btn-remove-media {
  position: absolute;
  top: 8px;
  right: 8px;
  background: rgba(15, 23, 42, 0.7);
  color: #ffffff;
  border: none;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  cursor: pointer;
}

.upload-controls {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.btn-upload-file {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  background: #f8fafc;
  border: 1px dashed #cbd5e1;
  border-radius: 8px;
  padding: 10px;
  color: #475569;
  font-size: 0.84rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
}

.btn-upload-file:hover {
  background: #ffffff;
  border-color: #6c63ff;
  color: #6c63ff;
}

.input-url {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 0.82rem;
  outline: none;
}

.input-url:focus {
  border-color: #6c63ff;
}

/* Tags */
.tags-input-wrap {
  position: relative;
  display: flex;
  align-items: center;
  margin-bottom: 10px;
}

.hash-icon {
  position: absolute;
  left: 10px;
  color: #94a3b8;
}

.input-tag {
  width: 100%;
  padding: 8px 12px 8px 32px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.88rem;
  outline: none;
}

.input-tag:focus {
  border-color: #6c63ff;
}

.tag-chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 12px;
}

.tag-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: rgba(108, 99, 255, 0.08);
  border: 1px solid rgba(108, 99, 255, 0.2);
  color: #6c63ff;
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 0.82rem;
  font-weight: 600;
}

.tag-chip button {
  background: transparent;
  border: none;
  color: #6c63ff;
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
  padding: 0;
}

.tag-suggestions {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  border-top: 1px solid #f1f5f9;
  padding-top: 10px;
}

.suggestion-label {
  font-size: 0.78rem;
  color: #94a3b8;
  font-weight: 600;
}

.suggestion-btn {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 3px 8px;
  font-size: 0.78rem;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
}

.suggestion-btn:hover {
  color: #6c63ff;
  border-color: #6c63ff;
}

/* Options */
.options-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.option-field label {
  display: block;
  font-size: 0.8rem;
  font-weight: 700;
  color: #475569;
  margin-bottom: 4px;
}

.input-detail {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 0.85rem;
  outline: none;
}

/* ── Right Column: Live Feed Preview ─────────────────────── */
.preview-column {
  position: sticky;
  top: 20px;
}

.preview-sticky-wrap {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.preview-header-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.preview-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.82rem;
  font-weight: 700;
  color: #6c63ff;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.preview-hint {
  font-size: 0.76rem;
  color: #94a3b8;
}

/* Mock Post Card */
.mock-feed-shell {
  background: #f8fafc;
  border: 1px dashed #cbd5e1;
  border-radius: 20px;
  padding: 14px;
}

.mock-post-card {
  background: #ffffff;
  border: 1px solid rgba(226, 232, 240, 0.9);
  border-radius: 16px;
  padding: 18px;
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.04);
}

.mock-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.mock-avatar {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  object-fit: cover;
  border: 1.5px solid #e2e8f0;
}

.mock-name-line {
  display: flex;
  align-items: center;
  gap: 5px;
  flex-wrap: wrap;
}

.mock-author-name {
  font-size: 0.92rem;
  font-weight: 700;
  color: #0f172a;
}

.mock-verified {
  color: #6c63ff;
  display: inline-flex;
}

.mock-handle {
  font-size: 0.82rem;
  color: #64748b;
}

.mock-dot {
  color: #cbd5e1;
}

.mock-time {
  font-size: 0.8rem;
  color: #64748b;
}

.mock-headline {
  font-family: 'Space Grotesk', sans-serif;
  font-size: 1.05rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 8px;
}

.mock-body {
  font-size: 0.94rem;
  line-height: 1.6;
  color: #1e293b;
  margin-bottom: 12px;
  word-break: break-word;
}

.mock-body :deep(p) {
  margin: 0 0 8px;
}

.mock-body :deep(p:last-child) {
  margin-bottom: 0;
}

.mock-body :deep(a) {
  color: #6c63ff;
  text-decoration: underline;
}

.mock-body :deep(code) {
  background: #f1f5f9;
  padding: 2px 5px;
  border-radius: 4px;
  font-size: 0.88em;
  color: #6c63ff;
}

.mock-body :deep(.preview-hashtag) {
  color: #6c63ff;
  font-weight: 600;
}

.placeholder-text {
  color: #94a3b8;
  font-style: italic;
}

.mock-media-image {
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  margin-bottom: 12px;
}

.mock-media-image img {
  width: 100%;
  max-height: 260px;
  object-fit: cover;
  display: block;
}

.mock-media-audio {
  margin-bottom: 12px;
}

.mock-audio-player {
  width: 100%;
  height: 38px;
}

.mock-tags-row {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin-bottom: 12px;
}

.mock-tag-pill {
  background: rgba(108, 99, 255, 0.06);
  border: 1px solid rgba(108, 99, 255, 0.15);
  color: #6c63ff;
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 0.76rem;
  font-weight: 600;
}

.mock-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #f1f5f9;
  padding-top: 10px;
  margin-top: 4px;
}

.mock-reactions {
  display: flex;
  gap: 5px;
}

.mock-reaction-btn {
  font-size: 0.78rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  padding: 3px 8px;
  color: #475569;
  font-weight: 600;
}

.mock-actions {
  display: flex;
  gap: 10px;
}

.mock-action-link {
  font-size: 0.8rem;
  font-weight: 600;
  color: #64748b;
}

/* ── Responsive ─────────────────────────────────────────── */
@media (max-width: 900px) {
  .composer-layout {
    grid-template-columns: 1fr;
  }
  .mobile-tab-nav {
    display: flex;
  }
  .mobile-hidden {
    display: none;
  }
  .media-row {
    grid-template-columns: 1fr;
  }
}
</style>
