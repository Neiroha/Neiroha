import 'package:flutter/widgets.dart';

/// Two form fields side by side on wide panes, stacked on narrow ones.
class FormPair extends StatelessWidget {
  const FormPair({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 620,
  });
  final Widget first;
  final Widget second;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < breakpoint
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );
}
