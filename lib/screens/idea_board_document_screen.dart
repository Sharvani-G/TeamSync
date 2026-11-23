import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;

import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

bool _isCloudinaryUrl(String url) => url.trim().startsWith('https://res.cloudinary.com');

class IdeaBoardDocumentScreen extends StatefulWidget {
  final String projectId;
  final String levelId;

  const IdeaBoardDocumentScreen({super.key, required this.projectId, required this.levelId});

  @override
  State<IdeaBoardDocumentScreen> createState() => _IdeaBoardDocumentScreenState();
}

class _IdeaBoardDocumentScreenState extends State<IdeaBoardDocumentScreen> {
  bool _isMutating = false;
  String? _uploadingBlockId;
  double _uploadProgress = 0.0;
  String? _uploadError;

  late Stream<Project?> _projectStream;
  late Stream<List<IdeaBoardBlock>> _blocksStream;

  @override
  void initState() {
    super.initState();
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
    _blocksStream = ProjectService.instance.watchIdeaBoardBlocks(
      projectId: widget.projectId,
      levelId: widget.levelId,
    );
  }

  String extractPublicId(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final uploadIndex = segments.indexOf('upload');
    if (uploadIndex == -1) return '';
    final afterUpload = segments.sublist(uploadIndex + 1);
    final withoutVersion = afterUpload.first.startsWith('v') ? afterUpload.sublist(1) : afterUpload;
    final joined = withoutVersion.join('/');
    return joined.contains('.') ? joined.substring(0, joined.lastIndexOf('.')) : joined;
  }

