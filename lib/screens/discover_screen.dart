import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'join_request_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
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
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search public projects...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
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

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final projects = snapshot.data ?? [];
          final filtered = projects
              .where((project) =>
                  _query.isEmpty ||
                  project.title.toLowerCase().contains(_query.toLowerCase()) ||
                  project.description.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No projects found',
              subtitle: 'Try a different search term',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = filtered[index];
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
                        'Members: ${project.collaboratorCount}/${project.requiredCollaborators > 0 ? project.requiredCollaborators : 'unlimited'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      if (project.requiredSkills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Skills needed: ${project.requiredSkills.join(', ')}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      if (project.isOpenForRequests) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Accepting join requests',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (project.isOpenForRequests)
                        _RequestToJoinButton(project: project)
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.border),
                              foregroundColor: AppTheme.textMuted,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Not accepting requests'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestToJoinButton extends StatefulWidget {
  final Project project;

  const _RequestToJoinButton({required this.project});

  @override
  State<_RequestToJoinButton> createState() => _RequestToJoinButtonState();
}

class _RequestToJoinButtonState extends State<_RequestToJoinButton> {
  bool _isLoading = false;

  void _requestToJoin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JoinRequestScreen(
          projectId: widget.project.id,
          project: widget.project,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _requestToJoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Request to Join'),
      ),
    );
  }
}
