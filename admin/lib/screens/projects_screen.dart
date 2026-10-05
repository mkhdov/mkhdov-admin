import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/project.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_page_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isLoading = true;
  List<Project> _projects = [];
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.from('projects')
          .select('id, title, description, published, featured, tech_stack, cover_image_url, live_url, github_url, order_index, created_at')
          .order('order_index', ascending: true);
          
      setState(() {
        _projects = (response as List).map((e) => Project.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePublished(Project project) async {
    try {
      await SupabaseService.from('projects')
          .update({'published': !project.published})
          .eq('id', project.id);
          
      setState(() {
        final index = _projects.indexWhere((p) => p.id == project.id);
        if (index != -1) {
          _projects[index] = Project(
            id: project.id,
            title: project.title,
            description: project.description,
            content: project.content,
            published: !project.published,
            featured: project.featured,
            techStack: project.techStack,
            coverImageUrl: project.coverImageUrl,
            liveUrl: project.liveUrl,
            githubUrl: project.githubUrl,
            orderIndex: project.orderIndex,
            createdAt: project.createdAt,
          );
        }
      });
    } catch (e) {
      debugPrint('Error toggling publish: $e');
    }
  }

  Future<void> _toggleFeatured(Project project) async {
    try {
      await SupabaseService.from('projects')
          .update({'featured': !project.featured})
          .eq('id', project.id);
          
      setState(() {
        final index = _projects.indexWhere((p) => p.id == project.id);
        if (index != -1) {
          _projects[index] = Project(
            id: project.id,
            title: project.title,
            description: project.description,
            content: project.content,
            published: project.published,
            featured: !project.featured,
            techStack: project.techStack,
            coverImageUrl: project.coverImageUrl,
            liveUrl: project.liveUrl,
            githubUrl: project.githubUrl,
            orderIndex: project.orderIndex,
            createdAt: project.createdAt,
          );
        }
      });
    } catch (e) {
      debugPrint('Error toggling featured: $e');
    }
  }

  Future<void> _deleteProject(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project?'),
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
      await SupabaseService.from('projects').delete().eq('id', id);
      setState(() {
        _projects.removeWhere((p) => p.id == id);
      });
    } catch (e) {
      debugPrint('Error deleting project: $e');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }
  
  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Projects',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_projects.length} project${_projects.length != 1 ? 's' : ''} total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/admin/projects/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Project'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading projects...')
                : _projects.isEmpty
                    ? EmptyState(
                        icon: '🚀',
                        title: 'No projects yet',
                        subtitle: 'Add your first project to showcase your work',
                        action: ElevatedButton(
                          onPressed: () => context.go('/admin/projects/new'),
                          child: const Text('Add your first project'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _projects.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final project = _projects[index];
                          final isDeleting = _deletingId == project.id;
                          
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
                                    width: 64,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.border,
                                      borderRadius: BorderRadius.circular(8),
                                      image: project.coverImageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(project.coverImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: project.coverImageUrl == null
                                        ? const Center(child: Text('🖥️', style: TextStyle(fontSize: 24)))
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                project.title,
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: AppColors.textHeadingAlt,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (project.featured) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.warning.withValues(alpha: 0.1),
                                                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '⭐ Featured',
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                    color: AppColors.warning,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('MMM d, yyyy').format(DateTime.parse(project.createdAt)),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                            if (project.techStack != null && project.techStack!.isNotEmpty) ...[
                                              const SizedBox(width: 12),
                                              ...project.techStack!.take(3).map((t) => Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accentDark.withValues(alpha: 0.07),
                                                    border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.15)),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    t,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: AppColors.accentDark,
                                                    ),
                                                  ),
                                                ),
                                              )),
                                              if (project.techStack!.length > 3)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.textMuted.withValues(alpha: 0.08),
                                                    border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    '+${project.techStack!.length - 3}',
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Status Badge
                                  StatusBadge(status: project.published ? 'Published' : 'Draft'),
                                  const SizedBox(width: 16),
                                  
                                  // Actions
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (project.liveUrl != null && project.liveUrl!.isNotEmpty) ...[
                                        _buildActionButton(
                                          icon: '🔗',
                                          tooltip: 'Live Demo',
                                          onTap: () => _launchUrl(project.liveUrl),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (project.githubUrl != null && project.githubUrl!.isNotEmpty) ...[
                                        _buildActionButton(
                                          icon: LucideIcons.github, // Or a custom svg
                                          tooltip: 'GitHub',
                                          onTap: () => _launchUrl(project.githubUrl),
                                          isIconData: true,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      _buildActionButton(
                                        icon: '✏️',
                                        tooltip: 'Edit',
                                        onTap: () => context.go('/admin/projects/${project.id}'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: project.featured ? '★' : '☆',
                                        tooltip: project.featured ? 'Unfeature' : 'Feature',
                                        onTap: () => _toggleFeatured(project),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: project.published ? '🔒' : '🚀',
                                        tooltip: project.published ? 'Unpublish' : 'Publish',
                                        onTap: () => _togglePublished(project),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildActionButton(
                                        icon: '🗑',
                                        tooltip: 'Delete',
                                        onTap: isDeleting ? null : () => _deleteProject(project.id),
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
    required dynamic icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool isDanger = false,
    bool isIconData = false,
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
            child: isIconData 
                ? Icon(icon as IconData, size: 16, color: AppColors.textHeadingAlt)
                : Text(icon.toString(), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
