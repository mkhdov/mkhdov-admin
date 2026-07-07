<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue'
import {
  CheckCircle2,
  Clock3,
  Inbox,
  Mail,
  MessageSquare,
  RotateCcw,
  Search,
  Send,
  Trash2,
  UserRound,
} from 'lucide-vue-next'
import AdminPageShell from './AdminPageShell.vue'
import { supabase } from '../../lib/supabase'

interface Conversation {
  id: string
  visitor_id: string
  guest_name: string | null
  guest_email: string | null
  status: string | null
  unread_count_admin: number | null
  unread_count_guest: number | null
  updated_at: string
  created_at: string
}

interface Message {
  id: string
  conversation_id: string
  sender_type: 'guest' | 'admin'
  content: string
  created_at: string
}

type StatusFilter = 'all' | 'open' | 'resolved'

const conversations = ref<Conversation[]>([])
const activeConversation = ref<Conversation | null>(null)
const messages = ref<Message[]>([])
const newMessage = ref('')
const searchQuery = ref('')
const statusFilter = ref<StatusFilter>('all')
const loadingConversations = ref(true)
const loadingMessages = ref(false)
const sending = ref(false)
const deletingConversationId = ref<string | null>(null)
const messagesContainer = ref<HTMLElement | null>(null)

let convSubscription: ReturnType<typeof supabase.channel> | null = null
let msgSubscription: ReturnType<typeof supabase.channel> | null = null

const totalUnread = computed(() =>
  conversations.value.reduce((total, conv) => total + (conv.unread_count_admin ?? 0), 0)
)

const openCount = computed(() =>
  conversations.value.filter((conv) => (conv.status ?? 'open') !== 'resolved').length
)

const filteredConversations = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()

  return conversations.value.filter((conv) => {
    const normalizedStatus = conv.status ?? 'open'
    const matchesStatus = statusFilter.value === 'all' || normalizedStatus === statusFilter.value
    const haystack = [
      conv.guest_name,
      conv.guest_email,
      conv.visitor_id,
      conv.status,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase()

    return matchesStatus && (!query || haystack.includes(query))
  })
})

function displayName(conv: Conversation) {
  return conv.guest_name?.trim() || conv.guest_email?.trim() || 'Guest visitor'
}

function initials(conv: Conversation) {
  return displayName(conv)
    .split(/\s+/)
    .slice(0, 2)
    .map((word) => word[0])
    .join('')
    .toUpperCase()
    .slice(0, 2)
}

function shortVisitorId(conv: Conversation) {
  return conv.visitor_id ? conv.visitor_id.substring(0, 6) : conv.id.substring(0, 6)
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString([], {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatTime(dateStr: string) {
  return new Date(dateStr).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  })
}

function sortConversations() {
  conversations.value = [...conversations.value].sort(
    (a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
  )
}

function upsertConversation(conv: Conversation) {
  const index = conversations.value.findIndex((item) => item.id === conv.id)

  if (index >= 0) {
    conversations.value[index] = conv
  } else {
    conversations.value.unshift(conv)
  }

  if (activeConversation.value?.id === conv.id) {
    activeConversation.value = conv
  }

  sortConversations()
}

function removeConversationLocally(conversationId: string) {
  conversations.value = conversations.value.filter((conv) => conv.id !== conversationId)

  if (activeConversation.value?.id === conversationId) {
    activeConversation.value = null
    messages.value = []
  }
}

async function loadConversations() {
  loadingConversations.value = true

  const { data, error } = await supabase
    .from('conversations')
    .select('*')
    .order('updated_at', { ascending: false })

  if (error) {
    console.error('Error fetching conversations:', error)
  } else {
    conversations.value = (data ?? []) as Conversation[]
  }

  loadingConversations.value = false
}

async function refreshConversation(conversationId: string) {
  const { data, error } = await supabase
    .from('conversations')
    .select('*')
    .eq('id', conversationId)
    .single()

  if (error) {
    console.error('Error refreshing conversation:', error)
    return
  }

  if (data) {
    upsertConversation(data as Conversation)
  }
}

async function selectConversation(conv: Conversation) {
  activeConversation.value = conv
  loadingMessages.value = true
  messages.value = []

  if ((conv.unread_count_admin ?? 0) > 0) {
    await markAsRead(conv.id)
  }

  await loadMessages(conv.id)
  loadingMessages.value = false
}

async function markAsRead(conversationId: string) {
  const { error } = await supabase
    .from('conversations')
    .update({ unread_count_admin: 0 })
    .eq('id', conversationId)

  if (error) {
    console.error('Error marking conversation as read:', error)
    return
  }

  const index = conversations.value.findIndex((conv) => conv.id === conversationId)
  if (index !== -1) {
    conversations.value[index] = {
      ...conversations.value[index],
      unread_count_admin: 0,
    }
  }

  if (activeConversation.value?.id === conversationId) {
    activeConversation.value = {
      ...activeConversation.value,
      unread_count_admin: 0,
    }
  }
}

async function loadMessages(conversationId: string) {
  const { data, error } = await supabase
    .from('messages')
    .select('*')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })

  if (error) {
    console.error('Error fetching messages:', error)
  } else {
    messages.value = (data ?? []) as Message[]
    scrollToBottom()
  }
}

