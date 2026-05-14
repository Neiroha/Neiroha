part of '../../screens/novel_reader_screen.dart';

class _NovelEditorBar extends StatelessWidget {
  final db.NovelProject project;
  final VoidCallback onBack;

  const _NovelEditorBar({required this.project, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to novels',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.menu_book_rounded,
            color: AppTheme.accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovelProjectHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _NovelProjectHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          const Text(
            'Novel Reader',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Novel'),
          ),
        ],
      ),
    );
  }
}

class _CreateNovelDialog extends StatefulWidget {
  final List<db.VoiceBank> banks;

  const _CreateNovelDialog({required this.banks});

  @override
  State<_CreateNovelDialog> createState() => _CreateNovelDialogState();
}

class _CreateNovelDialogState extends State<_CreateNovelDialog> {
  final _nameController = TextEditingController();
  late String _bankId;

  @override
  void initState() {
    super.initState();
    _bankId = widget.banks
        .firstWhere((bank) => bank.isActive, orElse: () => widget.banks.first)
        .id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Novel'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Project name'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bankId,
              decoration: const InputDecoration(labelText: 'Voice bank'),
              items: [
                for (final bank in widget.banks)
                  DropdownMenuItem(value: bank.id, child: Text(bank.name)),
              ],
              onChanged: (id) {
                if (id != null) setState(() => _bankId = id);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _CreateNovelResult(name: name, bankId: _bankId));
  }
}

class _CreateNovelResult {
  final String name;
  final String bankId;

  const _CreateNovelResult({required this.name, required this.bankId});
}
