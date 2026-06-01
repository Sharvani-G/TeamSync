import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _skillController = TextEditingController();
  final _collabUsernameController = TextEditingController();
  final _collabCountController = TextEditingController(text: '1');

  final List<String> _skills = [];
  final List<String> _sections = ["Problem Statement", "Research", "Design", "Development", "Testing"];
  String _visibility = 'private';
  bool _isOpenToRequests = false;
  final List<AppUser> _selectedCollaborators = [];
  bool _isSearchingUser = false;
  String? _userSearchError;
  final _sectionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _skillController.dispose();
    _collabUsernameController.dispose();
    _collabCountController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _addSection() {
    final section = _sectionController.text.trim();
    if (section.isNotEmpty && !_sections.contains(section)) {
      setState(() {
        _sections.add(section);
        _sectionController.clear();
      });
    }
  }

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillController.clear();
      });
    }
  }

  Future<void> _searchAndAddCollaborator() async {
    final username = _collabUsernameController.text.trim();
    if (username.isEmpty) return;

    if (_selectedCollaborators.any((u) => u.username == username)) {
      setState(() => _userSearchError = 'User already added');
      return;
    }

    setState(() {
      _isSearchingUser = true;
      _userSearchError = null;
    });

    try {
      final user = await UserService.instance.getUserByUsername(username);
      if (user != null) {
        // getUserByUsername returns (uid, username) or similar?
        // Let's check models.dart for AppUser.
        // ProjectService uses UserService.getUserByUsername(username).
        // I should probably fetch the full AppUser.
        final fullUser = await UserService.instance.getUserById(user.$1);
        if (fullUser != null) {
          if (fullUser.id == FirebaseAuth.instance.currentUser?.uid) {
            setState(() => _userSearchError = 'Cannot add yourself');
          } else {
            setState(() {
              _selectedCollaborators.add(fullUser);
              _collabUsernameController.clear();
            });
          }
        } else {
          setState(() => _userSearchError = 'User not found');
        }
      } else {
        setState(() => _userSearchError = 'User not found');
      }
    } catch (e) {
      setState(() => _userSearchError = 'Error searching user');
    } finally {
      setState(() => _isSearchingUser = false);
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (_sections.isEmpty) {
        throw Exception('At least one Idea Board section is required');
      }

      final projectId = await ProjectService.instance.createProject(
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        requiredSkills: _skills,
        visibility: _visibility,
        isOpenForRequests: _isOpenToRequests,
        requiredCollaborators: _isOpenToRequests ? int.tryParse(_collabCountController.text) ?? 1 : 0,
        collaboratorUsernames: _selectedCollaborators.map((u) => u.username).toList(),
        contactEmail: user.email ?? '',
        ideaBoardSections: _sections,
      );

      if (mounted) {
        // Navigate directly to workspace
        Navigator.pushReplacementNamed(context, '/project/$projectId/workspace');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.kTextPrimary, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Project', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('Project Name *'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                decoration: _inputDecoration('Enter project name'),
                validator: (v) => v == null || v.isEmpty ? 'Project name is required' : null,
              ),
              SizedBox(height: 20.h),

              _Label('Project Description *'),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _descController,
                style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                minLines: 3,
                maxLines: null,
                decoration: _inputDecoration('Describe your project goals and scope'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Description is required';
                  if (v.length < 20) return 'Description must be at least 20 characters';
                  return null;
                },
              ),
              SizedBox(height: 20.h),

              _Label('Skills / Roles needed (optional)'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillController,
                      style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                      decoration: _inputDecoration('e.g. Flutter Developer'),
                      onSubmitted: (_) => _addSkill(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: _addSkill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kAccentBlue,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    child: Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: _skills.map((skill) => Chip(
                  label: Text(skill, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                  backgroundColor: AppColors.kBgElevated,
                  deleteIcon: Icon(Icons.close, size: 14.sp, color: Colors.white),
                  onDeleted: () => setState(() => _skills.remove(skill)),
                )).toList(),
              ),
              SizedBox(height: 20.h),

              _Label('Project Visibility *'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  _VisibilityOption(
                    label: 'Private',
                    value: 'private',
                    groupValue: _visibility,
                    onChanged: (v) => setState(() {
                      _visibility = v!;
                      _isOpenToRequests = false;
                    }),
                  ),
                  SizedBox(width: 16.w),
                  _VisibilityOption(
                    label: 'Public',
                    value: 'public',
                    groupValue: _visibility,
                    onChanged: (v) => setState(() => _visibility = v!),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              if (_visibility == 'public') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Label('Open to join requests'),
                    Switch(
                      value: _isOpenToRequests,
                      onChanged: (v) => setState(() => _isOpenToRequests = v),
                      activeColor: AppColors.kAccentBlue,
                    ),
                  ],
                ),
                if (_isOpenToRequests) ...[
                  SizedBox(height: 8.h),
                  _Label('Collaborators required (1-20)'),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _collabCountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                    decoration: _inputDecoration('Number of collaborators needed'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 20) return 'Enter a number between 1 and 20';
                      return null;
                    },
                  ),
                  SizedBox(height: 20.h),
                ],
              ],

              SizedBox(height: 20.h),

              _Label('Idea Board Sections *'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sectionController,
                      style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                      decoration: _inputDecoration('e.g. Analysis'),
                      onSubmitted: (_) => _addSection(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: _addSection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kAccentBlue,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    child: Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.kBgInput,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final String item = _sections.removeAt(oldIndex);
                      _sections.insert(newIndex, item);
                    });
                  },
                  children: _sections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;
                    return ListTile(
                      key: ValueKey(section),
                      dense: true,
                      title: Text(section, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.close, size: 18.sp, color: Colors.white70),
                            onPressed: () {
                              if (_sections.length > 1) {
                                setState(() => _sections.removeAt(index));
                              }
                            },
                          ),
                          Icon(Icons.drag_handle, color: Colors.white54),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 20.h),

              _Label('Add Collaborators (optional)'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _collabUsernameController,
                      style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14.sp),
                      decoration: _inputDecoration('Enter username').copyWith(
                        errorText: _userSearchError,
                      ),
                      onSubmitted: (_) => _searchAndAddCollaborator(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _isSearchingUser
                    ? SizedBox(width: 40, height: 40, child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _searchAndAddCollaborator,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kAccentBlue,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        ),
                        child: Text('Add', style: TextStyle(color: Colors.white)),
                      ),
                ],
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                children: _selectedCollaborators.map((u) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.kAccentLight,
                    child: Text(u.name[0].toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 10.sp)),
                  ),
                  label: Text(u.name, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                  backgroundColor: AppColors.kBgElevated,
                  deleteIcon: Icon(Icons.close, size: 14.sp, color: Colors.white),
                  onDeleted: () => setState(() => _selectedCollaborators.remove(u)),
                )).toList(),
              ),
              SizedBox(height: 40.h),

              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _createProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kAccentBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text('Create Project', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.kTextHint),
      filled: true,
      fillColor: AppColors.kBgInput,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.kAccentBlue, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.kDanger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.kDanger, width: 1.5)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: AppColors.kTextSecond, fontSize: 13.sp, fontWeight: FontWeight.w600));
  }
}

class _VisibilityOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _VisibilityOption({required this.label, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.kAccentBlue : AppColors.kBgElevated,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
