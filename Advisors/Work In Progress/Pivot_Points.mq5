/*
--------------------------------- DISCLAIMER ---------------------------------
Input values hardcoded in this strategy are meaningless.
These are coded in order to be able to compile the strategy.
Appropiate inputs are obtained through backtesting and parameter optimization.
------------------------------------------------------------------------------

Asset: X

- LONG
   - Entry

   - TP

   - SL


- SHORT
   - Entry

   - TP

   - SL


*/
#property version "1.00"
#property link "https://github.com/Xavopls"
#property copyright "Xavi Olivares"
#property description ""

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include "../../Libraries/Utils.mq5"

CTrade trade;
ulong pos_ticket;
CPositionInfo position;
COrderInfo order;
Utils utils;

// Global variables
string asset = Symbol();
ENUM_TIMEFRAMES period = Period();
bool async_trading_permitted = false;
int bars_total;
double partial_closed_tickets[];

// Static inputs
sinput bool short_allowed = true;         // Short allowed
sinput bool long_allowed = true;          // Long allowed
sinput bool partial_exits_allowed = true; // Partial exits allowed
sinput bool live_trading_allowed = false; // Live trading allowed

// Input variables
input float equity_percentage_per_trade = 40; // Equity percentage per trade
input double partial_tp_ratio = 1.5;          // Ratio SL:TP of the partial exit
input double partial_percentage = 50;         // Position size in % to reduce when partially closing

// This variable depends on the asset, must check
int lots_per_unit = 5;
bool trading_allowed;

// Open long position
void OpenLong(string comment)
{
    double sl = GetSlLong();
    double tp = GetTpLong();
    double ask = SymbolInfoDouble(asset, SYMBOL_ASK);
    int size = utils.SharesToBuyPerMaxEquity(ask / lots_per_unit, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
    if (trade.Buy(size, asset, ask, sl, tp, comment))
    {
        pos_ticket = trade.ResultOrder();
    }
}

// Open short position
void OpenShort(string comment)
{
    double sl = GetSlShort();
    double tp = GetTpShort();
    double bid = SymbolInfoDouble(asset, SYMBOL_BID);
    int size = utils.SharesToBuyPerMaxEquity(bid / lots_per_unit, AccountInfoDouble(ACCOUNT_BALANCE), equity_percentage_per_trade);
    if (trade.Sell(size, asset, bid, sl, 0, comment))
    {
        pos_ticket = trade.ResultOrder();
    }
}

// Close last position
void CloseOrder()
{
    trade.PositionClose(pos_ticket);
    pos_ticket = 0;
}

// Check if last bar is completed, eg. new bar created
bool isNewBar()
{
    int bars = iBars(asset, PERIOD_CURRENT);
    if (bars_total != bars)
    {
        bars_total = bars;
        return (true);
    }
    return (false);
}

// Check if position is open, checks the last one executed
string CheckPositionOpen()
{
    PositionSelectByTicket(pos_ticket);
    int posType = (int)PositionGetInteger(POSITION_TYPE);

    if (PositionsTotal() == 0)
    {
        return ("none");
    }
    else
    {
        if (posType == POSITION_TYPE_BUY)
        {
            return ("long");
        }
        if (posType == POSITION_TYPE_SELL)
        {
            return ("short");
        }
    }
    return ("error");
}

// Close all the open orders and positions
void closeAllOrders()
{
    // Close Positions
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (position.SelectByIndex(i))
        {
            trade.PositionClose(position.Ticket());
            Sleep(100);
        }
    }

    // Close Orders
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (order.SelectByIndex(i))
        {
            trade.OrderDelete(order.Ticket());
            Sleep(100);
        }
    }

    // 2nd iteration of Close Positions
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (position.SelectByIndex(i))
        {
            trade.PositionClose(position.Ticket());
            Sleep(100);
        }
    }
}

// Check if account is real or demo
bool isAccountReal()
{
    CAccountInfo account;
    long login = account.Login();
    ENUM_ACCOUNT_TRADE_MODE account_type = account.TradeMode();
    if (account_type == ACCOUNT_TRADE_MODE_REAL)
    {
        MessageBox("Trading on a real account is forbidden, disabling", "The Expert Advisor has been launched on a real account!");
        return (true);
    }
    else
    {
        return (false);
    }
}