function subscribeToConversations() {
  convSubscription = supabase
    .channel('admin_conversations')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'conversations',
      },
      (payload) => {
        if (payload.eventType === 'DELETE') {
          removeConversationLocally((payload.old as Conversation).id)
          return
        }

        const conv = payload.new as Conversation
        upsertConversation(conv)

        if (activeConversation.value?.id === conv.id && (conv.unread_count_admin ?? 0) > 0) {
          void markAsRead(conv.id)
        }
      }
    )
    .subscribe()
}

function subscribeToMessages() {
  msgSubscription = supabase
    .channel('admin_messages')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
      },
      async (payload) => {
        const incomingMessage = payload.new as Message

        if (activeConversation.value?.id === incomingMessage.conversation_id) {
          if (!messages.value.some((message) => message.id === incomingMessage.id)) {
            messages.value.push(incomingMessage)
            scrollToBottom()
          }

          if (incomingMessage.sender_type === 'guest') {
            await markAsRead(incomingMessage.conversation_id)
          }
        }

        await refreshConversation(incomingMessage.conversation_id)
      }
    )
    .subscribe()
}

async function sendMessage() {
  if (!activeConversation.value) return

  const content = newMessage.value.trim()
  if (!content) return

  sending.value = true
  newMessage.value = ''

  const { data, error } = await supabase
    .from('messages')
    .insert([
      {
        conversation_id: activeConversation.value.id,
        sender_type: 'admin',
        content,
      },
    ])
    .select('*')
    .single()

  if (error) {
    console.error('Error sending message:', error)
    newMessage.value = content
  } else if (data && !messages.value.some((message) => message.id === data.id)) {
    messages.value.push(data as Message)
    scrollToBottom()
    await refreshConversation(activeConversation.value.id)
  }

  sending.value = false
}

async function setConversationStatus(status: 'open' | 'resolved') {
  if (!activeConversation.value) return

  const { data, error } = await supabase
    .from('conversations')
    .update({ status })
    .eq('id', activeConversation.value.id)
    .select('*')
    .single()

  if (error) {
    console.error('Error updating conversation status:', error)
    return
  }

  if (data) {
    upsertConversation(data as Conversation)
  }
}

