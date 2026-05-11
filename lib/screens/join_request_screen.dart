import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/file_service.dart';
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
  
  final List<Map<String, String>> _selectedFiles = [];
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
    // File picker disabled in v1.0 - coming in v1.1
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File upload coming soon in v1.1')),
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
      _showSnackBar('Please write a short message');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Submit join request first to get ID if needed, 
      // but here we just need project context.
      
      // 1. Upload files if any
      List<String> fileUrls = [];
      if (_selectedFiles.isNotEmpty) {
        fileUrls = await FileService.instance.uploadPortfolioFiles(
          widget.projectId,
          _selectedFiles,
        );
      }

      final skillsList = skills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // 2. Submit join request
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
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: 'Join ${widget.project.title}'),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Requirements info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Requirements',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.project.requiredSkills.isNotEmpty)
                          Text(
                            'Desired Skills: ${widget.project.requiredSkills.join(", ")}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (widget.project.requiredCollaborators > 0)
                          Text(
                            'Seeking ${widget.project.requiredCollaborators} collaborators',
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _label('Your Relevant Skills *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _skillsController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Flutter, Firebase, UI Design',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _label('Message to Project Admin *'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Why do you want to join and what can you contribute?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _label('GitHub Link (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _githubController,
                    decoration: InputDecoration(
                      hintText: 'https://github.com/username',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _label('LinkedIn Link (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _linkedinController,
                    decoration: InputDecoration(
                      hintText: 'https://linkedin.com/in/username',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _label('Portfolio Files (optional)'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
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
                                  style: const TextStyle(fontSize: 12),
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
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attach Files'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Request'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
