/*
--------------------------------- DISCLAIMER ---------------------------------
Input values hardcoded in this strategy are meaningless.
These are coded in order to be able to compile the strategy.
Appropiate inputs are obtained through backtesting and parameter optimization.
------------------------------------------------------------------------------

TP: It needs to check the type of 1h candle in which the order has been executed
It doesnt make much sense to check the current one for TP, maybe it does for pyramiding
Check market. Also maybe check other 1h EMAs, even check other TFs.

Asset: SPY

- LONG
   - Entry
      - 5m EMA 15[1] > 5m EMA 30[1] > 5m EMA 65[1] > 5m EMA 200[1] 
      - 5m EMA 65[2] < 5m EMA 200[2] 

   - TP

      Mandatory condition: (X1 < X2, X3 < X4, X5 < X6)

      - If (1h Low[1] > 1h EMA 100[1])
         - 5m EMA X1[2] > 5m EMA X2[2]
         - 5m EMA X1[1] < 5m EMA X2[1]

      - If (1h High[1] < 1h EMA 100[1])
         - 5m EMA X3[2] > 5m EMA X4[2]
         - 5m EMA X3[1] < 5m EMA X4[1]

      - If (1h High[1] > 1h EMA 100[1] &&
            1h Low[1] < 1h EMA 100[1])
         - 5m EMA X5[2] > 5m EMA X6[2]
         - 5m EMA X5[1] < 5m EMA X6[1]

   - SL
      - Lowest of last X 5M candles

- SHORT
   - Entry
      - 5m EMA 15[1] < 5m EMA 30[1] < 5m EMA 65[1] < 5m EMA 200[1] 
      - 5m EMA 65[2] > 5m EMA 200[2] 

   - TP
      - If (1h Low[1] > 1h EMA 100[1])
         - 5m EMA X1[1] > 5m EMA X2[1]
      - If (1h High[1] < 1h EMA 100[1])
         - 5m EMA X3[1] > 5m EMA X4[1]
      - If (1h High[1] > 1h EMA 100[1] &&
            1h Low[1] < 1h EMA 100[1])
         - 5m EMA X5[1] > 5m EMA X6[1]
   - SL
      - Highest of last X 5M candles
*/

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#property tester_everytick_calculate
#include <Arrays/List.mqh>
#include "../Libraries/Utils.mq5"
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

int ema_15_handle_5m;
int ema_30_handle_5m;
int ema_65_handle_5m;
int ema_200_handle_5m;
int ema_100_handle_1h;
int ema_tp_long_1_handle;
int ema_tp_long_2_handle;
int ema_tp_long_3_handle;
int ema_tp_long_4_handle;
int ema_tp_short_1_handle;
int ema_tp_short_2_handle;

double ema_15_buffer_5m[];
double ema_30_buffer_5m[]; 
double ema_65_buffer_5m[]; 
double ema_200_buffer_5m[];
double ema_100_buffer_1h[];
double ema_tp_long_1_buffer[];
double ema_tp_long_2_buffer[];
double ema_tp_long_3_buffer[];
double ema_tp_long_4_buffer[];
double ema_tp_long_5_buffer[];
double ema_tp_long_6_buffer[];
double ema_tp_short_1_buffer[];
double ema_tp_short_2_buffer[];
double ema_tp_short_3_buffer[];
double ema_tp_short_4_buffer[];
double ema_tp_short_5_buffer[];
double ema_tp_short_6_buffer[];

// Static inputs
sinput bool live_trading_allowed = false;       // Live trading allowed
sinput bool short_allowed = true;               // Short allowed
sinput bool long_allowed = true;                // Long allowed
sinput bool partial_exits_allowed = true;       // Partial exits allowed

