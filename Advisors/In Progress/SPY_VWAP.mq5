/*
--------------------------------- DISCLAIMER ---------------------------------
Input values hardcoded in this strategy are meaningless.
These are coded in order to be able to compile the strategy.
Appropiate inputs are obtained through backtesting and parameter optimization.
------------------------------------------------------------------------------

Asset: SPY

- LONG 
   - Entry
      - Wait X candles after session starts
      - Close[1] > VWAP[1]
      - Open[1] < VWAP[1]
      - Close[1] > Open[1]
      - Close[1] / Open[1] * 100 - 100 > X
      
   - TP
      - TBD

   - SL
      - Last min from X candles
      - Check for trailing stop

   - SHORT 
      - Entry
         - Wait X candles after session starts
         - Close[1] < VWAP[1]
         - Open[1] > VWAP[1]
         - Close[1] < Open[1]
         - Open[1] / Close[1] * 100 - 100 > X
         
      - TP
         - TBD

      - SL
         - Last max from X candles
         - Check for trailing stop

*/

#property version     "1.00" 
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include "../Libraries/Utils.mq5"
#resource "\\Indicators\\VWAP.ex5"

CTrade trade;
ulong pos_ticket;
CPositionInfo position; 
COrderInfo order;
Utils utils;

// Global variables
string asset = Symbol();
ENUM_TIMEFRAMES period = Period();
bool async_trading_permitted = false;
int bars_total;
double partial_closed_tickets[];

// Static inputs
sinput bool short_allowed = false;              // Short allowed
sinput bool long_allowed = true;                // Long allowed
sinput bool partial_exits_allowed = false;      // Partial exits allowed
sinput bool live_trading_allowed = false;       // Live trading allowed

// Input variables
input float equity_percentage_per_trade = 40;   // Equity percentage per trade
input double partial_tp_ratio = 1.5;            // Ratio SL:TP of the partial exit
input double partial_percentage = 50;           // Position size in % to reduce when partially closing
input int candles_to_wait_entry = 3;            // Candles to wait after the session starts to entry
input bool wait_until_session_ends = false;     // Exit only when session ends
input bool trailing_stop_activated = false;     // Trailing stop activated
input int trailing_stop_candles_lookback = 3;   // Trailing stop candles lookback
input bool sl_session_start = false;            // SL as the first candle of session
input double bullish_candle_percentage = 1.0;   // Bullish candle size in percentage
input double bearish_candle_percentage = 1.0;   // Bearish candle size in percentage
input int candles_sl_long = 5;                  // Amount of candles to get last Min for Long SL
input int candles_sl_short = 5;                 // Amount of candles to get last Min for Short SL

// This variable depends on the asset, must check
int lots_per_unit = 5;

int vwap_daily_handle;
double vwap_daily_buffer[];
int candle_count_since_session_start = 0;
bool trading_activated = false;

// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = GetTpLong();
   double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
   int size = utils.SharesToBuyPerMaxEquity(ask / lots_per_unit, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
   if(trade.Buy(size, asset, ask, sl, tp, comment)){
      pos_ticket = trade.ResultOrder();
   }
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = GetTpShort();
   double bid = SymbolInfoDouble(asset, SYMBOL_BID);
   int size = utils.SharesToBuyPerMaxEquity(bid / lots_per_unit, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
   if(trade.Sell(size, asset, bid, sl, 0, comment)){
      pos_ticket = trade.ResultOrder();
   }
}

// Close last position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check close long
void CheckExitLong(){

}

// Check close short
void CheckExitShort(){

}

// Check if last bar is completed, eg. new bar created
bool isNewBar(){
   int bars = iBars(asset, PERIOD_CURRENT);
   if(bars_total != bars){
      bars_total = bars;
      return(true);
   }
   return(false);
}

// Check if position is open, checks the last one executed
string CheckPositionOpen(){
   PositionSelectByTicket(pos_ticket);
   int posType = (int)PositionGetInteger(POSITION_TYPE);

   if(PositionsTotal() == 0){
      return("none");
   }
   else {
      if(posType == POSITION_TYPE_BUY){
         return("long");
      }
      if(posType == POSITION_TYPE_SELL){
         return("short");
      }
   }
   return("error");
}

// Get TP of long position
double GetTpLong(){
   return(0);
}

// Get SL of long position
double GetSlLong(){
   return(iLow(asset, Period(), iLowest(asset, Period(), MODE_LOW, candles_sl_long, 1)));
}

// Get TP of short position
double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   return(iHigh(asset, Period(), iHighest(asset, Period(), MODE_LOW, candles_sl_short, 1)));
}

// Close all the open orders and positions
void closeAllOrders(){
   // Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         trade.PositionClose(position.Ticket());
         Sleep(100);
      }
   }

   // Close Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--){ 
      if(order.SelectByIndex(i)){
         trade.OrderDelete(order.Ticket()); 
         Sleep(100); 
      }
   }

   // 2nd iteration of Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         trade.PositionClose(position.Ticket()); 
         Sleep(100); 
      }
   }
}

