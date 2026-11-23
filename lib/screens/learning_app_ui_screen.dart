import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LearningAppUiScreen extends StatelessWidget {
  const LearningAppUiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: SimpleAppBar(title: 'Learning Center'),
      body: Center(
        child: EmptyState(
          icon: Icons.school_outlined,
          title: 'Learning Resources',
          subtitle: 'Educational tutorials and onboarding walkthroughs will appear here.',
        ),
      ),
    );
  }
}
