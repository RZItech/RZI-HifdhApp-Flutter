import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:yaml/yaml.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/data/models/book_model.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';
import 'package:rzi_hifdhapp/features/book/data/models/draft_book.dart';

class CreatorChapter {
  String name;
  String arabic;
  String translation;
  String? audioPath;

  CreatorChapter({
    this.name = '',
    this.arabic = '',
    this.translation = '',
    this.audioPath,
  });
}

class BookCreatorPage extends StatefulWidget {
  final DraftBook? draft;
  const BookCreatorPage({super.key, this.draft});

  @override
  State<BookCreatorPage> createState() => _BookCreatorPageState();
}

class _BookCreatorPageState extends State<BookCreatorPage> {
  late String _draftId;
  final TextEditingController _nameController = TextEditingController();
  final List<CreatorChapter> _chapters = [];

  @override
  void initState() {
    super.initState();
    if (widget.draft != null) {
      _draftId = widget.draft!.id;
      _nameController.text = widget.draft!.name;
      _chapters.addAll(
        widget.draft!.chapters.map(
          (c) => CreatorChapter(
            name: c.name,
            arabic: c.arabic,
            translation: c.translation,
            audioPath: c.audioPath,
          ),
        ),
      );
    } else {
      _draftId = DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  Future<void> _saveToDraft() async {
    final draft = DraftBook(
      id: _draftId,
      name: _nameController.text.trim(),
      chapters: _chapters
          .map(
            (c) => DraftChapter(
              name: c.name,
              arabic: c.arabic,
              translation: c.translation,
              audioPath: c.audioPath,
            ),
          )
          .toList(),
      lastModified: DateTime.now(),
    );
    await DraftService.saveDraft(draft);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addChapter() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChapterEditorPage()),
    );

    if (result is CreatorChapter) {
      setState(() {
        _chapters.add(result);
      });
    }
  }

