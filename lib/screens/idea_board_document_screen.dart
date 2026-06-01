import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as picker;

import '../models/models.dart';
import '../services/attachment_service.dart';
import '../services/project_service.dart';
import '../theme/app_colors.dart';

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
          SnackBar(content: Text('Failed to add block: $e')),
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
          SnackBar(content: Text('Failed to delete block: $e')),
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
        title: Text('Delete File'),
        content: Text('Are you sure you want to delete ${file.fileName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: TextStyle(color: AppColors.kDanger))),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
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
          return const Scaffold(backgroundColor: AppColors.kBgDeep, body: Center(child: CircularProgressIndicator()));
        }

        final project = snapshot.data;
        if (project == null) return const Scaffold(backgroundColor: AppColors.kBgDeep, body: Center(child: Text('Project not found', style: TextStyle(color: Colors.white))));

        final isCollaborator = project.isCollaborator(FirebaseAuth.instance.currentUser?.uid ?? '');
        final levelTitle = widget.levelId;

        return Scaffold(
          backgroundColor: AppColors.kBgDeep,
          appBar: AppBar(
            backgroundColor: AppColors.kBgDeep,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(levelTitle, style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
          ),
          body: Column(
            children: [
              if (!isCollaborator)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  color: AppColors.kAccentBlue.withValues(alpha: 0.1),
                  child: Text('View only mode', style: TextStyle(color: AppColors.kAccentLight, fontWeight: FontWeight.w600, fontSize: 13.sp)),
                ),
              Expanded(
                child: StreamBuilder<List<IdeaBoardBlock>>(
                  stream: _blocksStream,
                  builder: (context, blockSnap) {
                    if (blockSnap.connectionState == ConnectionState.waiting && blockSnap.data == null) {
                       return const Center(child: CircularProgressIndicator());
                    }
                    final blocks = blockSnap.data ?? [];
                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
                      itemCount: blocks.length,
                      separatorBuilder: (_, __) => SizedBox(height: 16.h),
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
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'title', child: Text('Add Title')),
        const PopupMenuItem(value: 'paragraph', child: Text('Add Paragraph')),
        const PopupMenuItem(value: 'file', child: Text('Add File')),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(color: AppColors.kAccentBlue, borderRadius: BorderRadius.circular(999.r)),
        child: Text('+ Add Block', style: TextStyle(color: AppColors.kWhite, fontWeight: FontWeight.w700, fontSize: 14.sp)),
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
      // Focus lost, save immediately
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.kBgCard,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(color: AppColors.kBgElevated, borderRadius: BorderRadius.circular(4.r)),
                child: Text(widget.block.type.toUpperCase(), style: TextStyle(color: AppColors.kTextSecond, fontSize: 10.sp, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              if (widget.canEdit) IconButton(icon: Icon(Icons.delete_outline, color: AppColors.kDanger, size: 20.sp), onPressed: widget.onDelete),
            ],
          ),
          if (widget.block.type != 'file')
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (val) {
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 1500), () => widget.onSaveContent(val));
              },
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: isTitle ? 20.sp : 14.sp, fontWeight: isTitle ? FontWeight.w600 : FontWeight.w400),
              maxLines: null,
              decoration: InputDecoration(border: InputBorder.none, hintText: isTitle ? 'Section Title' : 'Start typing...'),
            ),
          if (widget.block.files.isNotEmpty) ...[
            SizedBox(height: 12.h),
            ...widget.block.files.map((f) => FileAttachmentWidget(
                  file: f,
                  canDelete: widget.canEdit,
                  onPreview: () => widget.onPreviewFile(f),
                  onDownload: () => widget.onDownloadFile(f),
                  onDelete: () => widget.onDeleteFile(f),
                )),
          ],
          if (isUploading) ...[
            SizedBox(height: 12.h),
            LinearProgressIndicator(value: widget.uploadProgress, backgroundColor: AppColors.kBgElevated, color: AppColors.kAccentBlue),
            SizedBox(height: 4.h),
            Text('Uploading...', style: TextStyle(color: AppColors.kTextSecond, fontSize: 11.sp)),
          ],
          if (widget.uploadError != null && isUploading) ...[
            SizedBox(height: 8.h),
            Text(widget.uploadError!, style: TextStyle(color: AppColors.kDanger, fontSize: 12.sp)),
          ],
          if (widget.canEdit && widget.block.type != 'title')
            TextButton.icon(
              onPressed: widget.onAttachFiles,
              icon: Icon(Icons.add_circle_outline, color: AppColors.kAccentLight, size: 18.sp),
              label: Text('Attach File', style: TextStyle(color: AppColors.kAccentLight, fontSize: 13.sp)),
            ),
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

  const FileAttachmentWidget({super.key, required this.file, required this.canDelete, required this.onPreview, required this.onDownload, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.kBgElevated,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file, color: AppColors.kAccentLight, size: 24.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  file.fileName,
                  style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _ActionButton(icon: Icons.visibility_outlined, label: 'View', onTap: onPreview),
              SizedBox(width: 8.w),
              _ActionButton(icon: Icons.download_outlined, label: 'Download', onTap: onDownload),
              if (canDelete) ...[
                const Spacer(),
                _ActionButton(icon: Icons.delete_outline, label: 'Delete', color: AppColors.kDanger, onTap: onDelete),
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

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final finalColor = color ?? AppColors.kAccentLight;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: finalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: finalColor),
            SizedBox(width: 4.w),
            Text(label, style: TextStyle(color: finalColor, fontSize: 12.sp, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

