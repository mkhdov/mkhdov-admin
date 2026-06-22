import { supabase } from '../lib/supabase'
import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router'

export const LOGIN_PATH = '/admin/login'
export const DEFAULT_AUTH_REDIRECT = '/admin/dashboard'

export async function getSession() {
  const { data, error } = await supabase.auth.getSession()
  if (error) return null
  return data.session
}

function resolveRedirectTarget(
  redirect: unknown,
  fallback = DEFAULT_AUTH_REDIRECT
) {
  if (typeof redirect !== 'string' || !redirect.startsWith('/admin')) {
    return fallback
  }

  if (redirect === LOGIN_PATH) {
    return fallback
  }

  return redirect
}

export const authGuard = async (
  to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext
) => {
  const session = await getSession()

  if (session) {
    next()
    return
  }

  next({
    path: LOGIN_PATH,
    query: {
      redirect: to.fullPath !== LOGIN_PATH ? to.fullPath : DEFAULT_AUTH_REDIRECT,
    },
  })
}

export const guestGuard = async (
  to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext
) => {
  const session = await getSession()

  if (session) {
    next(resolveRedirectTarget(to.query.redirect))
    return
  }

  next()
}

import type { Router } from 'vue-router'

export function setupAuthListener(router: Router) {
  supabase.auth.onAuthStateChange((event, session) => {
    const route = router.currentRoute.value
    const requiresAuth = route.matched.some((record) => record.meta.requiresAuth)

    if (event === 'SIGNED_OUT' && requiresAuth) {
      router.push(LOGIN_PATH)
      return
    }

    if (event === 'SIGNED_IN' && route.meta.guestOnly) {
      router.push(resolveRedirectTarget(route.query.redirect))
      return
    }

    if (event === 'TOKEN_REFRESHED' && !session && requiresAuth) {
      router.push(LOGIN_PATH)
    }
  })
}