async function deleteConversation(conv: Conversation) {
  if (!window.confirm(`Delete chat with ${displayName(conv)}? This cannot be undone.`)) {
    return
  }

  deletingConversationId.value = conv.id

  const { error: messagesError } = await supabase
    .from('messages')
    .delete()
    .eq('conversation_id', conv.id)

  if (messagesError) {
    console.error('Error deleting conversation messages:', messagesError)
    deletingConversationId.value = null
    return
  }

  const { error } = await supabase
    .from('conversations')
    .delete()
    .eq('id', conv.id)

  if (error) {
    console.error('Error deleting conversation:', error)
  } else {
    removeConversationLocally(conv.id)
  }

  deletingConversationId.value = null
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

onMounted(() => {
  void loadConversations()
  subscribeToConversations()
  subscribeToMessages()
})

onUnmounted(() => {
  if (convSubscription) supabase.removeChannel(convSubscription)
  if (msgSubscription) supabase.removeChannel(msgSubscription)
})
</script>

<template>
  <AdminPageShell title="Inbox">
    <div class="inbox">
      <aside class="inbox__left" aria-label="Inbox conversations">
        <header class="inbox__left-header">
          <div>
            <p class="eyebrow">Live inbox</p>
            <h2>Chats</h2>
          </div>
          <span class="inbox__count">{{ conversations.length }}</span>
        </header>

        <div class="inbox__stats">
          <div>
            <strong>{{ totalUnread }}</strong>
            <span>Unread</span>
          </div>
          <div>
            <strong>{{ openCount }}</strong>
            <span>Open</span>
          </div>
        </div>

        <label class="inbox__search">
          <Search :size="17" />
          <input v-model="searchQuery" type="search" placeholder="Search chats" />
        </label>

        <div class="inbox__filters" aria-label="Conversation filters">
          <button
            type="button"
            :class="{ active: statusFilter === 'all' }"
            @click="statusFilter = 'all'"
          >
            All
          </button>
          <button
            type="button"
            :class="{ active: statusFilter === 'open' }"
            @click="statusFilter = 'open'"
          >
            Open
          </button>
          <button
            type="button"
            :class="{ active: statusFilter === 'resolved' }"
            @click="statusFilter = 'resolved'"
          >
            Resolved
          </button>
        </div>

        <div class="conversation-list">
          <div v-if="loadingConversations" class="state state--compact">
            Loading conversations...
          </div>

          <div v-else-if="filteredConversations.length === 0" class="state state--compact">
            No chats found.
          </div>

          <template v-else>
            <button
              v-for="conv in filteredConversations"
              :key="conv.id"
              type="button"
              class="conversation"
              :class="{
                active: activeConversation?.id === conv.id,
                unread: (conv.unread_count_admin ?? 0) > 0,
              }"
              @click="selectConversation(conv)"
            >
              <span class="conversation__avatar">{{ initials(conv) }}</span>
              <span class="conversation__body">
                <span class="conversation__topline">
                  <strong>{{ displayName(conv) }}</strong>
                  <time>{{ formatDate(conv.updated_at) }}</time>
                </span>
                <span class="conversation__meta">
                  <span>#{{ shortVisitorId(conv) }}</span>
                  <span class="conversation__status" :class="`is-${conv.status ?? 'open'}`">
                    {{ conv.status ?? 'open' }}
                  </span>
                </span>
              </span>
              <span v-if="(conv.unread_count_admin ?? 0) > 0" class="conversation__badge">
                {{ conv.unread_count_admin }}
              </span>
            </button>
          </template>
        </div>
      </aside>

      <section class="inbox__chat" aria-label="Selected conversation">
        <div v-if="!activeConversation" class="chat-empty">
          <span class="chat-empty__icon">
            <Inbox :size="34" />
          </span>
          <h3>Select a chat</h3>
          <p>Choose a conversation from the inbox list to read and reply in real time.</p>
        </div>

        <template v-else>
          <header class="chat-header">
            <div class="chat-header__identity">
              <span class="conversation__avatar conversation__avatar--large">
                {{ initials(activeConversation) }}
              </span>
              <div>
                <p class="chat-header__name">{{ displayName(activeConversation) }}</p>
                <div class="chat-header__details">
                  <span><UserRound :size="14" /> #{{ shortVisitorId(activeConversation) }}</span>
                  <a
                    v-if="activeConversation.guest_email"
                    :href="`mailto:${activeConversation.guest_email}`"
                  >
                    <Mail :size="14" /> {{ activeConversation.guest_email }}
                  </a>
                  <span><Clock3 :size="14" /> {{ formatDate(activeConversation.updated_at) }}</span>
                </div>
              </div>
            </div>

            <div class="chat-header__actions">
              <button
                v-if="activeConversation.status === 'resolved'"
                class="icon-btn"
                type="button"
                title="Reopen chat"
                @click="setConversationStatus('open')"
              >
                <RotateCcw :size="17" />
              </button>
              <button
                v-else
                class="icon-btn"
                type="button"
                title="Mark resolved"
                @click="setConversationStatus('resolved')"
              >
                <CheckCircle2 :size="17" />
              </button>
              <button
                class="icon-btn icon-btn--danger"
                type="button"
                title="Delete chat"
                :disabled="deletingConversationId === activeConversation.id"
                @click="deleteConversation(activeConversation)"
              >
                <Trash2 :size="17" />
              </button>
            </div>
          </header>

          <div ref="messagesContainer" class="chat-messages">
            <div v-if="loadingMessages" class="state">
              Loading messages...
            </div>

            <div v-else-if="messages.length === 0" class="state">
              <MessageSquare :size="28" />
              No messages in this chat yet.
            </div>

            <template v-else>
              <div
                v-for="message in messages"
                :key="message.id"
                class="message"
                :class="`message--${message.sender_type}`"
              >
                <div class="message__bubble">{{ message.content }}</div>
                <time class="message__time">{{ formatTime(message.created_at) }}</time>
              </div>
            </template>
          </div>

          <form class="reply-box" @submit.prevent="sendMessage">
            <input
              v-model="newMessage"
              class="reply-box__input"
              type="text"
              placeholder="Write a reply..."
              :disabled="sending || deletingConversationId === activeConversation.id"
            />
            <button
              class="reply-box__send"
              type="submit"
              title="Send reply"
              :disabled="!newMessage.trim() || sending || deletingConversationId === activeConversation.id"
            >
              <Send v-if="!sending" :size="19" />
              <span v-else class="spinner" />
            </button>
          </form>
        </template>
      </section>
    </div>
  </AdminPageShell>
