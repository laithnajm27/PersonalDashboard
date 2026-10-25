import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/calendar.dart';
import '../models/customer.dart';
import '../models/project.dart';
import '../models/shotlist.dart';

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
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  Future<List<Customer>> getCustomers() async {
    final rows = await _client
        .from(customersTable)
        .select()
        .order('name');
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
    final rows = await _client
        .from(calendarTable)
        .select()
        .order('date_time');
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
