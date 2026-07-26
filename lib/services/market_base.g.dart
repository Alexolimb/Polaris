// СГЕНЕРИРОВАНО — РУКАМИ НЕ ПРАВИТЬ.
//
// Источник: server/data/market_base.json (версия 2026-07-25).
// Перегенерировать: node server/tools/sync_market_base.mjs
//
// Это офлайн-набор приложения: те же активы, те же базовые цены и те же
// дивиденды, что раздаёт сервер. Раньше таблицы жили в двух местах и
// разъехались (BTC $118 420 против $68 000, SOL/NFLX/ADA сервер не знал
// вовсе и подставлял $100) — портфель игрока прыгал при переключении
// онлайн↔офлайн. Для учебного продукта про деньги это подрывало доверие
// ко всем цифрам сразу.
library;

import '../models/models.dart';
import 'api.dart' show MarketTheme;

/// Версия канонических данных — сверяется с сервером в тестах.
const String marketBaseVersion = '2026-07-25';

/// Темы-подборки (фолбэк, если сервер тем не прислал). Идентификаторы
/// совпадают с assets/content/themes.*.json — по ним же работают ссылки
/// «попробовать в симуляторе» из уроков.
const List<MarketTheme> fixtureThemes = [
  MarketTheme(id: 'ai', title: 'Искусственный интеллект'),
  MarketTheme(id: 'big-tech', title: 'Большие технологии'),
  MarketTheme(id: 'semiconductors', title: 'Полупроводники'),
  MarketTheme(id: 'dividend-giants', title: 'Дивидендные гиганты'),
  MarketTheme(id: 'green-energy', title: 'Зелёная энергия'),
  MarketTheme(id: 'ev', title: 'Электромобили'),
  MarketTheme(id: 'health', title: 'Здоровье'),
  MarketTheme(id: 'finance', title: 'Финансы'),
  MarketTheme(id: 'consumer', title: 'Потребитель'),
  MarketTheme(id: 'crypto-leaders', title: 'Криптолидеры'),
  MarketTheme(id: 'broad-market', title: 'Широкий рынок (индексные ETF)'),
  MarketTheme(id: 'bonds-safety', title: 'Облигации и надёжность'),
];

