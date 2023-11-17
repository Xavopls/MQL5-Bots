/*
-------------------------------------------------------
SPY
-------------------------------------------------------

IDEA 1:
   - LONG
      - Entry
         - 1h EMA 30 > 1h EMA 65 > 1h EMA 100 > 1h EMA 200 
         - 1h Low[2] < 1h EMA 200
         - 1h Close > 1h EMA 200

      - TP
         - Daily RSI decreasing
         - RSI Daily[2] > X Value

      - SL
         - Minimum of last X 1h candles

IDEA 2:
   - LONG
      - Entry
         - Low > 1D Lower BB (EMA 200, std dev ~0.3)
         - 1h RSI < X
         - 1h RSI growing
         - 1h Stoch %D line growing

      - TP
         - TBD

      - SL
         - Minimum of last X 1h candles
-------------------------------------------------------

*/

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include "../Libraries/Utils.mq5"
#property tester_everytick_calculate


CTrade trade;
COrderInfo order;
CPositionInfo position; 
ulong pos_ticket;
Utils utils;

// Global variables
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
int ema_200_handle_1d;
int macd_handle_4h;
int macd_handle_1d;
int macd_handle_1h;
int rsi_handle_1d;
int rsi_handle_1h;
int stoch_handle_1h;
int bb_handle_1d;

double ema_30_buffer_1h[]; 
double ema_65_buffer_1h[]; 
double ema_100_buffer_1h[];
double ema_200_buffer_1h[];
double ema_100_buffer_1d[];
double ema_200_buffer_1d[];
double macd_buffer_4h[];
double macd_buffer_1h[];
double macd_buffer_signal_4h[];
double macd_buffer_signal_1h[];
double macd_buffer_1d[];
double macd_buffer_signal_1d[];
double rsi_buffer_1d[];
double rsi_buffer_1h[];
double stoch_buffer_1h[];
double bb_lower_buffer_1d[];

// Inputs

// Long
sinput bool long_allowed = true;                // Long allowed
sinput int long_idea = 2;                       // Long idea number
sinput double long_percentage_per_loss = 10;     // (Long) Percentage of equity to lose per trade
input int last_min_candles_sl_long = 7;         // Long Latest min in terms of candles
input double rsi_value_tp_long = 65;            // Long Max RSI tp value
input double rsi_value_entry_long = 60;            // Long Max RSI tp value
input double macd_upper_long_1h = 1.9;
input double macd_lower_long_1h = 0;

// Short
sinput bool short_allowed = false;              // Short allowed
sinput double short_percentage_per_loss = 1;    // (Short) Percentage of equity to lose per trade
input int candles_lookback_crossed_ema = 5;     // Candle amount to lookback when crossed EMA
input bool bearish_only_crossed_ema = true;     // Candle that crossed ema only bearish?
input bool gaps_allowed_crossed_ema = true;     // Gaps allowed in the crossed ema?
sinput double diff_ema200_ema100_1d = 8;         // Minimum difference between 1D EMA 200 and EMA 100
input bool ema_30_allowed = true;               // EMA 30 allowed?
sinput int last_max_candles_sl_short = 3;        // Amount of candles to get last maximum (SL)
input double sl_threshold = 5;                  // SL Threshold if current price > last maximum
input double tp_ratio_short = 45;
input double macd_range_upper_short = 1;        // Upper MACD Range for TP in short 
input double macd_range_lower_short = 1;        // Lower MACD Range for TP in short   

// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = GetTpLong();
   double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
   int pos_size = utils.SharesToBuyPerPercentageLost(ask, sl, AccountInfoDouble(ACCOUNT_BALANCE), long_percentage_per_loss);
   trade.Buy(pos_size, asset, ask, sl, tp, comment);
   pos_ticket = trade.ResultOrder();
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = 0;
   double bid = SymbolInfoDouble(asset, SYMBOL_BID);
   int pos_size = utils.SharesToBuyPerPercentageLost(bid, sl, AccountInfoDouble(ACCOUNT_BALANCE), short_percentage_per_loss);
   trade.Sell(pos_size, asset, bid, sl, tp, comment);
   pos_ticket = trade.ResultOrder();
}

