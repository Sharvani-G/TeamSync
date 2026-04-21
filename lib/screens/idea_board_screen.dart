import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';

class IdeaBoardScreen extends StatefulWidget {
  final String projectId;
  const IdeaBoardScreen({super.key, required this.projectId});

  @override
  State<IdeaBoardScreen> createState() => _IdeaBoardScreenState();
}

class _IdeaBoardScreenState extends State<IdeaBoardScreen>
    with TickerProviderStateMixin {
  late List<ProjectLevel> _levels;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late AnimationController _listAnimationController;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    final project = projects.firstWhere((p) => p.id == widget.projectId,
        orElse: () => projects.first);
    _levels = List.from(project.levels);

    // FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _fabAnimationController.forward();

    // List animation
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _listAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  void _addNewLevel() {
    showDialog(
      context: context,
      builder: (context) => _AddLevelDialog(
        onAdd: (name, description) {
          setState(() {
            final newId = DateTime.now().millisecondsSinceEpoch.toString();
            _levels.add(ProjectLevel(
              id: newId,
              name: name,
              progress: 0,
              documents: [],
            ));
          });
          // Animate the new item
          _listAnimationController.reset();
          _listAnimationController.forward();
        },
      ),
    );
  }

  void _deleteLevel(String levelId) {
    final index = _levels.indexWhere((level) => level.id == levelId);
    if (index != -1) {
      setState(() {
        _levels.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = projects.firstWhere((p) => p.id == widget.projectId,
        orElse: () => projects.first);

    return Scaffold(
      appBar: SimpleAppBar(
        title: project.title,
        actions: [
          AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabAnimation.value,
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addNewLevel,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(project.title,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _listAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _listAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(_listAnimation),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _levels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final level = _levels[index];
                        return _AnimatedLevelCard(
                          level: level,
                          projectId: widget.projectId,
                          onDelete: () => _deleteLevel(level.id),
                          delay: index * 100,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: FloatingActionButton(
              onPressed: _addNewLevel,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLevelCard extends StatefulWidget {
  final ProjectLevel level;
  final String projectId;
  final VoidCallback onDelete;
  final int delay;

  const _AnimatedLevelCard({
    required this.level,
    required this.projectId,
    required this.onDelete,
    required this.delay,
  });

  @override
  State<_AnimatedLevelCard> createState() => _AnimatedLevelCardState();
}

class _AnimatedLevelCardState extends State<_AnimatedLevelCard>
    with TickerProviderStateMixin {
  late AnimationController _cardAnimationController;
  late Animation<double> _cardAnimation;
  late AnimationController _iconAnimationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.bounceOut,
      ),
    );

    // Start animation with delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _cardAnimationController.forward();
        _iconAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cardAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardAnimation.value,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, '/project/${widget.projectId}/idea-board/${widget.level.id}'),
            child: Card(
              elevation: 2,
              shadowColor: AppTheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFF8FAFC),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _iconAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _iconAnimation.value,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x1A3B82F6),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.level.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.level.documents.length} documents',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: widget.onDelete,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddLevelDialog extends StatefulWidget {
  final Function(String, String) onAdd;

  const _AddLevelDialog({required this.onAdd});

  @override
  State<_AddLevelDialog> createState() => _AddLevelDialogState();
}

class _AddLevelDialogState extends State<_AddLevelDialog>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late AnimationController _dialogAnimationController;
  late Animation<double> _dialogAnimation;

  @override
  void initState() {
    super.initState();
    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dialogAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dialogAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _dialogAnimationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dialogAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dialogAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _dialogAnimation.value,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Add New Level',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter level name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter description (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isNotEmpty) {
                    widget.onAdd(
                      _nameController.text.trim(),
                      _descriptionController.text.trim(),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }
}
