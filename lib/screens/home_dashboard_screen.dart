import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(backgroundColor: AppTheme.surface, elevation: 0, title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Project>>(
          stream: ProjectService.instance.watchMyProjects(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: \\${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final projects = snapshot.data ?? <Project>[];
            if (projects.isEmpty) return Center(child: Text('No projects yet', style: TextStyle(color: AppTheme.textMuted)));

            return LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1100;
              return isWide ? _horizontal(projects, constraints) : _vertical(projects, constraints);
            });
          },
        ),
      ),
    );
  }

  Widget _horizontal(List<Project> projects, BoxConstraints constraints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: projects.map((p) {
        final color = _palette[projects.indexOf(p) % _palette.length];
        return Container(width: math.min(380, constraints.maxWidth * 0.36), margin: const EdgeInsets.symmetric(horizontal: 8), child: _Tile(p, color));
      }).toList()),
    );
  }

  Widget _vertical(List<Project> projects, BoxConstraints constraints) {
    return ListView.builder(itemCount: projects.length, itemBuilder: (c, i) {final p = projects[i]; final color = _palette[i % _palette.length]; return Padding(padding: const EdgeInsets.only(bottom:12), child: SizedBox(height:140, child: _Tile(p, color)));});
  }

  static const _palette = [Color(0xFF979DBF), Color(0xFFE29497), Color(0xFFDBDBA5)];
}

class _Tile extends StatelessWidget {
  final Project project;
  final Color color;
  const _Tile(this.project, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    final created = DateFormat.yMMMd().format(project.createdAt);
    final collab = project.safeCollaboratorCount;
    final progress = (project.progressValue).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/project/${project.id}'),
      child: CustomPaint(
        painter: _BucketPainter(color: color),
        child: Container(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(project.displayTitle, style: const TextStyle(fontSize:16, fontWeight: FontWeight.w700)),
            const SizedBox(height:6),
            Text(created, style: TextStyle(color: AppTheme.textMuted, fontSize:12)),
            const Spacer(),
            FutureBuilder<AppUser?>(future: UserService.instance.getUserById(project.createdBy), builder: (c,s)=> Text('Admin: ${s.data?.name ?? s.data?.username ?? 'Admin'}', style: TextStyle(color: AppTheme.textSecondary))),
          ])),
          const SizedBox(width:12),
          SizedBox(width:68, height:68, child: CustomPaint(painter: _ProgressPainter(progress: progress), child: Center(child: Text('${(progress*100).round()}%')))),
        ])),
      ),
    );
  }
}

class _BucketPainter extends CustomPainter {
  final Color color; const _BucketPainter({required this.color});
  @override void paint(Canvas canvas, Size size) {final p=Paint()..color=color; final path=Path(); path.moveTo(0,size.height); path.lineTo(0,28); path.quadraticBezierTo(size.width*0.25,0,size.width*0.5,26); path.quadraticBezierTo(size.width*0.75,0,size.width,28); path.lineTo(size.width,size.height); path.close(); canvas.drawPath(path,p); final inner=RRect.fromRectAndRadius(Rect.fromLTWH(8,34,size.width-16,size.height-42), const Radius.circular(12)); canvas.drawRRect(inner, Paint()..color=Colors.white.withOpacity(0.92));}
  @override bool shouldRepaint(covariant CustomPainter old)=>false;
}

class _ProgressPainter extends CustomPainter {
  final double progress; const _ProgressPainter({required this.progress});
  @override void paint(Canvas canvas, Size size){final c=Offset(size.width/2,size.height/2); final r=math.min(size.width,size.height)/2-6; final bg=Paint()..color=Colors.white70..style=PaintingStyle.stroke..strokeWidth=6; final fg=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=6..strokeCap=StrokeCap.round; canvas.drawCircle(c,r,bg); canvas.drawArc(Rect.fromCircle(center:c,radius:r), -math.pi/2, 2*math.pi*progress, false, fg);} 
  @override bool shouldRepaint(covariant _ProgressPainter old)=>old.progress!=progress;
}
