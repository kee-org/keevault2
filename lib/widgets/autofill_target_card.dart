import 'dart:async';

import 'package:flutter_autofill_service/flutter_autofill_service.dart';
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
    case AutofillConcern.domainUserSelectedOnly:
      return str.autofillWarningDomainUserSelectedOnly(domain);
    case AutofillConcern.domainUncheckable:
      return str.autofillWarningDomainUncheckable(domain);
    case AutofillConcern.appIdSelfReported:
      return str.autofillWarningAppIdSelfReported(target.contextAppId ?? '');
    case AutofillConcern.appIdFromTitle:
      return str.autofillWarningAppIdFromTitle;
    case AutofillConcern.webContentNotVerifiable:
      return target.inTrustedBrowser
          ? str.autofillWarningWebContentNotVerifiableBrowser
          : str.autofillWarningWebContentNotVerifiable;
    case AutofillConcern.focusedDomainUnknown:
      return target.isNotice(concern)
          ? str.autofillWarningFocusedDomainUnknownApp
          : str.autofillWarningFocusedDomainUnknown;
    case AutofillConcern.noIdentity:
      return str.autofillWarningNoIdentity;
  }
}

/// The same concerns as [autofillConcernMessage] but described for a save request, where there are no matches or
/// fields to fill. Each explains what will, or won't, be linked to the new entry (see [AutofillSaveDraft]).
String autofillSaveConcernMessage(S str, AutofillConcern concern, AutofillTarget target) {
  final domain = target.web?.domain.domain ?? '';
  switch (concern) {
    case AutofillConcern.domainNotOwnedByApp:
      return str.autofillSaveWarningDomainNotOwnedByApp(domain);
    case AutofillConcern.unrecognisedBrowser:
      return str.autofillSaveWarningUnrecognisedBrowser(domain);
    case AutofillConcern.domainUserSelectedOnly:
      return str.autofillSaveWarningDomainUserSelectedOnly(domain);
    case AutofillConcern.domainUncheckable:
      return str.autofillSaveWarningDomainUncheckable(domain);
    case AutofillConcern.appIdSelfReported:
      return str.autofillSaveWarningAppIdSelfReported(target.contextAppId ?? '');
    case AutofillConcern.appIdFromTitle:
      return str.autofillSaveWarningAppIdFromTitle;
    case AutofillConcern.webContentNotVerifiable:
      return target.inTrustedBrowser
          ? str.autofillSaveWarningWebContentNotVerifiableBrowser
          : str.autofillSaveWarningWebContentNotVerifiable;
    case AutofillConcern.focusedDomainUnknown:
      return target.isNotice(concern)
          ? str.autofillSaveWarningFocusedDomainUnknownApp
          : str.autofillSaveWarningFocusedDomainUnknown;
    case AutofillConcern.noIdentity:
      return str.autofillSaveWarningNoIdentity;
  }
}

/// One banner per concern, shared by the fill and save flows so that both describe trust in the same way.
/// A caution (info) when the request still has a verified signal or the concern is only a notice, otherwise a warning.
class AutofillConcernBanners extends StatelessWidget {
  final AutofillTarget target;
  final EdgeInsetsGeometry padding;

  /// Describe the concerns for a save request rather than a fill request
  final bool saving;

  const AutofillConcernBanners({super.key, required this.target, this.padding = EdgeInsets.zero, this.saving = false});

