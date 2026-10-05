<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { EditorContent, useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import TextAlign from '@tiptap/extension-text-align'
import Underline from '@tiptap/extension-underline'
import { supabase } from '../../lib/supabase'

const route = useRoute()
const router = useRouter()

const isEdit = computed(() => Boolean(route.params.id))
const postId = computed(() => route.params.id as string | undefined)

const title = ref('')
const slug = ref('')
const excerpt = ref('')
const author = ref('Olimjon Makhmudov')
const coverImageUrl = ref('')
const tagInput = ref('')
const tags = ref<string[]>([])
const published = ref(false)
const publishedAt = ref('')
const saving = ref(false)
const uploading = ref(false)
const saveMsg = ref('')
const slugTouched = ref(false)

const editor = useEditor({
  extensions: [
    StarterKit,
    Underline,
    Image.configure({ inline: false, allowBase64: false }),
    Link.configure({ openOnClick: false }),
    TextAlign.configure({ types: ['heading', 'paragraph'] }),
    Placeholder.configure({ placeholder: 'Write with headings, links, diagrams, images, and code samples...' }),
  ],
  content: '',
  editorProps: {
    attributes: { class: 'tiptap-editor' },
  },
})

const readMinutes = computed(() => {
  const html = editor.value?.getHTML() ?? ''
  const text = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()
  return Math.max(1, Math.ceil(text.split(/\s+/).filter(Boolean).length / 220))
})

watch(title, (value) => {
  if (!slugTouched.value && !isEdit.value) {
    slug.value = makeSlug(value)
  }
})

onMounted(loadPost)
onBeforeUnmount(() => editor.value?.destroy())

async function loadPost() {
  if (!isEdit.value || !postId.value) return
  const { data, error } = await supabase
    .from('blog_posts')
    .select('*')
    .eq('id', postId.value)
    .single()

  if (error) {
    alert(`Unable to load post: ${error.message}`)
    await router.push('/admin/blog')
    return
  }

  title.value = data.title ?? ''
  slug.value = data.slug ?? ''
  excerpt.value = data.excerpt ?? ''
  author.value = data.author ?? 'Olimjon Makhmudov'
  coverImageUrl.value = data.cover_image_url ?? ''
  tags.value = Array.isArray(data.tags) ? data.tags : []
  published.value = Boolean(data.published)
  publishedAt.value = toDatetimeLocal(data.published_at)
  editor.value?.commands.setContent(data.content ?? '')
  slugTouched.value = Boolean(data.slug)
}

async function save() {
  if (!title.value.trim()) {
    alert('Please add a title.')
    return
  }

  saving.value = true
  saveMsg.value = ''

  const now = new Date().toISOString()
  const publishDate = published.value
    ? fromDatetimeLocal(publishedAt.value) || now
    : fromDatetimeLocal(publishedAt.value)

  const payload = {
    title: title.value.trim(),
    slug: slug.value.trim() || makeSlug(title.value),
    excerpt: excerpt.value.trim() || null,
    content: editor.value?.getHTML() ?? '',
    cover_image_url: coverImageUrl.value || null,
    author: author.value.trim() || 'Olimjon Makhmudov',
    tags: tags.value,
    published: published.value,
    published_at: publishDate,
    updated_at: now,
    read_minutes: readMinutes.value,
  }

  const response = isEdit.value && postId.value
    ? await supabase.from('blog_posts').update(payload).eq('id', postId.value)
    : await supabase.from('blog_posts').insert(payload)

  if (response.error) {
    alert(`Unable to save post: ${response.error.message}`)
    saving.value = false
    return
  }

  saving.value = false
  saveMsg.value = 'Saved'
  window.setTimeout(() => {
    void router.push('/admin/blog')
  }, 650)
}

async function uploadImage(event: Event, mode: 'cover' | 'inline') {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploading.value = true
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]+/g, '-')
  const path = `blog/${mode}/${Date.now()}-${safeName}`
  const { error } = await supabase.storage.from('article-images').upload(path, file)

  if (error) {
    alert(`Upload failed: ${error.message}`)
    uploading.value = false
    return
  }

  const { data } = supabase.storage.from('article-images').getPublicUrl(path)
  if (mode === 'cover') {
    coverImageUrl.value = data.publicUrl
  } else {
    editor.value?.chain().focus().setImage({ src: data.publicUrl }).run()
  }
  uploading.value = false
}

function addTag() {
  const value = tagInput.value.trim()
  if (value && !tags.value.includes(value)) tags.value.push(value)
  tagInput.value = ''
}

function removeTag(tag: string) {
  tags.value = tags.value.filter((item) => item !== tag)
}

function handleTagKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' || event.key === ',') {
    event.preventDefault()
    addTag()
  }
}

function setLink() {
  const previousUrl = editor.value?.getAttributes('link').href as string | undefined
  const url = prompt('Enter URL', previousUrl ?? 'https://')
  if (!url || !editor.value) return
  editor.value.chain().focus().setLink({ href: url }).run()
}

