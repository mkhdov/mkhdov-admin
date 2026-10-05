import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ArticleEditorScreen extends StatefulWidget {
  final String? id;

  const ArticleEditorScreen({super.key, this.id});

  @override
  State<ArticleEditorScreen> createState() => _ArticleEditorScreenState();
}

class _ArticleEditorScreenState extends State<ArticleEditorScreen> {
  final _titleController = TextEditingController();
  final QuillController _quillController = QuillController.basic();
  
  bool _isEdit = false;
  String _coverImageUrl = '';
  bool _published = false;
  bool _saving = false;
  bool _uploadingImage = false;
  String _saveMsg = '';

  @override
  void initState() {
    super.initState();
    _isEdit = widget.id != null;
    if (_isEdit) {
      _loadArticle();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    try {
      final response = await SupabaseService.from('articles')
          .select('*')
          .eq('id', widget.id!)
          .single();

      setState(() {
        _titleController.text = response['title'];
        _coverImageUrl = response['cover_image_url'] ?? '';
        _published = response['published'];
        
        // In a real app we'd convert the HTML from supabase to Delta, or save Delta directly.
        // For this demo, we're assuming the web app saved HTML, and flutter_quill uses Delta.
        // It's a complex conversion to do perfectly. We will just load plain text if it exists.
        // If they use flutter specifically, we would save Delta to the db in a separate column.
        if (response['content'] != null) {
           _quillController.document = Document()..insert(0, response['content']); 
        }
      });
    } catch (e) {
      debugPrint('Error loading article: $e');
    }
  }

  Future<void> _uploadCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    setState(() => _uploadingImage = true);
    
    try {
      final path = 'covers/${DateTime.now().millisecondsSinceEpoch}-${image.name}';
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
      // In a real scenario we'd convert the Quill delta to HTML to be compatible with the web app,
      // or save the delta JSON.
      // For now we just get the plain text or you could implement a Delta->HTML converter.
      final content = _quillController.document.toPlainText();
      
      final payload = {
        'title': _titleController.text.trim(),
        'content': content,
        'cover_image_url': _coverImageUrl.isEmpty ? null : _coverImageUrl,
        'published': _published,
      };

      if (_isEdit) {
        await SupabaseService.from('articles').update(payload).eq('id', widget.id!);
      } else {
        await SupabaseService.from('articles').insert(payload);
      }

      setState(() {
        _saving = false;
        _saveMsg = 'Saved!';
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _saveMsg = '');
          context.go('/admin/articles');
        }
      });
    } catch (e) {
      debugPrint('Error saving article: $e');
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
            onPressed: () => context.go('/admin/articles'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('← Back', style: TextStyle(color: AppColors.textBody)),
          ),
        ),
        title: Text(
          _isEdit ? 'Edit Article' : 'New Article',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          // Toggle
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
          // Save Button
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
              
              Widget mainContent = Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: Theme.of(context).textTheme.displaySmall,
                      decoration: const InputDecoration(
                        hintText: 'Article title...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QuillEditor.basic(
                          controller: _quillController,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              Widget sidebar = Container(
                width: isMobile ? double.infinity : 280,
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('COVER IMAGE', style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 12),
                          if (_coverImageUrl.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_coverImageUrl, fit: BoxFit.cover, height: 140, width: double.infinity),
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
                                  child: Text(
                                    '+ Upload Cover',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STATUS', style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: _published ? AppColors.success : AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _published 
                                      ? 'Published — visible to readers' 
                                      : 'Draft — only you can see it',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
}
