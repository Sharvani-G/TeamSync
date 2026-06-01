import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class IdeaBoardScreen extends StatefulWidget {
  final String projectId;

  const IdeaBoardScreen({super.key, required this.projectId});

  @override
  State<IdeaBoardScreen> createState() => _IdeaBoardScreenState();
}

class _IdeaBoardScreenState extends State<IdeaBoardScreen> {
  late Stream<Project?> _projectStream;

  @override
  void initState() {
    super.initState();
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: _projectStream,
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
                  'You do not have access to this project or the project could not be loaded.',
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

        final sections = project.ideaBoardSections.isNotEmpty
            ? project.ideaBoardSections
            : ["Problem Statement", "Research", "Design", "Development", "Testing"];

        return Scaffold(
          appBar: SimpleAppBar(title: project.title),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sectionTitle = sections[index];
              // Use the title as the ID for now, or index.
              // Since the blocks are stored with levelId, we need a stable ID.
              // If we use index, reordering in Create Project will break existing blocks mapping.
              // But if we use title, renaming a section will break it.
              // The prompt says "store levels as an array of strings".
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                    foregroundColor: AppTheme.primary,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(sectionTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/project/${widget.projectId}/idea-board/$sectionTitle',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatCreatedAt(DateTime createdAt) {
    return 'Created ${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}