import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/folder_model.dart';
import '../models/note_model.dart';

class LocalStorageService {
  static const _foldersKey = 'note_folders';
  static const _notesKey = 'notes';

  Future<({List<NoteFolder> folders, List<Note> notes, Map<String, List<String>> calendar})> load() async {
    final preferences = await SharedPreferences.getInstance();
    final foldersJson = preferences.getString(_foldersKey);
    final notesJson = preferences.getString(_notesKey);
    final calendarJson = preferences.getString('calendar_attachments');

    if (foldersJson == null || notesJson == null) {
      final seeded = _seedData();
      await save(seeded.folders, seeded.notes, seeded.calendar);
      return seeded;
    }

    final folders = (jsonDecode(foldersJson) as List)
        .map((item) => NoteFolder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final notes = (jsonDecode(notesJson) as List)
        .map((item) => Note.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final calendar = calendarJson == null
        ? <String, List<String>>{}
        : (jsonDecode(calendarJson) as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          );
    final migratedFolders = folders
        .where((folder) => folder.id != 'university')
        .toList();
    if (!migratedFolders.any((folder) => folder.id == 'calendar')) {
      migratedFolders.add(const NoteFolder(id: 'calendar', name: 'Календарь'));
    }
    final migratedNotes = notes
        .map((note) => note.folderId == 'university' ? note.copyWith(folderId: 'all') : note)
        .toList();
    return (folders: migratedFolders, notes: migratedNotes, calendar: calendar);
  }

  Future<void> save(
    List<NoteFolder> folders,
    List<Note> notes,
    Map<String, List<String>> calendar,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _foldersKey,
      jsonEncode(folders.map((folder) => folder.toJson()).toList()),
    );
    await preferences.setString(
      _notesKey,
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
    await preferences.setString('calendar_attachments', jsonEncode(calendar));
  }

  ({List<NoteFolder> folders, List<Note> notes, Map<String, List<String>> calendar}) _seedData() {
    final now = DateTime.now();
    const folders = [
      NoteFolder(id: 'all', name: 'Все заметки'),
      NoteFolder(id: 'projects', name: 'Проекты'),
    ];
    final notes = [
      Note(
        id: 'welcome',
        folderId: 'all',
        title: 'Добро пожаловать',
        content:
            '# Моя база знаний\n\nНачните писать конспект здесь. Создавайте папки для дисциплин, проектов и личных заметок.\n\n## Идея\n\nКаждая заметка сохраняется локально на этом устройстве.',
        updatedAt: now,
      ),
    ];
    return (folders: folders, notes: notes, calendar: {});
  }
}
