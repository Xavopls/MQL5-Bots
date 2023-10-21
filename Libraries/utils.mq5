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
   
      //--------- TRADING METHODS ---------

      /** Returns the amount of shares to buy given the stoploss, entry price and the total balance.
       * @param entry_price  [in]  Entry price of the asset.
       * @param stop_loss_price  [in]  Stop loss price of the trade.
       * @param total_equity  [in]  Total balance of the account.
       * @param percentage_to_lose  [in]  Percentage willing to lose for the trade.
       * @return ( int )
       */
      int SharesToBuy(
         double entry_price,
         double stop_loss_price,
         double total_equity,
         double percentage_to_lose) const;
};  



//--------- TRADING METHODS ---------

int Utils::SharesToBuy(         
         double entry_price,
         double stop_loss_price,
         double total_equity,
         double percentage_to_lose) const{
            // Get the maximum amount of shares that could be bought with the current equity
            int max_amount_of_shares_possible = int(MathRound(total_equity / entry_price));

            // Calculate number of shares
            double amount_to_risk = total_equity * (percentage_to_lose / 100);
            double stop_loss_level = MathAbs(entry_price - stop_loss_price);
            int shares_to_buy = int(MathRound(amount_to_risk / stop_loss_level));

            // Check if the shares too buy are more than we can possibly can with the current balance
            if(shares_to_buy > max_amount_of_shares_possible){
               return(max_amount_of_shares_possible);
            }
            else {
               return(shares_to_buy);
            }
         }

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
 