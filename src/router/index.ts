import { createRouter, createWebHistory } from 'vue-router'
import { authGuard, guestGuard, getSession, setupAuthListener } from './guards'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      redirect: '/admin/login',
    },
    {
      path: '/admin/login',
      name: 'admin-login',
      component: () => import('../views/AdminLogin.vue'),
      meta: { guestOnly: true },
      beforeEnter: guestGuard,
    },
    {
      path: '/admin',
      component: () => import('../layouts/AdminLayout.vue'),
      meta: { requiresAuth: true },
      beforeEnter: authGuard,
      children: [
        {
          path: '',
          redirect: '/admin/dashboard',
        },
        {
          path: 'dashboard',
          name: 'admin-dashboard',
          component: () => import('../views/admin/DashboardView.vue'),
          meta: { requiresAuth: true, title: 'Dashboard' },
        },
        {
          path: 'articles',
          name: 'admin-articles',
          component: () => import('../views/admin/ArticlesView.vue'),
          meta: { requiresAuth: true, title: 'Articles' },
        },
        {
          path: 'articles/new',
          name: 'admin-articles-new',
          component: () => import('../views/admin/ArticleEditorView.vue'),
          meta: { requiresAuth: true, title: 'New Article' },
        },
        {
          path: 'articles/:id',
          name: 'admin-articles-edit',
          component: () => import('../views/admin/ArticleEditorView.vue'),
          meta: { requiresAuth: true, title: 'Edit Article' },
        },
        {
          path: 'blog',
          name: 'admin-blog',
          component: () => import('../views/admin/BlogView.vue'),
          meta: { requiresAuth: true, title: 'Blog' },
        },
        {
          path: 'inbox',
          name: 'admin-inbox',
          component: () => import('../views/admin/InboxView.vue'),
          meta: { requiresAuth: true, title: 'Inbox' },
        },
        {
          path: 'projects',
          name: 'admin-projects',
          component: () => import('../views/admin/ProjectsView.vue'),
          meta: { requiresAuth: true, title: 'Projects' },
        },
        {
          path: 'skills',
          name: 'admin-skills',
          component: () => import('../views/admin/SkillsView.vue'),
          meta: { requiresAuth: true, title: 'Skills' },
        },
        {
          path: 'portfolio',
          name: 'admin-portfolio',
          component: () => import('../views/admin/PortfolioView.vue'),
          meta: { requiresAuth: true, title: 'Portfolio' },
        },
        {
          path: 'about',
          name: 'admin-about',
          component: () => import('../views/admin/AboutView.vue'),
          meta: { requiresAuth: true, title: 'About' },
        },
        {
          path: 'media',
          name: 'admin-media',
          component: () => import('../views/admin/MediaView.vue'),
          meta: { requiresAuth: true, title: 'Media' },
        },
        {
          path: 'settings',
          name: 'admin-settings',
          component: () => import('../views/admin/SettingsView.vue'),
          meta: { requiresAuth: true, title: 'Settings' },
        },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/admin/login',
    },
  ],
})

router.beforeEach(async (to) => {
  const requiresAuth = to.matched.some((record) => record.meta.requiresAuth)
  const guestOnly = to.matched.some((record) => record.meta.guestOnly)

  if (!requiresAuth && !guestOnly) {
    return true
  }

  const session = await getSession()

  if (requiresAuth && !session) {
    return {
      path: '/admin/login',
      query: {
        redirect: to.fullPath !== '/admin/login' ? to.fullPath : '/admin/dashboard',
      },
    }
  }

  if (guestOnly && session) {
    const redirect =
      typeof to.query.redirect === 'string' && to.query.redirect.startsWith('/admin')
        ? to.query.redirect
        : '/admin/dashboard'

    return redirect === '/admin/login' ? '/admin/dashboard' : redirect
  }

  return true
})

setupAuthListener(router)

export default router