function makeSlug(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
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
</script>

<template>
  <div class="blog-editor">
    <header class="topbar">
      <button type="button" class="ghost-btn" @click="router.push('/admin/blog')">Back</button>
      <div>
        <span>Blog editor</span>
        <h1>{{ isEdit ? 'Edit post' : 'New post' }}</h1>
      </div>
      <div class="top-actions">
        <label class="publish-toggle">
          <span>{{ published ? 'Published' : 'Draft' }}</span>
          <input v-model="published" type="checkbox" />
        </label>
        <button type="button" class="save-btn" :disabled="saving" @click="save">
          {{ saving ? 'Saving...' : saveMsg || 'Save' }}
        </button>
      </div>
    </header>

    <div class="editor-grid">
      <main class="editor-main">
        <input v-model="title" class="title-input" type="text" placeholder="Post title" />
        <textarea v-model="excerpt" class="excerpt-input" rows="3" placeholder="Short summary shown on blog cards and article header."></textarea>

        <div v-if="editor" class="toolbar">
          <button type="button" :class="{ active: editor.isActive('bold') }" @click="editor.chain().focus().toggleBold().run()">B</button>
          <button type="button" :class="{ active: editor.isActive('italic') }" @click="editor.chain().focus().toggleItalic().run()">I</button>
          <button type="button" :class="{ active: editor.isActive('underline') }" @click="editor.chain().focus().toggleUnderline().run()">U</button>
          <span></span>
          <button type="button" :class="{ active: editor.isActive('heading', { level: 2 }) }" @click="editor.chain().focus().toggleHeading({ level: 2 }).run()">H2</button>
          <button type="button" :class="{ active: editor.isActive('heading', { level: 3 }) }" @click="editor.chain().focus().toggleHeading({ level: 3 }).run()">H3</button>
          <button type="button" :class="{ active: editor.isActive('bulletList') }" @click="editor.chain().focus().toggleBulletList().run()">List</button>
          <button type="button" :class="{ active: editor.isActive('orderedList') }" @click="editor.chain().focus().toggleOrderedList().run()">1. List</button>
          <button type="button" :class="{ active: editor.isActive('blockquote') }" @click="editor.chain().focus().toggleBlockquote().run()">Quote</button>
          <button type="button" :class="{ active: editor.isActive('codeBlock') }" @click="editor.chain().focus().toggleCodeBlock().run()">Code block</button>
          <button type="button" :class="{ active: editor.isActive('code') }" @click="editor.chain().focus().toggleCode().run()">Code</button>
          <span></span>
          <button type="button" @click="setLink">Link</button>
          <label class="upload-inline">
            Image
            <input type="file" accept="image/*" hidden @change="uploadImage($event, 'inline')" />
          </label>
          <button type="button" @click="editor.chain().focus().undo().run()">Undo</button>
          <button type="button" @click="editor.chain().focus().redo().run()">Redo</button>
        </div>

        <EditorContent :editor="editor" class="editor-content" />
      </main>

      <aside class="editor-side">
        <section class="side-card">
          <h2>Cover image</h2>
          <div v-if="coverImageUrl" class="cover-preview">
            <img :src="coverImageUrl" alt="Cover preview" />
            <button type="button" @click="coverImageUrl = ''">Remove</button>
          </div>
          <label v-else class="upload-cover">
            {{ uploading ? 'Uploading...' : 'Upload cover' }}
            <input type="file" accept="image/*" hidden @change="uploadImage($event, 'cover')" />
          </label>
        </section>

        <section class="side-card">
          <h2>Details</h2>
          <label>
            Author
            <input v-model="author" type="text" />
          </label>
          <label>
            Slug
            <input v-model="slug" type="text" @input="onSlugInput" />
          </label>
          <label>
            Publish date
            <input v-model="publishedAt" type="datetime-local" />
          </label>
          <p>{{ readMinutes }} min read</p>
        </section>

        <section class="side-card">
          <h2>Tags</h2>
          <div class="tags">
            <span v-for="tag in tags" :key="tag">
              {{ tag }}
              <button type="button" @click="removeTag(tag)">x</button>
            </span>
          </div>
          <input
            v-model="tagInput"
            type="text"
            placeholder="Add tag"
            @keydown="handleTagKeydown"
            @blur="addTag"
          />
        </section>

        <section class="side-card">
          <h2>Checklist</h2>
          <ul>
            <li :class="{ done: Boolean(coverImageUrl) }">Cover image</li>
            <li :class="{ done: Boolean(author.trim()) }">Author</li>
            <li :class="{ done: tags.length > 0 }">Tags</li>
            <li :class="{ done: Boolean(excerpt.trim()) }">Excerpt</li>
            <li :class="{ done: readMinutes > 0 }">Readable content</li>
          </ul>
        </section>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.blog-editor {
  min-height: 100%;
  font-family: 'Inter', system-ui, sans-serif;
  color: #0f172a;
}

.topbar {
  position: sticky;
  top: -32px;
  z-index: 5;
  display: flex;
  align-items: center;
  gap: 16px;
  margin: -32px -28px 24px;
  padding: 18px 28px;
  background: rgba(255, 255, 255, 0.94);
  border-bottom: 1px solid #e2e8f0;
  backdrop-filter: blur(12px);
}

.topbar div:nth-child(2) {
  flex: 1;
}

.topbar span {
  color: #6c63ff;
  font-size: 0.72rem;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.topbar h1 {
  margin: 2px 0 0;
  font-size: 1.25rem;
}

.top-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.ghost-btn,
.save-btn,
.toolbar button,
.upload-inline,
.upload-cover,
.cover-preview button {
  border: 1px solid rgba(108, 99, 255, 0.22);
  border-radius: 8px;
  font: inherit;
  font-weight: 800;
  cursor: pointer;
}

.ghost-btn {
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.06);
  padding: 9px 12px;
}

.save-btn {
  min-width: 96px;
  color: #ffffff;
  background: #6c63ff;
  padding: 10px 16px;
}

.publish-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #64748b;
  font-weight: 800;
}

