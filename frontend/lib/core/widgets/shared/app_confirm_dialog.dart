import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';

/// Dialogue de confirmation standardisé PHARMA+
/// Remplace showDialog custom dans toutes les pages
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirmer',
    this.cancelText = 'Annuler',
    this.confirmActionText,
    this.cancelActionText,
    this.type = AppConfirmType.warning,
    this.icon,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.confirmLoading = false,
    this.cancelLoading = false,
    this.extraContent,
    this.extraContentPadding,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final String? confirmActionText;
  final String? cancelActionText;
  final AppConfirmType type;
  final IconData? icon;
  final Future<void> Function()? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool confirmLoading;
  final bool cancelLoading;
  final Widget? extraContent;
  final EdgeInsetsGeometry? extraContentPadding;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    AppConfirmType type = AppConfirmType.warning,
    IconData? icon,
    Future<void> Function()? onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    Widget? extraContent,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: !isDestructive,
      builder: (context) => AppConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        type: type,
        icon: icon,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDestructive: isDestructive,
        extraContent: extraContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    final config = _getConfig(context);

    return AlertDialog(
      backgroundColor: isDark ? tokens.bgSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.rDialog),
      ),
      elevation: tokens.elevation4,
      titlePadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        tokens.sp5,
        tokens.sp6,
        tokens.sp2,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        0,
        tokens.sp6,
        tokens.sp3,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        tokens.sp4,
        0,
        tokens.sp4,
        tokens.sp4,
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.sp2),
            decoration: BoxDecoration(
              color: config.bgColor,
              borderRadius: BorderRadius.circular(tokens.rMd),
            ),
            child: Icon(
              icon ?? config.icon,
              color: config.iconColor,
              size: tokens.fontSizeXl,
            ),
          ),
          SizedBox(width: tokens.sp3),
          Expanded(
            child: Text(
              title,
              style: tokens.headlineSmall.copyWith(
                color: isDark ? tokens.textPrimary : tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: tokens.bodyMedium.copyWith(
              color: isDark ? tokens.textSecondary : tokens.textSecondary,
              height: 1.5,
            ),
          ),
          if (extraContent != null) ...[
            SizedBox(height: tokens.sp4),
            Padding(
              padding: extraContentPadding ?? EdgeInsets.zero,
              child: extraContent!,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: cancelLoading
              ? null
              : () {
                  Navigator.of(context).pop(false);
                  onCancel?.call();
                },
          style: TextButton.styleFrom(
            foregroundColor: isDark ? tokens.textSecondary : tokens.textSecondary,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sp5,
              vertical: tokens.sp3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.rButton),
            ),
          ),
          child: cancelLoading
              ? SizedBox(
                  width: tokens.sp4,
                  height: tokens.sp4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? tokens.textSecondary : tokens.textSecondary,
                  ),
                )
              : Text(
                  cancelActionText ?? cancelText,
                  style: tokens.labelLarge,
                ),
        ),
        SizedBox(width: tokens.sp2),
        FilledButton(
          onPressed: confirmLoading
              ? null
              : () async {
                  await onConfirm?.call();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? tokens.danger : tokens.brandPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sp5,
              vertical: tokens.sp3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.rButton),
            ),
            elevation: tokens.elevation2,
          ),
          child: confirmLoading
              ? SizedBox(
                  width: tokens.sp4,
                  height: tokens.sp4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  confirmActionText ?? confirmText,
                  style: tokens.labelLarge.copyWith(color: Colors.white),
                ),
        ),
      ],
    );
  }

  _ConfirmConfig _getConfig(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    switch (type) {
      case AppConfirmType.success:
        return _ConfirmConfig(
          bgColor: tokens.success.withValues(alpha: 0.15),
          iconColor: tokens.success,
          icon: Icons.check_circle_rounded,
        );
      case AppConfirmType.warning:
        return _ConfirmConfig(
          bgColor: tokens.warning.withValues(alpha: 0.15),
          iconColor: tokens.warning,
          icon: Icons.warning_amber_rounded,
        );
      case AppConfirmType.danger:
      case AppConfirmType.error:
        return _ConfirmConfig(
          bgColor: tokens.danger.withValues(alpha: 0.15),
          iconColor: tokens.danger,
          icon: Icons.delete_forever_rounded,
        );
      case AppConfirmType.info:
        return _ConfirmConfig(
          bgColor: tokens.info.withValues(alpha: 0.15),
          iconColor: tokens.info,
          icon: Icons.info_rounded,
        );
      case AppConfirmType.question:
        return _ConfirmConfig(
          bgColor: tokens.brandPrimary.withValues(alpha: 0.15),
          iconColor: tokens.brandPrimary,
          icon: Icons.help_outline_rounded,
        );
      case AppConfirmType.custom:
        return _ConfirmConfig(
          bgColor: tokens.brandPrimary.withValues(alpha: 0.15),
          iconColor: tokens.brandPrimary,
          icon: icon ?? Icons.help_outline_rounded,
        );
    }
  }
}

