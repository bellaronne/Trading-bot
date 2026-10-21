//+------------------------------------------------------------------+
//|                                                  FVG_Gold_EA.mq5 |
//|  Fair Value Gap retracement EA for XAUUSD (default M15).          |
//|                                                                  |
//|  Strategy                                                        |
//|   - Bullish FVG: candle1.high < candle3.low (gap between them).   |
//|     Buy limit at the gap's near (top) edge = candle3.low.         |
//|   - Bearish FVG: candle1.low > candle3.high.                      |
//|     Sell limit at the gap's near (bottom) edge = candle3.high.    |
//|   - Stop beyond the gap (candle1 extreme or far gap edge) plus a  |
//|     buffer; take profit at RewardRisk x the stop distance.        |
//|   - Lot size risks RiskPercent of balance per trade.              |
//|                                                                  |
//|   - Only trades with the higher-timeframe trend (H1 200 EMA) and  |
//|     only during the London and New York sessions.                 |
//|                                                                  |
//|   - Stop moves to breakeven once the trade is 1R in profit.       |
//|                                                                  |
//|  Safety: spread filter, max positions, unfilled orders expire,    |
//|  daily loss kill switch.                                          |
//+------------------------------------------------------------------+
#property copyright "Trading-bot"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_STOP_MODE
  {
   STOP_CANDLE1_EXTREME = 0, // Beyond candle 1's extreme (wider stop)
   STOP_GAP_FAR_EDGE    = 1  // Beyond the far edge of the gap (tighter stop)
  };

enum ENUM_SERVER_CLOCK
  {
   SERVER_CLOCK_AUTO     = 0, // Auto-detect live; fixed offset in the tester
   SERVER_CLOCK_FIXED    = 1, // Fixed GMT offset (InpServerGmtOffset)
   SERVER_CLOCK_NY_CLOSE = 2  // GMT+2, GMT+3 during US summer time
  };

//--- Strategy
input ENUM_TIMEFRAMES InpTimeframe          = PERIOD_M15;           // Signal timeframe
input double          InpMinGap             = 1.00;                 // Min gap size (price, $ for gold)
input bool            InpRequireDisplacement = true;                // Middle candle must close in gap direction
input ENUM_STOP_MODE  InpStopMode           = STOP_CANDLE1_EXTREME; // Stop placement
input double          InpStopBuffer         = 0.50;                 // Extra stop buffer (price, $ for gold)
input double          InpRewardRisk         = 2.0;                  // Take profit in R multiples
input int             InpOrderExpiryBars    = 16;                   // Cancel unfilled order after N bars
input bool            InpReplacePending     = true;                 // New FVG replaces an unfilled order

//--- Risk
input double          InpRiskPercent        = 1.0;                  // Risk per trade (% of balance)
input int             InpMaxPositions       = 1;                    // Max open positions
input double          InpMaxDailyLossPct    = 3.0;                  // Daily loss kill switch (% of day-start equity, 0 = off)
input double          InpMaxSpread          = 0.50;                 // Max spread to place orders (price, $ for gold, 0 = off)

//--- Breakeven
input bool            InpUseBreakeven       = true;                 // Move stop to breakeven
input double          InpBreakevenTriggerR  = 1.0;                  // Trigger when profit reaches N x initial risk
input double          InpBreakevenOffset    = 0.10;                 // Lock in this much past entry (price, $ for gold; covers spread)

//--- Trend filter: only trade gaps in the direction of the higher-timeframe trend
input bool            InpUseTrendFilter     = true;                 // Enable trend filter
input ENUM_TIMEFRAMES InpTrendTimeframe     = PERIOD_H1;            // Trend timeframe
input int             InpTrendMAPeriod      = 200;                  // Trend EMA period

//--- Sessions, in each city's local time (summer time handled automatically)
input bool            InpUseLondon          = true;                 // Trade the London session
input int             InpLondonStartHour    = 8;                    // London start hour, UK time (0-23)
input int             InpLondonEndHour      = 17;                   // London end hour, UK time (1-24)
input bool            InpUseNewYork         = true;                 // Trade the New York session
input int             InpNewYorkStartHour   = 8;                    // New York start hour, NY time (0-23)
input int             InpNewYorkEndHour     = 16;                   // New York end hour, NY time (1-24, before the 17:00 rollover)
input bool            InpCancelOutsideSession = true;               // Cancel unfilled orders outside the sessions

//--- Broker server clock, used to convert server time to UTC
input ENUM_SERVER_CLOCK InpServerClock      = SERVER_CLOCK_AUTO;    // Server clock
input int             InpServerGmtOffset    = 0;                    // Fixed server GMT offset in hours (Exness: 0)

