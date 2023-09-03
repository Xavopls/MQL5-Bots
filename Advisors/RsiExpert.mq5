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

double OnTester(){
   if(!HistorySelect(0,TimeCurrent())) 
      return (false); 
      
   // Init variables
   uint total_deals = HistoryDealsTotal();
   double volume = 0; 
   double pl_results[];
   ulong ticket_history_deal = 0;
   double result[];
   ArrayResize(result,total_deals);
   string agent_name = MQLInfoString(MQL_PROGRAM_NAME);

   // Write results in a .csv file
   string filename = agent_name+".csv";
   int filehandle = FileOpen(filename,FILE_WRITE|FILE_CSV,",");
   if(filehandle!=INVALID_HANDLE){
      FileWrite(filehandle,"Type","Profit", "Volume","Time","Reason","ID");
      for(uint i=0; i<total_deals;i++){
         if((ticket_history_deal=HistoryDealGetTicket(i))>0){
            ENUM_DEAL_ENTRY deal_entry  =(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket_history_deal,DEAL_ENTRY); 
            long   deal_type   =HistoryDealGetInteger(ticket_history_deal,DEAL_TYPE); 
            double deal_profit =HistoryDealGetDouble(ticket_history_deal,DEAL_PROFIT); 
            double deal_volume =HistoryDealGetDouble(ticket_history_deal,DEAL_VOLUME); 
            long deal_time =HistoryDealGetInteger(ticket_history_deal,DEAL_TIME); 
            ENUM_DEAL_REASON deal_reason =(ENUM_DEAL_REASON)HistoryDealGetInteger(ticket_history_deal,DEAL_REASON); 
            long deal_id =HistoryDealGetInteger(ticket_history_deal,DEAL_POSITION_ID); 
            FileWrite(filehandle, deal_type, deal_profit, deal_volume, deal_time, deal_reason, deal_id);
         }
      }
      FileClose(filehandle);
      Print("FileOpen OK");
     }
   else Print("Operation FileOpen failed, error ",GetLastError());   
   return (true); 
   
}
