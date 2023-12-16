#property version "1.00"
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#property indicator_chart_window

#property indicator_buffers 3
#property indicator_plots 1

#property indicator_label1 "RSI Divergence"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrRed
#property indicator_width1 2

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

int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, rsi_long_divergence_buffer, INDICATOR_DATA);
   SetIndexBuffer(1, rsi_short_divergence_buffer, INDICATOR_DATA);

   //--- Define the symbol code for drawing in PLOT_ARROW
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrBlue);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);

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
         if ((rsi_buffer[i - 2] - rsi_buffer[i - 1]) >= rsi_distance_peak_long &&
             rsi_buffer[i] - rsi_buffer[i - 1] >= rsi_distance_peak_long)
         {
            rsi_long_divergence_buffer[i] = low[i];
         }

         if ((rsi_buffer[i - 1] - rsi_buffer[i - 2]) >= rsi_distance_peak_short &&
             rsi_buffer[i - 1] - rsi_buffer[i] >= rsi_distance_peak_short)
         {
            rsi_short_divergence_buffer[i] = high[i];
         }


      }
   }

   //--- return value of prev_calculated for next call
   return (rates_total);
}
//+------------------------------------------------------------------+
