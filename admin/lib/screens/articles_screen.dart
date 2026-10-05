import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_page_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  bool _isLoading = true;
  List<Article> _articles = [];
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetchArticles();
  }

  Future<void> _fetchArticles() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.from('articles')
          .select('id, title, published, created_at, cover_image_url')
          .order('created_at', ascending: false);
          
      setState(() {
        _articles = (response as List).map((e) => Article.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching articles: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePublished(Article article) async {
    try {
      await SupabaseService.from('articles')
          .update({'published': !article.published})
          .eq('id', article.id);
          
      setState(() {
        final index = _articles.indexWhere((a) => a.id == article.id);
        if (index != -1) {
          _articles[index] = Article(
            id: article.id,
            title: article.title,
            published: !article.published,
            createdAt: article.createdAt,
            coverImageUrl: article.coverImageUrl,
          );
        }
      });
    } catch (e) {
      debugPrint('Error toggling publish: $e');
    }
  }

  Future<void> _deleteArticle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('Are you sure you want to delete this article?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingId = id);
    try {
      await SupabaseService.from('articles').delete().eq('id', id);
      setState(() {
        _articles.removeWhere((a) => a.id == id);
      });
    } catch (e) {
      debugPrint('Error deleting article: $e');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Articles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_articles.length} article${_articles.length != 1 ? 's' : ''} total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/articles/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Article'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading articles...')
                : _articles.isEmpty
                    ? EmptyState(
                        icon: '📝',
                        title: 'No articles yet',
                        subtitle: 'Start writing your first article',
                        action: ElevatedButton(
                          onPressed: () => context.go('/admin/articles/new'),
                          child: const Text('Write your first article'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _articles.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final article = _articles[index];
                          final isDeleting = _deletingId == article.id;
                          
                          return Opacity(
                            opacity: isDeleting ? 0.5 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  // Cover
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.border,
                                      borderRadius: BorderRadius.circular(8),
                                      image: article.coverImageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(article.coverImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: article.coverImageUrl == null
                                        ? const Center(child: Text('📄', style: TextStyle(fontSize: 24)))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          article.title,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: AppColors.textHeadingAlt,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM d, yyyy').format(DateTime.parse(article.createdAt)),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Status Badge
                                  StatusBadge(status: article.published ? 'Published' : 'Draft'),
                                  const SizedBox(width: 16),
                                  
                                  // Actions
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildActionButton(
                                        icon: '👁',
                                        tooltip: 'Preview',
                                        onTap: () {
                                          // Preview route (would usually open in browser or in-app web view)
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: '✏️',
                                        tooltip: 'Edit',
                                        onTap: () => context.go('/admin/articles/${article.id}'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: article.published ? '🔒' : '🚀',
                                        tooltip: article.published ? 'Unpublish' : 'Publish',
                                        onTap: () => _togglePublished(article),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: '🗑',
                                        tooltip: 'Delete',
                                        onTap: isDeleting ? null : () => _deleteArticle(article.id),
                                        isDanger: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDanger ? AppColors.errorBg : AppColors.accent.withValues(alpha: 0.08),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
