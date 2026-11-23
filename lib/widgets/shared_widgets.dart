import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

/// Clean, authoritative AppBar following the TeamSync visual design system
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool? showBack;
  final VoidCallback? onBack;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = (showBack ?? canPop) && (canPop || onBack != null);

    return AppBar(
      title: Text(
        title,
        style: AppTheme.heading2,
      ),
      centerTitle: false,
      backgroundColor: AppTheme.panel,
      foregroundColor: AppTheme.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: shouldShowBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppTheme.ink),
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      automaticallyImplyLeading: shouldShowBack,
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppTheme.rule),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// Standard Project Card with clean white surface and hairline border
class ProjectCard extends StatelessWidget {
  final String title;
  final String description;
  final int collaborators;
  final bool isPrivate;
  final String lastUpdated;
  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.title,
    required this.description,
    required this.collaborators,
    required this.isPrivate,
    required this.lastUpdated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
          border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0616191F),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.heading3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _VisibilityBadge(isPrivate: isPrivate),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 15, color: AppTheme.inkSecondary),
                const SizedBox(width: 5),
                Text(
                  '$collaborators collaborators',
                  style: AppTheme.metadataText,
                ),
                const Spacer(),
                const Icon(Icons.access_time, size: 14, color: AppTheme.inkSecondary),
                const SizedBox(width: 5),
                Text(
                  lastUpdated,
                  style: AppTheme.metadataText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final bool isPrivate;
  const _VisibilityBadge({required this.isPrivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPrivate ? AppTheme.groundMuted : AppColors.dpSuccessBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrivate ? AppTheme.rule : AppColors.dpSuccess.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate) ...[
            const Icon(Icons.lock_outline, size: 11, color: AppTheme.inkSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            isPrivate ? 'Private' : 'Public',
            style: AppTheme.labelText.copyWith(
              color: isPrivate ? AppTheme.inkSecondary : AppColors.dpSuccess,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular User Avatar with initials or network image
class UserAvatar extends StatelessWidget {
  final String name;
  final String? username;
  final double size;
  final Color? color;
  final String? imageUrl;

  const UserAvatar({
    super.key,
    required this.name,
    this.username,
    this.size = 36,
    this.color,
    this.imageUrl,
  });

  String get initials {
    final source = (username != null && username!.trim().isNotEmpty)
        ? username!.trim()
        : name.trim();
    if (source.isEmpty) {
      return '?';
    }
    final match = RegExp(r'[A-Za-z]').firstMatch(source);
    return match?.group(0)?.toUpperCase() ?? '?';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.dpInfoBg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.rule, width: 1),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (_, __, ___) => _buildInitials(),
              )
            : _buildInitials(),
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        initials,
        style: AppTheme.hostGrotesk(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: color != null ? AppTheme.ink : AppTheme.accent,
        ),
      ),
    );
  }
}

/// Uppercase section header label with consistent tracking
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTheme.labelText.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: AppTheme.inkSecondary,
        ),
      ),
    );
  }
}

/// Clean empty state with circular icon, title, and subtitle
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.groundMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.rule, width: 1),
              ),
              child: Icon(icon, size: 32, color: AppTheme.inkSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTheme.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Authoritative Card Container
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0616191F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        child: cardContent,
      );
    }
    return cardContent;
  }
}
