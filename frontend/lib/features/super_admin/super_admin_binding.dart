/// ============================================================
/// SUPER ADMIN — Binding for Tree-shaking Prevention
/// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_store.dart';
import '../super_admin/super_admin_functions.dart';

/// Mixin that forces tree-shaking retention by executing code at app startup
/// This binding is initialized in main() and its constructor runs immediately
mixin SuperAdminRetentionMixin {
  /// Force tree-shaking retention by accessing the singleton and its methods
  /// This runs during app initialization before runApp()
  static void ensureInitialized() {
    // Force tree-shaking retention by accessing the singleton and its methods
    // This runs during app initialization before runApp()
    final functions = SuperAdminFunctions.instance;
    
    // Access methods in a way the tree-shaker can't optimize away
    // by using them in a conditional that affects program state
    _forceRetention(functions);
  }

  /// Force retention by using functions in a way the tree-shaker can't optimize
  static void _forceRetention(SuperAdminFunctions functions) {
    // Use hashCode to force evaluation
    final hash1 = functions.hashCode;
    final hash2 = functions.returnToPharma.hashCode;
    final hash3 = functions.confirmLogout.hashCode;
    
    // Use in a conditional that could theoretically affect program behavior
    // The tree-shaker can't prove this is never true
    if (hash1 == 0 && hash2 == 0 && hash3 == 0) {
      // This branch is never taken but forces the values to be computed
      debugPrint('SuperAdmin retention check');
    }
  }
}

/// Initialize the SuperAdmin retention mixin
void initializeSuperAdminRetention() {
  SuperAdminRetentionMixin.ensureInitialized();
}