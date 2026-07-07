<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.ts'

interface Skill {
  id: string
  name: string
  order_index: number
}

const skills = ref<Skill[]>([])
const loading = ref(true)
const newSkillName = ref('')
const newSkillOrder = ref(0)
const isAdding = ref(false)
const deletingId = ref<string | null>(null)
const draggedSkill = ref<Skill | null>(null)
const dragOverId = ref<string | null>(null)


onMounted(async () => {
  await fetchSkills()
})

async function fetchSkills() {
  loading.value = true
  const { data, error } = await supabase
    .from('skills')
    .select('id, name, order_index')
    .order('order_index', { ascending: true })
  
  if (!error) {
    skills.value = data ?? []
    if (skills.value.length > 0) {
      newSkillOrder.value = Math.max(...skills.value.map(s => s.order_index)) + 1
    } else {
      newSkillOrder.value = 1
    }
  }
  loading.value = false
}

async function addSkill() {
  if (!newSkillName.value.trim()) return
  
  isAdding.value = true
  const targetOrder = newSkillOrder.value

  // Check if we need to shift items
  const itemsToShift = []
  for (let i = 0; i < skills.value.length; i++) {
    if (skills.value[i].order_index >= targetOrder) {
      skills.value[i].order_index++
      itemsToShift.push(skills.value[i])
    }
  }

  // If there are items to shift, update them in the database
  if (itemsToShift.length > 0) {
    const promises = []
    for (let i = 0; i < itemsToShift.length; i++) {
      promises.push(
        supabase.from('skills').update({ order_index: itemsToShift[i].order_index }).eq('id', itemsToShift[i].id)
      )
    }
    await Promise.all(promises)
  }
  
  const { data, error } = await supabase
    .from('skills')
    .insert({
      name: newSkillName.value.trim(),
      order_index: targetOrder
    })
    .select()
    .single()
    
  if (!error && data) {
    skills.value.push(data)
    skills.value.sort((a, b) => a.order_index - b.order_index)
    newSkillName.value = ''
    newSkillOrder.value = skills.value.length > 0 ? Math.max(...skills.value.map(s => s.order_index)) + 1 : 1
  } else {
    // Revert shifting if insert failed
    if (itemsToShift.length > 0) {
      const promises = []
      for (let i = 0; i < itemsToShift.length; i++) {
        itemsToShift[i].order_index--
        promises.push(
          supabase.from('skills').update({ order_index: itemsToShift[i].order_index }).eq('id', itemsToShift[i].id)
        )
      }
      await Promise.all(promises)
    }
    alert('Error adding skill')
  }
  isAdding.value = false
}

async function deleteSkill(id: string) {
  if (!confirm('Are you sure you want to delete this skill?')) return
  
  deletingId.value = id
  const { error } = await supabase.from('skills').delete().eq('id', id)
  if (!error) {
    skills.value = skills.value.filter(s => s.id !== id)
  }
  deletingId.value = null
}

