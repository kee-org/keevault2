import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logging/logger.dart';
import 'widgets/dialog_utils.dart';
import '../generated/l10n.dart';

enum PermissionResult { rejected, approved, pending }

Future<PermissionResult> tryToGetPermission(
  BuildContext context,
  Permission permission,
  String permissionName,
  String reason,
  String negativeConsequence,
) async {
  final str = S.of(context);
  while (true) {
    PermissionStatus permissionStatus = await permission.status;
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await permission.request();
      if (permissionStatus == PermissionStatus.permanentlyDenied) {
        l.w('$permissionName permission permanently denied');
        if (await DialogUtils.showConfirmDialog(
            context: context,
            params: ConfirmDialogParams(
              title: str.permissionError,
              content: str.permissionDeniedPermanentlyError(reason),
              positiveButtonText: str.openSettings,
              negativeButtonText: negativeConsequence,
            ))) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!await openAppSettings()) {
              await DialogUtils.showSimpleAlertDialog(
                context,
                str.vaultStatusError,
                str.permissionSettingsOpenError,
                routeAppend: 'couldNotOpenPermissionSettings',
              );
            }
          });
          // User should return later after changing settings so we can try again
          return PermissionResult.pending;
        } else {
          // User does not want to grant permission
          return PermissionResult.rejected;
        }
      }

      if (permissionStatus == PermissionStatus.denied) {
        l.w('$permissionName permission denied: ${permissionStatus.toString()}');
        final tryAgain = await DialogUtils.showConfirmDialog(
            context: context,
            params: ConfirmDialogParams(
              title: str.permissionError,
              content: str.permissionDeniedError(reason),
              positiveButtonText: str.tryAgain,
              negativeButtonText: negativeConsequence,
            ));
        if (!tryAgain) {
          return PermissionResult.rejected;
        }
      }
    } else {
      return PermissionResult.approved;
    }
  }
}
