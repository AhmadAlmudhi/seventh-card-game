// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الورقة السابعة';

  @override
  String get logoTagline => 'THE SEVENTH CARD';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get soundOn => 'الصوت مفعّل';

  @override
  String get soundOff => 'الصوت متوقف';

  @override
  String get nicknameLabel => 'الاسم';

  @override
  String get nicknameHint => 'اكتب اسمك';

  @override
  String get nicknameInvalid => 'استخدم من 1 إلى 16 حرفًا أو رقمًا أو مسافة.';

  @override
  String get createRoom => 'إنشاء غرفة';

  @override
  String get joinRoom => 'الانضمام لغرفة';

  @override
  String get howToPlay => 'كيفية اللعب';

  @override
  String get back => 'رجوع';

  @override
  String returnToRoom(String code) {
    return 'العودة إلى الغرفة $code';
  }

  @override
  String get joinTitle => 'الانضمام لغرفة';

  @override
  String get roomCodeLabel => 'رمز الغرفة';

  @override
  String get roomCodeHint => '5 أحرف وأرقام';

  @override
  String get joinButton => 'انضمام';

  @override
  String get joinNeedsName => 'اكتب اسمك أولًا.';

  @override
  String get roomCodeIncomplete => 'الرمز من 5 أحرف وأرقام.';

  @override
  String get connecting => 'جارٍ الانضمام إلى الغرفة…';

  @override
  String get reconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String nicknamePromptTitle(String code) {
    return 'الانضمام إلى الغرفة $code';
  }

  @override
  String get goHome => 'الرئيسية';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get errorRoomNotFound => 'هذه الغرفة غير موجودة. تأكد من الرمز.';

  @override
  String get errorRoomFull => 'هذه الغرفة ممتلئة (8 لاعبين).';

  @override
  String get errorGameStarted => 'بدأت هذه اللعبة بالفعل.';

  @override
  String get errorRoomBusy => 'انتهت لعبة للتو في هذه الغرفة. حاول مرة أخرى بعد قليل.';

  @override
  String get errorNicknameTaken => 'هناك من يستخدم هذا الاسم في الغرفة.';

  @override
  String get errorRemoved => 'أزالك المضيف من هذه الغرفة.';

  @override
  String get errorSeatLost => 'أُزلت من اللعبة بعد انقطاع الاتصال لفترة طويلة.';

  @override
  String get errorConnectionLost => 'تعذّرت إعادة الاتصال بالغرفة.';

  @override
  String get errorServersBusy => 'الخوادم مشغولة، حاول مرة أخرى لاحقًا.';

  @override
  String get errorNetwork => 'تعذّر الوصول إلى الخادم. تحقق من اتصالك.';

  @override
  String get errorGameAbandoned => 'انقطع اتصال الجميع لفترة طويلة، فانتهت اللعبة بلا نتيجة.';

  @override
  String get errorNotHost => 'هذا للمضيف فقط.';

  @override
  String get errorGeneric => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String get shareLink => 'مشاركة الرابط';

  @override
  String shareMessage(String link) {
    return 'انضم إلى لعبتي في الورقة السابعة: $link';
  }

  @override
  String playersTitle(int count) {
    return 'اللاعبون ($count/8)';
  }

  @override
  String get youTag => 'أنت';

  @override
  String get hostTag => 'المضيف';

  @override
  String get removePlayer => 'إزالة اللاعب';

  @override
  String removeConfirmTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get removeConfirmBody => 'لن يمكن الانضمام إلى هذه الغرفة مرة أخرى من الجهاز نفسه.';

  @override
  String get remove => 'إزالة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get settingsTitle => 'إعدادات اللعبة';

  @override
  String get modeLabel => 'الوضع';

  @override
  String get modeNormal => 'عادي';

  @override
  String get modeHard => 'صعب';

  @override
  String get targetLabel => 'نقاط الفوز';

  @override
  String forcedLineNote(int line) {
    return 'السحب إجباري من $line نقطة';
  }

  @override
  String get decreaseTarget => 'خفض نقاط الفوز';

  @override
  String get increaseTarget => 'رفع نقاط الفوز';

  @override
  String get startGame => 'ابدأ اللعبة';

  @override
  String get waitingForHost => 'بانتظار أن يبدأ المضيف…';

  @override
  String get needTwoPlayers => 'تحتاج إلى لاعبَين على الأقل للبدء.';

  @override
  String waitingFor(String names) {
    return 'بانتظار: $names';
  }

  @override
  String get leaveRoom => 'مغادرة الغرفة';

  @override
  String get leaveConfirmTitle => 'مغادرة الغرفة؟';

  @override
  String get leave => 'مغادرة';

  @override
  String roundLabel(int round) {
    return 'الجولة $round';
  }

  @override
  String roomLabel(String code) {
    return 'غرفة $code';
  }

  @override
  String tiebreakLabel(int roundNo) {
    return 'كسر التعادل $roundNo/3';
  }

  @override
  String get quit => 'خروج';

  @override
  String get quitConfirmTitle => 'الخروج من اللعبة؟';

  @override
  String get quitConfirmBody => 'ستحصل على 0 في هذه الجولة ولن تتمكن من العودة إلى هذه اللعبة.';

  @override
  String get keepPlaying => 'متابعة اللعب';

  @override
  String get cardCounter => 'عدّاد الأوراق';

  @override
  String get deckLabel => 'المتبقية';

  @override
  String get discardLabel => 'المستعملة';

  @override
  String get hit => 'اسحب';

  @override
  String get stay => 'اكتفِ';

  @override
  String get you => 'أنت';

  @override
  String totalScore(int score) {
    return 'المجموع $score';
  }

  @override
  String get thisRound => 'هذه الجولة';

  @override
  String get yourTurn => 'دورك';

  @override
  String turnOf(String name) {
    return 'دور $name';
  }

  @override
  String waitingChoice(String name) {
    return 'بانتظار اختيار $name…';
  }

  @override
  String get dealing => 'توزيع الأوراق…';

  @override
  String get chooseFreeze => 'اختر لاعبًا للتجميد';

  @override
  String get chooseFlipThree => 'اختر لاعبًا يسحب 3 أوراق';

  @override
  String get chooseSecondChance => 'اختر مَن يأخذ الفرصة الثانية';

  @override
  String get forcedBadge => 'إجباري';

  @override
  String get statusStayed => 'اكتفاء';

  @override
  String get statusFrozen => 'تجميد';

  @override
  String get statusBusted => 'احتراق';

  @override
  String get statusLeft => 'مغادرة';

  @override
  String get statusWatching => 'مشاهدة';

  @override
  String get statusReconnecting => 'إعادة اتصال';

  @override
  String get statusTurn => 'الدور';

  @override
  String get seventhCard => 'السابعة!';

  @override
  String get bust => 'احترقت!';

  @override
  String roundScoresTitle(int round) {
    return 'نتائج الجولة $round';
  }

  @override
  String nextRoundIn(int seconds) {
    return 'الجولة التالية بعد $seconds ث';
  }

  @override
  String tiebreakStarting(String names) {
    return 'تعادل في الصدارة! جولة كسر التعادل بين $names';
  }

  @override
  String get pausedTitle => 'بانتظار اللاعبين';

  @override
  String get pausedBody => 'انقطع اتصال الجميع. تستمر اللعبة عند عودة لاعبَين.';

  @override
  String secondsShort(int seconds) {
    return '$seconds ث';
  }

  @override
  String get counterInDeck => 'في المجموعة';

  @override
  String get counterDiscarded => 'مستعملة';

  @override
  String get counterNumbers => 'أوراق الأرقام';

  @override
  String get counterSpecial => 'الأوراق الخاصة';

  @override
  String get secondDeckNote => 'تُستخدم مجموعتان من الأوراق في هذه الجولة';

  @override
  String get resultsTitle => 'انتهت اللعبة';

  @override
  String get winner => 'الفائز';

  @override
  String get youWon => 'فزت!';

  @override
  String drawBetween(String names) {
    return 'تعادل بين $names';
  }

  @override
  String pointsShort(int score) {
    return '$score نقطة';
  }

  @override
  String get continueButton => 'متابعة';

  @override
  String cardNumber(int value) {
    return 'رقم $value';
  }

  @override
  String cardPlus(int value) {
    return 'زائد $value';
  }

  @override
  String get cardTimesTwo => 'ضعف';

  @override
  String get cardFreeze => 'تجميد';

  @override
  String get cardFlipThree => 'اسحب ثلاثة';

  @override
  String get cardSecondChance => 'فرصة ثانية';

  @override
  String get cardBack => 'ورقة مقلوبة';

  @override
  String get howGoalTitle => 'الهدف';

  @override
  String get howGoalBody =>
      'اجمع النقاط على مدى عدة جولات. في نهاية كل جولة، إذا وصل أي لاعب إلى نقاط الفوز (200 افتراضيًا)، يفوز صاحب أعلى مجموع.';

  @override
  String get howTurnTitle => 'دورك';

  @override
  String get howTurnBody =>
      'اختر «اسحب» لتأخذ ورقة، أو «اكتفِ» لتحتفظ بنقاطك وتتوقف في هذه الجولة. تحتاج إلى ورقة رقم واحدة على الأقل لتكتفي.';

  @override
  String get howBustTitle => 'احترقت!';

  @override
  String get howBustBody => 'إذا حصلت على رقم موجود لديك احترقت، وتكون نقاطك 0 في هذه الجولة.';

  @override
  String get howSeventhTitle => 'السابعة!';

  @override
  String get howSeventhBody => 'اجمع 7 أرقام مختلفة لتنتهي الجولة فورًا وتحصل على 15 نقطة إضافية.';

  @override
  String get howSpecialTitle => 'الأوراق الخاصة';

  @override
  String get howFreeze => 'تجميد: اختر لاعبًا (ويمكن أن تكون أنت)، فيحتفظ بنقاطه ويخرج من الجولة.';

  @override
  String get howFlipThree => 'اسحب ثلاثة: اختر لاعبًا (ويمكن أن تكون أنت)، وعليه أن يأخذ الأوراق الثلاث التالية.';

  @override
  String get howSecondChance => 'فرصة ثانية: تنقذك من رقم مكرر مرة واحدة.';

  @override
  String get howPlus => 'من +2 إلى +10: تُضاف إلى نقاطك.';

  @override
  String get howTimesTwo => 'x2: تضاعف مجموع أوراق الأرقام.';

  @override
  String get howScoringTitle => 'حساب النقاط';

  @override
  String get howScoringBody => 'اجمع أوراق الأرقام، وضاعف المجموع إذا كانت لديك x2، ثم أضف أوراق + وأي نقاط إضافية.';

  @override
  String get howHardTitle => 'الوضع الصعب';

  @override
  String get howHardBody =>
      'إذا اختاره المضيف: نقاط الفوز 400 افتراضيًا، والاحتراق يخصم منك 5 نقاط، وعندما يصل مجموعك إلى 75% من نقاط الفوز لا يمكنك الاكتفاء بـ 3 أوراق أرقام أو أقل، وتسحب اللعبة عنك تلقائيًا.';

  @override
  String get howColorsNote => 'لون كل رقم يدل على عدد نسخه: الذهبي للنادر، والأزرق الداكن للأكثر تكرارًا.';

  @override
  String get dealerTag => 'الموزّع';

  @override
  String flipThreeProgress(int count) {
    return 'اسحب ثلاثة: بقي $count';
  }

  @override
  String get watchingTiebreak => 'مشاهدة جولة كسر التعادل';

  @override
  String get chooseHint => 'أو اضغط على مقعد لاعب';
}
