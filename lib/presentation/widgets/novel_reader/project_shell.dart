part of '../../screens/novel_reader_screen.dart';

class _NovelEditorBar extends StatelessWidget {
  final db.NovelProject project;
  final VoidCallback onBack;

  /// Read / role-review switch, shown in the bar instead of its own row.
  final Widget? modeSwitch;

  const _NovelEditorBar({
    required this.project,
    required this.onBack,
    this.modeSwitch,
  });

  @override
  Widget build(BuildContext context) => PageHeader(
    onBack: onBack,
    backTooltip: AppLocalizations.of(context).uiBackToNovels,
    icon: Icons.menu_book_rounded,
    title: project.name,
    center: modeSwitch,
  );
}

class _NovelProjectHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _NovelProjectHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PageHeader(
      icon: Icons.menu_book_rounded,
      title: l10n.navNovelReader,
      actions: [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.uiNewNovel),
        ),
      ],
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
      title: Text(AppLocalizations.of(context).uiNewNovel),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiProjectName,
              ),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bankId,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiVoiceBank,
              ),
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
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppLocalizations.of(context).uiCreate),
        ),
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
