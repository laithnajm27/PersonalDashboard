import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/calendar.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/project.dart';
import '../models/shotlist.dart';
import '../models/workspace.dart';

class SupabaseService {
  SupabaseService(this._client);

  factory SupabaseService.fromInitialized() {
    return SupabaseService(Supabase.instance.client);
  }

  static const customersTable = 'customers';
  static const projectsTable = 'projects';
  static const calendarTable = 'calendar_entries';

  final SupabaseClient _client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    );
  }

  Future<List<Customer>> getCustomers() async {
    final rows = await _client.from(customersTable).select().order('name');
    return rows.map((row) => Customer.fromJson(row)).toList();
  }

  Future<Customer> createCustomer(Customer customer) async {
    final row = await _client
        .from(customersTable)
        .insert(customer.toJson(includeId: false))
        .select()
        .single();
    return Customer.fromJson(row);
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final id = _requireId(customer.id, 'customer.id');
    final row = await _client
        .from(customersTable)
        .update(customer.toJson(includeId: false))
        .eq('id', id)
        .select()
        .single();
    return Customer.fromJson(row);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from(customersTable).delete().eq('id', id);
  }

  Future<List<Project>> getProjects() async {
    final rows = await _client
        .from(projectsTable)
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => Project.fromJson(row)).toList();
  }

  Future<CreatorProfile> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Für das Profil ist eine Anmeldung erforderlich.');
    }
    final row =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row != null) {
      return CreatorProfile.fromJson(row);
    }
    final userName = user.userMetadata?['full_name'] as String? ?? '';
    final created = await _client
        .from('profiles')
        .insert({'id': user.id, 'full_name': userName})
        .select()
        .single();
    return CreatorProfile.fromJson(created);
  }

  Future<CreatorProfile> saveProfile(CreatorProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null || profile.id != user.id) {
      throw StateError('Du darfst nur dein eigenes Profil ändern.');
    }
    final row = await _client
        .from('profiles')
        .upsert(profile.toJson())
        .select()
        .single();
    return CreatorProfile.fromJson(row);
  }

  Future<List<EquipmentItem>> getEquipment() async {
    final rows = await _client.from('equipment').select().order('name');
    return rows.map((row) => EquipmentItem.fromJson(row)).toList();
  }

  Future<EquipmentItem> createEquipment(EquipmentItem item) async {
    final row = await _client
        .from('equipment')
        .insert(item.toJson(includeId: false))
        .select()
        .single();
    return EquipmentItem.fromJson(row);
  }

  Future<EquipmentItem> updateEquipment(EquipmentItem item) async {
    final id = _requireId(item.id, 'equipment.id');
    final row = await _client
        .from('equipment')
        .update(item.toJson(includeId: false))
        .eq('id', id)
        .select()
        .single();
    return EquipmentItem.fromJson(row);
  }

  Future<void> deleteEquipment(String id) async {
    await _client.from('equipment').delete().eq('id', id);
  }

  Future<List<DashboardTask>> getTasks({String? projectId}) async {
    final query = _client.from('tasks').select();
    final rows = projectId == null
        ? await query.order('due_at', nullsFirst: false)
        : await query
            .eq('project_id', projectId)
            .order('due_at', nullsFirst: false);
    return rows.map((row) => DashboardTask.fromJson(row)).toList();
  }

  Future<DashboardTask> saveTask(DashboardTask task) async {
    final values = task.toJson(includeId: false);
    final query = task.id == null
        ? _client.from('tasks').insert(values)
        : _client
            .from('tasks')
            .update(values)
            .eq('id', _requireId(task.id, 'task.id'));
    final row = await query.select().single();
    return DashboardTask.fromJson(row);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  Future<List<CreatorGoal>> getGoals() async {
    final rows = await _client
        .from('goals')
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => CreatorGoal.fromJson(row)).toList();
  }

  Future<CreatorGoal> saveGoal(CreatorGoal goal) async {
    final values = goal.toJson(includeId: false);
    final query = goal.id == null
        ? _client.from('goals').insert(values)
        : _client
            .from('goals')
            .update(values)
            .eq('id', _requireId(goal.id, 'goal.id'));
    final row = await query.select().single();
    return CreatorGoal.fromJson(row);
  }

  Future<void> deleteGoal(String id) async {
    await _client.from('goals').delete().eq('id', id);
  }

  Future<List<InvoiceDocument>> getInvoiceDocuments() async {
    final rows = await _client
        .from('invoice_documents')
        .select()
        .eq('is_finalized', true)
        .order('finalized_at', ascending: false);
    return rows.map((row) => InvoiceDocument.fromJson(row)).toList();
  }

  Future<Map<String, dynamic>> reserveInvoiceDocument({
    required int year,
    required InvoiceDocumentType type,
    required double total,
    required Map<String, dynamic> snapshot,
  }) async {
    final response = await _client.rpc(
      'reserve_invoice_document',
      params: {
        'p_year': year,
        'p_document_type': type.name,
        'p_total': total,
        'p_snapshot': snapshot,
      },
    );
    if (response is! List || response.isEmpty) {
      throw const FormatException('Belegnummer konnte nicht erstellt werden.');
    }
    return response.first as Map<String, dynamic>;
  }

  Future<void> completeInvoiceDocument({
    required String id,
    required String storagePath,
    required String sha256,
  }) async {
    await _client.rpc(
      'complete_invoice_document',
      params: {
        'p_id': id,
        'p_storage_path': storagePath,
        'p_sha256': sha256,
      },
    );
  }

  Future<InvoiceDocument> getInvoiceDocument(String id) async {
    final row =
        await _client.from('invoice_documents').select().eq('id', id).single();
    return InvoiceDocument.fromJson(row);
  }

  Future<Project> createProject(Project project) async {
    final row = await _client
        .from(projectsTable)
        .insert(project.toJson(includeId: false))
        .select()
        .single();
    return Project.fromJson(row);
  }

  Future<Project> updateProject(Project project) async {
    final id = _requireId(project.id, 'project.id');
    final row = await _client
        .from(projectsTable)
        .update(project.toJson(includeId: false))
        .eq('id', id)
        .select()
        .single();
    return Project.fromJson(row);
  }

  Future<void> deleteProject(String id) async {
    await _client.from(projectsTable).delete().eq('id', id);
  }

  Future<List<ProjectLink>> getProjectLinks(String projectId) async {
    final rows = await _client
        .from('project_links')
        .select()
        .eq('project_id', projectId)
        .order('created_at');
    return rows.map((row) => ProjectLink.fromJson(row)).toList();
  }

  Future<ProjectLink> saveProjectLink(ProjectLink link) async {
    final values = link.toJson(includeId: false);
    final query = link.id == null
        ? _client.from('project_links').insert(values)
        : _client
            .from('project_links')
            .update(values)
            .eq('id', _requireId(link.id, 'projectLink.id'));
    final row = await query.select().single();
    return ProjectLink.fromJson(row);
  }

  Future<void> deleteProjectLink(String id) async {
    await _client.from('project_links').delete().eq('id', id);
  }

  Future<List<Shotlist>> getManualShotlist(String projectId) async {
    final row = await _client
        .from(projectsTable)
        .select('shotlist_daten')
        .eq('id', projectId)
        .single();
    final entries = row['shotlist_daten'] as List<dynamic>? ?? const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(Shotlist.fromJson)
        .toList();
  }

  Future<Project> saveManualShotlist({
    required String projectId,
    required List<Shotlist> shotlist,
  }) async {
    final row = await _client
        .from(projectsTable)
        .update({
          'shotlist_daten': shotlist.map((item) => item.toJson()).toList(),
        })
        .eq('id', projectId)
        .select()
        .single();
    return Project.fromJson(row);
  }

  Future<List<CalendarEntry>> getCalendarEntries() async {
    final rows = await _client.from(calendarTable).select().order('date_time');
    return rows.map((row) => CalendarEntry.fromJson(row)).toList();
  }

  Future<CalendarEntry> createCalendarEntry(CalendarEntry entry) async {
    final row = await _client
        .from(calendarTable)
        .insert(entry.toJson(includeId: false))
        .select()
        .single();
    return CalendarEntry.fromJson(row);
  }

  Future<CalendarEntry> updateCalendarEntry(CalendarEntry entry) async {
    final id = _requireId(entry.id, 'calendarEntry.id');
    final row = await _client
        .from(calendarTable)
        .update(entry.toJson(includeId: false))
        .eq('id', id)
        .select()
        .single();
    return CalendarEntry.fromJson(row);
  }

  Future<void> deleteCalendarEntry(String id) async {
    await _client.from(calendarTable).delete().eq('id', id);
  }

  String _requireId(String? id, String field) {
    if (id == null || id.isEmpty) {
      throw ArgumentError.value(id, field, 'Must not be empty');
    }
    return id;
  }
}
