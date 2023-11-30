/*
--------------------------------- DISCLAIMER ---------------------------------
Input values hardcoded in this strategy are meaningless.
These are coded in order to be able to compile the strategy.
Appropiate inputs are obtained through backtesting and parameter optimization.
------------------------------------------------------------------------------

Asset: GBPJPY

- LONG
   - Entry 1
      - Min < Lower BB
      - Close > Lower BB
      - Open > Lower BB
      - Std dev < X
      - (Possible upgrade) Compare accumulated daily std dev with current
   
   - Entry 2
      - Open < Lower BB
      - Close > Lower BB
      - Std dev < X
      - (Possible upgrade) Compare accumulated daily std dev with current

   - TP
      - Max > Upper BB
      - Open > EMA 12 && Close < EMA 12
      - Open > EMA 20 && Close < EMA 20
      - X pips

   - SL
      - X pips


- SHORT
   - Entry 1
      - Max > Upper BB
      - Close < Upper BB
      - Open < Upper BB
      - Std dev < X
      - (Possible upgrade) Compare accumulated daily std dev with current
   
   - Entry 2
      - Open > Upper BB
      - Close < Upper BB
      - Std dev < X
      - (Possible upgrade) Compare accumulated daily std dev with current

   - TP
      - Min < Lower BB
      - Open < EMA 12 && Close > EMA 12
      - Open < EMA 20 && Close > EMA 20
      - X pips

   - SL
      - X pips
     

*/

#property version     "1.00" 
#property link    "https://github.com/Xavopls"
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
sinput bool std_dev_allowed = false;            // Standard deviation is being used

enum TP_TYPE
{
    upper_bb, // Upper BB
    ema12,    // EMA 12
    ema20,    // EMA 20
    x_points  // X points
};

input TP_TYPE long_tp_type = upper_bb;          // TP Type long
input TP_TYPE short_tp_type = upper_bb;         // TP Type short

// Input variables
input float equity_percentage_per_trade = 40;   // Equity percentage per trade
input double partial_tp_ratio = 1.5;            // Ratio SL:TP of the partial exit
input double partial_percentage = 50;           // Position size in % to reduce when partially closing
input int bbs_period = 2;                       // BBs Period
input double bbs_std_dev = 2;                   // BBs Std Dev
input int std_dev_period = 20;                  // Price Std Dev Period
input double max_std_dev_value = 0.1;           // Max Std Dev to enter long
input int long_tp_pips = 10;                    // TP in Pips long
input int short_tp_pips = 10;                   // TP in Pips short
input int long_sl_pips = 300;                   // SL in Pips long
input int short_sl_pips = 300;                  // SL in Pips short
input int entry_type_long = 1;                  // Entry type long
input int entry_type_short = 1;                 // Entry type short
input int maximum_spread = 10;                  // Maximum spread allowed to operate 

int bbs_handle;
int std_dev_handle;
int ema12_handle;
int ema20_handle;

double ema12_buffer[];
double ema20_buffer[];
double bbs_upper_buffer[];
double bbs_lower_buffer[];
double std_dev_buffer[];


// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = 0;
   if(long_tp_type == x_points){
      tp = GetTpLong();
   }
   double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
   double size = 0.25;
   if(trade.Buy(size, asset, ask, sl, tp, comment)){
      pos_ticket = trade.ResultOrder();
   }
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = 0;
   if(short_tp_type == x_points){
      tp = GetTpShort();
   }
   double bid = SymbolInfoDouble(asset, SYMBOL_BID);
   double size = 0.25;
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
   switch (long_tp_type){
      case upper_bb:
         if(iHigh(asset, period, 1) > bbs_upper_buffer[1]){
            closeAllOrders();
         }
         break;
      case ema12:
         if(iOpen(asset, period, 1) > ema12_buffer[1] &&
         iClose(asset, period, 1) < ema12_buffer[1]){
            closeAllOrders();
         }
         break;
      case ema20:
         if(iOpen(asset, period, 1) > ema20_buffer[1] &&
         iClose(asset, period, 1) < ema20_buffer[1]){
            closeAllOrders();
         }
         break;
      default:
         break;
   }
}

