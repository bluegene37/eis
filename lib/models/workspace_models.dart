// Gene - Nov, 24, 2026: Workspace RBAC roles, memberships, and session state models for Supabase mode.

enum EisUserRole {
  admin('admin', 'Admin'),
  accountant('accountant', 'Accountant'),
  cashier('cashier', 'Cashier / POS'),
  auditor('auditor', 'Auditor'),
  securityOfficer('security_officer', 'Security Officer');

  final String apiValue;
  final String label;

  const EisUserRole(this.apiValue, this.label);

  static EisUserRole fromString(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final role in EisUserRole.values) {
      if (role.apiValue == normalized) return role;
    }
    return EisUserRole.auditor;
  }

  bool get canIssueInvoice =>
      this == admin || this == accountant || this == cashier;

  bool get canManageTaxpayers => this == admin || this == accountant;

  bool get canSyncConnectors => this == admin || this == accountant;

  bool get canManageRetryQueue => this == admin || this == accountant;

  bool get canIssueCreditMemo => this == admin || this == accountant;

  bool get canExportReports =>
      this == admin || this == accountant || this == auditor;

  bool get canRotateKeys => this == admin || this == securityOfficer;

  bool get canManageGateway => this == admin || this == securityOfficer;

  bool get canManageMembers => this == admin;
}

class WorkspaceMembershipModel {
  final String workspaceId;
  final String workspaceCode;
  final String workspaceName;
  final EisUserRole role;
  final String email;

  const WorkspaceMembershipModel({
    required this.workspaceId,
    required this.workspaceCode,
    required this.workspaceName,
    required this.role,
    required this.email,
  });

  factory WorkspaceMembershipModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceMembershipModel(
      workspaceId: json['workspaceId']?.toString() ?? '',
      workspaceCode: json['workspaceCode']?.toString() ?? '',
      workspaceName: json['workspaceName']?.toString() ?? '',
      role: EisUserRole.fromString(json['role']?.toString()),
      email: json['email']?.toString() ?? '',
    );
  }
}

class WorkspaceMemberRecord {
  final String id;
  final String userId;
  final String email;
  final EisUserRole role;
  final String createdAt;

  const WorkspaceMemberRecord({
    required this.id,
    required this.userId,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory WorkspaceMemberRecord.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberRecord(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: EisUserRole.fromString(json['role']?.toString()),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class EisAuthSessionState {
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final List<WorkspaceMembershipModel> workspaces;
  final WorkspaceMembershipModel? activeWorkspace;

  const EisAuthSessionState({
    required this.isAuthenticated,
    this.userId,
    this.email,
    this.workspaces = const [],
    this.activeWorkspace,
  });

  const EisAuthSessionState.unauthenticated()
      : isAuthenticated = false,
        userId = null,
        email = null,
        workspaces = const [],
        activeWorkspace = null;

  EisUserRole? get activeRole => activeWorkspace?.role;
}
