<template>
  <div v-if="normalizedImages.length" class="carousel-container">
    <!-- Single Image Mode (Exact look & feel as before) -->
    <div
      v-if="normalizedImages.length === 1"
      class="single-image-wrap"
      @click="onImageClick(0)"
    >
      <img
        :src="normalizedImages[0]"
        :alt="alt || 'Post image'"
        loading="lazy"
        class="carousel-img"
      />
      <span class="media-zoom-hint" title="View full size">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/>
          <line x1="21" y1="21" x2="16.65" y2="16.65"/>
          <line x1="11" y1="8" x2="11" y2="14"/>
          <line x1="8" y1="11" x2="14" y2="11"/>
        </svg>
      </span>
    </div>

    <!-- Multi-Image Instagram-Style Carousel -->
    <div
      v-else
      class="multi-carousel-wrap"
      @touchstart="handleTouchStart"
      @touchmove="handleTouchMove"
      @touchend="handleTouchEnd"
      @mousedown="handleMouseDown"
    >
      <!-- Track of Slides -->
      <div
        class="carousel-track"
        :style="{
          transform: `translateX(calc(-${currentIndex * 100}% + ${dragOffset}px))`,
          transition: isDragging ? 'none' : 'transform 0.32s cubic-bezier(0.22, 1, 0.36, 1)'
        }"
      >
        <div
          v-for="(imgUrl, idx) in normalizedImages"
          :key="imgUrl + idx"
          class="carousel-slide"
          @click="onImageClick(idx)"
        >
          <img
            :src="imgUrl"
            :alt="`${alt || 'Post image'} (${idx + 1}/${normalizedImages.length})`"
            loading="lazy"
            class="carousel-img"
            draggable="false"
          />
        </div>
      </div>

      <!-- Instagram-Style Index Badge (e.g. 1/4) -->
      <div class="carousel-counter-badge">
        {{ currentIndex + 1 }}/{{ normalizedImages.length }}
      </div>

      <!-- Navigation Arrow: Previous -->
      <transition name="fade">
        <button
          v-if="currentIndex > 0"
          type="button"
          class="carousel-nav-btn btn-prev"
          aria-label="Previous photo"
          @click.stop="prevSlide"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
            <polyline points="15 18 9 12 15 6"></polyline>
          </svg>
        </button>
      </transition>

      <!-- Navigation Arrow: Next -->
      <transition name="fade">
        <button
          v-if="currentIndex < normalizedImages.length - 1"
          type="button"
          class="carousel-nav-btn btn-next"
          aria-label="Next photo"
          @click.stop="nextSlide"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
            <polyline points="9 18 15 12 9 6"></polyline>
          </svg>
        </button>
      </transition>

      <!-- Instagram-Style Pagination Dots -->
      <div class="carousel-dots-row">
        <button
          v-for="(_, dotIdx) in normalizedImages"
          :key="dotIdx"
          type="button"
          class="carousel-dot"
          :class="{ 'is-active': dotIdx === currentIndex }"
          :aria-label="`Go to slide ${dotIdx + 1}`"
          @click.stop="goToSlide(dotIdx)"
        ></button>
      </div>

      <!-- Zoom hint overlay -->
      <span class="media-zoom-hint" title="View full size" @click.stop="onImageClick(currentIndex)">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"/>
          <line x1="21" y1="21" x2="16.65" y2="16.65"/>
          <line x1="11" y1="8" x2="11" y2="14"/>
          <line x1="8" y1="11" x2="14" y2="11"/>
        </svg>
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'

const props = defineProps<{
  images?: string[] | string | null
  alt?: string
}>()

const emit = defineEmits<{
  (e: 'open-lightbox', index: number): void
}>()

const currentIndex = ref(0)
const isDragging = ref(false)
const dragOffset = ref(0)

const normalizedImages = computed<string[]>(() => {
  if (!props.images) return []
  if (Array.isArray(props.images)) {
    return props.images.filter((u): u is string => typeof u === 'string' && u.trim().length > 0)
  }
  if (typeof props.images === 'string' && props.images.trim().length > 0) {
    return [props.images.trim()]
  }
  return []
})

function prevSlide() {
  if (currentIndex.value > 0) {
    currentIndex.value--
  }
}

function nextSlide() {
  if (currentIndex.value < normalizedImages.value.length - 1) {
    currentIndex.value++
  }
}

function goToSlide(idx: number) {
  currentIndex.value = Math.max(0, Math.min(normalizedImages.value.length - 1, idx))
}

function onImageClick(idx: number) {
  // If user dragged more than 5px, don't trigger click
  if (Math.abs(dragOffset.value) > 6) return
  emit('open-lightbox', idx)
}

// ── Touch Gestures (Instagram Swipe) ─────────────────────────
let touchStartX = 0
let touchStartY = 0
let isHorizontalSwipe = false

function handleTouchStart(e: TouchEvent) {
  if (normalizedImages.value.length <= 1) return
  touchStartX = e.touches[0].clientX
  touchStartY = e.touches[0].clientY
  isHorizontalSwipe = false
  isDragging.value = false
  dragOffset.value = 0
}

