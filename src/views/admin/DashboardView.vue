<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { supabase } from '../../lib/supabase.ts'
import { Line, Bar, Doughnut } from 'vue-chartjs'
import {
  Chart as ChartJS,
  LineElement,
  BarElement,
  ArcElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler
} from 'chart.js'

ChartJS.register(LineElement, BarElement, ArcElement, PointElement, LinearScale, CategoryScale, Tooltip, Legend, Filler)

// ── Time range ──────────────────────────────────────────────
type Range = '7d' | '30d' | 'all'
const activeRange = ref<Range>('7d')
const ranges: { label: string; value: Range }[] = [
  { label: 'Last 7 days',  value: '7d'  },
  { label: 'Last 30 days', value: '30d' },
  { label: 'All time',     value: 'all' },
]

// ── State ────────────────────────────────────────────────────
const totalToday     = ref(0)
const totalWeek      = ref(0)
const totalMonth     = ref(0)
const totalAllTime   = ref(0)
const unreadMessages = ref(0)
const chartData      = ref<{ day: string; count: number }[]>([])
const pageBreakdown  = ref<Record<string, number>>({})
const hourlyData     = ref<number[]>(new Array(24).fill(0))
const loading        = ref(true)
const chartLoading   = ref(false)

// ── Helpers ──────────────────────────────────────────────────
function getRangeStart(range: Range): Date | null {
  if (range === 'all') return null
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  d.setDate(d.getDate() - (range === '7d' ? 6 : 29))
  return d
}

function groupByDay(views: { visited_at: string }[], rangeStart: Date | null) {
  const grouped: Record<string, number> = {}
  views.forEach(v => {
    const d = new Date(v.visited_at)
    if (rangeStart && d < rangeStart) return
    const key = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
    grouped[key] = (grouped[key] ?? 0) + 1
  })
  return Object.entries(grouped).map(([day, count]) => ({ day, count }))
}

// ── Load static stat cards (always full counts) ─────────────
async function loadStatCards() {
  const now = new Date()

  const startOfDay = new Date(now); startOfDay.setHours(0,0,0,0)
  const startOfWeek = new Date(); startOfWeek.setDate(startOfWeek.getDate() - 6); startOfWeek.setHours(0,0,0,0)
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)

  const [
    { count: todayCount },
    { count: weekCount },
    { count: monthCount },
    { count: allCount },
    { count: msgCount },
  ] = await Promise.all([
    supabase.from('page_views').select('*', { count: 'exact', head: true }).gte('visited_at', startOfDay.toISOString()),
    supabase.from('page_views').select('*', { count: 'exact', head: true }).gte('visited_at', startOfWeek.toISOString()),
    supabase.from('page_views').select('*', { count: 'exact', head: true }).gte('visited_at', startOfMonth.toISOString()),
    supabase.from('page_views').select('*', { count: 'exact', head: true }),
    supabase.from('messages').select('*', { count: 'exact', head: true }).eq('read', false),
  ])

  totalToday.value    = todayCount   ?? 0
  totalWeek.value     = weekCount    ?? 0
  totalMonth.value    = monthCount   ?? 0
  totalAllTime.value  = allCount     ?? 0
  unreadMessages.value = msgCount    ?? 0

  // Hourly for today
  const { data: todayViews } = await supabase
      .from('page_views')
      .select('visited_at')
      .gte('visited_at', startOfDay.toISOString())

  const hourly = new Array(24).fill(0)
  todayViews?.forEach(v => { hourly[new Date(v.visited_at).getHours()]++ })
  hourlyData.value = hourly
}

// ── Load chart data based on range ──────────────────────────
async function loadChartData(range: Range) {
  chartLoading.value = true
  const rangeStart = getRangeStart(range)

  let query = supabase.from('page_views').select('visited_at, page').order('visited_at')
  if (rangeStart) query = query.gte('visited_at', rangeStart.toISOString())

  const { data: views } = await query

  chartData.value = groupByDay(views ?? [], rangeStart)

  const pages: Record<string, number> = {}
  views?.forEach(v => {
    const page = v.page || '/'
    pages[page] = (pages[page] ?? 0) + 1
  })
  pageBreakdown.value = pages
  chartLoading.value = false
}

onMounted(async () => {
  await Promise.all([loadStatCards(), loadChartData(activeRange.value)])
  loading.value = false
})

watch(activeRange, (range) => loadChartData(range))

// ── Chart configs ────────────────────────────────────────────
const lineChartData = computed(() => ({
  labels: chartData.value.map(d => d.day),
  datasets: [{
    label: 'Visits',
    data: chartData.value.map(d => d.count),
    borderColor: '#6366f1',
    backgroundColor: 'rgba(99,102,241,0.07)',
    pointBackgroundColor: '#6366f1',
    pointRadius: 4,
    pointHoverRadius: 7,
    tension: 0.45,
    fill: true,
  }]
}))

const lineChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1e1b4b', titleColor: '#c7d2fe', bodyColor: '#fff', padding: 12, cornerRadius: 8 }
  },
  scales: {
    x: { grid: { display: false }, ticks: { color: '#94a3b8', maxTicksLimit: 10 } },
    y: { grid: { color: '#f1f5f9' }, ticks: { color: '#94a3b8', stepSize: 1 } }
  }
}

const barChartData = computed(() => ({
  labels: hourlyData.value.map((_, i) => `${i}:00`),
  datasets: [{
    label: 'Visits',
    data: hourlyData.value,
    backgroundColor: hourlyData.value.map((_, i) =>
        i % 2 === 0 ? 'rgba(99,102,241,0.65)' : 'rgba(168,85,247,0.65)'
    ),
    borderRadius: 6,
    borderSkipped: false,
  }]
}))

const barChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1e1b4b', titleColor: '#c7d2fe', bodyColor: '#fff', padding: 12, cornerRadius: 8 }
  },
  scales: {
    x: { grid: { display: false }, ticks: { color: '#94a3b8', font: { size: 10 }, maxTicksLimit: 12 } },
    y: { grid: { color: '#f1f5f9' }, ticks: { color: '#94a3b8', stepSize: 1 } }
  }
}

const doughnutData = computed(() => {
  const entries = Object.entries(pageBreakdown.value)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6)
  return {
    labels: entries.map(([page]) => page),
    datasets: [{
      data: entries.map(([, count]) => count),
      backgroundColor: [
        'rgba(99,102,241,0.75)',
        'rgba(168,85,247,0.75)',
        'rgba(236,72,153,0.75)',
        'rgba(245,158,11,0.75)',
        'rgba(16,185,129,0.75)',
        'rgba(59,130,246,0.75)',
      ],
      borderColor: '#fff',
      borderWidth: 3,
      hoverOffset: 10,
    }]
  }
})

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom' as const,
      labels: { color: '#64748b', padding: 14, font: { size: 12 }, usePointStyle: true, pointStyleWidth: 8 }
    },
    tooltip: { backgroundColor: '#1e1b4b', titleColor: '#c7d2fe', bodyColor: '#fff', padding: 12, cornerRadius: 8 }
  }
}

const stats = computed(() => [
  { label: 'Today',           value: totalToday.value,    color: '#6366f1', bg: 'rgba(99,102,241,0.07)',  icon: '👁️' },
  { label: 'This Week',       value: totalWeek.value,     color: '#a855f7', bg: 'rgba(168,85,247,0.07)', icon: '📅' },
  { label: 'This Month',      value: totalMonth.value,    color: '#ec4899', bg: 'rgba(236,72,153,0.07)', icon: '📆' },
  { label: 'All Time',        value: totalAllTime.value,  color: '#f59e0b', bg: 'rgba(245,158,11,0.07)', icon: '🌍' },
  { label: 'Unread Messages', value: unreadMessages.value,color: '#10b981', bg: 'rgba(16,185,129,0.07)', icon: '✉️' },
])

const rangeTitleMap: Record<Range, string> = {
  '7d':  'Last 7 Days',
  '30d': 'Last 30 Days',
  'all': 'All Time',
}
</script>

