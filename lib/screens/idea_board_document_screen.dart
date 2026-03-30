import 'package:flutter/material.dart';
import '../data/mock_data.dart';
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
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    final project = projects.firstWhere((p) => p.id == widget.projectId,
        orElse: () => projects.first);
    final level = project.levels.firstWhere((l) => l.id == widget.levelId,
        orElse: () => project.levels.first);
    final doc = level.documents.isNotEmpty ? level.documents.first : null;
    _titleController =
        TextEditingController(text: doc?.title ?? 'Untitled Document');
    _contentController = TextEditingController(
        text: doc?.content ?? 'Start writing your ideas here...');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = projects.firstWhere((p) => p.id == widget.projectId,
        orElse: () => projects.first);
    final level = project.levels.firstWhere((l) => l.id == widget.levelId,
        orElse: () => project.levels.first);
    final doc = level.documents.isNotEmpty ? level.documents.first : null;
    final attachments = doc?.attachments ?? [];

    return Scaffold(
      appBar: SimpleAppBar(title: level.name),
      body: Column(
        children: [
          // Title field
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Document title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                fillColor: Colors.transparent,
              ),
            ),
          ),
          const Divider(height: 1),
          // Toolbar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _ToolbarButton(
                      icon: Icons.text_fields, label: 'Add Text', onTap: () {}),
                  const SizedBox(width: 8),
                  _ToolbarButton(
                      icon: Icons.image_outlined,
                      label: 'Add Image',
                      onTap: () {}),
                  const SizedBox(width: 8),
                  _ToolbarButton(
                      icon: Icons.upload_outlined,
                      label: 'Upload File',
                      onTap: () {}),
                  const SizedBox(width: 8),
                  _ToolbarButton(
                      icon: Icons.attach_file,
                      label: 'Attachment',
                      onTap: () {}),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Supported files info
          Container(
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Text('Supported files: PDF, PPT, DOCX, PNG, JPG',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8))),
              ],
            ),
          ),
          const Divider(height: 1),
          // Editor
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'Start writing...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const Divider(height: 1),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attachments (${attachments.length})',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 10),
                          ...attachments.map((att) => _AttachmentTile(
                                name: att.name,
                                type: att.type,
                                uploadedBy: att.uploadedBy,
                                uploadedAt: att.uploadedAt,
                              )),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: DottedUploadButton(onTap: () {}),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String name;
  final String type;
  final String uploadedBy;
  final String uploadedAt;

  const _AttachmentTile({
    required this.name,
    required this.type,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  IconData get _icon {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'ppt':
        return Icons.slideshow_outlined;
      case 'png':
      case 'jpg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'ppt':
        return const Color(0xFFEA580C);
      case 'png':
      case 'jpg':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(uploadedBy,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted)),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time,
                        size: 11, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Text(uploadedAt,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('View', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class DottedUploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const DottedUploadButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFFD1D5DB),
              width: 1.5,
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_outlined,
                size: 18, color: AppTheme.textSecondary),
            SizedBox(width: 8),
            Text('Upload New File',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
