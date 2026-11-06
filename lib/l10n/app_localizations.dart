import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// The game's name. Also the browser tab title.
  ///
  /// In ar, this message translates to:
  /// **'الورقة السابعة'**
  String get appTitle;

  /// Latin line under the logo. The same in both languages.
  ///
  /// In ar, this message translates to:
  /// **'THE SEVENTH CARD'**
  String get logoTagline;

  /// Language toggle label. Always written in Arabic, in both languages.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Language toggle label. Always written in English, in both languages.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @soundOn.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مفعّل'**
  String get soundOn;

  /// No description provided for @soundOff.
  ///
  /// In ar, this message translates to:
  /// **'الصوت متوقف'**
  String get soundOff;

  /// No description provided for @nicknameLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get nicknameLabel;

  /// No description provided for @nicknameHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك'**
  String get nicknameHint;

  /// No description provided for @nicknameInvalid.
  ///
  /// In ar, this message translates to:
  /// **'استخدم من 1 إلى 16 حرفًا أو رقمًا أو مسافة.'**
  String get nicknameInvalid;

  /// No description provided for @createRoom.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء غرفة'**
  String get createRoom;

  /// No description provided for @joinRoom.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام لغرفة'**
  String get joinRoom;

  /// No description provided for @howToPlay.
  ///
  /// In ar, this message translates to:
  /// **'كيفية اللعب'**
  String get howToPlay;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @returnToRoom.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الغرفة {code}'**
  String returnToRoom(String code);

  /// No description provided for @joinTitle.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام لغرفة'**
  String get joinTitle;

  /// No description provided for @roomCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز الغرفة'**
  String get roomCodeLabel;

  /// No description provided for @roomCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'5 أحرف وأرقام'**
  String get roomCodeHint;

  /// No description provided for @joinButton.
  ///
  /// In ar, this message translates to:
  /// **'انضمام'**
  String get joinButton;

  /// No description provided for @joinNeedsName.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسمك أولًا.'**
  String get joinNeedsName;

  /// No description provided for @roomCodeIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'الرمز من 5 أحرف وأرقام.'**
  String get roomCodeIncomplete;

  /// No description provided for @connecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الانضمام إلى الغرفة…'**
  String get connecting;

  /// No description provided for @reconnecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إعادة الاتصال…'**
  String get reconnecting;

  /// No description provided for @nicknamePromptTitle.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام إلى الغرفة {code}'**
  String nicknamePromptTitle(String code);

  /// No description provided for @goHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get goHome;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get tryAgain;

  /// No description provided for @errorRoomNotFound.
  ///
  /// In ar, this message translates to:
  /// **'هذه الغرفة غير موجودة. تأكد من الرمز.'**
  String get errorRoomNotFound;

  /// No description provided for @errorRoomFull.
  ///
  /// In ar, this message translates to:
  /// **'هذه الغرفة ممتلئة (8 لاعبين).'**
  String get errorRoomFull;

  /// No description provided for @errorGameStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت هذه اللعبة بالفعل.'**
  String get errorGameStarted;

  /// No description provided for @errorRoomBusy.
  ///
  /// In ar, this message translates to:
  /// **'انتهت لعبة للتو في هذه الغرفة. حاول مرة أخرى بعد قليل.'**
  String get errorRoomBusy;

  /// No description provided for @errorNicknameTaken.
  ///
  /// In ar, this message translates to:
  /// **'هناك من يستخدم هذا الاسم في الغرفة.'**
  String get errorNicknameTaken;

  /// No description provided for @errorRemoved.
  ///
  /// In ar, this message translates to:
  /// **'أزالك المضيف من هذه الغرفة.'**
  String get errorRemoved;

  /// No description provided for @errorSeatLost.
  ///
  /// In ar, this message translates to:
  /// **'أُزلت من اللعبة بعد انقطاع الاتصال لفترة طويلة.'**
  String get errorSeatLost;

  /// No description provided for @errorConnectionLost.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت إعادة الاتصال بالغرفة.'**
  String get errorConnectionLost;

  /// No description provided for @errorServersBusy.
  ///
  /// In ar, this message translates to:
  /// **'الخوادم مشغولة، حاول مرة أخرى لاحقًا.'**
  String get errorServersBusy;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى الخادم. تحقق من اتصالك.'**
  String get errorNetwork;

  /// No description provided for @errorGameAbandoned.
  ///
  /// In ar, this message translates to:
  /// **'انقطع اتصال الجميع لفترة طويلة، فانتهت اللعبة بلا نتيجة.'**
  String get errorGameAbandoned;

  /// No description provided for @errorNotHost.
  ///
  /// In ar, this message translates to:
  /// **'هذا للمضيف فقط.'**
  String get errorNotHost;

  /// No description provided for @errorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما. حاول مرة أخرى.'**
  String get errorGeneric;

  /// No description provided for @copyCode.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الرمز'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ الرمز'**
  String get codeCopied;

  /// No description provided for @shareLink.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الرابط'**
  String get shareLink;

  /// No description provided for @shareMessage.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى لعبتي في الورقة السابعة: {link}'**
  String shareMessage(String link);

  /// No description provided for @playersTitle.
  ///
  /// In ar, this message translates to:
  /// **'اللاعبون ({count}/8)'**
  String playersTitle(int count);

  /// No description provided for @youTag.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get youTag;

  /// No description provided for @hostTag.
  ///
  /// In ar, this message translates to:
  /// **'المضيف'**
  String get hostTag;

  /// No description provided for @removePlayer.
  ///
  /// In ar, this message translates to:
  /// **'إزالة اللاعب'**
  String get removePlayer;

  /// No description provided for @removeConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name}؟'**
  String removeConfirmTitle(String name);

  /// No description provided for @removeConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'لن يمكن الانضمام إلى هذه الغرفة مرة أخرى من الجهاز نفسه.'**
  String get removeConfirmBody;

  /// No description provided for @remove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات اللعبة'**
  String get settingsTitle;

  /// No description provided for @modeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوضع'**
  String get modeLabel;

  /// No description provided for @modeNormal.
  ///
  /// In ar, this message translates to:
  /// **'عادي'**
  String get modeNormal;

  /// No description provided for @modeHard.
  ///
  /// In ar, this message translates to:
  /// **'صعب'**
  String get modeHard;

  /// No description provided for @targetLabel.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الفوز'**
  String get targetLabel;

  /// No description provided for @forcedLineNote.
  ///
  /// In ar, this message translates to:
  /// **'السحب إجباري من {line} نقطة'**
  String forcedLineNote(int line);

  /// No description provided for @decreaseTarget.
  ///
  /// In ar, this message translates to:
  /// **'خفض نقاط الفوز'**
  String get decreaseTarget;

  /// No description provided for @increaseTarget.
  ///
  /// In ar, this message translates to:
  /// **'رفع نقاط الفوز'**
  String get increaseTarget;

  /// No description provided for @startGame.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ اللعبة'**
  String get startGame;

  /// No description provided for @waitingForHost.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار أن يبدأ المضيف…'**
  String get waitingForHost;

  /// No description provided for @needTwoPlayers.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج إلى لاعبَين على الأقل للبدء.'**
  String get needTwoPlayers;

  /// No description provided for @waitingFor.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار: {names}'**
  String waitingFor(String names);

  /// No description provided for @leaveRoom.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الغرفة'**
  String get leaveRoom;

  /// No description provided for @leaveConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الغرفة؟'**
  String get leaveConfirmTitle;

  /// No description provided for @leave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get leave;

  /// No description provided for @roundLabel.
  ///
  /// In ar, this message translates to:
  /// **'الجولة {round}'**
  String roundLabel(int round);

  /// No description provided for @roomLabel.
  ///
  /// In ar, this message translates to:
  /// **'غرفة {code}'**
  String roomLabel(String code);

  /// No description provided for @tiebreakLabel.
  ///
  /// In ar, this message translates to:
  /// **'كسر التعادل {roundNo}/3'**
  String tiebreakLabel(int roundNo);

  /// No description provided for @quit.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get quit;

  /// No description provided for @quitConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'الخروج من اللعبة؟'**
  String get quitConfirmTitle;

  /// No description provided for @quitConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستحصل على 0 في هذه الجولة ولن تتمكن من العودة إلى هذه اللعبة.'**
  String get quitConfirmBody;

  /// No description provided for @keepPlaying.
  ///
  /// In ar, this message translates to:
  /// **'متابعة اللعب'**
  String get keepPlaying;

  /// No description provided for @cardCounter.
  ///
  /// In ar, this message translates to:
  /// **'عدّاد الأوراق'**
  String get cardCounter;

  /// No description provided for @deckLabel.
  ///
  /// In ar, this message translates to:
  /// **'المتبقية'**
  String get deckLabel;

  /// No description provided for @discardLabel.
  ///
  /// In ar, this message translates to:
  /// **'المستعملة'**
  String get discardLabel;

  /// No description provided for @hit.
  ///
  /// In ar, this message translates to:
  /// **'اسحب'**
  String get hit;

  /// No description provided for @stay.
  ///
  /// In ar, this message translates to:
  /// **'اكتفِ'**
  String get stay;

  /// No description provided for @you.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get you;

  /// No description provided for @totalScore.
  ///
  /// In ar, this message translates to:
  /// **'المجموع {score}'**
  String totalScore(int score);

  /// No description provided for @thisRound.
  ///
  /// In ar, this message translates to:
  /// **'هذه الجولة'**
  String get thisRound;

  /// No description provided for @yourTurn.
  ///
  /// In ar, this message translates to:
  /// **'دورك'**
  String get yourTurn;

  /// No description provided for @turnOf.
  ///
  /// In ar, this message translates to:
  /// **'دور {name}'**
  String turnOf(String name);

  /// No description provided for @waitingChoice.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار اختيار {name}…'**
  String waitingChoice(String name);

  /// No description provided for @dealing.
  ///
  /// In ar, this message translates to:
  /// **'توزيع الأوراق…'**
  String get dealing;

  /// No description provided for @chooseFreeze.
  ///
  /// In ar, this message translates to:
  /// **'اختر لاعبًا للتجميد'**
  String get chooseFreeze;

  /// No description provided for @chooseFlipThree.
  ///
  /// In ar, this message translates to:
  /// **'اختر لاعبًا يسحب 3 أوراق'**
  String get chooseFlipThree;

  /// No description provided for @chooseSecondChance.
  ///
  /// In ar, this message translates to:
  /// **'اختر مَن يأخذ الفرصة الثانية'**
  String get chooseSecondChance;

  /// No description provided for @forcedBadge.
  ///
  /// In ar, this message translates to:
  /// **'إجباري'**
  String get forcedBadge;

  /// No description provided for @statusStayed.
  ///
  /// In ar, this message translates to:
  /// **'اكتفاء'**
  String get statusStayed;

  /// No description provided for @statusFrozen.
  ///
  /// In ar, this message translates to:
  /// **'تجميد'**
  String get statusFrozen;

  /// No description provided for @statusBusted.
  ///
  /// In ar, this message translates to:
  /// **'احتراق'**
  String get statusBusted;

  /// No description provided for @statusLeft.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get statusLeft;

  /// No description provided for @statusWatching.
  ///
  /// In ar, this message translates to:
  /// **'مشاهدة'**
  String get statusWatching;

  /// No description provided for @statusReconnecting.
  ///
  /// In ar, this message translates to:
  /// **'إعادة اتصال'**
  String get statusReconnecting;

  /// No description provided for @statusTurn.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get statusTurn;

  /// No description provided for @seventhCard.
  ///
  /// In ar, this message translates to:
  /// **'السابعة!'**
  String get seventhCard;

  /// No description provided for @bust.
  ///
  /// In ar, this message translates to:
  /// **'احترقت!'**
  String get bust;

  /// No description provided for @roundScoresTitle.
  ///
  /// In ar, this message translates to:
  /// **'نتائج الجولة {round}'**
  String roundScoresTitle(int round);

  /// No description provided for @nextRoundIn.
  ///
  /// In ar, this message translates to:
  /// **'الجولة التالية بعد {seconds} ث'**
  String nextRoundIn(int seconds);

  /// No description provided for @tiebreakStarting.
  ///
  /// In ar, this message translates to:
  /// **'تعادل في الصدارة! جولة كسر التعادل بين {names}'**
  String tiebreakStarting(String names);

  /// No description provided for @pausedTitle.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار اللاعبين'**
  String get pausedTitle;

  /// No description provided for @pausedBody.
  ///
  /// In ar, this message translates to:
  /// **'انقطع اتصال الجميع. تستمر اللعبة عند عودة لاعبَين.'**
  String get pausedBody;

  /// No description provided for @secondsShort.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث'**
  String secondsShort(int seconds);

  /// No description provided for @counterInDeck.
  ///
  /// In ar, this message translates to:
  /// **'في المجموعة'**
  String get counterInDeck;

  /// No description provided for @counterDiscarded.
  ///
  /// In ar, this message translates to:
  /// **'مستعملة'**
  String get counterDiscarded;

  /// No description provided for @counterNumbers.
  ///
  /// In ar, this message translates to:
  /// **'أوراق الأرقام'**
  String get counterNumbers;

  /// No description provided for @counterSpecial.
  ///
  /// In ar, this message translates to:
  /// **'الأوراق الخاصة'**
  String get counterSpecial;

  /// No description provided for @secondDeckNote.
  ///
  /// In ar, this message translates to:
  /// **'تُستخدم مجموعتان من الأوراق في هذه الجولة'**
  String get secondDeckNote;

  /// No description provided for @resultsTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتهت اللعبة'**
  String get resultsTitle;

  /// No description provided for @winner.
  ///
  /// In ar, this message translates to:
  /// **'الفائز'**
  String get winner;

  /// No description provided for @youWon.
  ///
  /// In ar, this message translates to:
  /// **'فزت!'**
  String get youWon;

  /// No description provided for @drawBetween.
  ///
  /// In ar, this message translates to:
  /// **'تعادل بين {names}'**
  String drawBetween(String names);

  /// No description provided for @pointsShort.
  ///
  /// In ar, this message translates to:
  /// **'{score} نقطة'**
  String pointsShort(int score);

  /// No description provided for @continueButton.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueButton;

  /// No description provided for @cardNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم {value}'**
  String cardNumber(int value);

  /// No description provided for @cardPlus.
  ///
  /// In ar, this message translates to:
  /// **'زائد {value}'**
  String cardPlus(int value);

  /// No description provided for @cardTimesTwo.
  ///
  /// In ar, this message translates to:
  /// **'ضعف'**
  String get cardTimesTwo;

  /// No description provided for @cardFreeze.
  ///
  /// In ar, this message translates to:
  /// **'تجميد'**
  String get cardFreeze;

  /// No description provided for @cardFlipThree.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ثلاثة'**
  String get cardFlipThree;

  /// No description provided for @cardSecondChance.
  ///
  /// In ar, this message translates to:
  /// **'فرصة ثانية'**
  String get cardSecondChance;

  /// No description provided for @cardBack.
  ///
  /// In ar, this message translates to:
  /// **'ورقة مقلوبة'**
  String get cardBack;

  /// No description provided for @howGoalTitle.
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get howGoalTitle;

  /// No description provided for @howGoalBody.
  ///
  /// In ar, this message translates to:
  /// **'اجمع النقاط على مدى عدة جولات. في نهاية كل جولة، إذا وصل أي لاعب إلى نقاط الفوز (200 افتراضيًا)، يفوز صاحب أعلى مجموع.'**
  String get howGoalBody;

  /// No description provided for @howTurnTitle.
  ///
  /// In ar, this message translates to:
  /// **'دورك'**
  String get howTurnTitle;

  /// No description provided for @howTurnBody.
  ///
  /// In ar, this message translates to:
  /// **'اختر «اسحب» لتأخذ ورقة، أو «اكتفِ» لتحتفظ بنقاطك وتتوقف في هذه الجولة. تحتاج إلى ورقة رقم واحدة على الأقل لتكتفي.'**
  String get howTurnBody;

  /// No description provided for @howBustTitle.
  ///
  /// In ar, this message translates to:
  /// **'احترقت!'**
  String get howBustTitle;

  /// No description provided for @howBustBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا حصلت على رقم موجود لديك احترقت، وتكون نقاطك 0 في هذه الجولة.'**
  String get howBustBody;

  /// No description provided for @howSeventhTitle.
  ///
  /// In ar, this message translates to:
  /// **'السابعة!'**
  String get howSeventhTitle;

  /// No description provided for @howSeventhBody.
  ///
  /// In ar, this message translates to:
  /// **'اجمع 7 أرقام مختلفة لتنتهي الجولة فورًا وتحصل على 15 نقطة إضافية.'**
  String get howSeventhBody;

  /// No description provided for @howSpecialTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأوراق الخاصة'**
  String get howSpecialTitle;

  /// No description provided for @howFreeze.
  ///
  /// In ar, this message translates to:
  /// **'تجميد: اختر لاعبًا (ويمكن أن تكون أنت)، فيحتفظ بنقاطه ويخرج من الجولة.'**
  String get howFreeze;

  /// No description provided for @howFlipThree.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ثلاثة: اختر لاعبًا (ويمكن أن تكون أنت)، وعليه أن يأخذ الأوراق الثلاث التالية.'**
  String get howFlipThree;

  /// No description provided for @howSecondChance.
  ///
  /// In ar, this message translates to:
  /// **'فرصة ثانية: تنقذك من رقم مكرر مرة واحدة.'**
  String get howSecondChance;

  /// No description provided for @howPlus.
  ///
  /// In ar, this message translates to:
  /// **'من +2 إلى +10: تُضاف إلى نقاطك.'**
  String get howPlus;

  /// No description provided for @howTimesTwo.
  ///
  /// In ar, this message translates to:
  /// **'x2: تضاعف مجموع أوراق الأرقام.'**
  String get howTimesTwo;

  /// No description provided for @howScoringTitle.
  ///
  /// In ar, this message translates to:
  /// **'حساب النقاط'**
  String get howScoringTitle;

  /// No description provided for @howScoringBody.
  ///
  /// In ar, this message translates to:
  /// **'اجمع أوراق الأرقام، وضاعف المجموع إذا كانت لديك x2، ثم أضف أوراق + وأي نقاط إضافية.'**
  String get howScoringBody;

  /// No description provided for @howHardTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الصعب'**
  String get howHardTitle;

  /// No description provided for @howHardBody.
  ///
  /// In ar, this message translates to:
  /// **'إذا اختاره المضيف: نقاط الفوز 400 افتراضيًا، والاحتراق يخصم منك 5 نقاط، وعندما يصل مجموعك إلى 75% من نقاط الفوز لا يمكنك الاكتفاء بـ 3 أوراق أرقام أو أقل، وتسحب اللعبة عنك تلقائيًا.'**
  String get howHardBody;

  /// No description provided for @howColorsNote.
  ///
  /// In ar, this message translates to:
  /// **'لون كل رقم يدل على خطره: لكل رقم نسخ بعدد قيمته، فالأخضر نادر وآمن، والأحمر كثير التكرار وأخطر.'**
  String get howColorsNote;

  /// No description provided for @dealerTag.
  ///
  /// In ar, this message translates to:
  /// **'الموزّع'**
  String get dealerTag;

  /// No description provided for @flipThreeProgress.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ثلاثة: بقي {count}'**
  String flipThreeProgress(int count);

  /// No description provided for @watchingTiebreak.
  ///
  /// In ar, this message translates to:
  /// **'مشاهدة جولة كسر التعادل'**
  String get watchingTiebreak;

  /// No description provided for @chooseHint.
  ///
  /// In ar, this message translates to:
  /// **'أو اضغط على مقعد لاعب'**
  String get chooseHint;

  /// No description provided for @tutorialButton.
  ///
  /// In ar, this message translates to:
  /// **'لعبة تعليمية'**
  String get tutorialButton;

  /// No description provided for @returnToTutorial.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى اللعبة التعليمية'**
  String get returnToTutorial;

  /// No description provided for @tutorialLabel.
  ///
  /// In ar, this message translates to:
  /// **'لعبة تعليمية · حتى {score}'**
  String tutorialLabel(int score);

  /// No description provided for @botName.
  ///
  /// In ar, this message translates to:
  /// **'روبو'**
  String get botName;

  /// No description provided for @seatRound.
  ///
  /// In ar, this message translates to:
  /// **'الجولة'**
  String get seatRound;

  /// No description provided for @seatTotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get seatTotal;

  /// No description provided for @lastCardOf.
  ///
  /// In ar, this message translates to:
  /// **'ورقة {name}'**
  String lastCardOf(String name);

  /// No description provided for @lastCardMine.
  ///
  /// In ar, this message translates to:
  /// **'ورقتك'**
  String get lastCardMine;

  /// No description provided for @lastCardWaiting.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار أول ورقة'**
  String get lastCardWaiting;

  /// No description provided for @stageBust.
  ///
  /// In ar, this message translates to:
  /// **'احتراق!'**
  String get stageBust;

  /// No description provided for @stageSaved.
  ///
  /// In ar, this message translates to:
  /// **'نجاة!'**
  String get stageSaved;

  /// No description provided for @stageFreeze.
  ///
  /// In ar, this message translates to:
  /// **'تجميد!'**
  String get stageFreeze;

  /// No description provided for @stageFlipThree.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ثلاثة!'**
  String get stageFlipThree;

  /// No description provided for @stageSecondChance.
  ///
  /// In ar, this message translates to:
  /// **'فرصة ثانية!'**
  String get stageSecondChance;

  /// No description provided for @counterLeftTotal.
  ///
  /// In ar, this message translates to:
  /// **'في المجموعة'**
  String get counterLeftTotal;

  /// No description provided for @counterDiscardedTotal.
  ///
  /// In ar, this message translates to:
  /// **'مستعملة'**
  String get counterDiscardedTotal;

  /// No description provided for @tipGotIt.
  ///
  /// In ar, this message translates to:
  /// **'فهمت'**
  String get tipGotIt;

  /// No description provided for @tipWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بك في اللعبة التعليمية'**
  String get tipWelcomeTitle;

  /// No description provided for @tipWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'تغلّب على روبو بالوصول إلى 50 نقطة. خذ الأوراق واحدة تلو الأخرى، وتوقّف قبل أن يتكرر معك رقم.'**
  String get tipWelcomeBody;

  /// No description provided for @tipTurnTitle.
  ///
  /// In ar, this message translates to:
  /// **'دورك'**
  String get tipTurnTitle;

  /// No description provided for @tipTurnBody.
  ///
  /// In ar, this message translates to:
  /// **'«اسحب» تعطيك ورقة جديدة يُضاف رقمها إلى نقاط جولتك. «اكتفِ» تحفظ نقاطك وتنهي جولتك.'**
  String get tipTurnBody;

  /// No description provided for @tipRiskTitle.
  ///
  /// In ar, this message translates to:
  /// **'انتبه للألوان'**
  String get tipRiskTitle;

  /// No description provided for @tipRiskBody.
  ///
  /// In ar, this message translates to:
  /// **'لكل رقم نسخ بعدد قيمته. الأرقام الحمراء هي الأكثر تكرارًا، فكلما جمعت منها زاد خطر الاحتراق.'**
  String get tipRiskBody;

  /// No description provided for @tipBustTitle.
  ///
  /// In ar, this message translates to:
  /// **'احتراق!'**
  String get tipBustTitle;

  /// No description provided for @tipBustBody.
  ///
  /// In ar, this message translates to:
  /// **'تكرار رقم في الجولة نفسها يعني الاحتراق، وتكون نقاط تلك الجولة 0.'**
  String get tipBustBody;

  /// No description provided for @tipFreezeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تجميد'**
  String get tipFreezeTitle;

  /// No description provided for @tipFreezeBody.
  ///
  /// In ar, this message translates to:
  /// **'من يسحبها يختار لاعبًا يحتفظ بنقاطه ويتوقف في هذه الجولة. جرّب تجميد روبو مبكرًا، أو جمّد نفسك لتحفظ جولة جيدة.'**
  String get tipFreezeBody;

  /// No description provided for @tipFlipThreeTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسحب ثلاثة'**
  String get tipFlipThreeTitle;

  /// No description provided for @tipFlipThreeBody.
  ///
  /// In ar, this message translates to:
  /// **'من يسحبها يختار لاعبًا يأخذ الأوراق الثلاث التالية. إنها مخاطرة، لذا من الأفضل غالبًا أن تعطيها لروبو.'**
  String get tipFlipThreeBody;

  /// No description provided for @tipSecondChanceTitle.
  ///
  /// In ar, this message translates to:
  /// **'فرصة ثانية'**
  String get tipSecondChanceTitle;

  /// No description provided for @tipSecondChanceBody.
  ///
  /// In ar, this message translates to:
  /// **'تنقذ صاحبها من رقم مكرر مرة واحدة، فتُستبعد مع الرقم المكرر بدل الاحتراق.'**
  String get tipSecondChanceBody;

  /// No description provided for @tipModifierTitle.
  ///
  /// In ar, this message translates to:
  /// **'أوراق الإضافة'**
  String get tipModifierTitle;

  /// No description provided for @tipModifierBody.
  ///
  /// In ar, this message translates to:
  /// **'أوراق + تضيف نقاطًا إلى الجولة، وورقة x2 تضاعف مجموع أوراق الأرقام.'**
  String get tipModifierBody;

  /// No description provided for @tipSeventhTitle.
  ///
  /// In ar, this message translates to:
  /// **'السابعة!'**
  String get tipSeventhTitle;

  /// No description provided for @tipSeventhBody.
  ///
  /// In ar, this message translates to:
  /// **'سبعة أرقام مختلفة تنهي الجولة فورًا، مع 15 نقطة إضافية.'**
  String get tipSeventhBody;

  /// No description provided for @tutorialWonBody.
  ///
  /// In ar, this message translates to:
  /// **'أتقنت اللعبة! أنشئ غرفة وادعُ أصدقاءك.'**
  String get tutorialWonBody;

  /// No description provided for @tutorialLostBody.
  ///
  /// In ar, this message translates to:
  /// **'فاز روبو هذه المرة. جرّب مرة أخرى.'**
  String get tutorialLostBody;

  /// No description provided for @playAgain.
  ///
  /// In ar, this message translates to:
  /// **'العب مرة أخرى'**
  String get playAgain;

  /// No description provided for @tutorialRoundNote.
  ///
  /// In ar, this message translates to:
  /// **'عندما تنتهي جولة وأحدكما على 50 نقطة أو أكثر، يفوز صاحب أعلى مجموع.'**
  String get tutorialRoundNote;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