</template>

<style scoped>
.inbox {
  display: grid;
  grid-template-columns: minmax(280px, 360px) minmax(0, 1fr);
  gap: 18px;
  min-height: 640px;
  height: calc(100svh - 190px);
  margin-top: 22px;
}

.inbox__left,
.inbox__chat {
  min-height: 0;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(108, 99, 255, 0.14);
  border-radius: 18px;
  box-shadow: 0 12px 34px rgba(15, 23, 42, 0.06);
  overflow: hidden;
}

.inbox__left {
  display: flex;
  flex-direction: column;
}

.inbox__left-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 22px 22px 16px;
}

.eyebrow {
  margin: 0 0 4px;
  color: #6c63ff;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.inbox__left-header h2 {
  margin: 0;
  color: #1a1a2e;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 1.35rem;
}

.inbox__count {
  display: grid;
  place-items: center;
  min-width: 36px;
  height: 36px;
  padding: 0 10px;
  border-radius: 12px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.09);
  font-weight: 800;
}

.inbox__stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  padding: 0 18px 16px;
}

.inbox__stats div {
  padding: 12px;
  border: 1px solid rgba(108, 99, 255, 0.12);
  border-radius: 14px;
  background: #f8fafc;
}

.inbox__stats strong,
.inbox__stats span {
  display: block;
}

.inbox__stats strong {
  color: #1a1a2e;
  font-size: 1.15rem;
  line-height: 1;
}

.inbox__stats span {
  margin-top: 5px;
  color: #94a3b8;
  font-size: 0.78rem;
  font-weight: 700;
}

.inbox__search {
  display: flex;
  align-items: center;
  gap: 9px;
  margin: 0 18px 12px;
  padding: 11px 12px;
  color: #94a3b8;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  background: #ffffff;
}

.inbox__search input {
  width: 100%;
  min-width: 0;
  border: 0;
  outline: 0;
  color: #1e293b;
  background: transparent;
  font-size: 0.9rem;
}

.inbox__filters {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
  padding: 0 18px 16px;
}

.inbox__filters button {
  border: 1px solid transparent;
  border-radius: 12px;
  padding: 8px 10px;
  color: #64748b;
  background: #f8fafc;
  font: inherit;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
}

.inbox__filters button.active {
  color: #6c63ff;
  border-color: rgba(108, 99, 255, 0.18);
  background: rgba(108, 99, 255, 0.09);
}

.conversation-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 0 12px 14px;
}

.conversation {
  position: relative;
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr) auto;
  align-items: center;
  gap: 12px;
  width: 100%;
  min-height: 78px;
  padding: 12px;
  border: 1px solid transparent;
  border-radius: 16px;
  color: inherit;
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition: background 0.18s ease, border-color 0.18s ease, transform 0.18s ease;
}

.conversation:hover,
.conversation.active {
  background: #ffffff;
  border-color: rgba(108, 99, 255, 0.14);
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
}

.conversation.active {
  transform: translateX(2px);
}

.conversation.unread .conversation__avatar {
  color: #ffffff;
  background: #6c63ff;
}

.conversation__avatar {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 14px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.1);
  font-size: 0.78rem;
  font-weight: 800;
}

.conversation__avatar--large {
  width: 48px;
  height: 48px;
  border-radius: 16px;
}

.conversation__body,
.conversation__topline,
.conversation__meta {
  min-width: 0;
}

.conversation__topline {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
}

.conversation__topline strong {
  overflow: hidden;
  color: #1a1a2e;
  font-size: 0.93rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.conversation__topline time {
  flex-shrink: 0;
  color: #94a3b8;
  font-size: 0.68rem;
}

.conversation__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 6px;
  color: #94a3b8;
  font-size: 0.75rem;
}

.conversation__status {
  padding: 2px 7px;
  border-radius: 999px;
  color: #64748b;
  background: #f1f5f9;
  font-weight: 800;
  text-transform: capitalize;
}

.conversation__status.is-open {
  color: #047857;
  background: rgba(16, 185, 129, 0.1);
}

.conversation__status.is-resolved {
  color: #7c3aed;
  background: rgba(124, 58, 237, 0.1);
}

.conversation__badge {
  display: grid;
  place-items: center;
  min-width: 24px;
  height: 24px;
  padding: 0 7px;
  border-radius: 999px;
  color: #ffffff;
  background: #ef4444;
  font-size: 0.72rem;
  font-weight: 800;
}

