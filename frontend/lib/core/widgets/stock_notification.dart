import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Notification de stock partagée par le POS complet et le mini-POS.
/// Elle reste centrée dans la zone supérieure du contenu, sans être
/// attachée au bas du viewport comme un SnackBar classique.
class StockNotification {
  StockNotification._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String key,
    required String title,
    required String message,
  }) {
    dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);
    final icon = key == 'stock_impossible'
        ? Icons.warning_amber_rounded
        : key == 'stock_zero'
            ? Icons.remove_shopping_cart
            : Icons.error_outline;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final width = MediaQuery.sizeOf(overlayContext).width;
        final horizontal = width < 600 ? 16.0 : 0.0;
        return Positioned(
          top: MediaQuery.paddingOf(overlayContext).top + 16,
          left: horizontal,
          right: horizontal,
          child: IgnorePointer(
            ignoring: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width < 600 ? width - 32 : 360,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.goldBorderStrong),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.36),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child:
                              Icon(icon, color: AppColors.brandGold, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$title\n',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: message,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const IconButton(
                          tooltip: 'Fermer',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(Icons.close,
                              color: AppColors.brandGold, size: 17),
                          onPressed: dismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 5), dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}
