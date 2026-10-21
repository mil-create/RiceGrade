import 'package:flutter/material.dart';

/// Asks for a batch label. Returns null if cancelled.
Future<String?> showSaveLabelDialog(BuildContext context, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SaveLabelDialog(initial: initial),
  );
}

class _SaveLabelDialog extends StatefulWidget {
  const _SaveLabelDialog({this.initial});

  final String? initial;

  @override
  State<_SaveLabelDialog> createState() => _SaveLabelDialogState();
}

class _SaveLabelDialogState extends State<_SaveLabelDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Save result'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: textTheme.titleLarge,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Label',
          hintText: 'e.g. Supplier A, sack 3',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
