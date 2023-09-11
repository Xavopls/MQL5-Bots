#include <Trade/Trade.mqh>

CTrade trade;
ulong posTicket;

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// https://www.youtube.com/watch?v=ZmLposmKLvs

input int rsiTop = 60;
input int rsiBot = 40;
input int lwmaBufferSize = 10;
input int lastCandlesSl = 10;

int lwmaHandle;
int rsiHandle;

double rsiBuffer[];
double lwmaBuffer[];

// Open buy position
void OpenLong(){
   double sl = GetSlLong(); 
   trade.Buy(0.01, _Symbol, 0, sl, 0);
   posTicket = trade.ResultOrder();
}

// Open sell position
void OpenShort(){
   double sl = GetSlShort(); 
   trade.Sell(0.01, _Symbol, 0, sl, 0);
   posTicket = trade.ResultOrder();
}

// Close buy position
void CloseLong(){
   int posType = (int)PositionGetInteger(POSITION_TYPE);
   if(posType == POSITION_TYPE_BUY){
      trade.PositionClose(posTicket);
      posTicket = 0;   
   }
}
// Close short position
void CloseShort(){
   int posType = (int)PositionGetInteger(POSITION_TYPE);
   if(posType == POSITION_TYPE_SELL){
      trade.PositionClose(posTicket);
      posTicket = 0;   
   }
}

// Check if position is open
bool CheckPositionOpen(){
   return(posTicket > 0 && PositionSelectByTicket(posTicket));
}

// Get SL of buy position
double GetSlLong(){
   return(iLow( Symbol(), _Period, iLowest( Symbol(), _Period, MODE_LOW, lastCandlesSl, 1)));
}

// Get SL of sell position
double GetSlShort(){
   return(iHigh( Symbol(), _Period, iHighest( Symbol(), _Period, MODE_LOW, lastCandlesSl, 1)));
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   lwmaHandle = iCustom(_Symbol, _Period, "../Indicators/lwma");
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
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

   // Get price data and indicator values per tick
   bool lwmaShort = false;
   bool lwmaLong = false;
   CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer);
   CopyBuffer(lwmaHandle, 0, 0, lwmaBufferSize, lwmaBuffer);
   
   // Check for open longs and close shorts
   if(rsiBuffer[0] < rsiBot){
      for(int i = 1; i < ArraySize(lwmaBuffer) || lwmaLong; i++){
         if(lwmaBuffer[i-1] < lwmaBuffer[i]){
            lwmaLong = true;
            if(CheckPositionOpen())
               CloseShort();
            OpenLong();
         }
      }
   }
   
   // Check shorts and close longs
   if(rsiBuffer[0] > rsiTop){
      for(int i = 1; i < ArraySize(lwmaBuffer) || lwmaShort; i++){
         if(lwmaBuffer[i-1] > lwmaBuffer[i]){
            lwmaShort = true;
            if(CheckPositionOpen())
               CloseLong();
            OpenShort();
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