/// Каталог активов офлайн-режима.
const List<Asset> fixtureAssets = [
  Asset(symbol: 'AAPL', name: 'Apple Inc.', type: AssetType.stock, sector: 'Technology', themeIds: ['big-tech', 'dividend-giants', 'consumer']),
  Asset(symbol: 'MSFT', name: 'Microsoft', type: AssetType.stock, sector: 'Technology', themeIds: ['big-tech', 'ai', 'dividend-giants']),
  Asset(symbol: 'GOOGL', name: 'Alphabet (Google)', type: AssetType.stock, sector: 'Communication Services', themeIds: ['big-tech', 'ai']),
  Asset(symbol: 'AMZN', name: 'Amazon', type: AssetType.stock, sector: 'Consumer Cyclical', themeIds: ['big-tech', 'consumer']),
  Asset(symbol: 'NVDA', name: 'NVIDIA', type: AssetType.stock, sector: 'Technology', themeIds: ['ai', 'big-tech', 'semiconductors']),
  Asset(symbol: 'META', name: 'Meta Platforms', type: AssetType.stock, sector: 'Communication Services', themeIds: ['ai', 'big-tech']),
  Asset(symbol: 'TSLA', name: 'Tesla', type: AssetType.stock, sector: 'Consumer Cyclical', themeIds: ['ev', 'green-energy']),
  Asset(symbol: 'AMD', name: 'Advanced Micro Devices', type: AssetType.stock, sector: 'Technology', themeIds: ['ai', 'semiconductors']),
  Asset(symbol: 'JPM', name: 'JPMorgan Chase', type: AssetType.stock, sector: 'Financial Services', themeIds: ['dividend-giants', 'finance']),
  Asset(symbol: 'V', name: 'Visa', type: AssetType.stock, sector: 'Financial Services', themeIds: ['finance']),
  Asset(symbol: 'JNJ', name: 'Johnson & Johnson', type: AssetType.stock, sector: 'Healthcare', themeIds: ['dividend-giants', 'health']),
  Asset(symbol: 'KO', name: 'Coca-Cola', type: AssetType.stock, sector: 'Consumer Defensive', themeIds: ['dividend-giants', 'consumer']),
  Asset(symbol: 'PG', name: 'Procter & Gamble', type: AssetType.stock, sector: 'Consumer Defensive', themeIds: ['dividend-giants', 'consumer']),
  Asset(symbol: 'XOM', name: 'Exxon Mobil', type: AssetType.stock, sector: 'Energy', themeIds: ['dividend-giants']),
  Asset(symbol: 'CVX', name: 'Chevron', type: AssetType.stock, sector: 'Energy', themeIds: ['dividend-giants']),
  Asset(symbol: 'DIS', name: 'Walt Disney', type: AssetType.stock, sector: 'Communication Services', themeIds: ['consumer']),
  Asset(symbol: 'NFLX', name: 'Netflix', type: AssetType.stock, sector: 'Communication Services', themeIds: ['consumer']),
  Asset(symbol: 'NEE', name: 'NextEra Energy', type: AssetType.stock, sector: 'Utilities', themeIds: ['green-energy', 'dividend-giants']),
  Asset(symbol: 'FSLR', name: 'First Solar', type: AssetType.stock, sector: 'Technology', themeIds: ['green-energy']),
  Asset(symbol: 'ASML', name: 'ASML Holding', type: AssetType.stock, sector: 'Technology', themeIds: ['ai', 'semiconductors'], freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'TM', name: 'Toyota Motor', type: AssetType.stock, sector: 'Consumer Cyclical', themeIds: ['ev', 'consumer'], freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'SPY', name: 'S&P 500 (SPDR)', type: AssetType.etf, sector: 'Index', themeIds: ['broad-market']),
  Asset(symbol: 'VOO', name: 'S&P 500 (Vanguard)', type: AssetType.etf, sector: 'Index', themeIds: ['broad-market', 'dividend-giants']),
  Asset(symbol: 'QQQ', name: 'Nasdaq 100 (Invesco)', type: AssetType.etf, sector: 'Index', themeIds: ['broad-market', 'big-tech']),
  Asset(symbol: 'VTI', name: 'Весь рынок США (Vanguard)', type: AssetType.etf, sector: 'Index', themeIds: ['broad-market']),
  Asset(symbol: 'SCHD', name: 'Дивидендные акции США (Schwab)', type: AssetType.etf, sector: 'Index', themeIds: ['dividend-giants']),
  Asset(symbol: 'ICLN', name: 'Чистая энергетика (iShares)', type: AssetType.etf, sector: 'Index', themeIds: ['green-energy']),
  Asset(symbol: 'BND', name: 'Облигации США (Vanguard)', type: AssetType.bondEtf, sector: 'Bonds', themeIds: ['bonds-safety']),
  Asset(symbol: 'TLT', name: 'Долгие гособлигации США (iShares)', type: AssetType.bondEtf, sector: 'Bonds', themeIds: ['bonds-safety']),
  Asset(symbol: 'BTC', name: 'Bitcoin', type: AssetType.crypto, themeIds: ['crypto-leaders']),
  Asset(symbol: 'ETH', name: 'Ethereum', type: AssetType.crypto, themeIds: ['crypto-leaders']),
  Asset(symbol: 'SOL', name: 'Solana', type: AssetType.crypto, themeIds: ['crypto-leaders']),
  Asset(symbol: 'ADA', name: 'Cardano', type: AssetType.crypto, themeIds: ['crypto-leaders']),
  Asset(symbol: 'EUR', name: 'Евро (за 100 EUR)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'GBP', name: 'Британский фунт (за 100 GBP)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'CHF', name: 'Швейцарский франк (за 100 CHF)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
  Asset(symbol: 'JPY', name: 'Японская иена (за 100 JPY)', type: AssetType.fiat, freshness: QuoteFreshness.endOfDay),
];

/// Цены офлайн-режима: (текущая, вчерашнее закрытие), в центах.
const Map<String, ({int price, int prev})> fixturePrices = {
  'AAPL': (price: 23412, prev: 23180),
  'MSFT': (price: 51230, prev: 50890),
  'GOOGL': (price: 20510, prev: 20690),
  'AMZN': (price: 24380, prev: 24010),
  'NVDA': (price: 17650, prev: 17210),
  'META': (price: 71540, prev: 72110),
  'TSLA': (price: 31220, prev: 32040),
  'AMD': (price: 19840, prev: 19510),
  'JPM': (price: 26150, prev: 26030),
  'V': (price: 31890, prev: 31760),
  'JNJ': (price: 16240, prev: 16190),
  'KO': (price: 7210, prev: 7180),
  'PG': (price: 17520, prev: 17580),
  'XOM': (price: 12470, prev: 12310),
  'CVX': (price: 16840, prev: 16720),
  'DIS': (price: 11890, prev: 11750),
  'NFLX': (price: 128740, prev: 127210),
  'NEE': (price: 8460, prev: 8390),
  'FSLR': (price: 27390, prev: 26840),
  'ASML': (price: 112450, prev: 111200),
  'TM': (price: 21230, prev: 21340),
  'SPY': (price: 63840, prev: 63510),
  'VOO': (price: 58720, prev: 58410),
  'QQQ': (price: 56210, prev: 55840),
  'VTI': (price: 31240, prev: 31090),
  'SCHD': (price: 8940, prev: 8910),
  'ICLN': (price: 3120, prev: 3060),
  'BND': (price: 7480, prev: 7490),
  'TLT': (price: 9210, prev: 9270),
  'BTC': (price: 11842000, prev: 11731000),
  'ETH': (price: 642000, prev: 631500),
  'SOL': (price: 21400, prev: 22150),
  'ADA': (price: 92, prev: 90),
  'EUR': (price: 10923, prev: 10896),
  'GBP': (price: 12704, prev: 12651),
  'CHF': (price: 11215, prev: 11168),
  'JPY': (price: 68, prev: 67),
};

/// Дивиденд на акцию, центы. Символов без выплат здесь нет.
const Map<String, int> fixtureDividendPerShare = {
  'AAPL': 26,
  'MSFT': 83,
  'JPM': 140,
  'V': 59,
  'JNJ': 124,
  'KO': 51,
  'PG': 101,
  'XOM': 99,
  'CVX': 175,
  'NEE': 57,
  'ASML': 160,
  'TM': 120,
  'SPY': 180,
  'VOO': 172,
  'QQQ': 68,
  'VTI': 95,
  'SCHD': 74,
  'BND': 18,
  'TLT': 29,
};
