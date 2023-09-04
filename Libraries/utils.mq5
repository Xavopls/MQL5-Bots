#property library
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Object.mqh>

class Utils : public CObject{
   public:
      Utils::Utils(void){}
      Utils::~Utils(void){}
      
      //--------- BACKTEST METHODS ---------
      bool BacktestExportCsv(void) const;

};  
   //--------- BACKTEST METHODS ---------
   
bool Utils::BacktestExportCsv(void) const {

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
   int rand = MathRand()%1000000;
   
   string filename = agent_name + "_" + IntegerToString(rand) + ".csv";
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

   return(true);
}  
 