enum AppConfirmType {
  success,
  warning,
  danger,
  error,
  info,
  question,
  custom,
}

class _ConfirmConfig {
  const _ConfirmConfig({
    required this.bgColor,
    required this.iconColor,
    required this.icon,
  });

  final Color bgColor;
  final Color iconColor;
  final IconData icon;
}

/// Dialogue d'erreur standardisé
class AppErrorDialog extends StatelessWidget {
  const AppErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.onDismiss,
    this.retryText = 'Réessayer',
    this.dismissText = 'Fermer',
  });

  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final String retryText;
  final String dismissText;

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    String? details,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppErrorDialog(
        title: title,
        message: message,
        details: details,
        onRetry: onRetry,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    return AlertDialog(
      backgroundColor: isDark ? tokens.bgSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.rDialog),
      ),
      titlePadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        tokens.sp5,
        tokens.sp6,
        tokens.sp2,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        0,
        tokens.sp6,
        tokens.sp3,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        tokens.sp4,
        0,
        tokens.sp4,
        tokens.sp4,
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.sp2),
            decoration: BoxDecoration(
              color: tokens.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.rMd),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: tokens.danger,
              size: tokens.fontSizeXl,
            ),
          ),
          SizedBox(width: tokens.sp3),
          Expanded(
            child: Text(
              title,
              style: tokens.headlineSmall.copyWith(
                color: isDark ? tokens.textPrimary : tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: tokens.bodyMedium.copyWith(
              color: isDark ? tokens.textSecondary : tokens.textSecondary,
              height: 1.5,
            ),
          ),
          if (details != null) ...[
            SizedBox(height: tokens.sp3),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(tokens.sp3),
              decoration: BoxDecoration(
                color: isDark ? tokens.bgSidebar : Colors.grey[100],
                borderRadius: BorderRadius.circular(tokens.rMd),
                border: Border.all(
                  color: isDark ? tokens.borderDark : tokens.borderLight,
                ),
              ),
              child: SelectableText(
                details!,
                style: tokens.bodySmall.copyWith(
                  color: isDark ? tokens.textTertiary : tokens.textDisabled,
                  fontFamily: 'Roboto Mono',
                  fontSize: tokens.fontSizeXs,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onRetry != null)
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.brandPrimary,
              side: BorderSide(color: tokens.brandPrimary),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.sp5,
                vertical: tokens.sp3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.rButton),
              ),
            ),
            child: Text(retryText, style: tokens.labelLarge),
          ),
        if (onRetry != null) SizedBox(width: tokens.sp2),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: tokens.brandPrimary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sp5,
              vertical: tokens.sp3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.rButton),
            ),
          ),
          child: Text(dismissText, style: tokens.labelLarge.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// Dialogue de succès standardisé
class AppSuccessDialog extends StatelessWidget {
  const AppSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.onDismiss,
    this.dismissText = 'OK',
    this.autoDismissDuration,
  });

  final String title;
  final String message;
  final VoidCallback? onDismiss;
  final String dismissText;
  final Duration? autoDismissDuration;

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
    Duration? autoDismissDuration,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AppSuccessDialog(
        title: title,
        message: message,
        onDismiss: onDismiss,
        autoDismissDuration: autoDismissDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = context.isDark;

    if (autoDismissDuration != null) {
      Future.delayed(autoDismissDuration!, () {
        if (context.mounted) {
          Navigator.of(context).pop();
          onDismiss?.call();
        }
      });
    }

    return AlertDialog(
      backgroundColor: isDark ? tokens.bgSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.rDialog),
      ),
      titlePadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        tokens.sp5,
        tokens.sp6,
        tokens.sp2,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        tokens.sp6,
        0,
        tokens.sp6,
        tokens.sp3,
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        tokens.sp4,
        0,
        tokens.sp4,
        tokens.sp4,
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.sp2),
            decoration: BoxDecoration(
              color: tokens.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.rMd),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: tokens.success,
              size: tokens.fontSizeXl,
            ),
          ),
          SizedBox(width: tokens.sp3),
          Expanded(
            child: Text(
              title,
              style: tokens.headlineSmall.copyWith(
                color: isDark ? tokens.textPrimary : tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: tokens.bodyMedium.copyWith(
          color: isDark ? tokens.textSecondary : tokens.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: tokens.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.sp6,
              vertical: tokens.sp3,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.rButton),
            ),
          ),
          child: Text(dismissText, style: tokens.labelLarge.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}