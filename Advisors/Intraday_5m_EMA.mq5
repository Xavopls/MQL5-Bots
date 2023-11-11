/*
- LONG
   - Entry
      - 5m EMA 15[1] > 5m EMA 30[1] > 5m EMA 65[1] > 5m EMA 200[1] 
      - 5m EMA 65[2] < 5m EMA 200[2] 

   - Pyramiding (TBD)
      - 5m bullish candle 
      - Min and Open < 5m EMA 65 
      - Close > 5m EMA 65
      - 5m EMA 15 < 5m EMA 30

   - TP
      - 5m EMA 15[1] < 5m EMA 65[1]

   - SL
      - Minimum of last X 5M candles
*/

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#property tester_everytick_calculate


CTrade trade;
ulong pos_ticket;
CPositionInfo position; 
COrderInfo order;


// Global variables
float pos_size = 80;
string asset = Symbol();
ENUM_TIMEFRAMES period = Period();
bool real_account_permitted = false;
bool async_trading_permitted = false;
int bars_total;

int ema_15_handle_5m;
int ema_30_handle_5m;
int ema_65_handle_5m;
int ema_200_handle_5m;
int rsi_handle_5m;
double ema_15_buffer_5m[];
double ema_30_buffer_5m[]; 
double ema_65_buffer_5m[]; 
double ema_200_buffer_5m[];
double rsi_buffer_5m[];

// Input variables
int candles_sl_long = 5; // Amount of candles to get last Min for Long SL
int candles_sl_short = 5; // Amount of candles to get last Min for Short SL


// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = GetTpLong();
   double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
   trade.Buy(pos_size, asset, ask, sl, tp, comment);
   pos_ticket = trade.ResultOrder();
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = GetTpShort();
   double bid = SymbolInfoDouble(asset, SYMBOL_BID);
   trade.Sell(pos_size, asset, bid, sl, 0, comment);
   pos_ticket = trade.ResultOrder();
}

// Close position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check close long
void CheckExitLong(){

}

// Check close long
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
   return(iLow(Symbol(), Period(), iLowest(Symbol(), Period(), MODE_LOW, candles_sl_long, 1)));
}

double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   return(iHigh(Symbol(), Period(), iHighest(Symbol(), Period(), MODE_LOW, candles_sl_short, 1)));
}

void closeAllOrders(){
   for(int i = PositionsTotal() - 1; i >= 0; i--) // loop all Open Positions
      if(position.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(position.Ticket()); // then close it --period
         Sleep(100); // Relax for 100 ms
        }
   //--End  Positions

   //-- Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--) // loop all Orders
      if(order.SelectByIndex(i))  // select an order
        {
         trade.OrderDelete(order.Ticket()); // then delete it --period
         Sleep(100); // Relax for 100 ms
        }
   //--End 
   //-- Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) // loop all Open Positions
      if(position.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(position.Ticket()); // then close it --period
         Sleep(100); // Relax for 100 ms
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

int OnInit(){
   // If real account is not permitted, exit
   if(!real_account_permitted) {
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

   ArraySetAsSeries(ema_15_buffer_5m, true);
   ArraySetAsSeries(ema_30_buffer_5m, true);
   ArraySetAsSeries(ema_65_buffer_5m, true);
   ArraySetAsSeries(ema_200_buffer_5m, true);

   return(INIT_SUCCEEDED);
}




void OnTick(){
   if(isNewBar()){

      CopyBuffer(ema_15_handle_5m, 0, 0, 3, ema_15_buffer_5m);
      CopyBuffer(ema_30_handle_5m, 0, 0, 3, ema_30_buffer_5m);
      CopyBuffer(ema_65_handle_5m, 0, 0, 3, ema_65_buffer_5m);
      CopyBuffer(ema_200_handle_5m, 0, 0, 3, ema_200_buffer_5m);

      if(CheckPositionOpen() == "none"){
         // Check for longs
         if(ema_15_buffer_5m[1] > ema_30_buffer_5m[1] &&
         ema_30_buffer_5m[1] > ema_65_buffer_5m[1] &&
         ema_65_buffer_5m[1] > ema_200_buffer_5m[1] &&
         ema_65_buffer_5m[2] < ema_200_buffer_5m[2]){
            OpenLong("");
         }

         // Check for shorts
         if(ema_15_buffer_5m[1] < ema_30_buffer_5m[1] &&
         ema_30_buffer_5m[1] < ema_65_buffer_5m[1] &&
         ema_65_buffer_5m[1] < ema_200_buffer_5m[1] &&
         ema_65_buffer_5m[2] > ema_200_buffer_5m[2]){
            OpenShort("");
         }
      }

      if(CheckPositionOpen() == "long"){
         // // Check if add position
         // if(iOpen(asset, period, 1) < iClose(asset, period, 1) &&
         // iLow(asset, period, 1) < ema_65_buffer_5m[1] &&
         // iOpen(asset, period, 1) < ema_65_buffer_5m[1] &&
         // iClose(asset, period, 1) > ema_65_buffer_5m[1] &&
         // ema_15_buffer_5m[1] < ema_30_buffer_5m[1]){
         //    OpenLong("");
         // }

         // Check TP
         if(ema_15_buffer_5m[1] < ema_65_buffer_5m[1]){
            closeAllOrders();
         }
      }

      if(CheckPositionOpen() == "short"){
         // Check TP
         if(ema_15_buffer_5m[1] > ema_65_buffer_5m[1]){
            closeAllOrders();
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
