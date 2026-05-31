import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;

import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/file_delivery_service.dart';
import '../services/file_service.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// File-level helpers used across widgets in this file
bool _isCloudinaryUrl(String url) {
  return url.trim().startsWith('https://res.cloudinary.com');
}

bool _isImageFile(dynamic value) {
  if (value is String) return value.startsWith('image/');
  if (value is IdeaBoardFile) {
    final mime = value.fileType.trim().toLowerCase();
    if (mime.isNotEmpty) return mime.startsWith('image/');
    final ext = value.fileName.split('.').length > 1 ? value.fileName.split('.').last : '';
    return ext.toLowerCase().startsWith('jpg') || ext.toLowerCase().startsWith('png') || ext.toLowerCase().startsWith('gif') || ext.toLowerCase().startsWith('webp');
  }
  return false;
}

bool _isImageAttachment(String mimeType) {
  return mimeType.startsWith('image/');
}

String _getMimeType(String fileName, String? extension) {
  const map = {
    'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
    'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain', 'csv': 'text/csv', 'zip': 'application/zip',
  };
  return map[extension?.toLowerCase()] ?? 'application/octet-stream';
}

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
  static final _IdeaBoardUploadCoordinator _uploadCoordinator =
      _IdeaBoardUploadCoordinator();

  bool _isMutating = false;

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
    }
  }

  Future<void> _uploadFilesToBlock(
      IdeaBoardBlock block, List<picker.PlatformFile> files) async {
    final retryAction = () => _uploadFilesToBlock(block, files);
    _uploadCoordinator.begin(
      blockId: block.id,
      fileName: files.isNotEmpty ? files.first.name : 'Attachment',
      retryAction: retryAction,
    );

    try {
      await AttachmentService.instance.attachToIdeaBoard(
        projectId: widget.projectId,
        levelId: widget.levelId,
        blockId: block.id,
        existingFiles: block.files.map((item) => item.toMap()).toList(),
        files: files,
        onProgress: (progress, currentFileName) {
          _uploadCoordinator.updateProgress(
            fileName: currentFileName,
            progress: progress,
          );
        },
        appendToBlock: true,
      );
    } catch (e, stackTrace) {
      debugPrint('[SCREEN REJECTION INTERCEPTED] Details: $e');
      debugPrint('-> Forensics Stack: $stackTrace');
      _uploadCoordinator.fail(
        blockId: block.id,
        message: e.toString(),
        retryAction: retryAction,
      );
      rethrow;
    } finally {
      if (_uploadCoordinator.isActiveForBlock(block.id) &&
          !_uploadCoordinator.hasError) {
        _uploadCoordinator.clear();
      }
    }
  }

  Future<void> _replaceFile(IdeaBoardBlock block, IdeaBoardFile target) async {
    try {
      final files = await _pickFiles(allowMultiple: false);
      if (files.isEmpty) return;

      final uploaded = await AttachmentService.instance.uploadFiles(
        storagePathPrefix: 'project_files/${widget.projectId}/${block.id}',
        context: {
          'type': 'ideaboard',
          'projectId': widget.projectId,
          'levelId': widget.levelId,
          'blockId': block.id,
        },
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

  bool _isImageFile(IdeaBoardFile file) {
    return _mimeOrExtension(file).startsWith('image/');
  }

  bool _isPdfFile(IdeaBoardFile file) {
    final mimeOrExt = _mimeOrExtension(file);
    return mimeOrExt == 'application/pdf' || _fileExtension(file) == '.pdf';
  }

  bool _isSvgFile(IdeaBoardFile file) {
    final mimeOrExt = _mimeOrExtension(file);
    return mimeOrExt == 'image/svg+xml' || _fileExtension(file) == '.svg';
  }

  bool _isOfficeFile(IdeaBoardFile file) {
    final mimeOrExt = _mimeOrExtension(file);
    final extension = _fileExtension(file);
    return mimeOrExt.contains('officedocument') ||
        mimeOrExt == 'application/msword' ||
        mimeOrExt == 'application/vnd.ms-excel' ||
        mimeOrExt == 'application/vnd.ms-powerpoint' ||
        extension == '.doc' ||
        extension == '.docx' ||
        extension == '.xls' ||
        extension == '.xlsx' ||
        extension == '.ppt' ||
        extension == '.pptx';
  }

  String _mimeOrExtension(IdeaBoardFile file) {
    final mime = file.fileType.trim().toLowerCase();
    if (mime.isNotEmpty) {
      return mime;
    }
    final extension = _fileExtension(file);
    if (extension == '.pdf') return 'application/pdf';
    if (extension == '.jpg' || extension == '.jpeg') return 'image/jpeg';
    if (extension == '.png') return 'image/png';
    if (extension == '.gif') return 'image/gif';
    if (extension == '.webp') return 'image/webp';
    if (extension == '.svg') return 'image/svg+xml';
    if (extension == '.txt') return 'text/plain';
    if (extension == '.csv') return 'text/csv';
    if (extension == '.zip') return 'application/zip';
    if (extension == '.doc') return 'application/msword';
    if (extension == '.docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (extension == '.xls') return 'application/vnd.ms-excel';
    if (extension == '.xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (extension == '.ppt') return 'application/vnd.ms-powerpoint';
    if (extension == '.pptx') return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    return extension;
  }

  bool _isCloudinaryUrl(String url) {
    return url.trim().startsWith('https://res.cloudinary.com');
  }

  String _cloudinaryDownloadUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.contains('?') ? '$trimmed&fl_attachment' : '$trimmed?fl_attachment';
  }

  String _fileExtension(IdeaBoardFile file) {
    final source = file.fileName.trim().isNotEmpty
        ? file.fileName.trim()
        : file.fileUrl.trim();
    final uri = Uri.tryParse(source);
    final path = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : source;
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return path.substring(dotIndex).toLowerCase();
  }

  String _docsViewerUrl(String url) {
    return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}';
  }

  Future<void> _showFileMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showImagePreview(IdeaBoardFile file) async {
    final url = file.fileUrl.trim();
    if (!_isCloudinaryUrl(url)) {
      await _showFileMessage('File unavailable. Please re-upload.');
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Unable to preview this file.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewFile(IdeaBoardFile file) async {
    final downloadUrl = file.fileUrl.trim();
    if (!_isCloudinaryUrl(downloadUrl)) {
      await _showFileMessage('File unavailable. Please re-upload.');
      return;
    }

    if (_isImageFile(file)) {
      await _showImagePreview(file);
      return;
    }

    await launchUrl(
      Uri.parse(downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _downloadFile(IdeaBoardFile file) async {
    final downloadUrl = file.fileUrl.trim();
    if (!_isCloudinaryUrl(downloadUrl)) {
      await _showFileMessage('File unavailable. Please re-upload.');
      return;
    }

    await FileDeliveryService.instance.downloadFromUrl(
      url: _cloudinaryDownloadUrl(downloadUrl),
      fileName: file.fileName.isNotEmpty ? file.fileName : 'download',
    );
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
                child: StreamBuilder<_IdeaBoardUploadState?>(
                  stream: _uploadCoordinator.stream,
                  initialData: _uploadCoordinator.currentState,
                  builder: (context, uploadSnapshot) {
                    final uploadState = uploadSnapshot.data;
                    return StreamBuilder<List<IdeaBoardBlock>>(
                      stream: ProjectService.instance.watchIdeaBoardBlocks(
                        projectId: widget.projectId,
                        levelId: widget.levelId,
                      ),
                      builder: (context, blockSnapshot) {
                        if (blockSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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
                                    colors: [
                                      Color(0xFFEFF6FF),
                                      Color(0xFFDBEAFE)
                                    ],
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
                                uploadState:
                                    uploadState?.blockId == block.id ? uploadState : null,
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
    required this.uploadState,
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
  final _IdeaBoardUploadState? uploadState;
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
    final isUploadingThisBlock = widget.uploadState != null;
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
          if (widget.uploadState != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UploadStatusCard(
                state: widget.uploadState!,
                onRetry: widget.uploadState?.retryAction,
                onDismiss: _IdeaBoardDocumentScreenState._uploadCoordinator.clear,
              ),
            ),
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
                    if (_isCloudinaryUrl(file.fileUrl.trim()) && _isImageFile(file))
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onPreviewFile(file),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                file.fileUrl.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black12,
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported_outlined),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.attach_file, size: 16, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.fileName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 2),
                                      if (!_isCloudinaryUrl(file.fileUrl.trim()))
                                        const Text(
                                          'File unavailable. Please re-upload.',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFB91C1C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      else
                                        Text(
                                          _formatFileSize(file.fileSize),
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _isCloudinaryUrl(file.fileUrl.trim())
                                      ? () => widget.onPreviewFile(file)
                                      : null,
                                  icon: const Icon(Icons.open_in_new, size: 15),
                                  label: const Text('Open'),
                                ),
                                TextButton.icon(
                                  onPressed: _isCloudinaryUrl(file.fileUrl.trim())
                                      ? () => widget.onDownloadFile(file)
                                      : null,
                                  icon: const Icon(Icons.download_outlined, size: 15),
                                  label: const Text('Download'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                onPressed:
                    widget.canEdit && !isUploadingThisBlock ? widget.onAttachFiles : null,
                icon: const Icon(Icons.upload_file),
                label: const Text('Attach File'),
              ),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(int size) {
    if (size <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _UploadStatusCard extends StatelessWidget {
  const _UploadStatusCard({
    required this.state,
    required this.onRetry,
    required this.onDismiss,
  });

  final _IdeaBoardUploadState state;
  final Future<void> Function()? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (state.isFailed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pause_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }

    final isSaving = state.progress >= 1.0;
    final statusText = isSaving
        ? 'Saving ${state.fileName}...'
        : state.progress < 0.3
            ? 'Preparing ${state.fileName}...'
            : 'Uploading ${state.fileName}...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!isSaving)
                Text(
                  '${(state.progress * 100).clamp(0, 99).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                )
              else
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isSaving)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: state.progress.clamp(0, 0.99)),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _IdeaBoardUploadState {
  final String blockId;
  final String fileName;
  final double progress;
  final String message;
  final Future<void> Function()? retryAction;

  const _IdeaBoardUploadState({
    required this.blockId,
    required this.fileName,
    required this.progress,
    required this.message,
    this.retryAction,
  });

  bool get isFailed => retryAction != null && message.isNotEmpty;
}

class _IdeaBoardUploadCoordinator {
  final StreamController<_IdeaBoardUploadState?> _controller =
      StreamController<_IdeaBoardUploadState?>.broadcast();
  _IdeaBoardUploadState? _currentState;

  Stream<_IdeaBoardUploadState?> get stream => _controller.stream;
  _IdeaBoardUploadState? get currentState => _currentState;
  bool get hasError => _currentState?.isFailed ?? false;

  void begin({
    required String blockId,
    required String fileName,
    required Future<void> Function() retryAction,
  }) {
    _currentState = _IdeaBoardUploadState(
      blockId: blockId,
      fileName: fileName,
      progress: 0,
      message: '',
      retryAction: retryAction,
    );
    _emit();
  }

  void updateProgress({
    required String fileName,
    required double progress,
  }) {
    final current = _currentState;
    if (current == null) {
      return;
    }
    _currentState = _IdeaBoardUploadState(
      blockId: current.blockId,
      fileName: fileName,
      progress: progress.clamp(0, 1),
      message: current.message,
      retryAction: current.retryAction,
    );
    _emit();
  }

  void fail({
    required String blockId,
    required String message,
    required Future<void> Function() retryAction,
  }) {
    final current = _currentState;
    _currentState = _IdeaBoardUploadState(
      blockId: blockId,
      fileName: current?.fileName ?? 'Attachment',
      progress: current?.progress ?? 0,
      message: message,
      retryAction: retryAction,
    );
    _emit();
  }

  bool isActiveForBlock(String blockId) {
    return _currentState?.blockId == blockId;
  }

  void clear() {
    _currentState = null;
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_currentState);
    }
  }
}
