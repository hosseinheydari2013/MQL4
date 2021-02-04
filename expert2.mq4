//+------------------------------------------------------------------+
//|                                                      expert2.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "EINSTEIN BOT CENTER"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "EINSTEIN BOT PRESENTS!"


#property strict


#import "stdlib.ex4"
string ErrorDescription(int error_code);
int    RGB(int red_value,int green_value,int blue_value);
bool   CompareDoubles(double number1,double number2);
string DoubleToStrMorePrecision(double number,int precision);
#import

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int buyStop = 0; // buyTicketNo but initialized to 0
int sellStop = 0; // sellTicketNo initialized to 0
// BOOLEAN VARS   
bool boolBuy = false; 
bool boolSell = false;
bool boolTradeRestriction = false;
bool deleteStatus = false;
bool modifyStatus = false;
bool closeStatus = false;
bool selectStatus = false;
bool finishedTrade = true;
bool restrictionStopLevel = false;

// if trade finishes he shouldn't trade immediately. sondern he should wait at least for 5 mins!


// configured by the user
extern double volume = 1.0;
extern int slippage = 5;
extern double trailingStopLoss =  0.0001 * 0.7 ; // 0.7 pip
extern double trailingTakeProfit =  0.0001 * 0.0 ; // 0 pip
int magicSell = 12345;
int magicBuy = 12346;

int OnInit()
  {
  
   Print("WELCOME ON BOARD!");
   Print("COMPILATION DATE & TIME: ", __DATETIME__);
   Print("COMPILER: ", __MQL4BUILD__);
   boolTradeRestriction = tradeRestriction();
   // BROKER SPECIFIC CHECKS
   if(MarketInfo(Symbol(), MODE_STOPLEVEL) == 0)
   {  
      if(GetLastError() == 130)
      {  
         Print("MarketInfo: EXTERNAL DYNAMIC LEVEL CONTROL! ", __LINE__);
         restrictionStopLevel = false;
         
      }
      else
      {  
         Print("MarketInfo: NO RESTRICTION FOR STOPLOSS ", __LINE__); 
         restrictionStopLevel = true;
      }
   }
   if(boolTradeRestriction && restrictionStopLevel)
   {
      pendingOrders();
   }
   
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      Print("DESTRUCTOR IS CALLED!");
      Print("DESTRUCTOR: REASON = ", reason);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

      if(boolBuy && boolSell && boolTradeRestriction && finishedTrade) // get in only with successful sellStop and buyStop, finished trades and green weekdays
      {
           modifyPendingOrders();
      }
      else
      {
         pendingOrders();
      }
    
      //signalChecker();
   
  }
//+------------------------------------------------------------------+

// CUSTOM FUNCTIONS

void pendingOrders()
{
  buyStop = OrderSend( 
   Symbol(),              // symbol 
   OP_BUYSTOP,                 // operation 
   volume,              // volume 
   NormalizeDouble(Ask + 40 * Point, Digits),               // price 
   slippage,            // slippage 
   NormalizeDouble(Ask - trailingStopLoss, Digits),            // stop loss 
   NormalizeDouble(trailingTakeProfit, Digits),          // take profit 
   "BUYBOT",        // comment 
   magicBuy,             // magic number 
   0,        // pending order expiration 
   clrAliceBlue  // color 
   ); 
   
   boolBuy = errorSignal(buyStop);
   
   sellStop = OrderSend( 
   Symbol(),              // symbol 
   OP_SELLSTOP,                 // operation 
   volume,              // volume 
   NormalizeDouble(Bid - 40 * Point, Digits),               // price 
   slippage,            // slippage 
   NormalizeDouble(Bid + trailingStopLoss, Digits),            // stop loss 
   NormalizeDouble(trailingTakeProfit, Digits),          // take profit 
   "SELLBOT",        // comment 
   magicSell,             // magic number 
   0,        // pending order expiration 
   clrRed  // color 
   ); 
   
   boolSell = errorSignal(sellStop);
}

bool errorSignal(int &ticketNo)
{
   
      if(ticketNo <= 0) 
        { 
         int error=GetLastError(); 
         //---- not enough money 
         if(error==134) 
         {
            Print("errorSignal: Not enough money! ", __LINE__);
         } 
         else 
         {
            Print("errorSignal: Look for ", error, " error code in MQL4 database", __LINE__);
         }
          return false;
        }
      else
      {
         return true;
      }
       
}