  void _editChapter(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterEditorPage(initialChapter: _chapters[index]),
      ),
    );

    if (result is CreatorChapter) {
      setState(() {
        _chapters[index] = result;
      });
    }
  }

  void _removeChapter(int index) {
    setState(() {
      _chapters.removeAt(index);
    });
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Import from Library'),
              onTap: () {
                Navigator.pop(context);
                _importFromLibrary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Import from ZIP File'),
              onTap: () {
                Navigator.pop(context);
                _importFromFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromLibrary() async {
    final bookState = context.read<BookBloc>().state;
    if (bookState is! BookLoaded || bookState.books.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No books in library')));
      return;
    }

    final selectedBook = await showDialog<Book>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Book'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: bookState.books.length,
            itemBuilder: (context, index) {
              final book = bookState.books[index];
              return ListTile(
                title: Text(book.name),
                subtitle: Text('${book.chapters.length} chapters'),
                onTap: () => Navigator.pop(context, book),
              );
            },
          ),
        ),
      ),
    );

    if (selectedBook != null) {
      _loadBookIntoCreator(selectedBook);
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(
        '${tempDir.path}/import_${DateTime.now().millisecondsSinceEpoch}',
      );
      await extractDir.create();

      // Extract ZIP
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, extractDir.path);

      // Read data.yml
      final dataFile = File('${extractDir.path}/data.yml');
      if (!await dataFile.exists()) {
        throw Exception('Invalid book file: data.yml not found');
      }

      final yamlString = await dataFile.readAsString();
      final yamlMap = loadYaml(yamlString) as Map;
      final bookName = result.files.single.name.replaceAll('.zip', '');
      final book = BookModel.fromYaml(yamlMap, bookName);

      _loadBookIntoCreator(book, extractDir.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  void _loadBookIntoCreator(Book book, [String? audioBasePath]) {
    setState(() {
      _nameController.text = book.name;
      _chapters.clear();

      for (final chapter in book.chapters) {
        String? audioPath;
        if (chapter.audioPath.isNotEmpty && chapter.audioPath != 'null') {
          if (audioBasePath != null) {
            // From ZIP import - use extracted path
            audioPath = '$audioBasePath/${chapter.audioPath}';
          } else {
            // From library - use existing path
            audioPath = chapter.audioPath;
          }
        }

        _chapters.add(
          CreatorChapter(
            name: chapter.name,
            arabic: chapter.arabicText,
            translation: chapter.englishText,
            audioPath: audioPath,
          ),
        );
      }
    });
  }

  Future<void> _exportBook() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a book name')));
      return;
    }

    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one chapter')),
      );
      return;
    }

    try {
      // 1. Generate YAML Content
      final buffer = StringBuffer();
      buffer.writeln('name: "${_nameController.text.trim()}"');

      final archive = Archive();

      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        final chapterKey = 'chapter_${i + 1}';

        buffer.writeln('$chapterKey:');
        buffer.writeln('  name: "${chapter.name}"');

        // Handle multiline strings safely for YAML
        buffer.writeln('  arabic: |');
        for (var line in chapter.arabic.split('\n')) {
          if (line.trim().isNotEmpty) buffer.writeln('    $line');
        }

        buffer.writeln('  translation: |');
        for (var line in chapter.translation.split('\n')) {
          if (line.trim().isNotEmpty) buffer.writeln('    $line');
        }

        if (chapter.audioPath != null) {
          final audioFile = File(chapter.audioPath!);
          if (await audioFile.exists()) {
            final fileName = 'audio_${i + 1}.mp3';
            buffer.writeln('  audio: "$fileName"');

            // Add Audio to Archive
            final audioBytes = await audioFile.readAsBytes();
            archive.addFile(
              ArchiveFile(fileName, audioBytes.length, audioBytes),
            );
          } else {
            buffer.writeln('  audio: null');
          }
        } else {
          buffer.writeln('  audio: null');
        }
      }

      // 2. Add data.yml to archive
      List<int> utf8Bytes = utf8.encode(buffer.toString());

      archive.addFile(ArchiveFile('data.yml', utf8Bytes.length, utf8Bytes));

      // 3. Create Zip
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      // 4. Save to Temp
      final tempDir = await getTemporaryDirectory();
      // User said "export books with the correct format". The import logic looks for .zip
      final fileName =
          '${_nameController.text.trim().replaceAll(" ", "_")}.zip';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(zipBytes);

      // 5. Share
      // ignoring deprecation as SharePlus.shareXFiles is not static and instance API is unclear without docs.
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Install this book in HifdhApp');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _saveToDraft();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Book'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_open),
              onPressed: _showImportOptions,
              tooltip: 'Import',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _exportBook,
              tooltip: 'Export',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Book Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _chapters[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          chapter.name.isNotEmpty
                              ? chapter.name
                              : 'Untitled Chapter',
                        ),
                        subtitle: Text('${chapter.arabic.length} chars'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editChapter(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _removeChapter(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addChapter,
                icon: const Icon(Icons.add),
                label: const Text('Add Chapter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChapterEditorPage extends StatefulWidget {
  final CreatorChapter? initialChapter;

  const ChapterEditorPage({super.key, this.initialChapter});

  @override
  State<ChapterEditorPage> createState() => _ChapterEditorPageState();
}

class _ChapterEditorPageState extends State<ChapterEditorPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _arabicCtrl;
  late TextEditingController _translationCtrl;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialChapter?.name ?? '');
    _arabicCtrl = TextEditingController(
      text: widget.initialChapter?.arabic ?? '',
    );
    _translationCtrl = TextEditingController(
      text: widget.initialChapter?.translation ?? '',
    );
    _audioPath = widget.initialChapter?.audioPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _arabicCtrl.dispose();
    _translationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _audioPath = result.files.single.path;
      });
    }
  }

  void _save() {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }

    Navigator.pop(
      context,
      CreatorChapter(
        name: _nameCtrl.text.trim(),
        arabic: _arabicCtrl.text.trim(),
        translation: _translationCtrl.text.trim(),
        audioPath: _audioPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialChapter == null ? 'New Chapter' : 'Edit Chapter',
        ),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Chapter Name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _arabicCtrl,
            decoration: const InputDecoration(
              labelText: 'Arabic Text',
              alignLabelWithHint: true,
            ),
            maxLines: 8,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _translationCtrl,
            decoration: const InputDecoration(
              labelText: 'English Translation',
              alignLabelWithHint: true,
            ),
            maxLines: 8,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Audio File (Optional)'),
            subtitle: Text(
              _audioPath != null
                  ? _audioPath!.split('/').last
                  : 'None selected',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.audio_file),
              onPressed: _pickAudio,
            ),
          ),
          if (_audioPath != null)
            TextButton(
              onPressed: () => setState(() => _audioPath = null),
              child: const Text('Remove Audio'),
            ),
        ],
      ),
    );
  }
}
