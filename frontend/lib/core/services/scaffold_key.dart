// Global scaffold key for HomeShell, accessible from DashboardPage to open the drawer.
import 'package:flutter/material.dart';

/// Service to manage the global scaffold key for HomeShell.
class ScaffoldKeyService {
  static GlobalKey<ScaffoldState>? _scaffoldKey;

  static void setScaffoldKey(GlobalKey<ScaffoldState> key) {
    _scaffoldKey = key;
  }

  static GlobalKey<ScaffoldState>? get scaffoldKey => _scaffoldKey;

  static void clear() {
    _scaffoldKey = null;
  }
}