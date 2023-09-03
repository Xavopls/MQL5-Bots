#include <Trade/Trade.mqh>

int rsiHandle;
CTrade trade;
ulong posTicket;

int OnInit()
  {
   // RSI
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);

   return(0);
  }

void OnDeinit(const int reason)
  {
   
  }

void OnTick(){

   // RSI
   double rsi[];
   CopyBuffer(rsiHandle, 0, 1, 1, rsi);
   
   if(rsi[0] > 70){
   
      // If position is already open
      if(posTicket > 0 && PositionSelectByTicket(posTicket)) {
         
         // Close buy position
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         if(posType == POSITION_TYPE_BUY){
            trade.PositionClose(posTicket);
            posTicket = 0;   
         }
      }

      // If there are no positions open, sell
      if(posTicket <= 0){
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
         double sl = current_bid * 1.005;
         double tp = current_bid * 0.995;
         trade.Sell(0.01, _Symbol, 0, sl, tp);
         posTicket = trade.ResultOrder();
      }
   }
   
   else if(rsi[0] < 30){
      // If position is already open
      if(posTicket > 0 && PositionSelectByTicket(posTicket)) {
         // Close sell position
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         if(posType == POSITION_TYPE_SELL){
            trade.PositionClose(posTicket);
            posTicket = 0;   
         }
      }
      
      // If there are no positions open, buy
      if(posTicket <= 0){
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
         double sl = current_bid * 0.995;
         double tp = current_bid * 1.005;
         trade.Buy(0.01, _Symbol, 0, sl, tp);
         posTicket = trade.ResultOrder();
      }
      
      if(PositionSelectByTicket(posTicket)){
         double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posSl = PositionGetDouble(POSITION_SL);
         double posTp = PositionGetDouble(POSITION_TP);
         Print("SL:",posSl, "\n TP:", posTp);
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         
         if(posType == POSITION_TYPE_SELL){
            if(posSl == 0 && posTp == 0){
               double sl = posPrice * 1.0025;
               double tp = posPrice * 0.995;
               trade.PositionModify(posTicket, sl, tp);
            }    
         }
         
         if(posType == POSITION_TYPE_BUY){
            if(posSl == 0 && posTp == 0){
               double sl = posPrice * 0.995;
               double tp = posPrice * 1.005;
               trade.PositionModify(posTicket, sl, tp);
            }    
         }
      }

      else{
         posTicket = 0;
      }
   }
}
