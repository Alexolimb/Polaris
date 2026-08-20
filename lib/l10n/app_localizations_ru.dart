// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navPortfolio => 'Портфель';

  @override
  String get navMarkets => 'Рынки';

  @override
  String get navCosmo => 'Cosmo';

  @override
  String get navLearn => 'Учёба';

  @override
  String get navMore => 'Ещё';

  @override
  String get cancelLabel => 'Отмена';

  @override
  String get doneLabel => 'Понятно';

  @override
  String get commonNothingFound => 'Ничего не нашлось';

  @override
  String get resetDialogTitle => 'Начать заново?';

  @override
  String get resetDialogBody =>
      'Портфель обнулится и вернутся стартовые \$10 000. История сделок сотрётся. Это тренировочные деньги — ничего страшного.';

  @override
  String get resetConfirmAction => 'Начать заново';

  @override
  String get moreScreenTitle => 'Ещё';

  @override
  String get moreSettingsTitle => 'Настройки';

  @override
  String get moreSettingsSubtitle => 'Уведомления и данные портфеля';

  @override
  String get moreBrokersTitle => 'Готов к настоящим инвестициям?';

  @override
  String get moreBrokersSubtitle => 'Лицензированные в ЕС брокеры для старта';

  @override
  String get moreAboutTitle => 'О приложении';

  @override
  String get moreAboutSubtitle => 'Polaris, версия, благодарности';

  @override
  String get morePrivacyTitle => 'Конфиденциальность';

  @override
  String get morePrivacySubtitle => 'Что и куда уходит из приложения';

  @override
  String get moreLegalTitle => 'Правовая информация';

  @override
  String get moreLegalSubtitle => 'Дисклеймеры и условия использования';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguageSection => 'Язык';

  @override
  String get settingsLanguageAuto => 'Авто (по системе)';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsNotificationsSection => 'Уведомления';

  @override
  String get settingsNotifLesson => 'Урок дня и стрик';

  @override
  String get settingsNotifLessonSub => 'Напоминание позаниматься вечером';

  @override
  String get settingsNotifWeekly => 'Недельная сводка';

  @override
  String get settingsNotifWeeklySub => 'Как изменился портфель за неделю';

  @override
  String get settingsNotifDividend => 'Дивиденд пришёл';

  @override
  String get settingsNotifDividendSub => 'Уведомление о начисленных дивидендах';

  @override
  String get settingsNotifBigMoves => 'Крупные движения цены';

  @override
  String get settingsNotifBigMovesSub => '±5% за день по бумагам в портфеле';

  @override
  String get settingsDataSection => 'Данные';

  @override
  String get settingsResetPortfolio => 'Сбросить портфель';

  @override
  String get settingsResetPortfolioSub =>
      'Вернуть стартовые \$10 000, стереть историю';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String aboutVersionLabel(String version) {
    return 'Версия $version · симулятор инвестиций';
  }

  @override
  String get aboutWhatIsItTitle => 'Что это';

  @override
  String get aboutWhatIsItBody =>
      'Polaris — бесплатный тренажёр инвестиций для тех, кто раньше никогда не покупал акции. Виртуальный портфель \$10 000, смоделированные рыночные цены, дивиденды по настоящему календарю и AI-наставник Cosmo, который объясняет всё простыми словами — без спешки и без «казино».';

  @override
  String get aboutSimNoteTitle => 'Это обучение, не биржа';

  @override
  String get aboutSimNoteBody =>
      'Это симулятор: деньги в портфеле виртуальные, реальные сделки приложение не совершает. Раздел «Готов к настоящим инвестициям?» во вкладке «Ещё» — честный переход к лицензированным в ЕС брокерам, когда решишь инвестировать по-настоящему.';

  @override
  String get aboutMascotTitle => 'Cosmo';

  @override
  String get aboutMascotBody =>
      'Твой наставник-астронавт. Cosmo не даёт персональных инвестиционных рекомендаций и не обещает доходность — только спокойно объясняет, что происходит с рынком и с твоим портфелем.';

  @override
  String get aboutDataTitle => 'Откуда данные';

  @override
  String get aboutDataBody =>
      'Цены и графики генерирует собственный сервер Polaris: они ведут себя как настоящий рынок, но они смоделированы и не являются биржевыми данными. Никакие чужие биржевые источники приложение не использует.';

  @override
  String get aboutThanksTitle => 'Благодарности';

  @override
  String get aboutAttrCoinGecko => 'Powered by CoinGecko';

  @override
  String get aboutAttrCurrency => 'Курсы валют: open.er-api.com';

  @override
  String get aboutAttrCrypto => 'Крипто-тикеры: Binance public API';

  @override
  String get aboutAttrStocks =>
      'Котировки акций: Yahoo Finance (может задерживаться)';

  @override
  String get brokersTitle => 'Готов к настоящим инвестициям?';

  @override
  String get brokersRiskTop =>
      'Инвестиции связаны с риском потери капитала. Всё ниже — не финансовая консультация и не персональная рекомендация: Polaris не является лицензированным финансовым консультантом. Перед тем как вкладывать настоящие деньги, изучи условия и риски у выбранного брокера сам.';

  @override
  String get brokersRiskBottom =>
      'Список ниже — информационный и приведён в алфавитном порядке, а не по рекомендации. Мы не получаем деньги за то, какого брокера ты выберешь (этап 1). Решение — только твоё.';

  @override
  String get brokersIntro =>
      'Ты потренировался в Polaris на виртуальных \$10 000 и настоящих живых ценах — это был безопасный способ понять, как всё устроено, без риска для кошелька. Когда почувствуешь, что готов инвестировать реальные деньги, вот несколько брокеров акций, лицензированных в Евросоюзе — у них новичкам обычно проще начать.';

  @override
  String get brokersSectionListTitle =>
      'Брокеры акций и ETF, лицензированные в ЕС';

  @override
  String get brokersExternalSiteNote => 'внешний сайт';

  @override
  String get brokersOpenFailed =>
      'Не удалось открыть ссылку на этом устройстве';

  @override
  String get brokersOpenSiteLabel => 'Открыть сайт';

  @override
  String get brokersNoCryptoNote =>
      'Здесь нет криптоброкеров и криптообменников — только регулируемые брокеры настоящих акций и ETF.';

  @override
  String get brokersEtoroDesc =>
      'Брокер с простым мобильным приложением и готовыми подборками портфелей; регулируется в ЕС (Кипр/Мальта).';

  @override
  String get brokersIbkrDesc =>
      'Один из крупнейших брокеров в мире, огромный выбор рынков; больше подходит тем, кто готов разобраться в интерфейсе подробнее.';

  @override
  String get brokersLightyearDesc =>
      'Молодой европейский брокер с честным интерфейсом и объяснениями «почему цена изменилась» — по духу ближе всего к Polaris.';

  @override
  String get brokersScalableDesc =>
      'Немецкий необрокер с дробными акциями и готовыми сберегательными планами; регулируется BaFin (Германия).';

  @override
  String get brokersTraderepublicDesc =>
      'Немецкий необрокер-банк с простым приложением и низкими комиссиями; регулируется как банк в ЕС.';

  @override
  String get brokersXtbDesc =>
      'Польский брокер с бесплатными акциями/ETF до определённого оборота и обучающими материалами для новичков; лицензирован в ЕС.';

  @override
  String get legalTitle => 'Правовая информация';

  @override
  String get legalIntro =>
      'Простыми словами о том, что Polaris может и не может, — без мелкого шрифта.';

  @override
  String get legalSimTitle => 'Образовательный симулятор';

  @override
  String get legalSimBody =>
      'Polaris — обучающее приложение. Портфель, сделки и деньги в нём виртуальные: реальные покупки акций, ETF или чего-либо ещё приложение не совершает и не может совершать.';

  @override
  String get legalNoAdviceTitle => 'Не инвестиционная рекомендация';

  @override
  String get legalNoAdviceBody =>
      'Ничего в приложении — ни цифры, ни комментарии Cosmo, ни подборки тем — не является персональной инвестиционной рекомендацией, консультацией или предложением купить/продать конкретный инструмент. Polaris не лицензированный финансовый консультант и не банк.';

  @override
  String get legalPastResultsTitle => 'Прошлое не гарантирует будущего';

  @override
  String get legalPastResultsBody =>
      'Рост актива в прошлом (в приложении или в жизни) не гарантирует, что он вырастет и дальше. Любые инвестиции могут как расти, так и падать в цене, вплоть до полной потери вложенных денег.';

  @override
  String get legalDelayedDataTitle => 'Данные могут задерживаться';

  @override
  String get legalDelayedDataBody =>
      'Часть котировок (мировые акции вне США, некоторые бумаги) обновляется не в реальном времени, а на конец торгового дня — такие активы честно помечены в каталоге меткой «EOD»/«задержка». Даже «живые» цены — с обычной для бесплатных источников небольшой задержкой.';

  @override
  String get legalAiTitle => 'AI-наставник Cosmo — не советник';

  @override
  String get legalAiBody =>
      'Cosmo объясняет термины и комментирует твои учебные сделки простым языком, но не подбирает тебе конкретные бумаги под твою ситуацию и не обещает доходность. Ответы Cosmo могут быть неточными — как у любого AI — и не заменяют консультацию у лицензированного специалиста.';

  @override
  String get legalEntityTitle => 'Кто делает Polaris';

  @override
  String get legalEntityBody =>
      'На этапе симулятора Polaris — некоммерческий образовательный проект, без банковской или брокерской лицензии и без сбора реальных денег пользователей. Информация о юридическом лице публикуется здесь при запуске реальной торговли на следующем этапе.';

  @override
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyIntro =>
      'Коротко: у Polaris нет аккаунта, нет твоего имени и почты, нет продажи данных рекламодателям. Ниже — что именно происходит с данными.';

  @override
  String get privacyLocalTitle => 'Хранится на устройстве';

  @override
  String get privacyLocalBody =>
      'Портфель, прогресс в уроках, стрик и настройки хранятся прямо на телефоне или компьютере. Аккаунта и входа нет — гость играет сразу. Удалить всё можно, просто удалив приложение.';

  @override
  String get privacyServerTitle => 'Уходит на сервер';

  @override
  String get privacyServerBody =>
      'На сервер Polaris уходят только: (1) анонимные запросы котировок (тикер, без привязки к тебе) и (2) текст твоих вопросов Cosmo вместе с обезличенным снимком портфеля (тикеры и доли, без имени и без устройства). Личные данные — имя, почта, номер телефона, геолокация — приложение не собирает и никуда не отправляет.';

  @override
  String get privacyNoTrackersTitle => 'Никаких трекеров третьих лиц';

  @override
  String get privacyNoTrackersBody =>
      'Рекламных SDK, трекеров поведения сторонних компаний и продажи данных нет. Анонимная статистика использования (какие уроки проходят чаще) нужна только для того, чтобы улучшать программу обучения — без персональных инвестиционных рекомендаций по ней (юридическая граница ЕС).';

  @override
  String get privacyRightsTitle => 'Твои права (GDPR)';

  @override
  String get privacyRightsBody =>
      'Раз данные не покидают устройство и нет аккаунта — удалить их можно в любой момент самому: сброс портфеля в настройках или полное удаление приложения стирает всё. Отдельно запрашивать удаление данных у нас не нужно — их просто нет на сервере.';

  @override
  String get privacyFullPolicyLabel =>
      'Полный текст политики конфиденциальности';

  @override
  String get privacyFullPolicyNote => 'откроется на нашем сайте';

  @override
  String get onboardingWelcomeTitle => 'Привет, я Cosmo';

  @override
  String get onboardingWelcomeBody =>
      'Я — твой наставник. Помогу разобраться в инвестициях: объясню каждый шаг простыми словами, без спешки и без давления.';

  @override
  String get onboardingMoneyTitle => '\$10 000 виртуальных денег';

  @override
  String get onboardingMoneyBody =>
      'Тренируйся на настоящих ценах рынка — акции, ETF, крипта — не рискуя ни центом реальных денег.';

  @override
  String get onboardingLearnTitle => 'Учись по шагам';

  @override
  String get onboardingLearnBody =>
      'Короткие уроки — и сразу пробуешь на своём портфеле. Спрашивай меня о чём угодно, я рядом в любой момент.';

  @override
  String get onboardingGoalTitle => 'Зачем ты здесь?';

  @override
  String get onboardingGoalBody =>
      'Это поможет мне точнее подбирать слова — выбери, что ближе.';

  @override
  String get onboardingGoalSave => 'Накопить на будущее';

  @override
  String get onboardingGoalLearn => 'Разобраться в инвестициях';

  @override
  String get onboardingGoalCurious => 'Просто любопытно';

  @override
  String get onboardingDisclaimerTitle => 'Важно понимать';

  @override
  String get onboardingDisclaimerBody =>
      'Polaris — обучающий симулятор, а не инвестиционная рекомендация. Цены могут показываться с задержкой и отличаться от биржи. Любые решения с настоящими деньгами — только твои, взвешенно.';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';

  @override
  String get homeMyPortfolio => 'Мой портфель';

  @override
  String get homeLivePrices => 'живые цены';

  @override
  String get homeResetTooltip => 'Начать заново';

  @override
  String homeFreeCash(String amount) {
    return 'Свободно: $amount';
  }

  @override
  String homeDividendsReceived(String amount) {
    return 'Дивидендами получено: $amount';
  }

  @override
  String homeSharesCount(String qty) {
    return '$qty шт';
  }

  @override
  String get homeEmptyTitle => 'Портфель пока пуст';

  @override
  String get homeEmptyBody =>
      'У тебя есть \$10 000 виртуальных денег, чтобы потренироваться без риска. Загляни в «Рынки» и купи первую бумагу — Cosmo всё объяснит.';

  @override
  String get tradeNoPriceSnack => 'Нет актуальной цены — попробуй чуть позже';

  @override
  String tradeBuyTitle(String symbol) {
    return 'Купить $symbol';
  }

  @override
  String tradeSellTitle(String symbol) {
    return 'Продать $symbol';
  }

  @override
  String tradePriceLabel(String price) {
    return 'Цена $price за штуку';
  }

  @override
  String tradeFreeCash(String amount) {
    return 'Свободно: $amount';
  }

  @override
  String tradeYouHave(String qty, String symbol) {
    return 'У тебя: $qty $symbol';
  }

  @override
  String get tradeHintBuy => 'Сколько вложить';

  @override
  String get tradeHintSell => 'Сколько штук продать';

  @override
  String tradePreviewBuy(String qty, String symbol) {
    return 'Получишь ≈ $qty $symbol';
  }

  @override
  String tradePreviewSell(String amount) {
    return 'Получишь ≈ $amount';
  }

  @override
  String get tradeAll => 'Всё';

  @override
  String get tradeBuyAction => 'Купить';

  @override
  String get tradeSellAction => 'Продать';

  @override
  String get tradeDisclaimer =>
      'Виртуальные деньги · это тренировка, не реальная торговля';

  @override
  String get tradeGenericError => 'Не получилось — попробуй ещё раз';

  @override
  String get tradeBoughtVerb => 'Куплено';

  @override
  String get tradeSoldVerb => 'Продано';

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
      'Сумма и цена должны быть больше нуля';

  @override
  String get simErrorInsufficientCash => 'Не хватает виртуальных денег';

  @override
  String get simErrorAmountTooSmall => 'Слишком маленькая сумма для этой цены';

  @override
  String get simErrorSellQtyPriceInvalid =>
      'Количество и цена должны быть больше нуля';

  @override
  String get simErrorNoPosition => 'Такой бумаги в портфеле нет';

  @override
  String get simErrorSellTooMuch => 'В портфеле меньше, чем продаёшь';

  @override
  String get simErrorDividendInvalid => 'Дивиденд должен быть больше нуля';

  @override
  String get marketScreenTitle => 'Рынки';

  @override
  String get marketOfflineBadge => 'демо-данные';

  @override
  String get marketDemoTag => 'ДЕМО';

  @override
  String get homeEmptyCta => 'Открыть Рынки';

  @override
  String get homeSimulatedPrices => 'учебные цены';

  @override
  String get marketDemoNotice =>
      'Цены смоделированы для обучения — это не реальные биржевые данные.';

  @override
  String get marketSearchHint => 'Поиск: тикер или название';

  @override
  String get marketThemeAll => 'Все';

  @override
  String get marketSectionStocks => 'АКЦИИ';

  @override
  String get marketSectionEtfs => 'ETF И ОБЛИГАЦИИ';

  @override
  String get marketSectionCrypto => 'КРИПТА';

  @override
  String get marketSectionFiat => 'ВАЛЮТЫ';

  @override
  String get marketNothingFoundTitle => 'Ничего не нашлось';

  @override
  String get marketNothingFoundBody =>
      'Попробуй другой тикер или сбрось фильтр темы';

  @override
  String get marketTradeComingTitle => 'Торговля подключается';

  @override
  String marketTradeComingBodyBuy(String symbol) {
    return 'Скоро здесь можно будет купить $symbol за виртуальные деньги — Cosmo уже готовит торговый модуль.';
  }

  @override
  String marketTradeComingBodySell(String symbol) {
    return 'Скоро здесь можно будет продать $symbol за виртуальные деньги — Cosmo уже готовит торговый модуль.';
  }

  @override
  String get assetTypeStock => 'Акция';

  @override
  String get assetTypeEtf => 'ETF';

  @override
  String get assetTypeBondEtf => 'Облигационный ETF';

  @override
  String get assetTypeCrypto => 'Криптовалюта';

  @override
  String get assetTypeFiat => 'Валюта';

  @override
  String assetDescStock(String name) {
    return 'Акция — это маленький кусочек компании «$name». Покупая её, ты становишься совладельцем бизнеса: он растёт — растёт и твоя доля. Но бывает и наоборот, поэтому акции считаются активом со средним риском.';
  }

  @override
  String get assetDescEtf =>
      'ETF — готовая корзина из десятков или сотен бумаг сразу. Один клик — и ты владеешь кусочком целого рынка, а не одной компанией. Для новичка это самый спокойный способ инвестировать.';

  @override
  String get assetDescBondEtf =>
      'Облигационный ETF — корзина займов государству и крупным компаниям. Растёт медленно, зато и трясёт его куда меньше, чем акции. Такая «подушка безопасности» в портфеле.';

  @override
  String get assetDescCrypto =>
      'Криптовалюта — цифровая валюта без банков и государств. Может сильно вырасти и так же сильно упасть: это самый «дикий» класс активов, держи его долю в портфеле небольшой.';

  @override
  String get assetDescFiat =>
      'Обычная мировая валюта. Здесь показана цена за 100 единиц в долларах. Курсы валют двигаются спокойнее акций, но тоже влияют на портфель.';

  @override
  String assetSectorLine(String sector) {
    return 'Сектор: $sector.';
  }

  @override
  String get sectorTechnology => 'Технологии — софт, железо и всё цифровое';

  @override
  String get sectorFinancial => 'Финансы — банки и платёжные системы';

  @override
  String get sectorHealthcare => 'Здравоохранение — лекарства и медицина';

  @override
  String get sectorConsumerDefensive =>
      'Товары первой необходимости — еда, напитки, быт';

  @override
  String get sectorConsumerCyclical =>
      'Потребительские товары — покупки «по желанию»';

  @override
  String get sectorCommunication => 'Коммуникации и медиа';

  @override
  String get sectorEnergy => 'Энергетика — нефть и газ';

  @override
  String get sectorUtilities => 'Коммунальный сектор — электричество и вода';

  @override
  String get sectorIndustrials => 'Промышленность — заводы и оборудование';

  @override
  String get assetEodTag => 'EOD';

  @override
  String get assetQuoteUnavailable => 'Котировка пока недоступна';

  @override
  String get assetPriceEndOfDay => 'Цена на конец дня';

  @override
  String get assetWhatIsThisTitle => 'Что это?';

  @override
  String get assetNoChartData => 'Нет данных за этот период';

  @override
  String get assetRange1D => '1Д';

  @override
  String get assetRange1W => '1Н';

  @override
  String get assetRange1M => '1М';

  @override
  String get assetRange1Y => '1Г';

  @override
  String get assetModeLine => 'Линия';

  @override
  String get assetModeCandles => 'Свечи';

  @override
  String get assetMetricsTitle => 'Метрики';

  @override
  String get assetMetricPrevClose => 'Закрытие пред. дня';

  @override
  String get assetMetricPrevCloseHint =>
      'Цена, по которой торги завершились в предыдущий день — от неё считается дневное изменение.';

  @override
  String get assetMetricRange => 'Диапазон за период';

  @override
  String get assetMetricRangeHint =>
      'Самая низкая и самая высокая цена за выбранный на графике период.';

  @override
  String assetMetricRangeValue(String min, String max) {
    return '$min – $max';
  }

  @override
  String get assetMetricAssetClass => 'Класс актива';

  @override
  String get assetMetricAssetClassHint =>
      'К какой большой группе финансовых инструментов относится актив.';

  @override
  String get assetMetricCurrency => 'Валюта котировки';

  @override
  String get assetMetricCurrencyHint =>
      'В какой валюте показана цена этого актива.';

  @override
  String get assetMetricUpdate => 'Обновление цены';

  @override
  String get assetMetricUpdateRealtime => 'В реальном времени';

  @override
  String get assetMetricUpdateEod => 'Раз в день (конец торгов)';

  @override
  String get assetMetricUpdateHintRealtime =>
      'Цена подтягивается с биржи почти мгновенно.';

  @override
  String get assetMetricUpdateHintEod =>
      'Этот актив торгуется на бирже, недоступной в реальном времени — цену обновляем раз в сутки и честно помечаем «EOD».';

  @override
  String get assetMetricSector => 'Сектор';

  @override
  String get assetMetricSectorHint => 'Отрасль, в которой работает компания.';

  @override
  String get assetSellAction => 'Продать';

  @override
  String get assetBuyAction => 'Купить';

  @override
  String get learnScreenTitle => 'Учёба';

  @override
  String learnProgressLabel(String pct) {
    return 'Пройдено $pct% пути';
  }

  @override
  String get learnGlossaryTooltip => 'Глоссарий';

  @override
  String get learnEmptyTitle => 'Уроки пока не загрузились';

  @override
  String get learnEmptyBody =>
      'Проверь соединение и открой вкладку «Учёба» ещё раз';

  @override
  String get learnGlossarySheetTitle => 'Глоссарий';

  @override
  String get learnGlossarySearchHint => 'Поиск термина';

  @override
  String get streakStartYours => 'Начни свою серию';

  @override
  String streakDaysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0 подряд';
  }

  @override
  String get streakSubtitleNone => 'Пройди свой первый урок сегодня';

  @override
  String get streakSubtitleDoneToday => 'Сегодня уже позанимался — отлично!';

  @override
  String get streakSubtitleTodo =>
      'Пройди урок сегодня, чтобы не потерять серию';

  @override
  String streakLabelWithDays(String daysText) {
    return 'Серия: $daysText';
  }

  @override
  String get lessonCloseTooltip => 'Закрыть урок';

  @override
  String get lessonButtonDone => 'Готово';

  @override
  String get lessonButtonToQuiz => 'К квизу';

  @override
  String get lessonButtonNext => 'Дальше';

  @override
  String get lessonQuizHeader => 'ПРОВЕРЬ СЕБЯ';

  @override
  String get lessonButtonAnswer => 'Ответить';

  @override
  String get lessonButtonNextQuestion => 'Следующий вопрос';

  @override
  String get lessonButtonFinish => 'Завершить урок';

  @override
  String get lessonCompleteTitle => 'Урок пройден!';

  @override
  String lessonScore(int correct, int total) {
    return 'Верно $correct из $total';
  }

  @override
  String get lessonButtonReady => 'Готово';

  @override
  String get settingsQuotesKeyHelp =>
      'Без ключа цены смоделированы и помечены «ДЕМО». С бесплатным ключом с finnhub.io акции и ETF США показывают настоящие биржевые цены. Ключ остаётся на этом устройстве. Крипта и валюты в бесплатный тариф не входят — у них бейдж «ДЕМО» сохранится.';

  @override
  String get settingsQuotesKeyHint => 'вставь ключ с finnhub.io';

  @override
  String get settingsQuotesKeyLabel => 'Ключ Finnhub';

  @override
  String get settingsQuotesOff => 'Цены смоделированы';

  @override
  String get settingsQuotesOn => 'Настоящие цены включены';

  @override
  String get settingsQuotesSection => 'Настоящие цены';

  @override
  String get tradeNotSavedError =>
      'Не смог сохранить на устройстве — сделка отменена. Деньги на месте. Освободи немного места и попробуй ещё раз.';

  @override
  String get assetChartSimulatedNotice =>
      'Учебный график: история придумана алгоритмом, а не взята с биржи';

  @override
  String get assetMetricRangeSimulated => 'Диапазон за период (учебный график)';

  @override
  String get assetMetricRangeHintSimulated =>
      'Считается по учебному графику, поэтому эти числа тоже выдуманы — не сравнивай их с настоящей биржей.';

  @override
  String get learnLoadFailedTitle => 'Не смог открыть твой прогресс';

  @override
  String get learnLoadFailedBody =>
      'Ничего не потеряно: пройденные уроки и стрик остаются на устройстве. Пока прогресс не прочитан, отмечать уроки пройденными нельзя — иначе старый прогресс затрётся пустым.';

  @override
  String get learnRetryAction => 'Попробовать снова';

  @override
  String get learnNotSavedError =>
      'Урок НЕ засчитан: прогресс не удалось сохранить на устройстве. Попробуй ещё раз — иначе после перезапуска урока не будет.';

  @override
  String get learnProgressUnreadableNotice =>
      'Не смог прочитать твой сохранённый прогресс обучения. Он НЕ потерян: я отложил его в сторону и ничего не затираю. Покажи мне это сообщение, и я верну.';
}
