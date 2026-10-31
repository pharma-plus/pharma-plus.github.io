/// ============================================================
/// PERMISSIONS — Matrice complète rôles/permissions PHARMA+
/// ============================================================

/// Actions possibles sur chaque module
enum PermissionAction {
  view,
  create,
  edit,
  delete,
  export,
  print,
  validate,
  approve,
  reject,
  assign,
  import,
  manage,
  configure,
  audit,
  adjust,
  writeOff,
  pay,
  receive,
  credit,
  schedule,
  sync,
  train,
  send,
  automate,
  billing,
  reconcile,
  count,
  dispense,
  cancel,
  record,
  playback,
  lock,
  restore,
}

/// Modules du système
enum Module {
  dashboard,
  pos,
  catalog,
  stock,
  suppliers,
  purchases,
  customers,
  employees,
  reports,
  settings,
  reference,
  reorder,
  ai,
  whatsapp,
  superadmin,
  accounting,
  inventory,
  prescriptions,
  invoices,
  cameras,
  floorplan,
  attendance,
  analytics,
  notifications,
  security,
  backup,
}

/// Rôles prédéfinis
enum Role {
  superAdmin,
  admin,
  pharmacist,
  cashier,
  stockManager,
  purchaser,
  salesRep,
  hrManager,
  accountant,
  viewer,
  // Rôles personnalisés
  custom,
}

/// Matrice des permissions par défaut (non-const pour permettre la construction dynamique)
Map<Role, Map<Module, Set<PermissionAction>>> get defaultRolePermissions => {
  Role.superAdmin: {
    for (final m in Module.values) m: PermissionAction.values.toSet(),
  },
  Role.admin: {
    Module.dashboard: {PermissionAction.view},
    Module.pos: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.catalog: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage},
    Module.stock: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage},
    Module.suppliers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage},
    Module.purchases: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve, PermissionAction.reject},
    Module.customers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.employees: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.reports: {PermissionAction.view, PermissionAction.export, PermissionAction.print},
    Module.settings: {PermissionAction.view, PermissionAction.edit, PermissionAction.configure},
    Module.reference: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.reorder: {PermissionAction.view, PermissionAction.create, PermissionAction.approve},
    Module.ai: {PermissionAction.view, PermissionAction.configure},
    Module.whatsapp: {PermissionAction.view, PermissionAction.create, PermissionAction.manage},
    Module.accounting: {PermissionAction.view, PermissionAction.export},
    Module.inventory: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.prescriptions: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.invoices: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.export},
    Module.cameras: {PermissionAction.view, PermissionAction.configure},
    Module.floorplan: {PermissionAction.view, PermissionAction.edit},
    Module.attendance: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve},
    Module.analytics: {PermissionAction.view, PermissionAction.export},
    Module.notifications: {PermissionAction.view, PermissionAction.create, PermissionAction.manage},
    Module.security: {PermissionAction.view, PermissionAction.audit},
    Module.backup: {PermissionAction.view, PermissionAction.manage},
  },
  Role.pharmacist: {
    Module.dashboard: {PermissionAction.view},
    Module.pos: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.catalog: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.stock: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.customers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.prescriptions: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.inventory: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.reorder: {PermissionAction.view, PermissionAction.create},
    Module.ai: {PermissionAction.view},
    Module.whatsapp: {PermissionAction.view, PermissionAction.create},
  },
  Role.cashier: {
    Module.dashboard: {PermissionAction.view},
    Module.pos: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.catalog: {PermissionAction.view},
    Module.customers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.whatsapp: {PermissionAction.view, PermissionAction.create},
  },
  Role.stockManager: {
    Module.dashboard: {PermissionAction.view},
    Module.catalog: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.stock: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage},
    Module.suppliers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.purchases: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve},
    Module.reorder: {PermissionAction.view, PermissionAction.create, PermissionAction.approve},
    Module.inventory: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.reports: {PermissionAction.view, PermissionAction.export},
    Module.ai: {PermissionAction.view},
  },
  Role.purchaser: {
    Module.dashboard: {PermissionAction.view},
    Module.suppliers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.purchases: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve},
    Module.reorder: {PermissionAction.view, PermissionAction.create, PermissionAction.approve},
    Module.reports: {PermissionAction.view, PermissionAction.export},
  },
  Role.salesRep: {
    Module.dashboard: {PermissionAction.view},
    Module.pos: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate},
    Module.catalog: {PermissionAction.view},
    Module.customers: {PermissionAction.view, PermissionAction.create, PermissionAction.edit},
    Module.reports: {PermissionAction.view, PermissionAction.export},
    Module.ai: {PermissionAction.view},
    Module.whatsapp: {PermissionAction.view, PermissionAction.create},
  },
  Role.hrManager: {
    Module.dashboard: {PermissionAction.view},
    Module.employees: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.manage},
    Module.attendance: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve},
    Module.reports: {PermissionAction.view, PermissionAction.export},
    Module.settings: {PermissionAction.view},
  },
  Role.accountant: {
    Module.dashboard: {PermissionAction.view},
    Module.reports: {PermissionAction.view, PermissionAction.export, PermissionAction.print},
    Module.accounting: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.export},
    Module.invoices: {PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.export},
    Module.settings: {PermissionAction.view},
  },
  Role.viewer: {
    for (final m in Module.values) m: {PermissionAction.view},
  },
};

