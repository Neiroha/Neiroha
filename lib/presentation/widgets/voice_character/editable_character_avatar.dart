import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

class EditableCharacterAvatar extends StatelessWidget {
  const EditableCharacterAvatar({super.key, required this.avatar, this.onEdit});

  final Widget avatar;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    if (onEdit == null) return avatar;
    return GestureDetector(
      onTap: onEdit,
      child: Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBright,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surfaceDim, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
