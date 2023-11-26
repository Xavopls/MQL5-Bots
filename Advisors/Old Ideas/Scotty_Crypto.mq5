// Transcripted strategy from freqtrade: https://github.com/Xavopls/Comfy-Bot/blob/main/user_data/strategies/scotty.py

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#property tester_everytick_calculate


CTrade trade;
ulong pos_ticket;

// Global variables
int bars_total;
bool real_account_permitted = false;
bool async_trading_permitted = false;
int bb_handle;
double bb_upper_buffer[];
double bb_lower_buffer[];
int rsi_handle;
double rsi_buffer[];
int stoch_handle;
double stoch_buffer[];
int stoch_k;
int stoch_d;
int stoch_slowing;
double current_sl;

enum stoch_osc_type {
   responsive, // Responsive (5,3,3)
   mid_term,   // Mid term (21,7,7)
   long_term,  // Long term (21,14,14)
   pablito,    // Custom term (10,6,6)
  };

// Optimizable parameters
input float pos_size = 0.5;                  // Pos size in lots
input float sl_tp_ratio = 2;                 // SL/TP ratio
input int last_candles_sl = 5;               // Candles count from last minimum (SL) 
input bool operate_market_hours = false;     // Only Market hours
input bool bullish_candle = false;           // Current candle being bullish
input bool weekend_trading = false;          // Trading during weekends
input double stoch_value_min = 5;            // Stoch. Osc. Top
input double stoch_value_max = 20;           // Stoch. Osc. Bottom
input double rsi_value_min = 15;             // RSI Top
input double rsi_value_max = 35;             // RSI Bottom
input stoch_osc_type osc_type = responsive;  // Stoch. Osc. Setup
input int bb_length = 50;                    // BB length
input float bb_std_dev = 2.5;                // BB Std. dev
input int rsi_length = 14;                   // RSI length
input bool rsi_growing = false;              // RSI Growing in last candle




// Open long position
void OpenLong(string comment){
   double sl = GetSlLong();
   double tp = GetTpLong();
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   trade.Buy(pos_size, Symbol(), ask, sl, tp, comment);
   pos_ticket = trade.ResultOrder();
}

// Open short position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double tp = GetTpShort();
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   trade.Sell(pos_size, Symbol(), bid, sl, 0, comment);
   pos_ticket = trade.ResultOrder();
}

// Close position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check if last bar is completed, eg. new bar created
bool isNewBar(){
   int bars = iBars(Symbol(), PERIOD_CURRENT);
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
   double avg_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2; 
   double avg_price = (iHigh(Symbol(), Period(), 1) + iLow(Symbol(), Period(), 1)) / 2;
   double sl_distance = avg_price - current_sl;
   double tp = sl_tp_ratio * sl_distance + avg_price; 
   return(tp + avg_spread);
}

// Get SL of long position
double GetSlLong(){
   double avg_spread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2; 
   double last_low = iLow(Symbol(), Period(), iLowest(Symbol(), Period(), MODE_LOW, last_candles_sl, 1));
   current_sl = last_low - avg_spread;
   return(current_sl);
}

// Get TP of short position
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

   // Set up inputs
   switch (osc_type){
      case responsive:
         stoch_k = 5;
         stoch_d = 3;
         stoch_slowing = 3;
         break;

      case mid_term:
         stoch_k = 14;
         stoch_d = 7;
         stoch_slowing = 7;
         break;

      case long_term:
         stoch_k = 5;
         stoch_d = 3;
         stoch_slowing = 3;
         break;

      case pablito:
         stoch_k = 10;
         stoch_d = 6;
         stoch_slowing = 6;
         break;

      default:
         break;
      }

   // Init indicators
   rsi_handle = iRSI(Symbol(), Period(), rsi_length, PRICE_CLOSE);
   stoch_handle = iStochastic(Symbol(), Period(), stoch_k, stoch_d, stoch_slowing, MODE_SMA, STO_LOWHIGH);
   bb_handle = iBands(Symbol(), Period(), bb_length, 0, bb_std_dev, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){
      // Get price data and indicator values per tick
      CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer);
      CopyBuffer(stoch_handle, 0, 0, 1, stoch_buffer);
      CopyBuffer(bb_handle, 1, 0, 1, bb_upper_buffer);
      CopyBuffer(bb_handle, 2, 0, 1, bb_lower_buffer);
      ArraySetAsSeries(stoch_buffer, true);
      ArraySetAsSeries(bb_upper_buffer, true);
      ArraySetAsSeries(bb_lower_buffer, true);
      double high = iHigh(Symbol(),Period(), 1);
      
      // Check for open longs
      if(bb_upper_buffer[0] < high &&
         stoch_buffer[0] < stoch_value_max &&
         stoch_buffer[0] > stoch_value_min && 
         rsi_buffer[0] < rsi_value_max &&
         rsi_buffer[0] > rsi_value_min) {

         if(CheckPositionOpen() == "none"){
            OpenLong("");
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