/// Vérification de permission
class PermissionChecker {
  static bool hasPermission(Role role, Module module, PermissionAction action) {
    final perms = defaultRolePermissions[role];
    if (perms == null) return false;
    final actions = perms[module];
    return actions?.contains(action) ?? false;
  }

  static Set<PermissionAction> getPermissions(Role role, Module module) {
    return defaultRolePermissions[role]?[module] ?? {};
  }

  static List<Module> getAccessibleModules(Role role) {
    return defaultRolePermissions[role]?.keys.toList() ?? [];
  }
}

/// Matrice modules/actions pour l'UI
final Map<Module, List<PermissionAction>> moduleActions = {
  Module.dashboard: [PermissionAction.view],
  Module.pos: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.delete],
  Module.catalog: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.import, PermissionAction.export],
  Module.stock: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.adjust, PermissionAction.writeOff],
  Module.suppliers: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.pay],
  Module.purchases: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve, PermissionAction.reject, PermissionAction.receive],
  Module.customers: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.credit],
  Module.employees: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.assign],
  Module.reports: [PermissionAction.view, PermissionAction.export, PermissionAction.print, PermissionAction.schedule],
  Module.settings: [PermissionAction.view, PermissionAction.edit, PermissionAction.configure, PermissionAction.audit],
  Module.reference: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.sync],
  Module.reorder: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve, PermissionAction.delete],
  Module.ai: [PermissionAction.view, PermissionAction.configure, PermissionAction.train],
  Module.whatsapp: [PermissionAction.view, PermissionAction.create, PermissionAction.send, PermissionAction.manage, PermissionAction.automate],
  Module.superadmin: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.configure, PermissionAction.audit, PermissionAction.billing],
  Module.accounting: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.export, PermissionAction.reconcile],
  Module.inventory: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.delete, PermissionAction.manage, PermissionAction.adjust, PermissionAction.count],
  Module.prescriptions: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.dispense, PermissionAction.cancel],
  Module.invoices: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.validate, PermissionAction.export, PermissionAction.send, PermissionAction.cancel],
  Module.cameras: [PermissionAction.view, PermissionAction.configure, PermissionAction.record, PermissionAction.playback],
  Module.floorplan: [PermissionAction.view, PermissionAction.edit, PermissionAction.configure],
  Module.attendance: [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.approve, PermissionAction.reject],
  Module.analytics: [PermissionAction.view, PermissionAction.export, PermissionAction.schedule, PermissionAction.configure],
  Module.notifications: [PermissionAction.view, PermissionAction.create, PermissionAction.send, PermissionAction.manage],
  Module.security: [PermissionAction.view, PermissionAction.audit, PermissionAction.configure, PermissionAction.lock],
  Module.backup: [PermissionAction.view, PermissionAction.create, PermissionAction.restore, PermissionAction.schedule, PermissionAction.manage],
};

/// Extension pour vérification facile
extension PermissionExt on Role {
  bool can(Module module, PermissionAction action) => PermissionChecker.hasPermission(this, module, action);
  Set<PermissionAction> permissionsFor(Module module) => PermissionChecker.getPermissions(this, module);
  List<Module> get accessibleModules => PermissionChecker.getAccessibleModules(this);
}