import 'package:flutter/material.dart';

import '../models/folder_model.dart';
import '../models/note_model.dart';
import '../services/local_storage_service.dart';

enum _AppSection { notes, projects, calendar }

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final _storage = LocalStorageService();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  List<NoteFolder> _folders = [];
  List<Note> _notes = [];
  Map<String, List<String>> _calendarAttachments = {};
  String _selectedFolderId = 'all';
  String? _selectedNoteId;
  _AppSection _section = _AppSection.notes;
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  Note? get _selectedNote => _notes.where((note) => note.id == _selectedNoteId).firstOrNull;

  List<Note> get _visibleNotes {
    final query = _searchController.text.trim().toLowerCase();
    return _notes.where((note) {
      final inFolder = _selectedFolderId == 'all' || note.folderId == _selectedFolderId;
      final matches = query.isEmpty || note.title.toLowerCase().contains(query) || note.content.toLowerCase().contains(query);
      return inFolder && matches;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_refresh);
  }

  Future<void> _loadData() async {
    final data = await _storage.load();
    if (!mounted) return;
    setState(() {
      _folders = data.folders;
      _notes = data.notes;
      _calendarAttachments = data.calendar;
      _selectedNoteId = data.notes.firstOrNull?.id;
      _loading = false;
    });
    _syncEditor();
  }

  void _refresh() => setState(() {});

  void _selectNote(Note note) {
    _saveCurrentNote();
    setState(() => _selectedNoteId = note.id);
    _syncEditor();
  }

  void _syncEditor() {
    final note = _selectedNote;
    _titleController.text = note?.title ?? '';
    _contentController.text = note?.content ?? '';
  }

  Future<void> _saveCurrentNote() async {
    final note = _selectedNote;
    if (note == null) return;
    final updated = note.copyWith(
      title: _titleController.text.trim().isEmpty ? 'Без названия' : _titleController.text.trim(),
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index < 0) return;
    _notes[index] = updated;
    setState(() {});
    await _persist();
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    await _storage.save(_folders, _notes, _calendarAttachments);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _createNote() async {
    final projectFolder = _folders.where((folder) => folder.id != 'all' && folder.id != 'calendar').firstOrNull;
    final folderId = _selectedFolderId == 'all' ? (projectFolder?.id ?? 'all') : _selectedFolderId;
    final note = Note(id: DateTime.now().microsecondsSinceEpoch.toString(), folderId: folderId, title: 'Новая заметка', content: '', updatedAt: DateTime.now());
    setState(() {
      _notes.add(note);
      _selectedNoteId = note.id;
    });
    _syncEditor();
    await _persist();
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая папка'),
        content: TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'Например, Математика')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('Создать')),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _folders.add(NoteFolder(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name)));
    await _persist();
  }

  Future<void> _attachNoteToDay(Note note, DateTime day) async {
    final key = _dateKey(day);
    final attached = List<String>.from(_calendarAttachments[key] ?? []);
    if (attached.contains(note.id)) {
      attached.remove(note.id);
    } else {
      attached.add(note.id);
    }
    setState(() => _calendarAttachments[key] = attached);
    await _persist();
  }

  void _showNoteOnMainScreen(Note note) {
    setState(() {
      _section = _AppSection.notes;
      _selectedFolderId = 'all';
      _selectedNoteId = note.id;
    });
    _syncEditor();
  }

  String _dateKey(DateTime day) => '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> _deleteNote() async {
    final note = _selectedNote;
    if (note == null) return;
    setState(() {
      _notes.removeWhere((item) => item.id == note.id);
      _selectedNoteId = _visibleNotes.where((item) => item.id != note.id).firstOrNull?.id;
    });
    _syncEditor();
    await _persist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildWorkspace()),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: const Color(0xff292a32),
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('STUDY\nVAULT', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: .95, letterSpacing: 1.5)),
        const SizedBox(height: 34),
        _sidebarAction(Icons.folder_copy_outlined, 'Проекты', () => setState(() => _section = _AppSection.projects)),
        const SizedBox(height: 22),
        const Text('РАЗДЕЛЫ', style: TextStyle(color: Color(0xffaaa8b3), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Expanded(child: ListView(children: [
          _sectionTile(Icons.home_outlined, 'Все заметки', _AppSection.notes, _selectedFolderId == 'all'),
          _sectionTile(Icons.calendar_month_outlined, 'Календарь', _AppSection.calendar, _section == _AppSection.calendar),
        ])),
        const Divider(color: Color(0xff45464f)),
        _sidebarAction(Icons.settings_outlined, 'Настройки', () {}),
      ]),
    );
  }

  Widget _sectionTile(IconData icon, String label, _AppSection section, bool selected) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: const Color(0xff73577e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      leading: Icon(icon, color: selected ? Colors.white : const Color(0xffc2b8c7), size: 19),
      title: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xffd9d6dc), fontSize: 14)),
      onTap: () => setState(() {
        _section = section;
        if (section == _AppSection.notes) _selectedFolderId = 'all';
      }),
    );
  }

  Widget _sidebarAction(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(4), child: Padding(padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4), child: Row(children: [Icon(icon, size: 19, color: const Color(0xffd2c3d7)), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Color(0xffeeeaf0), fontSize: 14))])));
  }

  Widget _buildWorkspace() {
    if (_section == _AppSection.projects) return _buildProjectsPage();
    if (_section == _AppSection.calendar) return _buildCalendarPage();
    return Container(
      color: const Color(0xff735a7b),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 14), child: Row(children: [
          const Text('Мои конспекты', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          const Spacer(),
          SizedBox(width: 260, child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Поиск по заметкам', prefixIcon: const Icon(Icons.search, size: 19), filled: true, fillColor: Colors.white.withValues(alpha: .12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none), hintStyle: const TextStyle(color: Color(0xffddd3df)), contentPadding: EdgeInsets.zero), style: const TextStyle(color: Colors.white))),
          const SizedBox(width: 10),
          IconButton(onPressed: _createNote, tooltip: 'Новая заметка', icon: const Icon(Icons.add, color: Colors.white)),
        ])),
        Expanded(child: Container(color: const Color(0xfff6f3f7), child: Row(children: [
          SizedBox(width: 285, child: _buildNotesList()),
          Expanded(child: _buildEditor()),
        ]))),
      ]),
    );
  }

  Widget _buildProjectsPage() {
    final projectFolders = _folders.where((folder) => folder.id != 'all' && folder.id != 'calendar').toList();
    return Container(
      color: const Color(0xfff6f3f7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: const Color(0xff735a7b),
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
          child: Row(children: [
            const Text('Проекты', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const Spacer(),
            FilledButton.icon(
              onPressed: _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Создать новую папку'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff8d6a98), foregroundColor: Colors.white),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
          child: Text('${projectFolders.length} папок для ваших файлов', style: const TextStyle(fontSize: 16, color: Color(0xff625666))),
        ),
        Expanded(
          child: projectFolders.isEmpty
              ? const Center(child: Text('Создайте первую папку для проекта'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 132, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  itemCount: projectFolders.length,
                  itemBuilder: (context, index) {
                    final folder = projectFolders[index];
                    final noteCount = _notes.where((note) => note.folderId == folder.id).length;
                    return InkWell(
                      onTap: () => setState(() {
                        _section = _AppSection.notes;
                        _selectedFolderId = folder.id;
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe2dbe4))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.folder_outlined, color: Color(0xff735a7b), size: 30),
                          const Spacer(),
                          Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xff403544))),
                          const SizedBox(height: 4),
                          Text('$noteCount заметок', style: const TextStyle(fontSize: 12, color: Color(0xff948899))),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildCalendarPage() {
    final dayKey = _dateKey(_selectedDay);
    final attachedNotes = (_calendarAttachments[dayKey] ?? [])
        .map((id) => _notes.where((note) => note.id == id).firstOrNull)
        .whereType<Note>()
        .toList();
    return Container(
      color: const Color(0xfff6f3f7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: const Color(0xff735a7b),
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
          child: const Text('Календарь', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('План учебных материалов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xff403544))),
              const SizedBox(height: 6),
              const Text('Выберите день и прикрепите к нему готовые конспекты.', style: TextStyle(color: Color(0xff887b8b))),
              const SizedBox(height: 18),
              Container(
                constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe2dbe4))),
                child: CalendarDatePicker(
                  initialDate: _selectedDay,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  currentDate: DateTime.now(),
                  onDateChanged: (date) => setState(() => _selectedDay = date),
                ),
              ),
              const SizedBox(height: 26),
              Row(children: [
                Text('Конспекты на ${_dateLabel(_selectedDay)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xff403544))),
                const SizedBox(width: 10),
                Text('${attachedNotes.length}', style: const TextStyle(color: Color(0xff958697))),
              ]),
              const SizedBox(height: 12),
              if (attachedNotes.isEmpty)
                const Text('На этот день пока ничего не прикреплено.', style: TextStyle(color: Color(0xff887b8b)))
              else
                Wrap(spacing: 10, runSpacing: 10, children: attachedNotes.map((note) => InputChip(label: Text(note.title), onPressed: () => _showNoteOnMainScreen(note), onDeleted: () => _attachNoteToDay(note, _selectedDay))).toList()),
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: _showAttachDialog, icon: const Icon(Icons.attach_file), label: const Text('Прикрепить конспект')),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _showAttachDialog() async {
    final dayKey = _dateKey(_selectedDay);
    final selected = Set<String>.from(_calendarAttachments[dayKey] ?? []);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Конспекты на ${_dateLabel(_selectedDay)}'),
          content: SizedBox(
            width: 390,
            child: _notes.isEmpty
                ? const Text('Сначала создайте заметку на главном экране.')
                : ListView(
                    shrinkWrap: true,
                    children: _notes.map((note) {
                      return CheckboxListTile(
                        value: selected.contains(note.id),
                        title: Text(note.title),
                        subtitle: Text(_folderName(note.folderId)),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(note.id);
                            } else {
                              selected.remove(note.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _calendarAttachments[dayKey] = result.toList());
    await _persist();
  }

  String _folderName(String folderId) => _folders.where((folder) => folder.id == folderId).firstOrNull?.name ?? 'Все заметки';

  Widget _buildNotesList() {
    return Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xffe2dde3)))), child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Text('Заметки', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff403544))), const Spacer(), Text('${_visibleNotes.length}', style: const TextStyle(color: Color(0xff8f8192)))])),
      Expanded(child: _visibleNotes.isEmpty ? const Center(child: Text('Пока пусто')) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: _visibleNotes.length, itemBuilder: (context, index) {
        final note = _visibleNotes[index];
        final selected = note.id == _selectedNoteId;
        return InkWell(onTap: () => _selectNote(note), child: Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 5), decoration: BoxDecoration(color: selected ? const Color(0xffeadfec) : Colors.transparent, borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? const Color(0xff614c68) : const Color(0xff403544))), const SizedBox(height: 5), Text(note.content.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xff897e8c))), const SizedBox(height: 7), Text(_dateLabel(note.updatedAt), style: const TextStyle(fontSize: 10, color: Color(0xffa399a6)))])));
      })),
    ]));
  }

  Widget _buildEditor() {
    final note = _selectedNote;
    if (note == null) return const Center(child: Text('Создайте заметку, чтобы начать'));
    return Padding(padding: const EdgeInsets.fromLTRB(32, 24, 38, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: TextField(controller: _titleController, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: Color(0xff342b38)), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Название заметки'))), IconButton(onPressed: _deleteNote, tooltip: 'Удалить заметку', icon: const Icon(Icons.delete_outline, color: Color(0xff8d7d90))), FilledButton.icon(onPressed: _saveCurrentNote, icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined, size: 17), label: const Text('Сохранить'))]),
      const Divider(height: 1),
      const SizedBox(height: 14),
      Expanded(child: TextField(controller: _contentController, expands: true, maxLines: null, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xff403544)), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Начните писать конспект...'))),
    ]));
  }

  String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