  Future<void> _addBlock(String type) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await ProjectService.instance.addIdeaBoardBlock(
        projectId: widget.projectId,
        levelId: widget.levelId,
        type: type,
        content: type == 'title' ? 'Untitled section' : '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add block: $e'),
            backgroundColor: AppColors.dpDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    try {
      await ProjectService.instance.removeIdeaBoardBlock(projectId: widget.projectId, blockId: blockId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete block: $e'),
            backgroundColor: AppColors.dpDanger,
          ),
        );
      }
    }
  }

  Future<void> _saveContent(String blockId, String content) async {
    try {
      await ProjectService.instance.updateIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: blockId,
        content: content,
      );
    } catch (e) {
      debugPrint('Failed to save content: $e');
    }
  }

  Future<void> _attachFiles(IdeaBoardBlock block) async {
    final result = await picker.FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _uploadingBlockId = block.id;
      _uploadError = null;
      _uploadProgress = 0.0;
    });

    try {
      await AttachmentService.instance.attachToIdeaBoard(
        projectId: widget.projectId,
        levelId: widget.levelId,
        blockId: block.id,
        existingFiles: block.files.map((item) => item.toMap()).toList(),
        files: [file],
        onProgress: (p, name) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _uploadError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingBlockId = null;
        });
      }
    }
  }

  Future<void> _deleteFile(IdeaBoardBlock block, IdeaBoardFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete ${file.fileName}?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dpDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final publicId = extractPublicId(file.fileUrl);
      if (publicId.isNotEmpty) {
        await AttachmentService.instance.deleteFile(publicId: publicId);
      }

      final updatedFiles = block.files
          .where((f) => f.id != file.id)
          .map((f) => f.toMap())
          .toList();

      await ProjectService.instance.updateIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: block.id,
        files: updatedFiles,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete file: $e'),
            backgroundColor: AppColors.dpDanger,
          ),
        );
      }
    }
  }

  Future<void> _previewFile(IdeaBoardFile file) async {
    final url = file.fileUrl.trim();
    if (!_isCloudinaryUrl(url)) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadFile(IdeaBoardFile file) async {
    final url = file.fileUrl.trim();
    if (!_isCloudinaryUrl(url)) return;
    await launchUrl(Uri.parse('$url?fl_attachment'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: _projectStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: SimpleAppBar(title: 'Idea Board'),
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Project Not Found',
              subtitle: 'This project could not be located.',
            ),
          );
        }

        final isCollaborator = project.isCollaborator(FirebaseAuth.instance.currentUser?.uid ?? '');
        final levelTitle = widget.levelId;

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(title: levelTitle),
          body: Column(
            children: [
              if (!isCollaborator)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: AppColors.dpInfoBg,
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'View-only mode — you are not a collaborator on this project',
                        style: AppTheme.metadataText.copyWith(color: AppTheme.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: StreamBuilder<List<IdeaBoardBlock>>(
                      stream: _blocksStream,
                      builder: (context, blockSnap) {
                        if (blockSnap.connectionState == ConnectionState.waiting && blockSnap.data == null) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
                        }
                        final blocks = blockSnap.data ?? [];
                        if (blocks.isEmpty) {
                          return EmptyState(
                            icon: Icons.lightbulb_outline,
                            title: 'No blocks added yet',
                            subtitle: isCollaborator
                                ? 'Tap "+ Add Block" to add titles, text, or file attachments.'
                                : 'No content has been added to this section yet.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          itemCount: blocks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (c, i) => _IdeaBlockCard(
                            block: blocks[i],
                            canEdit: isCollaborator,
                            uploadingBlockId: _uploadingBlockId,
                            uploadProgress: _uploadProgress,
                            uploadError: _uploadError,
                            onDelete: () => _deleteBlock(blocks[i].id),
                            onSaveContent: (val) => _saveContent(blocks[i].id, val),
                            onAttachFiles: () => _attachFiles(blocks[i]),
                            onPreviewFile: _previewFile,
                            onDownloadFile: _downloadFile,
                            onDeleteFile: (file) => _deleteFile(blocks[i], file),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isCollaborator ? _AddBlockFab(onAdd: _addBlock) : null,
        );
      },
    );
  }
}

class _AddBlockFab extends StatelessWidget {
  final Function(String) onAdd;
  const _AddBlockFab({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onAdd,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.rule),
      ),
      color: AppTheme.panel,
      elevation: 4,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'title',
          child: Row(
            children: [
              const Icon(Icons.title, size: 18, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text('Add Title Block', style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'paragraph',
          child: Row(
            children: [
              const Icon(Icons.notes, size: 18, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text('Add Paragraph Block', style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'file',
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 18, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text('Add File Attachment Block', style: AppTheme.bodySmall.copyWith(color: AppTheme.ink)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28074CE0),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Add Block',
              style: AppTheme.instrumentSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaBlockCard extends StatefulWidget {
  final IdeaBoardBlock block;
  final bool canEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onSaveContent;
  final VoidCallback onAttachFiles;
  final Function(IdeaBoardFile) onPreviewFile;
  final Function(IdeaBoardFile) onDownloadFile;
  final Function(IdeaBoardFile) onDeleteFile;
  final String? uploadingBlockId;
  final double uploadProgress;
  final String? uploadError;

  const _IdeaBlockCard({
    required this.block,
    required this.canEdit,
    required this.onDelete,
    required this.onSaveContent,
    required this.onAttachFiles,
    required this.onPreviewFile,
    required this.onDownloadFile,
    required this.onDeleteFile,
    this.uploadingBlockId,
    this.uploadProgress = 0,
    this.uploadError,
  });

  @override
  State<_IdeaBlockCard> createState() => _IdeaBlockCardState();
}

class _IdeaBlockCardState extends State<_IdeaBlockCard> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _timer?.cancel();
      widget.onSaveContent(_controller.text);
    }
  }

  @override
  void didUpdateWidget(_IdeaBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.content != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.block.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTitle = widget.block.type == 'title';
    final isUploading = widget.uploadingBlockId == widget.block.id;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0616191F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.groundMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.rule),
                ),
                child: Text(
                  widget.block.type.toUpperCase(),
                  style: AppTheme.labelText.copyWith(fontSize: 10, color: AppTheme.inkSecondary),
                ),
              ),
              const Spacer(),
              if (widget.canEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.dpDanger, size: 18),
                  tooltip: 'Delete block',
                  onPressed: widget.onDelete,
                ),
            ],
          ),
          if (widget.block.type != 'file') ...[
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.canEdit,
              onChanged: (val) {
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 1500), () => widget.onSaveContent(val));
              },
              style: isTitle
                  ? AppTheme.heading2.copyWith(fontSize: 20)
                  : AppTheme.bodySmall.copyWith(color: AppTheme.ink, height: 1.5),
              maxLines: isTitle ? 1 : null,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: isTitle ? 'Section Title' : 'Start typing your notes, details or idea content...',
                hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
              ),
            ),
          ],
          if (widget.block.files.isNotEmpty && widget.block.type != 'title') ...[
            const SizedBox(height: 14),
            ...widget.block.files.map((f) => FileAttachmentWidget(
                  file: f,
                  canDelete: widget.canEdit,
                  onPreview: () => widget.onPreviewFile(f),
                  onDownload: () => widget.onDownloadFile(f),
                  onDelete: () => widget.onDeleteFile(f),
                )),
          ],
          if (isUploading && widget.block.type != 'title') ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: widget.uploadProgress,
              backgroundColor: AppTheme.groundMuted,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 5),
            Text(
              'Uploading attachment (${(widget.uploadProgress * 100).toInt()}%)...',
              style: AppTheme.metadataText,
            ),
          ],
          if (widget.uploadError != null && isUploading && widget.block.type != 'title') ...[
            const SizedBox(height: 8),
            Text(
              widget.uploadError!,
              style: AppTheme.bodySmall.copyWith(color: AppColors.dpDanger),
            ),
          ],
          if (widget.canEdit && widget.block.type != 'title') ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onAttachFiles,
              icon: const Icon(Icons.attach_file, color: AppTheme.accent, size: 16),
              label: Text(
                'Attach File',
                style: AppTheme.instrumentSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FileAttachmentWidget extends StatelessWidget {
  final IdeaBoardFile file;
  final bool canDelete;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const FileAttachmentWidget({
    super.key,
    required this.file,
    required this.canDelete,
    required this.onPreview,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.groundMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.dpInfoBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.insert_drive_file_outlined, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file.fileName,
                  style: AppTheme.heading3.copyWith(fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionButton(
                icon: Icons.open_in_new,
                label: 'Open',
                onTap: onPreview,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.download_outlined,
                label: 'Download',
                onTap: onDownload,
              ),
              if (canDelete) ...[
                const Spacer(),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: AppColors.dpDanger,
                  onTap: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color != null ? AppColors.dpDangerBg : AppColors.dpInfoBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: effectiveColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.labelText.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