.inbox__chat {
  display: flex;
  flex-direction: column;
}

.chat-empty,
.state {
  display: grid;
  place-items: center;
  align-content: center;
  gap: 10px;
  min-height: 100%;
  padding: 30px;
  color: #94a3b8;
  text-align: center;
}

.state--compact {
  min-height: 220px;
  font-size: 0.92rem;
}

.chat-empty__icon {
  display: grid;
  place-items: center;
  width: 72px;
  height: 72px;
  border-radius: 22px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.09);
}

.chat-empty h3 {
  margin: 6px 0 0;
  color: #1a1a2e;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 1.25rem;
}

.chat-empty p {
  max-width: 360px;
  margin: 0;
}

.chat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 18px 22px;
  border-bottom: 1px solid rgba(108, 99, 255, 0.12);
  background: #ffffff;
}

.chat-header__identity {
  display: flex;
  align-items: center;
  min-width: 0;
  gap: 13px;
}

.chat-header__name {
  margin: 0 0 5px;
  color: #1a1a2e;
  font-size: 1rem;
  font-weight: 800;
}

.chat-header__details {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 14px;
  color: #64748b;
  font-size: 0.78rem;
}

.chat-header__details span,
.chat-header__details a {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  color: inherit;
  text-decoration: none;
}

.chat-header__actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.icon-btn,
.reply-box__send {
  display: grid;
  place-items: center;
  border: 0;
  cursor: pointer;
  transition: transform 0.18s ease, background 0.18s ease, color 0.18s ease;
}

.icon-btn {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  color: #6c63ff;
  background: rgba(108, 99, 255, 0.09);
}

.icon-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  background: rgba(108, 99, 255, 0.14);
}

.icon-btn--danger {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.08);
}

.icon-btn--danger:hover:not(:disabled) {
  background: rgba(239, 68, 68, 0.12);
}

.icon-btn:disabled,
.reply-box__send:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.chat-messages {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 24px;
  background: linear-gradient(180deg, #f8fafc 0%, #ffffff 100%);
}

.message {
  display: flex;
  flex-direction: column;
  gap: 5px;
  max-width: min(68%, 620px);
  margin-bottom: 15px;
}

.message--admin {
  align-items: flex-end;
  margin-left: auto;
}

.message--guest {
  align-items: flex-start;
  margin-right: auto;
}

.message__bubble {
  padding: 12px 15px;
  border-radius: 17px;
  font-size: 0.92rem;
  line-height: 1.55;
  overflow-wrap: anywhere;
}

.message--admin .message__bubble {
  color: #ffffff;
  border-bottom-right-radius: 5px;
  background: linear-gradient(135deg, #6c63ff 0%, #818cf8 100%);
  box-shadow: 0 10px 24px rgba(108, 99, 255, 0.2);
}

.message--guest .message__bubble {
  color: #1e293b;
  border: 1px solid #e2e8f0;
  border-bottom-left-radius: 5px;
  background: #ffffff;
}

.message__time {
  padding: 0 4px;
  color: #94a3b8;
  font-size: 0.72rem;
}

.reply-box {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 18px 22px;
  border-top: 1px solid rgba(108, 99, 255, 0.12);
  background: #ffffff;
}

.reply-box__input {
  flex: 1;
  min-width: 0;
  border: 1px solid #dbe3ef;
  border-radius: 14px;
  outline: 0;
  padding: 13px 15px;
  color: #1e293b;
  background: #f8fafc;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
}

.reply-box__input:focus {
  border-color: #6c63ff;
  background: #ffffff;
  box-shadow: 0 0 0 4px rgba(108, 99, 255, 0.1);
}

.reply-box__send {
  width: 46px;
  height: 46px;
  flex-shrink: 0;
  border-radius: 15px;
  color: #ffffff;
  background: #6c63ff;
}

.reply-box__send:hover:not(:disabled) {
  transform: translateY(-1px);
  background: #5a52d5;
}

.spinner {
  width: 18px;
  height: 18px;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #ffffff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 920px) {
  .inbox {
    grid-template-columns: 1fr;
    height: auto;
  }

  .inbox__left {
    min-height: 520px;
  }

  .inbox__chat {
    min-height: 620px;
  }
}

@media (max-width: 640px) {
  .inbox {
    gap: 14px;
    min-height: 0;
  }

  .chat-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .chat-header__actions {
    width: 100%;
    justify-content: flex-end;
  }

  .message {
    max-width: 88%;
  }
}
</style>
