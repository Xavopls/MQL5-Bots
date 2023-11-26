#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#property tester_everytick_calculate


CTrade trade;
ulong pos_ticket;

// Global variables
double pos_size = 0.3;
string asset = Symbol();
ENUM_TIMEFRAMES period = Period();
bool real_account_permitted = false;
bool async_trading_permitted = false;
int bars_total;
int bbs_handle;
double bbs_buffer_upper[];
double bbs_buffer_middle[];
double bbs_buffer_lower[];


// Inputs

input double bb_deviation = 2.0;

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
   trade.Sell(pos_size, asset, bid, sl, tp, comment);
   pos_ticket = trade.ResultOrder();
}

// Close position
void CloseOrder(){
   trade.PositionClose(pos_ticket);
   pos_ticket = 0;   
}

// Check close long
void CheckExitLong(){
    if(iClose(asset, period, 1) > bbs_buffer_middle[1]){
        CloseOrder();
    }
}

// Check close long
void CheckExitShort(){
    if(iClose(asset, period, 1) < bbs_buffer_middle[1]){
        CloseOrder();
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
   return(0);
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

   bbs_handle = iBands(asset, period, 40, 0, bb_deviation, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

void OnTick(){
   if(isNewBar()){

    CopyBuffer(bbs_handle, 2, 0, 3, bbs_buffer_lower);
    CopyBuffer(bbs_handle, 1, 0, 3, bbs_buffer_upper);
    CopyBuffer(bbs_handle, 0, 0, 3, bbs_buffer_middle);

    // Check entries
    if(CheckPositionOpen() == "none"){
        if(iClose(asset, period, 2) < bbs_buffer_lower[2] && iClose(asset, period, 1) > bbs_buffer_lower[1]){
            OpenLong("");
        }

        if(iClose(asset, period, 2) > bbs_buffer_upper[2] && iClose(asset, period, 1) < bbs_buffer_upper[1]){
            OpenShort("");
        }
    }
    // Check exits
    else {
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