function handleTouchMove(e: TouchEvent) {
  if (normalizedImages.value.length <= 1) return
  const currentX = e.touches[0].clientX
  const currentY = e.touches[0].clientY
  const diffX = currentX - touchStartX
  const diffY = currentY - touchStartY

  if (!isHorizontalSwipe && Math.abs(diffX) > 8 && Math.abs(diffX) > Math.abs(diffY)) {
    isHorizontalSwipe = true
  }

  if (isHorizontalSwipe) {
    // Prevent vertical scrolling when actively swiping horizontally
    e.preventDefault()
    // Edge dampening
    if (
      (currentIndex.value === 0 && diffX > 0) ||
      (currentIndex.value === normalizedImages.value.length - 1 && diffX < 0)
    ) {
      dragOffset.value = diffX * 0.3
    } else {
      dragOffset.value = diffX
    }
  }
}

function handleTouchEnd() {
  if (normalizedImages.value.length <= 1 || !isHorizontalSwipe) {
    dragOffset.value = 0
    return
  }

  const threshold = 40
  if (dragOffset.value < -threshold && currentIndex.value < normalizedImages.value.length - 1) {
    nextSlide()
  } else if (dragOffset.value > threshold && currentIndex.value > 0) {
    prevSlide()
  }

  isDragging.value = false
  dragOffset.value = 0
  isHorizontalSwipe = false
}

// ── Mouse Drag Swipe (Desktop) ──────────────────────────────
let mouseStartX = 0

function handleMouseDown(e: MouseEvent) {
  if (normalizedImages.value.length <= 1) return
  // Don't drag if clicked on button
  if ((e.target as HTMLElement).closest('.carousel-nav-btn, .carousel-dot')) return

  mouseStartX = e.clientX
  isDragging.value = true
  dragOffset.value = 0

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (!isDragging.value) return
    const diffX = moveEvent.clientX - mouseStartX
    if (
      (currentIndex.value === 0 && diffX > 0) ||
      (currentIndex.value === normalizedImages.value.length - 1 && diffX < 0)
    ) {
      dragOffset.value = diffX * 0.25
    } else {
      dragOffset.value = diffX
    }
  }

  const onMouseUp = () => {
    if (!isDragging.value) return
    isDragging.value = false
    const threshold = 50
    if (dragOffset.value < -threshold && currentIndex.value < normalizedImages.value.length - 1) {
      nextSlide()
    } else if (dragOffset.value > threshold && currentIndex.value > 0) {
      prevSlide()
    }
    dragOffset.value = 0
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }

  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}
</script>

<style scoped>
.carousel-container {
  width: 100%;
  margin-bottom: 14px;
}

/* Single Image */
.single-image-wrap {
  position: relative;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  background: #0f172a;
  cursor: pointer;
  max-height: 480px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.single-image-wrap:hover .carousel-img {
  transform: scale(1.01);
}

/* Multi-Image Carousel */
.multi-carousel-wrap {
  position: relative;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  background: #0f172a;
  user-select: none;
  cursor: grab;
  touch-action: pan-y;
}

.multi-carousel-wrap:active {
  cursor: grabbing;
}

.carousel-track {
  display: flex;
  width: 100%;
  height: 100%;
}

.carousel-slide {
  flex: 0 0 100%;
  width: 100%;
  max-height: 480px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: #0b0f19;
}

.carousel-img {
  width: 100%;
  height: auto;
  max-height: 480px;
  object-fit: cover;
  display: block;
  transition: transform 0.2s ease;
}

/* ── Instagram Counter Badge (Top Right) ──────────────────── */
.carousel-counter-badge {
  position: absolute;
  top: 12px;
  right: 12px;
  background: rgba(15, 23, 42, 0.72);
  color: #ffffff;
  font-size: 11px;
  font-weight: 700;
  padding: 4px 9px;
  border-radius: 999px;
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  letter-spacing: 0.5px;
  z-index: 2;
  pointer-events: none;
}

/* ── Navigation Arrows ────────────────────────────────────── */
.carousel-nav-btn {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(15, 23, 42, 0.72);
  color: #ffffff;
  border: 1px solid rgba(255, 255, 255, 0.2);
  display: grid;
  place-items: center;
  cursor: pointer;
  z-index: 3;
  backdrop-filter: blur(8px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
  transition: background 0.18s ease, transform 0.18s ease;
}

.carousel-nav-btn:hover {
  background: #6c63ff;
  border-color: #6c63ff;
  transform: translateY(-50%) scale(1.1);
}

.btn-prev {
  left: 10px;
}

.btn-next {
  right: 10px;
}

/* ── Instagram Dots Indicator (Bottom Center) ─────────────── */
.carousel-dots-row {
  position: absolute;
  bottom: 12px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(15, 23, 42, 0.5);
  padding: 5px 10px;
  border-radius: 999px;
  backdrop-filter: blur(6px);
  z-index: 2;
}

.carousel-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.45);
  border: none;
  padding: 0;
  cursor: pointer;
  transition: all 0.22s cubic-bezier(0.16, 1, 0.3, 1);
}

.carousel-dot.is-active {
  background: #ffffff;
  width: 16px;
  border-radius: 999px;
}

/* ── Zoom Hint ────────────────────────────────────────────── */
.media-zoom-hint {
  position: absolute;
  top: 12px;
  left: 12px;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  background: rgba(15, 23, 42, 0.65);
  color: #ffffff;
  display: grid;
  place-items: center;
  backdrop-filter: blur(4px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  z-index: 2;
  cursor: pointer;
  transition: transform 0.15s ease;
}

.media-zoom-hint:hover {
  transform: scale(1.1);
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
