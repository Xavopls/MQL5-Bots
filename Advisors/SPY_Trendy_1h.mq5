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
   - 1h EMA 30 < 1h EMA 65 < 1h EMA 100 < 1h EMA 200
   - X amount of 1d candles where the min < 1d EMA 100 
   - (Boolean) BEARISH candle crossing EMA 100? (Boolean) gaps allowed?
   - EMA 200 - EMA 100 > X
   - (Boolean) 1h EMA 30?
- SL
   - Maximum of last X 1h candles
   - If current price is higher than last max, add X to open price

- TP 
   - Trailing stop?
   - TBD
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
int ema_30_handle_1h; 
int ema_65_handle_1h; 
int ema_100_handle_1h;
int ema_200_handle_1h;
int ema_100_handle_1d;
int macd_handle_4h;
int rsi_handle_1d;
int rsi_handle_1h;

double ema_30_buffer_1h[]; 
double ema_65_buffer_1h[]; 
double ema_100_buffer_1h[];
double ema_200_buffer_1h[];
double ema_100_buffer_1d[];

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
sinput bool short_allowed = false;              // Short allowed
input int candles_lookback_crossed_ema = 3;     // Candle amount to lookback when crossed EMA
input bool bearish_only_crossed_ema = true;     // Candle that crossed ema only bearish?
input bool gaps_allowed_crossed_ema = true;     // Gaps allowed in the crossed ema?
input double diff_ema200_ema100 = 10;           // Minimum difference between EMA 200 and EMA 100
input bool ema_30_allowed = true;               // EMA 30 allowed?
input int last_max_candles_sl_short = 10;       // Amount of candles to get last maximum (SL)


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
   if(true){ //TBD
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

bool crossedEma100(){

   return(true);
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
   ema_30_handle_1h = iMA(asset, period, 30, 0, MODE_EMA, PRICE_CLOSE);
   ema_65_handle_1h = iMA(asset, period, 65, 0, MODE_EMA, PRICE_CLOSE);
   ema_100_handle_1h = iMA(asset, period, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle_1h = iMA(asset, period, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema_100_handle_1d = iMA(asset, PERIOD_D1, 100, 0, MODE_EMA, PRICE_CLOSE);

   macd_handle_4h = iMACD(asset, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);

   rsi_handle_1h = iRSI(asset, period, 14, PRICE_CLOSE);
   rsi_handle_1d = iRSI(asset, PERIOD_D1, 14, PRICE_CLOSE);
   
   ArraySetAsSeries(ema_30_buffer_1h, true);
   ArraySetAsSeries(ema_65_buffer_1h, true);
   ArraySetAsSeries(ema_100_buffer_1h, true);
   ArraySetAsSeries(ema_200_buffer_1h, true);
   ArraySetAsSeries(ema_100_buffer_1d, true);
   ArraySetAsSeries(macd_buffer_4h, true);
   ArraySetAsSeries(macd_buffer_signal_4h, true);
   ArraySetAsSeries(rsi_buffer_1d, true);
   ArraySetAsSeries(rsi_buffer_1h, true);

   return(INIT_SUCCEEDED);
}

void OnTick(){

   if(isNewBar()){

      // if(TimeToString(TimeCurrent(), TIME_DATE)== "2022.08.19" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.08.22" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.08.23" ){}

      // Set up indicator values
      if(TimeToString(TimeCurrent(), TIME_MINUTES)== "16:00"){
         CopyBuffer(rsi_handle_1d, 0, 0, 3, rsi_buffer_1d);
         CopyBuffer(ema_100_handle_1d, 0, 0, candles_lookback_crossed_ema, ema_100_buffer_1d);
      }

      CopyBuffer(ema_30_handle_1h, 0, 0, 3, ema_30_buffer_1h);
      CopyBuffer(ema_65_handle_1h, 0, 0, 3, ema_65_buffer_1h);
      CopyBuffer(ema_100_handle_1h, 0, 0, 3, ema_100_buffer_1h);
      CopyBuffer(ema_200_handle_1h, 0, 0, 3, ema_200_buffer_1h);
      CopyBuffer(rsi_handle_1h, 0, 0, 3, rsi_buffer_1h);


      
      if(long_allowed){
         // Check for long exits
         CheckExitLong();

         // Check for long entries
         if(ema_30_buffer_1h[1] > ema_65_buffer_1h[1] &&
            ema_65_buffer_1h[1] > ema_100_buffer_1h[1] &&
            ema_100_buffer_1h[1] > ema_200_buffer_1h[1] &&
            iLow(asset, period, 2) < ema_200_buffer_1h[2] &&
            iClose(asset, period, 1) > ema_200_buffer_1h[1]){
               OpenLong("");
         }
      }

      if(short_allowed){
         if(CheckPositionOpen() == "short"){
            // Check for short exits
            CheckExitShort();
         }

         if(CheckPositionOpen() == "none"){
            // Check for short entries
            if(ema_30_buffer_1h[1] < ema_65_buffer_1h[1] &&
            ema_65_buffer_1h[1] < ema_100_buffer_1h[1] &&
            ema_100_buffer_1h[1] < ema_200_buffer_1h[1] &&
            crossedEma100() &&
            (ema_200_buffer_1h[1] - ema_100_buffer_1h[1]) > diff_ema200_ema100 ){
               OpenShort("");
            }
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
