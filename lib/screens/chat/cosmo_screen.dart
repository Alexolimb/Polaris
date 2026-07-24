/// Экран Cosmo — чат с AI-наставником (волна 2а). Пузыри сообщений, живой
/// стриминг ответа, простой аватар-астронавт (CustomPainter), кнопки-подсказки,
/// приветствие при первом входе. Дисклеймер симулятора закреплён над полем ввода.
///
/// [ChatState] живёт внутри экрана (не в AppScope — интегратор просто вставляет
/// готовый `const CosmoScreen()` в IndexedStack вкладок main.dart), история
/// сохраняется на диск через PrefsStorage. Портфельный контекст для Cosmo
/// берётся анонимно из AppScope (PortfolioState.aiContext + свежие котировки),
/// если экран внутри дерева с AppScope — иначе Cosmo просто отвечает без него.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/storage.dart';
import '../../state/app_scope.dart';
import '../../state/app_settings.dart';
import '../../state/chat_state.dart';
import '../../theme/theme.dart';
import '../../widgets/cosmo/cosmo_mascot.dart';
import '../../widgets/fx/glow.dart';
import '../../widgets/fx/motion.dart';
import '../../widgets/fx/stars_background.dart';

/// Язык ответа Cosmo — по локали устройства, пока нет полноценного l10n-выбора
/// (волна 3). ru/es распознаём явно, всё остальное — английский.
String cosmoDeviceLang() {
  final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
  return (code == 'ru' || code == 'es') ? code : 'en';
}

const _greeting = {
  'ru':
      'Привет, я Cosmo! Помогу разобраться в инвестициях простыми словами — без спешки и без «покупай срочно». Спрашивай что угодно или выбери вопрос ниже.',
  'en':
      "Hi, I'm Cosmo! I'll help you understand investing in plain words — no rush, no \"buy now\" pressure. Ask me anything, or pick a question below.",
  'es':
      '¡Hola, soy Cosmo! Te ayudo a entender la inversión con palabras simples — sin prisas ni "compra ahora". Pregúntame lo que quieras, o elige una pregunta de abajo.',
};

const _quickPrompts = {
  'ru': ['Что такое ETF?', 'Почему мой портфель просел?', 'С чего начать?'],
  'en': ['What is an ETF?', 'Why did my portfolio drop?', 'Where do I start?'],
  'es': ['¿Qué es un ETF?', '¿Por qué bajó mi cartera?', '¿Por dónde empiezo?'],
};

const _disclaimer = {
  'ru': 'Это симулятор с виртуальными деньгами. Cosmo обучает, но не даёт личных инвестиционных советов.',
  'en': "This is a virtual-money simulator. Cosmo teaches, but doesn't give personal investment advice.",
  'es': 'Esto es un simulador con dinero virtual. Cosmo enseña, pero no da consejos de inversión personales.',
};

const _inputHint = {
  'ru': 'Спроси Cosmo о чём угодно…',
  'en': 'Ask Cosmo anything…',
  'es': 'Pregúntale algo a Cosmo…',
};

const _typingLabel = {
  'ru': 'Cosmo печатает…',
  'en': 'Cosmo is typing…',
  'es': 'Cosmo está escribiendo…',
};

class CosmoScreen extends StatefulWidget {
  /// Подменяемый инстанс для тестов/превью — в продакшене создаётся сам.
  final ChatState? chatState;

  const CosmoScreen({super.key, this.chatState});

  @override
  State<CosmoScreen> createState() => _CosmoScreenState();
}

class _CosmoScreenState extends State<CosmoScreen> {
  late final ChatState _chat;
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  /// Настройки, если экран внутри AppScope (в изолированных тестах/превью
  /// их может не быть) — слушаем их, чтобы смена языка в «Ещё → Настройки»
  /// сразу перерисовывала приветствие/подсказки/дисклеймер на новом языке.
  AppSettings? _settings;

  /// Язык текста экрана (приветствие/подсказки/дисклеймер).
  /// 1) ChatState передан извне (продакшен — Shell в main.dart, либо тесты) —
  ///    берём его lang() как есть, чтобы статичные тексты совпадали с тем, на
  ///    каком языке реально отвечает Cosmo (в проде это уже
  ///    AppSettings.resolvedLanguageCode, см. main.dart).
  /// 2) Экран сам создал ChatState (нет chatState в конструкторе), но
  ///    AppScope доступен — читаем язык оттуда напрямую.
  /// 3) Совсем без контекста (изолированный тест/превью) — язык устройства.
  String get _lang =>
      widget.chatState?.lang() ?? _settings?.resolvedLanguageCode ?? cosmoDeviceLang();

  @override
  void initState() {
    super.initState();
    _chat = widget.chatState ?? ChatState(storage: PrefsStorage(), lang: _lang0);
    _chat.addListener(_onChanged);
    _chat.load();
  }

