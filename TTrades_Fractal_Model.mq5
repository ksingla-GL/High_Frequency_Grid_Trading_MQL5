//+------------------------------------------------------------------+
//|                                    TTrades_Fractal_Model.mq5     |
//|                                    Fractal Model Pro Replica     |
//|                                    Based on TTrades concepts     |
//+------------------------------------------------------------------+
#property copyright "Fractal Model Replica"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   6

// Indicator visual properties
#property indicator_label1  "Bullish Setup"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Bearish Setup"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "HTF Candle High"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "HTF Candle Low"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

#property indicator_label5  "CISD Level"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrYellow
#property indicator_style5  STYLE_DASH
#property indicator_width5  2

#property indicator_label6  "Projection Target"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_style6  STYLE_DASH
#property indicator_width6  1

// Input parameters
input ENUM_TIMEFRAMES HTF_Period = PERIOD_H4;        // Higher Timeframe
input int             History_Setups = 10;           // Number of Historical Setups (0-40)
input int             Bias_Mode = 0;                 // Bias Mode (0=Neutral, 1=Bullish, 2=Bearish)
input bool            Show_HTF_Candles = true;       // Show HTF Candles (PO3)
input bool            Show_CISD = true;              // Show Change in State of Delivery
input bool            Show_Projections = true;       // Show Price Projections
input bool            Show_Countdown = true;         // Show HTF Candle Countdown
input string          Time_Filter1 = "08:00-12:00"; // Time Filter 1 (Empty=Disabled)
input string          Time_Filter2 = "14:00-18:00"; // Time Filter 2 (Empty=Disabled)
input string          Time_Filter3 = "";            // Time Filter 3 (Empty=Disabled)
input bool            Enable_Alerts = true;          // Enable Alerts
input bool            Alert_New_Setup = true;        // Alert on New Fractal Setup
input bool            Alert_CISD = true;             // Alert on CISD
input bool            Alert_Target_Hit = true;       // Alert on Target Hit

// Indicator buffers
double BullishSetupBuffer[];
double BearishSetupBuffer[];
double HTFHighBuffer[];
double HTFLowBuffer[];
double CISDBuffer[];
double ProjectionBuffer[];

// Working buffers (not displayed)
double HTFOpenBuffer[];
double HTFCloseBuffer[];
double SetupCountBuffer[];
double BiasBuffer[];

