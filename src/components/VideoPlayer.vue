<template>
  <div
    ref="containerRef"
    class="video-player-container"
    :class="{
      'is-fullscreen': isFullscreen,
      'is-playing': isPlaying,
      'controls-visible': controlsVisible || !isPlaying,
      'is-buffering': isBuffering
    }"
    tabindex="0"
    @mousemove="handleUserActivity"
    @mouseleave="handleMouseLeave"
    @keydown="handleKeyDown"
  >
    <!-- HTML5 Video element -->
    <video
      ref="videoRef"
      :src="src"
      class="video-element"
      playsinline
      preload="metadata"
      @play="onPlay"
      @pause="onPause"
      @timeupdate="onTimeUpdate"
      @loadedmetadata="onLoadedMetadata"
      @progress="onProgress"
      @waiting="isBuffering = true"
      @playing="isBuffering = false"
      @ended="onEnded"
      @click="togglePlay"
      @dblclick="toggleFullscreen"
    ></video>

    <!-- Buffering Spinner -->
    <div v-if="isBuffering" class="buffering-spinner-wrap">
      <div class="buffering-spinner"></div>
    </div>

    <!-- Center Play/Replay Button Overlay -->
    <transition name="fade-scale">
      <div
        v-if="!isPlaying && !isBuffering"
        class="center-play-overlay"
        @click="togglePlay"
      >
        <button type="button" class="center-play-btn" :aria-label="hasEnded ? 'Replay' : 'Play'">
          <svg v-if="hasEnded" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" width="32" height="32">
            <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
            <path d="M3 3v5h5" />
          </svg>
          <svg v-else viewBox="0 0 24 24" fill="currentColor" width="34" height="34">
            <path d="M8 5v14l11-7z" />
          </svg>
        </button>
      </div>
    </transition>

    <!-- Bottom Controls Overlay -->
    <div
      class="video-controls-overlay"
      @click.stop
    >
      <!-- Timeline Scrubber with Hover Time Indicator -->
      <div
        ref="timelineRef"
        class="timeline-track-wrap"
        @mousemove="onTimelineHover"
        @mouseleave="timelineHoverTime = null"
        @mousedown="startSeek"
      >
        <div class="timeline-track">
          <!-- Buffered Range -->
          <div class="timeline-buffered" :style="{ width: `${bufferedPercent}%` }"></div>
          <!-- Played Progress -->
          <div class="timeline-played" :style="{ width: `${progressPercent}%` }"></div>
          <!-- Seek Handle/Scrubber Knob -->
          <div class="timeline-handle" :style="{ left: `${progressPercent}%` }"></div>
        </div>

        <!-- Hover Time Tooltip -->
        <div
          v-if="timelineHoverTime !== null"
          class="timeline-tooltip"
          :style="{ left: `${timelineHoverPercent}%` }"
        >
          {{ formatTime(timelineHoverTime) }}
        </div>
      </div>

      <!-- Action Buttons Row -->
      <div class="controls-row">
        <div class="controls-left">
          <!-- Play / Pause Toggle -->
          <button
            type="button"
            class="ctrl-btn play-pause-btn"
            :title="isPlaying ? 'Pause (Space)' : 'Play (Space)'"
            @click="togglePlay"
          >
            <svg v-if="!isPlaying" viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M8 5v14l11-7z" />
            </svg>
            <svg v-else viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
            </svg>
          </button>

          <!-- Volume / Mute Button & Slider -->
          <div class="volume-control-group" @mouseenter="isVolumeHovered = true" @mouseleave="isVolumeHovered = false">
            <button
              type="button"
              class="ctrl-btn volume-btn"
              :title="isMuted ? 'Unmute (M)' : 'Mute (M)'"
              @click="toggleMute"
            >
              <!-- Muted Icon -->
              <svg v-if="isMuted || volume === 0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="19" height="19">
                <path d="M11 5L6 9H2v6h4l5 4V5z"/>
                <line x1="23" y1="9" x2="17" y2="15"/>
                <line x1="17" y1="9" x2="23" y2="15"/>
              </svg>
              <!-- Low Volume -->
              <svg v-else-if="volume < 0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="19" height="19">
                <path d="M11 5L6 9H2v6h4l5 4V5z"/>
                <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
              </svg>
              <!-- High Volume -->
              <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="19" height="19">
                <path d="M11 5L6 9H2v6h4l5 4V5z"/>
                <path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>
                <path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>
              </svg>
            </button>

            <!-- Volume Slider -->
            <div class="volume-slider-box" :class="{ 'is-active': isVolumeHovered }">
              <input
                type="range"
                min="0"
                max="1"
                step="0.05"
                :value="isMuted ? 0 : volume"
                class="volume-range-slider"
                aria-label="Volume slider"
                @input="onVolumeInput"
              />
            </div>
          </div>

          <!-- Time Display -->
          <div class="time-display">
            <span class="time-current">{{ formatTime(currentTime) }}</span>
            <span class="time-sep">/</span>
            <span class="time-duration">{{ formatTime(duration) }}</span>
          </div>
        </div>

        <div class="controls-right">
          <!-- Playback Speed Button -->
          <button
            type="button"
            class="ctrl-btn speed-btn"
            title="Playback Speed"
            @click="cycleSpeed"
          >
            {{ playbackRate }}x
          </button>

          <!-- Picture in Picture (if supported) -->
          <button
            v-if="supportsPiP"
            type="button"
            class="ctrl-btn pip-btn"
            title="Picture in Picture"
            @click="togglePiP"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
              <rect x="2" y="4" width="20" height="16" rx="2"/>
              <rect x="12" y="10" width="8" height="6" rx="1"/>
            </svg>
          </button>

          <!-- Fullscreen Button -->
          <button
            type="button"
            class="ctrl-btn fullscreen-btn"
            :title="isFullscreen ? 'Exit Fullscreen (F)' : 'Fullscreen (F)'"
            @click="toggleFullscreen"
          >
            <svg v-if="!isFullscreen" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="19" height="19">
              <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/>
            </svg>
            <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="19" height="19">
              <path d="M8 3v3a2 2 0 0 1-2 2H3m18 0h-3a2 2 0 0 1-2-2V3m0 18v-3a2 2 0 0 1 2-2h3M3 16h3a2 2 0 0 1 2 2v3"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const props = defineProps<{
  src: string
  title?: string
  poster?: string
}>()

