import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ru.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ru'),
  ];

  /// No description provided for @navPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get navPortfolio;

  /// No description provided for @navMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get navMarkets;

  /// No description provided for @navCosmo.
  ///
  /// In en, this message translates to:
  /// **'Cosmo'**
  String get navCosmo;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @cancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelLabel;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get doneLabel;

  /// No description provided for @commonNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get commonNothingFound;

  /// No description provided for @resetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Start over?'**
  String get resetDialogTitle;

  /// No description provided for @resetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio will reset to the starting \$10,000. Trade history will be cleared. It\'s practice money — no worries.'**
  String get resetDialogBody;

  /// No description provided for @resetConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get resetConfirmAction;

  /// No description provided for @moreScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreScreenTitle;

  /// No description provided for @moreSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moreSettingsTitle;

  /// No description provided for @moreSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications and portfolio data'**
  String get moreSettingsSubtitle;

  /// No description provided for @moreBrokersTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready for real investing?'**
  String get moreBrokersTitle;

  /// No description provided for @moreBrokersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'EU-licensed brokers to get started'**
  String get moreBrokersSubtitle;

  /// No description provided for @moreAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get moreAboutTitle;

  /// No description provided for @moreAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Polaris, version, credits'**
  String get moreAboutSubtitle;

  /// No description provided for @morePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get morePrivacyTitle;

  /// No description provided for @morePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What data leaves the app, and where'**
  String get morePrivacySubtitle;

  /// No description provided for @moreLegalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get moreLegalTitle;

  /// No description provided for @moreLegalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimers and terms of use'**
  String get moreLegalSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic (system)'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRussian;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsNotifLesson.
  ///
  /// In en, this message translates to:
  /// **'Daily lesson & streak'**
  String get settingsNotifLesson;

  /// No description provided for @settingsNotifLessonSub.
  ///
  /// In en, this message translates to:
  /// **'Evening reminder to practice'**
  String get settingsNotifLessonSub;

  /// No description provided for @settingsNotifWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get settingsNotifWeekly;

  /// No description provided for @settingsNotifWeeklySub.
  ///
  /// In en, this message translates to:
  /// **'How your portfolio changed this week'**
  String get settingsNotifWeeklySub;

  /// No description provided for @settingsNotifDividend.
  ///
  /// In en, this message translates to:
  /// **'Dividend received'**
  String get settingsNotifDividend;

  /// No description provided for @settingsNotifDividendSub.
  ///
  /// In en, this message translates to:
  /// **'Notify when dividends are credited'**
  String get settingsNotifDividendSub;

  /// No description provided for @settingsNotifBigMoves.
  ///
  /// In en, this message translates to:
  /// **'Big price moves'**
  String get settingsNotifBigMoves;

  /// No description provided for @settingsNotifBigMovesSub.
  ///
  /// In en, this message translates to:
  /// **'±5% in a day on your holdings'**
  String get settingsNotifBigMovesSub;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataSection;

  /// No description provided for @settingsResetPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Reset portfolio'**
  String get settingsResetPortfolio;

  /// No description provided for @settingsResetPortfolioSub.
  ///
  /// In en, this message translates to:
  /// **'Restore the starting \$10,000, clear history'**
  String get settingsResetPortfolioSub;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get aboutTitle;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · investing simulator'**
  String aboutVersionLabel(String version);

  /// No description provided for @aboutWhatIsItTitle.
  ///
  /// In en, this message translates to:
  /// **'What this is'**
  String get aboutWhatIsItTitle;

  /// No description provided for @aboutWhatIsItBody.
  ///
  /// In en, this message translates to:
  /// **'Polaris is a free investing trainer for people who have never bought a stock before. A virtual \$10,000 portfolio, real live prices, honest dividends, and an AI mentor, Cosmo, who explains everything in plain words — no rush, no \"casino\" pressure.'**
  String get aboutWhatIsItBody;

  /// No description provided for @aboutSimNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'This is learning, not a stock exchange'**
  String get aboutSimNoteTitle;

  /// No description provided for @aboutSimNoteBody.
  ///
  /// In en, this message translates to:
  /// **'This is a simulator: the money in your portfolio is virtual, the app never places real trades. The \"Ready for real investing?\" section under More is an honest handoff to EU-licensed brokers, for whenever you decide to invest for real.'**
  String get aboutSimNoteBody;

  /// No description provided for @aboutMascotTitle.
  ///
  /// In en, this message translates to:
  /// **'Cosmo'**
  String get aboutMascotTitle;

  /// No description provided for @aboutMascotBody.
  ///
  /// In en, this message translates to:
  /// **'Your astronaut mentor. Cosmo doesn\'t give personal investment recommendations or promise returns — just calmly explains what\'s happening in the market and in your portfolio.'**
  String get aboutMascotBody;

  /// No description provided for @aboutDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Where the data comes from'**
  String get aboutDataTitle;

  /// No description provided for @aboutDataBody.
  ///
  /// In en, this message translates to:
  /// **'Quotes, exchange rates and charts arrive through Polaris\'s own caching server — the app never talks to third-party APIs directly. Sources are listed below.'**
  String get aboutDataBody;

  /// No description provided for @aboutThanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get aboutThanksTitle;

  /// No description provided for @aboutAttrCoinGecko.
  ///
  /// In en, this message translates to:
  /// **'Powered by CoinGecko'**
  String get aboutAttrCoinGecko;

  /// No description provided for @aboutAttrCurrency.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates: open.er-api.com'**
  String get aboutAttrCurrency;

  /// No description provided for @aboutAttrCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto tickers: Binance public API'**
  String get aboutAttrCrypto;

  /// No description provided for @aboutAttrStocks.
  ///
  /// In en, this message translates to:
  /// **'Stock quotes: Yahoo Finance (may be delayed)'**
  String get aboutAttrStocks;

  /// No description provided for @brokersTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready for real investing?'**
  String get brokersTitle;

  /// No description provided for @brokersRiskTop.
  ///
  /// In en, this message translates to:
  /// **'Investing carries the risk of losing capital. Nothing below is financial advice or a personal recommendation: Polaris is not a licensed financial advisor. Before investing real money, study the terms and risks with your chosen broker yourself.'**
  String get brokersRiskTop;

  /// No description provided for @brokersRiskBottom.
  ///
  /// In en, this message translates to:
  /// **'The list below is informational and shown in alphabetical order, not as a recommendation. We don\'t get paid for which broker you choose (phase 1). The decision is yours alone.'**
  String get brokersRiskBottom;

  /// No description provided for @brokersIntro.
  ///
  /// In en, this message translates to:
  /// **'You\'ve practiced in Polaris with a virtual \$10,000 and real live prices — a safe way to understand how it all works, with no risk to your wallet. Once you feel ready to invest real money, here are a few EU-licensed stock brokers — beginners usually find them easier to start with.'**
  String get brokersIntro;

  /// No description provided for @brokersSectionListTitle.
  ///
  /// In en, this message translates to:
  /// **'EU-licensed stock and ETF brokers'**
  String get brokersSectionListTitle;

  /// No description provided for @brokersExternalSiteNote.
  ///
  /// In en, this message translates to:
  /// **'external site'**
  String get brokersExternalSiteNote;

  /// No description provided for @brokersOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link on this device'**
  String get brokersOpenFailed;

  /// No description provided for @brokersOpenSiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Open website'**
  String get brokersOpenSiteLabel;

  /// No description provided for @brokersNoCryptoNote.
  ///
  /// In en, this message translates to:
  /// **'No crypto brokers or exchanges here — only regulated brokers for real stocks and ETFs.'**
  String get brokersNoCryptoNote;

  /// No description provided for @brokersEtoroDesc.
  ///
  /// In en, this message translates to:
  /// **'A broker with a simple mobile app and ready-made portfolio picks; regulated in the EU (Cyprus/Malta).'**
  String get brokersEtoroDesc;

  /// No description provided for @brokersIbkrDesc.
  ///
  /// In en, this message translates to:
  /// **'One of the largest brokers in the world, a huge range of markets; better suited to those ready to dig into a more detailed interface.'**
  String get brokersIbkrDesc;

  /// No description provided for @brokersLightyearDesc.
  ///
  /// In en, this message translates to:
  /// **'A young European broker with an honest interface and \"why the price changed\" explanations — closest in spirit to Polaris.'**
  String get brokersLightyearDesc;

  /// No description provided for @brokersScalableDesc.
  ///
  /// In en, this message translates to:
  /// **'A German neobroker with fractional shares and ready-made savings plans; regulated by BaFin (Germany).'**
  String get brokersScalableDesc;

  /// No description provided for @brokersTraderepublicDesc.
  ///
  /// In en, this message translates to:
  /// **'A German neobroker-bank with a simple app and low fees; regulated as a bank in the EU.'**
  String get brokersTraderepublicDesc;

  /// No description provided for @brokersXtbDesc.
  ///
  /// In en, this message translates to:
  /// **'A Polish broker with free stocks/ETFs up to a certain turnover and educational materials for beginners; licensed in the EU.'**
  String get brokersXtbDesc;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get legalTitle;

  /// No description provided for @legalIntro.
  ///
  /// In en, this message translates to:
  /// **'In plain words about what Polaris can and can\'t do — no fine print.'**
  String get legalIntro;

  /// No description provided for @legalSimTitle.
  ///
  /// In en, this message translates to:
  /// **'Educational simulator'**
  String get legalSimTitle;

  /// No description provided for @legalSimBody.
  ///
  /// In en, this message translates to:
  /// **'Polaris is an educational app. The portfolio, trades and money in it are virtual: the app does not and cannot make real purchases of stocks, ETFs or anything else.'**
  String get legalSimBody;

  /// No description provided for @legalNoAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Not investment advice'**
  String get legalNoAdviceTitle;

  /// No description provided for @legalNoAdviceBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the app — not the numbers, not Cosmo\'s comments, not the theme picks — is a personal investment recommendation, advice, or an offer to buy/sell a specific instrument. Polaris is not a licensed financial advisor and not a bank.'**
  String get legalNoAdviceBody;

  /// No description provided for @legalPastResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Past performance doesn\'t guarantee the future'**
  String get legalPastResultsTitle;

  /// No description provided for @legalPastResultsBody.
  ///
  /// In en, this message translates to:
  /// **'An asset\'s growth in the past (in the app or in real life) doesn\'t guarantee it will keep growing. Any investment can rise or fall in value, up to a complete loss of the money invested.'**
  String get legalPastResultsBody;

  /// No description provided for @legalDelayedDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data may be delayed'**
  String get legalDelayedDataTitle;

  /// No description provided for @legalDelayedDataBody.
  ///
  /// In en, this message translates to:
  /// **'Some quotes (non-US stocks, some securities) are updated not in real time but at end of trading day — such assets are honestly marked \"EOD\"/\"delayed\" in the catalog. Even \"live\" prices carry the usual small delay of free data sources.'**
  String get legalDelayedDataBody;

  /// No description provided for @legalAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI mentor Cosmo is not an advisor'**
  String get legalAiTitle;

  /// No description provided for @legalAiBody.
  ///
  /// In en, this message translates to:
  /// **'Cosmo explains terms and comments on your practice trades in plain language, but doesn\'t pick specific securities for your situation and doesn\'t promise returns. Cosmo\'s answers can be inaccurate — like any AI — and don\'t replace consulting a licensed professional.'**
  String get legalAiBody;

  /// No description provided for @legalEntityTitle.
  ///
  /// In en, this message translates to:
  /// **'Who makes Polaris'**
  String get legalEntityTitle;

  /// No description provided for @legalEntityBody.
  ///
  /// In en, this message translates to:
  /// **'At the simulator stage, Polaris is a non-commercial educational project, without a banking or brokerage license and without collecting users\' real money. Legal entity information will be published here once real trading launches at the next stage.'**
  String get legalEntityBody;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'In short: Polaris has no account, no name or email of yours, and doesn\'t sell data to advertisers. Below is exactly what happens with your data.'**
  String get privacyIntro;

  /// No description provided for @privacyLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Stored on your device'**
  String get privacyLocalTitle;

  /// No description provided for @privacyLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio, lesson progress, streak and settings are stored right on your phone or computer. There\'s no account or sign-in — you play as a guest right away. You can erase everything by simply deleting the app.'**
  String get privacyLocalBody;

  /// No description provided for @privacyServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent to the server'**
  String get privacyServerTitle;

  /// No description provided for @privacyServerBody.
  ///
  /// In en, this message translates to:
  /// **'Only this is sent to the Polaris server: (1) anonymous quote requests (ticker only, not tied to you) and (2) the text of your questions to Cosmo, along with an anonymized portfolio snapshot (tickers and shares, no name or device info). Personal data — name, email, phone number, location — is never collected or sent anywhere by the app.'**
  String get privacyServerBody;

  /// No description provided for @privacyNoTrackersTitle.
  ///
  /// In en, this message translates to:
  /// **'No third-party trackers'**
  String get privacyNoTrackersTitle;

  /// No description provided for @privacyNoTrackersBody.
  ///
  /// In en, this message translates to:
  /// **'No ad SDKs, no third-party behavioral trackers, no data sale. Anonymous usage stats (which lessons are taken more often) exist only to improve the learning program — never used for personal investment recommendations (that\'s the EU legal boundary).'**
  String get privacyNoTrackersBody;

  /// No description provided for @privacyRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rights (GDPR)'**
  String get privacyRightsTitle;

  /// No description provided for @privacyRightsBody.
  ///
  /// In en, this message translates to:
  /// **'Since data never leaves your device and there\'s no account, you can delete it yourself at any moment: reset the portfolio in settings, or delete the app entirely to erase everything. There\'s no need to separately request data deletion from us — there\'s simply nothing on a server.'**
  String get privacyRightsBody;

  /// No description provided for @privacyFullPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Full privacy policy'**
  String get privacyFullPolicyLabel;

  /// No description provided for @privacyFullPolicyNote.
  ///
  /// In en, this message translates to:
  /// **'opens on our website'**
  String get privacyFullPolicyNote;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m Cosmo'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'I\'m your mentor. I\'ll help you understand investing: explaining every step in plain words, no rush and no pressure.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'\$10,000 in virtual money'**
  String get onboardingMoneyTitle;

  /// No description provided for @onboardingMoneyBody.
  ///
  /// In en, this message translates to:
  /// **'Practice with real market prices — stocks, ETFs, crypto — without risking a single cent of real money.'**
  String get onboardingMoneyBody;

  /// No description provided for @onboardingLearnTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn step by step'**
  String get onboardingLearnTitle;

  /// No description provided for @onboardingLearnBody.
  ///
  /// In en, this message translates to:
  /// **'Short lessons — then try them right away on your own portfolio. Ask me anything, I\'m here whenever you need me.'**
  String get onboardingLearnBody;

  /// No description provided for @onboardingGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you here?'**
  String get onboardingGoalTitle;

  /// No description provided for @onboardingGoalBody.
  ///
  /// In en, this message translates to:
  /// **'This helps me choose my words more precisely — pick whichever feels closest.'**
  String get onboardingGoalBody;

  /// No description provided for @onboardingGoalSave.
  ///
  /// In en, this message translates to:
  /// **'Save for the future'**
  String get onboardingGoalSave;

  /// No description provided for @onboardingGoalLearn.
  ///
  /// In en, this message translates to:
  /// **'Understand investing'**
  String get onboardingGoalLearn;

  /// No description provided for @onboardingGoalCurious.
  ///
  /// In en, this message translates to:
  /// **'Just curious'**
  String get onboardingGoalCurious;

  /// No description provided for @onboardingDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Important to understand'**
  String get onboardingDisclaimerTitle;

  /// No description provided for @onboardingDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Polaris is an educational simulator, not investment advice. Prices may be shown with a delay and differ from the exchange. Any decisions with real money are yours alone, made thoughtfully.'**
  String get onboardingDisclaimerBody;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// No description provided for @homeMyPortfolio.
  ///
  /// In en, this message translates to:
  /// **'My portfolio'**
  String get homeMyPortfolio;

  /// No description provided for @homeLivePrices.
  ///
  /// In en, this message translates to:
  /// **'live prices'**
  String get homeLivePrices;

  /// No description provided for @homeResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get homeResetTooltip;

  /// No description provided for @homeFreeCash.
  ///
  /// In en, this message translates to:
  /// **'Free: {amount}'**
  String homeFreeCash(String amount);

  /// No description provided for @homeDividendsReceived.
  ///
  /// In en, this message translates to:
  /// **'Received in dividends: {amount}'**
  String homeDividendsReceived(String amount);

  /// No description provided for @homeSharesCount.
  ///
  /// In en, this message translates to:
  /// **'{qty} shares'**
  String homeSharesCount(String qty);

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your portfolio is empty'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You have \$10,000 in virtual money to practice risk-free. Check out \"Markets\" and buy your first security — Cosmo will explain everything.'**
  String get homeEmptyBody;

  /// No description provided for @tradeNoPriceSnack.
  ///
  /// In en, this message translates to:
  /// **'No current price — try again in a moment'**
  String get tradeNoPriceSnack;

  /// No description provided for @tradeBuyTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy {symbol}'**
  String tradeBuyTitle(String symbol);

  /// No description provided for @tradeSellTitle.
  ///
  /// In en, this message translates to:
  /// **'Sell {symbol}'**
  String tradeSellTitle(String symbol);

  /// No description provided for @tradePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price {price} per share'**
  String tradePriceLabel(String price);

  /// No description provided for @tradeFreeCash.
  ///
  /// In en, this message translates to:
  /// **'Free: {amount}'**
  String tradeFreeCash(String amount);

  /// No description provided for @tradeYouHave.
  ///
  /// In en, this message translates to:
  /// **'You have: {qty} {symbol}'**
  String tradeYouHave(String qty, String symbol);

  /// No description provided for @tradeHintBuy.
  ///
  /// In en, this message translates to:
  /// **'How much to invest'**
  String get tradeHintBuy;

  /// No description provided for @tradeHintSell.
  ///
  /// In en, this message translates to:
  /// **'How many shares to sell'**
  String get tradeHintSell;

  /// No description provided for @tradePreviewBuy.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get ≈ {qty} {symbol}'**
  String tradePreviewBuy(String qty, String symbol);

  /// No description provided for @tradePreviewSell.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get ≈ {amount}'**
  String tradePreviewSell(String amount);

  /// No description provided for @tradeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tradeAll;

  /// No description provided for @tradeBuyAction.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get tradeBuyAction;

  /// No description provided for @tradeSellAction.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get tradeSellAction;

  /// No description provided for @tradeDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Virtual money · this is practice, not real trading'**
  String get tradeDisclaimer;

  /// No description provided for @tradeGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — try again'**
  String get tradeGenericError;

  /// No description provided for @tradeBoughtVerb.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get tradeBoughtVerb;

  /// No description provided for @tradeSoldVerb.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get tradeSoldVerb;

  /// No description provided for @tradeDoneSnack.
  ///
  /// In en, this message translates to:
  /// **'{verb}: {symbol}'**
  String tradeDoneSnack(String verb, String symbol);

  /// No description provided for @tradeCosmoComment.
  ///
  /// In en, this message translates to:
  /// **'🧑‍🚀 Cosmo: {comment}'**
  String tradeCosmoComment(String comment);

  /// No description provided for @simErrorBuyAmountPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Amount and price must be greater than zero'**
  String get simErrorBuyAmountPriceInvalid;

  /// No description provided for @simErrorInsufficientCash.
  ///
  /// In en, this message translates to:
  /// **'Not enough virtual money'**
  String get simErrorInsufficientCash;

  /// No description provided for @simErrorAmountTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Amount too small for this price'**
  String get simErrorAmountTooSmall;

  /// No description provided for @simErrorSellQtyPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Quantity and price must be greater than zero'**
  String get simErrorSellQtyPriceInvalid;

  /// No description provided for @simErrorNoPosition.
  ///
  /// In en, this message translates to:
  /// **'You don\'t hold this security'**
  String get simErrorNoPosition;

  /// No description provided for @simErrorSellTooMuch.
  ///
  /// In en, this message translates to:
  /// **'You have fewer shares than you\'re trying to sell'**
  String get simErrorSellTooMuch;

  /// No description provided for @simErrorDividendInvalid.
  ///
  /// In en, this message translates to:
  /// **'Dividend must be greater than zero'**
  String get simErrorDividendInvalid;

  /// No description provided for @marketScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get marketScreenTitle;

  /// No description provided for @marketOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'demo data'**
  String get marketOfflineBadge;

  /// No description provided for @marketSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search: ticker or name'**
  String get marketSearchHint;

  /// No description provided for @marketThemeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get marketThemeAll;

  /// No description provided for @marketSectionStocks.
  ///
  /// In en, this message translates to:
  /// **'STOCKS'**
  String get marketSectionStocks;

  /// No description provided for @marketSectionEtfs.
  ///
  /// In en, this message translates to:
  /// **'ETFS & BONDS'**
  String get marketSectionEtfs;

  /// No description provided for @marketSectionCrypto.
  ///
  /// In en, this message translates to:
  /// **'CRYPTO'**
  String get marketSectionCrypto;

  /// No description provided for @marketSectionFiat.
  ///
  /// In en, this message translates to:
  /// **'CURRENCIES'**
  String get marketSectionFiat;

  /// No description provided for @marketNothingFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get marketNothingFoundTitle;

  /// No description provided for @marketNothingFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different ticker or clear the theme filter'**
  String get marketNothingFoundBody;

  /// No description provided for @marketTradeComingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trading is coming online'**
  String get marketTradeComingTitle;

  /// No description provided for @marketTradeComingBodyBuy.
  ///
  /// In en, this message translates to:
  /// **'Soon you\'ll be able to buy {symbol} with virtual money — Cosmo is already preparing the trading module.'**
  String marketTradeComingBodyBuy(String symbol);

  /// No description provided for @marketTradeComingBodySell.
  ///
  /// In en, this message translates to:
  /// **'Soon you\'ll be able to sell {symbol} with virtual money — Cosmo is already preparing the trading module.'**
  String marketTradeComingBodySell(String symbol);

  /// No description provided for @assetTypeStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get assetTypeStock;

  /// No description provided for @assetTypeEtf.
  ///
  /// In en, this message translates to:
  /// **'ETF'**
  String get assetTypeEtf;

  /// No description provided for @assetTypeBondEtf.
  ///
  /// In en, this message translates to:
  /// **'Bond ETF'**
  String get assetTypeBondEtf;

  /// No description provided for @assetTypeCrypto.
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrency'**
  String get assetTypeCrypto;

  /// No description provided for @assetTypeFiat.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get assetTypeFiat;

  /// No description provided for @assetDescStock.
  ///
  /// In en, this message translates to:
  /// **'A stock is a small piece of the company \"{name}\". Buying it makes you a part-owner of the business: when it grows, so does your share. But it can go the other way too, which is why stocks are considered a medium-risk asset.'**
  String assetDescStock(String name);

  /// No description provided for @assetDescEtf.
  ///
  /// In en, this message translates to:
  /// **'An ETF is a ready-made basket of dozens or hundreds of securities at once. One click and you own a slice of an entire market instead of a single company. For a beginner, it\'s the calmest way to invest.'**
  String get assetDescEtf;

  /// No description provided for @assetDescBondEtf.
  ///
  /// In en, this message translates to:
  /// **'A bond ETF is a basket of loans to governments and large companies. It grows slowly, but it\'s shaken around much less than stocks — a \"safety cushion\" in a portfolio.'**
  String get assetDescBondEtf;

  /// No description provided for @assetDescCrypto.
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrency is digital money without banks or governments. It can rise sharply and fall just as sharply: the \"wildest\" asset class, so keep its share of your portfolio small.'**
  String get assetDescCrypto;

  /// No description provided for @assetDescFiat.
  ///
  /// In en, this message translates to:
  /// **'An ordinary world currency. The price shown here is for 100 units in dollars. Currency rates move more calmly than stocks, but they still affect a portfolio.'**
  String get assetDescFiat;

  /// No description provided for @assetSectorLine.
  ///
  /// In en, this message translates to:
  /// **'Sector: {sector}.'**
  String assetSectorLine(String sector);

  /// No description provided for @sectorTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology — software, hardware and everything digital'**
  String get sectorTechnology;

  /// No description provided for @sectorFinancial.
  ///
  /// In en, this message translates to:
  /// **'Financial services — banks and payment systems'**
  String get sectorFinancial;

  /// No description provided for @sectorHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare — medicine and pharmaceuticals'**
  String get sectorHealthcare;

  /// No description provided for @sectorConsumerDefensive.
  ///
  /// In en, this message translates to:
  /// **'Everyday essentials — food, drinks, household goods'**
  String get sectorConsumerDefensive;

  /// No description provided for @sectorConsumerCyclical.
  ///
  /// In en, this message translates to:
  /// **'Consumer goods — \"want to have\" purchases'**
  String get sectorConsumerCyclical;

  /// No description provided for @sectorCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication and media'**
  String get sectorCommunication;

  /// No description provided for @sectorEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy — oil and gas'**
  String get sectorEnergy;

  /// No description provided for @sectorUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities — electricity and water'**
  String get sectorUtilities;

  /// No description provided for @sectorIndustrials.
  ///
  /// In en, this message translates to:
  /// **'Industrials — factories and equipment'**
  String get sectorIndustrials;

  /// No description provided for @assetEodTag.
  ///
  /// In en, this message translates to:
  /// **'EOD'**
  String get assetEodTag;

  /// No description provided for @assetQuoteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Quote unavailable right now'**
  String get assetQuoteUnavailable;

  /// No description provided for @assetPriceEndOfDay.
  ///
  /// In en, this message translates to:
  /// **'End-of-day price'**
  String get assetPriceEndOfDay;

  /// No description provided for @assetWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What is this?'**
  String get assetWhatIsThisTitle;

  /// No description provided for @assetNoChartData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get assetNoChartData;

  /// No description provided for @assetRange1D.
  ///
  /// In en, this message translates to:
  /// **'1D'**
  String get assetRange1D;

  /// No description provided for @assetRange1W.
  ///
  /// In en, this message translates to:
  /// **'1W'**
  String get assetRange1W;

  /// No description provided for @assetRange1M.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get assetRange1M;

  /// No description provided for @assetRange1Y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get assetRange1Y;

  /// No description provided for @assetModeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get assetModeLine;

  /// No description provided for @assetModeCandles.
  ///
  /// In en, this message translates to:
  /// **'Candles'**
  String get assetModeCandles;

  /// No description provided for @assetMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get assetMetricsTitle;

  /// No description provided for @assetMetricPrevClose.
  ///
  /// In en, this message translates to:
  /// **'Previous close'**
  String get assetMetricPrevClose;

  /// No description provided for @assetMetricPrevCloseHint.
  ///
  /// In en, this message translates to:
  /// **'The price trading closed at the previous day — daily change is calculated from it.'**
  String get assetMetricPrevCloseHint;

  /// No description provided for @assetMetricRange.
  ///
  /// In en, this message translates to:
  /// **'Range for period'**
  String get assetMetricRange;

  /// No description provided for @assetMetricRangeHint.
  ///
  /// In en, this message translates to:
  /// **'The lowest and highest price for the period shown on the chart.'**
  String get assetMetricRangeHint;

  /// No description provided for @assetMetricRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String assetMetricRangeValue(String min, String max);

  /// No description provided for @assetMetricAssetClass.
  ///
  /// In en, this message translates to:
  /// **'Asset class'**
  String get assetMetricAssetClass;

  /// No description provided for @assetMetricAssetClassHint.
  ///
  /// In en, this message translates to:
  /// **'Which broad group of financial instruments this asset belongs to.'**
  String get assetMetricAssetClassHint;

  /// No description provided for @assetMetricCurrency.
  ///
  /// In en, this message translates to:
  /// **'Quote currency'**
  String get assetMetricCurrency;

  /// No description provided for @assetMetricCurrencyHint.
  ///
  /// In en, this message translates to:
  /// **'The currency this asset\'s price is shown in.'**
  String get assetMetricCurrencyHint;

  /// No description provided for @assetMetricUpdate.
  ///
  /// In en, this message translates to:
  /// **'Price update'**
  String get assetMetricUpdate;

  /// No description provided for @assetMetricUpdateRealtime.
  ///
  /// In en, this message translates to:
  /// **'Real time'**
  String get assetMetricUpdateRealtime;

  /// No description provided for @assetMetricUpdateEod.
  ///
  /// In en, this message translates to:
  /// **'Once a day (end of trading)'**
  String get assetMetricUpdateEod;

  /// No description provided for @assetMetricUpdateHintRealtime.
  ///
  /// In en, this message translates to:
  /// **'The price is pulled from the exchange almost instantly.'**
  String get assetMetricUpdateHintRealtime;

  /// No description provided for @assetMetricUpdateHintEod.
  ///
  /// In en, this message translates to:
  /// **'This asset trades on an exchange not available in real time — we update the price once a day and honestly mark it \"EOD\".'**
  String get assetMetricUpdateHintEod;

  /// No description provided for @assetMetricSector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get assetMetricSector;

  /// No description provided for @assetMetricSectorHint.
  ///
  /// In en, this message translates to:
  /// **'The industry the company operates in.'**
  String get assetMetricSectorHint;

  /// No description provided for @assetSellAction.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get assetSellAction;

  /// No description provided for @assetBuyAction.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get assetBuyAction;

  /// No description provided for @learnScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learnScreenTitle;

  /// No description provided for @learnProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of the path completed'**
  String learnProgressLabel(String pct);

  /// No description provided for @learnGlossaryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get learnGlossaryTooltip;

  /// No description provided for @learnEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Lessons haven\'t loaded yet'**
  String get learnEmptyTitle;

  /// No description provided for @learnEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and open the \"Learn\" tab again'**
  String get learnEmptyBody;

  /// No description provided for @learnGlossarySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Glossary'**
  String get learnGlossarySheetTitle;

  /// No description provided for @learnGlossarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a term'**
  String get learnGlossarySearchHint;

  /// No description provided for @streakStartYours.
  ///
  /// In en, this message translates to:
  /// **'Start your streak'**
  String get streakStartYours;

  /// No description provided for @streakDaysInARow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} day} other{{count} days}} in a row'**
  String streakDaysInARow(int count);

  /// No description provided for @streakSubtitleNone.
  ///
  /// In en, this message translates to:
  /// **'Take your first lesson today'**
  String get streakSubtitleNone;

  /// No description provided for @streakSubtitleDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Already practiced today — nice work!'**
  String get streakSubtitleDoneToday;

  /// No description provided for @streakSubtitleTodo.
  ///
  /// In en, this message translates to:
  /// **'Take a lesson today to keep your streak'**
  String get streakSubtitleTodo;

  /// No description provided for @streakLabelWithDays.
  ///
  /// In en, this message translates to:
  /// **'Streak: {daysText}'**
  String streakLabelWithDays(String daysText);

  /// No description provided for @lessonCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close lesson'**
  String get lessonCloseTooltip;

  /// No description provided for @lessonButtonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lessonButtonDone;

  /// No description provided for @lessonButtonToQuiz.
  ///
  /// In en, this message translates to:
  /// **'To the quiz'**
  String get lessonButtonToQuiz;

  /// No description provided for @lessonButtonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get lessonButtonNext;

  /// No description provided for @lessonQuizHeader.
  ///
  /// In en, this message translates to:
  /// **'CHECK YOURSELF'**
  String get lessonQuizHeader;

  /// No description provided for @lessonButtonAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get lessonButtonAnswer;

  /// No description provided for @lessonButtonNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get lessonButtonNextQuestion;

  /// No description provided for @lessonButtonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish lesson'**
  String get lessonButtonFinish;

  /// No description provided for @lessonCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson complete!'**
  String get lessonCompleteTitle;

  /// No description provided for @lessonScore.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String lessonScore(int correct, int total);

  /// No description provided for @lessonButtonReady.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get lessonButtonReady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