// Check if current trade is already partially closed
bool IsAlreadyPartiallyClosed(double ticket)
{
    for (int i = 0; i < ArraySize(partial_closed_tickets); i++)
    {
        if (ticket == partial_closed_tickets[i])
        {
            return (true);
        }
    }
    return (false);
}

// Partial close method
void CheckIfPartialClose()
{
    // Init variables
    double
        position_volume,
        position_current_profit_distance,
        position_sl_distance;

    // Loop through open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // Select position
        if (position.SelectByIndex(i))
        {
            // Check if position has not already been partially closed
            if (!IsAlreadyPartiallyClosed(position.Ticket()))
            {
                // Check if it's profitable
                if (position.Profit() > 0)
                {
                    // Get position info
                    position_volume = position.Volume();
                    position_current_profit_distance = MathAbs(position.PriceOpen() - position.PriceCurrent());
                    position_sl_distance = MathAbs(position.PriceOpen() - position.StopLoss());

                    // Check if partial profit reached
                    if (position_current_profit_distance > position_sl_distance * partial_tp_ratio)
                    {
                        trade.PositionClosePartial(position.Ticket(), MathRound(position_volume * (partial_percentage / 100)));
                        ArrayResize(partial_closed_tickets, ArraySize(partial_closed_tickets) + 1);
                        ArrayFill(partial_closed_tickets, ArraySize(partial_closed_tickets) - 1, 1, position.Ticket());
                        // Set a buffer to not overload the array
                        if (ArraySize(partial_closed_tickets) > 10)
                        {
                            ArrayRemove(partial_closed_tickets, 0, 1);
                        }
                    }
                }
            }
        }
    }
}

// Get TP of long position
double GetTpLong()
{
    return (0);
}

// Get SL of long position
double GetSlLong()
{
    return (0);
}

// Get TP of short position
double GetTpShort()
{
    return (0);
}

// Get SL of short position
double GetSlShort()
{
    return (0);
}

// Check entry long
void CheckEntryLong()
{
}

// Check entry short
void CheckEntryShort()
{
}

// Check close long
void CheckExitLong()
{
}

// Check close short
void CheckExitShort()
{
}

int OnInit()
{
    trading_allowed = false;

    // If real account is not permitted, exit
    if (!live_trading_allowed)
    {
        if (isAccountReal())
        {
            return (-1);
        }
    }

    // Async trades setup
    trade.SetAsyncMode(async_trading_permitted);

    // Init indicators
    // -----
    // -----
    // -----

    return (INIT_SUCCEEDED);
}

void OnTick()
{
    if (isNewBar())
    {
        if (TimeToString(TimeCurrent(), TIME_MINUTES) == "16:30")
        {
            trading_allowed = true;
            double hlc3 = (iHigh(asset, PERIOD_D1, 1) + iLow(asset, PERIOD_D1, 1) + iClose(asset, PERIOD_D1, 1)) / 3;
            double r1 = hlc3 * 2 - iLow(asset, PERIOD_D1, 1);
            double r2 = hlc3 + (iHigh(asset, PERIOD_D1, 1) - iLow(asset, PERIOD_D1, 1));
            double s1 = hlc3 * 2 - iHigh(asset, PERIOD_D1, 1);
            double s2 = hlc3 - (iHigh(asset, PERIOD_D1, 1) - iLow(asset, PERIOD_D1, 1));
        }

        if (TimeToString(TimeCurrent(), TIME_MINUTES) == "23:00")
        {
            trading_allowed = false;
        }

        if (trading_allowed)
        {

            // Update indicators

            if (CheckPositionOpen() == "none")
            {
                if (long_allowed)
                {
                    // Check entries for long positions
                    CheckEntryLong();
                }

                if (short_allowed)
                {
                    // Check entries for short positions
                    CheckEntryShort();
                }
            }

            else
            {
                // Check if any trade has reached the partial objective
                if (partial_exits_allowed)
                {
                    CheckIfPartialClose();
                }

                // Check exits for long positions
                if (CheckPositionOpen() == "long")
                {
                    // Check TP
                    CheckExitLong();
                }

                // Check exits for short positions
                if (CheckPositionOpen() == "short")
                {
                    // Check TP
                    CheckExitShort();
                }
            }
        }
    }
}

void OnTimer() {}

void OnTrade() {}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {}

double OnTester() { return (0.0); }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {}

void OnDeinit(const int reason) { EventKillTimer(); }