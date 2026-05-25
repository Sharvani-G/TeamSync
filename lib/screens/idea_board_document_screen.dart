import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;

import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/file_service.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class IdeaBoardDocumentScreen extends StatefulWidget {
  final String projectId;
  final String levelId;

  const IdeaBoardDocumentScreen(
      {super.key, required this.projectId, required this.levelId});

  @override
  State<IdeaBoardDocumentScreen> createState() =>
      _IdeaBoardDocumentScreenState();
}

class _IdeaBoardDocumentScreenState extends State<IdeaBoardDocumentScreen> {
  bool _isMutating = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadLabel = '';

  Future<List<picker.PlatformFile>> _pickFiles(
      {bool allowMultiple = true}) async {
    try {
      return await AttachmentService.instance
          .pickFiles(allowMultiple: allowMultiple);
    } catch (e, stackTrace) {
      debugPrint('File picker failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    try {
      await ProjectService.instance.removeIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: blockId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _attachFiles(IdeaBoardBlock block) async {
    try {
      final files = await _pickFiles();
      if (files.isEmpty) return;

      await _uploadFilesToBlock(block, files);
    } catch (e, stackTrace) {
      debugPrint('Attachment upload failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () async {
              try {
                final files = await _pickFiles();
                if (files.isEmpty) return;
                await _uploadFilesToBlock(block, files);
              } catch (retryError) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Retry failed: ${retryError.toString()}')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _uploadFilesToBlock(
      IdeaBoardBlock block, List<picker.PlatformFile> files) async {
    if (!mounted) return;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadLabel = files.isNotEmpty ? files.first.name : '';
    });

    try {
      // Create placeholder entries in the block so uploaded files appear
      // in the correct section immediately and persist even if the user
      // navigates away while upload completes.
      final authUser = FirebaseAuth.instance.currentUser;
      final uploaderId = authUser?.uid ?? '';
      final tempIds = <String>[];
      final placeholders = <Map<String, dynamic>>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final tempId = 'tmp-${DateTime.now().millisecondsSinceEpoch}-$i';
        tempIds.add(tempId);
        placeholders.add({
          'id': tempId,
          'name': f.name,
          'mimeType': '',
          'size': f.size,
          'downloadUrl': '',
          'uploadedBy': uploaderId,
          'createdAt': DateTime.now().toIso8601String(),
          'storagePath': '',
          'fileName': f.name,
          'fileUrl': '',
          'fileType': '',
          'fileSize': f.size,
          'url': '',
          'type': '',
          'sizeBytes': f.size,
          'uploading': true,
        });
      }

      // Append placeholders so UI shows them in the correct block immediately
      await ProjectService.instance.appendFilesToIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: block.id,
        newFiles: placeholders,
      );
      final uploaded = await AttachmentService.instance.attachToIdeaBoard(
        projectId: widget.projectId,
        levelId: widget.levelId,
        blockId: block.id,
        existingFiles: block.files.map((item) => item.toMap()).toList(),
        files: files,
        onProgress: (progress, currentFileName) {
          if (!mounted) return;
          setState(() {
            _uploadLabel = currentFileName;
            _uploadProgress = progress;
          });
        },
        appendToBlock: false,
      );

      // Build replacements mapping from temp ids to the uploaded metadata
      final replacements = <String, Map<String, dynamic>>{};
      for (var i = 0; i < tempIds.length && i < uploaded.length; i++) {
        replacements[tempIds[i]] = uploaded[i].toMap();
      }

      if (replacements.isNotEmpty) {
        await ProjectService.instance.replacePlaceholdersInIdeaBoardBlock(
          projectId: widget.projectId,
          blockId: block.id,
          replacements: replacements,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Attachment upload failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () async {
              await _uploadFilesToBlock(block, files);
            },
          ),
        ),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _uploadLabel = '';
        });
      }
    }
  }

  Future<void> _replaceFile(IdeaBoardBlock block, IdeaBoardFile target) async {
    try {
      final files = await _pickFiles(allowMultiple: false);
      if (files.isEmpty) return;

      final uploaded = await AttachmentService.instance.uploadFiles(
        storagePathPrefix: 'project_files/${widget.projectId}/${block.id}',
        files: [files.first],
        onProgress: null,
      );

      final attachment = uploaded.first;

      final updatedFiles = block.files.map<Map<String, dynamic>>((item) {
        if (item.id != target.id) {
          return item.toMap();
        }
        return attachment.toMap();
      }).toList();

      await ProjectService.instance.updateIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: block.id,
        files: updatedFiles,
      );

      await FileService.instance.deleteIdeaBoardAttachment(target.storagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _previewFile(IdeaBoardFile file) async {
    final uri = Uri.parse(file.url);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _downloadFile(IdeaBoardFile file) async {
    final uri = Uri.parse(file.url);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _moveBlock(IdeaBoardBlock block, bool moveUp) async {
    try {
      await ProjectService.instance.moveIdeaBoardBlock(
        projectId: widget.projectId,
        blockId: block.id,
        moveUp: moveUp,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _removeFile(IdeaBoardBlock block, IdeaBoardFile file) async {
    final updated = block.files
        .where((item) => item.id != file.id)
        .map((item) => item.toMap())
        .toList();

    await FileService.instance.deleteIdeaBoardAttachment(file.storagePath);

    await ProjectService.instance.updateIdeaBoardBlock(
      projectId: widget.projectId,
      blockId: block.id,
      files: updated,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: const SimpleAppBar(title: 'Idea Board'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'You do not have access to this document or it could not be loaded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            body: Center(child: Text('Project not found')),
          );
        }

        final orderedLevels = [...project.levels]
          ..sort((a, b) => a.order.compareTo(b.order));

        if (orderedLevels.isEmpty) {
          return Scaffold(
            appBar: SimpleAppBar(title: project.title),
            body: const Center(
              child: Text('This project does not have any levels yet.'),
            ),
          );
        }

        ProjectLevel? level;
        try {
          level = orderedLevels.firstWhere((item) => item.id == widget.levelId);
        } catch (_) {
          level = null;
        }

        if (level == null) {
          return Scaffold(
            appBar: SimpleAppBar(title: project.title),
            body: const Center(
              child: Text('Level not found'),
            ),
          );
        }

        final authUser = FirebaseAuth.instance.currentUser;
        final isCollaborator =
            authUser != null && project.isCollaborator(authUser.uid);

        return Scaffold(
          appBar: SimpleAppBar(title: level.title),
          body: Column(
            children: [
              if (_isUploading)
                Material(
                  color: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _uploadLabel.isNotEmpty
                              ? 'Uploading $_uploadLabel'
                              : 'Uploading file...',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _uploadProgress),
                      ],
                    ),
                  ),
                ),
              if (!isCollaborator)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFE0F2FE),
                  child: const Text(
                    'View only mode: only collaborators can edit this idea board.',
                    style: TextStyle(
                      color: Color(0xFF075985),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<IdeaBoardBlock>>(
                  stream: ProjectService.instance.watchIdeaBoardBlocks(
                    projectId: widget.projectId,
                    levelId: widget.levelId,
                  ),
                  builder: (context, blockSnapshot) {
                    if (blockSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final blocks =
                        blockSnapshot.data ?? const <IdeaBoardBlock>[];

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      children: [
                        if (blocks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                              ),
                            ),
                            child: const Text(
                              'No content yet. Add a title, paragraph, or file block to start collaborating.',
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          ),
                        ...blocks.map(
                          (block) => _IdeaBlockCard(
                            block: block,
                            canEdit: isCollaborator,
                            onDelete: () => _deleteBlock(block.id),
                            onSaveContent: (value) =>
                                _saveContent(block.id, value),
                            onAttachFiles: () => _attachFiles(block),
                            onReplaceFile: (file) => _replaceFile(block, file),
                            onPreviewFile: (file) => _previewFile(file),
                            onDownloadFile: (file) => _downloadFile(file),
                            onRemoveFile: (file) => _removeFile(block, file),
                            onMoveUp: () => _moveBlock(block, true),
                            onMoveDown: () => _moveBlock(block, false),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: isCollaborator
              ? _AddBlockFab(
                  isBusy: _isMutating,
                  onAddTitle: () => _addBlock('title'),
                  onAddParagraph: () => _addBlock('paragraph'),
                  onAddFileBlock: () => _addBlock('file'),
                )
              : null,
        );
      },
    );
  }
}

class _AddBlockFab extends StatelessWidget {
  const _AddBlockFab({
    required this.isBusy,
    required this.onAddTitle,
    required this.onAddParagraph,
    required this.onAddFileBlock,
  });

  final bool isBusy;
  final VoidCallback onAddTitle;
  final VoidCallback onAddParagraph;
  final VoidCallback onAddFileBlock;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isBusy,
      onSelected: (value) {
        if (value == 'title') onAddTitle();
        if (value == 'paragraph') onAddParagraph();
        if (value == 'file') onAddFileBlock();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'title', child: Text('+ Add Title Block')),
        PopupMenuItem(value: 'paragraph', child: Text('+ Add Paragraph Block')),
        PopupMenuItem(value: 'file', child: Text('+ Add Attachment Block')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          isBusy ? 'Saving...' : '+ Add Block',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _IdeaBlockCard extends StatefulWidget {
  const _IdeaBlockCard({
    required this.block,
    required this.canEdit,
    required this.onDelete,
    required this.onSaveContent,
    required this.onAttachFiles,
    required this.onReplaceFile,
    required this.onPreviewFile,
    required this.onDownloadFile,
    required this.onRemoveFile,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final IdeaBoardBlock block;
  final bool canEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onSaveContent;
  final VoidCallback onAttachFiles;
  final Future<void> Function(IdeaBoardFile file) onReplaceFile;
  final Future<void> Function(IdeaBoardFile file) onPreviewFile;
  final Future<void> Function(IdeaBoardFile file) onDownloadFile;
  final Future<void> Function(IdeaBoardFile file) onRemoveFile;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  State<_IdeaBlockCard> createState() => _IdeaBlockCardState();
}

class _IdeaBlockCardState extends State<_IdeaBlockCard> {
  late final TextEditingController _controller;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.block.content);
    _controller.addListener(_scheduleSave);
  }

  @override
  void didUpdateWidget(covariant _IdeaBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.content != widget.block.content &&
        _controller.text != widget.block.content) {
      _controller.text = widget.block.content;
    }
  }

  void _scheduleSave() {
    if (!widget.canEdit) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      widget.onSaveContent(_controller.text);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller.removeListener(_scheduleSave);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTitle = widget.block.type == 'title';
    final isFile = widget.block.type == 'file';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFF1F5F9),
                ),
                child: Text(
                  widget.block.type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Spacer(),
              if (widget.canEdit) ...[
                IconButton(
                  onPressed: widget.onMoveUp,
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  tooltip: 'Move Up',
                ),
                IconButton(
                  onPressed: widget.onMoveDown,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  tooltip: 'Move Down',
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ],
          ),
          if (!isFile)
            TextField(
              controller: _controller,
              readOnly: !widget.canEdit,
              minLines: isTitle ? 1 : 3,
              maxLines: null,
              style: TextStyle(
                fontSize: isTitle ? 24 : 15,
                fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isTitle ? 'Section title' : 'Write content...',
              ),
            ),
          if (widget.block.files.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...widget.block.files.map(
              (file) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: () => widget.onPreviewFile(file),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      tooltip: 'Preview',
                    ),
                    IconButton(
                      onPressed: () => widget.onDownloadFile(file),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      tooltip: 'Download',
                    ),
                    if (widget.canEdit) ...[
                      IconButton(
                        onPressed: () => widget.onReplaceFile(file),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        tooltip: 'Replace',
                      ),
                      IconButton(
                        onPressed: () => widget.onRemoveFile(file),
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Remove',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (widget.canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAttachFiles,
                icon: const Icon(Icons.upload_file),
                label: const Text('Attach File'),
              ),
            ),
        ],
      ),
    );
  }
}
