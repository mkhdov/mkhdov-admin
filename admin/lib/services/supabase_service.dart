import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const _supabaseUrl = 'https://jdafqzlhkmczluozwgfp.supabase.co';
  static const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkYWZxemxoa21jemx1b3p3Z2ZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1OTM2MDEsImV4cCI6MjA5NzE2OTYwMX0.uouhHjIPCbhxIpv0Y0ZUqqEZTHzbm1uodG7KUGYdfr8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────

  static Session? get currentSession => client.auth.currentSession;
  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentSession != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ── Database Helpers ──────────────────────────────────────────

  static SupabaseQueryBuilder from(String table) => client.from(table);

  static SupabaseStorageClient get storage => client.storage;

  static RealtimeChannel channel(String name) => client.channel(name);

  static Future<void> removeChannel(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
