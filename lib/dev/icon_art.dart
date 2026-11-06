// The app icon, drawn from the logo, for exporting the web and store icons. Screen gallery only:
// `#/?screen=icon` draws it at 512 × 512 in the top-left corner.
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/ui.dart';

class IconArt extends StatelessWidget {
  const IconArt({super.key, this.size = 512});

  final double size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox.square(
      dimension: size,
      // Full-bleed felt, with the cards inside the middle 80% so maskable icons never crop them.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [AppColors.tableLight, AppColors.table], radius: 0.85),
        ),
        child: Center(
          child: Transform.translate(
            offset: Offset(-size * 0.035, size * 0.012),
            child: LogoMark(scale: size / 182),
          ),
        ),
      ),
    ),
  );
}
