#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

CTrade trade;
ulong posTicket;

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property tester_everytick_calculate

// https://www.youtube.com/watch?v=ZmLposmKLvs

input int rsiTop = 60;
input int rsiBot = 40;
input int lwmaBufferSize = 2;
input int lastCandlesSl = 15;
input double diffLwmaLong = 0.2;
input double diffLwmaShort = 0.2;
int barsTotal;
int lwmaHandle;
int rsiHandle;
int magicNumber;
double rsiBuffer[];
double lwmaBuffer[];

// Open buy position
void OpenLong(string comment){
   double sl = GetSlLong();
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   trade.Buy(0.05, Symbol(), ask, sl, 0, comment);
   posTicket = trade.ResultOrder();
}

// Open sell position
void OpenShort(string comment){
   double sl = GetSlShort(); 
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   trade.Sell(0.05, Symbol(), bid, sl, 0, comment);
   posTicket = trade.ResultOrder();
}

// Close position
void CloseOrder(){
   trade.PositionClose(posTicket);
   posTicket = 0;   
}

// Check if last bar is completed, tf opened new bar
bool isNewBar(){
   int bars = iBars(Symbol(), PERIOD_CURRENT);
   if(barsTotal != bars){
      barsTotal = bars;
      return(true);
   }
   return(false);
}

// Check if position is open, only works with 1 position opened max
string CheckPositionOpen(){
   PositionSelectByTicket(posTicket);
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

// Get SL of long position
double GetSlLong(){
   double avgSpread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2; 
   return((iLow(Symbol(), Period(), iLowest(Symbol(), Period(), MODE_LOW, lastCandlesSl, 1))) - avgSpread);
}

// Get SL of short position
double GetSlShort(){
   double avgSpread = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2; 
   return((iHigh( Symbol(), Period(), iHighest( Symbol(), Period(), MODE_HIGH, lastCandlesSl, 1))) + avgSpread);
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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   Print("------------------------------------------------------------------------------------------------------------");

   // Check if account is demo or real. Exit if it's real 
   if(isAccountReal()){
      return(-1);
   }

   // Async trades are disabled
   trade.SetAsyncMode(false);

   // Init indicators
   lwmaHandle = iMA(Symbol(), PERIOD_CURRENT, 14, 0, MODE_LWMA, PRICE_CLOSE);
   rsiHandle = iRSI(Symbol(), PERIOD_CURRENT, 14, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   if(isNewBar()){
   // Get price data and indicator values per tick
      CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer);
      CopyBuffer(lwmaHandle, 0, 0, lwmaBufferSize, lwmaBuffer);
      ArraySetAsSeries(lwmaBuffer, true);
      lwmaBuffer[0] = NormalizeDouble(lwmaBuffer[0],1);
      lwmaBuffer[1] = NormalizeDouble(lwmaBuffer[1],1);
      
      // Check for open longs and close shorts
      if(rsiBuffer[0] < rsiBot && lwmaBuffer[1] < lwmaBuffer[0] && (lwmaBuffer[0] - lwmaBuffer[1]) > diffLwmaLong ){
         if(CheckPositionOpen() == "short"){
            CloseOrder();
            OpenLong(IntegerToString(PositionsTotal()));
         }
         else if(CheckPositionOpen() == "none"){
            OpenLong(IntegerToString(PositionsTotal()));
         }
      }
         
      // Check shorts and close longs
      if(rsiBuffer[0] > rsiTop && lwmaBuffer[1] > lwmaBuffer[0] && (lwmaBuffer[1] - lwmaBuffer[0]) > diffLwmaShort ){
         if(CheckPositionOpen() == "long"){
            CloseOrder();
            OpenShort(IntegerToString(PositionsTotal()));
         }
         else if(CheckPositionOpen() == "none"){
            OpenShort(IntegerToString(PositionsTotal()));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
