// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navPortfolio => 'Cartera';

  @override
  String get navMarkets => 'Mercados';

  @override
  String get navCosmo => 'Cosmo';

  @override
  String get navLearn => 'Aprende';

  @override
  String get navMore => 'Más';

  @override
  String get cancelLabel => 'Cancelar';

  @override
  String get doneLabel => 'Entendido';

  @override
  String get commonNothingFound => 'No se encontró nada';

  @override
  String get resetDialogTitle => '¿Empezar de nuevo?';

  @override
  String get resetDialogBody =>
      'Tu cartera volverá a los \$10,000 iniciales. El historial de operaciones se borrará. Es dinero de práctica, no pasa nada.';

  @override
  String get resetConfirmAction => 'Empezar de nuevo';

  @override
  String get moreScreenTitle => 'Más';

  @override
  String get moreSettingsTitle => 'Ajustes';

  @override
  String get moreSettingsSubtitle => 'Notificaciones y datos de la cartera';

  @override
  String get moreBrokersTitle => '¿Listo para invertir de verdad?';

  @override
  String get moreBrokersSubtitle =>
      'Brokers con licencia en la UE para empezar';

  @override
  String get moreAboutTitle => 'Acerca de la app';

  @override
  String get moreAboutSubtitle => 'Polaris, versión, agradecimientos';

  @override
  String get morePrivacyTitle => 'Privacidad';

  @override
  String get morePrivacySubtitle => 'Qué datos salen de la app y adónde';

  @override
  String get moreLegalTitle => 'Información legal';

  @override
  String get moreLegalSubtitle => 'Avisos legales y condiciones de uso';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageSection => 'Idioma';

  @override
  String get settingsLanguageAuto => 'Automático (del sistema)';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsNotificationsSection => 'Notificaciones';

  @override
  String get settingsNotifLesson => 'Lección del día y racha';

  @override
  String get settingsNotifLessonSub => 'Recordatorio nocturno para practicar';

  @override
  String get settingsNotifWeekly => 'Resumen semanal';

  @override
  String get settingsNotifWeeklySub => 'Cómo cambió tu cartera esta semana';

  @override
  String get settingsNotifDividend => 'Dividendo recibido';

  @override
  String get settingsNotifDividendSub => 'Aviso cuando se acreditan dividendos';

  @override
  String get settingsNotifBigMoves => 'Grandes movimientos de precio';

  @override
  String get settingsNotifBigMovesSub => '±5% en un día en tus posiciones';

  @override
  String get settingsDataSection => 'Datos';

  @override
  String get settingsResetPortfolio => 'Reiniciar cartera';

  @override
  String get settingsResetPortfolioSub =>
      'Restaurar los \$10,000 iniciales y borrar el historial';

  @override
  String get aboutTitle => 'Acerca de la app';

  @override
  String aboutVersionLabel(String version) {
    return 'Versión $version · simulador de inversión';
  }

  @override
  String get aboutWhatIsItTitle => 'Qué es esto';

  @override
  String get aboutWhatIsItBody =>
      'Polaris es un simulador gratuito de inversión para quienes nunca antes compraron una acción. Una cartera virtual de \$10,000, precios reales en vivo, dividendos honestos y un mentor de IA, Cosmo, que explica todo con palabras simples — sin prisas ni presión de \"casino\".';

  @override
  String get aboutSimNoteTitle => 'Esto es aprendizaje, no una bolsa';

  @override
  String get aboutSimNoteBody =>
      'Esto es un simulador: el dinero de la cartera es virtual, la app nunca realiza operaciones reales. La sección \"¿Listo para invertir de verdad?\" en Más es una transición honesta hacia brokers con licencia en la UE, para cuando decidas invertir de verdad.';

  @override
  String get aboutMascotTitle => 'Cosmo';

  @override
  String get aboutMascotBody =>
      'Tu mentor astronauta. Cosmo no da recomendaciones de inversión personales ni promete rentabilidad — solo explica con calma qué está pasando en el mercado y en tu cartera.';

  @override
  String get aboutDataTitle => 'De dónde vienen los datos';

  @override
  String get aboutDataBody =>
      'Las cotizaciones, tipos de cambio y gráficos llegan a través del propio servidor de caché de Polaris — la app nunca contacta APIs de terceros directamente. Las fuentes están abajo.';

  @override
  String get aboutThanksTitle => 'Agradecimientos';

  @override
  String get aboutAttrCoinGecko => 'Powered by CoinGecko';

  @override
  String get aboutAttrCurrency => 'Tipos de cambio: open.er-api.com';

  @override
  String get aboutAttrCrypto => 'Tickers cripto: API pública de Binance';

  @override
  String get aboutAttrStocks =>
      'Cotizaciones de acciones: Yahoo Finance (puede tener retraso)';

  @override
  String get brokersTitle => '¿Listo para invertir de verdad?';

  @override
  String get brokersRiskTop =>
      'Invertir implica riesgo de pérdida de capital. Nada de lo siguiente es asesoramiento financiero ni una recomendación personal: Polaris no es un asesor financiero autorizado. Antes de invertir dinero real, estudia tú mismo las condiciones y riesgos con el broker que elijas.';

  @override
  String get brokersRiskBottom =>
      'La lista de abajo es informativa y está en orden alfabético, no por recomendación. No recibimos dinero por el broker que elijas (fase 1). La decisión es solo tuya.';

  @override
  String get brokersIntro =>
      'Has practicado en Polaris con \$10,000 virtuales y precios reales en vivo — una forma segura de entender cómo funciona todo, sin riesgo para tu bolsillo. Cuando sientas que estás listo para invertir dinero real, aquí tienes algunos brokers de acciones con licencia en la Unión Europea — a los principiantes suele resultarles más fácil empezar con ellos.';

  @override
  String get brokersSectionListTitle =>
      'Brokers de acciones y ETF con licencia en la UE';

  @override
  String get brokersExternalSiteNote => 'sitio externo';

  @override
  String get brokersOpenFailed =>
      'No se pudo abrir el enlace en este dispositivo';

  @override
  String get brokersOpenSiteLabel => 'Abrir sitio';

  @override
  String get brokersNoCryptoNote =>
      'Aquí no hay brokers ni exchanges de cripto — solo brokers regulados de acciones y ETF reales.';

  @override
  String get brokersEtoroDesc =>
      'Broker con una app móvil sencilla y carteras ya armadas; regulado en la UE (Chipre/Malta).';

  @override
  String get brokersIbkrDesc =>
      'Uno de los mayores brokers del mundo, con una enorme variedad de mercados; más adecuado para quien esté dispuesto a explorar una interfaz más detallada.';

  @override
  String get brokersLightyearDesc =>
      'Un broker europeo joven con una interfaz honesta y explicaciones de \"por qué cambió el precio\" — el más parecido en espíritu a Polaris.';

  @override
  String get brokersScalableDesc =>
      'Neobroker alemán con acciones fraccionadas y planes de ahorro ya armados; regulado por BaFin (Alemania).';

  @override
  String get brokersTraderepublicDesc =>
      'Neobanco-broker alemán con una app sencilla y comisiones bajas; regulado como banco en la UE.';

  @override
  String get brokersXtbDesc =>
      'Broker polaco con acciones/ETF gratis hasta cierto volumen y materiales educativos para principiantes; con licencia en la UE.';

  @override
  String get legalTitle => 'Información legal';

  @override
  String get legalIntro =>
      'En palabras simples sobre lo que Polaris puede y no puede hacer — sin letra pequeña.';

  @override
  String get legalSimTitle => 'Simulador educativo';

  @override
  String get legalSimBody =>
      'Polaris es una app educativa. La cartera, las operaciones y el dinero en ella son virtuales: la app no realiza ni puede realizar compras reales de acciones, ETF ni de ningún otro instrumento.';

  @override
  String get legalNoAdviceTitle => 'No es una recomendación de inversión';

  @override
  String get legalNoAdviceBody =>
      'Nada en la app — ni las cifras, ni los comentarios de Cosmo, ni las selecciones temáticas — constituye una recomendación de inversión personal, un asesoramiento o una oferta de compra/venta de un instrumento concreto. Polaris no es un asesor financiero autorizado ni un banco.';

  @override
  String get legalPastResultsTitle => 'El pasado no garantiza el futuro';

  @override
  String get legalPastResultsBody =>
      'Que un activo haya subido en el pasado (en la app o en la vida real) no garantiza que siga subiendo. Cualquier inversión puede subir o bajar de valor, incluso hasta la pérdida total del dinero invertido.';

  @override
  String get legalDelayedDataTitle => 'Los datos pueden tener retraso';

  @override
  String get legalDelayedDataBody =>
      'Parte de las cotizaciones (acciones fuera de EE. UU., algunos valores) se actualiza no en tiempo real, sino al cierre de la sesión — esos activos se marcan honestamente en el catálogo como \"EOD\"/\"con retraso\". Incluso los precios \"en vivo\" tienen el pequeño retraso habitual de las fuentes de datos gratuitas.';

  @override
  String get legalAiTitle => 'El mentor de IA Cosmo no es un asesor';

  @override
  String get legalAiBody =>
      'Cosmo explica términos y comenta tus operaciones de práctica en lenguaje simple, pero no elige valores concretos para tu situación ni promete rentabilidad. Las respuestas de Cosmo pueden ser inexactas — como cualquier IA — y no sustituyen la consulta con un profesional autorizado.';

  @override
  String get legalEntityTitle => 'Quién hace Polaris';

  @override
  String get legalEntityBody =>
      'En la etapa de simulador, Polaris es un proyecto educativo sin fines de lucro, sin licencia bancaria ni de correduría y sin recaudar dinero real de los usuarios. La información sobre la entidad legal se publicará aquí cuando se lance la negociación real en la siguiente etapa.';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get privacyIntro =>
      'En resumen: Polaris no tiene cuenta, no tiene tu nombre ni tu correo, y no vende datos a anunciantes. Abajo está exactamente qué pasa con los datos.';

  @override
  String get privacyLocalTitle => 'Se guarda en el dispositivo';

  @override
  String get privacyLocalBody =>
      'La cartera, el progreso en las lecciones, la racha y los ajustes se guardan directamente en tu teléfono u ordenador. No hay cuenta ni inicio de sesión — juegas como invitado de inmediato. Puedes borrar todo simplemente desinstalando la app.';

  @override
  String get privacyServerTitle => 'Se envía al servidor';

  @override
  String get privacyServerBody =>
      'Al servidor de Polaris solo se envía: (1) solicitudes anónimas de cotizaciones (ticker, sin vincularlas a ti) y (2) el texto de tus preguntas a Cosmo junto con una instantánea anónima de la cartera (tickers y participaciones, sin nombre ni datos del dispositivo). La app nunca recopila ni envía datos personales — nombre, correo, teléfono, ubicación.';

  @override
  String get privacyNoTrackersTitle => 'Sin rastreadores de terceros';

  @override
  String get privacyNoTrackersBody =>
      'No hay SDK publicitarios, ni rastreadores de comportamiento de terceros, ni venta de datos. Las estadísticas de uso anónimas (qué lecciones se toman más) solo sirven para mejorar el programa de aprendizaje — nunca para dar recomendaciones de inversión personales (ese es el límite legal de la UE).';

  @override
  String get privacyRightsTitle => 'Tus derechos (RGPD)';

  @override
  String get privacyRightsBody =>
      'Como los datos nunca salen del dispositivo y no hay cuenta, puedes borrarlos tú mismo en cualquier momento: reinicia la cartera en ajustes o desinstala la app por completo para borrar todo. No hace falta pedirnos por separado que eliminemos datos — sencillamente no hay nada en un servidor.';

  @override
  String get privacyFullPolicyLabel => 'Política de privacidad completa';

  @override
  String get privacyFullPolicyNote => 'se abre en nuestro sitio web';

  @override
  String get onboardingWelcomeTitle => 'Hola, soy Cosmo';

  @override
  String get onboardingWelcomeBody =>
      'Soy tu mentor. Te ayudaré a entender la inversión: explicando cada paso con palabras simples, sin prisas ni presión.';

  @override
  String get onboardingMoneyTitle => '\$10,000 en dinero virtual';

  @override
  String get onboardingMoneyBody =>
      'Practica con precios reales de mercado — acciones, ETF, cripto — sin arriesgar ni un centavo de dinero real.';

  @override
  String get onboardingLearnTitle => 'Aprende paso a paso';

  @override
  String get onboardingLearnBody =>
      'Lecciones cortas — y las pruebas al momento en tu propia cartera. Pregúntame lo que quieras, estoy aquí siempre que me necesites.';

  @override
  String get onboardingGoalTitle => '¿Para qué estás aquí?';

  @override
  String get onboardingGoalBody =>
      'Esto me ayuda a elegir mejor mis palabras — elige la opción más cercana a ti.';

  @override
  String get onboardingGoalSave => 'Ahorrar para el futuro';

  @override
  String get onboardingGoalLearn => 'Entender la inversión';

  @override
  String get onboardingGoalCurious => 'Solo curiosidad';

  @override
  String get onboardingDisclaimerTitle => 'Importante entender';

  @override
  String get onboardingDisclaimerBody =>
      'Polaris es un simulador educativo, no una recomendación de inversión. Los precios pueden mostrarse con retraso y diferir de la bolsa. Cualquier decisión con dinero real es solo tuya, y debe tomarse con cabeza.';

  @override
  String get onboardingBack => 'Atrás';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar';

  @override
  String get homeMyPortfolio => 'Mi cartera';

  @override
  String get homeLivePrices => 'precios en vivo';

  @override
  String get homeResetTooltip => 'Empezar de nuevo';

  @override
  String homeFreeCash(String amount) {
    return 'Disponible: $amount';
  }

  @override
  String homeDividendsReceived(String amount) {
    return 'Recibido en dividendos: $amount';
  }

  @override
  String homeSharesCount(String qty) {
    return '$qty uds';
  }

  @override
  String get homeEmptyTitle => 'Tu cartera está vacía';

  @override
  String get homeEmptyBody =>
      'Tienes \$10,000 en dinero virtual para practicar sin riesgo. Entra en \"Mercados\" y compra tu primer valor — Cosmo te lo explicará todo.';

  @override
  String get tradeNoPriceSnack =>
      'Sin precio actual — inténtalo de nuevo en un momento';

  @override
  String tradeBuyTitle(String symbol) {
    return 'Comprar $symbol';
  }

  @override
  String tradeSellTitle(String symbol) {
    return 'Vender $symbol';
  }

  @override
  String tradePriceLabel(String price) {
    return 'Precio $price por unidad';
  }

  @override
  String tradeFreeCash(String amount) {
    return 'Disponible: $amount';
  }

  @override
  String tradeYouHave(String qty, String symbol) {
    return 'Tienes: $qty $symbol';
  }

  @override
  String get tradeHintBuy => 'Cuánto invertir';

  @override
  String get tradeHintSell => 'Cuántas unidades vender';

  @override
  String tradePreviewBuy(String qty, String symbol) {
    return 'Obtendrás ≈ $qty $symbol';
  }

  @override
  String tradePreviewSell(String amount) {
    return 'Obtendrás ≈ $amount';
  }

  @override
  String get tradeAll => 'Todo';

  @override
  String get tradeBuyAction => 'Comprar';

  @override
  String get tradeSellAction => 'Vender';

  @override
  String get tradeDisclaimer =>
      'Dinero virtual · esto es práctica, no una operación real';

  @override
  String get tradeGenericError => 'Algo falló — inténtalo de nuevo';

  @override
  String get tradeBoughtVerb => 'Comprado';

  @override
  String get tradeSoldVerb => 'Vendido';

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
      'El importe y el precio deben ser mayores que cero';

  @override
  String get simErrorInsufficientCash => 'No tienes suficiente dinero virtual';

  @override
  String get simErrorAmountTooSmall =>
      'Importe demasiado pequeño para este precio';

  @override
  String get simErrorSellQtyPriceInvalid =>
      'La cantidad y el precio deben ser mayores que cero';

  @override
  String get simErrorNoPosition => 'No tienes ese valor en tu cartera';

  @override
  String get simErrorSellTooMuch =>
      'Tienes menos unidades de las que intentas vender';

  @override
  String get simErrorDividendInvalid => 'El dividendo debe ser mayor que cero';

  @override
  String get marketScreenTitle => 'Mercados';

  @override
  String get marketOfflineBadge => 'datos de demostración';

  @override
  String get marketDemoTag => 'DEMO';

  @override
  String get marketDemoNotice =>
      'Los precios están simulados con fines educativos: no son datos reales de mercado.';

  @override
  String get marketSearchHint => 'Buscar: ticker o nombre';

  @override
  String get marketThemeAll => 'Todos';

  @override
  String get marketSectionStocks => 'ACCIONES';

  @override
  String get marketSectionEtfs => 'ETF Y BONOS';

  @override
  String get marketSectionCrypto => 'CRIPTO';

  @override
  String get marketSectionFiat => 'DIVISAS';

  @override
  String get marketNothingFoundTitle => 'No se encontró nada';

  @override
  String get marketNothingFoundBody =>
      'Prueba con otro ticker o quita el filtro de tema';

  @override
  String get marketTradeComingTitle => 'La operativa se está conectando';

  @override
  String marketTradeComingBodyBuy(String symbol) {
    return 'Pronto podrás comprar $symbol con dinero virtual — Cosmo ya está preparando el módulo de operaciones.';
  }

  @override
  String marketTradeComingBodySell(String symbol) {
    return 'Pronto podrás vender $symbol con dinero virtual — Cosmo ya está preparando el módulo de operaciones.';
  }

  @override
  String get assetTypeStock => 'Acción';

  @override
  String get assetTypeEtf => 'ETF';

  @override
  String get assetTypeBondEtf => 'ETF de bonos';

  @override
  String get assetTypeCrypto => 'Criptomoneda';

  @override
  String get assetTypeFiat => 'Divisa';

  @override
  String assetDescStock(String name) {
    return 'Una acción es un pequeño trozo de la empresa «$name». Al comprarla, te conviertes en copropietario del negocio: si crece, también crece tu parte. Pero también puede ir al revés, por eso las acciones se consideran un activo de riesgo medio.';
  }

  @override
  String get assetDescEtf =>
      'Un ETF es una cesta ya armada de decenas o cientos de valores a la vez. Con un clic eres dueño de un trozo de todo un mercado, no de una sola empresa. Para un principiante, es la forma más tranquila de invertir.';

  @override
  String get assetDescBondEtf =>
      'Un ETF de bonos es una cesta de préstamos a gobiernos y grandes empresas. Crece despacio, pero se mueve mucho menos que las acciones — un \"colchón de seguridad\" en la cartera.';

  @override
  String get assetDescCrypto =>
      'La criptomoneda es dinero digital sin bancos ni gobiernos. Puede subir mucho y bajar igual de fuerte: es la clase de activo más \"salvaje\", así que mantén su peso en la cartera pequeño.';

  @override
  String get assetDescFiat =>
      'Una divisa mundial normal. Aquí se muestra el precio de 100 unidades en dólares. Los tipos de cambio se mueven con más calma que las acciones, pero también afectan a la cartera.';

  @override
  String assetSectorLine(String sector) {
    return 'Sector: $sector.';
  }

  @override
  String get sectorTechnology =>
      'Tecnología — software, hardware y todo lo digital';

  @override
  String get sectorFinancial =>
      'Servicios financieros — bancos y sistemas de pago';

  @override
  String get sectorHealthcare => 'Salud — medicina y farmacéuticas';

  @override
  String get sectorConsumerDefensive =>
      'Bienes de primera necesidad — comida, bebidas, hogar';

  @override
  String get sectorConsumerCyclical =>
      'Bienes de consumo — compras \"por gusto\"';

  @override
  String get sectorCommunication => 'Comunicaciones y medios';

  @override
  String get sectorEnergy => 'Energía — petróleo y gas';

  @override
  String get sectorUtilities => 'Servicios públicos — electricidad y agua';

  @override
  String get sectorIndustrials => 'Industria — fábricas y equipamiento';

  @override
  String get assetEodTag => 'EOD';

  @override
  String get assetQuoteUnavailable => 'Cotización no disponible por ahora';

  @override
  String get assetPriceEndOfDay => 'Precio de cierre del día';

  @override
  String get assetWhatIsThisTitle => '¿Qué es esto?';

  @override
  String get assetNoChartData => 'Sin datos para este período';

  @override
  String get assetRange1D => '1D';

  @override
  String get assetRange1W => '1S';

  @override
  String get assetRange1M => '1M';

  @override
  String get assetRange1Y => '1A';

  @override
  String get assetModeLine => 'Línea';

  @override
  String get assetModeCandles => 'Velas';

  @override
  String get assetMetricsTitle => 'Métricas';

  @override
  String get assetMetricPrevClose => 'Cierre del día anterior';

  @override
  String get assetMetricPrevCloseHint =>
      'Precio en el que cerró la sesión el día anterior — de ahí se calcula el cambio diario.';

  @override
  String get assetMetricRange => 'Rango del período';

  @override
  String get assetMetricRangeHint =>
      'El precio más bajo y más alto en el período mostrado en el gráfico.';

  @override
  String assetMetricRangeValue(String min, String max) {
    return '$min – $max';
  }

  @override
  String get assetMetricAssetClass => 'Clase de activo';

  @override
  String get assetMetricAssetClassHint =>
      'A qué gran grupo de instrumentos financieros pertenece el activo.';

  @override
  String get assetMetricCurrency => 'Moneda de cotización';

  @override
  String get assetMetricCurrencyHint =>
      'En qué moneda se muestra el precio de este activo.';

  @override
  String get assetMetricUpdate => 'Actualización del precio';

  @override
  String get assetMetricUpdateRealtime => 'En tiempo real';

  @override
  String get assetMetricUpdateEod => 'Una vez al día (cierre de sesión)';

  @override
  String get assetMetricUpdateHintRealtime =>
      'El precio se obtiene de la bolsa casi al instante.';

  @override
  String get assetMetricUpdateHintEod =>
      'Este activo cotiza en una bolsa sin datos en tiempo real — actualizamos el precio una vez al día y lo marcamos honestamente como \"EOD\".';

  @override
  String get assetMetricSector => 'Sector';

  @override
  String get assetMetricSectorHint => 'El sector en el que opera la empresa.';

  @override
  String get assetSellAction => 'Vender';

  @override
  String get assetBuyAction => 'Comprar';

  @override
  String get learnScreenTitle => 'Aprende';

  @override
  String learnProgressLabel(String pct) {
    return 'Completado el $pct% del camino';
  }

  @override
  String get learnGlossaryTooltip => 'Glosario';

  @override
  String get learnEmptyTitle => 'Las lecciones aún no se cargaron';

  @override
  String get learnEmptyBody =>
      'Revisa tu conexión y abre de nuevo la pestaña \"Aprende\"';

  @override
  String get learnGlossarySheetTitle => 'Glosario';

  @override
  String get learnGlossarySearchHint => 'Buscar un término';

  @override
  String get streakStartYours => 'Empieza tu racha';

  @override
  String streakDaysInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0 seguidos';
  }

  @override
  String get streakSubtitleNone => 'Completa tu primera lección hoy';

  @override
  String get streakSubtitleDoneToday => 'Ya practicaste hoy — ¡muy bien!';

  @override
  String get streakSubtitleTodo =>
      'Completa una lección hoy para no perder tu racha';

  @override
  String streakLabelWithDays(String daysText) {
    return 'Racha: $daysText';
  }

  @override
  String get lessonCloseTooltip => 'Cerrar lección';

  @override
  String get lessonButtonDone => 'Listo';

  @override
  String get lessonButtonToQuiz => 'Al cuestionario';

  @override
  String get lessonButtonNext => 'Siguiente';

  @override
  String get lessonQuizHeader => 'PONTE A PRUEBA';

  @override
  String get lessonButtonAnswer => 'Responder';

  @override
  String get lessonButtonNextQuestion => 'Siguiente pregunta';

  @override
  String get lessonButtonFinish => 'Terminar lección';

  @override
  String get lessonCompleteTitle => '¡Lección completada!';

  @override
  String lessonScore(int correct, int total) {
    return '$correct de $total correctas';
  }

  @override
  String get lessonButtonReady => 'Listo';
}
