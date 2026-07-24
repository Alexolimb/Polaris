// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get navMarkets => 'Markets';

  @override
  String get navCosmo => 'Cosmo';

  @override
  String get navLearn => 'Learn';

  @override
  String get navMore => 'More';

  @override
  String get cancelLabel => 'Cancel';

  @override
  String get doneLabel => 'Got it';

  @override
  String get commonNothingFound => 'Nothing found';

  @override
  String get resetDialogTitle => 'Start over?';

  @override
  String get resetDialogBody =>
      'Your portfolio will reset to the starting \$10,000. Trade history will be cleared. It\'s practice money — no worries.';

  @override
  String get resetConfirmAction => 'Start over';

  @override
  String get moreScreenTitle => 'More';

  @override
  String get moreSettingsTitle => 'Settings';

  @override
  String get moreSettingsSubtitle => 'Notifications and portfolio data';

  @override
  String get moreBrokersTitle => 'Ready for real investing?';

  @override
  String get moreBrokersSubtitle => 'EU-licensed brokers to get started';

  @override
  String get moreAboutTitle => 'About the app';

  @override
  String get moreAboutSubtitle => 'Polaris, version, credits';

  @override
  String get morePrivacyTitle => 'Privacy';

  @override
  String get morePrivacySubtitle => 'What data leaves the app, and where';

  @override
  String get moreLegalTitle => 'Legal information';

  @override
  String get moreLegalSubtitle => 'Disclaimers and terms of use';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageAuto => 'Automatic (system)';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsNotificationsSection => 'Notifications';

  @override
  String get settingsNotifLesson => 'Daily lesson & streak';

  @override
  String get settingsNotifLessonSub => 'Evening reminder to practice';

  @override
  String get settingsNotifWeekly => 'Weekly summary';

  @override
  String get settingsNotifWeeklySub => 'How your portfolio changed this week';

  @override
  String get settingsNotifDividend => 'Dividend received';

  @override
  String get settingsNotifDividendSub => 'Notify when dividends are credited';

  @override
  String get settingsNotifBigMoves => 'Big price moves';

  @override
  String get settingsNotifBigMovesSub => '±5% in a day on your holdings';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get settingsResetPortfolio => 'Reset portfolio';

  @override
  String get settingsResetPortfolioSub =>
      'Restore the starting \$10,000, clear history';

  @override
  String get aboutTitle => 'About the app';

  @override
  String aboutVersionLabel(String version) {
    return 'Version $version · investing simulator';
  }

  @override
  String get aboutWhatIsItTitle => 'What this is';

  @override
  String get aboutWhatIsItBody =>
      'Polaris is a free investing trainer for people who have never bought a stock before. A virtual \$10,000 portfolio, real live prices, honest dividends, and an AI mentor, Cosmo, who explains everything in plain words — no rush, no \"casino\" pressure.';

  @override
  String get aboutSimNoteTitle => 'This is learning, not a stock exchange';

  @override
  String get aboutSimNoteBody =>
      'This is a simulator: the money in your portfolio is virtual, the app never places real trades. The \"Ready for real investing?\" section under More is an honest handoff to EU-licensed brokers, for whenever you decide to invest for real.';

  @override
  String get aboutMascotTitle => 'Cosmo';

  @override
  String get aboutMascotBody =>
      'Your astronaut mentor. Cosmo doesn\'t give personal investment recommendations or promise returns — just calmly explains what\'s happening in the market and in your portfolio.';

  @override
  String get aboutDataTitle => 'Where the data comes from';

  @override
  String get aboutDataBody =>
      'Quotes, exchange rates and charts arrive through Polaris\'s own caching server — the app never talks to third-party APIs directly. Sources are listed below.';

  @override
  String get aboutThanksTitle => 'Credits';

  @override
  String get aboutAttrCoinGecko => 'Powered by CoinGecko';

  @override
  String get aboutAttrCurrency => 'Exchange rates: open.er-api.com';

  @override
  String get aboutAttrCrypto => 'Crypto tickers: Binance public API';

  @override
  String get aboutAttrStocks => 'Stock quotes: Yahoo Finance (may be delayed)';

  @override
  String get brokersTitle => 'Ready for real investing?';

  @override
  String get brokersRiskTop =>
      'Investing carries the risk of losing capital. Nothing below is financial advice or a personal recommendation: Polaris is not a licensed financial advisor. Before investing real money, study the terms and risks with your chosen broker yourself.';

  @override
  String get brokersRiskBottom =>
      'The list below is informational and shown in alphabetical order, not as a recommendation. We don\'t get paid for which broker you choose (phase 1). The decision is yours alone.';

  @override
  String get brokersIntro =>
      'You\'ve practiced in Polaris with a virtual \$10,000 and real live prices — a safe way to understand how it all works, with no risk to your wallet. Once you feel ready to invest real money, here are a few EU-licensed stock brokers — beginners usually find them easier to start with.';

  @override
  String get brokersSectionListTitle => 'EU-licensed stock and ETF brokers';

  @override
  String get brokersExternalSiteNote => 'external site';

  @override
  String get brokersOpenFailed => 'Couldn\'t open the link on this device';

  @override
  String get brokersOpenSiteLabel => 'Open website';

  @override
  String get brokersNoCryptoNote =>
      'No crypto brokers or exchanges here — only regulated brokers for real stocks and ETFs.';

  @override
  String get brokersEtoroDesc =>
      'A broker with a simple mobile app and ready-made portfolio picks; regulated in the EU (Cyprus/Malta).';

  @override
  String get brokersIbkrDesc =>
      'One of the largest brokers in the world, a huge range of markets; better suited to those ready to dig into a more detailed interface.';

  @override
  String get brokersLightyearDesc =>
      'A young European broker with an honest interface and \"why the price changed\" explanations — closest in spirit to Polaris.';

  @override
  String get brokersScalableDesc =>
      'A German neobroker with fractional shares and ready-made savings plans; regulated by BaFin (Germany).';

  @override
  String get brokersTraderepublicDesc =>
      'A German neobroker-bank with a simple app and low fees; regulated as a bank in the EU.';

  @override
  String get brokersXtbDesc =>
      'A Polish broker with free stocks/ETFs up to a certain turnover and educational materials for beginners; licensed in the EU.';

  @override
  String get legalTitle => 'Legal information';

  @override
  String get legalIntro =>
      'In plain words about what Polaris can and can\'t do — no fine print.';

  @override
  String get legalSimTitle => 'Educational simulator';

  @override
  String get legalSimBody =>
      'Polaris is an educational app. The portfolio, trades and money in it are virtual: the app does not and cannot make real purchases of stocks, ETFs or anything else.';

  @override
  String get legalNoAdviceTitle => 'Not investment advice';

  @override
  String get legalNoAdviceBody =>
      'Nothing in the app — not the numbers, not Cosmo\'s comments, not the theme picks — is a personal investment recommendation, advice, or an offer to buy/sell a specific instrument. Polaris is not a licensed financial advisor and not a bank.';

  @override
  String get legalPastResultsTitle =>
      'Past performance doesn\'t guarantee the future';

  @override
  String get legalPastResultsBody =>
      'An asset\'s growth in the past (in the app or in real life) doesn\'t guarantee it will keep growing. Any investment can rise or fall in value, up to a complete loss of the money invested.';

  @override
  String get legalDelayedDataTitle => 'Data may be delayed';

  @override
  String get legalDelayedDataBody =>
      'Some quotes (non-US stocks, some securities) are updated not in real time but at end of trading day — such assets are honestly marked \"EOD\"/\"delayed\" in the catalog. Even \"live\" prices carry the usual small delay of free data sources.';

  @override
  String get legalAiTitle => 'AI mentor Cosmo is not an advisor';

  @override
  String get legalAiBody =>
      'Cosmo explains terms and comments on your practice trades in plain language, but doesn\'t pick specific securities for your situation and doesn\'t promise returns. Cosmo\'s answers can be inaccurate — like any AI — and don\'t replace consulting a licensed professional.';

  @override
  String get legalEntityTitle => 'Who makes Polaris';

  @override
  String get legalEntityBody =>
      'At the simulator stage, Polaris is a non-commercial educational project, without a banking or brokerage license and without collecting users\' real money. Legal entity information will be published here once real trading launches at the next stage.';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyIntro =>
      'In short: Polaris has no account, no name or email of yours, and doesn\'t sell data to advertisers. Below is exactly what happens with your data.';

  @override
  String get privacyLocalTitle => 'Stored on your device';

  @override
  String get privacyLocalBody =>
      'Your portfolio, lesson progress, streak and settings are stored right on your phone or computer. There\'s no account or sign-in — you play as a guest right away. You can erase everything by simply deleting the app.';

  @override
  String get privacyServerTitle => 'Sent to the server';

  @override
  String get privacyServerBody =>
      'Only this is sent to the Polaris server: (1) anonymous quote requests (ticker only, not tied to you) and (2) the text of your questions to Cosmo, along with an anonymized portfolio snapshot (tickers and shares, no name or device info). Personal data — name, email, phone number, location — is never collected or sent anywhere by the app.';

  @override
  String get privacyNoTrackersTitle => 'No third-party trackers';

  @override
  String get privacyNoTrackersBody =>
      'No ad SDKs, no third-party behavioral trackers, no data sale. Anonymous usage stats (which lessons are taken more often) exist only to improve the learning program — never used for personal investment recommendations (that\'s the EU legal boundary).';

  @override
  String get privacyRightsTitle => 'Your rights (GDPR)';

  @override
  String get privacyRightsBody =>
      'Since data never leaves your device and there\'s no account, you can delete it yourself at any moment: reset the portfolio in settings, or delete the app entirely to erase everything. There\'s no need to separately request data deletion from us — there\'s simply nothing on a server.';

  @override
  String get privacyFullPolicyLabel => 'Full privacy policy';

  @override
  String get privacyFullPolicyNote => 'opens on our website';

  @override
  String get onboardingWelcomeTitle => 'Hi, I\'m Cosmo';

  @override
  String get onboardingWelcomeBody =>
      'I\'m your mentor. I\'ll help you understand investing: explaining every step in plain words, no rush and no pressure.';

  @override
  String get onboardingMoneyTitle => '\$10,000 in virtual money';

  @override
  String get onboardingMoneyBody =>
      'Practice with real market prices — stocks, ETFs, crypto — without risking a single cent of real money.';

  @override
  String get onboardingLearnTitle => 'Learn step by step';

  @override
  String get onboardingLearnBody =>
      'Short lessons — then try them right away on your own portfolio. Ask me anything, I\'m here whenever you need me.';

  @override
  String get onboardingGoalTitle => 'Why are you here?';

  @override
  String get onboardingGoalBody =>
      'This helps me choose my words more precisely — pick whichever feels closest.';

  @override
  String get onboardingGoalSave => 'Save for the future';

  @override
  String get onboardingGoalLearn => 'Understand investing';

  @override
  String get onboardingGoalCurious => 'Just curious';

  @override
  String get onboardingDisclaimerTitle => 'Important to understand';

  @override
  String get onboardingDisclaimerBody =>
      'Polaris is an educational simulator, not investment advice. Prices may be shown with a delay and differ from the exchange. Any decisions with real money are yours alone, made thoughtfully.';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Start';

  @override
  String get homeMyPortfolio => 'My portfolio';

  @override
  String get homeLivePrices => 'live prices';

  @override
  String get homeResetTooltip => 'Start over';

  @override
  String homeFreeCash(String amount) {
    return 'Free: $amount';
  }

  @override
  String homeDividendsReceived(String amount) {
    return 'Received in dividends: $amount';
  }

  @override
  String homeSharesCount(String qty) {
    return '$qty shares';
  }

  @override
  String get homeEmptyTitle => 'Your portfolio is empty';

  @override
  String get homeEmptyBody =>
      'You have \$10,000 in virtual money to practice risk-free. Check out \"Markets\" and buy your first security — Cosmo will explain everything.';

  @override
  String get tradeNoPriceSnack => 'No current price — try again in a moment';

  @override
  String tradeBuyTitle(String symbol) {
    return 'Buy $symbol';
  }

  @override
  String tradeSellTitle(String symbol) {
    return 'Sell $symbol';
  }

  @override
  String tradePriceLabel(String price) {
    return 'Price $price per share';
  }

  @override
  String tradeFreeCash(String amount) {
    return 'Free: $amount';
  }

  @override
  String tradeYouHave(String qty, String symbol) {
    return 'You have: $qty $symbol';
  }

  @override
  String get tradeHintBuy => 'How much to invest';

  @override
  String get tradeHintSell => 'How many shares to sell';

  @override
  String tradePreviewBuy(String qty, String symbol) {
    return 'You\'ll get ≈ $qty $symbol';
  }

  @override
  String tradePreviewSell(String amount) {
    return 'You\'ll get ≈ $amount';
  }

  @override
  String get tradeAll => 'All';

  @override
  String get tradeBuyAction => 'Buy';

  @override
  String get tradeSellAction => 'Sell';

  @override
  String get tradeDisclaimer =>
      'Virtual money · this is practice, not real trading';

  @override
  String get tradeGenericError => 'Something went wrong — try again';

  @override
  String get tradeBoughtVerb => 'Bought';

  @override
  String get tradeSoldVerb => 'Sold';

  @override
  String tradeDoneSnack(String verb, String symbol) {
    return '$verb: $symbol';
  }

  @override
  String tradeCosmoComment(String comment) {
    return '🧑‍🚀 Cosmo: $comment';
  }

  @override
  String get simErrorBuyAmountPriceInvalid =>
      'Amount and price must be greater than zero';

  @override
  String get simErrorInsufficientCash => 'Not enough virtual money';

  @override
  String get simErrorAmountTooSmall => 'Amount too small for this price';

  @override
  String get simErrorSellQtyPriceInvalid =>
      'Quantity and price must be greater than zero';

  @override
  String get simErrorNoPosition => 'You don\'t hold this security';

  @override
  String get simErrorSellTooMuch =>
      'You have fewer shares than you\'re trying to sell';

  @override
  String get simErrorDividendInvalid => 'Dividend must be greater than zero';

  @override
  String get marketScreenTitle => 'Markets';

  @override
  String get marketOfflineBadge => 'demo data';

  @override
  String get marketDemoTag => 'DEMO';

  @override
  String get marketDemoNotice =>
      'Prices are simulated for learning — they are not real market data.';

  @override
  String get marketSearchHint => 'Search: ticker or name';

  @override
  String get marketThemeAll => 'All';

  @override
  String get marketSectionStocks => 'STOCKS';

  @override
  String get marketSectionEtfs => 'ETFS & BONDS';

  @override
  String get marketSectionCrypto => 'CRYPTO';

  @override
  String get marketSectionFiat => 'CURRENCIES';

  @override
  String get marketNothingFoundTitle => 'Nothing found';

  @override
  String get marketNothingFoundBody =>
      'Try a different ticker or clear the theme filter';

  @override
  String get marketTradeComingTitle => 'Trading is coming online';

  @override
  String marketTradeComingBodyBuy(String symbol) {
    return 'Soon you\'ll be able to buy $symbol with virtual money — Cosmo is already preparing the trading module.';
  }

  @override
  String marketTradeComingBodySell(String symbol) {
    return 'Soon you\'ll be able to sell $symbol with virtual money — Cosmo is already preparing the trading module.';
  }

  @override
  String get assetTypeStock => 'Stock';

  @override
  String get assetTypeEtf => 'ETF';

  @override
  String get assetTypeBondEtf => 'Bond ETF';

  @override
  String get assetTypeCrypto => 'Cryptocurrency';

  @override
  String get assetTypeFiat => 'Currency';

  @override
  String assetDescStock(String name) {
    return 'A stock is a small piece of the company \"$name\". Buying it makes you a part-owner of the business: when it grows, so does your share. But it can go the other way too, which is why stocks are considered a medium-risk asset.';
  }

  @override
  String get assetDescEtf =>
      'An ETF is a ready-made basket of dozens or hundreds of securities at once. One click and you own a slice of an entire market instead of a single company. For a beginner, it\'s the calmest way to invest.';

  @override
  String get assetDescBondEtf =>
      'A bond ETF is a basket of loans to governments and large companies. It grows slowly, but it\'s shaken around much less than stocks — a \"safety cushion\" in a portfolio.';

  @override
  String get assetDescCrypto =>
      'Cryptocurrency is digital money without banks or governments. It can rise sharply and fall just as sharply: the \"wildest\" asset class, so keep its share of your portfolio small.';

  @override
  String get assetDescFiat =>
      'An ordinary world currency. The price shown here is for 100 units in dollars. Currency rates move more calmly than stocks, but they still affect a portfolio.';

  @override
  String assetSectorLine(String sector) {
    return 'Sector: $sector.';
  }

  @override
  String get sectorTechnology =>
      'Technology — software, hardware and everything digital';

  @override
  String get sectorFinancial =>
      'Financial services — banks and payment systems';

  @override
  String get sectorHealthcare => 'Healthcare — medicine and pharmaceuticals';

  @override
  String get sectorConsumerDefensive =>
      'Everyday essentials — food, drinks, household goods';

  @override
  String get sectorConsumerCyclical =>
      'Consumer goods — \"want to have\" purchases';

  @override
  String get sectorCommunication => 'Communication and media';

  @override
  String get sectorEnergy => 'Energy — oil and gas';

  @override
  String get sectorUtilities => 'Utilities — electricity and water';

  @override
  String get sectorIndustrials => 'Industrials — factories and equipment';

  @override
  String get assetEodTag => 'EOD';

  @override
  String get assetQuoteUnavailable => 'Quote unavailable right now';

  @override
  String get assetPriceEndOfDay => 'End-of-day price';

  @override
  String get assetWhatIsThisTitle => 'What is this?';

  @override
  String get assetNoChartData => 'No data for this period';

  @override
  String get assetRange1D => '1D';

  @override
  String get assetRange1W => '1W';

  @override
  String get assetRange1M => '1M';

  @override
  String get assetRange1Y => '1Y';

  @override
  String get assetModeLine => 'Line';

  @override
  String get assetModeCandles => 'Candles';

  @override
  String get assetMetricsTitle => 'Metrics';

  @override
  String get assetMetricPrevClose => 'Previous close';

  @override
  String get assetMetricPrevCloseHint =>
      'The price trading closed at the previous day — daily change is calculated from it.';

  @override
  String get assetMetricRange => 'Range for period';

  @override
  String get assetMetricRangeHint =>
      'The lowest and highest price for the period shown on the chart.';

  @override
  String assetMetricRangeValue(String min, String max) {
    return '$min – $max';
  }

  @override
  String get assetMetricAssetClass => 'Asset class';

  @override
  String get assetMetricAssetClassHint =>
      'Which broad group of financial instruments this asset belongs to.';

  @override
  String get assetMetricCurrency => 'Quote currency';

  @override
  String get assetMetricCurrencyHint =>
      'The currency this asset\'s price is shown in.';

  @override
  String get assetMetricUpdate => 'Price update';

  @override
  String get assetMetricUpdateRealtime => 'Real time';

  @override
  String get assetMetricUpdateEod => 'Once a day (end of trading)';

  @override
  String get assetMetricUpdateHintRealtime =>
      'The price is pulled from the exchange almost instantly.';

  @override
  String get assetMetricUpdateHintEod =>
      'This asset trades on an exchange not available in real time — we update the price once a day and honestly mark it \"EOD\".';

  @override
  String get assetMetricSector => 'Sector';

  @override
  String get assetMetricSectorHint => 'The industry the company operates in.';

  @override
  String get assetSellAction => 'Sell';

  @override
  String get assetBuyAction => 'Buy';

  @override
  String get learnScreenTitle => 'Learn';

  @override
  String learnProgressLabel(String pct) {
    return '$pct% of the path completed';
  }

  @override
  String get learnGlossaryTooltip => 'Glossary';

  @override
  String get learnEmptyTitle => 'Lessons haven\'t loaded yet';

  @override
  String get learnEmptyBody =>
      'Check your connection and open the \"Learn\" tab again';

  @override
  String get learnGlossarySheetTitle => 'Glossary';

  @override
  String get learnGlossarySearchHint => 'Search a term';

  @override
  String get streakStartYours => 'Start your streak';

  @override
  String streakDaysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0 in a row';
  }

  @override
  String get streakSubtitleNone => 'Take your first lesson today';

  @override
  String get streakSubtitleDoneToday => 'Already practiced today — nice work!';

  @override
  String get streakSubtitleTodo => 'Take a lesson today to keep your streak';

  @override
  String streakLabelWithDays(String daysText) {
    return 'Streak: $daysText';
  }

  @override
  String get lessonCloseTooltip => 'Close lesson';

  @override
  String get lessonButtonDone => 'Done';

  @override
  String get lessonButtonToQuiz => 'To the quiz';

  @override
  String get lessonButtonNext => 'Next';

  @override
  String get lessonQuizHeader => 'CHECK YOURSELF';

  @override
  String get lessonButtonAnswer => 'Answer';

  @override
  String get lessonButtonNextQuestion => 'Next question';

  @override
  String get lessonButtonFinish => 'Finish lesson';

  @override
  String get lessonCompleteTitle => 'Lesson complete!';

  @override
  String lessonScore(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get lessonButtonReady => 'Done';
}
