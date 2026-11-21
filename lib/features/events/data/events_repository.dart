import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/event.dart';

class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Event>> fetchEvents() async {
    final data = await _client.from('events').select().order('start_time');
    return data.map<Event>((row) => Event.fromMap(row)).toList();
  }

  Future<void> addEvent(Event event) async {
    await _client.from('events').insert(event.toMap());
  }

  Future<void> updateEvent(Event event) async {
    await _client.from('events').update(event.toMap()).eq('id', event.id);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(supabaseClientProvider));
});

final eventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(eventsRepositoryProvider).fetchEvents();
});