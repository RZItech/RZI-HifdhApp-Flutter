import 'package:flutter/material.dart';
import 'package:rzi_hifdhapp/features/book/data/models/draft_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/book_creator_page.dart';

class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  List<DraftBook> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    final drafts = await DraftService.getDrafts();
    setState(() {
      _drafts = drafts;
      _isLoading = false;
    });
  }

  void _createNewDraft() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookCreatorPage()),
    );
    _loadDrafts();
  }

  void _openDraft(DraftBook draft) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookCreatorPage(draft: draft)),
    );
    _loadDrafts();
  }

  Future<void> _deleteDraft(String id) async {
    await DraftService.deleteDraft(id);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Drafts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
          ? const Center(
              child: Text('No drafts yet. Press + to start creating.'),
            )
          : ListView.builder(
              itemCount: _drafts.length,
              itemBuilder: (context, index) {
                final draft = _drafts[index];
                return Dismissible(
                  key: Key(draft.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Draft'),
                        content: const Text(
                          'Are you sure you want to delete this draft?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) => _deleteDraft(draft.id),
                  child: ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: Text(
                      draft.name.isEmpty ? 'Untitled Book' : draft.name,
                    ),
                    subtitle: Text(
                      '${draft.chapters.length} chapters • Modified: ${_formatDate(draft.lastModified)}',
                    ),
                    onTap: () => _openDraft(draft),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewDraft,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
