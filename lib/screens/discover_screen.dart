import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/project_service.dart';
import '../models/models.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Discover'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search public projects...',
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppTheme.textMuted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Project>>(
        stream: ProjectService.instance.watchPublicProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProjects = snapshot.data ?? [];
          final filtered = allProjects
              .where((p) =>
                  _query.isEmpty ||
                  p.title.toLowerCase().contains(_query.toLowerCase()) ||
                  p.description.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No projects found',
              subtitle: allProjects.isEmpty
                  ? 'No public projects available yet'
                  : 'Try a different search term',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = filtered[index];
              final memberCount = project.collaborators.length + 1; // +1 for creator

              return _buildProjectCard(
                context: context,
                project: project,
                memberCount: memberCount,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectCard({
    required BuildContext context,
    required Project project,
    required int memberCount,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              project.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Members: $memberCount/${project.requiredCollaborators > 0 ? project.requiredCollaborators : 'unlimited'}',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
            ),
            if (project.isOpenForRequests) ...[
              const SizedBox(height: 4),
              const Text(
                'Looking for collaborators',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: project.isOpenForRequests
                    ? () => _requestToJoin(context, project)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.border),
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  project.isOpenForRequests
                      ? 'Request to Join'
                      : 'Not accepting requests',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestToJoin(BuildContext context, Project project) async {
    try {
      await ProjectService.instance.requestToJoinProject(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Join request sent to ${project.title}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
