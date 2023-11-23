#property version     "1.00" 
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "Vwap"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+

int session_candles = 0;
double current_hlc3, cumulative_hlc3_volume, vwap;
long current_volume, cumulative_volume;
double vwap_buffer[];
bool started_indicator = false;

int OnInit()
  {
//--- indicator buffers mapping
  SetIndexBuffer(0, vwap_buffer, INDICATOR_DATA);

//---
   return(INIT_SUCCEEDED);
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
    for(int i = 0; i < rates_total; i++){
      if(TimeToString(time[i], TIME_MINUTES) == "16:30"){
        cumulative_hlc3_volume = 0;
        cumulative_volume = 0;
      }
      // Get typical price
      current_hlc3 = (high[i] + low[i] + close[i]) / 3;
      current_volume = tick_volume[i];

      cumulative_volume += current_volume;
      cumulative_hlc3_volume += current_hlc3 * current_volume;

      vwap_buffer[i] = cumulative_hlc3_volume / cumulative_volume;
    }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