// Close position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check close long
void CheckExitLong1(){
   // Check if we have enough daily data to close the trade
   if(ArraySize(rsi_buffer_1d) >= 3){
      // Check TP
      if(rsi_buffer_1d[2] > rsi_buffer_1d[1] &&
         rsi_buffer_1d[2] > rsi_value_tp_long){
            closeAllOrders();
      }
   }
}

void CheckExitLong2(){
   // Check if we have enough daily data to close the trade
   if(macd_buffer_1h[1] > macd_upper_long_1h &&
      macd_buffer_1h[1] < macd_buffer_1h[2] ){
         closeAllOrders();
   }
}

// Check close long
void CheckExitShort(){
   if(macd_buffer_1d[1] < macd_range_upper_short &&
      macd_buffer_1d[1] > macd_range_lower_short &&
      macd_buffer_1d[2] < macd_buffer_signal_1d[2] &&
      macd_buffer_1d[1] > macd_buffer_signal_1d[1]){ 
         closeAllOrders();
   }
}

void UpdateTrailingStopShort(){

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
   double current_price = (SymbolInfoDouble(asset, SYMBOL_BID) + SymbolInfoDouble(asset, SYMBOL_ASK)) / 2;
   return(current_price - tp_ratio_short);
}

// Get SL of short position
double GetSlShort(){
   double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2;
   double last_max = getLastMax(last_max_candles_sl_short);
   if(current_price > last_max){
      return(current_price = sl_threshold);
   }
   else {
      return(last_max);
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

bool crossedEma1001d(){
   for(int i = 1; i < candles_lookback_crossed_ema - 1; i++){
      // In case Bearish only is active
      if(bearish_only_crossed_ema){
         // Check if it's bearish
         if(iClose(asset, PERIOD_D1, i) < iOpen(asset, PERIOD_D1, i) ){
            // Check if EMA crossed
            if(iLow(asset, PERIOD_D1, i) < ema_100_buffer_1d[i] &&
            iHigh(asset, PERIOD_D1, i) > ema_100_buffer_1d[i]){
               return(true);
            }
         }
      }

      // In case gaps are allowed (Candle post gap must be bearish)
      if(gaps_allowed_crossed_ema){
         if(iClose(asset, PERIOD_D1, i + 1) > ema_100_buffer_1d[i+1] &&
         iOpen(asset, PERIOD_D1, i) < ema_100_buffer_1d[i] &&
         iClose(asset, PERIOD_D1, i) < iOpen(asset, PERIOD_D1, i)){
            return(true);
         }
      }
   }
   return(false);
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

   // 1h
   ema_30_handle_1h = iMA(asset, period, 30, 0, MODE_EMA, PRICE_CLOSE);
   ema_65_handle_1h = iMA(asset, period, 65, 0, MODE_EMA, PRICE_CLOSE);
   ema_100_handle_1h = iMA(asset, period, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle_1h = iMA(asset, period, 200, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle_1h = iRSI(asset, period, 14, PRICE_CLOSE);
   stoch_handle_1h = iStochastic(asset, period, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   macd_handle_1h = iMACD(asset, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);

   // 1D
   bb_handle_1d = iBands(asset, PERIOD_D1, 200, 0, 0.3, PRICE_CLOSE);
   macd_handle_1d = iMACD(asset, PERIOD_D1, 12, 26, 9, PRICE_CLOSE);
   ema_100_handle_1d = iMA(asset, PERIOD_D1, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema_200_handle_1d = iMA(asset, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle_1d = iRSI(asset, PERIOD_D1, 14, PRICE_CLOSE);
   // 4h
   macd_handle_4h = iMACD(asset, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);

   ArraySetAsSeries(ema_30_buffer_1h, true);
   ArraySetAsSeries(ema_65_buffer_1h, true);
   ArraySetAsSeries(ema_100_buffer_1h, true);
   ArraySetAsSeries(ema_200_buffer_1h, true);
   ArraySetAsSeries(ema_100_buffer_1d, true);
   ArraySetAsSeries(ema_200_buffer_1d, true);
   ArraySetAsSeries(macd_buffer_4h, true);
   ArraySetAsSeries(macd_buffer_1d, true);
   ArraySetAsSeries(macd_buffer_signal_4h, true);
   ArraySetAsSeries(macd_buffer_signal_1d, true);
   ArraySetAsSeries(rsi_buffer_1d, true);
   ArraySetAsSeries(rsi_buffer_1h, true);
   ArraySetAsSeries(bb_lower_buffer_1d, true);

   return(INIT_SUCCEEDED);
}

void OnTick(){

   if(isNewBar()){

      // if(TimeToString(TimeCurrent(), TIME_DATE)== "2022.09.09" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.09.12" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.09.14" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.09.15" ||
      // TimeToString(TimeCurrent(), TIME_DATE)== "2022.09.13" ){
      //    Print("-------------------------");
      //    Print(ema_30_buffer_1h[1] < ema_65_buffer_1h[1]);
      //    Print(ema_65_buffer_1h[1] < ema_100_buffer_1h[1]);
      //    Print(ema_100_buffer_1h[1] < ema_200_buffer_1h[1]);
      //    Print("EEE, ", MathAbs(ema_100_buffer_1d[1] - ema_200_buffer_1d[1]));
      //    Print(crossedEma1001d());
      // }

      // Set up indicator values
      if(TimeToString(TimeCurrent(), TIME_MINUTES)== "16:00"){
         CopyBuffer(rsi_handle_1d, 0, 0, 3, rsi_buffer_1d);
         CopyBuffer(ema_100_handle_1d, 0, 0, candles_lookback_crossed_ema + 2, ema_100_buffer_1d);
         CopyBuffer(ema_200_handle_1d, 0, 0, 3, ema_200_buffer_1d);
         CopyBuffer(macd_handle_1d, 0, 0, 3, macd_buffer_1d);
         CopyBuffer(macd_handle_1d, 1, 0, 3, macd_buffer_signal_1d);
      }

      CopyBuffer(ema_30_handle_1h, 0, 0, 3, ema_30_buffer_1h);
      CopyBuffer(ema_65_handle_1h, 0, 0, 3, ema_65_buffer_1h);
      CopyBuffer(ema_100_handle_1h, 0, 0, 3, ema_100_buffer_1h);
      CopyBuffer(ema_200_handle_1h, 0, 0, 3, ema_200_buffer_1h);
      CopyBuffer(rsi_handle_1h, 0, 0, 3, rsi_buffer_1h);
      CopyBuffer(bb_handle_1d, 2, 0, 3, bb_lower_buffer_1d);
      CopyBuffer(stoch_handle_1h, 1, 0, 3, stoch_buffer_1h);
      CopyBuffer(macd_handle_1h, 0, 0, 3, macd_buffer_1h);
      CopyBuffer(macd_handle_1h, 1, 0, 3, macd_buffer_signal_1h);

      
      if(long_allowed){
         if(long_idea == 1){
            // Check for long exits
            CheckExitLong1();

            // Check for long entries
            if(ema_30_buffer_1h[1] > ema_65_buffer_1h[1] &&
               ema_65_buffer_1h[1] > ema_100_buffer_1h[1] &&
               ema_100_buffer_1h[1] > ema_200_buffer_1h[1] &&
               iLow(asset, period, 2) < ema_200_buffer_1h[2] &&
               iClose(asset, period, 1) > ema_200_buffer_1h[1]){
                  OpenLong("");
            }
         }

         if(long_idea == 2){
            // Check for long exits
            CheckExitLong2();

            // Check for long entries
            if(iLow(asset, period, 1) > bb_lower_buffer_1d[1] &&
            // rsi_buffer_1h[1] < rsi_value_entry_long &&
            // rsi_buffer_1h[2] < rsi_buffer_1h[1] &&
            // stoch_buffer_1h[2] < stoch_buffer_1h[1] &&
            macd_buffer_1h[1] < macd_lower_long_1h &&
            macd_buffer_1h[2] > macd_buffer_signal_1h[2] &&
            macd_buffer_1h[1] < macd_buffer_signal_1h[1] 
            ){
               OpenLong("");
            }
         }

      }

      if(short_allowed){
         if(CheckPositionOpen() == "short"){
            // Check for short exits
            CheckExitShort();
            UpdateTrailingStopShort();
         }

         if(CheckPositionOpen() == "none"){
            // Check for short entries
            if(ema_30_buffer_1h[1] < ema_65_buffer_1h[1] &&
            ema_65_buffer_1h[1] < ema_100_buffer_1h[1] &&
            ema_100_buffer_1h[1] < ema_200_buffer_1h[1] &&
            crossedEma1001d() &&
            MathAbs(ema_200_buffer_1d[1] - ema_100_buffer_1d[1]) < diff_ema200_ema100_1d ){
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
