import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../autofill_matching.dart';
import '../cubit/autofill_cubit.dart';
import '../generated/l10n.dart';

String autofillConcernMessage(S str, AutofillConcern concern, AutofillTarget target) {
  final domain = target.web?.domain.domain ?? '';
  switch (concern) {
    case AutofillConcern.domainNotOwnedByApp:
      return str.autofillWarningDomainNotOwnedByApp(domain);
    case AutofillConcern.unrecognisedBrowser:
      return str.autofillWarningUnrecognisedBrowser(domain);
    case AutofillConcern.appIdFromTitle:
      return str.autofillWarningAppIdFromTitle;
    case AutofillConcern.webContentNotVerifiable:
      return str.autofillWarningWebContentNotVerifiable;
    case AutofillConcern.multipleDomains:
      return str.autofillWarningMultipleDomains;
    case AutofillConcern.noIdentity:
      return str.autofillWarningNoIdentity;
  }
}

/// One banner per concern, shared by the fill and save flows so that both describe trust in the same way.
/// A caution (info) when the request still has a verified signal, otherwise a warning.
class AutofillConcernBanners extends StatelessWidget {
  final AutofillTarget target;
  final EdgeInsetsGeometry padding;

  const AutofillConcernBanners({super.key, required this.target, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    if (target.concerns.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final str = S.of(context);
    final caution = target.hasVerifiedSignal;
    final background = caution ? theme.colorScheme.tertiaryContainer : theme.colorScheme.errorContainer;
    final foreground = caution ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onErrorContainer;
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final concern in target.concerns)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                container: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(caution ? Icons.info_outline : Icons.warning_amber, color: foreground, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          autofillConcernMessage(str, concern, target),
                          style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What we are filling into, what Android could verify about it and what we will remember about the user's choice.
class AutofillTargetCard extends StatelessWidget {
  final AutofillRequested state;

  const AutofillTargetCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final str = S.of(context);
    final cubit = BlocProvider.of<AutofillCubit>(context);
    final target = state.target;
    final app = target.app;
    final web = target.web;

    final learnApp = app?.trust == SignalTrust.verified;
    final offerLinkUnverifiedDomain = learnApp && web != null && web.trust == SignalTrust.unverified;
    final learnWeb =
        web != null && (web.trust == SignalTrust.verified || (offerLinkUnverifiedDomain && state.linkUnverifiedDomain));
    final learningText = learnApp && learnWeb
        ? str.autofillWillLinkAppAndSite
        : learnApp
        ? str.autofillWillLinkApp
        : learnWeb
        ? str.autofillWillLinkSite
        : str.autofillWontLink;

    final rows = <Widget>[];
    if (app != null) {
      rows.add(
        _SignalRow(
          icon: Icons.apps,
          text: app.appId,
          chip: app.trust == SignalTrust.verified
              ? _TrustChip.verified(str.autofillChipVerified, str.autofillChipVerifiedAppHint)
              : _TrustChip.problem(str.autofillChipNotVerified),
        ),
      );
    }
    if (web != null) {
      final String problem = target.concerns.contains(AutofillConcern.unrecognisedBrowser)
          ? str.autofillChipUnrecognisedBrowser
          : target.concerns.contains(AutofillConcern.domainNotOwnedByApp)
          ? str.autofillChipNotAppsSite
          : str.autofillChipNotVerified;
      rows.add(
        _SignalRow(
          icon: Icons.language,
          text: web.domain.domain,
          // A browser's id is context, not an identity, so it only appears as a line under the website.
          subText: app == null && target.contextAppId != null ? str.autofillInApp(target.contextAppId!) : null,
          chip: web.trust == SignalTrust.verified
              ? _TrustChip.verified(str.autofillChipVerified, str.autofillChipVerifiedSiteHint)
              : _TrustChip.problem(problem),
        ),
      );
    }
    if (app == null && web == null) {
      rows.add(
        _SignalRow(
          icon: Icons.help_outline,
          text: str.autofillUnknownTarget,
          subText: target.contextAppId != null ? str.autofillInApp(target.contextAppId!) : null,
          chip: _TrustChip.problem(str.autofillChipNotVerified),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str.autofillFillInto, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              ...rows,
              const SizedBox(height: 4),
              Text('${str.autofillListedFirstHint} $learningText', style: theme.textTheme.bodyMedium),
              if (offerLinkUnverifiedDomain)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(str.autofillAlsoLinkDomain(web.domain.domain)),
                  value: state.linkUnverifiedDomain,
                  onChanged: cubit.setLinkUnverifiedDomain,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => unawaited(cubit.cancelFill()), child: Text(str.autofillCancel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subText;
  final _TrustChip chip;

  const _SignalRow({required this.icon, required this.text, required this.chip, this.subText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(text, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                chip,
                if (subText != null)
                  SizedBox(
                    width: double.infinity,
                    child: Text(subText!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status is always conveyed by icon and text as well as colour
class _TrustChip extends StatelessWidget {
  final String label;
  final String? tooltip;
  final bool verified;

  const _TrustChip.verified(this.label, [this.tooltip]) : verified = true;
  const _TrustChip.problem(this.label) : tooltip = null, verified = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = verified ? scheme.primaryContainer : scheme.errorContainer;
    final foreground = verified ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified : Icons.error_outline, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
          ),
        ],
      ),
    );
    final message = tooltip;
    if (message == null) return chip;
    // Long press (or hover / screen reader long press) shows the explanation
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 6),
      child: chip,
    );
  }
}