void modifyPendingOrders()
{
   double oldBuyPrice = Ask;
   double oldSellPrice = Bid;
   Sleep(1000);
   RefreshRates(); // the price should get updated otherwise they are going to be equal.
   double currentBuyPrice = Ask;
   double currentSellPrice = Bid;
   
   for(int i = OrdersTotal(); i >= 0 ; i--)
   {
      selectStatus = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (!selectStatus)
      {  
         Print("modifyPendingOrders: OrderSelect FAILED! ERROR CODE: ", GetLastError(), " LINE NO.: ", __LINE__);
         //Print("modifyPendingOrders: ", ErrorDescription(GetLastError()));
      }
      else
      {
         if(OrderType() == OP_BUYSTOP && OrderMagicNumber() == magicBuy)
         {
            modifyStatus = OrderModify(buyStop, NormalizeDouble(currentBuyPrice + 40 * Point, Digits), stopLevelBuyCalc(currentBuyPrice), NormalizeDouble(trailingTakeProfit, Digits), 0, clrAliceBlue);
         if(!modifyStatus)
         {
            Print("FAILED MODIFYING BUY ORDER!");
            Print("MODIFY BUY ORDER ERROR: ", GetLastError(), "LINE NO.: ", __LINE__);
            //Print("ERROR DESCRIPTION: ", ErrorDescription(GetLastError()));
         }
      
         }
         else if( OrderType() == OP_SELLSTOP && OrderMagicNumber() == magicSell)
         {
            modifyStatus = OrderModify(sellStop, NormalizeDouble(currentSellPrice - 40 * Point, Digits), stopLevelSellCalc(currentSellPrice), NormalizeDouble(trailingTakeProfit, Digits), 0,clrRed); 
         if(!modifyStatus)
         {
            Print("FAILED MODIFYING SELL ORDER!");
            Print("MODIFY SELL ORDER ERROR: ", GetLastError(), "LINE NO.: ", __LINE__);
            //Print("ERROR DESCRIPTION: ", ErrorDescription(GetLastError()));
         }
         }
         else if( OrderType() == OP_BUY && OrderTicket() == buyStop )
         {
            // KILL PENDING SELL ORDER
            deleteStatus = OrderDelete(sellStop);
                  if(!deleteStatus)
                  {
                     Print("FAILED CANCELLING PENDING SELL ORDER! LINE NO.: ", __LINE__);
                  }
                  // tracking buy order
                  track(buyStop, "BUY", currentBuyPrice, currentSellPrice);
         }
         else if(OrderType() == OP_SELL && OrderTicket() == sellStop)   
         {
            // KILL PENDING BUY ORDER
            deleteStatus = OrderDelete(buyStop);
                  if(!deleteStatus)
                  {
                     Print("FAILED CANCELLING PENDING BUY ORDER! LINE NO.: ", __LINE__);
                  }
                  // tracking buy order
                  track(sellStop, "SELL", currentBuyPrice, currentSellPrice);
         }   
      }
   }
   
   
}

bool tradeRestriction()
{
   if(DayOfWeek() == 0 || DayOfWeek() == 6) // Saturday && Sunday
   {
      return false;
   } 
   else if(DayOfWeek() == 1) // Monday
   {
      if(Hour() > 10)
      {
         return true;
      }     
      else
      {
         return false;
      }
   }
   else if(DayOfWeek() == 5) // Friday
   {  
      if(Hour() > 16)
      {
         return false;
      }
      else
      {
         return true;
      }
   }
   else
   {
      return true;
   }
   
}

void track(int &ticketNo, const string orderStatus, double &buyPrice, double &sellPrice)
{

RefreshRates(); // update the values 
bool whileExitor = true;
while(whileExitor)
{
   //debug mode
   //Print("TRACK FUNC. IS CALLED!");
   if(OrderSelect(ticketNo,SELECT_BY_TICKET,MODE_TRADES) == true)
   {
      if(orderStatus == "BUY")
      {
         if(NormalizeDouble(Ask - buyPrice, Digits) <  -NormalizeDouble(trailingStopLoss, Digits) )
         {
            // close the order
            closeStatus = OrderClose( 
            ticketNo,      // ticket 
            volume,        // volume 
            Ask,       // close price 
            slippage,    // slippage 
            clrCyan  // color 
             );
             
             // PREPARING FOR NEW CYCLE
             finishedTrade = false;
             whileExitor = false;
             if(!closeStatus)
             { 
               Print("FALED CLOSING BUY ORDER! LINE NO.: ", __LINE__);
             }
             else
             { 
               break;
             }
         }
         else
         {
            // update buyPrice
            buyPrice = Ask;
            Sleep(1000);
            RefreshRates();
         }
      }
      else
      {
         if(NormalizeDouble(Bid - sellPrice, Digits) >  NormalizeDouble(trailingStopLoss, Digits) )
         {
            // close the order
            closeStatus = OrderClose( 
            ticketNo,      // ticket 
            volume,        // volume 
            Bid,       // close price 
            slippage,    // slippage 
            clrCyan  // color 
             );
             // PREPARING FOR NEW CYLCE
             finishedTrade = false;
             whileExitor = false;
             if(!closeStatus)
             { 
               Print("FALED CLOSING BUY ORDER! LINE NO.: ", __LINE__);
             }
             else
             { 
               break;
             }
         }
         else
         {
            // update buyPrice
            sellPrice = Bid;
            Sleep(1000);
            RefreshRates();
         }
         
      }
   }
}  
}

// INCLUSION OF STOPLEVEL 
double stopLevelBuyCalc(double &buyPrice)
{  
   double stopLevel = NormalizeDouble(MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD), Digits);
   if(trailingStopLoss * 10 < stopLevel) // COMPARISON IN POINTS
   {  
      return NormalizeDouble(buyPrice - stopLevel/10.0, Digits) ;
   }
   else
   {  
      return NormalizeDouble(buyPrice - trailingStopLoss, Digits);
   }
   
}

double stopLevelSellCalc(double &sellPrice)
{  
   double stopLevel = NormalizeDouble(MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD), Digits);
   if(trailingStopLoss * 10 < stopLevel) // COMPARISON IN POINTS
   {  
      return NormalizeDouble(sellPrice + stopLevel/10.0, Digits) ;
   }
   else
   {  
      return NormalizeDouble(sellPrice + trailingStopLoss, Digits);
   }
   
}