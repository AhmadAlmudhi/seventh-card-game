// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Seventh Card';

  @override
  String get logoTagline => 'THE SEVENTH CARD';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get soundOn => 'Sound on';

  @override
  String get soundOff => 'Sound off';

  @override
  String get nicknameLabel => 'Nickname';

  @override
  String get nicknameHint => 'Your name';

  @override
  String get nicknameInvalid => 'Use 1–16 letters, numbers or spaces.';

  @override
  String get createRoom => 'Create room';

  @override
  String get joinRoom => 'Join room';

  @override
  String get howToPlay => 'How to play';

  @override
  String get back => 'Back';

  @override
  String returnToRoom(String code) {
    return 'Back to room $code';
  }

  @override
  String get joinTitle => 'Join a room';

  @override
  String get roomCodeLabel => 'Room code';

  @override
  String get roomCodeHint => '5 letters and numbers';

  @override
  String get joinButton => 'Join';

  @override
  String get joinNeedsName => 'Enter your name first.';

  @override
  String get roomCodeIncomplete => 'The code has 5 letters and numbers.';

  @override
  String get connecting => 'Joining the room…';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String nicknamePromptTitle(String code) {
    return 'Join room $code';
  }

  @override
  String get goHome => 'Home';

  @override
  String get tryAgain => 'Try again';

  @override
  String get errorRoomNotFound => 'That room doesn\'t exist. Check the code.';

  @override
  String get errorRoomFull => 'This room is full (8 players).';

  @override
  String get errorGameStarted => 'This game has already started.';

  @override
  String get errorRoomBusy => 'A game just ended in this room. Try again in a moment.';

  @override
  String get errorNicknameTaken => 'Someone in this room already uses that name.';

  @override
  String get errorRemoved => 'The host removed you from this room.';

  @override
  String get errorSeatLost => 'You were removed from the game after being disconnected for too long.';

  @override
  String get errorConnectionLost => 'We couldn\'t reconnect to the room.';

  @override
  String get errorServersBusy => 'Servers are busy, please try again later.';

  @override
  String get errorNetwork => 'Can\'t reach the server. Check your connection.';

  @override
  String get errorGameAbandoned => 'Everyone was disconnected for too long, so the game ended with no result.';

  @override
  String get errorNotHost => 'Only the host can do that.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get shareLink => 'Share link';

  @override
  String shareMessage(String link) {
    return 'Join my game of The Seventh Card: $link';
  }

  @override
  String playersTitle(int count) {
    return 'Players ($count/8)';
  }

  @override
  String get youTag => 'You';

  @override
  String get hostTag => 'Host';

  @override
  String get removePlayer => 'Remove player';

  @override
  String removeConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeConfirmBody => 'They won\'t be able to rejoin this room from the same device.';

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get settingsTitle => 'Game settings';

  @override
  String get modeLabel => 'Mode';

  @override
  String get modeNormal => 'Normal';

  @override
  String get modeHard => 'Hard';

  @override
  String get targetLabel => 'Winning score';

  @override
  String forcedLineNote(int line) {
    return 'Forced Hit from $line points';
  }

  @override
  String get decreaseTarget => 'Lower the winning score';

  @override
  String get increaseTarget => 'Raise the winning score';

  @override
  String get startGame => 'Start game';

  @override
  String get waitingForHost => 'Waiting for the host to start…';

  @override
  String get needTwoPlayers => 'You need at least 2 players to start.';

  @override
  String waitingFor(String names) {
    return 'Waiting for: $names';
  }

  @override
  String get leaveRoom => 'Leave room';

  @override
  String get leaveConfirmTitle => 'Leave the room?';

  @override
  String get leave => 'Leave';

  @override
  String roundLabel(int round) {
    return 'Round $round';
  }

  @override
  String roomLabel(String code) {
    return 'Room $code';
  }

  @override
  String tiebreakLabel(int roundNo) {
    return 'Tie-break $roundNo/3';
  }

  @override
  String get quit => 'Quit';

  @override
  String get quitConfirmTitle => 'Quit the game?';

  @override
  String get quitConfirmBody => 'You\'ll score 0 this round and can\'t rejoin this game.';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get cardCounter => 'Card counter';

  @override
  String get deckLabel => 'Left';

  @override
  String get discardLabel => 'Discarded';

  @override
  String get hit => 'Hit';

  @override
  String get stay => 'Stay';

  @override
  String get you => 'You';

  @override
  String totalScore(int score) {
    return 'Total $score';
  }

  @override
  String get thisRound => 'This round';

  @override
  String get yourTurn => 'Your turn';

  @override
  String turnOf(String name) {
    return '$name\'s turn';
  }

  @override
  String waitingChoice(String name) {
    return 'Waiting for $name to choose…';
  }

  @override
  String get dealing => 'Dealing…';

  @override
  String get chooseFreeze => 'Choose a player to freeze';

  @override
  String get chooseFlipThree => 'Choose a player to take 3 cards';

  @override
  String get chooseSecondChance => 'Choose who gets the Second Chance';

  @override
  String get forcedBadge => 'Forced';

  @override
  String get statusStayed => 'Stayed';

  @override
  String get statusFrozen => 'Frozen';

  @override
  String get statusBusted => 'Busted';

  @override
  String get statusLeft => 'Left';

  @override
  String get statusWatching => 'Watching';

  @override
  String get statusReconnecting => 'Reconnecting';

  @override
  String get statusTurn => 'Turn';

  @override
  String get seventhCard => 'Seventh Card!';

  @override
  String get bust => 'Bust!';

  @override
  String roundScoresTitle(int round) {
    return 'Round $round scores';
  }

  @override
  String nextRoundIn(int seconds) {
    return 'Next round in ${seconds}s';
  }

  @override
  String tiebreakStarting(String names) {
    return 'Tied at the top! Tie-break round for $names';
  }

  @override
  String get pausedTitle => 'Waiting for players';

  @override
  String get pausedBody => 'Everyone lost connection. The game continues when 2 players are back.';

  @override
  String secondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String get counterInDeck => 'In deck';

  @override
  String get counterDiscarded => 'Discarded';

  @override
  String get counterNumbers => 'Number cards';

  @override
  String get counterSpecial => 'Special cards';

  @override
  String get secondDeckNote => 'Two decks are in play this round';

  @override
  String get resultsTitle => 'Game over';

  @override
  String get winner => 'Winner';

  @override
  String get youWon => 'You won!';

  @override
  String drawBetween(String names) {
    return 'Draw between $names';
  }

  @override
  String pointsShort(int score) {
    return '$score pts';
  }

  @override
  String get continueButton => 'Continue';

  @override
  String cardNumber(int value) {
    return 'Number $value';
  }

  @override
  String cardPlus(int value) {
    return 'Plus $value';
  }

  @override
  String get cardTimesTwo => 'Times two';

  @override
  String get cardFreeze => 'Freeze';

  @override
  String get cardFlipThree => 'Flip Three';

  @override
  String get cardSecondChance => 'Second Chance';

  @override
  String get cardBack => 'Face-down card';

  @override
  String get howGoalTitle => 'The goal';

  @override
  String get howGoalBody =>
      'Score points over several rounds. At the end of a round, if anyone has reached the winning score (200 by default), the highest total wins.';

  @override
  String get howTurnTitle => 'Your turn';

  @override
  String get howTurnBody =>
      'Choose Hit to take a card, or Stay to keep your points and stop for this round. You need at least one number card to Stay.';

  @override
  String get howBustTitle => 'Bust!';

  @override
  String get howBustBody => 'Get a number you already have and you bust: you score 0 for the round.';

  @override
  String get howSeventhTitle => 'Seventh Card!';

  @override
  String get howSeventhBody =>
      'Collect 7 different numbers and the round ends right away, with a 15-point bonus for you.';

  @override
  String get howSpecialTitle => 'Special cards';

  @override
  String get howFreeze => 'Freeze: pick a player (it can be you). They keep their points and are out for the round.';

  @override
  String get howFlipThree => 'Flip Three: pick a player (it can be you). They must take the next 3 cards.';

  @override
  String get howSecondChance => 'Second Chance: saves you from one duplicate number.';

  @override
  String get howPlus => '+2 to +10: added to your score.';

  @override
  String get howTimesTwo => 'x2: doubles the total of your number cards.';

  @override
  String get howScoringTitle => 'Scoring';

  @override
  String get howScoringBody => 'Add up your number cards, double that for x2, then add your + cards and any bonus.';

  @override
  String get howHardTitle => 'Hard Mode';

  @override
  String get howHardBody =>
      'If the host picks it: the winning score is 400 by default, a bust costs you 5 points, and once your total reaches 75% of the winning score you can\'t Stay with 3 or fewer number cards. The game draws for you.';

  @override
  String get howColorsNote =>
      'Each number\'s color shows its risk: a number has as many copies as its value, so green ones are rare and safe, and red ones are common and riskier.';

  @override
  String get dealerTag => 'Dealer';

  @override
  String flipThreeProgress(int count) {
    return 'Flip Three: $count to go';
  }

  @override
  String get watchingTiebreak => 'Watching the tie-break';

  @override
  String get chooseHint => 'or tap a player\'s seat';

  @override
  String get tutorialButton => 'Tutorial game';

  @override
  String get returnToTutorial => 'Back to the tutorial';

  @override
  String tutorialLabel(int score) {
    return 'Tutorial · to $score';
  }

  @override
  String get botName => 'Robo';

  @override
  String get seatRound => 'Round';

  @override
  String get seatTotal => 'Total';

  @override
  String lastCardOf(String name) {
    return '$name\'s card';
  }

  @override
  String get lastCardMine => 'Your card';

  @override
  String get lastCardWaiting => 'Waiting for the first card';

  @override
  String get stageBust => 'Bust!';

  @override
  String get stageSaved => 'Saved!';

  @override
  String get stageFreeze => 'Freeze!';

  @override
  String get stageFlipThree => 'Flip Three!';

  @override
  String get stageSecondChance => 'Second Chance!';

  @override
  String get counterLeftTotal => 'In the deck';

  @override
  String get counterDiscardedTotal => 'Discarded';

  @override
  String get tipGotIt => 'Got it';

  @override
  String get tipWelcomeTitle => 'Welcome to the tutorial';

  @override
  String get tipWelcomeBody =>
      'Beat Robo to 50 points. Take cards one at a time, and stop before you get the same number twice.';

  @override
  String get tipTurnTitle => 'Your turn';

  @override
  String get tipTurnBody =>
      'Hit gives you another card and adds its number to your round. Stay keeps your points and ends your round.';

  @override
  String get tipRiskTitle => 'Watch the colors';

  @override
  String get tipRiskBody =>
      'Each number has as many copies as its value. Red numbers are the most common, so the more of them you hold, the likelier a bust.';

  @override
  String get tipBustTitle => 'Bust!';

  @override
  String get tipBustBody => 'Getting a number twice in one round is a bust: that round scores 0.';

  @override
  String get tipFreezeTitle => 'Freeze';

  @override
  String get tipFreezeBody =>
      'Whoever draws it picks a player, who keeps their points but stops for this round. Try freezing Robo early, or yourself to bank a good round.';

  @override
  String get tipFlipThreeTitle => 'Flip Three';

  @override
  String get tipFlipThreeBody =>
      'Whoever draws it picks a player to take the next 3 cards. It\'s risky, so it\'s usually best given to Robo.';

  @override
  String get tipSecondChanceTitle => 'Second Chance';

  @override
  String get tipSecondChanceBody =>
      'It saves its holder from one duplicate number: both are discarded instead of a bust.';

  @override
  String get tipModifierTitle => 'Bonus cards';

  @override
  String get tipModifierBody => '+ cards add points to the round, and x2 doubles the total of the number cards.';

  @override
  String get tipSeventhTitle => 'Seventh Card!';

  @override
  String get tipSeventhBody => '7 different numbers end the round at once, with 15 bonus points.';

  @override
  String get tutorialWonBody => 'You\'ve got it! Create a room and invite your friends.';

  @override
  String get tutorialLostBody => 'Robo won this time. Give it another go.';

  @override
  String get playAgain => 'Play again';

  @override
  String get tutorialRoundNote => 'When a round ends with either of you on 50 or more, the highest total wins.';

  @override
  String get announceFrozen => 'You\'re frozen for this round';

  @override
  String get deckReshuffled => 'Discards shuffled back into the deck';

  @override
  String get deckExtra => 'A second deck joins';

  @override
  String get deckFresh => 'A fresh deck';

  @override
  String forcedDrawOf(String name) {
    return 'Forced Hit: $name';
  }

  @override
  String get forcedDrawMine => 'Forced Hit';

  @override
  String gameCaption(String code, int score) {
    return 'Room $code · to $score';
  }

  @override
  String gameCaptionHard(String code, int score) {
    return 'Room $code · Hard · to $score';
  }

  @override
  String get forcedNote => 'Forced Hit: the game draws for you until you have 4 number cards.';

  @override
  String get counterInRow => 'In your row';

  @override
  String tiebreakTitle(int roundNo) {
    return 'Tie-break $roundNo/3';
  }

  @override
  String get tiebreakBody => 'The best score this round wins';

  @override
  String get afterTiebreak => 'After a tie-break round';

  @override
  String afterTiebreaks(int count) {
    return 'After $count tie-break rounds';
  }
}