  @override
  Widget build(BuildContext context) {
    if (target.concerns.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final str = S.of(context);
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final concern in target.concerns)
            _banner(theme, str, concern, target.hasVerifiedSignal || target.isNotice(concern)),
        ],
      ),
    );
  }

  Widget _banner(ThemeData theme, S str, AutofillConcern concern, bool caution) {
    final background = caution ? theme.colorScheme.tertiaryContainer : theme.colorScheme.errorContainer;
    final foreground = caution ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onErrorContainer;
    return Padding(
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
                  saving
                      ? autofillSaveConcernMessage(str, concern, target)
                      : autofillConcernMessage(str, concern, target),
                  style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
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

    // A browser's id is context, not an identity, so it only appears as a line under the website.
    final String? inAppLine = app == null && target.contextAppId != null
        ? target.contextAppIdTrusted
              ? str.autofillInApp(target.contextAppId!)
              : str.autofillClaimsToBeApp(target.contextAppId!)
        : null;

    final rows = <Widget>[];
    if (app != null) {
      rows.add(
        _SignalRow(
          icon: Icons.apps,
          text: app.appId,
          chip: switch (app.source) {
            AppIdSource.component => _TrustChip.verified(str.autofillChipVerified, str.autofillChipVerifiedAppHint),
            AppIdSource.viewNode => _TrustChip.problem(
              str.autofillChipReportedByApp,
              str.autofillChipReportedByAppHint,
            ),
            AppIdSource.windowTitle ||
            AppIdSource.none => _TrustChip.problem(str.autofillChipBestGuess, str.autofillChipBestGuessHint),
          },
        ),
      );
    }
    if (web != null) {
      final concerns = target.concerns;
      final _TrustChip chip = web.trust == SignalTrust.verified
          ? _TrustChip.verified(str.autofillChipVerified, str.autofillChipVerifiedSiteHint)
          : concerns.contains(AutofillConcern.domainUserSelectedOnly)
          ? _TrustChip.problem(str.autofillChipLinkSettingOnly, str.autofillChipLinkSettingOnlyHint)
          : concerns.contains(AutofillConcern.domainUncheckable)
          ? _TrustChip.problem(str.autofillChipCantCheck)
          : concerns.contains(AutofillConcern.unrecognisedBrowser)
          ? _TrustChip.problem(str.autofillChipUnrecognisedBrowser)
          : concerns.contains(AutofillConcern.domainNotOwnedByApp)
          ? _TrustChip.problem(str.autofillChipNotAppsSite)
          : _TrustChip.problem(str.autofillChipNotVerified);
      final others = _domainList(target.otherDomains);
      rows.add(
        _SignalRow(
          icon: Icons.language,
          text: web.domain.domain,
          subTexts: [
            ?inAppLine,
            if (others != null)
              others.more == 0
                  ? str.autofillAlsoOnPage(others.shown)
                  : str.autofillAlsoOnPageMore(others.shown, others.more),
          ],
          chip: chip,
        ),
      );
    } else if (target.concerns.contains(AutofillConcern.focusedDomainUnknown)) {
      // Web content that we know is there but won't fill, because we can't tell which site has focus
      final others = _domainList(target.otherDomains);
      rows.add(
        _SignalRow(
          icon: Icons.language,
          text: others == null
              ? str.autofillWebContentUnidentified
              : str.autofillWebContentFrom(others.more == 0 ? others.shown : '${others.shown}, …'),
          subTexts: [?inAppLine],
          chip: target.isNotice(AutofillConcern.focusedDomainUnknown)
              ? _TrustChip.neutral(str.autofillChipWontBeFilled)
              : _TrustChip.problem(str.autofillChipWontBeFilled),
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(
        _SignalRow(
          icon: Icons.help_outline,
          text: str.autofillUnknownTarget,
          subTexts: [?inAppLine],
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
  final List<String> subTexts;
  final _TrustChip chip;

  const _SignalRow({required this.icon, required this.text, required this.chip, this.subTexts = const []});

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
                for (final subText in subTexts)
                  SizedBox(
                    width: double.infinity,
                    child: Text(subText, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to [max] domains as a comma separated list, plus how many more were left out, or null if there are none
({String shown, int more})? _domainList(List<AutofillWebDomain> domains, {int max = 3}) {
  if (domains.isEmpty) return null;
  return (
    shown: domains.take(max).map((d) => d.domain).join(', '),
    more: domains.length > max ? domains.length - max : 0,
  );
}

enum _ChipKind { verified, problem, neutral }

/// Status is always conveyed by icon and text as well as colour
class _TrustChip extends StatelessWidget {
  final String label;
  final String? tooltip;
  final _ChipKind kind;

  const _TrustChip.verified(this.label, [this.tooltip]) : kind = _ChipKind.verified;
  const _TrustChip.problem(this.label, [this.tooltip]) : kind = _ChipKind.problem;
  const _TrustChip.neutral(this.label) : tooltip = null, kind = _ChipKind.neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (kind) {
      _ChipKind.verified => (scheme.primaryContainer, scheme.onPrimaryContainer, Icons.verified),
      _ChipKind.problem => (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline),
      _ChipKind.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, Icons.info_outline),
    };
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
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