.editor-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 310px;
  gap: 22px;
  align-items: start;
}

.editor-main,
.side-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.editor-main {
  padding: 24px;
}

.title-input,
.excerpt-input,
.side-card input {
  width: 100%;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 12px 14px;
  color: #0f172a;
  font: inherit;
}

.title-input {
  border: 0;
  padding: 0;
  margin-bottom: 16px;
  font-size: clamp(2rem, 5vw, 3.4rem);
  font-weight: 800;
  outline: 0;
}

.excerpt-input {
  resize: vertical;
  margin-bottom: 16px;
}

.toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 14px;
  padding: 10px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.toolbar span {
  width: 1px;
  background: #e2e8f0;
}

.toolbar button,
.upload-inline {
  color: #475569;
  background: #ffffff;
  padding: 7px 10px;
  font-size: 0.83rem;
}

.toolbar button.active {
  color: #ffffff;
  background: #6c63ff;
}

.editor-content {
  min-height: 560px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 22px;
}

:deep(.tiptap-editor) {
  min-height: 520px;
  outline: 0;
  color: #1e293b;
  font-size: 1rem;
  line-height: 1.8;
}

:deep(.tiptap-editor h2) { font-size: 1.8rem; margin: 1.7rem 0 0.8rem; }
:deep(.tiptap-editor h3) { font-size: 1.35rem; margin: 1.4rem 0 0.7rem; }
:deep(.tiptap-editor p) { margin: 0 0 1rem; }
:deep(.tiptap-editor blockquote) {
  margin: 1.2rem 0;
  padding-left: 1rem;
  color: #64748b;
  border-left: 3px solid #6c63ff;
}
:deep(.tiptap-editor pre) {
  overflow-x: auto;
  border-radius: 8px;
  background: #0f172a;
  color: #e2e8f0;
  padding: 1rem;
}
:deep(.tiptap-editor code) {
  border-radius: 5px;
  background: #f1f5f9;
  color: #6c63ff;
  padding: 2px 6px;
}
:deep(.tiptap-editor pre code) {
  background: transparent;
  color: inherit;
  padding: 0;
}
:deep(.tiptap-editor img) {
  max-width: 100%;
  border-radius: 8px;
}
:deep(.tiptap-editor a) {
  color: #6c63ff;
  text-decoration: underline;
}
:deep(.tiptap-editor p.is-editor-empty:first-child::before) {
  content: attr(data-placeholder);
  float: left;
  height: 0;
  color: #94a3b8;
  pointer-events: none;
}

.editor-side {
  display: grid;
  gap: 14px;
}

.side-card {
  display: grid;
  gap: 12px;
  padding: 16px;
}

.side-card h2 {
  margin: 0;
  color: #475569;
  font-size: 0.8rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.side-card label {
  display: grid;
  gap: 6px;
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 800;
}

.side-card p {
  margin: 0;
  color: #64748b;
  font-size: 0.86rem;
  font-weight: 700;
}

.cover-preview {
  display: grid;
  gap: 10px;
}

.cover-preview img {
  width: 100%;
  max-height: 170px;
  object-fit: cover;
  border-radius: 8px;
}

.cover-preview button {
  color: #ef4444;
  background: #ffffff;
  padding: 9px;
}

.upload-cover {
  display: grid;
  place-items: center;
  min-height: 130px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.04);
  border-style: dashed;
}

.tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tags span {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.08);
  border-radius: 999px;
  padding: 5px 9px;
  font-size: 0.78rem;
  font-weight: 800;
}

.tags button {
  border: 0;
  color: inherit;
  background: transparent;
  cursor: pointer;
  font: inherit;
}

.side-card ul {
  display: grid;
  gap: 8px;
  margin: 0;
  padding-left: 18px;
  color: #94a3b8;
  font-size: 0.86rem;
  font-weight: 700;
}

.side-card li.done {
  color: #059669;
}

@media (max-width: 980px) {
  .editor-grid {
    grid-template-columns: 1fr;
  }

  .topbar {
    margin: -24px -16px 20px;
    padding: 14px 16px;
    top: -24px;
  }
}

@media (max-width: 640px) {
  .topbar,
  .top-actions {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