const containerRef = ref<HTMLDivElement | null>(null)
const videoRef = ref<HTMLVideoElement | null>(null)
const timelineRef = ref<HTMLDivElement | null>(null)

const isPlaying = ref(false)
const isBuffering = ref(false)
const hasEnded = ref(false)
const currentTime = ref(0)
const duration = ref(0)
const bufferedEnd = ref(0)
const volume = ref(1)
const isMuted = ref(false)
const prevVolume = ref(1)
const playbackRate = ref(1)
const isFullscreen = ref(false)
const controlsVisible = ref(true)
const isVolumeHovered = ref(false)
const timelineHoverTime = ref<number | null>(null)
const timelineHoverPercent = ref(0)
const supportsPiP = ref(false)

let hideControlsTimer: ReturnType<typeof setTimeout> | null = null
let isDraggingSeek = false

const progressPercent = computed(() => {
  if (!duration.value || duration.value === 0) return 0
  return Math.min(100, Math.max(0, (currentTime.value / duration.value) * 100))
})

const bufferedPercent = computed(() => {
  if (!duration.value || duration.value === 0) return 0
  return Math.min(100, Math.max(0, (bufferedEnd.value / duration.value) * 100))
})

function formatTime(seconds: number): string {
  if (!seconds || isNaN(seconds)) return '0:00'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }
  return `${m}:${s.toString().padStart(2, '0')}`
}

