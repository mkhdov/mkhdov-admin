import 'package:flutter/material.dart';
import '../models/skill.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_page_shell.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  bool _isLoading = true;
  List<Skill> _skills = [];
  
  final _nameController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isAdding = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetchSkills();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkills() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.from('skills')
          .select('id, name, order_index')
          .order('order_index', ascending: true);
          
      setState(() {
        _skills = (response as List).map((e) => Skill.fromJson(e)).toList();
        _setDefaultOrder();
      });
    } catch (e) {
      debugPrint('Error fetching skills: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _setDefaultOrder() {
    if (_skills.isNotEmpty) {
      final maxOrder = _skills.map((s) => s.orderIndex).reduce((a, b) => a > b ? a : b);
      _orderController.text = (maxOrder + 1).toString();
    } else {
      _orderController.text = '1';
    }
  }

  Future<void> _addSkill() async {
    final name = _nameController.text.trim();
    final orderText = _orderController.text.trim();
    
    if (name.isEmpty || orderText.isEmpty) return;
    
    final targetOrder = int.tryParse(orderText) ?? 1;

    setState(() => _isAdding = true);
    
    try {
      // Check if we need to shift items
      final itemsToShift = _skills.where((s) => s.orderIndex >= targetOrder).toList();
      
      if (itemsToShift.isNotEmpty) {
        final futures = itemsToShift.map((s) {
          return SupabaseService.from('skills')
              .update({'order_index': s.orderIndex + 1})
              .eq('id', s.id);
        });
        await Future.wait(futures);
      }

      final response = await SupabaseService.from('skills')
          .insert({
            'name': name,
            'order_index': targetOrder,
          })
          .select()
          .single();
          
      setState(() {
        _skills.add(Skill.fromJson(response));
        for (var item in itemsToShift) {
          item.orderIndex++;
        }
        _skills.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        _nameController.clear();
        _setDefaultOrder();
      });
    } catch (e) {
      debugPrint('Error adding skill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding skill: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteSkill(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Skill'),
        content: const Text('Are you sure you want to delete this skill?'),
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
      await SupabaseService.from('skills').delete().eq('id', id);
      setState(() {
        _skills.removeWhere((s) => s.id == id);
      });
    } catch (e) {
      debugPrint('Error deleting skill: $e');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _skills.removeAt(oldIndex);
      _skills.insert(newIndex, item);
      
      // Update order index locally
      for (int i = 0; i < _skills.length; i++) {
        _skills[i].orderIndex = i + 1;
      }
    });

    try {
      // Update all changed skills in Supabase
      final futures = _skills.map((s) {
        return SupabaseService.from('skills')
            .update({'order_index': s.orderIndex})
            .eq('id', s.id);
      });
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error updating order: $e');
      // Re-fetch to restore correct state on failure
      _fetchSkills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Stats
          Text(
            '${_skills.length} skill${_skills.length != 1 ? 's' : ''} total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          
          // Add Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                
                final fields = [
                  Expanded(
                    flex: isMobile ? 0 : 3,
                    child: TextField(
                      controller: _nameController,
                      enabled: !_isAdding,
                      decoration: const InputDecoration(
                        hintText: 'New skill name (e.g. Flutter)',
                      ),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  if (isMobile) const SizedBox(height: 12),
                  SizedBox(
                    width: isMobile ? double.infinity : 100,
                    child: TextField(
                      controller: _orderController,
                      enabled: !_isAdding,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Order',
                      ),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  if (isMobile) const SizedBox(height: 12),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    height: isMobile ? 48 : null,
                    child: ElevatedButton.icon(
                      onPressed: _isAdding ? null : _addSkill,
                      icon: _isAdding 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.add, size: 18),
                      label: Text(_isAdding ? 'Adding...' : 'Add'),
                    ),
                  ),
                ];
                
                if (isMobile) {
                  return Column(children: fields);
                } else {
                  return Row(children: fields);
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading skills...')
                : _skills.isEmpty
                    ? const EmptyState(
                        icon: '🛠️',
                        title: 'No skills yet',
                        subtitle: 'Add your first skill above',
                      )
                    : Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent, // Prevents white background while dragging
                        ),
                        child: ReorderableListView.builder(
                          itemCount: _skills.length,
                          onReorder: _onReorder,
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (BuildContext context, Widget? child) {
                                return Material(
                                  elevation: 8,
                                  color: Colors.transparent,
                                  child: child,
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final skill = _skills[index];
                            final isDeleting = _deletingId == skill.id;
                            
                            return Container(
                              key: ValueKey(skill.id),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Opacity(
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
                                      // Drag Handle
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: Icon(Icons.drag_indicator, color: AppColors.textMuted),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Info
                                      Expanded(
                                        child: Text(
                                          skill.name,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: AppColors.textHeadingAlt,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Order Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentDark.withValues(alpha: 0.07),
                                          border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.15)),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Order: ${skill.orderIndex}',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.accentDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Actions
                                      Tooltip(
                                        message: 'Delete',
                                        child: Material(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: const BorderSide(color: AppColors.border),
                                          ),
                                          child: InkWell(
                                            onTap: isDeleting ? null : () => _deleteSkill(skill.id),
                                            borderRadius: BorderRadius.circular(8),
                                            hoverColor: AppColors.errorBg,
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              alignment: Alignment.center,
                                              child: const Text('🗑', style: TextStyle(fontSize: 16)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
