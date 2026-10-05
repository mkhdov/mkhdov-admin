import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ProjectEditorScreen extends StatefulWidget {
  final String? id;

  const ProjectEditorScreen({super.key, this.id});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _liveUrlController = TextEditingController();
  final _githubUrlController = TextEditingController();
  final _orderController = TextEditingController();
  
  final QuillController _quillController = QuillController.basic();
  
  bool _isEdit = false;
  String _coverImageUrl = '';
  bool _published = false;
  bool _featured = false;
  List<String> _techStack = [];
  bool _saving = false;
  bool _uploadingImage = false;
  String _saveMsg = '';
  
  final _techInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEdit = widget.id != null;
    if (_isEdit) {
      _loadProject();
    } else {
      _orderController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _liveUrlController.dispose();
    _githubUrlController.dispose();
    _orderController.dispose();
    _techInputController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    try {
      final response = await SupabaseService.from('projects')
          .select('*')
          .eq('id', widget.id!)
          .single();

      setState(() {
        _titleController.text = response['title'] ?? '';
        _descriptionController.text = response['description'] ?? '';
        _liveUrlController.text = response['live_url'] ?? '';
        _githubUrlController.text = response['github_url'] ?? '';
        _orderController.text = (response['order_index'] ?? 0).toString();
        
        _coverImageUrl = response['cover_image_url'] ?? '';
        _published = response['published'] ?? false;
        _featured = response['featured'] ?? false;
        _techStack = (response['tech_stack'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
        
        if (response['content'] != null) {
           _quillController.document = Document()..insert(0, response['content']); 
        }
      });
    } catch (e) {
      debugPrint('Error loading project: $e');
    }
  }

  Future<void> _uploadCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    setState(() => _uploadingImage = true);
    
    try {
      final path = 'covers/projects-${DateTime.now().millisecondsSinceEpoch}-${image.name}';
      final bytes = await image.readAsBytes();
      
      await SupabaseService.storage.from('article-images').uploadBinary(path, bytes);
      
      final url = SupabaseService.storage.from('article-images').getPublicUrl(path);
      
      setState(() {
        _coverImageUrl = url;
      });
    } catch (e) {
      debugPrint('Error uploading cover: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _addTech() {
    final tech = _techInputController.text.trim();
    if (tech.isNotEmpty && !_techStack.contains(tech)) {
      setState(() {
        _techStack.add(tech);
        _techInputController.clear();
      });
    }
  }

  void _removeTech(String tech) {
    setState(() {
      _techStack.remove(tech);
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    setState(() {
      _saving = true;
      _saveMsg = '';
    });

    try {
      final content = _quillController.document.toPlainText();
      
      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'content': content,
        'cover_image_url': _coverImageUrl.isEmpty ? null : _coverImageUrl,
        'published': _published,
        'featured': _featured,
        'tech_stack': _techStack,
        'live_url': _liveUrlController.text.trim(),
        'github_url': _githubUrlController.text.trim(),
        'order_index': int.tryParse(_orderController.text) ?? 0,
      };

      if (_isEdit) {
        await SupabaseService.from('projects').update(payload).eq('id', widget.id!);
      } else {
        await SupabaseService.from('projects').insert(payload);
      }

      setState(() {
        _saving = false;
        _saveMsg = 'Saved!';
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _saveMsg = '');
          context.go('/admin/projects');
        }
      });
    } catch (e) {
      debugPrint('Error saving project: $e');
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: OutlinedButton(
            onPressed: () => context.go('/admin/projects'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('← Back', style: TextStyle(color: AppColors.textBody)),
          ),
        ),
        title: Text(
          _isEdit ? 'Edit Project' : 'New Project',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Row(
            children: [
              Text(
                _published ? 'Published' : 'Draft',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Switch(
                value: _published,
                onChanged: (val) => setState(() => _published = val),
                activeColor: AppColors.accent,
                activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _saveMsg.isNotEmpty ? AppColors.success : AppColors.accent,
              ),
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_saveMsg.isNotEmpty ? _saveMsg : 'Save'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              
              Widget mainContent = SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.displaySmall,
                      decoration: const InputDecoration(
                        hintText: 'Project title...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textBody),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Short description (appears in cards)...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QuillSimpleToolbar(
                        controller: _quillController,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 400,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QuillEditor.basic(
                        controller: _quillController,
                      ),
                    ),
                  ],
                ),
              );

              Widget sidebar = SingleChildScrollView(
                child: Container(
                  width: isMobile ? double.infinity : 320,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: isMobile ? Colors.transparent : AppColors.border),
                      top: BorderSide(color: isMobile ? AppColors.border : Colors.transparent),
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      _buildSidebarSection(
                        'COVER IMAGE',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_coverImageUrl.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_coverImageUrl, fit: BoxFit.cover, height: 160, width: double.infinity),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => setState(() => _coverImageUrl = ''),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Remove'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: _uploadCover,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('+ Upload Cover', style: Theme.of(context).textTheme.bodySmall),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Tech Stack
                      _buildSidebarSection(
                        'TECH STACK',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _techInputController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Vue.js',
                                    ),
                                    onSubmitted: (_) => _addTech(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addTech,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    backgroundColor: AppColors.surfaceAlt,
                                    foregroundColor: AppColors.textHeadingAlt,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  child: const Text('Add'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _techStack.map((tech) => Chip(
                                label: Text(tech, style: const TextStyle(fontSize: 12)),
                                onDeleted: () => _removeTech(tech),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                backgroundColor: AppColors.surface,
                                side: const BorderSide(color: AppColors.border),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Links
                      _buildSidebarSection(
                        'LINKS',
                        Column(
                          children: [
                            TextField(
                              controller: _liveUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Live URL',
                                prefixIcon: Icon(Icons.link, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _githubUrlController,
                              decoration: const InputDecoration(
                                labelText: 'GitHub URL',
                                prefixIcon: Icon(Icons.code, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Settings
                      _buildSidebarSection(
                        'SETTINGS',
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Featured Project'),
                                Switch(
                                  value: _featured,
                                  onChanged: (val) => setState(() => _featured = val),
                                  activeColor: AppColors.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _orderController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Sort Order',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isMobile) {
                return Column(
                  children: [
                    Expanded(child: mainContent),
                    sidebar,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: mainContent),
                  sidebar,
                ],
              );
            },
          ),
          
          if (_uploadingImage)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text('Uploading image...', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
