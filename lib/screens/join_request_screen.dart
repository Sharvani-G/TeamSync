import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/file_service.dart' show PlatformFile, FileService;
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';

class JoinRequestScreen extends StatefulWidget {
  final String projectId;
  final Project project;

  const JoinRequestScreen({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  State<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends State<JoinRequestScreen> {
  final _skillsController = TextEditingController();
  final _messageController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  
  final List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _skillsController.dispose();
    _messageController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File attachment is enabled for project documents and chat channels.', style: AppTheme.bodyFont(color: Colors.white)),
        backgroundColor: AppTheme.field,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitRequest() async {
    final skills = _skillsController.text.trim();
    final message = _messageController.text.trim();

    if (skills.isEmpty) {
      _showSnackBar('Please list your relevant skills');
      return;
    }
    if (message.isEmpty) {
      _showSnackBar('Please write a short message explaining how you can contribute');
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> fileUrls = [];
      if (_selectedFiles.isNotEmpty) {
        fileUrls = await FileService.instance.uploadPortfolioFiles(
          widget.projectId,
          _selectedFiles,
        );
      }

      final skillsList = skills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      await ProjectService.instance.submitJoinRequest(
        projectId: widget.projectId,
        skills: skillsList,
        message: message,
        githubLink: _githubController.text.trim(),
        linkedinLink: _linkedinController.text.trim(),
        fileUrls: fileUrls,
      );

      if (!mounted) return;
      _showSnackBar('Join request submitted successfully!');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.bodyFont(color: Colors.white)),
        backgroundColor: AppTheme.field,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: SimpleAppBar(title: 'Join ${widget.project.title}'),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Requirements Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.rule, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Project Requirements',
                                  style: AppTheme.displayFont(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (widget.project.requiredSkills.isNotEmpty) ...[
                              Text(
                                'Desired Skills:',
                                style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inkSecondary),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: widget.project.requiredSkills.map((skill) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.groundMuted,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.rule),
                                    ),
                                    child: Text(
                                      skill,
                                      style: AppTheme.bodyFont(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.ink),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (widget.project.requiredCollaborators > 0)
                              Text(
                                'Seeking up to ${widget.project.requiredCollaborators} collaborators',
                                style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.rule, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Your Relevant Skills *'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _skillsController,
                              style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'e.g. Flutter, Firebase, UI Design, Node.js',
                                fillColor: AppTheme.groundMuted,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _label('Message to Project Admin *'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _messageController,
                              maxLines: 4,
                              style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'Explain why you are excited about this project and what expertise you can contribute.',
                                fillColor: AppTheme.groundMuted,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _label('GitHub Profile or Repository (optional)'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _githubController,
                              style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'https://github.com/username',
                                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                                fillColor: AppTheme.groundMuted,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _label('LinkedIn or Portfolio Link (optional)'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _linkedinController,
                              style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                              decoration: InputDecoration(
                                hintText: 'https://linkedin.com/in/username',
                                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                                fillColor: AppTheme.groundMuted,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _label('Portfolio Attachments (optional)'),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.groundMuted,
                                border: Border.all(color: AppTheme.rule),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  if (_selectedFiles.isNotEmpty) ...[
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _selectedFiles.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            _selectedFiles[index].name,
                                            style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.ink),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.close, size: 18),
                                            onPressed: () => _removeFile(index),
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(),
                                  ],
                                  TextButton.icon(
                                    onPressed: _pickFiles,
                                    icon: const Icon(Icons.attach_file, color: AppTheme.accent),
                                    label: Text('Attach Portfolio Document', style: AppTheme.bodyFont(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Submit Join Request',
                            style: AppTheme.bodyFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTheme.bodyFont(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.ink,
      ),
    );
  }
}