//--- Misc
input ulong           InpMagic              = 20261021;             // Magic number
input string          InpComment            = "FVG";                // Order comment

CTrade   trade;
datetime g_lastBarTime    = 0;
datetime g_currentDay     = 0;
double   g_dayStartEquity = 0.0;
bool     g_haltedToday    = false;
int      g_trendMaHandle  = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
     {
      Print("RiskPercent must be in (0, 10]");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpRewardRisk <= 0 ||
      !ValidSessionHours(InpLondonStartHour, InpLondonEndHour) ||
      !ValidSessionHours(InpNewYorkStartHour, InpNewYorkEndHour))
     {
      Print("Invalid RewardRisk or session hours");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(InpUseTrendFilter)
     {
      if(InpTrendMAPeriod < 1)
        {
         Print("TrendMAPeriod must be >= 1");
         return INIT_PARAMETERS_INCORRECT;
        }
      g_trendMaHandle = iMA(_Symbol, InpTrendTimeframe, InpTrendMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_trendMaHandle == INVALID_HANDLE)
        {
         Print("Could not create trend EMA");
         return INIT_FAILED;
        }
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   // Max slippage for market closes (kill switch): $0.30, whatever the symbol's digits.
   trade.SetDeviationInPoints((ulong)MathMax(1, MathRound(0.30 / _Point)));

   ResetDailyState();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_trendMaHandle != INVALID_HANDLE)
      IndicatorRelease(g_trendMaHandle);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateDailyKillSwitch();
   if(g_haltedToday)
      return;

   ManageBreakeven();

   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;
   g_lastBarTime = barTime;

   ExpireOldOrders();

   if(!InSession())
     {
      if(InpCancelOutsideSession)
         DeleteAllPendingOrders();
      return;
     }

   CheckForFvg();
  }

//+------------------------------------------------------------------+
//| Daily loss kill switch                                            |
//+------------------------------------------------------------------+
void ResetDailyState()
  {
   g_currentDay     = iTime(_Symbol, PERIOD_D1, 0);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_haltedToday    = false;
  }

void UpdateDailyKillSwitch()
  {
   datetime day = iTime(_Symbol, PERIOD_D1, 0);
   if(day != 0 && day != g_currentDay)
      ResetDailyState();

   if(g_haltedToday || InpMaxDailyLossPct <= 0)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= g_dayStartEquity * (1.0 - InpMaxDailyLossPct / 100.0))
     {
      PrintFormat("Daily loss limit hit (equity %.2f, day start %.2f). Flattening and halting until tomorrow.",
                  equity, g_dayStartEquity);
      CloseAllPositions();
      DeleteAllPendingOrders();
      g_haltedToday = true;
     }
  }

