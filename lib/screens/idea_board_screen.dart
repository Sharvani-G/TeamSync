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

        final orderedLevels = [...project.levels]
          ..sort((a, b) => a.order.compareTo(b.order));

        if (orderedLevels.isEmpty) {
          return Scaffold(
            appBar: SimpleAppBar(title: project.title),
            body: const Center(
              child: Text('No levels have been created for this project yet.'),
            ),
          );
        }

        return Scaffold(
          appBar: SimpleAppBar(title: project.title),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orderedLevels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final level = orderedLevels[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.12),
                    foregroundColor: AppTheme.primary,
                    child: Text('${level.order}'),
                  ),
                  title: Text(level.title),
                  subtitle: Text(_formatCreatedAt(level.createdAt)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/project/${widget.projectId}/idea-board/${level.id}',
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