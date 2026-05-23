import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<FAQItem> faqItems = [
    FAQItem(
      category: 'Getting Started',
      question: 'How do I create a project?',
      answer:
          'To create a project, tap the "Add Project" button on the home dashboard. Enter your project name, description, and invite team members. You\'re all set!',
    ),
    FAQItem(
      category: 'Getting Started',
      question: 'How do I invite team members?',
      answer:
          'When creating a project, you can add collaborators in the team members section. You can also edit projects later to add or remove team members.',
    ),
    FAQItem(
      category: 'Projects',
      question: 'Can I delete a project?',
      answer:
          'Yes, project owners can delete projects. Navigate to the project settings and select "Delete Project". This action cannot be undone.',
    ),
    FAQItem(
      category: 'Projects',
      question: 'What are project levels?',
      answer:
          'Levels track your project progress. As you complete milestones and tasks, your project advances through different levels, unlocking achievements.',
    ),
    FAQItem(
      category: 'Collaboration',
      question: 'How do I create a channel?',
      answer:
          'In any project, open the Chat section and tap the "Create Channel" button. Give your channel a name and optionally make it private.',
    ),
    FAQItem(
      category: 'Collaboration',
      question: 'What\'s the difference between private and public channels?',
      answer:
          'Public channels are visible to all project members. Private channels are only accessible to invited members, great for sensitive discussions.',
    ),
    FAQItem(
      category: 'Calls',
      question: 'How do I start an instant call?',
      answer:
          'Open the Calls section in any project, tap "Start Instant Call", select collaborators, and you\'re connected! The call happens entirely within the app.',
    ),
    FAQItem(
      category: 'Calls',
      question: 'Can I schedule calls in advance?',
      answer:
          'Yes! Use the "Schedule Call" option to pick a date, time, agenda, and participants. Everyone will receive a reminder before the call.',
    ),
    FAQItem(
      category: 'Privacy & Security',
      question: 'Is my data secure?',
      answer:
          'All data is encrypted in transit and at rest using industry-standard security. We comply with privacy regulations and never share your data with third parties.',
    ),
    FAQItem(
      category: 'Privacy & Security',
      question: 'Can I download my data?',
      answer:
          'Yes, you can request a data download from Settings > Data & Storage. You\'ll receive all your personal data in a portable format.',
    ),
  ];

  late List<FAQCategory> _categories;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initializeCategories();
  }

  void _initializeCategories() {
    final categorySet = <String>{};
    for (var item in faqItems) {
      categorySet.add(item.category);
    }
    _categories = categorySet
        .map((cat) => FAQCategory(name: cat))
        .toList();
    _selectedCategory = _categories.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == null
        ? faqItems
        : faqItems
            .where((item) => item.category == _selectedCategory)
            .toList();

    return Scaffold(
      appBar: SimpleAppBar(title: 'FAQ'),
      body: Column(
        children: [
          // Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(
                _categories.length,
                (index) {
                  final category = _categories[index];
                  final isSelected = category.name == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory =
                              selected ? category.name : null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No FAQs found'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FAQCard(item: item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;
  bool isExpanded = false;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class FAQCategory {
  final String name;

  FAQCategory({required this.name});
}

class _FAQCard extends StatefulWidget {
  final FAQItem item;

  const _FAQCard({required this.item});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          widget.item.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: RotationTransition(
          turns: Tween(begin: 0.0, end: 0.5).animate(_controller),
          child: const Icon(Icons.expand_more_outlined),
        ),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        },
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            alignment: Alignment.centerLeft,
            child: Text(
              widget.item.answer,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
