/*
--------------------------------- DISCLAIMER ---------------------------------
Input values hardcoded in this strategy are meaningless.
These are coded in order to be able to compile the strategy.
Appropiate inputs are obtained through backtesting and parameter optimization.
------------------------------------------------------------------------------

Asset: X
Timeframe: Y

- LONG
   - Entry
      
   - TP

   - SL


- SHORT
   - Entry
      
   - TP
     
   - SL
     

*/
#property version     "1.00" 
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include "../../Libraries/Utils.mq5"

CTrade trade;
ulong pos_ticket;
CPositionInfo position; 
COrderInfo order;
Utils utils;

enum TRAILING_STOP_TYPE {
   swing,
   percentage,
   points,
   volatility,
   ema
};

// Global variables
string asset = Symbol();
ENUM_TIMEFRAMES period = Period();
bool async_trading_permitted = false;
int bars_total;
double partial_closed_tickets[];

// Static inputs
sinput bool short_allowed = true;               // Short allowed
sinput bool long_allowed = true;                // Long allowed
sinput bool partial_exits_allowed = true;       // Partial exits allowed
sinput bool live_trading_allowed = false;       // Live trading allowed
sinput bool trailing_stop_allowed = false;      // Trailing stop allowed

// Input variables
input float equity_percentage_per_trade = 40;   // Equity percentage per trade
input double partial_tp_ratio = 1.5;            // Ratio SL:TP of the partial exit
input double partial_percentage = 50;           // Position size in % to reduce when partially closing
input TRAILING_STOP_TYPE ts_type = swing;       // Trailing stop type
input int ts_swing_candles_long = 3;            // Swing TS Long Candles            
input int ts_swing_candles_short = 3;            // Swing TS Short Candles            

// This variable depends on the asset, must check
int lots_per_unit = 5;

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

// Check if last bar is completed, eg. new bar created
bool isNewBar(){
   int bars = iBars(asset, PERIOD_CURRENT);
   if(bars_total != bars){
      bars_total = bars;
      return(true);
   }
   return(false);
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

// Close all the open Long orders and Long positions
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

// Close all the open Short orders and Short positions
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

// Get TP of long position
double GetTpLong(){
   return(0);
}

// Get SL of long position
double GetSlLong(){
   if(trailing_stop_allowed){
      switch (ts_type)
      {
      case swing:
         return(iLow(asset, period, iLowest(asset, period, MODE_LOW, ts_swing_candles_long, 1)));
         break;
      
      default:
         return(0);
         break;
      }
   }
   else{
      return(0);
   }
}

// Get TP of short position
double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   if(trailing_stop_allowed){
      switch (ts_type)
      {
      case swing:
         return(iHigh(asset, period, iHighest(asset, period, MODE_HIGH, ts_swing_candles_short, 1)));
         break;
      
      default:
         return(0);
         break;
      }
   }
   else{
      return(0);
   }
}

// Check entry long
void CheckEntryLong(){
   // Check conditions for long orders
   if(false){
      OpenLong("");
   }
}

// Check entry short
void CheckEntryShort(){
   // Check conditions for short orders
   if(false){
      OpenShort("");
   }
}

// Check close long
void CheckExitLong(){
   if(trailing_stop_allowed){
      ModifyTrailingStop(ts_type);
   }
   else{

   }
}

// Check close short
void CheckExitShort(){
   if(trailing_stop_allowed){
      ModifyTrailingStop(ts_type);
   }
   else{
      
   }
}

// Returns true if longs are open
bool AreLongsOpen(){
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_BUY){
            return(true);
         }
      }
   }
   return(false);
}

// Returns true if shorts are open
bool AreShortsOpen(){
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         if(position.PositionType() == POSITION_TYPE_SELL){
            return(true);
         }
      }
   }
   return(false);
}

// Swing TS method
void TrailingStopSwing(){
   // Loop through open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--){ 
      if(position.SelectByIndex(i)){
         // Long position open
         if(position.PositionType() == POSITION_TYPE_BUY){
            double new_sl = iLow(asset, period, iLowest(asset, period, MODE_LOW, ts_swing_candles_long, 1));
            if(new_sl >= position.StopLoss()){
               trade.PositionModify(position.Ticket(), new_sl, 0);
            }          
         }
         // Short position open
         if(position.PositionType() == POSITION_TYPE_SELL){
            double new_sl = iHigh(asset, period, iHighest(asset, period, MODE_HIGH, ts_swing_candles_short, 1));
            if(new_sl <= position.StopLoss()){
               trade.PositionModify(position.Ticket(), new_sl, 0);
            }    
         }
      }
   }
}

// Price percentage TS method
void TrailingStopPercentage(){

}

// Price points (or pips) TS method
void TrailingStopPoints(){

}

// Volatility using ATR TS method
void TrailingStopVolatility(){

}

// EMA TS method
void TrailingStopEMA(){

}

// Trailing stop update method
void ModifyTrailingStop(TRAILING_STOP_TYPE type){
   switch (type){
      case swing:
         TrailingStopSwing();
         break;

      case percentage:
         TrailingStopPercentage();
         break;

      case points:
         TrailingStopPoints();
         break;

      case volatility:
         TrailingStopVolatility();
         break;

      case ema:
         TrailingStopEMA();
         break;

      default:
         break;
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
   // -----
   // -----
   // -----

   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){
      // Update generic indicators
      // --------
      // --------
      // --------
      // --------

      if(long_allowed){
         // Update Long indicators
         // --------
         // --------
         // --------

         // Check entry conditions for long orders
         CheckEntryLong();
         // Check if any long position is already open
         if(AreLongsOpen()){
            // Check if longs TPs reached
            CheckExitLong();
         }
      }

      if(short_allowed){
         // Update Short indicators
         // --------
         // --------
         // --------
         
         // Check entry conditions for long orders
         CheckEntryShort();
         // Check if any short position is already open
         if(AreShortsOpen()){
            // Check if shorts TPs reached
            CheckExitShort();
         }
      }

      // Check if any trade has reached the partial objective
      if(partial_exits_allowed){
         CheckIfPartialClose();
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