function handleUserActivity() {
  controlsVisible.value = true
  if (hideControlsTimer) clearTimeout(hideControlsTimer)
  if (isPlaying.value && !isVolumeHovered.value) {
    hideControlsTimer = setTimeout(() => {
      controlsVisible.value = false
    }, 2400)
  }
}

function handleMouseLeave() {
  if (isPlaying.value) {
    controlsVisible.value = false
  }
}

function togglePlay() {
  const v = videoRef.value
  if (!v) return
  if (v.paused || v.ended) {
    hasEnded.value = false
    v.play().catch((err) => console.error('Video play error:', err))
  } else {
    v.pause()
  }
}

function onPlay() {
  isPlaying.value = true
  hasEnded.value = false
  handleUserActivity()
}

function onPause() {
  isPlaying.value = false
  controlsVisible.value = true
  if (hideControlsTimer) clearTimeout(hideControlsTimer)
}

function onEnded() {
  isPlaying.value = false
  hasEnded.value = true
  controlsVisible.value = true
}

function onTimeUpdate() {
  if (!videoRef.value || isDraggingSeek) return
  currentTime.value = videoRef.value.currentTime
}

function onLoadedMetadata() {
  if (!videoRef.value) return
  duration.value = videoRef.value.duration || 0
}

function onProgress() {
  const v = videoRef.value
  if (!v || !v.buffered.length) return
  bufferedEnd.value = v.buffered.end(v.buffered.length - 1)
}

// ── Timeline Scrubbing ──────────────────────────────────────
function onTimelineHover(e: MouseEvent) {
  const rect = timelineRef.value?.getBoundingClientRect()
  if (!rect || !duration.value) return
  const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left))
  const pct = (x / rect.width) * 100
  timelineHoverPercent.value = pct
  timelineHoverTime.value = (pct / 100) * duration.value
}

function seekAtEvent(e: MouseEvent) {
  const rect = timelineRef.value?.getBoundingClientRect()
  if (!rect || !duration.value || !videoRef.value) return
  const x = Math.max(0, Math.min(rect.width, e.clientX - rect.left))
  const pct = Math.max(0, Math.min(1, x / rect.width))
  const targetTime = pct * duration.value
  videoRef.value.currentTime = targetTime
  currentTime.value = targetTime
}

function startSeek(e: MouseEvent) {
  isDraggingSeek = true
  seekAtEvent(e)

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (isDraggingSeek) {
      seekAtEvent(moveEvent)
    }
  }

  const onMouseUp = () => {
    isDraggingSeek = false
    window.removeEventListener('mousemove', onMouseMove)
    window.removeEventListener('mouseup', onMouseUp)
  }

  window.addEventListener('mousemove', onMouseMove)
  window.addEventListener('mouseup', onMouseUp)
}

// ── Volume Controls ─────────────────────────────────────────
function onVolumeInput(e: Event) {
  const target = e.target as HTMLInputElement
  const val = parseFloat(target.value)
  volume.value = val
  if (videoRef.value) {
    videoRef.value.volume = val
    if (val === 0) {
      videoRef.value.muted = true
      isMuted.value = true
    } else {
      videoRef.value.muted = false
      isMuted.value = false
    }
  }
}

function toggleMute() {
  const v = videoRef.value
  if (!v) return
  if (isMuted.value || volume.value === 0) {
    const restore = prevVolume.value > 0 ? prevVolume.value : 1
    v.volume = restore
    v.muted = false
    volume.value = restore
    isMuted.value = false
  } else {
    prevVolume.value = volume.value
    v.muted = true
    v.volume = 0
    volume.value = 0
    isMuted.value = true
  }
}

// ── Playback Speed ──────────────────────────────────────────
const speeds = [1, 1.25, 1.5, 2, 0.75]
function cycleSpeed() {
  const currentIdx = speeds.indexOf(playbackRate.value)
  const nextIdx = (currentIdx + 1) % speeds.length
  playbackRate.value = speeds[nextIdx]
  if (videoRef.value) {
    videoRef.value.playbackRate = playbackRate.value
  }
}

