<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../lib/supabase.ts'
import { useEditor, EditorContent } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Underline from '@tiptap/extension-underline'
import TextAlign from '@tiptap/extension-text-align'
import Placeholder from '@tiptap/extension-placeholder'

const router = useRouter()
const route  = useRoute()

const isEdit     = !!route.params.id
const articleId  = route.params.id as string | undefined

const title          = ref('')
const coverImageUrl  = ref('')
const published      = ref(false)
const saving         = ref(false)
const uploadingImage = ref(false)
const saveMsg        = ref('')

// ── Tiptap editor ────────────────────────────────────────────
const editor = useEditor({
  extensions: [
    StarterKit,
    Underline,
    Image.configure({ inline: false, allowBase64: false }),
    Link.configure({ openOnClick: false }),
    TextAlign.configure({ types: ['heading', 'paragraph'] }),
    Placeholder.configure({ placeholder: 'Start writing your article...' }),
  ],
  content: '',
  editorProps: {
    attributes: { class: 'tiptap-editor' }
  }
})

// ── Load existing article if editing ────────────────────────
onMounted(async () => {
  if (isEdit && articleId) {
    const { data } = await supabase
        .from('articles')
        .select('*')
        .eq('id', articleId)
        .single()
    if (data) {
      title.value         = data.title
      coverImageUrl.value = data.cover_image_url ?? ''
      published.value     = data.published
      editor.value?.commands.setContent(data.content ?? '')
    }
  }
})

onBeforeUnmount(() => editor.value?.destroy())

// ── Upload cover image ───────────────────────────────────────
async function uploadCover(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploadingImage.value = true
  const path = `covers/${Date.now()}-${file.name}`
  const { error } = await supabase.storage.from('article-images').upload(path, file)
  if (!error) {
    const { data } = supabase.storage.from('article-images').getPublicUrl(path)
    coverImageUrl.value = data.publicUrl
  }
  uploadingImage.value = false
}

// ── Upload inline image (into editor) ───────────────────────
async function uploadInlineImage(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file || !editor.value) return
  uploadingImage.value = true
  const path = `inline/${Date.now()}-${file.name}`
  const { error } = await supabase.storage.from('article-images').upload(path, file)
  if (!error) {
    const { data } = supabase.storage.from('article-images').getPublicUrl(path)
    editor.value.chain().focus().setImage({ src: data.publicUrl }).run()
  }
  uploadingImage.value = false
}

// ── Save ─────────────────────────────────────────────────────
async function save() {
  if (!title.value.trim()) { alert('Please add a title'); return }
  saving.value = true
  saveMsg.value = ''

  const payload = {
    title:           title.value.trim(),
    content:         editor.value?.getHTML() ?? '',
    cover_image_url: coverImageUrl.value || null,
    published:       published.value,
  }

  if (isEdit && articleId) {
    await supabase.from('articles').update(payload).eq('id', articleId)
  } else {
    await supabase.from('articles').insert(payload)
  }

  saving.value = false
  saveMsg.value = 'Saved!'
  setTimeout(() => {
    saveMsg.value = ''
    router.push('/admin/articles')
  }, 800)
}

// ── Toolbar helpers ──────────────────────────────────────────
function setLink() {
  const url = prompt('Enter URL')
  if (!url || !editor.value) return
  editor.value.chain().focus().setLink({ href: url }).run()
}
</script>