//+------------------------------------------------------------------+
//| Breakeven: once price moves TriggerR x the initial risk in our    |
//| favour, move the stop to entry (+ offset). Runs every tick.       |
//+------------------------------------------------------------------+
void ManageBreakeven()
  {
   if(!InpUseBreakeven)
      return;

   double offset  = InpBreakevenOffset;
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                    SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         PositionGetInteger(POSITION_MAGIC) != (long)InpMagic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      if(sl == 0)
         continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double newSl;
      if(isBuy)
        {
         // Stop still below entry means it hasn't been moved yet; its distance is the initial risk.
         if(sl >= entry || bid - entry < InpBreakevenTriggerR * (entry - sl))
            continue;
         newSl = NormalizePrice(entry + offset);
         if(newSl <= sl || bid - newSl < minDist)
            continue;
        }
      else
        {
         if(sl <= entry || entry - ask < InpBreakevenTriggerR * (sl - entry))
            continue;
         newSl = NormalizePrice(entry - offset);
         if(newSl >= sl || newSl - ask < minDist)
            continue;
        }

      if(trade.PositionModify(ticket, newSl, tp))
         PrintFormat("Breakeven: position %I64u stop moved to %.2f", ticket, newSl);
      else
         PrintFormat("Breakeven modify failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| Signal detection                                                  |
//+------------------------------------------------------------------+
void CheckForFvg()
  {
   // Last three closed bars: shift 3 = candle 1, shift 2 = candle 2, shift 1 = candle 3.
   double h1 = iHigh(_Symbol, InpTimeframe, 3), l1 = iLow(_Symbol, InpTimeframe, 3);
   double o2 = iOpen(_Symbol, InpTimeframe, 2), c2 = iClose(_Symbol, InpTimeframe, 2);
   double h3 = iHigh(_Symbol, InpTimeframe, 1), l3 = iLow(_Symbol, InpTimeframe, 1);
   if(h1 == 0 || l1 == 0 || h3 == 0 || l3 == 0)
      return;

   double minGap = InpMinGap;
   double buffer = InpStopBuffer;

   bool bullGap = (l3 - h1 >= minGap && (!InpRequireDisplacement || c2 > o2));
   bool bearGap = (l1 - h3 >= minGap && (!InpRequireDisplacement || c2 < o2));
   if(!bullGap && !bearGap)
      return;

   if(!TrendAllows(bullGap))
     {
      PrintFormat("Skip %s FVG: against the %s trend", bullGap ? "bullish" : "bearish",
                  EnumToString(InpTrendTimeframe));
      return;
     }

   // Bullish FVG
   if(bullGap)
     {
      double entry = l3;
      double sl    = (InpStopMode == STOP_CANDLE1_EXTREME ? l1 : h1) - buffer;
      double tp    = entry + InpRewardRisk * (entry - sl);
      PlaceOrder(ORDER_TYPE_BUY_LIMIT, entry, sl, tp);
     }
   // Bearish FVG
   else if(bearGap)
     {
      double entry = h3;
      double sl    = (InpStopMode == STOP_CANDLE1_EXTREME ? h1 : l1) + buffer;
      double tp    = entry - InpRewardRisk * (sl - entry);
      PlaceOrder(ORDER_TYPE_SELL_LIMIT, entry, sl, tp);
     }
  }

//+------------------------------------------------------------------+
//| Order placement                                                   |
//+------------------------------------------------------------------+
void PlaceOrder(ENUM_ORDER_TYPE type, double entry, double sl, double tp)
  {
   if(CountPositions() >= InpMaxPositions)
      return;

   if(CountPendingOrders() > 0)
     {
      if(!InpReplacePending)
         return;
      DeleteAllPendingOrders();
     }

   if(InpMaxSpread > 0)
     {
      double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(spread > InpMaxSpread)
        {
         PrintFormat("Skip FVG: spread %.3f > max %.3f", spread, InpMaxSpread);
         return;
        }
     }

   entry = NormalizePrice(entry);
   sl    = NormalizePrice(sl);
   tp    = NormalizePrice(tp);

   // A limit order must sit beyond the current price by at least the broker's stops level.
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minDist   = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   bool   isBuy     = (type == ORDER_TYPE_BUY_LIMIT);
   if(( isBuy && entry > ask - minDist) || (!isBuy && entry < bid + minDist))
     {
      PrintFormat("Skip FVG: price already at the gap edge (entry %.2f, bid %.2f, ask %.2f)", entry, bid, ask);
      return;
     }

   double lots = CalculateLots(type, entry, sl);
   if(lots <= 0)
      return;

   string comment = StringFormat("%s %s", InpComment, isBuy ? "bull" : "bear");
   bool ok = isBuy
             ? trade.BuyLimit(lots, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment)
             : trade.SellLimit(lots, entry, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);

   if(ok)
      PrintFormat("%s limit %.2f lots @ %.2f SL %.2f TP %.2f", isBuy ? "Buy" : "Sell", lots, entry, sl, tp);
   else
      PrintFormat("Order failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| Position sizing: lose RiskPercent of balance if the stop is hit   |
//+------------------------------------------------------------------+
double CalculateLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;

   double lossPerLot = 0.0;
   ENUM_ORDER_TYPE calcType = (type == ORDER_TYPE_BUY_LIMIT) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(calcType, _Symbol, 1.0, entry, sl, lossPerLot) || lossPerLot >= 0)
     {
      Print("Could not calculate loss per lot");
      return 0.0;
     }
   lossPerLot = MathAbs(lossPerLot);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lots = MathFloor((riskMoney / lossPerLot) / stepLot) * stepLot;
   if(lots < minLot)
     {
      // Never round up to the minimum lot: that would risk more than RiskPercent.
      PrintFormat("Skip FVG: required lots %.4f below broker minimum %.2f", riskMoney / lossPerLot, minLot);
      return 0.0;
     }
   lots = MathMin(lots, maxLot);

   int volDigits = (int)MathMax(0, MathCeil(-MathLog10(stepLot)));
   return NormalizeDouble(lots, volDigits);
  }

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0)
      price = MathRound(price / tick) * tick;
   return NormalizeDouble(price, _Digits);
  }