// Check close short
void CheckExitShort(){
   switch (short_tp_type){
      case upper_bb:
         if(iLow(asset, period, 1) < bbs_lower_buffer[1]){
            closeAllOrders();
         }
         break;
      case ema12:
         if(iOpen(asset, period, 1) < ema12_buffer[1] &&
         iClose(asset, period, 1) > ema12_buffer[1]){
            closeAllOrders();
         }
         break;
      case ema20:
         if(iOpen(asset, period, 1) < ema20_buffer[1] &&
         iClose(asset, period, 1) > ema20_buffer[1]){
            closeAllOrders();
         }
         break;
      default:
         break;
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
   return(SymbolInfoDouble(asset, SYMBOL_ASK) + long_tp_pips * SymbolInfoDouble(asset, SYMBOL_POINT));
}

// Get SL of long position
double GetSlLong(){
   return(SymbolInfoDouble(asset, SYMBOL_ASK) - long_sl_pips * SymbolInfoDouble(asset, SYMBOL_POINT));
}

// Get TP of short position
double GetTpShort(){
   return(SymbolInfoDouble(asset, SYMBOL_BID) - short_tp_pips * SymbolInfoDouble(asset, SYMBOL_POINT));
}

// Get SL of short position
double GetSlShort(){
   return(SymbolInfoDouble(asset, SYMBOL_BID) + short_sl_pips * SymbolInfoDouble(asset, SYMBOL_POINT));
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
   bbs_handle = iBands(asset, period, bbs_period, 0, bbs_std_dev, PRICE_CLOSE);
   std_dev_handle = iStdDev(asset, period, std_dev_period, 0, MODE_SMA, PRICE_CLOSE);
   ema12_handle = iMA(asset, period, 12, 0, MODE_EMA, PRICE_CLOSE);
   ema20_handle = iMA(asset, period, 20, 0, MODE_EMA, PRICE_CLOSE);

   ArraySetAsSeries(ema12_buffer, true);
   ArraySetAsSeries(ema20_buffer, true);

   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){
      // Update indicators
      CopyBuffer(bbs_handle, 1, 0, 2, bbs_upper_buffer);
      CopyBuffer(bbs_handle, 2, 0, 2, bbs_lower_buffer);
      
      if(std_dev_allowed){
         CopyBuffer(std_dev_handle, 0, 0, 2, std_dev_buffer);
      }

      if(long_allowed){
         switch(long_tp_type){
            case ema12:
               CopyBuffer(ema12_handle, 0, 0, 2, ema12_buffer);
               break;
            case ema20:
               CopyBuffer(ema20_handle, 0, 0, 2, ema20_buffer);
               break;
            default:
               break;
         }
      }

      if(short_allowed){
         switch(short_tp_type){
            case ema12:
               CopyBuffer(ema12_handle, 0, 0, 2, ema12_buffer);
               break;
            case ema20:
               CopyBuffer(ema20_handle, 0, 0, 2, ema20_buffer);
               break;
            default:
               break;
         }     
      }

      if(CheckPositionOpen() == "none"){
         if(maximum_spread > SymbolInfoInteger(asset, SYMBOL_SPREAD)){
            // Check for long entries
            if(long_allowed){
               if(entry_type_long == 1){
                  if(iLow(asset, period, 1) < bbs_lower_buffer[1] &&
                  iOpen(asset, period, 1) > bbs_lower_buffer[1] &&
                  iClose(asset, period, 1) > bbs_lower_buffer[1]){
                     if(std_dev_allowed){
                        if(std_dev_buffer[1] < max_std_dev_value){
                           OpenLong("");
                        }
                     }
                     else{
                        OpenLong("");
                     }
                  }
               }
               if(entry_type_long == 2){
                  if(iOpen(asset, period, 1) < bbs_lower_buffer[1] &&
                  iClose(asset, period, 1) > bbs_lower_buffer[1]){
                     if(std_dev_allowed){
                        if(std_dev_buffer[1] < max_std_dev_value){
                           OpenLong("");
                        }
                     }
                     else{
                        OpenLong("");
                     }
                  }
               }
            }
            
            // Check for short entries
            if(short_allowed){
               if(entry_type_short == 1){
                  if(iHigh(asset, period, 1) > bbs_upper_buffer[1] &&
                  iOpen(asset, period, 1) < bbs_upper_buffer[1] &&
                  iClose(asset, period, 1) < bbs_upper_buffer[1]){
                     if(std_dev_allowed){
                        if(std_dev_buffer[1] < max_std_dev_value){
                           OpenShort("");
                        }
                     }
                     else{
                        OpenShort("");
                     }
                  }
               }

               if(entry_type_short == 2){
                  if(iOpen(asset, period, 1) > bbs_upper_buffer[1] &&
                  iClose(asset, period, 1) < bbs_upper_buffer[1]){
                     if(std_dev_allowed){
                        if(std_dev_buffer[1] < max_std_dev_value){
                           OpenShort("");
                        }
                     }
                     else{
                        OpenShort("");
                     }
                  }
               }
            }
         }
      }

      else {
         // Check if any trade has reached the partial objective
         if(partial_exits_allowed){
            CheckIfPartialClose();
         }

         // Check exits for long positions
         if(CheckPositionOpen() == "long"){
            CheckExitLong();
         }

         // Check exits for short positions
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