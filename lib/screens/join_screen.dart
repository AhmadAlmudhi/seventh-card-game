import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../state/nickname_rules.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/ui.dart';
import 'home_screen.dart';

/// Join a room by its 5-character code (PRD §4.3). The code is always left-to-right Latin
/// capitals, in both languages (PRD §6.6).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _code = TextEditingController(text: RoomCodeRules.clean(widget.initialCode ?? ''));
  bool _showError = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() {
    final code = RoomCodeRules.clean(_code.text);
    if (!RoomCodeRules.isValid(code)) {
      setState(() => _showError = true);
      return;
    }
    context.go('/room/$code');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: FeltBackground(
        child: SafeArea(
          child: ContentWidth(
            child: Column(
              children: [
                SimpleTopBar(title: l10n.joinTitle),
                Expanded(
                  child: FillScroll(
                    children: [
                      const Spacer(),
                      Text(l10n.roomCodeLabel, style: AppText.heading),
                      const SizedBox(height: AppSpacing.xs),
                      Text(l10n.roomCodeHint, style: AppText.bodyMuted),
                      const SizedBox(height: AppSpacing.lg),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: AppTextField(
                          controller: _code,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          textCapitalization: TextCapitalization.characters,
                          keyboardType: TextInputType.visiblePassword,
                          maxLength: RoomCodeRules.length,
                          inputFormatters: [_RoomCodeFormatter()],
                          // Latin only, so letter spacing is safe here.
                          style: AppText.numeral(34, AppColors.onTable).copyWith(letterSpacing: 10, height: 1.2),
                          errorText: _showError ? l10n.roomCodeIncomplete : null,
                          onChanged: (_) {
                            if (_showError) setState(() => _showError = false);
                          },
                          onSubmitted: (_) => _join(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(label: l10n.joinButton, icon: Icons.login_rounded, onPressed: _join),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Upper-cases as the player types and drops characters that can't be in a code.
class _RoomCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = RoomCodeRules.clean(newValue.text);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}
