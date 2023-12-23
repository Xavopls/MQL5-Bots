#property version "1.00"
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots 2

#property indicator_label1 "Long RSI Divergence"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrBlue
#property indicator_width1 2


#property indicator_label2 "Short RSI Divergence"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_width2 2


#property indicator_label2 "Short RSI Divergence"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_width2 2

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+

// Inputs
input double rsi_distance_peak_long = 6;
input double rsi_distance_peak_short = 3;

// Variables
double rsi_long_divergence_buffer[];
double rsi_short_divergence_buffer[];
double rsi_buffer[];
int rsi_handle;
double last_maxs[];
double last_mins[];
double last_rsis_max[];
double last_rsis_min[];

int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, rsi_long_divergence_buffer, INDICATOR_DATA);
   SetIndexBuffer(1, rsi_short_divergence_buffer, INDICATOR_DATA);

   //--- Define the symbol code for drawing in PLOT_ARROW
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   
   //--- Set the vertical shift of arrows in pixels
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 5);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 5);
   //--- Set as an empty value 0
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   //---
   rsi_handle = iRSI(Symbol(), Period(), 14, PRICE_CLOSE);

   return (INIT_SUCCEEDED);
}

void ModifyArray(double& _arr[], double new_item){
   ArrayResize(_arr, ArraySize(_arr) + 1);
   ArrayFill(_arr, ArraySize(_arr)-1, 1, new_item);
   // Set a buffer to not overload the array
   if(ArraySize(_arr) > 3){
      ArrayRemove(_arr, 0, 1);
   }
}

bool CheckLongRSI(){
   if(ArraySize(last_mins) == 3 && ArraySize(last_rsis_min) == 3){
      if(last_rsis_min[2] > last_rsis_min[1] && last_rsis_min[1] > last_rsis_min[0] &&
      last_mins[2] < last_mins[1] && last_mins[1] < last_mins[0]){
         return(true);
      }
   }
   
      
   return(false);
}

bool CheckShortRSI(){
   if(ArraySize(last_maxs) == 3 && ArraySize(last_rsis_max) == 3){
      if(last_rsis_max[2] < last_rsis_max[1] && last_rsis_max[1] < last_rsis_max[0] &&
      last_maxs[2] > last_maxs[1] && last_maxs[1] > last_maxs[0]){
         return(true);
      }
   }
   
      
   return(false);
}


//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{

   if (rates_total > 5)
   {
      CopyBuffer(rsi_handle, 0, 0, rates_total, rsi_buffer);
      for (int i = 5; i < rates_total; i++)
      {
         if(high[i-4] < high[i-3] && high[i-3] < high[i-2] && high[i-2] > high[i-1] && high[i-1] > high[i] ){
            ModifyArray(last_maxs, high[i-2]);
            ModifyArray(last_rsis_max, rsi_buffer[i-2]);
         }

         if(low[i-4] > low[i-3] && low[i-3] > low[i-2] && low[i-2] < low[i-1] && low[i-1] < low[i] ){
            ModifyArray(last_mins, low[i-2]);
            ModifyArray(last_rsis_min, rsi_buffer[i-2]);         
         }

         if(CheckLongRSI()){
            rsi_long_divergence_buffer[i] = low[i];
         }

         if(CheckShortRSI()){
            rsi_short_divergence_buffer[i] = high[i];
         }
      }
   }

   //--- return value of prev_calculated for next call
   return (rates_total);
}
//+------------------------------------------------------------------+