// ── Fullscreen & PiP ────────────────────────────────────────
async function toggleFullscreen() {
  const container = containerRef.value
  if (!container) return

  if (!document.fullscreenElement) {
    try {
      await container.requestFullscreen()
    } catch {
      // iOS fallback or browser restriction
      if (videoRef.value && (videoRef.value as any).webkitEnterFullscreen) {
        (videoRef.value as any).webkitEnterFullscreen()
      }
    }
  } else {
    await document.exitFullscreen()
  }
}

function onFullscreenChange() {
  isFullscreen.value = Boolean(document.fullscreenElement)
}

async function togglePiP() {
  const v = videoRef.value as any
  if (!v) return
  try {
    if (document.pictureInPictureElement) {
      await document.exitPictureInPicture()
    } else if (v.requestPictureInPicture) {
      await v.requestPictureInPicture()
    }
  } catch (err) {
    console.error('PiP error:', err)
  }
}

// ── Keyboard Shortcuts ──────────────────────────────────────
function handleKeyDown(e: KeyboardEvent) {
  if (['input', 'textarea'].includes((e.target as HTMLElement)?.tagName.toLowerCase())) return

  if (e.key === ' ' || e.key === 'k') {
    e.preventDefault()
    togglePlay()
  } else if (e.key === 'f') {
    e.preventDefault()
    toggleFullscreen()
  } else if (e.key === 'm') {
    e.preventDefault()
    toggleMute()
  } else if (e.key === 'ArrowRight') {
    e.preventDefault()
    if (videoRef.value) videoRef.value.currentTime = Math.min(duration.value, currentTime.value + 5)
  } else if (e.key === 'ArrowLeft') {
    e.preventDefault()
    if (videoRef.value) videoRef.value.currentTime = Math.max(0, currentTime.value - 5)
  }
}

onMounted(() => {
  document.addEventListener('fullscreenchange', onFullscreenChange)
  supportsPiP.value = 'pictureInPictureEnabled' in document
})

onBeforeUnmount(() => {
  document.removeEventListener('fullscreenchange', onFullscreenChange)
  if (hideControlsTimer) clearTimeout(hideControlsTimer)
})
</script>

<style scoped>
.video-player-container {
  position: relative;
  width: 100%;
  max-height: 520px;
  background: #090d16;
  border-radius: 14px;
  overflow: hidden;
  border: 1px solid rgba(108, 99, 255, 0.22);
  outline: none;
  display: flex;
  align-items: center;
  justify-content: center;
  user-select: none;
  box-shadow: 0 4px 24px rgba(15, 23, 42, 0.2);
  margin-bottom: 14px;
}

.video-element {
  width: 100%;
  max-height: 520px;
  height: auto;
  display: block;
  object-fit: contain;
  background: #000;
  cursor: pointer;
}

/* ── Buffering Spinner ───────────────────────────────────── */
.buffering-spinner-wrap {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  pointer-events: none;
  z-index: 4;
}

.buffering-spinner {
  width: 46px;
  height: 46px;
  border: 4px solid rgba(255, 255, 255, 0.2);
  border-top-color: #6c63ff;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* ── Center Play / Replay Button ─────────────────────────── */
.center-play-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.28);
  cursor: pointer;
  z-index: 3;
}

.center-play-btn {
  width: 68px;
  height: 68px;
  border-radius: 50%;
  background: rgba(15, 23, 42, 0.85);
  border: 1.5px solid rgba(255, 255, 255, 0.25);
  color: #ffffff;
  display: grid;
  place-items: center;
  cursor: pointer;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.5), 0 0 20px rgba(108, 99, 255, 0.35);
  backdrop-filter: blur(8px);
  transition: transform 0.2s cubic-bezier(0.175, 0.885, 0.32, 1.275), background 0.2s ease, box-shadow 0.2s ease;
}

.center-play-btn:hover {
  transform: scale(1.1);
  background: #6c63ff;
  border-color: #6c63ff;
  box-shadow: 0 8px 32px rgba(108, 99, 255, 0.6);
}

