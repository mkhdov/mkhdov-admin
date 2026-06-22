<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { DEFAULT_AUTH_REDIRECT } from '../router/guards'

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)
const showPassword = ref(false)

const router = useRouter()
const route = useRoute()

const resolveRedirect = () => {
  const redirect = route.query.redirect
  if (typeof redirect === 'string' && redirect.startsWith('/admin') && redirect !== '/admin/login') {
    return redirect
  }
  return DEFAULT_AUTH_REDIRECT
}

const login = async () => {
  if (loading.value) return

  const trimmedEmail = email.value.trim()
  if (!trimmedEmail || !password.value) {
    error.value = 'Please enter your email and password.'
    return
  }

  loading.value = true
  error.value = ''

  const { error: authError } = await supabase.auth.signInWithPassword({
    email: trimmedEmail,
    password: password.value,
  })

  if (authError) {
    error.value = 'Invalid email or password. Please try again.'
    loading.value = false
    return
  }

  await router.push(resolveRedirect())
}

const onSubmit = (event: Event) => {
  event.preventDefault()
  login()
}
</script>

<template>
  <div class="login-page">
    <div class="login-bg">
      <div class="login-bg__orb login-bg__orb--one" />
      <div class="login-bg__orb login-bg__orb--two" />
    </div>

    <main class="login-shell">
      <section class="login-card">
        <header class="login-card__header">
          <div class="login-card__badge">Portfolio Admin</div>
          <h1>Welcome back</h1>
          <p>Sign in to manage your portfolio content, projects, and articles.</p>
        </header>

        <form class="login-form" @submit="onSubmit">
          <label class="field">
            <span>Email address</span>
            <input
              v-model="email"
              type="email"
              name="email"
              autocomplete="email"
              placeholder="you@example.com"
              :disabled="loading"
              required
            />
          </label>

          <label class="field">
            <span>Password</span>
            <div class="password-wrap">
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                name="password"
                autocomplete="current-password"
                placeholder="Enter your password"
                :disabled="loading"
                required
              />
              <button
                type="button"
                class="password-toggle"
                :aria-label="showPassword ? 'Hide password' : 'Show password'"
                :disabled="loading"
                @click="showPassword = !showPassword"
              >
                {{ showPassword ? 'Hide' : 'Show' }}
              </button>
            </div>
          </label>

          <p v-if="error" class="error" role="alert">{{ error }}</p>

          <button class="submit-btn" type="submit" :disabled="loading">
            <span v-if="loading" class="submit-btn__spinner" aria-hidden="true" />
            {{ loading ? 'Signing in...' : 'Sign in' }}
          </button>
        </form>

        <footer class="login-card__footer">
          <p>Protected area for portfolio administrators only.</p>
        </footer>
      </section>
    </main>
  </div>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&display=swap');

.login-page {
  --accent: #6c63ff;
  --accent-light: #a78bfa;
  --accent-soft: rgba(108, 99, 255, 0.1);
  --accent-border: rgba(108, 99, 255, 0.22);
  --text: #64748b;
  --text-h: #1a1a2e;
  --surface: rgba(255, 255, 255, 0.92);
  --shadow: 0 24px 70px rgba(15, 23, 42, 0.14), 0 3px 12px rgba(108, 99, 255, 0.12);

  position: relative;
  min-height: 100svh;
  display: grid;
  place-items: center;
  padding: 24px;
  overflow: hidden;
  background:
    linear-gradient(180deg, #ffffff 0%, #f8fafc 44%, #ffffff 100%);
  font-family: 'Inter', system-ui, sans-serif;
  color: var(--text);
}

.login-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.login-bg__orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(2px);
}

.login-bg__orb--one {
  width: 420px;
  height: 420px;
  top: -120px;
  right: -80px;
  background: radial-gradient(circle, rgba(108, 99, 255, 0.16) 0%, transparent 70%);
}

.login-bg__orb--two {
  width: 360px;
  height: 360px;
  bottom: -100px;
  left: -60px;
  background: radial-gradient(circle, rgba(167, 139, 250, 0.14) 0%, transparent 70%);
}

.login-shell {
  position: relative;
  z-index: 1;
  width: min(100%, 440px);
}

.login-card {
  background: var(--surface);
  border: 1px solid rgba(255, 255, 255, 0.72);
  border-radius: 24px;
  box-shadow: var(--shadow);
  backdrop-filter: blur(14px);
  padding: 36px 32px 28px;
}

.login-card__header {
  text-align: center;
  margin-bottom: 28px;
}

.login-card__badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 6px 12px;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--accent);
  background: var(--accent-soft);
  border: 1px solid var(--accent-border);
  margin-bottom: 18px;
}

.login-card__header h1 {
  margin: 0 0 10px;
  font-family: 'Space Grotesk', system-ui, sans-serif;
  font-size: 1.85rem;
  line-height: 1.15;
  letter-spacing: -0.03em;
  color: var(--text-h);
}

.login-card__header p {
  margin: 0;
  font-size: 0.95rem;
  line-height: 1.55;
}

.login-form {
  display: grid;
  gap: 18px;
}

.field {
  display: grid;
  gap: 8px;
  text-align: left;
}

.field span {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-h);
}

.field input {
  width: 100%;
  height: 48px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid var(--accent-border);
  background: #ffffff;
  color: var(--text-h);
  font: inherit;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.field input::placeholder {
  color: #94a3b8;
}

.field input:focus {
  outline: none;
  border-color: rgba(108, 99, 255, 0.55);
  box-shadow: 0 0 0 4px rgba(108, 99, 255, 0.12);
}

.field input:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.password-wrap {
  position: relative;
}

.password-wrap input {
  padding-right: 72px;
}

.password-toggle {
  position: absolute;
  top: 50%;
  right: 10px;
  transform: translateY(-50%);
  border: none;
  background: transparent;
  color: var(--accent);
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  padding: 6px 8px;
}

.password-toggle:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error {
  margin: 0;
  padding: 10px 12px;
  border-radius: 10px;
  font-size: 0.875rem;
  color: #b42318;
  background: rgba(244, 63, 94, 0.08);
  border: 1px solid rgba(244, 63, 94, 0.18);
}

.submit-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  width: 100%;
  height: 48px;
  margin-top: 4px;
  border: none;
  border-radius: 12px;
  font: inherit;
  font-weight: 600;
  color: #ffffff;
  cursor: pointer;
  background: linear-gradient(135deg, #6c63ff 0%, #818cf8 100%);
  box-shadow: 0 4px 20px rgba(108, 99, 255, 0.32);
  transition: transform 0.18s ease, box-shadow 0.18s ease, opacity 0.18s ease;
}

.submit-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 8px 30px rgba(108, 99, 255, 0.42);
}

.submit-btn:disabled {
  opacity: 0.75;
  cursor: not-allowed;
}

.submit-btn__spinner {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #ffffff;
  animation: spin 0.8s linear infinite;
}

.login-card__footer {
  margin-top: 22px;
  padding-top: 18px;
  border-top: 1px solid rgba(108, 99, 255, 0.1);
  text-align: center;
}

.login-card__footer p {
  margin: 0;
  font-size: 0.8125rem;
  color: #94a3b8;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 480px) {
  .login-page {
    padding: 16px;
  }

  .login-card {
    padding: 28px 20px 22px;
    border-radius: 20px;
  }

  .login-card__header h1 {
    font-size: 1.6rem;
  }
}
</style>