// Input variables
input float equity_percentage_per_trade = 80;   // Equity percentage per trade
input int candles_sl_long = 6;                  // Amount of candles to get last Min for Long SL
input int candles_sl_short = 3;                 // Amount of candles to get last Min for Short SL
input double partial_tp_ratio = 4.5;            // Ratio SL:TP of the partial exit
input double partial_percentage = 75;           // Position size in % to reduce when partially closing
input int ema_tp_long_1_value = 10;             // TP Long 1
input int ema_tp_long_2_value = 10;             // TP Long 2
input int ema_tp_long_3_value = 10;             // TP Long 3
input int ema_tp_long_4_value = 10;             // TP Long 4
input int ema_tp_long_5_value = 10;             // TP Long 5
input int ema_tp_long_6_value = 10;             // TP Long 6
input int ema_tp_short_1_value = 10;            // TP Short 1
input int ema_tp_short_2_value = 10;            // TP Short 2
input int ema_tp_short_3_value = 10;            // TP Short 3
input int ema_tp_short_4_value = 10;            // TP Short 4
input int ema_tp_short_5_value = 10;            // TP Short 5
input int ema_tp_short_6_value = 10;            // TP Short 6

// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = GetTpLong();
   double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
   int size = utils.SharesToBuyPerMaxEquity(ask/5, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
   if(trade.Buy(size, asset, ask, sl, tp, comment)){
      pos_ticket = trade.ResultOrder();
   }
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = GetTpShort();
   double bid = SymbolInfoDouble(asset, SYMBOL_BID);
   int size = utils.SharesToBuyPerMaxEquity(bid/5, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
   if(trade.Sell(size, asset, bid, sl, 0, comment)){
      pos_ticket = trade.ResultOrder();
   }
}

// Close position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check for long entries
void CheckEntryLong(){
   if(ema_15_buffer_5m[1] > ema_30_buffer_5m[1] &&
   ema_30_buffer_5m[1] > ema_65_buffer_5m[1] &&
   ema_65_buffer_5m[1] > ema_200_buffer_5m[1] &&
   ema_65_buffer_5m[2] < ema_200_buffer_5m[2]){
      OpenLong("");
   }
}

// Check for short entries
void CheckEntryShort(){
   if(ema_15_buffer_5m[1] < ema_30_buffer_5m[1] &&
   ema_30_buffer_5m[1] < ema_65_buffer_5m[1] &&
   ema_65_buffer_5m[1] < ema_200_buffer_5m[1] &&
   ema_65_buffer_5m[2] > ema_200_buffer_5m[2]){
      OpenShort("");
   }
}

// Check close long
void CheckExitLong(){
   if(iLow(asset, PERIOD_H1, 1) > ema_100_buffer_1h[1]){
      if(ema_tp_long_1_buffer[2] > ema_tp_long_2_buffer[2] &&
      ema_tp_long_1_buffer[1] < ema_tp_long_2_buffer[1]){
         CloseAllLongs();
      }
   }

   else if(iHigh(asset, PERIOD_H1, 1) < ema_100_buffer_1h[1]){
      if(ema_tp_long_3_buffer[2] > ema_tp_long_4_buffer[2] &&
      ema_tp_long_3_buffer[1] < ema_tp_long_4_buffer[1]){
         CloseAllLongs();
      }
   }

   else if(iHigh(asset, PERIOD_H1, 1) > ema_100_buffer_1h[1] &&
   iLow(asset, PERIOD_H1, 1) < ema_100_buffer_1h[1]){

   }


   // Old
   // if(ema_15_buffer_5m[1] < ema_65_buffer_5m[1]){
   //    closeAllOrders();
   // }
}

// Check close short
void CheckExitShort(){  
   // TP
   if(iLow(asset, PERIOD_H1, 1) > ema_100_buffer_1h[1]){
      if(ema_tp_short_1_buffer[1] > ema_tp_short_2_buffer[1]){
         closeAllOrders();
      }
   }
   if(iLow(asset, PERIOD_H1, 1) > ema_100_buffer_1h[1]){
      if(ema_tp_short_1_buffer[1] > ema_tp_short_2_buffer[1]){
         closeAllOrders();
      }
   }
   else{
      if(ema_15_buffer_5m[1] > ema_65_buffer_5m[1]){
         closeAllOrders();
      }
   }
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

// Check if position is open, only works with 1 position opened max
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
   if(sl_ema_allowed_long){
      return(0);
   }
   else{
      return(iLow(asset, Period(), iLowest(asset, Period(), MODE_LOW, candles_sl_long, 1)));
   }
}

double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   if(sl_ema_allowed_short){
      return(0);
   }
   else{
      return(iHigh(asset, Period(), iHighest(asset, Period(), MODE_LOW, candles_sl_short, 1)));
   }
}

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

 void CloseAllLongs(){
// Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_BUY){
            trade.PositionClose(position.Ticket());
            Sleep(100);
         }
      }
   }

   // Close Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--){ 
      if(order.SelectByIndex(i)){
         if(order.OrderType() == ORDER_TYPE_BUY){
            trade.OrderDelete(order.Ticket()); 
            Sleep(100); 
         }
      }
   }

   // 2nd iteration of Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_BUY){
            trade.PositionClose(position.Ticket());
            Sleep(100);
         }
      }
   }
}

 void CloseAllShorts(){
// Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_SELL){
            trade.PositionClose(position.Ticket());
            Sleep(100);
         }
      }
   }

   // Close Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--){ 
      if(order.SelectByIndex(i)){
         if(order.OrderType() == ORDER_TYPE_SELL){
            trade.OrderDelete(order.Ticket()); 
            Sleep(100); 
         }
      }
   }

   // 2nd iteration of Close Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_SELL){
            trade.PositionClose(position.Ticket());
            Sleep(100);
         }
      }
   }
}