.center-play-btn svg {
  margin-left: 2px;
}

/* ── Bottom Controls Overlay ─────────────────────────────── */
.video-controls-overlay {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 24px 16px 10px;
  background: linear-gradient(to top, rgba(9, 13, 22, 0.95) 0%, rgba(9, 13, 22, 0.65) 60%, transparent 100%);
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 5;
  transition: opacity 0.25s ease, transform 0.25s ease;
  pointer-events: auto;
}

.video-player-container:not(.controls-visible) .video-controls-overlay {
  opacity: 0;
  transform: translateY(6px);
  pointer-events: none;
}

/* ── Timeline Track ──────────────────────────────────────── */
.timeline-track-wrap {
  position: relative;
  width: 100%;
  height: 18px;
  display: flex;
  align-items: center;
  cursor: pointer;
}

.timeline-track {
  position: relative;
  width: 100%;
  height: 4px;
  background: rgba(255, 255, 255, 0.22);
  border-radius: 999px;
  transition: height 0.15s ease;
}

.timeline-track-wrap:hover .timeline-track {
  height: 6px;
}

.timeline-buffered {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: rgba(255, 255, 255, 0.4);
  border-radius: 999px;
  pointer-events: none;
}

.timeline-played {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: linear-gradient(90deg, #6c63ff, #8b5cf6);
  border-radius: 999px;
  pointer-events: none;
}

.timeline-handle {
  position: absolute;
  top: 50%;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: #ffffff;
  box-shadow: 0 0 6px rgba(0, 0, 0, 0.6), 0 0 10px rgba(108, 99, 255, 0.8);
  transform: translate(-50%, -50%) scale(0);
  transition: transform 0.15s ease;
  pointer-events: none;
}

.timeline-track-wrap:hover .timeline-handle {
  transform: translate(-50%, -50%) scale(1);
}

.timeline-tooltip {
  position: absolute;
  top: -26px;
  transform: translateX(-50%);
  background: rgba(15, 23, 42, 0.95);
  color: #f8fafc;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  border: 1px solid rgba(255, 255, 255, 0.15);
  pointer-events: none;
  white-space: nowrap;
}

/* ── Controls Row ────────────────────────────────────────── */
.controls-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.controls-left,
.controls-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.ctrl-btn {
  background: transparent;
  border: none;
  color: #e2e8f0;
  display: grid;
  place-items: center;
  padding: 4px;
  border-radius: 6px;
  cursor: pointer;
  transition: color 0.15s ease, transform 0.15s ease;
}

.ctrl-btn:hover {
  color: #ffffff;
  transform: scale(1.1);
}

/* Volume Group */
.volume-control-group {
  display: flex;
  align-items: center;
  gap: 6px;
}

.volume-slider-box {
  width: 0;
  overflow: hidden;
  transition: width 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  display: flex;
  align-items: center;
}

.volume-control-group:hover .volume-slider-box,
.volume-slider-box.is-active {
  width: 64px;
}

.volume-range-slider {
  -webkit-appearance: none;
  width: 60px;
  height: 4px;
  background: rgba(255, 255, 255, 0.35);
  border-radius: 999px;
  outline: none;
  cursor: pointer;
}

.volume-range-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: #ffffff;
  cursor: pointer;
}

/* Time Display */
.time-display {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  font-weight: 500;
  color: #cbd5e1;
  font-variant-numeric: tabular-nums;
  margin-left: 4px;
}

.time-sep {
  color: #64748b;
}

/* Speed Button */
.speed-btn {
  font-size: 12px;
  font-weight: 700;
  padding: 2px 6px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 5px;
  color: #cbd5e1;
}

.speed-btn:hover {
  border-color: #6c63ff;
  color: #ffffff;
}

/* Transitions */
.fade-scale-enter-active,
.fade-scale-leave-active {
  transition: all 0.2s ease;
}

.fade-scale-enter-from,
.fade-scale-leave-to {
  opacity: 0;
  transform: scale(0.85);
}
</style>