function onDragStart(event: DragEvent, skill: Skill) {
  draggedSkill.value = skill
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

function onDragEnter(_event: DragEvent, skill: Skill) {
  if (draggedSkill.value && draggedSkill.value.id !== skill.id) {
    dragOverId.value = skill.id
  }
}

function onDragEnd() {
  draggedSkill.value = null
  dragOverId.value = null
}

async function onDrop(_event: DragEvent, targetSkill: Skill) {
  if (!draggedSkill.value || draggedSkill.value.id === targetSkill.id) {
    dragOverId.value = null
    return
  }

  const sourceIndex = skills.value.findIndex(s => s.id === draggedSkill.value!.id)
  const targetIndex = skills.value.findIndex(s => s.id === targetSkill.id)
  
  const [removed] = skills.value.splice(sourceIndex, 1)
  skills.value.splice(targetIndex, 0, removed)
  
  skills.value.forEach((s, i) => {
    s.order_index = i + 1
  })

  dragOverId.value = null
  draggedSkill.value = null
  
  // Save new order to database
  const promises = skills.value.map(s => 
    supabase.from('skills').update({ order_index: s.order_index }).eq('id', s.id)
  )
  await Promise.all(promises)
}
</script>

<template>
  <div class="page">
    <!-- Header -->
    <div class="page-header">
      <div>
        <h1 class="page-title">Skills</h1>
        <p class="page-sub">{{ skills.length }} skill{{ skills.length !== 1 ? 's' : '' }} total</p>
      </div>
    </div>

    <!-- Add Form -->
    <div class="add-card">
      <form @submit.prevent="addSkill" class="add-form">
        <div class="form-group">
          <input v-model="newSkillName" type="text" placeholder="New skill name (e.g. Vue.js)" required :disabled="isAdding" class="input-field" />
        </div>
        <div class="form-group order-group">
          <input v-model="newSkillOrder" type="number" placeholder="Order" required :disabled="isAdding" class="input-field" />
        </div>
        <button type="submit" class="btn-new" :disabled="isAdding || !newSkillName.trim()">
          <span>＋</span> Add
        </button>
      </form>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>Loading skills...</p>
    </div>

    <!-- Empty -->
    <div v-else-if="skills.length === 0" class="empty-state">
      <div class="empty-icon">🛠️</div>
      <h3>No skills yet</h3>
      <p>Add your first skill above</p>
    </div>

    <!-- Skill List -->
    <div v-else class="skill-list">
      <div
          v-for="skill in skills"
          :key="skill.id"
          class="skill-row"
          :class="{ 
            deleting: deletingId === skill.id, 
            'drag-over': dragOverId === skill.id,
            'is-dragging': draggedSkill?.id === skill.id
          }"
          draggable="true"
          @dragstart="onDragStart($event, skill)"
          @dragenter.prevent="onDragEnter($event, skill)"
          @dragover.prevent
          @drop="onDrop($event, skill)"
          @dragend="onDragEnd"
      >
        <div class="skill-info">
          <div class="drag-handle" title="Drag to reorder">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="9" cy="12" r="1"/><circle cx="9" cy="5" r="1"/><circle cx="9" cy="19" r="1"/>
              <circle cx="15" cy="12" r="1"/><circle cx="15" cy="5" r="1"/><circle cx="15" cy="19" r="1"/>
            </svg>
          </div>
          <h3 class="skill-title">{{ skill.name }}</h3>
          <span class="skill-order">Order: {{ skill.order_index }}</span>
        </div>

        <div class="skill-actions">
          <button
              class="action-btn delete"
              title="Delete"
              :disabled="deletingId === skill.id"
              @click="deleteSkill(skill.id)"
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

/* Add Card */
.add-card {
  background: #fafafa;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 1.2rem;
  margin-bottom: 2rem;
}

.add-form {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.form-group {
  display: flex;
  flex: 1;
}

.order-group {
  flex: 0 0 100px;
}

.input-field {
  width: 100%;
  padding: 0.7rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.input-field:focus {
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99,102,241,0.1);
}

.btn-new {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: #6366f1;
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 0.7rem 1.4rem;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.18s, transform 0.15s;
  white-space: nowrap;
}
.btn-new:hover:not(:disabled) { background: #4f46e5; transform: translateY(-1px); }
.btn-new:disabled { opacity: 0.5; cursor: not-allowed; }

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

/* Skill list */
.skill-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.skill-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fafafa;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 0.9rem 1.25rem;
  transition: box-shadow 0.18s, opacity 0.2s, transform 0.2s, border-color 0.2s;
}
.skill-row:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.06); }
.skill-row.deleting { opacity: 0.4; pointer-events: none; }
.skill-row.is-dragging { opacity: 0.5; border: 2px dashed #cbd5e1; }
.skill-row.drag-over { border: 2px solid #6366f1; transform: scale(1.02); }

.drag-handle {
  color: #94a3b8;
  cursor: grab;
  display: flex;
  align-items: center;
  justify-content: center;
}
.drag-handle:active {
  cursor: grabbing;
}

.skill-info {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.skill-title {
  font-size: 1.05rem;
  font-weight: 600;
  color: #0f172a;
  margin: 0;
}

.skill-order {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6366f1;
  background: rgba(99,102,241,0.07);
  border: 1px solid rgba(99,102,241,0.15);
  padding: 3px 10px;
  border-radius: 999px;
}

.skill-actions {
  display: flex;
  gap: 0.4rem;
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
.action-btn.delete:hover   { background: rgba(239,68,68,0.08);   border-color: #ef4444; }
.action-btn:disabled       { opacity: 0.4; cursor: not-allowed; }

@media (max-width: 640px) {
  .page { padding: 1.25rem; }
  .add-form { flex-direction: column; align-items: stretch; }
  .order-group { flex: auto; }
}
</style>
