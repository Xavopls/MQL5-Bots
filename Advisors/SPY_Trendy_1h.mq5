/*
SPY - 1h
*/

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#property tester_everytick_calculate


CTrade trade;
COrderInfo order;
CPositionInfo position; 
ulong pos_ticket;

// Global variables
double pos_size = 10;
string asset = "SPY";
ENUM_TIMEFRAMES period = PERIOD_H1;
bool real_account_permitted = false;
bool async_trading_permitted = false;

int bars_total;
int ema_30_handle; 
int ema_65_handle; 
int ema_100_handle;
int ema_200_handle;
int rsi_handle;
double ema_30_buffer[]; 
double ema_65_buffer[]; 
double ema_100_buffer[];
double ema_200_buffer[];
double rsi_buffer[];

// Inputs
input int last_min_candles = 7;      // Latest min in terms of candles
input double rsi_tp_value = 65;      // Max RSI tp value



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
   // Check if we have enough daily data to close the trade
   if(ArraySize(rsi_buffer) >= 3){
      // Check TP
      if(rsi_buffer[2] > rsi_buffer[1] &&
         rsi_buffer[2] > rsi_tp_value){
            closeAllOrders();
      }
   }
}

// Check close long
void CheckExitShort(){

}

void closeAllOrders(){
   //--Đóng Positions
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


// Check if last bar is completed, eg. new bar created
bool isNewBar(){
   int bars = iBars(asset, PERIOD_CURRENT);
   if(bars_total != bars){
      bars_total = bars;
      return(true);
   }
   return(false);
}


double getLastMin(int candles){
   return(iLow(Symbol(), Period(), iLowest(Symbol(), Period(), MODE_LOW, candles, 1)));
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
   return(getLastMin(last_min_candles));
}

double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   return(0);
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

   // Init indicators
   ema_30_handle = iMA(asset, period, 30, 0, MODE_EMA, PRICE_CLOSE);
   ema_65_handle = iMA(asset, period, 65, 0, MODE_EMA, PRICE_CLOSE);
   ema_100_handle = iMA(asset, period, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle = iMA(asset, period, 200, 0, MODE_EMA, PRICE_CLOSE);

   rsi_handle = iRSI(asset, PERIOD_D1, 14, PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}




void OnTick(){

   if(isNewBar()){

      // Set up indicator values
      if(TimeToString(TimeCurrent(), TIME_MINUTES)== "16:00"){
         CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer);
      }

      CopyBuffer(ema_30_handle, 0, 0, 3, ema_30_buffer);
      CopyBuffer(ema_65_handle, 0, 0, 3, ema_65_buffer);
      CopyBuffer(ema_100_handle, 0, 0, 3, ema_100_buffer);
      CopyBuffer(ema_200_handle, 0, 0, 3, ema_200_buffer);

      ArraySetAsSeries(ema_30_buffer, true);
      ArraySetAsSeries(ema_65_buffer, true);
      ArraySetAsSeries(ema_100_buffer, true);
      ArraySetAsSeries(ema_200_buffer, true);

      // Check for exits
      CheckExitLong();

      // Check for entries
      if(ema_30_buffer[1] > ema_65_buffer[1] &&
         ema_65_buffer[1] > ema_100_buffer[1] &&
         ema_100_buffer[1] > ema_200_buffer[1] &&
         iLow(asset, period, 2) < ema_200_buffer[2] &&
         iClose(asset, period, 1) > ema_200_buffer[1]){
            OpenLong("");
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