<template>
  <div class="editor-page">

    <!-- Top Bar -->
    <div class="top-bar">
      <button class="btn-back" @click="router.push('/admin/articles')">← Back</button>
      <h1 class="editor-heading">{{ isEdit ? 'Edit Article' : 'New Article' }}</h1>
      <div class="top-actions">
        <label class="toggle-label">
          <span>{{ published ? 'Published' : 'Draft' }}</span>
          <div class="toggle" :class="{ on: published }" @click="published = !published">
            <div class="toggle-thumb"></div>
          </div>
        </label>
        <button class="btn-save" :disabled="saving" @click="save">
          <span v-if="saving">Saving...</span>
          <span v-else-if="saveMsg" class="save-ok">{{ saveMsg }}</span>
          <span v-else>Save</span>
        </button>
      </div>
    </div>

    <div class="editor-layout">

      <!-- Main editor area -->
      <div class="editor-main">

        <!-- Title -->
        <input
            v-model="title"
            class="title-input"
            placeholder="Article title..."
            type="text"
        />

        <!-- Toolbar -->
        <div v-if="editor" class="toolbar">
          <button class="tb-btn" :class="{ active: editor.isActive('bold') }"
                  @click="editor.chain().focus().toggleBold().run()" title="Bold">
            <b>B</b>
          </button>
          <button class="tb-btn" :class="{ active: editor.isActive('italic') }"
                  @click="editor.chain().focus().toggleItalic().run()" title="Italic">
            <i>I</i>
          </button>
          <button class="tb-btn" :class="{ active: editor.isActive('underline') }"
                  @click="editor.chain().focus().toggleUnderline().run()" title="Underline">
            <u>U</u>
          </button>
          <div class="tb-divider"></div>
          <button class="tb-btn" :class="{ active: editor.isActive('heading', { level: 1 }) }"
                  @click="editor.chain().focus().toggleHeading({ level: 1 }).run()">H1</button>
          <button class="tb-btn" :class="{ active: editor.isActive('heading', { level: 2 }) }"
                  @click="editor.chain().focus().toggleHeading({ level: 2 }).run()">H2</button>
          <button class="tb-btn" :class="{ active: editor.isActive('heading', { level: 3 }) }"
                  @click="editor.chain().focus().toggleHeading({ level: 3 }).run()">H3</button>
          <div class="tb-divider"></div>
          <button class="tb-btn" :class="{ active: editor.isActive({ textAlign: 'left' }) }"
                  @click="editor.chain().focus().setTextAlign('left').run()">⬅</button>
          <button class="tb-btn" :class="{ active: editor.isActive({ textAlign: 'center' }) }"
                  @click="editor.chain().focus().setTextAlign('center').run()">↔</button>
          <button class="tb-btn" :class="{ active: editor.isActive({ textAlign: 'right' }) }"
                  @click="editor.chain().focus().setTextAlign('right').run()">➡</button>
          <div class="tb-divider"></div>
          <button class="tb-btn" :class="{ active: editor.isActive('bulletList') }"
                  @click="editor.chain().focus().toggleBulletList().run()">• List</button>
          <button class="tb-btn" :class="{ active: editor.isActive('orderedList') }"
                  @click="editor.chain().focus().toggleOrderedList().run()">1. List</button>
          <button class="tb-btn" :class="{ active: editor.isActive('blockquote') }"
                  @click="editor.chain().focus().toggleBlockquote().run()">" Quote</button>
          <button class="tb-btn" :class="{ active: editor.isActive('code') }"
                  @click="editor.chain().focus().toggleCode().run()">&lt;/&gt;</button>
          <div class="tb-divider"></div>
          <button class="tb-btn" @click="setLink" :class="{ active: editor.isActive('link') }">🔗</button>
          <label class="tb-btn tb-img" title="Insert image">
            🖼
            <input type="file" accept="image/*" @change="uploadInlineImage" hidden />
          </label>
          <div class="tb-divider"></div>
          <button class="tb-btn" @click="editor.chain().focus().undo().run()">↩</button>
          <button class="tb-btn" @click="editor.chain().focus().redo().run()">↪</button>
        </div>

        <!-- Tiptap content area -->
        <EditorContent :editor="editor" class="editor-content" />
      </div>

      <!-- Sidebar -->
      <div class="editor-sidebar">

        <!-- Cover image -->
        <div class="sidebar-card">
          <h3 class="sidebar-title">Cover Image</h3>
          <div class="cover-preview" v-if="coverImageUrl">
            <img :src="coverImageUrl" alt="Cover" />
            <button class="remove-cover" @click="coverImageUrl = ''">✕ Remove</button>
          </div>
          <label class="upload-btn" v-else>
            <span v-if="uploadingImage">Uploading...</span>
            <span v-else>＋ Upload Cover</span>
            <input type="file" accept="image/*" @change="uploadCover" hidden />
          </label>
        </div>

        <!-- Status -->
        <div class="sidebar-card">
          <h3 class="sidebar-title">Status</h3>
          <div class="status-row">
            <span class="status-dot" :class="published ? 'green' : 'gray'"></span>
            <span class="status-text">{{ published ? 'Published — visible to readers' : 'Draft — only you can see it' }}</span>
          </div>
        </div>

      </div>
    </div>

    <!-- Uploading overlay -->
    <div v-if="uploadingImage" class="upload-overlay">
      <div class="spinner"></div>
      <p>Uploading image...</p>
    </div>

  </div>
