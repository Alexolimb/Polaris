import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'models/models.dart';
import 'screens/chat/cosmo_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/market/asset_screen.dart';
import 'screens/market/market_screen.dart';
import 'screens/more/more_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/splash.dart';
import 'widgets/fx/stars_background.dart';
import 'services/lessons.dart';
import 'services/notifications.dart';
import 'services/storage.dart';
import 'state/app_scope.dart';
import 'state/app_settings.dart';
import 'state/chat_state.dart';
import 'state/learn_state.dart';
import 'state/market_state.dart';
import 'state/portfolio_state.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PolarisApp());
}

/// Владеет [PrefsStorage] и [AppSettings] — оба должны существовать ВЫШЕ
/// [MaterialApp], потому что MaterialApp.locale читается из настроек
/// (localePref) при каждой перестройке. [AnimatedBuilder] на [_settings]
/// перестраивает MaterialApp сразу при смене языка в экране «Ещё → Настройки»
/// — без перезапуска приложения.
class PolarisApp extends StatefulWidget {
  const PolarisApp({super.key});

  @override
  State<PolarisApp> createState() => _PolarisAppState();
}

class _PolarisAppState extends State<PolarisApp> {
  late final PrefsStorage _storage;
  late final AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _storage = PrefsStorage();
    _settings = AppSettings(storage: _storage);
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  /// null (для [LocalePref.auto]) отдаёт выбор системе через
  /// [MaterialApp.localeResolutionCallback] ниже — иначе принудительный язык.
  Locale? _explicitLocale() => switch (_settings.localePref) {
        LocalePref.en => const Locale('en'),
        LocalePref.ru => const Locale('ru'),
        LocalePref.es => const Locale('es'),
        LocalePref.auto => null,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => MaterialApp(
        title: 'Polaris',
        debugShowCheckedModeBanner: false,
        theme: polarisTheme(),
        locale: _explicitLocale(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Локаль auto: берём язык устройства, если он один из трёх
        // поддерживаемых, иначе честный фолбэк на английский (не на первый
        // из списка, который был бы 'en' и так, но явно — для ясности).
        localeResolutionCallback: (deviceLocale, supported) {
          if (deviceLocale != null) {
            for (final l in supported) {
              if (l.languageCode == deviceLocale.languageCode) return l;
            }
          }
          return const Locale('en');
        },
        home: _Root(storage: _storage, settings: _settings),
      ),
    );
  }
}

/// Корень: создаёт и владеет общим состоянием, раздаёт через AppScope.
/// Поток запуска: заставка (пока грузятся данные) → онбординг (при первом
/// запуске) → каркас приложения.
class _Root extends StatefulWidget {
  final PrefsStorage storage;
  final AppSettings settings;

  const _Root({required this.storage, required this.settings});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final PortfolioState _portfolio;
  late final MarketState _market;
  late final ChatState _chat;
  late final LearnState _learn;
  late final AppSettings _settings;
  late final NotificationsController _notifications;

  bool _splashDone = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final storage = widget.storage;
    _settings = widget.settings;
    _portfolio = PortfolioState(storage: storage);
    _market = MarketState();
    // lang: обёртка, не значение — ChatState зовёт её при каждом запросе,
    // так что смена языка в настройках сразу меняет язык ответов Cosmo.
    _chat = ChatState(storage: storage, lang: () => _settings.resolvedLanguageCode);
    _learn = LearnState(storage: storage);
    _notifications = NotificationsController(
      gateway: LocalNotificationsPluginGateway(),
      settings: _settings,
    );

    _market.init();
    // Дожидаемся только того, что решает первый экран (портфель + настройки/
    // онбординг). Планирование уведомлений НЕ блокирует первый кадр —
    // запускаем его в фоне: пользователю незачем ждать расписание напоминаний,
    // чтобы увидеть онбординг/портфель.
    // Каждая load() глушит свою ошибку (у состояний безопасные значения по
    // умолчанию), а общий таймаут страхует от зависшего диска — иначе одно
    // исключение/зависание навсегда оставило бы пользователя на заставке.
    Future.wait([
      _portfolio.load().catchError((_) {}),
      _learn.load().catchError((_) {}),
      _settings.load().catchError((_) {}),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => <void>[]).whenComplete(() {
      if (mounted) setState(() => _loaded = true);
      _notifications.init(); // фоном, по настройкам
    });
  }

