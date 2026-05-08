import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class IdeaBoardDocumentScreen extends StatefulWidget {
  final String projectId;
  final String levelId;

  const IdeaBoardDocumentScreen({super.key, required this.projectId, required this.levelId});

  @override
  State<IdeaBoardDocumentScreen> createState() => _IdeaBoardDocumentScreenState();
}

class _IdeaBoardDocumentScreenState extends State<IdeaBoardDocumentScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

        return Scaffold(
          appBar: SimpleAppBar(title: level.title),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Document title',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      hintText: 'Start writing...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Attachments are not yet enabled in this view.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}