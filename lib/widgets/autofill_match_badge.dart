import 'package:material_ui/material_ui.dart';

import '../autofill_matching.dart';
import '../generated/l10n.dart';

/// A compact chip saying how well, and how trustworthily, an entry matches the target.
/// The label and icon carry the meaning (never colour alone) and the tooltip lists every signal that matched.
class AutofillMatchBadge extends StatelessWidget {
  final AutofillMatch match;
  final AutofillTarget target;

  const AutofillMatchBadge({super.key, required this.match, required this.target});

  @override
  Widget build(BuildContext context) {
    final str = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final appId = target.app?.appId ?? '';
    final host = match.matchedUrlHost ?? '';

    final String label;
    final IconData icon;
    final Color background;
    final Color foreground;
    String tooltip;
    switch (match.tier) {
      case AutofillMatchTier.appAndSite:
        label = str.autofillBadgeAppAndSiteMatch;
        icon = Icons.verified;
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        tooltip = str.autofillBadgeTooltipAppAndSite(appId, host);
      case AutofillMatchTier.strong:
        icon = Icons.verified;
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        if (match.viaVerifiedApp) {
          label = str.autofillBadgeAppMatch;
          tooltip = str.autofillBadgeTooltipApp(appId);
          if (match.hasUnverifiedWebMatch) {
            tooltip = '$tooltip. ${str.autofillBadgeTooltipAlsoSavedForUnowned(host)}';
          }
        } else {
          label = str.autofillBadgeExactMatch;
          tooltip = str.autofillBadgeTooltipExact(host);
        }
      case AutofillMatchTier.domain:
        label = str.autofillBadgeDomainMatch;
        icon = Icons.link;
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        tooltip = str.autofillBadgeTooltipDomain(host);
      case AutofillMatchTier.unverified:
        label = str.autofillBadgeUnverified;
        icon = Icons.warning_amber;
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        tooltip = match.webMatched != null
            ? str.autofillBadgeTooltipUnverifiedSite(host)
            : str.autofillBadgeTooltipUnverifiedApp(appId);
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label. $tooltip',
      child: Tooltip(
        message: tooltip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
