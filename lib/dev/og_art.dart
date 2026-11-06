// The link-preview image (1200 × 630) shown when a room link is shared (PRD §4.3). Screen
// gallery only: `#/?screen=og` draws it in the top-left corner, for exporting web/og-image.png.
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/ui.dart';

class OgArt extends StatelessWidget {
  const OgArt({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 1200,
      height: 630,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [AppColors.tableLight, AppColors.table], radius: 0.9),
        ),
        // Stacked and centred, so a square crop (some chat apps) still shows the card and the name.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoMark(scale: 1.75),
            const SizedBox(height: 18),
            Text('الورقة السابعة', style: AppText.display.copyWith(fontSize: 84, height: 1.1)),
            const SizedBox(height: 6),
            Text(
              'THE SEVENTH CARD',
              textDirection: TextDirection.ltr,
              style: AppText.latinTagline.copyWith(fontSize: 22, letterSpacing: 8),
            ),
            const SizedBox(height: 22),
            Text(
              'لعبة ورق جماعية للأصدقاء · A card game for friends',
              style: AppText.heading.copyWith(fontSize: 26, color: AppColors.gold),
            ),
          ],
        ),
      ),
    ),
  );
}