</template>

<style scoped>
.editor-page {
  min-height: 100vh;
  background: #fff;
  font-family: 'Inter', system-ui, sans-serif;
  position: relative;
}

/* Top Bar */
.top-bar {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem 2rem;
  border-bottom: 1px solid #e2e8f0;
  background: #fff;
  position: sticky;
  top: 0;
  z-index: 10;
}
.btn-back {
  background: none;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 0.4rem 0.9rem;
  font-size: 0.85rem;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
  white-space: nowrap;
}
.btn-back:hover { border-color: #6366f1; color: #6366f1; }

.editor-heading {
  font-size: 1.1rem;
  font-weight: 600;
  color: #0f172a;
  margin: 0;
  flex: 1;
}

.top-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

/* Toggle */
.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.82rem;
  color: #64748b;
  cursor: pointer;
  user-select: none;
}
.toggle {
  width: 40px; height: 22px;
  background: #e2e8f0;
  border-radius: 999px;
  position: relative;
  transition: background 0.2s;
}
.toggle.on { background: #6366f1; }
.toggle-thumb {
  position: absolute;
  top: 3px; left: 3px;
  width: 16px; height: 16px;
  background: #fff;
  border-radius: 50%;
  transition: left 0.2s;
  box-shadow: 0 1px 4px rgba(0,0,0,0.15);
}
.toggle.on .toggle-thumb { left: 21px; }

.btn-save {
  background: #6366f1;
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 0.55rem 1.3rem;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.18s;
  min-width: 80px;
}
.btn-save:hover:not(:disabled) { background: #4f46e5; }
.btn-save:disabled { opacity: 0.6; cursor: not-allowed; }
.save-ok { color: #bbf7d0; }

/* Layout */
.editor-layout {
  display: flex;
  gap: 0;
  align-items: flex-start;
}

/* Main */
.editor-main {
  flex: 1;
  padding: 2rem 2.5rem;
  min-width: 0;
}

.title-input {
  width: 100%;
  font-size: 2rem;
  font-weight: 700;
  color: #0f172a;
  border: none;
  outline: none;
  margin-bottom: 1.5rem;
  placeholder-color: #cbd5e1;
  font-family: inherit;
}
.title-input::placeholder { color: #cbd5e1; }

/* Toolbar */
.toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.2rem;
  padding: 0.6rem 0.75rem;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  margin-bottom: 1rem;
}
.tb-btn {
  padding: 0.3rem 0.55rem;
  border-radius: 6px;
  border: none;
  background: transparent;
  color: #475569;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.15s;
  font-family: inherit;
}
.tb-btn:hover { background: #e2e8f0; color: #0f172a; }
.tb-btn.active { background: #6366f1; color: #fff; }
.tb-img { cursor: pointer; }
.tb-divider {
  width: 1px;
  height: 20px;
  background: #e2e8f0;
  margin: 0 0.25rem;
}

/* Editor content area */
.editor-content {
  min-height: 500px;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.5rem;
}

/* Tiptap styles */
:deep(.tiptap-editor) {
  outline: none;
  min-height: 460px;
  font-size: 1rem;
  line-height: 1.75;
  color: #1e293b;
}
:deep(.tiptap-editor h1) { font-size: 2rem; font-weight: 700; margin: 1.5rem 0 0.75rem; color: #0f172a; }
:deep(.tiptap-editor h2) { font-size: 1.5rem; font-weight: 600; margin: 1.25rem 0 0.6rem; color: #0f172a; }
:deep(.tiptap-editor h3) { font-size: 1.2rem; font-weight: 600; margin: 1rem 0 0.5rem; color: #0f172a; }
:deep(.tiptap-editor p)  { margin: 0 0 1rem; }
:deep(.tiptap-editor ul), :deep(.tiptap-editor ol) { padding-left: 1.5rem; margin: 0 0 1rem; }
:deep(.tiptap-editor li) { margin-bottom: 0.25rem; }
:deep(.tiptap-editor blockquote) {
  border-left: 3px solid #6366f1;
  padding-left: 1rem;
  color: #64748b;
  font-style: italic;
  margin: 1rem 0;
}
:deep(.tiptap-editor code) {
  background: #f1f5f9;
  padding: 0.15rem 0.4rem;
  border-radius: 4px;
  font-size: 0.9em;
  font-family: monospace;
  color: #6366f1;
}
:deep(.tiptap-editor img) {
  max-width: 100%;
  border-radius: 8px;
  margin: 1rem 0;
}
:deep(.tiptap-editor a) { color: #6366f1; text-decoration: underline; }
:deep(.tiptap-editor p.is-editor-empty:first-child::before) {
  content: attr(data-placeholder);
  color: #cbd5e1;
  pointer-events: none;
  float: left;
  height: 0;
}

/* Sidebar */
.editor-sidebar {
  width: 260px;
  flex-shrink: 0;
  padding: 2rem 1.5rem 2rem 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  border-left: 1px solid #e2e8f0;
  margin-left: 1rem;
  padding-left: 1.5rem;
}
.sidebar-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1rem;
}
.sidebar-title {
  font-size: 0.8rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #94a3b8;
  margin: 0 0 0.75rem;
}

.cover-preview {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.cover-preview img {
  width: 100%;
  border-radius: 8px;
  object-fit: cover;
  max-height: 140px;
}
.remove-cover {
  font-size: 0.78rem;
  color: #ef4444;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
  text-align: left;
}

.upload-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  padding: 0.75rem;
  border: 1.5px dashed #cbd5e1;
  border-radius: 8px;
  font-size: 0.85rem;
  color: #64748b;
  cursor: pointer;
  transition: all 0.15s;
}
.upload-btn:hover { border-color: #6366f1; color: #6366f1; background: rgba(99,102,241,0.04); }

.status-row {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
}
.status-dot {
  width: 8px; height: 8px;
  border-radius: 50%;
  margin-top: 0.3rem;
  flex-shrink: 0;
}
.status-dot.green { background: #10b981; }
.status-dot.gray  { background: #94a3b8; }
.status-text { font-size: 0.82rem; color: #64748b; line-height: 1.5; }

/* Upload overlay */
.upload-overlay {
  position: fixed;
  inset: 0;
  background: rgba(255,255,255,0.8);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  z-index: 100;
  color: #64748b;
  font-size: 0.9rem;
}
.spinner {
  width: 36px; height: 36px;
  border: 3px solid #e2e8f0;
  border-top-color: #6366f1;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

@media (max-width: 768px) {
  .editor-layout { flex-direction: column; }
  .editor-sidebar { width: 100%; border-left: none; border-top: 1px solid #e2e8f0; margin: 0; padding: 1.25rem; }
  .editor-main { padding: 1.25rem; }
  .top-bar { padding: 0.75rem 1rem; }
}
</style>