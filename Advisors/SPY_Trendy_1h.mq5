/*
-------------------------------------------------------
SPY
-------------------------------------------------------

- Long
   - 1h EMA 30 > 1h EMA 65 > 1h EMA 100 > 1h EMA 200 
   - 1h Low[2] < 1h EMA 200
   - 1h Close > 1h EMA 200

- TP
   - Daily RSI decreasing
   - RSI Daily[2] > X Value
- SL
   - Minimum of last X 1h candles

-------------------------------------------------------

- Short
   - 4h MACD line and Signal line decreasing
   - 4h MACD Line < 4h Signal line
   - 1h EMA 65 decreasing
   - 4h MACD line > X level (Y last candles ej 10)

- SL
   - Maximum of last X 1h candles

- TP 
   - 1h RSI Below X Level
   - 1h RSI growing
-------------------------------------------------------
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
int macd_handle_4h;
int rsi_handle_1d;
int rsi_handle_1h;

double ema_30_buffer[]; 
double ema_65_buffer[]; 
double ema_100_buffer[];
double ema_200_buffer[];
double macd_buffer_4h[];
double macd_buffer_signal_4h[];
double rsi_buffer_1d[];
double rsi_buffer_1h[];

// Inputs

// Long
sinput bool long_allowed = true;          // Long allowed
input int last_min_candles_sl_long = 7;   // Long Latest min in terms of candles
input double rsi_value_tp_long = 65;      // Long Max RSI tp value

// Short
sinput bool short_allowed = true;         // Short allowed
input double macd_level_short = 5.0;      // Short Enter MACD level
input int last_max_candles_sl_short = 7;  // Short Latest min in terms of candles
input int last_max_candles_macd = 10;     // Short Last X candles to check max MACD
input double rsi_value_tp_short = 10;     // Short Max RSI tp value

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
   if(ArraySize(rsi_buffer_1d) >= 3){
      // Check TP
      if(rsi_buffer_1d[2] > rsi_buffer_1d[1] &&
         rsi_buffer_1d[2] > rsi_value_tp_long){
            closeAllOrders();
      }
   }
}

// Check close long
void CheckExitShort(){
   if(rsi_buffer_1h[1] < rsi_value_tp_short &&
      rsi_buffer_1h[2] < rsi_buffer_1h[1]){
         closeAllOrders();
   }
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

double getLastMax(int candles){
   return(iHigh(Symbol(), Period(), iHighest(Symbol(), Period(), MODE_HIGH, candles, 1)));
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
   return(getLastMin(last_min_candles_sl_long));
}

double GetTpShort(){
   return(0);
}

// Get SL of short position
double GetSlShort(){
   return(getLastMax(last_max_candles_sl_short));
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

   macd_handle_4h = iMACD(asset, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);

   rsi_handle_1h = iRSI(asset, period, 14, PRICE_CLOSE);
   rsi_handle_1d = iRSI(asset, PERIOD_D1, 14, PRICE_CLOSE);
   
   return(INIT_SUCCEEDED);
}

void OnTick(){

   if(isNewBar()){

      // Set up indicator values
      if(TimeToString(TimeCurrent(), TIME_MINUTES)== "16:00"){
         CopyBuffer(rsi_handle_1d, 0, 0, 3, rsi_buffer_1d);
      }

      CopyBuffer(ema_30_handle, 0, 0, 3, ema_30_buffer);
      CopyBuffer(ema_65_handle, 0, 0, 3, ema_65_buffer);
      CopyBuffer(ema_100_handle, 0, 0, 3, ema_100_buffer);
      CopyBuffer(ema_200_handle, 0, 0, 3, ema_200_buffer);
      CopyBuffer(rsi_handle_1h, 0, 0, 3, rsi_buffer_1h);
      CopyBuffer(macd_handle_4h, 0, 0, last_max_candles_macd, macd_buffer_4h);
      CopyBuffer(macd_handle_4h, 0, 1, last_max_candles_macd, macd_buffer_signal_4h);

      ArraySetAsSeries(ema_30_buffer, true);
      ArraySetAsSeries(ema_65_buffer, true);
      ArraySetAsSeries(ema_100_buffer, true);
      ArraySetAsSeries(ema_200_buffer, true);
      
      if(long_allowed){
         // Check for long exits
         CheckExitLong();

         // Check for long entries
         if(ema_30_buffer[1] > ema_65_buffer[1] &&
            ema_65_buffer[1] > ema_100_buffer[1] &&
            ema_100_buffer[1] > ema_200_buffer[1] &&
            iLow(asset, period, 2) < ema_200_buffer[2] &&
            iClose(asset, period, 1) > ema_200_buffer[1]){
               OpenLong("");
         }
      }

      if(short_allowed){
         // Check for short exits
         CheckExitShort();

         // Check for short entries
         if(macd_buffer_4h[2] > macd_buffer_4h[1] &&
            macd_buffer_signal_4h[2] > macd_buffer_signal_4h[1] &&
            macd_buffer_4h[1] < macd_buffer_signal_4h[1] &&
            ema_65_buffer[2] > ema_65_buffer[1] &&
            ArrayMaximum(macd_buffer_4h, 0, last_max_candles_macd) > macd_level_short){
            OpenShort("");
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
