import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Horizontal scrollable grid showing all 10 transition options.
///
/// Each transition is displayed as a small animated preview card.
class TransitionPicker extends StatelessWidget {
  final String? selectedTransition;
  final ValueChanged<String?> onChanged;

  const TransitionPicker({
    super.key,
    this.selectedTransition,
    required this.onChanged,
  });

  static const List<_TransitionOption> _transitions = [
    _TransitionOption('fade', 'Crossfade', Icons.blur_on_rounded),
    _TransitionOption('slideleft', 'Slide Left', Icons.arrow_back_rounded),
    _TransitionOption('slideright', 'Slide Right', Icons.arrow_forward_rounded),
    _TransitionOption('slideup', 'Slide Up', Icons.arrow_upward_rounded),
    _TransitionOption('slidedown', 'Slide Down', Icons.arrow_downward_rounded),
    _TransitionOption('wipeleft', 'Wipe Left', Icons.swipe_left_rounded),
    _TransitionOption('circleopen', 'Circle Open', Icons.circle_outlined),
    _TransitionOption('diamond', 'Diamond', Icons.diamond_outlined),
    _TransitionOption('pixelize', 'Pixelize', Icons.grid_on_rounded),
    _TransitionOption('zoompan', 'Zoom In', Icons.zoom_in_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Transitions', style: AppTheme.headingSm),
            if (selectedTransition != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Text(
                  'Clear',
                  style: AppTheme.labelSm.copyWith(color: AppTheme.accentSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _transitions.length,
            separatorBuilder: (_, index) => const SizedBox(width: AppTheme.spacingS),
            itemBuilder: (context, index) {
              final t = _transitions[index];
              final isSelected = selectedTransition == t.id;
              return _TransitionCard(
                option: t,
                isSelected: isSelected,
                onTap: () => onChanged(isSelected ? null : t.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransitionOption {
  final String id;
  final String label;
  final IconData icon;

  const _TransitionOption(this.id, this.label, this.icon);
}

class _TransitionCard extends StatefulWidget {
  final _TransitionOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransitionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TransitionCard> createState() => _TransitionCardState();
}

class _TransitionCardState extends State<_TransitionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => _hoverController.forward(),
        onExit: (_) => _hoverController.reverse(),
        child: AnimatedBuilder(
          animation: _hoverController,
          builder: (context, child) {
            final scale = 1.0 + (_hoverController.value * 0.05);
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 85,
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: widget.isSelected
                        ? AppTheme.accentPrimary
                        : AppTheme.surfaceBorder,
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: widget.isSelected
                      ? AppTheme.glowShadow(AppTheme.accentPrimary, blur: 12)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.option.icon,
                      size: 28,
                      color: widget.isSelected
                          ? AppTheme.accentPrimary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.option.label,
                      style: AppTheme.bodySm.copyWith(
                        color: widget.isSelected
                            ? AppTheme.accentPrimary
                            : AppTheme.textSecondary,
                        fontWeight:
                            widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
