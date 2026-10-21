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
//|  Safety: spread filter, session filter, max positions, unfilled   |
//|  orders expire, daily loss kill switch.                           |
//+------------------------------------------------------------------+
#property copyright "Trading-bot"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_STOP_MODE
  {
   STOP_CANDLE1_EXTREME = 0, // Beyond candle 1's extreme (wider stop)
   STOP_GAP_FAR_EDGE    = 1  // Beyond the far edge of the gap (tighter stop)
  };

//--- Strategy
input ENUM_TIMEFRAMES InpTimeframe          = PERIOD_M15;           // Signal timeframe
input double          InpMinGapPoints       = 100;                  // Min gap size (points)
input bool            InpRequireDisplacement = true;                // Middle candle must close in gap direction
input ENUM_STOP_MODE  InpStopMode           = STOP_CANDLE1_EXTREME; // Stop placement
input double          InpStopBufferPoints   = 50;                   // Extra stop buffer (points)
input double          InpRewardRisk         = 2.0;                  // Take profit in R multiples
input int             InpOrderExpiryBars    = 16;                   // Cancel unfilled order after N bars
input bool            InpReplacePending     = true;                 // New FVG replaces an unfilled order

//--- Risk
input double          InpRiskPercent        = 1.0;                  // Risk per trade (% of balance)
input int             InpMaxPositions       = 1;                    // Max open positions
input double          InpMaxDailyLossPct    = 3.0;                  // Daily loss kill switch (% of day-start equity, 0 = off)
input double          InpMaxSpreadPoints    = 50;                   // Max spread to place orders (points, 0 = off)

//--- Session (broker server time)
input int             InpSessionStartHour   = 0;                    // Session start hour (0-23)
input int             InpSessionEndHour     = 24;                   // Session end hour (1-24)

//--- Misc
input ulong           InpMagic              = 20261021;             // Magic number
input string          InpComment            = "FVG";                // Order comment

CTrade   trade;
datetime g_lastBarTime    = 0;
datetime g_currentDay     = 0;
double   g_dayStartEquity = 0.0;
bool     g_haltedToday    = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
     {
      Print("RiskPercent must be in (0, 10]");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpRewardRisk <= 0 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 1 || InpSessionEndHour > 24)
     {
      Print("Invalid RewardRisk or session hours");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(30);

   ResetDailyState();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateDailyKillSwitch();
   if(g_haltedToday)
      return;

   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime == 0 || barTime == g_lastBarTime)
      return;
   g_lastBarTime = barTime;

   ExpireOldOrders();

   if(!InSession())
      return;

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

   double minGap = InpMinGapPoints * _Point;
   double buffer = InpStopBufferPoints * _Point;

   // Bullish FVG
   if(l3 - h1 >= minGap && (!InpRequireDisplacement || c2 > o2))
     {
      double entry = l3;
      double sl    = (InpStopMode == STOP_CANDLE1_EXTREME ? l1 : h1) - buffer;
      double tp    = entry + InpRewardRisk * (entry - sl);
      PlaceOrder(ORDER_TYPE_BUY_LIMIT, entry, sl, tp);
     }
   // Bearish FVG
   else if(l1 - h3 >= minGap && (!InpRequireDisplacement || c2 < o2))
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

   if(InpMaxSpreadPoints > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPoints)
        {
         PrintFormat("Skip FVG: spread %d > max %.0f points", (int)spread, InpMaxSpreadPoints);
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

bool InSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpSessionStartHour < InpSessionEndHour)
      return dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour;
   // Session wraps past midnight, e.g. 22 -> 6
   return dt.hour >= InpSessionStartHour || dt.hour < InpSessionEndHour;
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