// Check if account is real or demo
bool isAccountReal(){
   CAccountInfo account;
   long login = account.Login();
   ENUM_ACCOUNT_TRADE_MODE account_type=account.TradeMode();
   if(account_type==ACCOUNT_TRADE_MODE_REAL){
      MessageBox("Trading on a real account is forbidden, disabling","The Expert Advisor has been launched on a real account!");
      return(true);
   }
   else {
      return(false);
   }
}

// Check if current trade is already partially closed
bool IsAlreadyPartiallyClosed(double ticket){
   for(int i=0; i < ArraySize(partial_closed_tickets); i++){
      if(ticket == partial_closed_tickets[i]){
         return(true);
      }
   }
   return(false);
}

// Partial close method
void CheckIfPartialClose(){
   // Init variables 
   double 
      position_volume, 
      position_current_profit_distance, 
      position_sl_distance;

   // Loop through open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      // Select position
      if(position.SelectByIndex(i)){
         // Check if position has not already been partially closed
         if(!IsAlreadyPartiallyClosed(position.Ticket())){
            // Check if it's profitable
            if(position.Profit() > 0){
               // Get position info
               position_volume = position.Volume();
               position_current_profit_distance = MathAbs(position.PriceOpen() - position.PriceCurrent());
               position_sl_distance = MathAbs(position.PriceOpen() - position.StopLoss());

               // Check if partial profit reached
               if(position_current_profit_distance > position_sl_distance * partial_tp_ratio){
                  trade.PositionClosePartial(position.Ticket(), MathRound(position_volume * (partial_percentage / 100)));
                  ArrayResize(partial_closed_tickets, ArraySize(partial_closed_tickets) + 1);
                  ArrayFill(partial_closed_tickets, ArraySize(partial_closed_tickets)-1, 1, position.Ticket());
                  // Set a buffer to not overload the array
                  if(ArraySize(partial_closed_tickets) > 10){
                     ArrayRemove(partial_closed_tickets, 0, 1);
                  }
               }
            }
         }
      }
   }
}

int OnInit(){
   // If real account is not permitted, exit
   if(!live_trading_allowed) {
      if(isAccountReal()){
         return(-1);
      }
   }

   // Async trades setup
   trade.SetAsyncMode(async_trading_permitted);

   // Init indicators
   vwap_daily_handle = iCustom(asset, period, "::Indicators\\VWAP.ex5");
   if(vwap_daily_handle==INVALID_HANDLE){
      Print("Expert: iCustom call: Error code=", GetLastError());
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){
      
      if(CheckPositionOpen() == "none"){
         if(TimeToString(TimeCurrent(), TIME_MINUTES) == "16:35"){
            candle_count_since_session_start = 0;
            trading_activated = true;
         }
         if(TimeToString(TimeCurrent(), TIME_MINUTES) == "22:50"){
            trading_activated = false;
         }

         if(trading_activated){
            // Update indicators
            CopyBuffer(vwap_daily_handle, 1, 0, 2, vwap_daily_buffer);
            ArraySetAsSeries(vwap_daily_buffer, true);

            if(candle_count_since_session_start > candles_to_wait_entry){
               if(long_allowed){
                  // Check entries for long positions
                  if(iClose(asset, period, 1) > vwap_daily_buffer[1] &&
                  iOpen(asset, period, 1) < vwap_daily_buffer[1] &&
                  iOpen(asset, period, 1) < iClose(asset, period, 1) &&
                  (iClose(asset, period, 1) / iOpen(asset, period, 1) * 100 - 100) > bullish_candle_percentage){
                     OpenLong("");
                  }
               }

               if(short_allowed){
                  // Check entries for short positions
                  if(iClose(asset, period, 1) < vwap_daily_buffer[1] &&
                  iOpen(asset, period, 1) > vwap_daily_buffer[1] &&
                  iOpen(asset, period, 1) > iClose(asset, period, 1) &&
                  (iOpen(asset, period, 1) / iClose(asset, period, 1) * 100 - 100) > bearish_candle_percentage){
                     OpenShort("");
                  }
               }
            }
         }
      }

      else {
         if(wait_until_session_ends){
            if(TimeToString(TimeCurrent(), TIME_MINUTES) == "22:50"){
               closeAllOrders();
            }
         }

         // Check if any trade has reached the partial objective
         if(partial_exits_allowed){
            if(partial_percentage != 0){
               CheckIfPartialClose();
            }
         }
      }
      candle_count_since_session_start += 1;
   }
}

void OnTimer(){}

void OnTrade(){}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result){}

double OnTester(){return(0.0);}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){}

void OnDeinit(const int reason){EventKillTimer();}