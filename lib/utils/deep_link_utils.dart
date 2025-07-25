import 'dart:core';

/// Parses a KeeVault deep link fragment like:
/// #dest=resetPasswordConfirm,resetAuthToken=<token>,resetEmail=<emailaddress>
/// Returns a map of parameters if dest matches expected value, else null.
Map<String, String>? parseKeeVaultFragment(String fragment, {String expectedDest = 'resetPasswordConfirm'}) {
  if (!fragment.startsWith('dest=')) return null;
  final parts = fragment.substring(5).split(',');
  if (parts.isEmpty) return null;
  final dest = parts[0];
  if (dest != expectedDest) return null;
  final params = <String, String>{'dest': dest};
  for (var i = 1; i < parts.length; i++) {
    final kv = parts[i].split('=');
    if (kv.length == 2) {
      params[kv[0]] = kv[1];
    }
  }
  return params;
}