  // Обёртка методом (не замыканием на _lang до его первого использования) —
  // ChatState зовёт эту функцию при каждом запросе, так что она видит
  // актуальный _lang, включая смену настроек после старта экрана.
  String _lang0() => _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppSettings? settings;
    try {
      settings = AppScope.of(context).settings;
    } catch (_) {
      // Экран без AppScope выше (тесты/превью) — язык остаётся по устройству.
    }
    if (!identical(settings, _settings)) {
      _settings?.removeListener(_onSettingsChanged);
      _settings = settings;
      _settings?.addListener(_onSettingsChanged);
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Анонимный контекст портфеля для Cosmo — только если экран внутри AppScope
  /// (в изолированных тестах экрана его может не быть, и это ок).
  Map<String, dynamic>? _portfolioContext() {
    try {
      final scope = AppScope.of(context);
      final quotes = <String, Quote>{};
      for (final symbol in scope.portfolio.positions.keys) {
        final q = scope.market.quoteOf(symbol);
        if (q != null) quotes[symbol] = q;
      }
      return scope.portfolio.aiContext(quotes);
    } catch (_) {
      return null;
    }
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    _chat.send(trimmed, portfolio: _portfolioContext());
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _chat.removeListener(_onChanged);
    if (widget.chatState == null) _chat.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting[_lang]!;
    final prompts = _quickPrompts[_lang]!;
    final showGreeting = _chat.loaded && _chat.isEmpty;

    return StarsBackground(
      intensity: 0.6,
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: showGreeting
                  ? _greetingView(greeting, prompts)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _chat.entries.length,
                      itemBuilder: (context, i) {
                        final entry = _chat.entries[i];
                        final isLast = i == _chat.entries.length - 1;
                        return StaggerIn(
                          index: i > 8 ? 8 : i,
                          child: _bubble(entry, showTyping: isLast && _chat.sending),
                        );
                      },
                    ),
            ),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const CosmoBadge(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cosmo',
                    style: TextStyle(
                        color: PolarisColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                Row(
                  children: [
                    const PulseDot(color: PolarisColors.aurora, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      _lang == 'ru'
                          ? 'наставник по инвестициям'
                          : _lang == 'es'
                              ? 'mentor de inversión'
                              : 'investing mentor',
                      style: const TextStyle(
                          color: PolarisColors.textFaint, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _greetingView(String greeting, List<String> prompts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          GlowCard(
            glowColor: PolarisColors.aurora,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CosmoBadge(size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(greeting,
                      style: const TextStyle(
                          color: PolarisColors.textPrimary, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...prompts.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Springy(
                  onTap: () => _send(p),
                  child: GlowCard(
                    glowColor: PolarisColors.polar,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: PolarisColors.polar, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                  color: PolarisColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _bubble(ChatEntry entry, {required bool showTyping}) {
    final isUser = entry.role == ChatRole.user;
    final typing = showTyping && entry.text.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CosmoBadge(size: 26),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? PolarisColors.polar.withValues(alpha: .18)
                    : PolarisColors.surfaceHigh.withValues(alpha: .8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: (isUser ? PolarisColors.polar : PolarisColors.aurora)
                      .withValues(alpha: .25),
                ),
              ),
              child: typing
                  ? _TypingIndicator(label: _typingLabel[_lang]!)
                  : Text(entry.text,
                      style: const TextStyle(
                          color: PolarisColors.textPrimary, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _disclaimer[_lang]!,
            style: const TextStyle(color: PolarisColors.textFaint, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: PolarisColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: PolarisColors.polar.withValues(alpha: .25)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: PolarisColors.textPrimary),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _inputHint[_lang],
                      hintStyle:
                          const TextStyle(color: PolarisColors.textFaint),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Springy(
                onTap: () => _send(_controller.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: PolarisColors.polar,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final String label;
  const _TypingIndicator({required this.label});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  // Не лениво — см. комментарий в fx/motion.dart про TickerMode.
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label,
            style: const TextStyle(
                color: PolarisColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic)),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            children: List.generate(3, (i) {
              final phase = (_c.value * 3 - i) % 1;
              final t = phase < 0 ? phase + 1 : phase;
              final opacity = 0.3 + 0.7 * (t < .5 ? t * 2 : (1 - t) * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: const CircleAvatar(
                      radius: 2.5, backgroundColor: PolarisColors.aurora),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Простой аватар-астронавта Cosmo: шлем + козырёк-градиент полярного сияния.
/// Программный CustomPainter (решение из плана — Rive потом, без потери срока).
class CosmoAvatar extends StatelessWidget {
  final double size;
  const CosmoAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CosmoAvatarPainter()),
    );
  }
}

class _CosmoAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Внешний ореол свечения.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          PolarisColors.polar.withValues(alpha: .35),
          PolarisColors.polar.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Корпус шлема.
    canvas.drawCircle(c, r * .82, Paint()..color = PolarisColors.surfaceHigh);
    canvas.drawCircle(
      c,
      r * .82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .08
        ..color = PolarisColors.star.withValues(alpha: .85),
    );

    // Козырёк-визор: градиент полярного сияния.
    final visorRect = Rect.fromCenter(
        center: c.translate(0, r * .04), width: r * 1.15, height: r * .95);
    canvas.drawOval(
      visorRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PolarisColors.polar, PolarisColors.aurora, PolarisColors.violet],
        ).createShader(visorRect),
    );

    // Блик на визоре — придаёт «стеклянность».
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-r * .22, -r * .18), width: r * .35, height: r * .2),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant _CosmoAvatarPainter oldDelegate) => false;
}