// Longs only while the last closed trend-timeframe bar closed above the EMA,
// shorts only while it closed below. Blocks both if the EMA isn't ready yet.
bool TrendAllows(bool isBuy)
  {
   if(!InpUseTrendFilter)
      return true;

   double ema[1];
   if(CopyBuffer(g_trendMaHandle, 0, 1, 1, ema) != 1)
      return false;
   double close = iClose(_Symbol, InpTrendTimeframe, 1);
   if(close == 0)
      return false;
   return isBuy ? close > ema[0] : close < ema[0];
  }

bool ValidSessionHours(int startHour, int endHour)
  {
   return startHour >= 0 && startHour <= 23 && endHour >= 1 && endHour <= 24 && startHour != endHour;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour < endHour)
      return hour >= startHour && hour < endHour;
   // Window wraps past midnight, e.g. 22 -> 6
   return hour >= startHour || hour < endHour;
  }

//--- Time zone helpers. MQL5 has no time zone database, so the UK and US
//--- summer-time rules are coded directly.
datetime MakeUtc(int year, int month, int day, int hour)
  {
   MqlDateTime t;
   ZeroMemory(t);
   t.year = year;
   t.mon  = month;
   t.day  = day;
   t.hour = hour;
   return StructToTime(t);
  }

int DayOfWeek(datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.day_of_week; // 0 = Sunday
  }

datetime FirstSunday(int year, int month)
  {
   datetime first = MakeUtc(year, month, 1, 0);
   return first + ((7 - DayOfWeek(first)) % 7) * 86400;
  }

datetime LastSunday(int year, int month)
  {
   datetime last = (month == 12 ? MakeUtc(year + 1, 1, 1, 0) : MakeUtc(year, month + 1, 1, 0)) - 86400;
   return last - DayOfWeek(last) * 86400;
  }

int YearOf(datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.year;
  }

// UK summer time: last Sunday of March 01:00 UTC to last Sunday of October 01:00 UTC.
bool UkSummerTime(datetime utc)
  {
   int y = YearOf(utc);
   return utc >= LastSunday(y, 3) + 3600 && utc < LastSunday(y, 10) + 3600;
  }

// US summer time: second Sunday of March 02:00 EST (07:00 UTC) to first Sunday of November 02:00 EDT (06:00 UTC).
bool UsSummerTime(datetime utc)
  {
   int y = YearOf(utc);
   return utc >= FirstSunday(y, 3) + 7 * 86400 + 7 * 3600 && utc < FirstSunday(y, 11) + 6 * 3600;
  }

datetime ServerToUtc(datetime server)
  {
   switch(InpServerClock)
     {
      case SERVER_CLOCK_NY_CLOSE:
         // Check summer time against the winter offset; only wrong for the hour of the switch.
         return server - (UsSummerTime(server - 2 * 3600) ? 3 : 2) * 3600;
      case SERVER_CLOCK_AUTO:
         if(!MQLInfoInteger(MQL_TESTER))
           {
            // TimeGMT() comes from the local PC clock; round the offset to 15 minutes.
            long offset = (long)MathRound((double)(TimeTradeServer() - TimeGMT()) / 900.0) * 900;
            return server - (datetime)offset;
           }
         // The tester has no real GMT, so fall through to the fixed offset.
      default:
         return server - InpServerGmtOffset * 3600;
     }
  }

int LocalHour(datetime utc, int winterOffset, bool summer)
  {
   MqlDateTime s;
   TimeToStruct(utc + (winterOffset + (summer ? 1 : 0)) * 3600, s);
   return s.hour;
  }

bool InSession()
  {
   datetime utc = ServerToUtc(TimeCurrent());
   return (InpUseLondon  && HourInWindow(LocalHour(utc,  0, UkSummerTime(utc)), InpLondonStartHour,  InpLondonEndHour)) ||
          (InpUseNewYork && HourInWindow(LocalHour(utc, -5, UsSummerTime(utc)), InpNewYorkStartHour, InpNewYorkEndHour));
  }

bool IsOurOrder(ulong ticket)
  {
   return OrderSelect(ticket) &&
          OrderGetInteger(ORDER_MAGIC) == (long)InpMagic &&
          OrderGetString(ORDER_SYMBOL) == _Symbol;
  }

int CountPendingOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(IsOurOrder(OrderGetTicket(i)))
         count++;
   return count;
  }

int CountPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
     }
   return count;
  }

void ExpireOldOrders()
  {
   int maxAge = InpOrderExpiryBars * PeriodSeconds(InpTimeframe);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!IsOurOrder(ticket))
         continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - setup >= maxAge)
         trade.OrderDelete(ticket);
     }
  }

void DeleteAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(IsOurOrder(ticket))
         trade.OrderDelete(ticket);
     }
  }

void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         trade.PositionClose(ticket);
     }
  }
//+------------------------------------------------------------------+
