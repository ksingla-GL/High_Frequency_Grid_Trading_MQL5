//+------------------------------------------------------------------+
//|                                          GridTradingStrategy.mq5 |
//|                                      High Frequency Grid Trading |
//+------------------------------------------------------------------+
#property copyright "Grid Trading EA"
#property version   "1.00"

// Input parameters for the strategy
input double InitialPrice = 2330.0;    // Starting price for grid
input double GridStep = 3.0;           // Distance between TP and SL (in points)
input double LotSize = 0.01;           // Trading lot size
input int MagicNumber = 12345;         // Unique identifier for this EA's trades

// Global variables to track positions
double buyTP, buySL, sellTP, sellSL;
bool hasBuyPosition = false;
bool hasSellPosition = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize grid levels
   buyTP = InitialPrice + GridStep;
   buySL = InitialPrice - GridStep;
   sellTP = InitialPrice - GridStep;
   sellSL = InitialPrice + GridStep;
   
   // Place initial buy and sell orders
   PlaceInitialOrders();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Place initial buy and sell orders                                |
//+------------------------------------------------------------------+
void PlaceInitialOrders()
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   // Clear the structures
   ZeroMemory(request);
   ZeroMemory(result);
   
   // Setup common parameters
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.magic = MagicNumber;
   request.deviation = 2;  // Maximum allowed slippage in points
   
   // Place BUY order
   request.action = TRADE_ACTION_DEAL;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.tp = buyTP;
   request.sl = buySL;
   
   if(OrderSend(request, result))
   {
      hasBuyPosition = true;
      Print("Buy order placed successfully");
   }
   
   // Place SELL order
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.tp = sellTP;
   request.sl = sellSL;
   
   if(OrderSend(request, result))
   {
      hasSellPosition = true;
      Print("Sell order placed successfully");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function - called on every price change              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if any position hit TP and adjust the other position
   CheckAndAdjustPositions();
}

//+------------------------------------------------------------------+
//| Check positions and adjust TP levels                            |
//+------------------------------------------------------------------+
void CheckAndAdjustPositions()
{
   // Check all positions for this EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            // Position belongs to this EA
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double positionTP = PositionGetDouble(POSITION_TP);
            
            // Check if position is about to hit TP
            if(MathAbs(currentPrice - positionTP) < _Point)
            {
               // Adjust the opposite position's TP
               AdjustOppositePosition(PositionGetInteger(POSITION_TYPE));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Adjust opposite position when one hits TP                       |
//+------------------------------------------------------------------+
void AdjustOppositePosition(long hitPositionType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   // Find and modify the opposite position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            long posType = PositionGetInteger(POSITION_TYPE);
            
            // If this is the opposite position
            if((hitPositionType == POSITION_TYPE_BUY && posType == POSITION_TYPE_SELL) ||
               (hitPositionType == POSITION_TYPE_SELL && posType == POSITION_TYPE_BUY))
            {
               // Modify TP by 1 point closer
               request.action = TRADE_ACTION_SLTP;
               request.position = PositionGetTicket(i);
               request.sl = PositionGetDouble(POSITION_SL);
               
               if(posType == POSITION_TYPE_BUY)
               {
                  request.tp = PositionGetDouble(POSITION_TP) - 1.0;
               }
               else
               {
                  request.tp = PositionGetDouble(POSITION_TP) + 1.0;
               }
               
               OrderSend(request, result);
            }
         }
      }
   }
}