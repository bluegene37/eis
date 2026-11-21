// Gene - Nov, 20, 2026: Ported from eis_flutter shared Material 3 components.
// Gene - Nov, 20, 2026: Upgraded shared components to modern Soft UI 2.0 neumorphism with light/dark semantic tokens and responsive headers.
import 'package:material_ui/material_ui.dart';
import '../theme/eis_neumorphic_theme.dart';
import 'neumorphic_widgets.dart';

String formatPhp(double amount) {
  final neg = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final posFromRight = intPart.length - i;
    buffer.write(intPart[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${neg ? '-' : ''}PHP ${buffer.toString()}.${parts[1]}';
}

// Color statusColor(BuildContext context, String status) {
//   switch (status) {
//     case 'TRANSMITTED':
//     case 'ACK-200':
//       return const Color(0xFF0F766E);
//     case 'QUEUED_RETRY':
//     case 'NET503':
//       return const Color(0xFFB45309);
//     case 'REJECTED':
//     case 'SYN004':
//     case 'VAL001':
//     case 'DUP001':
//     case 'SEC001':
//       return Theme.of(context).colorScheme.error;
//     default:
//       return Theme.of(context).colorScheme.primary;
//   }
// }
//
// class KpiCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final String? subtitle;
//   final IconData icon;
//   final Color? accentColor;
//
//   const KpiCard({
//     super.key,
//     required this.label,
//     required this.value,
//     this.subtitle,
//     required this.icon,
//     this.accentColor,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final scheme = Theme.of(context).colorScheme;
//     final color = accentColor ?? scheme.primary;
//     return Card(
//       elevation: 0,
//       color: scheme.surfaceContainerLow,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: color.withValues(alpha: 0.12),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(icon, size: 18, color: color),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     label,
//                     style: Theme.of(context).textTheme.labelMedium?.copyWith(
//                           color: scheme.onSurfaceVariant,
//                           fontWeight: FontWeight.w600,
//                         ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Text(
//               value,
//               style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                     fontWeight: FontWeight.w700,
//                     fontFeatures: const [FontFeature.tabularFigures()],
//                   ),
//             ),
//             if (subtitle != null) ...[
//               const SizedBox(height: 4),
//               Text(
//                 subtitle!,
//                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                       color: scheme.onSurfaceVariant,
//                     ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class StatusBadge extends StatelessWidget {
//   final String label;
//   final Color color;
//   final IconData? icon;
//
//   const StatusBadge({
//     super.key,
//     required this.label,
//     required this.color,
//     this.icon,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (icon != null) ...[
//             Icon(icon, size: 13, color: color),
//             const SizedBox(width: 4),
//           ],
//           Text(
//             label,
//             style: Theme.of(context).textTheme.labelSmall?.copyWith(
//                   color: color,
//                   fontWeight: FontWeight.w700,
//                   fontFamily: 'monospace',
//                 ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class SectionCard extends StatelessWidget {
//   final String title;
//   final String? subtitle;
//   final Widget? trailing;
//   final Widget child;
//
//   const SectionCard({
//     super.key,
//     required this.title,
//     this.subtitle,
//     this.trailing,
//     required this.child,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final scheme = Theme.of(context).colorScheme;
//     return Card(
//       elevation: 0,
//       color: scheme.surfaceContainerLow,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         title,
//                         style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                               fontWeight: FontWeight.w600,
//                             ),
//                       ),
//                       if (subtitle != null)
//                         Text(
//                           subtitle!,
//                           style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                                 color: scheme.onSurfaceVariant,
//                               ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 ?trailing,
//               ],
//             ),
//             const SizedBox(height: 12),
//             child,
//           ],
//         ),
//       ),
//     );
//   }
// }
// Gene - Nov, 20, 2026: Theme-aware status color resolver + Neumorphic KpiCard, StatusBadge, and responsive SectionCard.
Color statusColor(BuildContext context, String status) {
  final tokens = EisNeumorphicTokens.of(context);
  switch (status) {
    case 'TRANSMITTED':
    case 'ACK-200':
      return tokens.success;
    case 'QUEUED_RETRY':
    case 'NET503':
      return tokens.warning;
    case 'REJECTED':
    case 'SYN004':
    case 'VAL001':
    case 'DUP001':
    case 'SEC001':
      return tokens.danger;
    default:
      return tokens.accentPrimary;
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    final color = accentColor ?? tokens.accentPrimary;
    return NeumorphicSurface(
      depth: NeumorphicDepth.raised,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3.5,
            width: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              NeumorphicIconBadge(
                icon: icon,
                color: color,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tokens.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = EisNeumorphicTokens.of(context);
    return NeumorphicSurface(
      depth: NeumorphicDepth.raised,
      borderRadius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    NeumorphicIconBadge(
                      icon: icon!,
                      color: tokens.accentPrimary,
                      size: 38,
                      iconSize: 19,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.textSecondary,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );

              if (trailing == null) return titleBlock;
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  trailing!,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