<template>
  <div class="dashboard">

    <!-- Header -->
    <div class="dash-header">
      <div>
        <h1 class="dash-title">Dashboard</h1>
        <p class="dash-sub">Portfolio analytics overview</p>
      </div>
      <div class="dash-date">
        {{ new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }) }}
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="loading-state">
      <div class="spinner"></div>
      <p>Loading analytics...</p>
    </div>

    <template v-else>

      <!-- Stat Cards -->
      <div class="stat-grid">
        <div
            v-for="stat in stats"
            :key="stat.label"
            class="stat-card"
            :style="{ '--accent': stat.color, '--bg': stat.bg }"
        >
          <div class="stat-icon">{{ stat.icon }}</div>
          <div class="stat-info">
            <span class="stat-value">{{ stat.value.toLocaleString() }}</span>
            <span class="stat-label">{{ stat.label }}</span>
          </div>
          <div class="stat-bar" :style="{ background: stat.color }"></div>
        </div>
      </div>

      <!-- Range Filter -->
      <div class="range-bar">
        <span class="range-label">Showing:</span>
        <div class="range-pills">
          <button
              v-for="r in ranges"
              :key="r.value"
              class="range-pill"
              :class="{ active: activeRange === r.value }"
              @click="activeRange = r.value"
          >
            {{ r.label }}
          </button>
        </div>
      </div>

      <!-- Charts Row 1 -->
      <div class="chart-row">

        <!-- Line Chart -->
        <div class="chart-card wide">
          <div class="chart-header">
            <h2 class="chart-title">Visits — {{ rangeTitleMap[activeRange] }}</h2>
            <span class="chart-badge indigo">Daily</span>
          </div>
          <div class="chart-body" :class="{ dimmed: chartLoading }">
            <Line :data="lineChartData" :options="lineChartOptions" />
          </div>
        </div>

        <!-- Doughnut -->
        <div class="chart-card narrow">
          <div class="chart-header">
            <h2 class="chart-title">Pages Visited</h2>
            <span class="chart-badge purple">Breakdown</span>
          </div>
          <div class="chart-body" :class="{ dimmed: chartLoading }">
            <Doughnut :data="doughnutData" :options="doughnutOptions" />
          </div>
        </div>

      </div>

      <!-- Charts Row 2 -->
      <div class="chart-row">
        <div class="chart-card full">
          <div class="chart-header">
            <h2 class="chart-title">Hourly Traffic — Today</h2>
            <span class="chart-badge pink">24h</span>
          </div>
          <div class="chart-body tall">
            <Bar :data="barChartData" :options="barChartOptions" />
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.dashboard {
  min-height: 100vh;
  background: #ffffff;
  padding: 2rem 2.5rem;
  font-family: 'Inter', system-ui, sans-serif;
}

/* Header */
.dash-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 2rem;
}
.dash-title {
  font-size: 1.75rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 0.25rem;
}
.dash-sub {
  font-size: 0.9rem;
  color: #94a3b8;
  margin: 0;
}
.dash-date {
  font-size: 0.85rem;
  color: #94a3b8;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  padding: 0.5rem 1rem;
  border-radius: 999px;
}

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
  width: 40px;
  height: 40px;
  border: 3px solid #e2e8f0;
  border-top-color: #6366f1;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Stat Grid */
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.stat-card {
  background: var(--bg);
  border-radius: 16px;
  padding: 1.25rem 1.25rem 1rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(0,0,0,0.04);
  transition: transform 0.2s, box-shadow 0.2s;
}
.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.07);
}
.stat-icon { font-size: 1.5rem; line-height: 1; }
.stat-info { display: flex; flex-direction: column; }
.stat-value {
  font-size: 1.6rem;
  font-weight: 800;
  color: var(--accent);
  line-height: 1.1;
}
.stat-label {
  font-size: 0.75rem;
  color: #64748b;
  margin-top: 0.2rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.stat-bar {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  height: 3px;
  opacity: 0.4;
  border-radius: 0 0 16px 16px;
}

/* Range Filter */
.range-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
}
.range-label {
  font-size: 0.82rem;
  color: #94a3b8;
  font-weight: 500;
}
.range-pills {
  display: flex;
  gap: 0.4rem;
}
.range-pill {
  font-size: 0.82rem;
  font-weight: 500;
  padding: 0.35rem 0.9rem;
  border-radius: 999px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  color: #64748b;
  cursor: pointer;
  transition: all 0.18s;
}
.range-pill:hover {
  border-color: #c7d2fe;
  color: #6366f1;
  background: #eef2ff;
}
.range-pill.active {
  background: #6366f1;
  color: #fff;
  border-color: #6366f1;
}

/* Charts */
.chart-row {
  display: flex;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
  min-width: 0;
}
.chart-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 20px;
  padding: 1.5rem;
  box-shadow: 0 2px 12px rgba(0,0,0,0.04);
  min-width: 0;
}
.chart-card.wide   { flex: 2; min-width: 0; }
.chart-card.narrow { flex: 1; min-width: 0; }
.chart-card.full   { flex: 1; min-width: 0; }

.chart-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.25rem;
}
.chart-title {
  font-size: 1rem;
  font-weight: 600;
  color: #0f172a;
  margin: 0;
}
.chart-badge {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 999px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.chart-badge.indigo { background: rgba(99,102,241,0.1);  color: #6366f1; }
.chart-badge.purple { background: rgba(168,85,247,0.1);  color: #a855f7; }
.chart-badge.pink   { background: rgba(236,72,153,0.1);  color: #ec4899; }

.chart-body {
  height: 240px;
  position: relative;
  transition: opacity 0.2s;
}
.chart-body.tall   { height: 200px; }
.chart-body.dimmed { opacity: 0.4; pointer-events: none; }

@media (max-width: 768px) {
  .dashboard  { padding: 1.25rem; }
  .chart-row  { flex-direction: column; }
  .stat-grid  { grid-template-columns: repeat(2, 1fr); }
  .dash-header { flex-direction: column; gap: 0.75rem; }
  .range-bar  { flex-wrap: wrap; }
}
</style>