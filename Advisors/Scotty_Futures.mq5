// Scotty did it again: https://www.youtube.com/watch?v=DMaFprJsAMc

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
double pos_size = 0.1;

// Optimizable parameters
input int bb_length = 20;                    // BB length
input double bb_std_dev = 2.2;               // BB Std. dev
input double tp_percentage = 6.9;            // TP in %
input double sl_percentage = 4;              // SL in %

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
   double avg_price = (iHigh(Symbol(), Period(), 1) + iLow(Symbol(), Period(), 1)) / 2;
   double tp = avg_price * (1 + tp_percentage * 0.01); 
   return(tp);
}

// Get SL of long position
double GetSlLong(){
   double avg_price = (iHigh(Symbol(), Period(), 1) + iLow(Symbol(), Period(), 1)) / 2;
   double sl = avg_price * (1 - sl_percentage * 0.01);
   return(sl);
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

   // Init indicators
   bb_handle = iBands(Symbol(), Period(), bb_length, 0, bb_std_dev, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){
      // Get price data and indicator values per tick
      CopyBuffer(bb_handle, 1, 0, 1, bb_upper_buffer);
      ArraySetAsSeries(bb_upper_buffer, true);
      double close = iClose(Symbol(),Period(), 1);
      
      // Check for open longs
      if(bb_upper_buffer[0] < close) {
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