// Check is account is real or demo
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
bool IsAlreadyPartiallyClosed(double ticket){
   for(int i=0; i < ArraySize(partial_closed_tickets); i++){
      if(ticket == partial_closed_tickets[i]){
         return(true);
      }
   }
   return(false);
}

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

   ema_15_handle_5m = iMA(asset, period, 15, 0, MODE_EMA, PRICE_CLOSE);
   ema_30_handle_5m = iMA(asset, period, 30, 0, MODE_EMA, PRICE_CLOSE);
   ema_65_handle_5m = iMA(asset, period, 65, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle_5m = iMA(asset, period, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle_1h = iMA(asset, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema_sl_short_handle = iMA(asset, period, sl_ema_short_period, 0, MODE_EMA, PRICE_CLOSE);
   ema_sl_long_handle = iMA(asset, period, sl_ema_long_period, 0, MODE_EMA, PRICE_CLOSE);

   ArraySetAsSeries(ema_15_buffer_5m, true);
   ArraySetAsSeries(ema_30_buffer_5m, true);
   ArraySetAsSeries(ema_65_buffer_5m, true);
   ArraySetAsSeries(ema_200_buffer_5m, true);
   ArraySetAsSeries(ema_200_buffer_1h, true);
   ArraySetAsSeries(ema_sl_long_buffer, true);
   ArraySetAsSeries(ema_sl_short_buffer, true);

   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){

      CopyBuffer(ema_15_handle_5m, 0, 0, 3, ema_15_buffer_5m);
      CopyBuffer(ema_30_handle_5m, 0, 0, 3, ema_30_buffer_5m);
      CopyBuffer(ema_65_handle_5m, 0, 0, 3, ema_65_buffer_5m);
      CopyBuffer(ema_200_handle_5m, 0, 0, 3, ema_200_buffer_5m);
      CopyBuffer(ema_200_handle_1h, 0, 0, 3, ema_200_buffer_1h);
      CopyBuffer(ema_sl_long_handle, 0, 0, 3, ema_sl_long_buffer);
      CopyBuffer(ema_sl_short_handle, 0, 0, 3, ema_sl_short_buffer);

      if(CheckPositionOpen() == "none"){
         if(long_allowed){
            // Check for longs
            CheckEntryLong();
         }

         if(short_allowed){
            // Check for shorts
            CheckEntryShort();
         }
      }

      else {
         // Check if any trade has reached the partial objective
         if(partial_exits_allowed){
            CheckIfPartialClose();
         }

         if(CheckPositionOpen() == "long"){
            CheckExitLong();
         }

         if(CheckPositionOpen() == "short"){
            CheckExitShort();
         }
      }
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