// Global variables
datetime lastHTFCandle = 0;
int htfHandle;
string indicatorPrefix = "FractalModel_";
int setupCounter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, BullishSetupBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, BearishSetupBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, HTFHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, HTFLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, CISDBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, ProjectionBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, HTFOpenBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, HTFCloseBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, SetupCountBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(9, BiasBuffer, INDICATOR_CALCULATIONS);
    
    // Set arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow
    
    // Initialize buffers
    ArraySetAsSeries(BullishSetupBuffer, true);
    ArraySetAsSeries(BearishSetupBuffer, true);
    ArraySetAsSeries(HTFHighBuffer, true);
    ArraySetAsSeries(HTFLowBuffer, true);
    ArraySetAsSeries(CISDBuffer, true);
    ArraySetAsSeries(ProjectionBuffer, true);
    ArraySetAsSeries(HTFOpenBuffer, true);
    ArraySetAsSeries(HTFCloseBuffer, true);
    ArraySetAsSeries(SetupCountBuffer, true);
    ArraySetAsSeries(BiasBuffer, true);
    
    // Validate HTF is higher than current
    if(HTF_Period <= _Period)
    {
        Alert("Higher Timeframe must be greater than current timeframe!");
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up objects
    ObjectsDeleteAll(0, indicatorPrefix);
    Comment("");
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
    // Set arrays as series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    // Calculate starting position
    int start = (prev_calculated == 0) ? rates_total - 100 : rates_total - prev_calculated - 1;
    if(start < 0) start = 0;
    
    // Main calculation loop
    for(int i = start; i >= 0; i--)
    {
        // Clear buffers
        BullishSetupBuffer[i] = EMPTY_VALUE;
        BearishSetupBuffer[i] = EMPTY_VALUE;
        HTFHighBuffer[i] = EMPTY_VALUE;
        HTFLowBuffer[i] = EMPTY_VALUE;
        CISDBuffer[i] = EMPTY_VALUE;
        ProjectionBuffer[i] = EMPTY_VALUE;
        
        // Check time filters
        if(!CheckTimeFilter(time[i])) continue;
        
        // Get HTF data
        datetime htfTime = GetHTFTime(time[i]);
        double htfOpen, htfHigh, htfLow, htfClose;
        
        if(GetHTFCandle(htfTime, htfOpen, htfHigh, htfLow, htfClose))
        {
            // Store HTF data
            HTFOpenBuffer[i] = htfOpen;
            HTFCloseBuffer[i] = htfClose;
            
            // Show HTF candles if enabled
            if(Show_HTF_Candles && i < rates_total - 1)
            {
                HTFHighBuffer[i] = htfHigh;
                HTFLowBuffer[i] = htfLow;
            }
            
            // Check for fractal setups
            if(i < rates_total - 5)
            {
                CheckFractalSetup(i, time, open, high, low, close);
            }
            
            // Check for CISD
            if(Show_CISD && i < rates_total - 3)
            {
                CheckCISD(i, open, high, low, close);
            }
        }
    }
    
    // Update countdown if enabled
    if(Show_Countdown)
    {
        UpdateCountdown();
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check for fractal setup formation                               |
//+------------------------------------------------------------------+
void CheckFractalSetup(int index, const datetime &time[], const double &open[],
                       const double &high[], const double &low[], const double &close[])
{
    // Check if we've exceeded history limit
    if(History_Setups > 0 && setupCounter >= History_Setups)
    {
        return;
    }
    
    // Detect bullish fractal setup (expansion up)
    bool bullishSetup = false;
    bool bearishSetup = false;
    
    // Bullish setup: HTF close > HTF open AND LTF shows momentum shift up
    if(HTFCloseBuffer[index] > HTFOpenBuffer[index])
    {
        // Check for LTF momentum shift (simplified version)
        if(close[index] > open[index] && 
           close[index+1] > open[index+1] &&
           low[index] > low[index+2])
        {
            bullishSetup = true;
        }
    }
    
    // Bearish setup: HTF close < HTF open AND LTF shows momentum shift down
    if(HTFCloseBuffer[index] < HTFOpenBuffer[index])
    {
        // Check for LTF momentum shift (simplified version)
        if(close[index] < open[index] && 
           close[index+1] < open[index+1] &&
           high[index] < high[index+2])
        {
            bearishSetup = true;
        }
    }
    
    // Apply bias filter
    if(Bias_Mode == 1 && bearishSetup) bearishSetup = false; // Bullish only
    if(Bias_Mode == 2 && bullishSetup) bullishSetup = false; // Bearish only
    
    // Set buffer values and create alerts
    if(bullishSetup)
    {
        BullishSetupBuffer[index] = low[index] - 10 * _Point;
        setupCounter++;
        
        if(Enable_Alerts && Alert_New_Setup && index == 0)
        {
            Alert("Fractal Model: New Bullish Setup detected!");
        }
        
        // Create projection if enabled
        if(Show_Projections)
        {
            CreateProjection(index, time[index], high[index], true);
        }
    }
    
    if(bearishSetup)
    {
        BearishSetupBuffer[index] = high[index] + 10 * _Point;
        setupCounter++;
        
        if(Enable_Alerts && Alert_New_Setup && index == 0)
        {
            Alert("Fractal Model: New Bearish Setup detected!");
        }
        
        // Create projection if enabled
        if(Show_Projections)
        {
            CreateProjection(index, time[index], low[index], false);
        }
    }
}

//+------------------------------------------------------------------+
//| Check for Change in State of Delivery (CISD)                    |
//+------------------------------------------------------------------+
void CheckCISD(int index, const double &open[], const double &high[], 
               const double &low[], const double &close[])
{
    // CISD occurs when price breaks structure on LTF
    // Bullish CISD: Break above previous high
    if(close[index] > high[index+1] && close[index+1] <= high[index+2])
    {
        CISDBuffer[index] = high[index+1];
        
        if(Enable_Alerts && Alert_CISD && index == 0)
        {
            Alert("Fractal Model: Bullish CISD detected!");
        }
    }
    
    // Bearish CISD: Break below previous low
    if(close[index] < low[index+1] && close[index+1] >= low[index+2])
    {
        CISDBuffer[index] = low[index+1];
        
        if(Enable_Alerts && Alert_CISD && index == 0)
        {
            Alert("Fractal Model: Bearish CISD detected!");
        }
    }
}

//+------------------------------------------------------------------+
//| Create price projection levels                                   |
//+------------------------------------------------------------------+
void CreateProjection(int index, datetime time, double price, bool isBullish)
{
    // Calculate projection based on recent range
    double range = MathAbs(HTFHighBuffer[index] - HTFLowBuffer[index]);
    double projection;
    
    if(isBullish)
    {
        projection = price + range * 1.618; // Fibonacci extension
        ProjectionBuffer[index] = projection;
    }
    else
    {
        projection = price - range * 1.618; // Fibonacci extension
        ProjectionBuffer[index] = projection;
    }
}

//+------------------------------------------------------------------+
//| Get HTF candle data                                              |
//+------------------------------------------------------------------+
bool GetHTFCandle(datetime htfTime, double &htfOpen, double &htfHigh, 
                  double &htfLow, double &htfClose)
{
    // Copy HTF data
    double o[], h[], l[], c[];
    datetime t[];
    
    if(CopyTime(_Symbol, HTF_Period, htfTime, 1, t) <= 0) return false;
    if(CopyOpen(_Symbol, HTF_Period, htfTime, 1, o) <= 0) return false;
    if(CopyHigh(_Symbol, HTF_Period, htfTime, 1, h) <= 0) return false;
    if(CopyLow(_Symbol, HTF_Period, htfTime, 1, l) <= 0) return false;
    if(CopyClose(_Symbol, HTF_Period, htfTime, 1, c) <= 0) return false;
    
    htfOpen = o[0];
    htfHigh = h[0];
    htfLow = l[0];
    htfClose = c[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Get corresponding HTF time for current bar                      |
//+------------------------------------------------------------------+
datetime GetHTFTime(datetime currentTime)
{
    datetime htfTimes[];
    if(CopyTime(_Symbol, HTF_Period, currentTime, 1, htfTimes) > 0)
    {
        return htfTimes[0];
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Check if current time is within filter ranges                   |
//+------------------------------------------------------------------+
bool CheckTimeFilter(datetime checkTime)
{
    if(Time_Filter1 == "" && Time_Filter2 == "" && Time_Filter3 == "")
        return true; // No filters active
    
    MqlDateTime dt;
    TimeToStruct(checkTime, dt);
    int currentMinutes = dt.hour * 60 + dt.min;
    
    // Check each filter
    if(IsInTimeRange(currentMinutes, Time_Filter1)) return true;
    if(IsInTimeRange(currentMinutes, Time_Filter2)) return true;
    if(IsInTimeRange(currentMinutes, Time_Filter3)) return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if time is within range                                   |
//+------------------------------------------------------------------+
bool IsInTimeRange(int currentMinutes, string timeRange)
{
    if(timeRange == "") return false;
    
    // Parse time range (format: "HH:MM-HH:MM")
    string parts[];
    if(StringSplit(timeRange, '-', parts) != 2) return false;
    
    string start[], end[];
    if(StringSplit(parts[0], ':', start) != 2) return false;
    if(StringSplit(parts[1], ':', end) != 2) return false;
    
    int startMinutes = StringToInteger(start[0]) * 60 + StringToInteger(start[1]);
    int endMinutes = StringToInteger(end[0]) * 60 + StringToInteger(end[1]);
    
    if(startMinutes <= endMinutes)
    {
        return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
    }
    else
    {
        // Handle overnight ranges
        return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
    }
}

//+------------------------------------------------------------------+
//| Update countdown to HTF close                                    |
//+------------------------------------------------------------------+
void UpdateCountdown()
{
    datetime currentTime = TimeCurrent();
    datetime htfTimes[];
    
    // Get next HTF candle time
    if(CopyTime(_Symbol, HTF_Period, currentTime, 2, htfTimes) > 0)
    {
        datetime nextHTFClose = htfTimes[0] + PeriodSeconds(HTF_Period);
        int secondsRemaining = (int)(nextHTFClose - currentTime);
        
        if(secondsRemaining > 0)
        {
            int hours = secondsRemaining / 3600;
            int minutes = (secondsRemaining % 3600) / 60;
            int seconds = secondsRemaining % 60;
            
            string countdown = StringFormat("HTF Close in: %02d:%02d:%02d", 
                                          hours, minutes, seconds);
            Comment(countdown);
        }
    }
}

//+------------------------------------------------------------------+
//| Custom function to handle alerts                                |
//+------------------------------------------------------------------+
void SendAlert(string message)
{
    if(Enable_Alerts)
    {
        Alert(message);
        SendNotification(message);
    }
}