  @override
  void dispose() {
    _portfolio.dispose();
    _market.dispose();
    _chat.dispose();
    _learn.dispose();
    _notifications.dispose();
    // _settings НЕ наш — им владеет PolarisApp (нужен выше MaterialApp для
    // локали), он же его и disposes.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen;
    if (!_splashDone || !_loaded) {
      screen = SplashScreen(onDone: () {
        if (mounted) setState(() => _splashDone = true);
      });
    } else if (!_settings.onboardingDone) {
      screen = OnboardingScreen(
        settings: _settings,
        onDone: () => setState(() {}), // онбординг сам сохранил флаг
      );
    } else {
      screen = const Shell();
    }

    return AppScope(
      portfolio: _portfolio,
      market: _market,
      chat: _chat,
      learn: _learn,
      settings: _settings,
      notifications: _notifications,
      child: screen,
    );
  }
}

/// Каркас: 5 вкладок. Все готовы (волны 1-3).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  /// Переход из урока «попробуй на своём портфеле» → в нужное место рынка.
  void _handleTryIt(TryIt tryIt) {
    final scope = AppScope.read(context);
    switch (tryIt.action) {
      case TryItAction.openTheme:
        scope.market.selectTheme(tryIt.theme);
        setState(() => _tab = 1);
      case TryItAction.openAsset:
        final asset = scope.market.assets.cast<Asset?>().firstWhere(
            (a) => a?.symbol == tryIt.symbol,
            orElse: () => null);
        setState(() => _tab = 1);
        if (asset != null) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AssetScreen(asset: asset, state: scope.market)));
        }
      case TryItAction.openMarket:
      case TryItAction.unknown:
        setState(() => _tab = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    // IndexedStack — вкладки сохраняют состояние при переключении.
    final tabs = <Widget>[
      const HomeScreen(),
      MarketScreen(state: scope.market, active: _tab == 1),
      CosmoScreen(chatState: scope.chat),
      LearnScreen(
        state: scope.learn,
        onTryIt: _handleTryIt,
        lang: () => scope.settings.resolvedLanguageCode,
      ),
      const MoreScreen(),
    ];

    final body = IndexedStack(index: _tab, children: tabs);

    // Раскладка под ширину экрана. Раньше телефонная нижняя панель
    // использовалась и на десктопе: на окне 1280+ логических пикселей контент
    // растягивался во всю ширину (карточки со списками активов и пунктами
    // «Ещё» превращались в километровые полосы с пустотой посередине).
    // Порог 880 — как в Fluxo, чтобы приложения Алекса вели себя одинаково.
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: PolarisColors.surface,
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              indicatorColor: PolarisColors.polar.withValues(alpha: 0.18),
              selectedIconTheme:
                  const IconThemeData(color: PolarisColors.polar, size: 24),
              unselectedIconTheme: const IconThemeData(
                  color: PolarisColors.textSecondary, size: 24),
              selectedLabelTextStyle: const TextStyle(
                color: PolarisColors.polar,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: PolarisColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              destinations: [
                for (final d in _navItems(l10n))
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    label: Text(d.$2),
                  ),
              ],
            ),
            Container(width: 1, color: PolarisColors.surfaceHigh),
            // Небо рисуем один раз во всю ширину окна, а контент держим в
            // колонке. Иначе сияние обрезалось бы прямоугольником по краям
            // колонки — было видно на скриншотах.
            Expanded(
              child: StarsBackground.provide(
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _wideContentMaxWidth),
                    child: body,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _navItems(l10n))
            NavigationDestination(icon: Icon(d.$1), label: d.$2),
        ],
      ),
    );
  }

  /// Пункты навигации — один список на обе раскладки, чтобы они не разъезжались.
  List<(IconData, String)> _navItems(AppLocalizations l10n) => [
        (Icons.auto_awesome, l10n.navPortfolio),
        (Icons.travel_explore, l10n.navMarkets),
        (Icons.chat_bubble_outline, l10n.navCosmo),
        (Icons.school_outlined, l10n.navLearn),
        (Icons.more_horiz, l10n.navMore),
      ];
}

/// Ширина, с которой включается десктопная раскладка (боковая рельса).
const double _wideBreakpoint = 880;

/// Максимальная ширина колонки контента на широком экране — чтобы строки
/// текста и карточки не растягивались через весь монитор.
const double _wideContentMaxWidth = 840;
