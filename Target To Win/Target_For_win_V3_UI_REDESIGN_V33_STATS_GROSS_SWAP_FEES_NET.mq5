//+------------------------------------------------------------------+
//|                                            Target_For_win_V3.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property version   "3.10"
#property description "Trading Target Manager - Dashboard MT5"

//====================================================================
// INPUT
//====================================================================

input double InpInitialCapital = 250.00;
input double InpTargetCapital  = 1000.00;
input int    InpWorkingDays    = 20;

input bool   InpUseEquity      = false;

//====================================================================
// PREFIX OGGETTI
//====================================================================

string PREFIX = "TTM3_";

//====================================================================
// COLORI
//====================================================================

color BG_COLOR       = C'13,17,23';
color PANEL_COLOR    = C'22,28,37';
color PANEL2_COLOR   = C'29,36,47';

color BORDER_COLOR   = C'48,58,72';

color TEXT_COLOR     = C'235,238,243';
color MUTED_COLOR    = C'145,158,176';

color BLUE_COLOR     = C'78,145,255';
color GREEN_COLOR    = C'50,205,135';
color RED_COLOR      = C'245,88,96';
color YELLOW_COLOR   = C'245,190,72';
color ORANGE_COLOR   = C'255,155,55';

color EDIT_BG        = C'235,239,245';
color EDIT_TEXT      = C'25,28,34';

color BUTTON_BG      = C'43,54,70';
color BUTTON_TEXT    = C'245,247,250';

//====================================================================
// DATI PERCORSO
//====================================================================

double g_initial_capital = 0.0;
double g_target_capital  = 0.0;

int g_total_days = 20;

// Calendari separati:
// LIVE/ORDINI/STATISTICHE usano g_live_total_days.
// SIMULATORE/PIANO usano g_sim_total_days.
int g_live_total_days = 20;
int g_sim_total_days  = 20;

datetime g_start_date = 0;

//====================================================================
// DATI ACCOUNT
//====================================================================

double g_balance = 0.0;
double g_equity  = 0.0;

double g_current_capital = 0.0;

//====================================================================
// MODALITA' SIMULATORE
//====================================================================
bool   g_simulator_mode    = false;
double g_sim_capital       = 250.00;
int    g_sim_day           = 1;

double g_sim_open[367];
double g_sim_required_end[367];
double g_sim_result_eur[367];
double g_sim_result_pct[367];
double g_sim_close[367];
double g_sim_delta_vs_plan[367];
bool   g_sim_recorded[367];

double g_sim_day_result_input = 0.0;
int    g_current_page      = 1;   // 1=LIVE 2=ORDINI 3=RISK MANAGER 4=SIMULATORE 5=PIANO 6=STATISTICHE

// Offset di scorrimento delle tabelle.
// Visualizziamo 25 righe alla volta e le spostiamo con SU/GIU.
int g_scroll_orders = 0;
int g_scroll_sim    = 0;
int g_scroll_plan   = 0;
int g_scroll_stats  = 0;

const int DATA_ROWS_VISIBLE = 25;

// Limite massimo di giorni lavorativi pianificabili.
// Gli array del simulatore/piano sono da 367: teniamo un margine ampio.
const int MAX_WORKING_DAYS = 260;

int ClampWorkingDays(int d)
{
   if(d < 1) return 1;
   if(d > MAX_WORKING_DAYS) return MAX_WORKING_DAYS;
   return d;
}

//====================================================================
// PARSING NUMERICO TOLLERANTE
// Accetta sia il formato con punto decimale ("1000.50")
// sia quello all'italiana ("1.000,50" o "1000,50").
// Rimuove spazi e apostrofi usati come separatore migliaia.
//====================================================================
double ParseNumber(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);

   StringReplace(s," ","");
   StringReplace(s,"'","");
   StringReplace(s," ","");   // spazio insecabile

   bool has_dot   = (StringFind(s,".") >= 0);
   bool has_comma = (StringFind(s,",") >= 0);

   if(has_dot && has_comma)
   {
      // Il separatore decimale e' l'ultimo simbolo che compare.
      if(StringFind(s,",") > StringFind(s,"."))
      {
         StringReplace(s,".","");   // punti = migliaia
         StringReplace(s,",",".");  // virgola = decimale
      }
      else
      {
         StringReplace(s,",","");   // virgole = migliaia
      }
   }
   else
   if(has_comma)
   {
      StringReplace(s,",",".");
   }

   return StringToDouble(s);
}

int ParseInteger(string s)
{
   return (int)MathRound(ParseNumber(s));
}

long ParseLong(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   StringReplace(s," ","");
   StringReplace(s,"'","");
   return (long)StringToInteger(s);
}

//====================================================================
// RISK MANAGER
//====================================================================
bool     g_strategy_enabled             = false;
bool     g_strategy_scope_account       = false;   // false = solo Magic
long     g_strategy_magic               = 29082026;

double   g_strategy_fixed_lot           = 0.01;
int      g_strategy_max_open_positions  = 1;
int      g_strategy_max_trades_day      = 20;

double   g_strategy_tp_eur              = 3.00;
double   g_strategy_sl_eur              = 1.80;

bool     g_strategy_daily_target_auto   = true;
double   g_strategy_daily_target_manual = 15.00;
double   g_strategy_daily_loss_limit    = 7.20;

bool     g_strategy_alert_on_limit      = false;   // Alert MT5 quando scatta il lock giornaliero
bool     g_strategy_limit_alerted       = false;   // gia' avvisato per la giornata corrente

int      g_strategy_losses_before_pause = 2;
int      g_strategy_pause_minutes       = 60;
int      g_strategy_consec_losses       = 0;
int      g_strategy_consec_wins         = 0;
datetime g_strategy_pause_until         = 0;
bool     g_strategy_daily_locked        = false;
datetime g_strategy_day                 = 0;
bool     g_strategy_force_refresh       = true;   // forza il ricalcolo serie/pausa al prossimo giro



double g_total_profit = 0.0;
double g_total_return = 0.0;

//====================================================================
// DATI TARGET
//====================================================================

int g_days_elapsed   = 0;
int g_days_remaining = 0;

double g_progress = 0.0;

double g_required_pct   = 0.0;
double g_required_money = 0.0;

bool g_target_reached = false;

//====================================================================
// DIMENSIONI
//====================================================================

int g_width  = 760;
int g_height = 760;

// Dimensione reale (non clampata) del grafico all'ultimo rebuild.
int g_chart_px_w = 0;
int g_chart_px_h = 0;

// Area utile della dashboard: centrata e con larghezza massima.
// In questo modo su monitor larghi il pannello non si "stira" per 1800 px.
int g_dash_x = 18;
int g_dash_w = 1100;
int g_bar_w  = 1000;

//====================================================================
// NOME OGGETTI
//====================================================================

// Header
string O_TITLE    = PREFIX + "TITLE";
string O_SUBTITLE = PREFIX + "SUBTITLE";

// Parametri
string O_PARAM_PANEL = PREFIX + "PARAM_PANEL";
string O_PARAM_TITLE = PREFIX + "PARAM_TITLE";

string O_INITIAL_LABEL = PREFIX + "INITIAL_LABEL";
string O_INITIAL_EDIT  = PREFIX + "INITIAL_EDIT";

string O_TARGET_LABEL = PREFIX + "TARGET_LABEL";
string O_TARGET_EDIT  = PREFIX + "TARGET_EDIT";

string O_DAYS_LABEL = PREFIX + "DAYS_LABEL";
string O_DAYS_EDIT  = PREFIX + "DAYS_EDIT";

string O_START_LABEL = PREFIX + "START_LABEL";
string O_START_EDIT  = PREFIX + "START_EDIT";

string O_MINUS = PREFIX + "MINUS";
string O_PLUS  = PREFIX + "PLUS";

string O_CALCULATE = PREFIX + "CALCULATE";
string O_RESET     = PREFIX + "RESET";

// Account
string O_ACCOUNT_PANEL = PREFIX + "ACCOUNT_PANEL";
string O_ACCOUNT_TITLE = PREFIX + "ACCOUNT_TITLE";

string O_BALANCE = PREFIX + "BALANCE";
string O_EQUITY  = PREFIX + "EQUITY";
string O_PROFIT  = PREFIX + "PROFIT";
string O_RETURN  = PREFIX + "RETURN";

// Progress
string O_PROGRESS_PANEL = PREFIX + "PROGRESS_PANEL";
string O_PROGRESS_TITLE = PREFIX + "PROGRESS_TITLE";

string O_PROGRESS_BAR_BG = PREFIX + "PROGRESS_BG";
string O_PROGRESS_BAR    = PREFIX + "PROGRESS_BAR";

string O_PROGRESS_TEXT = PREFIX + "PROGRESS_TEXT";

string O_DAY       = PREFIX + "DAY";
string O_REMAINING = PREFIX + "REMAINING";

// Target
string O_TARGET_TITLE  = PREFIX + "TARGET_TITLE";
string O_REQUIRED_PCT  = PREFIX + "REQUIRED_PCT";
string O_REQUIRED_EURO = PREFIX + "REQUIRED_EURO";

string O_STATUS = PREFIX + "STATUS";

// Pair
string O_SYMBOL_PANEL = PREFIX + "SYMBOL_PANEL";
string O_SYMBOL_TITLE = PREFIX + "SYMBOL_TITLE";
string O_SYMBOL_TEXT  = PREFIX + "SYMBOL_TEXT";

//====================================================================
// UTILITY
//====================================================================

string ObjName(string base)
{
   return PREFIX + base;
}

//====================================================================
// CREA RECTANGLE
//====================================================================

void CreatePanel(
   string name,
   int x,
   int y,
   int w,
   int h,
   color bg,
   color border
)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      w
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      h
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      bg
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      border
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_TYPE,
      BORDER_FLAT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );
}

//====================================================================
// CREA LABEL
//====================================================================

void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   int w,
   int h,
   color clr,
   int fontsize,
   ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER
)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      anchor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clr
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      fontsize
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Segoe UI"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );
}

//====================================================================
// CREA EDIT
//====================================================================

void CreateEdit(
   string name,
   string text,
   int x,
   int y,
   int w,
   int h
)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_EDIT,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,EDIT_BG);
   ObjectSetInteger(0,name,OBJPROP_COLOR,EDIT_TEXT);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,BORDER_COLOR);

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,11);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_ALIGN,ALIGN_CENTER);

   // IMPORTANTE:
   // READONLY=false => il contenuto può essere scritto.
   // SELECTABLE=false => il click non entra nella modalità di spostamento
   // dell'oggetto, ma viene usato dall'EDIT per modificare il testo.
   ObjectSetInteger(0,name,OBJPROP_READONLY,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);

   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);

   ObjectSetString(
      0,
      name,
      OBJPROP_TOOLTIP,
      "Clicca qui e inserisci il nuovo valore"
   );
}

//====================================================================
// CREA BUTTON
//====================================================================

void CreateButton(
   string name,
   string text,
   int x,
   int y,
   int w,
   int h
)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_BUTTON,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      w
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      h
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      BUTTON_BG
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      BUTTON_TEXT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      BORDER_COLOR
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      10
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Segoe UI"
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );
}

//====================================================================
// DELETE OBJECT
//====================================================================

void DeleteObjectSafe(string name)
{
   if(ObjectFind(0,name) >= 0)
      ObjectDelete(0,name);
}

//====================================================================
// DELETE DASHBOARD
//====================================================================

void DeleteDashboard()
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name =
         ObjectName(
            0,
            i
         );

      if(StringFind(name,PREFIX) == 0)
         ObjectDelete(
            0,
            name
         );
   }
}

//====================================================================
// WORKING DAY
//====================================================================

bool IsWorkingDay(datetime t)
{
   MqlDateTime dt;

   TimeToStruct(t,dt);

   return(
      dt.day_of_week >= 1 &&
      dt.day_of_week <= 5
   );
}

//====================================================================
// WORKING DAYS
//====================================================================

int WorkingDaysBetween(
   datetime start,
   datetime finish
)
{
   if(finish < start)
      return 0;

   MqlDateTime s;
   MqlDateTime f;

   TimeToStruct(start,s);
   TimeToStruct(finish,f);

   s.hour = 0;
   s.min  = 0;
   s.sec  = 0;

   f.hour = 0;
   f.min  = 0;
   f.sec  = 0;

   datetime current =
      StructToTime(s);

   datetime end =
      StructToTime(f);

   int count = 0;

   while(current <= end)
   {
      if(IsWorkingDay(current))
         count++;

      current += 86400;
   }

   return count;
}

//====================================================================
// RISULTATO TRADING DI OGGI - LIVE
// Somma profitto, swap e commissioni dei deal chiusi da mezzanotte.
//====================================================================
double GetTodayClosedResult()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);

   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;

   datetime day_start = StructToTime(dt);

   if(!HistorySelect(day_start,TimeCurrent()))
      return 0.0;

   double result = 0.0;
   int total = HistoryDealsTotal();

   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      long entry =
         HistoryDealGetInteger(ticket,DEAL_ENTRY);

      if(entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT)
         continue;

      result +=
         HistoryDealGetDouble(ticket,DEAL_PROFIT)
         +
         HistoryDealGetDouble(ticket,DEAL_SWAP)
         +
         HistoryDealGetDouble(ticket,DEAL_COMMISSION);
   }

   return result;
}

//====================================================================
// CAPITALE LIVE A INIZIO GIORNATA
// Con Balance: balance attuale - risultato chiuso di oggi.
// Con Equity: aggiungiamo anche il floating corrente al risultato di oggi,
// così il confronto giornaliero include anche le posizioni aperte.
//====================================================================
double GetLiveDayStartCapital()
{
   double closed_today = GetTodayClosedResult();

   if(InpUseEquity)
   {
      double floating_now =
         AccountInfoDouble(ACCOUNT_PROFIT);

      return g_current_capital -
             closed_today -
             floating_now;
   }

   return g_current_capital -
          closed_today;
}

//====================================================================
// POSIZIONI APERTE - LIVE
//====================================================================
double GetOpenFloatingResult()
{
   double total = 0.0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      total += PositionGetDouble(POSITION_PROFIT);
      total += PositionGetDouble(POSITION_SWAP);
   }

   return total;
}

// Potenziale complessivo se ogni posizione raggiungesse il proprio TP.
// Le posizioni senza TP non vengono conteggiate.
double GetOpenPotentialTP()
{
   double total = 0.0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp     = PositionGetDouble(POSITION_TP);

      if(tp <= 0)
         continue;

      long ptype = PositionGetInteger(POSITION_TYPE);
      ENUM_ORDER_TYPE otype =
         (ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

      double value = 0.0;

      if(OrderCalcProfit(
            otype,
            symbol,
            volume,
            open,
            tp,
            value
         ))
      {
         total += value;
      }
   }

   return total;
}

// Rischio complessivo se ogni posizione raggiungesse il proprio SL.
// Normalmente sarà negativo. Le posizioni senza SL non vengono conteggiate.
double GetOpenRiskSL()
{
   double total = 0.0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);

      if(sl <= 0)
         continue;

      long ptype = PositionGetInteger(POSITION_TYPE);
      ENUM_ORDER_TYPE otype =
         (ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

      double value = 0.0;

      if(OrderCalcProfit(
            otype,
            symbol,
            volume,
            open,
            sl,
            value
         ))
      {
         total += value;
      }
   }

   return total;
}

//====================================================================
// RESET STORICO SIMULATORE
//====================================================================
void ResetSimulatorHistory()
{
   for(int i=0; i<367; i++)
   {
      g_sim_open[i] = 0.0;
      g_sim_required_end[i] = 0.0;
      g_sim_result_eur[i] = 0.0;
      g_sim_result_pct[i] = 0.0;
      g_sim_close[i] = 0.0;
      g_sim_delta_vs_plan[i] = 0.0;
      g_sim_recorded[i] = false;
   }

   g_sim_day_result_input = 0.0;
}

//====================================================================
// CURRENT CAPITAL
//====================================================================

double GetCurrentCapital()
{
   // In modalità simulatore il capitale è completamente manuale
   // e NON viene letto dal conto MT5.
   if(g_simulator_mode)
      return g_sim_capital;

   if(InpUseEquity)
      return AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   return AccountInfoDouble(
      ACCOUNT_BALANCE
   );
}

//====================================================================
// CALCOLO
//====================================================================

void CalculateTarget()
{
   g_total_days =
      g_simulator_mode
      ? g_sim_total_days
      : g_live_total_days;

   g_balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );

   g_equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   g_current_capital =
      GetCurrentCapital();

   //---------------------------------------------------------------
   // PROFITTO
   //---------------------------------------------------------------

   g_total_profit =
      g_current_capital -
      g_initial_capital;

   if(g_initial_capital > 0)
   {
      g_total_return =
         (
            g_total_profit /
            g_initial_capital
         ) * 100.0;
   }
   else
   {
      g_total_return = 0;
   }

   //---------------------------------------------------------------
   // GIORNI
   //---------------------------------------------------------------

   int completed_days = 0;

   if(g_simulator_mode)
   {
      if(g_sim_day < 1) g_sim_day = 1;
      if(g_sim_day > g_total_days) g_sim_day = g_total_days;

      g_days_elapsed = g_sim_day;
      completed_days = g_sim_day - 1;
      g_days_remaining = g_total_days - completed_days;
   }
   else
   {
      // Giorni lavorativi "toccati" dal percorso, incluso oggi.
      int working_days_seen =
         WorkingDaysBetween(
            g_start_date,
            TimeCurrent()
         );

      // I giorni COMPLETATI sono quelli precedenti a oggi.
      completed_days = working_days_seen - 1;
      if(completed_days < 0)
         completed_days = 0;

      if(completed_days > g_total_days)
         completed_days = g_total_days;

      g_days_elapsed = completed_days + 1;
      if(g_days_elapsed > g_total_days)
         g_days_elapsed = g_total_days;

      g_days_remaining =
         g_total_days -
         completed_days;
   }

   if(g_days_remaining < 0)
      g_days_remaining = 0;

   //---------------------------------------------------------------
   // PROGRESSO
   //---------------------------------------------------------------

   if(
      g_target_capital >
      g_initial_capital
   )
   {
      g_progress =
         (
            (
               g_current_capital -
               g_initial_capital
            )
            /
            (
               g_target_capital -
               g_initial_capital
            )
         ) * 100.0;
   }
   else
   {
      g_progress = 100.0;
   }

   if(g_progress < 0)
      g_progress = 0;

   if(g_progress > 100)
      g_progress = 100;

   //---------------------------------------------------------------
   // TARGET
   //---------------------------------------------------------------

   if(
      g_current_capital >=
      g_target_capital
   )
   {
      g_target_reached = true;

      g_required_pct = 0;
      g_required_money = 0;

      return;
   }

   g_target_reached = false;

   //---------------------------------------------------------------
   // TEMPO TERMINATO
   //---------------------------------------------------------------

   if(g_days_remaining <= 0)
   {
      g_required_pct = 0;

      g_required_money =
         g_target_capital -
         g_current_capital;

      return;
   }

   //---------------------------------------------------------------
   // COMPOUNDING
   //---------------------------------------------------------------

   if(g_current_capital > 0)
   {
      g_required_pct =
         (
            MathPow(
               g_target_capital /
               g_current_capital,
               1.0 /
               g_days_remaining
            )
            - 1.0
         ) * 100.0;

      g_required_money =
         g_current_capital *
         g_required_pct /
         100.0;
   }
}

//====================================================================
// SIMBOLO STATS
//====================================================================

struct SymbolStats
{
   string symbol;

   int trades;
   int wins;
   int losses;

   // Componenti economiche separate.
   double gross_profit;   // DEAL_PROFIT delle chiusure
   double swap;           // DEAL_SWAP delle chiusure
   double commission;     // commissioni di tutti i deal del simbolo
   double profit;         // NETTO = lordo + swap + commissioni
};

//====================================================================
// COSTRUISCI STATS
//
// Componenti economiche (lordo/swap/commissioni) come prima: il NETTO
// per simbolo riconcilia con i totali del conto MT5.
//
// Win/Loss ora sul NETTO REALE PER POSIZIONE = somma di lordo + swap +
// TUTTE le commissioni (ingresso + uscita) di quella posizione. Una
// posizione con netto negativo non puo' piu' risultare "WIN".
// "trades" = numero di posizioni chiuse (chiusure parziali contano 1).
//====================================================================

int GetSymbolStats(
   SymbolStats &stats[]
)
{
   ArrayResize(stats,0);

   // Tutto lo storico disponibile sul conto.
   if(!HistorySelect(0,TimeCurrent()))
      return 0;

   int total = HistoryDealsTotal();

   // Accumulo per POSIZIONE (per il conteggio W/L sul netto reale).
   ulong  pos_id[];
   string pos_sym[];
   double pos_net[];
   bool   pos_closed[];
   int    pos_n = 0;

   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      string symbol = HistoryDealGetString(ticket,DEAL_SYMBOL);
      if(symbol == "")
         continue;

      long   entry = HistoryDealGetInteger(ticket,DEAL_ENTRY);
      double gross = HistoryDealGetDouble(ticket,DEAL_PROFIT);
      double swp   = HistoryDealGetDouble(ticket,DEAL_SWAP);
      double comm  = HistoryDealGetDouble(ticket,DEAL_COMMISSION);

      bool is_close =
         (entry == DEAL_ENTRY_OUT ||
          entry == DEAL_ENTRY_OUT_BY ||
          entry == DEAL_ENTRY_INOUT);

      // Riga simbolo
      int index = -1;
      for(int j=0; j<ArraySize(stats); j++)
      {
         if(stats[j].symbol == symbol)
         {
            index = j;
            break;
         }
      }

      if(index < 0)
      {
         index = ArraySize(stats);
         ArrayResize(stats,index+1);

         stats[index].symbol       = symbol;
         stats[index].trades       = 0;
         stats[index].wins         = 0;
         stats[index].losses       = 0;
         stats[index].gross_profit = 0.0;
         stats[index].swap         = 0.0;
         stats[index].commission   = 0.0;
         stats[index].profit       = 0.0;
      }

      // Commissione: da TUTTI i deal (ingresso + uscita).
      stats[index].commission += comm;

      // Lordo e swap: solo dai deal di chiusura.
      if(is_close)
      {
         stats[index].gross_profit += gross;
         stats[index].swap         += swp;
      }

      // Accumulo per posizione.
      ulong pid = (ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
      if(pid > 0)
      {
         int pi = -1;
         for(int j=0; j<pos_n; j++)
         {
            if(pos_id[j] == pid)
            {
               pi = j;
               break;
            }
         }

         if(pi < 0)
         {
            pi = pos_n;
            pos_n++;
            ArrayResize(pos_id,pos_n);
            ArrayResize(pos_sym,pos_n);
            ArrayResize(pos_net,pos_n);
            ArrayResize(pos_closed,pos_n);

            pos_id[pi]     = pid;
            pos_sym[pi]    = symbol;
            pos_net[pi]    = 0.0;
            pos_closed[pi] = false;
         }

         pos_net[pi] += gross + swp + comm;
         if(is_close)
            pos_closed[pi] = true;
      }
   }

   // Aggrega W/L per simbolo dalle posizioni chiuse.
   for(int j=0; j<pos_n; j++)
   {
      if(!pos_closed[j])
         continue;

      int index = -1;
      for(int k=0; k<ArraySize(stats); k++)
      {
         if(stats[k].symbol == pos_sym[j])
         {
            index = k;
            break;
         }
      }

      if(index < 0)
         continue;

      stats[index].trades++;

      if(pos_net[j] > 0.0000001)
         stats[index].wins++;
      else
      if(pos_net[j] < -0.0000001)
         stats[index].losses++;
   }

   // Netto finale esplicito.
   for(int i=0; i<ArraySize(stats); i++)
   {
      stats[i].profit =
         stats[i].gross_profit +
         stats[i].swap +
         stats[i].commission;
   }

   return ArraySize(stats);
}

//====================================================================
// CACHE STATISTICHE
// GetSymbolStats() scansiona tutto lo storico: lo facciamo al massimo
// ogni 10s, o subito dopo un evento trade (g_stats_cache_time=0).
//====================================================================
datetime    g_stats_cache_time = 0;
SymbolStats g_stats_cache[];

int GetSymbolStatsCached(SymbolStats &out[])
{
   if(g_stats_cache_time == 0 ||
      TimeCurrent() - g_stats_cache_time >= 10)
   {
      GetSymbolStats(g_stats_cache);
      g_stats_cache_time = TimeCurrent();
   }

   int n = ArraySize(g_stats_cache);
   ArrayResize(out,n);
   for(int i=0; i<n; i++)
      out[i] = g_stats_cache[i];

   return n;
}
//====================================================================
// CREAZIONE DASHBOARD
//====================================================================

//====================================================================
// RISK MANAGER - HELPERS
//====================================================================
datetime StrategyDayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   return StructToTime(dt);
}

bool StrategyDealMatches(ulong deal)
{
   if(deal==0) return false;

   string symbol=HistoryDealGetString(deal,DEAL_SYMBOL);
   if(symbol=="") return false;

   if(g_strategy_scope_account)
      return true;

   long magic=(long)HistoryDealGetInteger(deal,DEAL_MAGIC);
   return (magic==g_strategy_magic);
}

bool StrategyPositionMatches()
{
   if(g_strategy_scope_account)
      return true;

   long magic=(long)PositionGetInteger(POSITION_MAGIC);
   return (magic==g_strategy_magic);
}

double StrategyTodayClosedResult()
{
   if(!HistorySelect(StrategyDayStart(),TimeCurrent()))
      return 0.0;

   double total=0.0;

   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || !StrategyDealMatches(deal))
         continue;

      ENUM_DEAL_ENTRY entry=
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);

      if(entry!=DEAL_ENTRY_OUT &&
         entry!=DEAL_ENTRY_OUT_BY &&
         entry!=DEAL_ENTRY_INOUT)
         continue;

      total += HistoryDealGetDouble(deal,DEAL_PROFIT)
             + HistoryDealGetDouble(deal,DEAL_SWAP)
             + HistoryDealGetDouble(deal,DEAL_COMMISSION);
   }

   return total;
}

int StrategyTradesToday()
{
   if(!HistorySelect(StrategyDayStart(),TimeCurrent()))
      return 0;

   int count=0;

   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || !StrategyDealMatches(deal))
         continue;

      ENUM_DEAL_ENTRY entry=
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);

      if(entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT)
         count++;
   }

   return count;
}

int StrategyOpenPositions()
{
   int count=0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!StrategyPositionMatches()) continue;
      count++;
   }

   return count;
}

double StrategyOpenFloating()
{
   double total=0.0;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!StrategyPositionMatches()) continue;

      total += PositionGetDouble(POSITION_PROFIT)
             + PositionGetDouble(POSITION_SWAP);
   }

   return total;
}

string StrategyScopeText()
{
   if(g_strategy_scope_account)
      return "ACCOUNT";

   return "MAGIC "+IntegerToString(g_strategy_magic);
}

// Giorni lavorativi COMPLETATI dal percorso LIVE (esclude oggi).
// Ricalcolato da g_start_date: non dipende dal fatto che CalculateTarget()
// sia stato eseguito in questo ciclo.
int LiveCompletedDays()
{
   int seen = WorkingDaysBetween(g_start_date, TimeCurrent());
   int completed = seen - 1;
   if(completed < 0) completed = 0;
   if(completed > g_live_total_days) completed = g_live_total_days;
   return completed;
}

double StrategyDailyTargetEUR()
{
   if(!g_strategy_daily_target_auto)
      return g_strategy_daily_target_manual;

   // Stesso target giornaliero del LIVE.
   double start=GetLiveDayStartCapital();

   int completed=LiveCompletedDays();

   int remaining=g_live_total_days-completed;
   if(remaining<1) remaining=1;

   double endTarget=start;

   if(start>0 && g_target_capital>start)
   {
      double factor=MathPow(
         g_target_capital/start,
         1.0/(double)remaining
      );
      endTarget=start*factor;
   }

   if(remaining==1)
      endTarget=g_target_capital;

   double req=endTarget-start;
   if(req<0) req=0;

   return req;
}

void StrategyResetDay()
{
   datetime today=StrategyDayStart();

   if(g_strategy_day==0)
      g_strategy_day=today;

   if(today==g_strategy_day)
      return;

   g_strategy_day=today;
   g_strategy_daily_locked=false;
   g_strategy_pause_until=0;
   g_strategy_consec_losses=0;
   g_strategy_consec_wins=0;
   g_strategy_limit_alerted=false;
   g_strategy_force_refresh=true;
   SavePersistentState();
}

// Ricalcola le serie W/L consecutive e la finestra di pausa leggendo i
// deal CHIUSI di oggi in ordine cronologico. Nessuno stato incrementale:
// il risultato e' sempre corretto anche dopo reload / disconnessioni.
void StrategyRecomputeSeries()
{
   g_strategy_consec_wins=0;
   g_strategy_consec_losses=0;
   g_strategy_pause_until=0;

   if(!HistorySelect(StrategyDayStart(),TimeCurrent()))
      return;

   int losses_since_pause=0;
   int total=HistoryDealsTotal();

   for(int i=0;i<total;i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || !StrategyDealMatches(deal))
         continue;

      ENUM_DEAL_ENTRY entry=
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);

      if(entry!=DEAL_ENTRY_OUT &&
         entry!=DEAL_ENTRY_OUT_BY &&
         entry!=DEAL_ENTRY_INOUT)
         continue;

      double net=HistoryDealGetDouble(deal,DEAL_PROFIT)
                +HistoryDealGetDouble(deal,DEAL_SWAP)
                +HistoryDealGetDouble(deal,DEAL_COMMISSION);

      datetime dt=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);

      if(net>0.0000001)
      {
         g_strategy_consec_wins++;
         g_strategy_consec_losses=0;
         losses_since_pause=0;
      }
      else
      if(net<-0.0000001)
      {
         g_strategy_consec_losses++;
         g_strategy_consec_wins=0;
         losses_since_pause++;

         if(g_strategy_losses_before_pause>0 &&
            losses_since_pause>=g_strategy_losses_before_pause)
         {
            g_strategy_pause_until=dt+g_strategy_pause_minutes*60;
            losses_since_pause=0;
         }
      }
   }
}

void StrategyRefreshState()
{
   StrategyResetDay();

   // Ricalcolo pesante (scansione storico) al massimo ogni 10 secondi,
   // oppure subito se e' arrivato un evento trade.
   static datetime last_calc=0;
   if(g_strategy_force_refresh || TimeCurrent()-last_calc>=10)
   {
      last_calc=TimeCurrent();
      g_strategy_force_refresh=false;
      StrategyRecomputeSeries();
   }

   double closed=StrategyTodayClosedResult();
   double target=StrategyDailyTargetEUR();

   // Il lock giornaliero e' "sticky": una volta scattato resta fino al
   // cambio di giornata (StrategyResetDay).
   if(target>0 && closed>=target)
      g_strategy_daily_locked=true;

   if(g_strategy_daily_loss_limit>0 &&
      closed<=-g_strategy_daily_loss_limit)
      g_strategy_daily_locked=true;

   // Avviso MT5 una sola volta al giorno quando scatta il lock.
   if(g_strategy_alert_on_limit &&
      g_strategy_daily_locked &&
      !g_strategy_limit_alerted)
   {
      g_strategy_limit_alerted=true;
      Alert("TTM: limite giornaliero raggiunto (realizzato ",
            DoubleToString(closed,2),
            " EUR). Stop operativita' consigliato.");
   }

   SavePersistentState();
}

bool StrategyCanTrade(string &reason)
{
   StrategyRefreshState();

   if(!g_strategy_enabled)
   {
      reason="MONITOR OFF";
      return false;
   }

   if(g_strategy_daily_locked)
   {
      reason="DAILY LOCK";
      return false;
   }

   if(TimeCurrent()<g_strategy_pause_until)
   {
      reason="IN PAUSA";
      return false;
   }

   if(g_strategy_max_open_positions>0 &&
      StrategyOpenPositions()>=g_strategy_max_open_positions)
   {
      reason="MAX POSIZIONI";
      return false;
   }

   if(g_strategy_max_trades_day>0 &&
      StrategyTradesToday()>=g_strategy_max_trades_day)
   {
      reason="MAX TRADE/GG";
      return false;
   }

   reason="OK";
   return true;
}

// Restituisce un prezzo TP/SL che corrisponde circa
// all'importo richiesto nella VALUTA DEL CONTO.
// Usa OrderCalcProfit(), tick size e vincoli broker.
double StrategyPriceForMoney(
   string symbol,
   ENUM_ORDER_TYPE type,
   double volume,
   double entry_price,
   double money_value,
   bool is_tp
)
{
   if(volume<=0 || money_value<=0 || entry_price<=0)
      return 0.0;

   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) tick=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(tick<=0) return 0.0;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   double direction;
   if(type==ORDER_TYPE_BUY)
      direction = is_tp ? 1.0 : -1.0;
   else
      direction = is_tp ? -1.0 : 1.0;

   double low=0.0;
   double high=tick;
   double p=0.0;

   for(int i=0;i<40;i++)
   {
      double test=NormalizeDouble(entry_price+direction*high,digits);

      if(!OrderCalcProfit(type,symbol,volume,entry_price,test,p))
         return 0.0;

      if(MathAbs(p)>=money_value)
         break;

      high*=2.0;
   }

   for(int i=0;i<50;i++)
   {
      double mid=(low+high)/2.0;
      double test=NormalizeDouble(entry_price+direction*mid,digits);

      if(!OrderCalcProfit(type,symbol,volume,entry_price,test,p))
         return 0.0;

      if(MathAbs(p)>=money_value) high=mid;
      else low=mid;
   }

   double price=entry_price+direction*high;
   price=MathRound(price/tick)*tick;
   price=NormalizeDouble(price,digits);

   long stops=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double minDist=MathMax((double)stops,(double)freeze)*point;

   double market=
      (type==ORDER_TYPE_BUY)
      ? SymbolInfoDouble(symbol,SYMBOL_BID)
      : SymbolInfoDouble(symbol,SYMBOL_ASK);

   if(minDist>0 && MathAbs(price-market)<minDist)
   {
      price=market+direction*minDist;
      price=MathRound(price/tick)*tick;
      price=NormalizeDouble(price,digits);
   }

   return price;
}

//====================================================================
// PERSISTENZA STATO LIVE / RISK MANAGER
//====================================================================
string StateKey(string suffix)
{
   string login = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   return "TTM_" + login + "_" + suffix;
}

// Scrive la Global Variable solo se il valore e' effettivamente cambiato.
// Evita la riscrittura continua su disco (SavePersistentState viene
// invocata anche a ogni tick del timer).
void GVSetIfChanged(string key, double value)
{
   if(GlobalVariableCheck(key) &&
      MathAbs(GlobalVariableGet(key) - value) < 0.0000001)
      return;

   GlobalVariableSet(key, value);
}

void SavePersistentState()
{
   GVSetIfChanged(StateKey("START"),      (double)g_start_date);
   GVSetIfChanged(StateKey("INITIAL"),    g_initial_capital);
   GVSetIfChanged(StateKey("TARGET"),     g_target_capital);
   GVSetIfChanged(StateKey("LIVE_DAYS"),  (double)g_live_total_days);
   GVSetIfChanged(StateKey("SIM_DAYS"),   (double)g_sim_total_days);

   GVSetIfChanged(StateKey("RISK_ON"),    g_strategy_enabled ? 1.0 : 0.0);
   GVSetIfChanged(StateKey("RISK_SCOPE"), g_strategy_scope_account ? 1.0 : 0.0);
   GVSetIfChanged(StateKey("MAGIC"),      (double)g_strategy_magic);

   GVSetIfChanged(StateKey("DAILY_LOCK"), g_strategy_daily_locked ? 1.0 : 0.0);
   GVSetIfChanged(StateKey("PAUSE_UNTIL"),(double)g_strategy_pause_until);
   GVSetIfChanged(StateKey("STRAT_DAY"),  (double)g_strategy_day);

   GVSetIfChanged(StateKey("CONS_LOSS"),  (double)g_strategy_consec_losses);
   GVSetIfChanged(StateKey("CONS_WIN"),   (double)g_strategy_consec_wins);
}

bool LoadPersistentState()
{
   bool found = false;

   if(GlobalVariableCheck(StateKey("START")))
   {
      g_start_date = (datetime)GlobalVariableGet(StateKey("START"));
      found = true;
   }

   if(GlobalVariableCheck(StateKey("INITIAL")))
      g_initial_capital = GlobalVariableGet(StateKey("INITIAL"));

   if(GlobalVariableCheck(StateKey("TARGET")))
      g_target_capital = GlobalVariableGet(StateKey("TARGET"));

   if(GlobalVariableCheck(StateKey("LIVE_DAYS")))
      g_live_total_days = ClampWorkingDays((int)GlobalVariableGet(StateKey("LIVE_DAYS")));

   if(GlobalVariableCheck(StateKey("SIM_DAYS")))
      g_sim_total_days = ClampWorkingDays((int)GlobalVariableGet(StateKey("SIM_DAYS")));

   if(GlobalVariableCheck(StateKey("RISK_ON")))
      g_strategy_enabled = GlobalVariableGet(StateKey("RISK_ON")) > 0.5;

   if(GlobalVariableCheck(StateKey("RISK_SCOPE")))
      g_strategy_scope_account = GlobalVariableGet(StateKey("RISK_SCOPE")) > 0.5;

   if(GlobalVariableCheck(StateKey("MAGIC")))
      g_strategy_magic = (long)GlobalVariableGet(StateKey("MAGIC"));

   if(GlobalVariableCheck(StateKey("DAILY_LOCK")))
      g_strategy_daily_locked = GlobalVariableGet(StateKey("DAILY_LOCK")) > 0.5;

   if(GlobalVariableCheck(StateKey("PAUSE_UNTIL")))
      g_strategy_pause_until = (datetime)GlobalVariableGet(StateKey("PAUSE_UNTIL"));

   if(GlobalVariableCheck(StateKey("STRAT_DAY")))
      g_strategy_day = (datetime)GlobalVariableGet(StateKey("STRAT_DAY"));

   if(GlobalVariableCheck(StateKey("CONS_LOSS")))
      g_strategy_consec_losses = (int)GlobalVariableGet(StateKey("CONS_LOSS"));

   if(GlobalVariableCheck(StateKey("CONS_WIN")))
      g_strategy_consec_wins = (int)GlobalVariableGet(StateKey("CONS_WIN"));

   return found;
}

// Cerca il primo deal disponibile nello storico del conto.
// Serve soltanto come fallback per recuperare una data storica
// quando la V31 viene installata per la prima volta e non esiste
// ancora uno stato persistente salvato.
datetime FindEarliestAccountDealTime()
{
   if(!HistorySelect(0, TimeCurrent()))
      return 0;

   int total = HistoryDealsTotal();

   datetime earliest = 0;

   for(int i=0; i<total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      datetime t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);

      if(t <= 0)
         continue;

      if(earliest == 0 || t < earliest)
         earliest = t;
   }

   return earliest;
}

//====================================================================
// CONTROLLI SCORRIMENTO TABELLE
//====================================================================
void CreateScrollControls(
   int x,
   int y,
   int panel_right,
   string prefix
)
{
   CreateButton(
      ObjName(prefix+"_SCROLL_UP"),
      "SU",
      panel_right-178,
      y,
      48,
      28
   );

   CreateLabel(
      ObjName(prefix+"_SCROLL_INFO"),
      "",
      panel_right-122,
      y+5,
      66,
      18,
      MUTED_COLOR,
      8
   );

   CreateButton(
      ObjName(prefix+"_SCROLL_DOWN"),
      "GIU",
      panel_right-52,
      y,
      52,
      28
   );
}

//====================================================================
// CREA DASHBOARD
//====================================================================
void CreateDashboard()
{
   DeleteDashboard();

   int W = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int H = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   g_chart_px_w = W;
   g_chart_px_h = H;

   if(W < 1080) W = 1080;
   if(H < 1290) H = 1290;

   g_width  = W;
   g_height = H;

   g_dash_w = MathMin(W - 60, 1240);
   if(g_dash_w < 980) g_dash_w = W - 20;
   g_dash_x = (W - g_dash_w) / 2;

   int x   = g_dash_x;
   int cw  = g_dash_w;
   int pad = 28;

   CreatePanel(PREFIX+"BACKGROUND", 0, 0, W, H, BG_COLOR, BG_COLOR);

   // ================================================================
   // HEADER
   // ================================================================
   CreateLabel(O_TITLE, "TRADING TARGET MANAGER",
               x+pad, 16, cw-pad*2, 30, TEXT_COLOR, 17);

   CreateLabel(O_SUBTITLE,
               "Live tracking  |  Simulation  |  Daily plan  |  Statistics",
               x+pad, 56, cw-pad*2, 18, MUTED_COLOR, 8);

   // ================================================================
   // NAVIGAZIONE
   // ================================================================
   int navY = 92;
   int navGap = 12;

   int n1 = x + pad;
   int n2 = n1 + 110 + navGap;
   int n3 = n2 + 110 + navGap;
   int n4 = n3 + 135 + navGap;
   int n5 = n4 + 145 + navGap;
   int n6 = n5 + 105 + navGap;

   CreateButton(ObjName("PAGE_DASH"), "LIVE",        n1, navY, 110, 32);
   CreateButton(ObjName("PAGE_ORD"),  "ORDINI",      n2, navY, 110, 32);
   CreateButton(ObjName("PAGE_STRAT"),"RISK MONITOR",   n3, navY, 135, 32);
   CreateButton(ObjName("PAGE_SIM"),  "SIMULATORE",  n4, navY, 145, 32);
   CreateButton(ObjName("PAGE_PLAN"), "PIANO",       n5, navY, 105, 32);
   CreateButton(ObjName("PAGE_STAT"), "STATISTICHE", n6, navY, 145, 32);

   // ================================================================
   // PAGINA 1 - LIVE
   // ================================================================
   if(g_current_page == 1)
   {
      int yParam = 140;
      int hParam = 200;

      CreatePanel(O_PARAM_PANEL, x, yParam, cw, hParam, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_PARAM_TITLE, "PARAMETRI LIVE",
                  x+pad, yParam+16, 260, 22, BLUE_COLOR, 11);

      int ly = yParam + 52;
      int ey = yParam + 80;

      int c1 = x + pad;
      int c2 = x + 250;
      int c3 = x + 470;
      int c4 = x + 700;

      CreateLabel(O_INITIAL_LABEL, "CAPITALE INIZIALE",
                  c1, ly, 180, 18, MUTED_COLOR, 8);
      CreateEdit(O_INITIAL_EDIT, DoubleToString(g_initial_capital,2),
                 c1, ey, 160, 34);

      CreateLabel(O_TARGET_LABEL, "OBIETTIVO",
                  c2, ly, 150, 18, MUTED_COLOR, 8);
      CreateEdit(O_TARGET_EDIT, DoubleToString(g_target_capital,2),
                 c2, ey, 160, 34);

      CreateLabel(O_DAYS_LABEL, "GIORNI LAVORATIVI",
                  c3, ly, 180, 18, MUTED_COLOR, 8);
      CreateEdit(O_DAYS_EDIT, IntegerToString(g_live_total_days),
                 c3, ey, 78, 34);

      CreateButton(O_MINUS, "-", c3+90, ey, 36, 34);
      CreateButton(O_PLUS,  "+", c3+136, ey, 36, 34);

      CreateButton(O_CALCULATE, "RICALCOLA", c4, ey, 150, 34);
      CreateButton(O_RESET, "RESET", c4+165, ey, 110, 34);

      // Seconda riga: data di inizio percorso
      int ly2 = yParam + 122;
      int ey2 = yParam + 150;

      CreateLabel(O_START_LABEL, "DATA INIZIO (AAAA.MM.GG)",
                  c1, ly2, 220, 18, MUTED_COLOR, 8);
      CreateEdit(O_START_EDIT, TimeToString(g_start_date, TIME_DATE),
                 c1, ey2, 160, 34);

      CreateLabel(ObjName("START_HINT"),
                  "Giorno 1 del percorso. Modificabile: premi INVIO per applicare.",
                  c2, ly2+8, cw - (c2 - x) - pad, 18, MUTED_COLOR, 8);

      // ACCOUNT
      int yAcc = 364;
      int hAcc = 150;

      CreatePanel(O_ACCOUNT_PANEL, x, yAcc, cw, hAcc, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_ACCOUNT_TITLE, "ACCOUNT MT5",
                  x+pad, yAcc+14, 220, 20, BLUE_COLOR, 10);

      int gap = 18;
      int cardW = (cw - pad*2 - gap*3) / 4;
      int cardY = yAcc + 50;
      int cardH = 78;

      int a1 = x + pad;
      int a2 = a1 + cardW + gap;
      int a3 = a2 + cardW + gap;
      int a4 = a3 + cardW + gap;

      CreatePanel(PREFIX+"KPI_BAL_BG", a1, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_BAL_T", "BALANCE", a1+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_BALANCE, "", a1+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      CreatePanel(PREFIX+"KPI_EQ_BG", a2, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_EQ_T", "EQUITY", a2+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_EQUITY, "", a2+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      CreatePanel(PREFIX+"KPI_PL_BG", a3, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_PL_T", "RISULTATO TOTALE", a3+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_PROFIT, "", a3+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      CreatePanel(PREFIX+"KPI_RET_BG", a4, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_RET_T", "RENDIMENTO", a4+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_RETURN, "", a4+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      // REALTIME OGGI
      int yRT = 531;
      int hRT = 132;

      CreatePanel(ObjName("LIVE_RT_PANEL"), x, yRT, cw, hRT, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(ObjName("LIVE_RT_TITLE"), "OGGI IN TEMPO REALE",
                  x+pad, yRT+14, 300, 20, BLUE_COLOR, 10);

      int rtGap = 18;
      int rtW = (cw - pad*2 - rtGap*3) / 4;
      int rtY = yRT + 46;
      int rtH = 66;

      int r1 = x+pad;
      int r2 = r1+rtW+rtGap;
      int r3 = r2+rtW+rtGap;
      int r4 = r3+rtW+rtGap;

      CreatePanel(ObjName("RT1_BG"),r1,rtY,rtW,rtH,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("RT1_T"),"REALIZZATO OGGI",r1+12,rtY+8,rtW-24,16,MUTED_COLOR,7);
      CreateLabel(ObjName("RT_REALIZED"),"",r1+12,rtY+34,rtW-24,22,TEXT_COLOR,11);

      CreatePanel(ObjName("RT2_BG"),r2,rtY,rtW,rtH,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("RT2_T"),"FLOATING APERTO",r2+12,rtY+8,rtW-24,16,MUTED_COLOR,7);
      CreateLabel(ObjName("RT_FLOATING"),"",r2+12,rtY+34,rtW-24,22,TEXT_COLOR,11);

      CreatePanel(ObjName("RT3_BG"),r3,rtY,rtW,rtH,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("RT3_T"),"POTENZIALE ORA",r3+12,rtY+8,rtW-24,16,MUTED_COLOR,7);
      CreateLabel(ObjName("RT_POTENTIAL"),"",r3+12,rtY+34,rtW-24,22,TEXT_COLOR,11);

      CreatePanel(ObjName("RT4_BG"),r4,rtY,rtW,rtH,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("RT4_T"),"MANCANO SE CHIUDI",r4+12,rtY+8,rtW-24,16,MUTED_COLOR,7);
      CreateLabel(ObjName("RT_MISSING"),"",r4+12,rtY+34,rtW-24,22,ORANGE_COLOR,11);

      // =============================================================
      // PROGRESSO TARGET GIORNALIERO
      // =============================================================
      int yDaily = 680;
      int hDaily = 205;

      CreatePanel(
         ObjName("DAILY_PROGRESS_PANEL"),
         x,
         yDaily,
         cw,
         hDaily,
         PANEL_COLOR,
         BORDER_COLOR
      );

      CreateLabel(
         ObjName("DAILY_PROGRESS_TITLE"),
         "PROGRESSO VERSO IL TARGET GIORNALIERO",
         x+pad,
         yDaily+14,
         430,
         20,
         YELLOW_COLOR,
         10
      );

      int dailySummaryW = cw - pad*2;
      int dailyColW = dailySummaryW / 3;
      int dailySummaryY = yDaily + 50;

      CreateLabel(
         ObjName("DAILY_CURRENT"),
         "",
         x+pad,
         dailySummaryY,
         dailyColW-12,
         24,
         TEXT_COLOR,
         10
      );

      CreateLabel(
         ObjName("DAILY_MISSING"),
         "",
         x+pad+dailyColW,
         dailySummaryY,
         dailyColW-12,
         24,
         ORANGE_COLOR,
         10
      );

      CreateLabel(
         ObjName("DAILY_TARGET"),
         "",
         x+pad+dailyColW*2,
         dailySummaryY,
         dailyColW-12,
         24,
         GREEN_COLOR,
         10
      );

      CreatePanel(
         ObjName("DAILY_BAR_BG"),
         x+pad,
         yDaily+88,
         g_bar_w,
         32,
         PANEL2_COLOR,
         PANEL2_COLOR
      );

      CreatePanel(
         ObjName("DAILY_BAR"),
         x+pad,
         yDaily+88,
         1,
         32,
         YELLOW_COLOR,
         YELLOW_COLOR
      );

      CreateLabel(
         ObjName("DAILY_PROGRESS_TEXT"),
         "",
         x+pad,
         yDaily+136,
         430,
         24,
         TEXT_COLOR,
         13
      );

      CreateLabel(
         ObjName("DAILY_REALIZED_TEXT"),
         "",
         x+pad,
         yDaily+168,
         430,
         22,
         MUTED_COLOR,
         9
      );

      CreateLabel(
         ObjName("DAILY_FLOATING_TEXT"),
         "",
         x+cw-470,
         yDaily+168,
         440,
         22,
         MUTED_COLOR,
         9
      );

      // =============================================================
      // PROGRESSO TARGET GENERALE
      // =============================================================
      int yProg = 902;
      int hProg = 270;

      CreatePanel(O_PROGRESS_PANEL, x, yProg, cw, hProg, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_PROGRESS_TITLE, "PROGRESSO VERSO IL TARGET GENERALE",
                  x+pad, yProg+14, 380, 20, BLUE_COLOR, 10);

      int summaryW = cw - pad*2;
      int summaryColW = summaryW / 3;
      int summaryY = yProg + 50;

      CreateLabel(ObjName("PROG_CURRENT"), "", x+pad, summaryY,
                  summaryColW-12, 24, TEXT_COLOR, 10);
      CreateLabel(ObjName("PROG_MISSING"), "", x+pad+summaryColW, summaryY,
                  summaryColW-12, 24, ORANGE_COLOR, 10);
      CreateLabel(ObjName("PROG_TARGET"), "", x+pad+summaryColW*2, summaryY,
                  summaryColW-12, 24, GREEN_COLOR, 10);

      g_bar_w = cw - pad*2;
      CreatePanel(O_PROGRESS_BAR_BG, x+pad, yProg+88, g_bar_w, 32, PANEL2_COLOR, PANEL2_COLOR);
      CreatePanel(O_PROGRESS_BAR,    x+pad, yProg+88, 1, 32, BLUE_COLOR, BLUE_COLOR);

      CreateLabel(O_PROGRESS_TEXT, "", x+pad, yProg+136, 430, 24, TEXT_COLOR, 13);
      CreateLabel(O_DAY, "", x+pad, yProg+172, 300, 20, MUTED_COLOR, 9);
      CreateLabel(O_REMAINING, "", x+cw-430, yProg+172, 400, 20, MUTED_COLOR, 9);

      CreatePanel(PREFIX+"TARGET_SEPARATOR", x+pad, yProg+202,
                  g_bar_w, 1, BORDER_COLOR, BORDER_COLOR);

      CreateLabel(O_TARGET_TITLE, "OBIETTIVO DI OGGI",
                  x+pad, yProg+216, 280, 18, MUTED_COLOR, 8);

      CreateLabel(O_REQUIRED_PCT, "", x+pad, yProg+236, 410, 26, TEXT_COLOR, 12);
      CreateLabel(O_REQUIRED_EURO, "", x+(int)(cw*0.56), yProg+236, 390, 26, TEXT_COLOR, 12);

      int yStatus = 1188;
      CreatePanel(PREFIX+"STATUS_BG", x, yStatus, cw, 58, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_STATUS, "", x+pad, yStatus+18, cw-pad*2, 24, GREEN_COLOR, 12);
   }

   // ================================================================
   // PAGINA 2 - ORDINI APERTI
   // ================================================================
   else
   if(g_current_page == 2)
   {
      int yInfo = 140;
      int hInfo = 150;

      CreatePanel(O_ACCOUNT_PANEL, x, yInfo, cw, hInfo, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_ACCOUNT_TITLE, "ORDINI APERTI - RIEPILOGO",
                  x+pad, yInfo+14, 330, 20, BLUE_COLOR, 10);

      int gap = 18;
      int cardW = (cw - pad*2 - gap*3) / 4;
      int cardY = yInfo + 50;
      int cardH = 78;

      int a1 = x + pad;
      int a2 = a1 + cardW + gap;
      int a3 = a2 + cardW + gap;
      int a4 = a3 + cardW + gap;

      CreatePanel(PREFIX+"KPI_BAL_BG", a1, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_BAL_T", "POSIZIONI APERTE", a1+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_BALANCE, "", a1+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      CreatePanel(PREFIX+"KPI_EQ_BG", a2, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_EQ_T", "FLOATING", a2+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_EQUITY, "", a2+14, cardY+43, cardW-28, 22, TEXT_COLOR, 11);

      CreatePanel(PREFIX+"KPI_PL_BG", a3, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_PL_T", "POTENZIALE AI TP", a3+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_PROFIT, "", a3+14, cardY+43, cardW-28, 22, GREEN_COLOR, 11);

      CreatePanel(PREFIX+"KPI_RET_BG", a4, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_RET_T", "RISCHIO AGLI SL", a4+14, cardY+10, cardW-28, 16, MUTED_COLOR, 7);
      CreateLabel(O_RETURN, "", a4+14, cardY+43, cardW-28, 22, RED_COLOR, 11);

      int yStatus = 306;
      CreatePanel(PREFIX+"STATUS_BG", x, yStatus, cw, 58, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_STATUS, "", x+pad, yStatus+18, cw-pad*2, 24, TEXT_COLOR, 11);

      int ySym = 380;
      int hSym = MathMax(360, H-ySym-18);

      CreatePanel(O_SYMBOL_PANEL, x, ySym, cw, hSym, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_SYMBOL_TITLE, "DETTAGLIO POSIZIONI APERTE",
                  x+pad, ySym+14, 500, 20, BLUE_COLOR, 10);

      CreateScrollControls(
         x+pad,
         ySym+10,
         x+cw-pad,
         "ORD"
      );

      int tableX = x + pad;
      int hdrY = ySym + 50;
      int rowY = ySym + 80;
      int rowStep = 24;

      int xSym   = tableX;
      int xType  = tableX + 115;
      int xLot   = tableX + 185;
      int xEntry = tableX + 260;
      int xNow   = tableX + 405;
      int xPL    = tableX + 550;
      int xSL    = tableX + 665;
      int xTP    = tableX + 800;
      int xTPeur = tableX + 935;
      int xSLeur = tableX + 1060;

      CreateLabel(ObjName("ORD_HDR_SYM"),   "SIMBOLO", xSym,   hdrY, 105,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_TYPE"),  "TIPO",    xType,  hdrY, 60,18, MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_LOT"),   "LOTTI",   xLot,   hdrY, 65,18, MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_ENTRY"), "ENTRY",   xEntry, hdrY, 130,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_NOW"),   "PREZZO",  xNow,   hdrY, 130,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_PL"),    "P/L",     xPL,    hdrY, 100,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_SL"),    "SL",      xSL,    hdrY, 120,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_TP"),    "TP",      xTP,    hdrY, 120,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_TPE"),   "P/L@TP",  xTPeur, hdrY, 110,18,MUTED_COLOR,8);
      CreateLabel(ObjName("ORD_HDR_SLE"),   "P/L@SL",  xSLeur, hdrY, 110,18,MUTED_COLOR,8);

      for(int r=1; r<=DATA_ROWS_VISIBLE; r++)
      {
         int yy = rowY + (r-1)*rowStep;
         string rr = IntegerToString(r);

         CreateLabel(ObjName("ORD_SYM_"+rr),   " ", xSym,   yy,105,20,TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_TYPE_"+rr),  " ", xType,  yy,60,20, TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_LOT_"+rr),   " ", xLot,   yy,65,20, TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_ENTRY_"+rr), " ", xEntry, yy,130,20,TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_NOW_"+rr),   " ", xNow,   yy,130,20,TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_PL_"+rr),    " ", xPL,    yy,100,20,TEXT_COLOR,8);
         CreateLabel(ObjName("ORD_SL_"+rr),    " ", xSL,    yy,120,20,MUTED_COLOR,8);
         CreateLabel(ObjName("ORD_TP_"+rr),    " ", xTP,    yy,120,20,MUTED_COLOR,8);
         CreateLabel(ObjName("ORD_TPE_"+rr),   " ", xTPeur, yy,110,20,GREEN_COLOR,8);
         CreateLabel(ObjName("ORD_SLE_"+rr),   " ", xSLeur, yy,110,20,RED_COLOR,8);
      }
   }

   // ================================================================
   // PAGINA 3 - RISK MANAGER
   // ================================================================
   else
   if(g_current_page == 3)
   {
      int yTop=140;

      CreatePanel(ObjName("STRAT_STATUS_PANEL"),x,yTop,cw,118,PANEL_COLOR,BORDER_COLOR);
      CreateLabel(ObjName("STRAT_TITLE"),"RISK MONITOR (solo visualizzazione - non invia ordini)",x+pad,yTop+14,700,20,BLUE_COLOR,11);

      int gap=18;
      int cardW=(cw-pad*2-gap*3)/4;
      int cy=yTop+48;
      int c1=x+pad;
      int c2=c1+cardW+gap;
      int c3=c2+cardW+gap;
      int c4=c3+cardW+gap;

      CreatePanel(ObjName("STRAT_K1_BG"),c1,cy,cardW,52,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("STRAT_K1_T"),"STATO",c1+10,cy+7,cardW-20,15,MUTED_COLOR,7);
      CreateLabel(ObjName("STRAT_STATE"),"",c1+10,cy+27,cardW-20,20,TEXT_COLOR,10);

      CreatePanel(ObjName("STRAT_K2_BG"),c2,cy,cardW,52,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("STRAT_K2_T"),"AMBITO",c2+10,cy+7,cardW-20,15,MUTED_COLOR,7);
      CreateLabel(ObjName("STRAT_SCOPE"),"",c2+10,cy+27,cardW-20,20,TEXT_COLOR,10);

      CreatePanel(ObjName("STRAT_K3_BG"),c3,cy,cardW,52,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("STRAT_K3_T"),"TRADE OGGI",c3+10,cy+7,cardW-20,15,MUTED_COLOR,7);
      CreateLabel(ObjName("STRAT_TRADES"),"",c3+10,cy+27,cardW-20,20,TEXT_COLOR,10);

      CreatePanel(ObjName("STRAT_K4_BG"),c4,cy,cardW,52,PANEL2_COLOR,PANEL2_COLOR);
      CreateLabel(ObjName("STRAT_K4_T"),"POSIZIONI",c4+10,cy+7,cardW-20,15,MUTED_COLOR,7);
      CreateLabel(ObjName("STRAT_POS"),"",c4+10,cy+27,cardW-20,20,TEXT_COLOR,10);

      int yMM=276;
      CreatePanel(ObjName("STRAT_MM"),x,yMM,cw,190,PANEL_COLOR,BORDER_COLOR);
      CreateLabel(ObjName("STRAT_MM_TITLE"),"CALCOLATORE TP/SL (riferimento per trading manuale)",x+pad,yMM+14,700,20,BLUE_COLOR,10);

      CreateLabel(ObjName("STRAT_L_MAGIC"),"MAGIC",x+pad,yMM+52,70,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_MAGIC"),IntegerToString(g_strategy_magic),x+pad+75,yMM+45,125,32);

      CreateLabel(ObjName("STRAT_L_LOT"),"LOTTO",x+pad+230,yMM+52,65,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_LOT"),DoubleToString(g_strategy_fixed_lot,2),x+pad+295,yMM+45,90,32);

      CreateLabel(ObjName("STRAT_L_MAXPOS"),"MAX POS.",x+pad+420,yMM+52,80,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_MAXPOS"),IntegerToString(g_strategy_max_open_positions),x+pad+500,yMM+45,75,32);

      CreateLabel(ObjName("STRAT_L_MAXTR"),"MAX TRADE/GG",x+pad+610,yMM+52,110,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_MAXTR"),IntegerToString(g_strategy_max_trades_day),x+pad+725,yMM+45,75,32);

      CreateLabel(ObjName("STRAT_L_TP"),"TP EUR",x+pad,yMM+104,80,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_TP"),DoubleToString(g_strategy_tp_eur,2),x+pad+75,yMM+97,125,32);

      CreateLabel(ObjName("STRAT_L_SL"),"SL EUR",x+pad+230,yMM+104,80,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_SL"),DoubleToString(g_strategy_sl_eur,2),x+pad+295,yMM+97,90,32);

      CreateButton(ObjName("STRAT_TOGGLE"),g_strategy_enabled ? "MONITOR: ON" : "MONITOR: OFF",
                   x+pad,yMM+145,145,32);
      CreateButton(ObjName("STRAT_SCOPE_BTN"),g_strategy_scope_account ? "AMBITO: ACCOUNT" : "AMBITO: MAGIC",
                   x+pad+165,yMM+145,190,32);

      int yDaily=484;
      CreatePanel(ObjName("STRAT_DAILY"),x,yDaily,cw,232,PANEL_COLOR,BORDER_COLOR);
      CreateLabel(ObjName("STRAT_DAILY_TITLE"),"GESTIONE GIORNALIERA",x+pad,yDaily+14,300,20,BLUE_COLOR,10);

      CreateLabel(ObjName("STRAT_D_TARGET"),"",x+pad,yDaily+50,330,22,TEXT_COLOR,10);
      CreateLabel(ObjName("STRAT_D_REAL"),"",x+pad+350,yDaily+50,330,22,TEXT_COLOR,10);
      CreateLabel(ObjName("STRAT_D_FLOAT"),"",x+pad+700,yDaily+50,330,22,TEXT_COLOR,10);

      CreateLabel(ObjName("STRAT_L_LOSSLIM"),"LOSS LIMIT",x+pad,yDaily+96,95,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_LOSSLIM"),DoubleToString(g_strategy_daily_loss_limit,2),x+pad+100,yDaily+89,100,32);

      CreateLabel(ObjName("STRAT_L_LOSSES"),"LOSS PAUSA",x+pad+240,yDaily+96,95,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_LOSSES"),IntegerToString(g_strategy_losses_before_pause),x+pad+340,yDaily+89,80,32);

      CreateLabel(ObjName("STRAT_L_PAUSE"),"PAUSA MIN",x+pad+460,yDaily+96,90,18,MUTED_COLOR,8);
      CreateEdit(ObjName("STRAT_PAUSE"),IntegerToString(g_strategy_pause_minutes),x+pad+555,yDaily+89,90,32);

      CreateButton(ObjName("STRAT_TARGET_MODE"),
                   g_strategy_daily_target_auto ? "TARGET: AUTO LIVE" : "TARGET: MANUALE",
                   x+pad,yDaily+140,190,32);

      CreateButton(ObjName("STRAT_CLOSE_LIMIT"),
                   g_strategy_alert_on_limit ? "AVVISO SU LIMITE: SI" : "AVVISO SU LIMITE: NO",
                   x+pad+210,yDaily+140,210,32);

      CreateLabel(ObjName("STRAT_D_LOCK"),"",x+pad,yDaily+188,430,22,TEXT_COLOR,10);
      CreateLabel(ObjName("STRAT_D_PAUSE"),"",x+pad+470,yDaily+188,570,22,TEXT_COLOR,10);

      int yTech=734;
      CreatePanel(ObjName("STRAT_TECH"),x,yTech,cw,200,PANEL_COLOR,BORDER_COLOR);
      CreateLabel(ObjName("STRAT_TECH_TITLE"),"CONTROLLI TECNICI / BROKER",x+pad,yTech+14,340,20,BLUE_COLOR,10);
      CreateLabel(ObjName("STRAT_TECH1"),"",x+pad,yTech+50,cw-pad*2,20,TEXT_COLOR,9);
      CreateLabel(ObjName("STRAT_TECH2"),"",x+pad,yTech+82,cw-pad*2,20,TEXT_COLOR,9);
      CreateLabel(ObjName("STRAT_TECH3"),"",x+pad,yTech+114,cw-pad*2,20,TEXT_COLOR,9);
      CreateLabel(ObjName("STRAT_TECH4"),"",x+pad,yTech+146,cw-pad*2,20,TEXT_COLOR,9);
   }

   // ================================================================
   // PAGINA 4 - SIMULATORE
   // ================================================================
   else
   if(g_current_page == 4)
   {
      int yParam = 140;
      int hParam = 250;

      CreatePanel(O_PARAM_PANEL, x, yParam, cw, hParam, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_PARAM_TITLE, "SIMULATORE GIORNALIERO",
                  x+pad, yParam+16, 320, 22, BLUE_COLOR, 11);

      int ly1 = yParam + 58;
      int ey1 = yParam + 86;

      int c1 = x + pad;
      int c2 = x + 250;
      int c3 = x + 500;
      int c4 = x + 760;

      CreateLabel(O_INITIAL_LABEL, "CAPITALE INIZIALE",
                  c1, ly1, 180, 18, MUTED_COLOR, 8);
      CreateEdit(O_INITIAL_EDIT, DoubleToString(g_initial_capital,2),
                 c1, ey1, 160, 34);

      CreateLabel(O_TARGET_LABEL, "OBIETTIVO",
                  c2, ly1, 150, 18, MUTED_COLOR, 8);
      CreateEdit(O_TARGET_EDIT, DoubleToString(g_target_capital,2),
                 c2, ey1, 160, 34);

      CreateLabel(O_DAYS_LABEL, "GIORNI LAVORATIVI",
                  c3, ly1, 180, 18, MUTED_COLOR, 8);
      CreateEdit(O_DAYS_EDIT, IntegerToString(g_sim_total_days),
                 c3, ey1, 78, 34);
      CreateButton(O_MINUS, "-", c3+90, ey1, 36, 34);
      CreateButton(O_PLUS,  "+", c3+136, ey1, 36, 34);

      CreateButton(O_CALCULATE, "RICALCOLA", c4, ey1, 150, 34);

      CreatePanel(PREFIX+"SIM_SEP1", x+pad, yParam+135, cw-pad*2, 1,
                  BORDER_COLOR, BORDER_COLOR);

      int ly2 = yParam + 154;
      int ey2 = yParam + 182;

      CreateLabel(ObjName("SIM_CAP_LABEL"), "CAPITALE ATTUALE SIM.",
                  c1, ly2, 190, 18, MUTED_COLOR, 8);
      CreateEdit(ObjName("SIM_CAP_EDIT"), DoubleToString(g_sim_capital,2),
                 c1, ey2, 160, 34);

      CreateLabel(ObjName("SIM_DAY_LABEL"), "GIORNO CORRENTE",
                  c2, ly2, 150, 18, MUTED_COLOR, 8);
      CreateEdit(ObjName("SIM_DAY_EDIT"), IntegerToString(g_sim_day),
                 c2, ey2, 78, 34);
      CreateButton(ObjName("SIM_DAY_MINUS"), "-", c2+90, ey2, 36, 34);
      CreateButton(ObjName("SIM_DAY_PLUS"),  "+", c2+136, ey2, 36, 34);

      CreateLabel(ObjName("SIM_RESULT_LABEL"), "RISULTATO OGGI (+/- EUR)",
                  c3, ly2, 210, 18, MUTED_COLOR, 8);
      CreateEdit(ObjName("SIM_RESULT_EDIT"),
                 DoubleToString(g_sim_day_result_input,2),
                 c3, ey2, 150, 34);

      CreateButton(ObjName("SIM_RECORD"), "REGISTRA GIORNO",
                  c4, ey2, 180, 34);
      CreateButton(ObjName("SIM_CLEAR"), "AZZERA SIM.",
                  c4+195, ey2, 140, 34);

      // RIEPILOGO
      int yInfo = 410;
      int hInfo = 118;
      CreatePanel(O_ACCOUNT_PANEL, x, yInfo, cw, hInfo, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_ACCOUNT_TITLE, "RIEPILOGO SIMULAZIONE",
                  x+pad, yInfo+14, 300, 20, BLUE_COLOR, 10);

      int gap = 18;
      int cardW = (cw - pad*2 - gap*3) / 4;
      int cardY = yInfo + 44;
      int cardH = 52;

      int a1 = x + pad;
      int a2 = a1 + cardW + gap;
      int a3 = a2 + cardW + gap;
      int a4 = a3 + cardW + gap;

      CreatePanel(PREFIX+"KPI_BAL_BG", a1, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_BAL_T", "ATTUALE", a1+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_BALANCE, "", a1+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_EQ_BG", a2, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_EQ_T", "TARGET", a2+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_EQUITY, "", a2+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_PL_BG", a3, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_PL_T", "MANCANO", a3+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_PROFIT, "", a3+14, cardY+28, cardW-28, 20, ORANGE_COLOR, 10);

      CreatePanel(PREFIX+"KPI_RET_BG", a4, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_RET_T", "GIORNO", a4+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_RETURN, "", a4+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      int yStatus = 544;
      CreatePanel(PREFIX+"STATUS_BG", x, yStatus, cw, 58, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_STATUS, "", x+pad, yStatus+18, cw-pad*2, 24, GREEN_COLOR, 12);

      int ySym = 618;
      int hSym = MathMax(260, H-ySym-18);
      CreatePanel(O_SYMBOL_PANEL, x, ySym, cw, hSym, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_SYMBOL_TITLE, "", x+pad, ySym+14, 500, 20, BLUE_COLOR, 10);

      CreateScrollControls(
         x+pad,
         ySym+10,
         x+cw-pad,
         "SIM"
      );

      // -------------------------------------------------------------
      // TABELLA SIMULATORE A COLONNE REALI
      // -------------------------------------------------------------
      int tableX = x + pad;
      int hdrY   = ySym + 50;
      int rowY   = ySym + 80;
      int rowStep = 22;

      // Larghezze / posizioni colonne
      int xGG      = tableX;
      int xStart   = tableX + 55;
      int xTarget  = tableX + 205;
      int xResult  = tableX + 365;
      int xClose   = tableX + 525;
      int xDelta   = tableX + 675;
      int xPct     = tableX + 825;
      int xState   = tableX + 955;

      CreateLabel(ObjName("SIM_HDR_GG"),     "GG",        xGG,     hdrY, 45, 18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_START"),  "PARTENZA",  xStart,  hdrY, 135,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_TARGET"), "TARGET GG", xTarget, hdrY, 145,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_RESULT"), "RISULTATO", xResult, hdrY, 145,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_CLOSE"),  "CHIUSURA",  xClose,  hdrY, 135,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_DELTA"),  "SCOST.",    xDelta,  hdrY, 130,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_PCT"),    "% EFF.",    xPct,    hdrY, 110,18, MUTED_COLOR, 9);
      CreateLabel(ObjName("SIM_HDR_STATE"),  "STATO",     xState,  hdrY, 140,18, MUTED_COLOR, 9);

      string hdrs[] = {
         ObjName("SIM_HDR_GG"),ObjName("SIM_HDR_START"),ObjName("SIM_HDR_TARGET"),
         ObjName("SIM_HDR_RESULT"),ObjName("SIM_HDR_CLOSE"),ObjName("SIM_HDR_DELTA"),
         ObjName("SIM_HDR_PCT"),ObjName("SIM_HDR_STATE")
      };
      for(int h=0; h<ArraySize(hdrs); h++)
         ObjectSetString(0,hdrs[h],OBJPROP_FONT,"Consolas");

      for(int r=1; r<=30; r++)
      {
         int yy = rowY + (r-1)*rowStep;
         string rr = IntegerToString(r);

         CreateLabel(ObjName("SIM_GG_"+rr),     " ", xGG,     yy, 45, 20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_START_"+rr),  " ", xStart,  yy, 135,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_TARGET_"+rr), " ", xTarget, yy, 145,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_RESULT_"+rr), " ", xResult, yy, 145,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_CLOSE_"+rr),  " ", xClose,  yy, 135,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_DELTA_"+rr),  " ", xDelta,  yy, 130,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_PCT_"+rr),    " ", xPct,    yy, 110,20, TEXT_COLOR, 9);
         CreateLabel(ObjName("SIM_STATE_"+rr),  " ", xState,  yy, 140,20, TEXT_COLOR, 9);

         string cells[] = {
            ObjName("SIM_GG_"+rr),ObjName("SIM_START_"+rr),ObjName("SIM_TARGET_"+rr),
            ObjName("SIM_RESULT_"+rr),ObjName("SIM_CLOSE_"+rr),ObjName("SIM_DELTA_"+rr),
            ObjName("SIM_PCT_"+rr),ObjName("SIM_STATE_"+rr)
         };

         for(int c=0; c<ArraySize(cells); c++)
            ObjectSetString(0,cells[c],OBJPROP_FONT,"Consolas");
      }
   }

   // ================================================================
   // PAGINA 5 - PIANO
   // ================================================================
   else
   if(g_current_page == 5)
   {
      int yParam = 140;
      int hParam = 150;

      CreatePanel(O_PARAM_PANEL, x, yParam, cw, hParam, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_PARAM_TITLE, "PIANO GIORNALIERO",
                  x+pad, yParam+16, 260, 22, BLUE_COLOR, 11);

      int ly = yParam + 60;
      int ey = yParam + 88;

      int c1 = x + pad;
      int c2 = x + 250;
      int c3 = x + 500;
      int c4 = x + 760;

      CreateLabel(ObjName("SIM_CAP_LABEL"), "CAPITALE DI PARTENZA",
                  c1, ly, 180, 18, MUTED_COLOR, 8);
      CreateEdit(ObjName("SIM_CAP_EDIT"), DoubleToString(g_sim_capital,2),
                 c1, ey, 160, 34);

      CreateLabel(O_TARGET_LABEL, "OBIETTIVO",
                  c2, ly, 150, 18, MUTED_COLOR, 8);
      CreateEdit(O_TARGET_EDIT, DoubleToString(g_target_capital,2),
                 c2, ey, 160, 34);

      CreateLabel(O_DAYS_LABEL, "GIORNI TOTALI",
                  c3, ly, 150, 18, MUTED_COLOR, 8);
      CreateEdit(O_DAYS_EDIT, IntegerToString(g_sim_total_days),
                 c3, ey, 78, 34);

      CreateButton(O_CALCULATE, "RICALCOLA PIANO", c4, ey, 180, 34);

      int yInfo = 314;
      int hInfo = 118;
      CreatePanel(O_ACCOUNT_PANEL, x, yInfo, cw, hInfo, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_ACCOUNT_TITLE, "RIEPILOGO PIANO",
                  x+pad, yInfo+14, 260, 20, BLUE_COLOR, 10);

      int gap = 18;
      int cardW = (cw - pad*2 - gap*3) / 4;
      int cardY = yInfo + 44;
      int cardH = 52;

      int a1 = x + pad;
      int a2 = a1 + cardW + gap;
      int a3 = a2 + cardW + gap;
      int a4 = a3 + cardW + gap;

      CreatePanel(PREFIX+"KPI_BAL_BG", a1, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_BAL_T", "PARTENZA", a1+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_BALANCE, "", a1+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_EQ_BG", a2, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_EQ_T", "TARGET", a2+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_EQUITY, "", a2+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_PL_BG", a3, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_PL_T", "DIFFERENZA", a3+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_PROFIT, "", a3+14, cardY+28, cardW-28, 20, ORANGE_COLOR, 10);

      CreatePanel(PREFIX+"KPI_RET_BG", a4, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_RET_T", "GIORNI", a4+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_RETURN, "", a4+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      int yStatus = 448;
      CreatePanel(PREFIX+"STATUS_BG", x, yStatus, cw, 58, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_STATUS, "", x+pad, yStatus+18, cw-pad*2, 24, GREEN_COLOR, 12);

      int ySym = 522;
      int hSym = MathMax(260, H-ySym-18);
      CreatePanel(O_SYMBOL_PANEL, x, ySym, cw, hSym, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_SYMBOL_TITLE, "", x+pad, ySym+14, 500, 20, BLUE_COLOR, 10);

      CreateScrollControls(
         x+pad,
         ySym+10,
         x+cw-pad,
         "PLAN"
      );

      CreateLabel(
         ObjName("PLAN_TABLE_HDR"),
         "GG   CAPITALE INIZIO     TARGET FINE GG     EURO DA FARE     % RICHIESTA",
         x+pad,
         ySym+48,
         cw-pad*2,
         18,
         MUTED_COLOR,
         8
      );
      ObjectSetString(0,ObjName("PLAN_TABLE_HDR"),OBJPROP_FONT,"Consolas");

      int rowY = ySym + 74;
      int rowStep = 17;

      for(int r=1; r<=30; r++)
      {
         string rn = ObjName("PLAN_TABLE_ROW_"+IntegerToString(r));

         CreateLabel(
            rn,
            " ",
            x+pad,
            rowY + (r-1)*rowStep,
            cw-pad*2,
            17,
            TEXT_COLOR,
            8
         );

         ObjectSetString(0,rn,OBJPROP_FONT,"Consolas");
      }
   }

   // ================================================================
   // PAGINA 6 - STATISTICHE
   // ================================================================
   else
   if(g_current_page == 6)
   {
      int yInfo = 140;
      int hInfo = 118;

      CreatePanel(O_ACCOUNT_PANEL, x, yInfo, cw, hInfo, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_ACCOUNT_TITLE, "RIEPILOGO LIVE",
                  x+pad, yInfo+14, 260, 20, BLUE_COLOR, 10);

      int gap = 18;
      int cardW = (cw - pad*2 - gap*3) / 4;
      int cardY = yInfo + 44;
      int cardH = 52;

      int a1 = x + pad;
      int a2 = a1 + cardW + gap;
      int a3 = a2 + cardW + gap;
      int a4 = a3 + cardW + gap;

      CreatePanel(PREFIX+"KPI_BAL_BG", a1, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_BAL_T", "ATTUALE", a1+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_BALANCE, "", a1+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_EQ_BG", a2, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_EQ_T", "TARGET", a2+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_EQUITY, "", a2+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      CreatePanel(PREFIX+"KPI_PL_BG", a3, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_PL_T", "MANCANO", a3+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_PROFIT, "", a3+14, cardY+28, cardW-28, 20, ORANGE_COLOR, 10);

      CreatePanel(PREFIX+"KPI_RET_BG", a4, cardY, cardW, cardH, PANEL2_COLOR, PANEL2_COLOR);
      CreateLabel(PREFIX+"KPI_RET_T", "GIORNO", a4+14, cardY+7, cardW-28, 14, MUTED_COLOR, 7);
      CreateLabel(O_RETURN, "", a4+14, cardY+28, cardW-28, 20, TEXT_COLOR, 10);

      int yStatus = 274;
      CreatePanel(PREFIX+"STATUS_BG", x, yStatus, cw, 58, PANEL_COLOR, BORDER_COLOR);
      CreateLabel(O_STATUS, "", x+pad, yStatus+18, cw-pad*2, 24, GREEN_COLOR, 12);

      int ySym = 348;
      int hSym = MathMax(320, H-ySym-18);

      CreatePanel(O_SYMBOL_PANEL, x, ySym, cw, hSym, PANEL_COLOR, BORDER_COLOR);

      CreateLabel(
         O_SYMBOL_TITLE,
         "STATISTICHE LIVE / RISULTATI PER SIMBOLO",
         x+pad,
         ySym+14,
         520,
         20,
         BLUE_COLOR,
         10
      );

      CreateScrollControls(
         x+pad,
         ySym+10,
         x+cw-pad,
         "STAT"
      );

      CreateLabel(
         ObjName("STAT_TODAY"),
         "",
         x+pad,
         ySym+48,
         cw-pad*2,
         22,
         TEXT_COLOR,
         10
      );

      CreatePanel(
         ObjName("STAT_SEP"),
         x+pad,
         ySym+80,
         cw-pad*2,
         1,
         BORDER_COLOR,
         BORDER_COLOR
      );

      int tableX = x + pad;
      int hdrY   = ySym + 96;
      int rowY   = ySym + 124;
      int rowStep = 23;

      int xSym   = tableX;
      int xTrade = tableX + 135;
      int xWin   = tableX + 215;
      int xLoss  = tableX + 285;
      int xGross = tableX + 365;
      int xSwap  = tableX + 500;
      int xComm  = tableX + 625;
      int xNet   = tableX + 765;
      int xWR    = tableX + 910;

      CreateLabel(ObjName("STAT_HDR_SYM"),   "SIMBOLO",     xSym,   hdrY,125,18,MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_TRADE"), "TRADE",       xTrade, hdrY,70,18, MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_WIN"),   "WIN",         xWin,   hdrY,60,18, MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_LOSS"),  "LOSS",        xLoss,  hdrY,65,18, MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_GROSS"), "PROFIT LORDO",xGross, hdrY,125,18,MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_SWAP"),  "SWAP",        xSwap,  hdrY,115,18,MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_COMM"),  "COMMISSIONI", xComm,  hdrY,130,18,MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_PL"),    "NETTO",       xNet,   hdrY,135,18,MUTED_COLOR,8);
      CreateLabel(ObjName("STAT_HDR_WR"),    "WIN RATE",    xWR,    hdrY,110,18,MUTED_COLOR,8);

      for(int r=1; r<=25; r++)
      {
         int yy = rowY + (r-1)*rowStep;
         string rr = IntegerToString(r);

         CreateLabel(ObjName("STAT_SYM_"+rr),   " ", xSym,   yy,125,20,TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_TRADE_"+rr), " ", xTrade, yy,70,20, TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_WIN_"+rr),   " ", xWin,   yy,60,20, TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_LOSS_"+rr),  " ", xLoss,  yy,65,20, TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_GROSS_"+rr), " ", xGross, yy,125,20,TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_SWAP_"+rr),  " ", xSwap,  yy,115,20,TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_COMM_"+rr),  " ", xComm,  yy,130,20,TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_PL_"+rr),    " ", xNet,   yy,135,20,TEXT_COLOR,8);
         CreateLabel(ObjName("STAT_WR_"+rr),    " ", xWR,    yy,110,20,TEXT_COLOR,8);
      }
   }

   ChartRedraw();
}

//====================================================================
// UPDATE DASHBOARD
//====================================================================

void UpdateDashboard()
{
   CalculateTarget();

   // Stato visuale dei tab pagina
   if(ObjectFind(0,ObjName("PAGE_DASH")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_DASH"),OBJPROP_BGCOLOR,
                       g_current_page==1 ? BLUE_COLOR : BUTTON_BG);

   if(ObjectFind(0,ObjName("PAGE_ORD")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_ORD"),OBJPROP_BGCOLOR,
                       g_current_page==2 ? BLUE_COLOR : BUTTON_BG);

   if(ObjectFind(0,ObjName("PAGE_STRAT")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_STRAT"),OBJPROP_BGCOLOR,
                       g_current_page==3 ? BLUE_COLOR : BUTTON_BG);

   if(ObjectFind(0,ObjName("PAGE_SIM")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_SIM"),OBJPROP_BGCOLOR,
                       g_current_page==4 ? BLUE_COLOR : BUTTON_BG);

   if(ObjectFind(0,ObjName("PAGE_PLAN")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_PLAN"),OBJPROP_BGCOLOR,
                       g_current_page==5 ? BLUE_COLOR : BUTTON_BG);

   if(ObjectFind(0,ObjName("PAGE_STAT")) >= 0)
      ObjectSetInteger(0,ObjName("PAGE_STAT"),OBJPROP_BGCOLOR,
                       g_current_page==6 ? BLUE_COLOR : BUTTON_BG);


   // Evidenzia la modalità attiva solo se i pulsanti esistono su questa pagina.
   if(ObjectFind(0,ObjName("MODE_LIVE")) >= 0)
      ObjectSetInteger(0, ObjName("MODE_LIVE"), OBJPROP_BGCOLOR,
                       g_simulator_mode ? BUTTON_BG : GREEN_COLOR);

   if(ObjectFind(0,ObjName("MODE_SIM")) >= 0)
      ObjectSetInteger(0, ObjName("MODE_SIM"), OBJPROP_BGCOLOR,
                       g_simulator_mode ? ORANGE_COLOR : BUTTON_BG);

   // ================================================================
   // ACCOUNT / RIEPILOGO KPI - DIPENDE DALLA PAGINA
   // ================================================================
   if(g_current_page == 1)
   {
      // PAGINA LIVE: valori REALI MT5
      ObjectSetString(0, O_BALANCE, OBJPROP_TEXT,
                      DoubleToString(g_balance,2) + " EUR");

      ObjectSetString(0, O_EQUITY, OBJPROP_TEXT,
                      DoubleToString(g_equity,2) + " EUR");

      string plSign = (g_total_profit > 0 ? "+" : "");
      ObjectSetString(0, O_PROFIT, OBJPROP_TEXT,
                      plSign + DoubleToString(g_total_profit,2) + " EUR");

      string retSign = (g_total_return > 0 ? "+" : "");
      ObjectSetString(0, O_RETURN, OBJPROP_TEXT,
                      retSign + DoubleToString(g_total_return,2) + " %");

      ObjectSetInteger(0, O_PROFIT, OBJPROP_COLOR,
                       g_total_profit > 0 ? GREEN_COLOR :
                       g_total_profit < 0 ? RED_COLOR : TEXT_COLOR);

      ObjectSetInteger(0, O_RETURN, OBJPROP_COLOR,
                       g_total_return > 0 ? GREEN_COLOR :
                       g_total_return < 0 ? RED_COLOR : TEXT_COLOR);
   }
   else
   if(g_current_page == 2)
   {
      double floating = GetOpenFloatingResult();
      double tp_total = GetOpenPotentialTP();
      double sl_total = GetOpenRiskSL();

      ObjectSetString(0, O_BALANCE, OBJPROP_TEXT,
                      IntegerToString(PositionsTotal()));

      ObjectSetString(0, O_EQUITY, OBJPROP_TEXT,
                      (floating >= 0 ? "+" : "") +
                      DoubleToString(floating,2) + " EUR");

      ObjectSetString(0, O_PROFIT, OBJPROP_TEXT,
                      (tp_total >= 0 ? "+" : "") +
                      DoubleToString(tp_total,2) + " EUR");

      ObjectSetString(0, O_RETURN, OBJPROP_TEXT,
                      DoubleToString(sl_total,2) + " EUR");

      ObjectSetInteger(0, O_EQUITY, OBJPROP_COLOR,
                       floating > 0 ? GREEN_COLOR :
                       floating < 0 ? RED_COLOR : TEXT_COLOR);

      ObjectSetInteger(0, O_PROFIT, OBJPROP_COLOR, GREEN_COLOR);
      ObjectSetInteger(0, O_RETURN, OBJPROP_COLOR, RED_COLOR);
   }
   else
   if(g_current_page == 4 || g_current_page == 5)
   {
      // SIMULATORE / PIANO
      double sim_missing = g_target_capital - g_current_capital;
      if(sim_missing < 0) sim_missing = 0;

      ObjectSetString(0, O_BALANCE, OBJPROP_TEXT,
                      DoubleToString(g_current_capital,2) + " EUR");

      ObjectSetString(0, O_EQUITY, OBJPROP_TEXT,
                      DoubleToString(g_target_capital,2) + " EUR");

      ObjectSetString(0, O_PROFIT, OBJPROP_TEXT,
                      DoubleToString(sim_missing,2) + " EUR");

      ObjectSetString(0, O_RETURN, OBJPROP_TEXT,
                      IntegerToString(g_days_elapsed) +
                      " / " + IntegerToString(g_total_days));

      ObjectSetInteger(0, O_PROFIT, OBJPROP_COLOR,
                       sim_missing <= 0 ? GREEN_COLOR : ORANGE_COLOR);

      ObjectSetInteger(0, O_RETURN, OBJPROP_COLOR, TEXT_COLOR);
   }
   else
   if(g_current_page == 6)
   {
      // STATISTICHE: riepilogo live compatto
      double live_missing = g_target_capital - g_current_capital;
      if(live_missing < 0) live_missing = 0;

      ObjectSetString(0, O_BALANCE, OBJPROP_TEXT,
                      DoubleToString(g_current_capital,2) + " EUR");

      ObjectSetString(0, O_EQUITY, OBJPROP_TEXT,
                      DoubleToString(g_target_capital,2) + " EUR");

      ObjectSetString(0, O_PROFIT, OBJPROP_TEXT,
                      DoubleToString(live_missing,2) + " EUR");

      ObjectSetString(0, O_RETURN, OBJPROP_TEXT,
                      IntegerToString(g_days_elapsed) +
                      " / " + IntegerToString(g_total_days));

      ObjectSetInteger(0, O_PROFIT, OBJPROP_COLOR,
                       live_missing <= 0 ? GREEN_COLOR : ORANGE_COLOR);

      ObjectSetInteger(0, O_RETURN, OBJPROP_COLOR, TEXT_COLOR);
   }

   // ================================================================
   // PROGRESSO GENERALE
   // ================================================================
   double missing_total = g_target_capital - g_current_capital;
   if(missing_total < 0) missing_total = 0;

   ObjectSetString(0, ObjName("PROG_CURRENT"), OBJPROP_TEXT,
                   "ATTUALE  " + DoubleToString(g_current_capital,2) + " EUR");

   ObjectSetString(0, ObjName("PROG_MISSING"), OBJPROP_TEXT,
                   "MANCANO  " + DoubleToString(missing_total,2) + " EUR");

   ObjectSetString(0, ObjName("PROG_TARGET"), OBJPROP_TEXT,
                   "TARGET  " + DoubleToString(g_target_capital,2) + " EUR");

   ObjectSetInteger(
      0,
      ObjName("PROG_CURRENT"),
      OBJPROP_COLOR,
      TEXT_COLOR
   );

   ObjectSetInteger(
      0,
      ObjName("PROG_MISSING"),
      OBJPROP_COLOR,
      missing_total <= 0 ? GREEN_COLOR : ORANGE_COLOR
   );

   ObjectSetInteger(
      0,
      ObjName("PROG_TARGET"),
      OBJPROP_COLOR,
      GREEN_COLOR
   );

   int progress_width = (int)MathRound(g_bar_w * g_progress / 100.0);
   if(progress_width < 1) progress_width = 1;
   if(progress_width > g_bar_w) progress_width = g_bar_w;

   ObjectSetInteger(0, O_PROGRESS_BAR, OBJPROP_XSIZE, progress_width);

   if(g_target_reached)
   {
      ObjectSetInteger(0, O_PROGRESS_BAR, OBJPROP_BGCOLOR, GREEN_COLOR);
      ObjectSetInteger(0, O_PROGRESS_BAR, OBJPROP_COLOR, GREEN_COLOR);

      ObjectSetString(0, O_PROGRESS_TEXT, OBJPROP_TEXT,
                      "PERCORSO COMPLETATO  100.0%");
      ObjectSetInteger(0, O_PROGRESS_TEXT, OBJPROP_COLOR, GREEN_COLOR);
   }
   else
   {
      ObjectSetInteger(0, O_PROGRESS_BAR, OBJPROP_BGCOLOR, BLUE_COLOR);
      ObjectSetInteger(0, O_PROGRESS_BAR, OBJPROP_COLOR, BLUE_COLOR);

      ObjectSetString(0, O_PROGRESS_TEXT, OBJPROP_TEXT,
                      "PERCORSO COMPLETATO  " +
                      DoubleToString(g_progress,1) + "%");
      ObjectSetInteger(0, O_PROGRESS_TEXT, OBJPROP_COLOR, TEXT_COLOR);
   }

   // ================================================================
   // GIORNI
   // ================================================================
   ObjectSetString(0, O_DAY, OBJPROP_TEXT,
                   "Giorno " + IntegerToString(g_days_elapsed) +
                   " / " + IntegerToString(g_total_days));

   ObjectSetString(0, O_REMAINING, OBJPROP_TEXT,
                   "Disponibili: " + IntegerToString(g_days_remaining) +
                   " giorni lavorativi");

   // ================================================================
   // OBIETTIVO GIORNALIERO - LIVE E SIMULATORE
   // ================================================================

   double day_start_capital = g_current_capital;

   if(g_simulator_mode)
      day_start_capital = g_sim_capital;
   else
      day_start_capital = GetLiveDayStartCapital();

   if(day_start_capital < 0)
      day_start_capital = 0;

   int remaining_today =
      g_days_remaining;

   if(remaining_today < 1)
      remaining_today = 1;

   // Percentuale richiesta DA INIZIO GIORNATA al target finale
   // distribuita sui giorni ancora disponibili.
   double required_today_pct = 0.0;
   double required_today_eur = 0.0;
   double today_end_target = day_start_capital;

   if(day_start_capital > 0 &&
      g_target_capital > day_start_capital &&
      remaining_today > 0)
   {
      required_today_pct =
         (
            MathPow(
               g_target_capital /
               day_start_capital,
               1.0 /
               (double)remaining_today
            )
            - 1.0
         ) * 100.0;

      required_today_eur =
         day_start_capital *
         required_today_pct /
         100.0;

      today_end_target =
         day_start_capital +
         required_today_eur;
   }

   // Risultato effettivo della giornata
   double today_actual_result =
      g_current_capital -
      day_start_capital;

   double today_actual_pct =
      (day_start_capital > 0
       ? today_actual_result /
         day_start_capital *
         100.0
       : 0.0);

   double today_delta =
      g_current_capital -
      today_end_target;

   double today_missing =
      today_end_target -
      g_current_capital;

   if(today_missing < 0)
      today_missing = 0;

   // ================================================================
   // OBIETTIVO DI OGGI
   // ================================================================
   if(g_target_reached)
   {
      ObjectSetString(0, O_REQUIRED_PCT, OBJPROP_TEXT,
                      "TARGET COMPLETATO");

      ObjectSetString(0, O_REQUIRED_EURO, OBJPROP_TEXT,
                      DoubleToString(g_target_capital,2) + " EUR");

      ObjectSetInteger(0, O_REQUIRED_PCT, OBJPROP_COLOR, GREEN_COLOR);
      ObjectSetInteger(0, O_REQUIRED_EURO, OBJPROP_COLOR, GREEN_COLOR);
   }
   else
   if(g_days_remaining <= 0)
   {
      ObjectSetString(0, O_REQUIRED_PCT, OBJPROP_TEXT,
                      "TEMPO TERMINATO");

      ObjectSetString(0, O_REQUIRED_EURO, OBJPROP_TEXT,
                      "Mancano " + DoubleToString(missing_total,2) + " EUR");

      ObjectSetInteger(0, O_REQUIRED_PCT, OBJPROP_COLOR, RED_COLOR);
      ObjectSetInteger(0, O_REQUIRED_EURO, OBJPROP_COLOR, RED_COLOR);
   }
   else
   {
      ObjectSetString(
         0,
         O_REQUIRED_PCT,
         OBJPROP_TEXT,
         "Richiesto oggi: +" +
         DoubleToString(required_today_pct,2) +
         "%"
      );

      ObjectSetString(
         0,
         O_REQUIRED_EURO,
         OBJPROP_TEXT,
         "Mancano oggi: " +
         DoubleToString(today_missing,2) +
         " EUR"
      );

      ObjectSetInteger(
         0,
         O_REQUIRED_PCT,
         OBJPROP_COLOR,
         today_missing <= 0 ? GREEN_COLOR : YELLOW_COLOR
      );

      ObjectSetInteger(
         0,
         O_REQUIRED_EURO,
         OBJPROP_COLOR,
         today_missing <= 0 ? GREEN_COLOR : ORANGE_COLOR
      );
   }

   // ================================================================
   // RISK MANAGER
   // ================================================================
   if(g_current_page == 3)
   {
      StrategyRefreshState();

      double closed=StrategyTodayClosedResult();
      double floating=StrategyOpenFloating();
      double target=StrategyDailyTargetEUR();
      int trades=StrategyTradesToday();
      int positions=StrategyOpenPositions();

      string state="MONITOR ON";
      if(!g_strategy_enabled) state="MONITOR OFF";
      else if(g_strategy_daily_locked) state="DAILY LOCK";
      else if(TimeCurrent()<g_strategy_pause_until) state="IN PAUSA";

      ObjectSetString(0,ObjName("STRAT_STATE"),OBJPROP_TEXT,state);
      ObjectSetString(0,ObjName("STRAT_SCOPE"),OBJPROP_TEXT,StrategyScopeText());
      ObjectSetString(0,ObjName("STRAT_TRADES"),OBJPROP_TEXT,
                      IntegerToString(trades)+" / "+IntegerToString(g_strategy_max_trades_day));
      ObjectSetString(0,ObjName("STRAT_POS"),OBJPROP_TEXT,
                      IntegerToString(positions)+" / "+IntegerToString(g_strategy_max_open_positions));

      color sc = !g_strategy_enabled ? MUTED_COLOR :
                 g_strategy_daily_locked ? RED_COLOR :
                 TimeCurrent()<g_strategy_pause_until ? ORANGE_COLOR :
                 GREEN_COLOR;

      ObjectSetInteger(0,ObjName("STRAT_STATE"),OBJPROP_COLOR,sc);

      ObjectSetString(0,ObjName("STRAT_D_TARGET"),OBJPROP_TEXT,
                      "TARGET OGGI  +"+DoubleToString(target,2)+" EUR");

      ObjectSetString(0,ObjName("STRAT_D_REAL"),OBJPROP_TEXT,
                      "REALIZZATO  "+(closed>=0?"+":"")+DoubleToString(closed,2)+" EUR");

      ObjectSetInteger(0,ObjName("STRAT_D_REAL"),OBJPROP_COLOR,
                       closed>0?GREEN_COLOR:closed<0?RED_COLOR:TEXT_COLOR);

      ObjectSetString(0,ObjName("STRAT_D_FLOAT"),OBJPROP_TEXT,
                      "FLOATING  "+(floating>=0?"+":"")+DoubleToString(floating,2)+" EUR");

      ObjectSetInteger(0,ObjName("STRAT_D_FLOAT"),OBJPROP_COLOR,
                       floating>0?GREEN_COLOR:floating<0?RED_COLOR:TEXT_COLOR);

      ObjectSetString(0,ObjName("STRAT_D_LOCK"),OBJPROP_TEXT,
                      g_strategy_daily_locked ? "DAILY LOCK: ATTIVO" : "DAILY LOCK: LIBERO");

      ObjectSetInteger(0,ObjName("STRAT_D_LOCK"),OBJPROP_COLOR,
                       g_strategy_daily_locked?RED_COLOR:GREEN_COLOR);

      string pause="PAUSA: NESSUNA";
      if(TimeCurrent()<g_strategy_pause_until)
         pause="PAUSA FINO A "+TimeToString(g_strategy_pause_until,TIME_MINUTES|TIME_SECONDS);

      ObjectSetString(0,ObjName("STRAT_D_PAUSE"),OBJPROP_TEXT,pause);

      string marginMode =
         AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING
         ? "HEDGING" : "NETTING/EXCHANGE";

      long stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
      long freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      ObjectSetString(0,ObjName("STRAT_TECH1"),OBJPROP_TEXT,
                      "Account mode: "+marginMode+
                      "  |  Server: "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));

      ObjectSetString(0,ObjName("STRAT_TECH2"),OBJPROP_TEXT,
                      "Stops level: "+IntegerToString((int)stops)+
                      " pt  |  Freeze: "+IntegerToString((int)freeze)+
                      " pt  |  Tick size: "+DoubleToString(tick,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)));

      double ref=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double tp=StrategyPriceForMoney(_Symbol,ORDER_TYPE_BUY,g_strategy_fixed_lot,ref,g_strategy_tp_eur,true);
      double sl=StrategyPriceForMoney(_Symbol,ORDER_TYPE_BUY,g_strategy_fixed_lot,ref,g_strategy_sl_eur,false);

      ObjectSetString(0,ObjName("STRAT_TECH3"),OBJPROP_TEXT,
                      "Preview BUY "+_Symbol+
                      "  | TP "+(tp>0?DoubleToString(tp,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)):"N/D")+
                      "  | SL "+(sl>0?DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)):"N/D"));

      string reason;
      bool canTrade=StrategyCanTrade(reason);

      ObjectSetString(0,ObjName("STRAT_TECH4"),OBJPROP_TEXT,
                      "Valutazione monitor: "+(canTrade?"OPERATIVITA' OK":"OPERATIVITA' DA EVITARE")+
                      "  |  "+reason+
                      "  |  (il monitor non apre/chiude posizioni)");

      ObjectSetInteger(0,ObjName("STRAT_TECH4"),OBJPROP_COLOR,
                       canTrade?GREEN_COLOR:ORANGE_COLOR);
   }

   // ================================================================
   // PROGRESSO TARGET GIORNALIERO - LIVE
   // ================================================================
   if(g_current_page == 1)
   {
      double realized_today_for_bar = GetTodayClosedResult();
      double floating_today_for_bar = GetOpenFloatingResult();

      // Il target giornaliero in euro è la crescita richiesta da capitale
      // di inizio giornata a target di fine giornata.
      double daily_target_eur =
         today_end_target -
         day_start_capital;

      if(daily_target_eur < 0)
         daily_target_eur = 0;

      // Progresso REALIZZATO: solo ciò che è già chiuso.
      double realized_progress_pct = 0.0;

      if(daily_target_eur > 0)
      {
         realized_progress_pct =
            realized_today_for_bar /
            daily_target_eur *
            100.0;
      }
      else
      if(g_target_reached)
      {
         realized_progress_pct = 100.0;
      }

      if(realized_progress_pct < 0)
         realized_progress_pct = 0;

      double realized_progress_bar = realized_progress_pct;
      if(realized_progress_bar > 100.0)
         realized_progress_bar = 100.0;

      int daily_bar_width =
         (int)MathRound(
            g_bar_w *
            realized_progress_bar /
            100.0
         );

      if(daily_bar_width < 1)
         daily_bar_width = 1;

      if(daily_bar_width > g_bar_w)
         daily_bar_width = g_bar_w;

      if(ObjectFind(0,ObjName("DAILY_BAR")) >= 0)
      {
         ObjectSetInteger(
            0,
            ObjName("DAILY_BAR"),
            OBJPROP_XSIZE,
            daily_bar_width
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_BAR"),
            OBJPROP_BGCOLOR,
            realized_progress_pct >= 100.0
            ? GREEN_COLOR
            : YELLOW_COLOR
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_BAR"),
            OBJPROP_COLOR,
            realized_progress_pct >= 100.0
            ? GREEN_COLOR
            : YELLOW_COLOR
         );
      }

      double daily_missing_realized =
         daily_target_eur -
         realized_today_for_bar;

      if(daily_missing_realized < 0)
         daily_missing_realized = 0;

      if(ObjectFind(0,ObjName("DAILY_CURRENT")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("DAILY_CURRENT"),
            OBJPROP_TEXT,
            "REALIZZATO  " +
            (realized_today_for_bar >= 0 ? "+" : "") +
            DoubleToString(realized_today_for_bar,2) +
            " EUR"
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_CURRENT"),
            OBJPROP_COLOR,
            realized_today_for_bar > 0 ? GREEN_COLOR :
            realized_today_for_bar < 0 ? RED_COLOR :
            TEXT_COLOR
         );
      }

      if(ObjectFind(0,ObjName("DAILY_MISSING")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("DAILY_MISSING"),
            OBJPROP_TEXT,
            "MANCANO  " +
            DoubleToString(daily_missing_realized,2) +
            " EUR"
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_MISSING"),
            OBJPROP_COLOR,
            daily_missing_realized <= 0
            ? GREEN_COLOR
            : ORANGE_COLOR
         );
      }

      if(ObjectFind(0,ObjName("DAILY_TARGET")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("DAILY_TARGET"),
            OBJPROP_TEXT,
            "TARGET  +" +
            DoubleToString(daily_target_eur,2) +
            " EUR"
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_TARGET"),
            OBJPROP_COLOR,
            GREEN_COLOR
         );
      }

      if(ObjectFind(0,ObjName("DAILY_PROGRESS_TEXT")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("DAILY_PROGRESS_TEXT"),
            OBJPROP_TEXT,
            "TARGET GIORNALIERO COMPLETATO  " +
            DoubleToString(realized_progress_pct,1) +
            "%"
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_PROGRESS_TEXT"),
            OBJPROP_COLOR,
            realized_progress_pct >= 100.0
            ? GREEN_COLOR
            : TEXT_COLOR
         );
      }

      if(ObjectFind(0,ObjName("DAILY_REALIZED_TEXT")) >= 0)
      {
         double realized_pct_day =
            (day_start_capital > 0
             ? realized_today_for_bar /
               day_start_capital *
               100.0
             : 0.0);

         ObjectSetString(
            0,
            ObjName("DAILY_REALIZED_TEXT"),
            OBJPROP_TEXT,
            "Realizzato: " +
            (realized_today_for_bar >= 0 ? "+" : "") +
            DoubleToString(realized_today_for_bar,2) +
            " EUR  (" +
            (realized_pct_day >= 0 ? "+" : "") +
            DoubleToString(realized_pct_day,2) +
            "%)"
         );
      }

      if(ObjectFind(0,ObjName("DAILY_FLOATING_TEXT")) >= 0)
      {
         double potential_today =
            realized_today_for_bar +
            floating_today_for_bar;

         double potential_progress_pct = 0.0;

         if(daily_target_eur > 0)
            potential_progress_pct =
               potential_today /
               daily_target_eur *
               100.0;

         ObjectSetString(
            0,
            ObjName("DAILY_FLOATING_TEXT"),
            OBJPROP_TEXT,
            "Con floating: " +
            (potential_today >= 0 ? "+" : "") +
            DoubleToString(potential_today,2) +
            " EUR  (" +
            DoubleToString(potential_progress_pct,1) +
            "% del target)"
         );

         ObjectSetInteger(
            0,
            ObjName("DAILY_FLOATING_TEXT"),
            OBJPROP_COLOR,
            potential_progress_pct >= 100.0
            ? GREEN_COLOR
            : floating_today_for_bar < 0
              ? RED_COLOR
              : MUTED_COLOR
         );
      }
   }

   // ================================================================
   // METRICHE LIVE REALTIME
   // ================================================================
   if(g_current_page == 1)
   {
      double realized_today = GetTodayClosedResult();
      double floating_open  = GetOpenFloatingResult();
      double potential_now  = realized_today + floating_open;

      double potential_capital =
         day_start_capital +
         potential_now;

      double missing_if_close =
         today_end_target -
         potential_capital;

      if(missing_if_close < 0)
         missing_if_close = 0;

      if(ObjectFind(0,ObjName("RT_REALIZED")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("RT_REALIZED"),
            OBJPROP_TEXT,
            (realized_today >= 0 ? "+" : "") +
            DoubleToString(realized_today,2) + " EUR"
         );
         ObjectSetInteger(
            0,
            ObjName("RT_REALIZED"),
            OBJPROP_COLOR,
            realized_today > 0 ? GREEN_COLOR :
            realized_today < 0 ? RED_COLOR : TEXT_COLOR
         );
      }

      if(ObjectFind(0,ObjName("RT_FLOATING")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("RT_FLOATING"),
            OBJPROP_TEXT,
            (floating_open >= 0 ? "+" : "") +
            DoubleToString(floating_open,2) + " EUR"
         );
         ObjectSetInteger(
            0,
            ObjName("RT_FLOATING"),
            OBJPROP_COLOR,
            floating_open > 0 ? GREEN_COLOR :
            floating_open < 0 ? RED_COLOR : TEXT_COLOR
         );
      }

      if(ObjectFind(0,ObjName("RT_POTENTIAL")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("RT_POTENTIAL"),
            OBJPROP_TEXT,
            (potential_now >= 0 ? "+" : "") +
            DoubleToString(potential_now,2) + " EUR"
         );
         ObjectSetInteger(
            0,
            ObjName("RT_POTENTIAL"),
            OBJPROP_COLOR,
            potential_now > 0 ? GREEN_COLOR :
            potential_now < 0 ? RED_COLOR : TEXT_COLOR
         );
      }

      if(ObjectFind(0,ObjName("RT_MISSING")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("RT_MISSING"),
            OBJPROP_TEXT,
            DoubleToString(missing_if_close,2) + " EUR"
         );
         ObjectSetInteger(
            0,
            ObjName("RT_MISSING"),
            OBJPROP_COLOR,
            missing_if_close <= 0 ? GREEN_COLOR : ORANGE_COLOR
         );
      }
   }

   // ================================================================
   // STATUS GIORNALIERO
   //
   // LIVE e SIMULATORE usano la stessa logica:
   // - VERDE: fatto più del richiesto
   // - VERDE: target centrato
   // - ARANCIONE: positivo ma sotto il richiesto
   // - ROSSO: risultato negativo
   // ================================================================
   if(g_target_reached)
   {
      ObjectSetString(0, O_STATUS, OBJPROP_TEXT,
                      "TARGET FINALE RAGGIUNTO");
      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, GREEN_COLOR);
   }
   else
   if(g_days_remaining <= 0)
   {
      ObjectSetString(0, O_STATUS, OBJPROP_TEXT,
                      "TEMPO TERMINATO  |  MANCANO " +
                      DoubleToString(missing_total,2) + " EUR");
      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, RED_COLOR);
   }
   else
   if(today_actual_result < -0.005)
   {
      ObjectSetString(
         0,
         O_STATUS,
         OBJPROP_TEXT,
         "OGGI IN PERDITA  |  " +
         DoubleToString(today_actual_result,2) +
         " EUR (" +
         DoubleToString(today_actual_pct,2) +
         "%)  |  MANCANO " +
         DoubleToString(today_missing,2) +
         " EUR AL TARGET DI OGGI"
      );

      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, RED_COLOR);
   }
   else
   if(!g_simulator_mode)
   {
      double realized_now = GetTodayClosedResult();
      double floating_now = GetOpenFloatingResult();
      double potential_capital = day_start_capital + realized_now + floating_now;

      if(g_current_capital + 0.005 < today_end_target &&
         potential_capital + 0.005 >= today_end_target)
      {
         ObjectSetString(
            0,
            O_STATUS,
            OBJPROP_TEXT,
            "TARGET POTENZIALMENTE RAGGIUNTO  |  FLOATING " +
            (floating_now >= 0 ? "+" : "") +
            DoubleToString(floating_now,2) +
            " EUR  |  NON ANCORA REALIZZATO"
         );

         ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, YELLOW_COLOR);
      }
      else
      if(today_delta > 0.005)
      {
         ObjectSetString(
            0,
            O_STATUS,
            OBJPROP_TEXT,
            "OGGI SOPRA TARGET  |  +" +
            DoubleToString(today_actual_result,2) +
            " EUR (" +
            DoubleToString(today_actual_pct,2) +
            "%)  |  +" +
            DoubleToString(today_delta,2) +
            " EUR OLTRE IL RICHIESTO"
         );

         ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, GREEN_COLOR);
      }
      else
      if(MathAbs(today_delta) <= 0.005)
      {
         ObjectSetString(
            0,
            O_STATUS,
            OBJPROP_TEXT,
            "TARGET DI OGGI CENTRATO  |  +" +
            DoubleToString(today_actual_result,2) +
            " EUR (" +
            DoubleToString(today_actual_pct,2) +
            "%)"
         );

         ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, GREEN_COLOR);
      }
      else
      {
         ObjectSetString(
            0,
            O_STATUS,
            OBJPROP_TEXT,
            "OGGI SOTTO TARGET  |  FATTO +" +
            DoubleToString(today_actual_result,2) +
            " EUR (" +
            DoubleToString(today_actual_pct,2) +
            "%)  |  MANCANO " +
            DoubleToString(today_missing,2) +
            " EUR"
         );

         ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, ORANGE_COLOR);
      }
   }
   else
   if(today_delta > 0.005)
   {
      ObjectSetString(
         0,
         O_STATUS,
         OBJPROP_TEXT,
         "OGGI SOPRA TARGET  |  +" +
         DoubleToString(today_actual_result,2) +
         " EUR (" +
         DoubleToString(today_actual_pct,2) +
         "%)  |  +" +
         DoubleToString(today_delta,2) +
         " EUR OLTRE IL RICHIESTO"
      );

      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, GREEN_COLOR);
   }
   else
   if(MathAbs(today_delta) <= 0.005)
   {
      ObjectSetString(
         0,
         O_STATUS,
         OBJPROP_TEXT,
         "TARGET DI OGGI CENTRATO  |  +" +
         DoubleToString(today_actual_result,2) +
         " EUR (" +
         DoubleToString(today_actual_pct,2) +
         "%)"
      );

      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, GREEN_COLOR);
   }
   else
   {
      ObjectSetString(
         0,
         O_STATUS,
         OBJPROP_TEXT,
         "OGGI SOTTO TARGET  |  FATTO +" +
         DoubleToString(today_actual_result,2) +
         " EUR (" +
         DoubleToString(today_actual_pct,2) +
         "%)  |  MANCANO " +
         DoubleToString(today_missing,2) +
         " EUR"
      );

      ObjectSetInteger(0, O_STATUS, OBJPROP_COLOR, ORANGE_COLOR);
   }

   // ================================================================
   // TABELLE / PAGINE
   // ================================================================
   if(g_current_page == 2)
   {
      double floating = GetOpenFloatingResult();
      double tp_total = GetOpenPotentialTP();
      double sl_total = GetOpenRiskSL();

      ObjectSetString(
         0,
         O_STATUS,
         OBJPROP_TEXT,
         "FLOATING " +
         (floating >= 0 ? "+" : "") +
         DoubleToString(floating,2) +
         " EUR  |  TP POTENZIALE " +
         (tp_total >= 0 ? "+" : "") +
         DoubleToString(tp_total,2) +
         " EUR  |  RISCHIO SL " +
         DoubleToString(sl_total,2) +
         " EUR"
      );

      ObjectSetInteger(
         0,
         O_STATUS,
         OBJPROP_COLOR,
         floating > 0 ? GREEN_COLOR :
         floating < 0 ? RED_COLOR : TEXT_COLOR
      );

      // pulizia righe
      for(int r=1; r<=DATA_ROWS_VISIBLE; r++)
      {
         string rr = IntegerToString(r);

         string cells[] = {
            ObjName("ORD_SYM_"+rr),ObjName("ORD_TYPE_"+rr),ObjName("ORD_LOT_"+rr),
            ObjName("ORD_ENTRY_"+rr),ObjName("ORD_NOW_"+rr),ObjName("ORD_PL_"+rr),
            ObjName("ORD_SL_"+rr),ObjName("ORD_TP_"+rr),ObjName("ORD_TPE_"+rr),
            ObjName("ORD_SLE_"+rr)
         };

         for(int c=0; c<ArraySize(cells); c++)
         {
            if(ObjectFind(0,cells[c]) >= 0)
               ObjectSetString(0,cells[c],OBJPROP_TEXT," ");
         }
      }

      int total_positions = PositionsTotal();

      int max_order_offset =
         total_positions - DATA_ROWS_VISIBLE;
      if(max_order_offset < 0)
         max_order_offset = 0;

      if(g_scroll_orders > max_order_offset)
         g_scroll_orders = max_order_offset;
      if(g_scroll_orders < 0)
         g_scroll_orders = 0;

      int rows = total_positions - g_scroll_orders;
      if(rows > DATA_ROWS_VISIBLE)
         rows = DATA_ROWS_VISIBLE;
      if(rows < 0)
         rows = 0;

      if(ObjectFind(0,ObjName("ORD_SCROLL_INFO")) >= 0)
      {
         string info =
            (total_positions <= 0
             ? "0 / 0"
             : IntegerToString(g_scroll_orders+1) +
               "-" +
               IntegerToString(g_scroll_orders+rows) +
               " / " +
               IntegerToString(total_positions));

         ObjectSetString(
            0,
            ObjName("ORD_SCROLL_INFO"),
            OBJPROP_TEXT,
            info
         );
      }

      for(int i=0; i<rows; i++)
      {
         int position_index = g_scroll_orders + i;

         ulong ticket = PositionGetTicket(position_index);
         if(ticket == 0)
            continue;

         string rr = IntegerToString(i+1);

         string symbol = PositionGetString(POSITION_SYMBOL);
         long ptype = PositionGetInteger(POSITION_TYPE);
         string side = (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL");

         double volume = PositionGetDouble(POSITION_VOLUME);
         double open   = PositionGetDouble(POSITION_PRICE_OPEN);
         double now    = PositionGetDouble(POSITION_PRICE_CURRENT);
         double pl     = PositionGetDouble(POSITION_PROFIT) +
                         PositionGetDouble(POSITION_SWAP);
         double sl     = PositionGetDouble(POSITION_SL);
         double tp     = PositionGetDouble(POSITION_TP);

         ENUM_ORDER_TYPE otype =
            (ptype == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

         double tp_eur = 0.0;
         bool has_tp = false;

         if(tp > 0)
            has_tp = OrderCalcProfit(otype,symbol,volume,open,tp,tp_eur);

         double sl_eur = 0.0;
         bool has_sl = false;

         if(sl > 0)
            has_sl = OrderCalcProfit(otype,symbol,volume,open,sl,sl_eur);

         int digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

         ObjectSetString(0,ObjName("ORD_SYM_"+rr),OBJPROP_TEXT,symbol);
         ObjectSetString(0,ObjName("ORD_TYPE_"+rr),OBJPROP_TEXT,side);
         ObjectSetString(0,ObjName("ORD_LOT_"+rr),OBJPROP_TEXT,DoubleToString(volume,2));
         ObjectSetString(0,ObjName("ORD_ENTRY_"+rr),OBJPROP_TEXT,DoubleToString(open,digits));
         ObjectSetString(0,ObjName("ORD_NOW_"+rr),OBJPROP_TEXT,DoubleToString(now,digits));
         ObjectSetString(0,ObjName("ORD_PL_"+rr),OBJPROP_TEXT,
                         (pl >= 0 ? "+" : "") + DoubleToString(pl,2));
         ObjectSetString(0,ObjName("ORD_SL_"+rr),OBJPROP_TEXT,
                         sl > 0 ? DoubleToString(sl,digits) : "—");
         ObjectSetString(0,ObjName("ORD_TP_"+rr),OBJPROP_TEXT,
                         tp > 0 ? DoubleToString(tp,digits) : "—");
         ObjectSetString(0,ObjName("ORD_TPE_"+rr),OBJPROP_TEXT,
                         has_tp ? ((tp_eur >= 0 ? "+" : "") + DoubleToString(tp_eur,2)) : "—");
         ObjectSetString(0,ObjName("ORD_SLE_"+rr),OBJPROP_TEXT,
                         has_sl ? DoubleToString(sl_eur,2) : "—");

         ObjectSetInteger(
            0,
            ObjName("ORD_PL_"+rr),
            OBJPROP_COLOR,
            pl > 0 ? GREEN_COLOR :
            pl < 0 ? RED_COLOR : TEXT_COLOR
         );
      }
   }
   else
   if(g_current_page == 4)
   {
      ObjectSetString(0, O_SYMBOL_TITLE, OBJPROP_TEXT,
                      "SIMULAZIONE DELLE GIORNATE");

      // Pulisce celle visibili.
      for(int r=1; r<=30; r++)
      {
         string rr = IntegerToString(r);

         string cells[] = {
            ObjName("SIM_GG_"+rr),ObjName("SIM_START_"+rr),ObjName("SIM_TARGET_"+rr),
            ObjName("SIM_RESULT_"+rr),ObjName("SIM_CLOSE_"+rr),ObjName("SIM_DELTA_"+rr),
            ObjName("SIM_PCT_"+rr),ObjName("SIM_STATE_"+rr)
         };

         for(int c=0; c<ArraySize(cells); c++)
         {
            if(ObjectFind(0,cells[c]) >= 0)
            {
               ObjectSetString(0,cells[c],OBJPROP_TEXT," ");
               ObjectSetInteger(0,cells[c],OBJPROP_COLOR,TEXT_COLOR);
            }
         }
      }

      // Costruiamo prima tutte le righe logiche.
      int total_rows = 0;

      // Max 366 righe, usiamo array locali.
      int    row_day[367];
      double row_start[367];
      double row_target[367];
      double row_result[367];
      double row_close[367];
      double row_delta[367];
      double row_pct[367];
      int    row_kind[367]; // 1 storico, 2 piano

      for(int d=1; d<=g_total_days && d<367; d++)
      {
         if(!g_sim_recorded[d])
            continue;

         row_day[total_rows]    = d;
         row_start[total_rows]  = g_sim_open[d];
         row_target[total_rows] = g_sim_required_end[d];
         row_result[total_rows] = g_sim_result_eur[d];
         row_close[total_rows]  = g_sim_close[d];
         row_delta[total_rows]  = g_sim_delta_vs_plan[d];
         row_pct[total_rows]    = g_sim_result_pct[d];
         row_kind[total_rows]   = 1;
         total_rows++;
      }

      int plan_day = g_sim_day;
      if(plan_day < 1) plan_day = 1;
      if(plan_day > g_total_days) plan_day = g_total_days;

      int remaining_days = g_total_days - plan_day + 1;
      if(remaining_days < 1) remaining_days = 1;

      double start_cap = g_sim_capital;
      double factor = 1.0;

      if(start_cap > 0 &&
         g_target_capital > start_cap)
      {
         factor =
            MathPow(
               g_target_capital/start_cap,
               1.0/(double)remaining_days
            );
      }

      for(int d=plan_day; d<=g_total_days && d<367; d++)
      {
         if(g_sim_recorded[d])
            continue;

         double target_end = start_cap * factor;
         if(d == g_total_days)
            target_end = g_target_capital;

         double inc = target_end - start_cap;
         double pct = (start_cap > 0 ? inc/start_cap*100.0 : 0.0);

         row_day[total_rows]    = d;
         row_start[total_rows]  = start_cap;
         row_target[total_rows] = target_end;
         row_result[total_rows] = inc;
         row_close[total_rows]  = target_end;
         row_delta[total_rows]  = 0.0;
         row_pct[total_rows]    = pct;
         row_kind[total_rows]   = 2;
         total_rows++;

         start_cap = target_end;
      }

      int max_sim_offset = total_rows - DATA_ROWS_VISIBLE;
      if(max_sim_offset < 0)
         max_sim_offset = 0;

      if(g_scroll_sim > max_sim_offset)
         g_scroll_sim = max_sim_offset;
      if(g_scroll_sim < 0)
         g_scroll_sim = 0;

      int visible_rows = total_rows - g_scroll_sim;
      if(visible_rows > DATA_ROWS_VISIBLE)
         visible_rows = DATA_ROWS_VISIBLE;
      if(visible_rows < 0)
         visible_rows = 0;

      if(ObjectFind(0,ObjName("SIM_SCROLL_INFO")) >= 0)
      {
         string info =
            (total_rows <= 0
             ? "0 / 0"
             : IntegerToString(g_scroll_sim+1) +
               "-" +
               IntegerToString(g_scroll_sim+visible_rows) +
               " / " +
               IntegerToString(total_rows));

         ObjectSetString(0,ObjName("SIM_SCROLL_INFO"),OBJPROP_TEXT,info);
      }

      for(int v=0; v<visible_rows; v++)
      {
         int idx = g_scroll_sim + v;
         string rr = IntegerToString(v+1);

         ObjectSetString(0,ObjName("SIM_GG_"+rr),OBJPROP_TEXT,IntegerToString(row_day[idx]));
         ObjectSetString(0,ObjName("SIM_START_"+rr),OBJPROP_TEXT,DoubleToString(row_start[idx],2));
         ObjectSetString(0,ObjName("SIM_TARGET_"+rr),OBJPROP_TEXT,DoubleToString(row_target[idx],2));

         if(row_kind[idx] == 1)
         {
            ObjectSetString(0,ObjName("SIM_RESULT_"+rr),OBJPROP_TEXT,
                            (row_result[idx] >= 0 ? "+" : "") + DoubleToString(row_result[idx],2));
            ObjectSetString(0,ObjName("SIM_CLOSE_"+rr),OBJPROP_TEXT,DoubleToString(row_close[idx],2));
            ObjectSetString(0,ObjName("SIM_DELTA_"+rr),OBJPROP_TEXT,
                            (row_delta[idx] >= 0 ? "+" : "") + DoubleToString(row_delta[idx],2));
            ObjectSetString(0,ObjName("SIM_PCT_"+rr),OBJPROP_TEXT,
                            (row_pct[idx] >= 0 ? "+" : "") + DoubleToString(row_pct[idx],2) + "%");

            string stato =
               (row_delta[idx] >= 0.005 ? "SOPRA" :
                row_delta[idx] <= -0.005 ? "SOTTO" : "OK");

            ObjectSetString(0,ObjName("SIM_STATE_"+rr),OBJPROP_TEXT,stato);

            color rc =
               (row_delta[idx] > 0.005 ? GREEN_COLOR :
                row_delta[idx] < -0.005 ? RED_COLOR : TEXT_COLOR);

            string cellsHist[] = {
               ObjName("SIM_GG_"+rr),ObjName("SIM_START_"+rr),ObjName("SIM_TARGET_"+rr),
               ObjName("SIM_RESULT_"+rr),ObjName("SIM_CLOSE_"+rr),ObjName("SIM_DELTA_"+rr),
               ObjName("SIM_PCT_"+rr),ObjName("SIM_STATE_"+rr)
            };
            for(int c=0; c<ArraySize(cellsHist); c++)
               ObjectSetInteger(0,cellsHist[c],OBJPROP_COLOR,rc);
         }
         else
         {
            ObjectSetString(0,ObjName("SIM_RESULT_"+rr),OBJPROP_TEXT,"+"+DoubleToString(row_result[idx],2));
            ObjectSetString(0,ObjName("SIM_CLOSE_"+rr),OBJPROP_TEXT,DoubleToString(row_close[idx],2));
            ObjectSetString(0,ObjName("SIM_DELTA_"+rr),OBJPROP_TEXT,"—");
            ObjectSetString(0,ObjName("SIM_PCT_"+rr),OBJPROP_TEXT,"+"+DoubleToString(row_pct[idx],2)+"%");
            ObjectSetString(0,ObjName("SIM_STATE_"+rr),OBJPROP_TEXT,"PIANO");

            color rc =
               (row_day[idx] == plan_day ? YELLOW_COLOR : MUTED_COLOR);

            string cellsPlan[] = {
               ObjName("SIM_GG_"+rr),ObjName("SIM_START_"+rr),ObjName("SIM_TARGET_"+rr),
               ObjName("SIM_RESULT_"+rr),ObjName("SIM_CLOSE_"+rr),ObjName("SIM_DELTA_"+rr),
               ObjName("SIM_PCT_"+rr),ObjName("SIM_STATE_"+rr)
            };
            for(int c=0; c<ArraySize(cellsPlan); c++)
               ObjectSetInteger(0,cellsPlan[c],OBJPROP_COLOR,rc);
         }
      }
   }
   else
   if(g_current_page == 5)
   {
      ObjectSetString(0, O_SYMBOL_TITLE, OBJPROP_TEXT,
                      "PIANO GIORNALIERO: PERCENTUALI E IMPORTI");

      for(int r=1; r<=30; r++)
      {
         string rn = ObjName("PLAN_TABLE_ROW_"+IntegerToString(r));
         if(ObjectFind(0,rn) >= 0)
            ObjectSetString(0,rn,OBJPROP_TEXT," ");
      }

      double plan_cap = g_sim_capital;
      int plan_day = g_sim_day;

      if(plan_day < 1) plan_day = 1;
      if(plan_day > g_total_days) plan_day = g_total_days;

      int total_rows = g_total_days - plan_day + 1;
      if(total_rows < 0)
         total_rows = 0;

      int max_plan_offset = total_rows - DATA_ROWS_VISIBLE;
      if(max_plan_offset < 0)
         max_plan_offset = 0;

      if(g_scroll_plan > max_plan_offset)
         g_scroll_plan = max_plan_offset;
      if(g_scroll_plan < 0)
         g_scroll_plan = 0;

      int visible_rows = total_rows - g_scroll_plan;
      if(visible_rows > DATA_ROWS_VISIBLE)
         visible_rows = DATA_ROWS_VISIBLE;
      if(visible_rows < 0)
         visible_rows = 0;

      if(ObjectFind(0,ObjName("PLAN_SCROLL_INFO")) >= 0)
      {
         string info =
            (total_rows <= 0
             ? "0 / 0"
             : IntegerToString(g_scroll_plan+1) +
               "-" +
               IntegerToString(g_scroll_plan+visible_rows) +
               " / " +
               IntegerToString(total_rows));

         ObjectSetString(0,ObjName("PLAN_SCROLL_INFO"),OBJPROP_TEXT,info);
      }

      int remaining_plan_days = g_total_days - plan_day + 1;
      if(remaining_plan_days < 1)
         remaining_plan_days = 1;

      double factor = 1.0;

      if(plan_cap > 0 &&
         g_target_capital > plan_cap &&
         remaining_plan_days > 0)
      {
         factor =
            MathPow(
               g_target_capital / plan_cap,
               1.0 / (double)remaining_plan_days
            );
      }

      // Avanza virtualmente fino all'offset.
      double start_cap = plan_cap;

      for(int skip=0; skip<g_scroll_plan; skip++)
      {
         int dskip = plan_day + skip;
         double target_skip = start_cap * factor;

         if(dskip == g_total_days)
            target_skip = g_target_capital;

         start_cap = target_skip;
      }

      for(int v=0; v<visible_rows; v++)
      {
         int d = plan_day + g_scroll_plan + v;

         double target_end = start_cap * factor;

         if(d == g_total_days)
            target_end = g_target_capital;

         double eur_to_do = target_end - start_cap;
         double pct_to_do =
            (start_cap > 0 ? eur_to_do/start_cap*100.0 : 0.0);

         string line = StringFormat(
            "%2d      %12.2f        %12.2f        %10.2f        %8.2f%%",
            d,
            start_cap,
            target_end,
            eur_to_do,
            pct_to_do
         );

         string rn = ObjName("PLAN_TABLE_ROW_"+IntegerToString(v+1));

         ObjectSetString(0,rn,OBJPROP_TEXT,line);

         ObjectSetInteger(
            0,
            rn,
            OBJPROP_COLOR,
            d == plan_day ? YELLOW_COLOR : TEXT_COLOR
         );

         start_cap = target_end;
      }
   }
   else
   if(g_current_page == 6)
   {
      double live_start = GetLiveDayStartCapital();
      double live_result = g_current_capital - live_start;
      double live_pct =
         (live_start > 0 ? live_result/live_start*100.0 : 0.0);

      if(ObjectFind(0,ObjName("STAT_TODAY")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("STAT_TODAY"),
            OBJPROP_TEXT,
            "OGGI  |  START " +
            DoubleToString(live_start,2) +
            " EUR   |   RISULTATO " +
            (live_result >= 0 ? "+" : "") +
            DoubleToString(live_result,2) +
            " EUR   |   " +
            (live_pct >= 0 ? "+" : "") +
            DoubleToString(live_pct,2) +
            "%"
         );

         ObjectSetInteger(
            0,
            ObjName("STAT_TODAY"),
            OBJPROP_COLOR,
            live_result > 0 ? GREEN_COLOR :
            live_result < 0 ? RED_COLOR : TEXT_COLOR
         );
      }

      // Pulisce righe precedenti
      for(int r=1; r<=25; r++)
      {
         string rr = IntegerToString(r);

         string cells[] = {
            ObjName("STAT_SYM_"+rr),
            ObjName("STAT_TRADE_"+rr),
            ObjName("STAT_WIN_"+rr),
            ObjName("STAT_LOSS_"+rr),
            ObjName("STAT_GROSS_"+rr),
            ObjName("STAT_SWAP_"+rr),
            ObjName("STAT_COMM_"+rr),
            ObjName("STAT_PL_"+rr),
            ObjName("STAT_WR_"+rr)
         };

         for(int c=0; c<ArraySize(cells); c++)
         {
            if(ObjectFind(0,cells[c]) >= 0)
            {
               ObjectSetString(0,cells[c],OBJPROP_TEXT," ");
               ObjectSetInteger(0,cells[c],OBJPROP_COLOR,TEXT_COLOR);
            }
         }
      }

      SymbolStats stats[];
      int count = GetSymbolStatsCached(stats);

      int max_stats_offset =
         count - DATA_ROWS_VISIBLE;
      if(max_stats_offset < 0)
         max_stats_offset = 0;

      if(g_scroll_stats > max_stats_offset)
         g_scroll_stats = max_stats_offset;
      if(g_scroll_stats < 0)
         g_scroll_stats = 0;

      int visible_stats = count - g_scroll_stats;
      if(visible_stats > DATA_ROWS_VISIBLE)
         visible_stats = DATA_ROWS_VISIBLE;
      if(visible_stats < 0)
         visible_stats = 0;

      if(ObjectFind(0,ObjName("STAT_SCROLL_INFO")) >= 0)
      {
         string info =
            (count <= 0
             ? "0 / 0"
             : IntegerToString(g_scroll_stats+1) +
               "-" +
               IntegerToString(g_scroll_stats+visible_stats) +
               " / " +
               IntegerToString(count));

         ObjectSetString(0,ObjName("STAT_SCROLL_INFO"),OBJPROP_TEXT,info);
      }

      for(int i=0; i<visible_stats; i++)
      {
         int stat_index = g_scroll_stats + i;
         string rr = IntegerToString(i+1);

         double wr =
            (stats[stat_index].trades > 0
             ? ((double)stats[stat_index].wins / (double)stats[stat_index].trades) * 100.0
             : 0.0);

         ObjectSetString(0,ObjName("STAT_SYM_"+rr),OBJPROP_TEXT,stats[stat_index].symbol);
         ObjectSetString(0,ObjName("STAT_TRADE_"+rr),OBJPROP_TEXT,IntegerToString(stats[stat_index].trades));
         ObjectSetString(0,ObjName("STAT_WIN_"+rr),OBJPROP_TEXT,IntegerToString(stats[stat_index].wins));
         ObjectSetString(0,ObjName("STAT_LOSS_"+rr),OBJPROP_TEXT,IntegerToString(stats[stat_index].losses));

         ObjectSetString(
            0,
            ObjName("STAT_GROSS_"+rr),
            OBJPROP_TEXT,
            (stats[stat_index].gross_profit >= 0 ? "+" : "") +
            DoubleToString(stats[stat_index].gross_profit,2)
         );

         ObjectSetString(
            0,
            ObjName("STAT_SWAP_"+rr),
            OBJPROP_TEXT,
            (stats[stat_index].swap >= 0 ? "+" : "") +
            DoubleToString(stats[stat_index].swap,2)
         );

         ObjectSetString(
            0,
            ObjName("STAT_COMM_"+rr),
            OBJPROP_TEXT,
            (stats[stat_index].commission >= 0 ? "+" : "") +
            DoubleToString(stats[stat_index].commission,2)
         );

         ObjectSetString(
            0,
            ObjName("STAT_PL_"+rr),
            OBJPROP_TEXT,
            (stats[stat_index].profit >= 0 ? "+" : "") +
            DoubleToString(stats[stat_index].profit,2)
         );

         ObjectSetString(
            0,
            ObjName("STAT_WR_"+rr),
            OBJPROP_TEXT,
            DoubleToString(wr,1) + "%"
         );

         color rowColor =
            stats[stat_index].profit > 0 ? GREEN_COLOR :
            stats[stat_index].profit < 0 ? RED_COLOR :
            TEXT_COLOR;

         ObjectSetInteger(0,ObjName("STAT_GROSS_"+rr),OBJPROP_COLOR,
                          stats[stat_index].gross_profit>0 ? GREEN_COLOR :
                          stats[stat_index].gross_profit<0 ? RED_COLOR : TEXT_COLOR);

         ObjectSetInteger(0,ObjName("STAT_SWAP_"+rr),OBJPROP_COLOR,
                          stats[stat_index].swap<0 ? RED_COLOR :
                          stats[stat_index].swap>0 ? GREEN_COLOR : MUTED_COLOR);

         ObjectSetInteger(0,ObjName("STAT_COMM_"+rr),OBJPROP_COLOR,
                          stats[stat_index].commission<0 ? RED_COLOR :
                          stats[stat_index].commission>0 ? GREEN_COLOR : MUTED_COLOR);

         ObjectSetInteger(0,ObjName("STAT_PL_"+rr),OBJPROP_COLOR,rowColor);
      }

      if(count == 0 && ObjectFind(0,ObjName("STAT_SYM_1")) >= 0)
      {
         ObjectSetString(
            0,
            ObjName("STAT_SYM_1"),
            OBJPROP_TEXT,
            "Nessuna operazione chiusa nello storico disponibile."
         );
         ObjectSetInteger(0,ObjName("STAT_SYM_1"),OBJPROP_COLOR,MUTED_COLOR);
      }
   }

   ChartRedraw();
}

//====================================================================
// LEGGE INPUT DAGLI EDIT
//====================================================================

void ReadManualInputs()
{
   string initial_text =
      ObjectGetString(
         0,
         O_INITIAL_EDIT,
         OBJPROP_TEXT
      );

   string target_text =
      ObjectGetString(
         0,
         O_TARGET_EDIT,
         OBJPROP_TEXT
      );

   string days_text =
      ObjectGetString(
         0,
         O_DAYS_EDIT,
         OBJPROP_TEXT
      );

   double initial = ParseNumber(initial_text);
   double target  = ParseNumber(target_text);
   int    days    = ParseInteger(days_text);

   if(initial > 0)
      g_initial_capital = initial;

   if(target > 0)
      g_target_capital = target;

   if(days > 0)
   {
      days = ClampWorkingDays(days);

      if(g_simulator_mode)
         g_sim_total_days = days;
      else
         g_live_total_days = days;

      g_total_days =
         g_simulator_mode
         ? g_sim_total_days
         : g_live_total_days;
   }

   if(g_simulator_mode && g_sim_day > g_sim_total_days)
      g_sim_day = g_sim_total_days;

   // Campo DATA INIZIO (solo pagina LIVE)
   if(ObjectFind(0,O_START_EDIT) >= 0)
   {
      string st = ObjectGetString(0,O_START_EDIT,OBJPROP_TEXT);
      StringTrimLeft(st);
      StringTrimRight(st);
      StringReplace(st,"/",".");
      StringReplace(st,"-",".");

      datetime parsed = StringToTime(st);
      if(parsed > 0)
      {
         MqlDateTime pdt;
         TimeToStruct(parsed,pdt);
         pdt.hour = 0; pdt.min = 0; pdt.sec = 0;
         g_start_date = StructToTime(pdt);
      }
   }

   // Campi STRATEGIA
   if(ObjectFind(0,ObjName("STRAT_MAGIC"))>=0)
   {
      long v=ParseLong(ObjectGetString(0,ObjName("STRAT_MAGIC"),OBJPROP_TEXT));
      if(v>=0) g_strategy_magic=v;
   }

   if(ObjectFind(0,ObjName("STRAT_LOT"))>=0)
   {
      double v=ParseNumber(ObjectGetString(0,ObjName("STRAT_LOT"),OBJPROP_TEXT));
      if(v>0) g_strategy_fixed_lot=v;
   }

   if(ObjectFind(0,ObjName("STRAT_MAXPOS"))>=0)
   {
      int v=ParseInteger(ObjectGetString(0,ObjName("STRAT_MAXPOS"),OBJPROP_TEXT));
      if(v>0) g_strategy_max_open_positions=v;
   }

   if(ObjectFind(0,ObjName("STRAT_MAXTR"))>=0)
   {
      int v=ParseInteger(ObjectGetString(0,ObjName("STRAT_MAXTR"),OBJPROP_TEXT));
      if(v>0) g_strategy_max_trades_day=v;
   }

   if(ObjectFind(0,ObjName("STRAT_TP"))>=0)
   {
      double v=ParseNumber(ObjectGetString(0,ObjName("STRAT_TP"),OBJPROP_TEXT));
      if(v>0) g_strategy_tp_eur=v;
   }

   if(ObjectFind(0,ObjName("STRAT_SL"))>=0)
   {
      double v=ParseNumber(ObjectGetString(0,ObjName("STRAT_SL"),OBJPROP_TEXT));
      if(v>0) g_strategy_sl_eur=v;
   }

   if(ObjectFind(0,ObjName("STRAT_LOSSLIM"))>=0)
   {
      double v=ParseNumber(ObjectGetString(0,ObjName("STRAT_LOSSLIM"),OBJPROP_TEXT));
      if(v>0) g_strategy_daily_loss_limit=v;
   }

   if(ObjectFind(0,ObjName("STRAT_LOSSES"))>=0)
   {
      int v=ParseInteger(ObjectGetString(0,ObjName("STRAT_LOSSES"),OBJPROP_TEXT));
      if(v>0) g_strategy_losses_before_pause=v;
   }

   if(ObjectFind(0,ObjName("STRAT_PAUSE"))>=0)
   {
      int v=ParseInteger(ObjectGetString(0,ObjName("STRAT_PAUSE"),OBJPROP_TEXT));
      if(v>0) g_strategy_pause_minutes=v;
   }

   // Campi simulatore
   if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
   {
      double sim_cap =
         ParseNumber(ObjectGetString(0,ObjName("SIM_CAP_EDIT"),OBJPROP_TEXT));

      if(sim_cap > 0)
         g_sim_capital = sim_cap;
   }

   if(ObjectFind(0,ObjName("SIM_DAY_EDIT")) >= 0)
   {
      int sim_day =
         ParseInteger(ObjectGetString(0,ObjName("SIM_DAY_EDIT"),OBJPROP_TEXT));

      if(sim_day < 1) sim_day = 1;
      if(sim_day > g_total_days) sim_day = g_total_days;

      g_sim_day = sim_day;
   }

   if(ObjectFind(0,ObjName("SIM_RESULT_EDIT")) >= 0)
   {
      g_sim_day_result_input =
         ParseNumber(ObjectGetString(0,ObjName("SIM_RESULT_EDIT"),OBJPROP_TEXT));
   }
   SavePersistentState();
}

//====================================================================
// RESET
//====================================================================

void ResetInputs()
{
   g_initial_capital =
      InpInitialCapital;

   g_target_capital =
      InpTargetCapital;

   g_live_total_days =
      ClampWorkingDays(InpWorkingDays);

   g_sim_total_days =
      ClampWorkingDays(InpWorkingDays);

   g_total_days =
      g_simulator_mode
      ? g_sim_total_days
      : g_live_total_days;

   g_sim_capital = g_initial_capital;
   g_sim_day = 1;

   ObjectSetString(
      0,
      O_INITIAL_EDIT,
      OBJPROP_TEXT,
      DoubleToString(
         g_initial_capital,
         2
      )
   );

   ObjectSetString(
      0,
      O_TARGET_EDIT,
      OBJPROP_TEXT,
      DoubleToString(
         g_target_capital,
         2
      )
   );

   ObjectSetString(
      0,
      O_DAYS_EDIT,
      OBJPROP_TEXT,
      IntegerToString(
         g_simulator_mode
         ? g_sim_total_days
         : g_live_total_days
      )
   );

   UpdateDashboard();
   SavePersistentState();
}

//====================================================================
// INIT
//====================================================================

int OnInit()
{
   //---------------------------------------------------------------
   // PARAMETRI
   //---------------------------------------------------------------

   // Valori di default: vengono usati solo se non esiste
   // ancora uno stato persistente per questo account.
   g_initial_capital = InpInitialCapital;
   g_target_capital  = InpTargetCapital;
   g_live_total_days = ClampWorkingDays(InpWorkingDays);
   g_sim_total_days  = ClampWorkingDays(InpWorkingDays);

   bool state_loaded = LoadPersistentState();

   g_live_total_days = ClampWorkingDays(g_live_total_days);
   g_sim_total_days  = ClampWorkingDays(g_sim_total_days);

   g_total_days =
      g_simulator_mode
      ? g_sim_total_days
      : g_live_total_days;

   g_sim_capital = g_initial_capital;
   g_sim_day = 1;
   ResetSimulatorHistory();

   g_strategy_day=StrategyDayStart();

   //---------------------------------------------------------------
   // DATA DI PARTENZA
   //
   // Alla prima installazione (nessuno stato persistente) si parte da
   // OGGI. L'utente puo' correggerla dal campo "DATA INIZIO" nella
   // pagina LIVE; il valore viene poi salvato nello stato persistente.
   //---------------------------------------------------------------

   if(!state_loaded || g_start_date <= 0)
   {
      MqlDateTime sdt;
      TimeToStruct(TimeCurrent(),sdt);
      sdt.hour = 0; sdt.min = 0; sdt.sec = 0;
      g_start_date = StructToTime(sdt);

      SavePersistentState();
   }

   //---------------------------------------------------------------
   // PULIZIA CHART
   //---------------------------------------------------------------

   ChartSetInteger(
      0,
      CHART_SHOW_GRID,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_OHLC,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_VOLUMES,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_TRADE_LEVELS,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_ASK_LINE,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_BID_LINE,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_LAST_LINE,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_PRICE_SCALE,
      false
   );

   ChartSetInteger(
      0,
      CHART_SHOW_DATE_SCALE,
      false
   );

   //---------------------------------------------------------------
   // CREA DASHBOARD
   //---------------------------------------------------------------

   CreateDashboard();

   //---------------------------------------------------------------
   // TIMER
   //---------------------------------------------------------------

   EventSetTimer(1);

   //---------------------------------------------------------------
   // PRIMO UPDATE
   //---------------------------------------------------------------

   UpdateDashboard();

   return INIT_SUCCEEDED;
}

//====================================================================
// DEINIT
//====================================================================

void OnDeinit(
   const int reason
)
{
   SavePersistentState();
   EventKillTimer();

   DeleteDashboard();

   ChartRedraw();
}

//====================================================================
// TICK
//====================================================================

void OnTick()
{
   // Dashboard only.
   // Nessuna operazione di trading.
}

//====================================================================
// TIMER
//====================================================================

void OnTimer()
{
   UpdateDashboard();
}

//====================================================================
// CHART EVENT
//====================================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam
)
{
   //---------------------------------------------------------------
   // FINE MODIFICA CAMPO EDIT
   //---------------------------------------------------------------
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(
         sparam == O_INITIAL_EDIT ||
         sparam == O_TARGET_EDIT  ||
         sparam == O_DAYS_EDIT    ||
         sparam == O_START_EDIT   ||
         sparam == ObjName("STRAT_MAGIC")   ||
         sparam == ObjName("STRAT_LOT")     ||
         sparam == ObjName("STRAT_MAXPOS")  ||
         sparam == ObjName("STRAT_MAXTR")   ||
         sparam == ObjName("STRAT_TP")      ||
         sparam == ObjName("STRAT_SL")      ||
         sparam == ObjName("STRAT_LOSSLIM") ||
         sparam == ObjName("STRAT_LOSSES")  ||
         sparam == ObjName("STRAT_PAUSE")   ||
         sparam == ObjName("SIM_CAP_EDIT") ||
         sparam == ObjName("SIM_DAY_EDIT") ||
         sparam == ObjName("SIM_RESULT_EDIT")
      )
      {
         ReadManualInputs();

         if(ObjectFind(0,O_START_EDIT) >= 0)
            ObjectSetString(
               0,
               O_START_EDIT,
               OBJPROP_TEXT,
               TimeToString(g_start_date, TIME_DATE)
            );

         // Risincronizza i valori visualizzati con quelli accettati
         ObjectSetString(
            0,
            O_INITIAL_EDIT,
            OBJPROP_TEXT,
            DoubleToString(g_initial_capital,2)
         );

         ObjectSetString(
            0,
            O_TARGET_EDIT,
            OBJPROP_TEXT,
            DoubleToString(g_target_capital,2)
         );

         ObjectSetString(
            0,
            O_DAYS_EDIT,
            OBJPROP_TEXT,
            IntegerToString(
               g_simulator_mode
               ? g_sim_total_days
               : g_live_total_days
            )
         );

         if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
            ObjectSetString(
               0,
               ObjName("SIM_CAP_EDIT"),
               OBJPROP_TEXT,
               DoubleToString(g_sim_capital,2)
            );

         if(ObjectFind(0,ObjName("SIM_DAY_EDIT")) >= 0)
            ObjectSetString(
               0,
               ObjName("SIM_DAY_EDIT"),
               OBJPROP_TEXT,
               IntegerToString(g_sim_day)
            );

         if(ObjectFind(0,ObjName("SIM_RESULT_EDIT")) >= 0)
            ObjectSetString(
               0,
               ObjName("SIM_RESULT_EDIT"),
               OBJPROP_TEXT,
               DoubleToString(g_sim_day_result_input,2)
            );

         UpdateDashboard();
         return;
      }
   }

   //---------------------------------------------------------------
   // CLICK OGGETTO
   //---------------------------------------------------------------

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // I tre campi sono input veri: il click deve sempre lasciarli editabili.
      if(
         sparam == O_INITIAL_EDIT ||
         sparam == O_TARGET_EDIT  ||
         sparam == O_DAYS_EDIT    ||
         sparam == O_START_EDIT
      )
      {
         ObjectSetInteger(0,sparam,OBJPROP_READONLY,false);
         ObjectSetInteger(0,sparam,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,sparam,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,sparam,OBJPROP_ZORDER,100);
         ChartRedraw();
         return;
      }

      //------------------------------------------------------------
      // SCORRIMENTO TABELLE
      //------------------------------------------------------------
      if(sparam == ObjName("ORD_SCROLL_UP"))
      {
         if(g_scroll_orders > 0)
            g_scroll_orders -= DATA_ROWS_VISIBLE;
         if(g_scroll_orders < 0)
            g_scroll_orders = 0;

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("ORD_SCROLL_DOWN"))
      {
         g_scroll_orders += DATA_ROWS_VISIBLE;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("SIM_SCROLL_UP"))
      {
         g_scroll_sim -= DATA_ROWS_VISIBLE;
         if(g_scroll_sim < 0)
            g_scroll_sim = 0;

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("SIM_SCROLL_DOWN"))
      {
         g_scroll_sim += DATA_ROWS_VISIBLE;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PLAN_SCROLL_UP"))
      {
         g_scroll_plan -= DATA_ROWS_VISIBLE;
         if(g_scroll_plan < 0)
            g_scroll_plan = 0;

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PLAN_SCROLL_DOWN"))
      {
         g_scroll_plan += DATA_ROWS_VISIBLE;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("STAT_SCROLL_UP"))
      {
         g_scroll_stats -= DATA_ROWS_VISIBLE;
         if(g_scroll_stats < 0)
            g_scroll_stats = 0;

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("STAT_SCROLL_DOWN"))
      {
         g_scroll_stats += DATA_ROWS_VISIBLE;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // RISK MANAGER
      //------------------------------------------------------------
      if(sparam == ObjName("STRAT_TOGGLE"))
      {
         ReadManualInputs();
         g_strategy_enabled=!g_strategy_enabled;
         SavePersistentState();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("STRAT_SCOPE_BTN"))
      {
         ReadManualInputs();
         g_strategy_scope_account=!g_strategy_scope_account;
         SavePersistentState();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("STRAT_TARGET_MODE"))
      {
         ReadManualInputs();
         g_strategy_daily_target_auto=!g_strategy_daily_target_auto;
         SavePersistentState();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("STRAT_CLOSE_LIMIT"))
      {
         ReadManualInputs();
         g_strategy_alert_on_limit=!g_strategy_alert_on_limit;
         SavePersistentState();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // PAGINE
      //------------------------------------------------------------
      if(sparam == ObjName("PAGE_DASH"))
      {
         g_current_page = 1;
         g_simulator_mode = false;
         g_total_days = g_live_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PAGE_ORD"))
      {
         g_scroll_orders = 0;
         g_current_page = 2;
         g_simulator_mode = false;
         g_total_days = g_live_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PAGE_STRAT"))
      {
         g_current_page = 3;
         g_simulator_mode = false;
         g_total_days = g_live_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PAGE_SIM"))
      {
         g_scroll_sim = 0;
         g_current_page = 4;
         g_simulator_mode = true;
         g_total_days = g_sim_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PAGE_PLAN"))
      {
         g_scroll_plan = 0;
         g_current_page = 5;
         g_simulator_mode = true;
         g_total_days = g_sim_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      if(sparam == ObjName("PAGE_STAT"))
      {
         g_scroll_stats = 0;
         g_current_page = 6;
         g_simulator_mode = false;
         g_total_days = g_live_total_days;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         CreateDashboard();
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // MODALITA' LIVE
      //------------------------------------------------------------
      if(sparam == ObjName("MODE_LIVE"))
      {
         ReadManualInputs();
         g_simulator_mode = false;
         g_total_days = g_live_total_days;

         ObjectSetInteger(0,ObjName("MODE_LIVE"),OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // MODALITA' SIMULATORE
      //------------------------------------------------------------
      if(sparam == ObjName("MODE_SIM"))
      {
         ReadManualInputs();

         // Ogni volta che entri nel simulatore parti da una situazione
         // comprensibile: Giorno 1 e capitale iniziale.
         g_simulator_mode = true;
         g_total_days = g_sim_total_days;
         ResetSimulatorHistory();
         g_sim_day = 1;
         g_sim_capital = g_initial_capital;

         if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
            ObjectSetString(
               0,
               ObjName("SIM_CAP_EDIT"),
               OBJPROP_TEXT,
               DoubleToString(g_sim_capital,2)
            );

         if(ObjectFind(0,ObjName("SIM_DAY_EDIT")) >= 0)
            ObjectSetString(
               0,
               ObjName("SIM_DAY_EDIT"),
               OBJPROP_TEXT,
               IntegerToString(g_sim_day)
            );

         ObjectSetInteger(0,ObjName("MODE_SIM"),OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // GIORNO SIMULATO -
      //------------------------------------------------------------
      if(sparam == ObjName("SIM_DAY_MINUS"))
      {
         if(g_sim_day > 1)
            g_sim_day--;

         ObjectSetString(
            0,
            ObjName("SIM_DAY_EDIT"),
            OBJPROP_TEXT,
            IntegerToString(g_sim_day)
         );

         g_simulator_mode = true;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // GIORNO SIMULATO +
      //------------------------------------------------------------
      if(sparam == ObjName("SIM_DAY_PLUS"))
      {
         if(g_sim_day < g_total_days)
            g_sim_day++;

         ObjectSetString(
            0,
            ObjName("SIM_DAY_EDIT"),
            OBJPROP_TEXT,
            IntegerToString(g_sim_day)
         );

         g_simulator_mode = true;
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // REGISTRA RISULTATO DEL GIORNO
      //------------------------------------------------------------
      if(sparam == ObjName("SIM_RECORD"))
      {
         ReadManualInputs();
         g_simulator_mode = true;

         int remaining_days = g_total_days - g_sim_day + 1;
         if(remaining_days < 1) remaining_days = 1;

         double start_cap = g_sim_capital;
         double factor = 1.0;

         if(start_cap > 0 &&
            g_target_capital > start_cap)
         {
            factor =
               MathPow(
                  g_target_capital / start_cap,
                  1.0 / (double)remaining_days
               );
         }

         double required_end = start_cap * factor;
         if(g_sim_day == g_total_days)
            required_end = g_target_capital;

         double close_cap =
            start_cap + g_sim_day_result_input;

         if(close_cap < 0)
            close_cap = 0;

         int d = g_sim_day;

         if(d >= 1 && d < 367)
         {
            g_sim_open[d] = start_cap;
            g_sim_required_end[d] = required_end;
            g_sim_result_eur[d] = g_sim_day_result_input;
            g_sim_result_pct[d] =
               (start_cap > 0
                ? (g_sim_day_result_input / start_cap) * 100.0
                : 0.0);
            g_sim_close[d] = close_cap;
            g_sim_delta_vs_plan[d] =
               close_cap - required_end;
            g_sim_recorded[d] = true;
         }

         g_sim_capital = close_cap;
         g_sim_day_result_input = 0.0;

         if(g_sim_day < g_total_days)
            g_sim_day++;

         if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_CAP_EDIT"),OBJPROP_TEXT,
                            DoubleToString(g_sim_capital,2));
         if(ObjectFind(0,ObjName("SIM_DAY_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_DAY_EDIT"),OBJPROP_TEXT,
                            IntegerToString(g_sim_day));
         if(ObjectFind(0,ObjName("SIM_RESULT_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_RESULT_EDIT"),OBJPROP_TEXT,"0.00");

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // AZZERA SIMULAZIONE
      //------------------------------------------------------------
      if(sparam == ObjName("SIM_CLEAR"))
      {
         ResetSimulatorHistory();
         g_simulator_mode = true;
         g_sim_day = 1;
         g_sim_capital = g_initial_capital;

         if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_CAP_EDIT"),OBJPROP_TEXT,
                            DoubleToString(g_sim_capital,2));
         if(ObjectFind(0,ObjName("SIM_DAY_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_DAY_EDIT"),OBJPROP_TEXT,"1");
         if(ObjectFind(0,ObjName("SIM_RESULT_EDIT")) >= 0)
            ObjectSetString(0,ObjName("SIM_RESULT_EDIT"),OBJPROP_TEXT,"0.00");

         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         UpdateDashboard();
         return;
      }

      //------------------------------------------------------------
      // RICALCOLA
      //------------------------------------------------------------

      if(sparam == O_CALCULATE)
      {
         double old_initial = g_initial_capital;

         ReadManualInputs();

         // Nel simulatore, al Giorno 1, cambiare il capitale iniziale
         // significa ripartire da quel nuovo capitale.
         if(g_simulator_mode && g_sim_day == 1 && g_initial_capital != old_initial)
         {
            g_sim_capital = g_initial_capital;

            if(ObjectFind(0,ObjName("SIM_CAP_EDIT")) >= 0)
               ObjectSetString(
                  0,
                  ObjName("SIM_CAP_EDIT"),
                  OBJPROP_TEXT,
                  DoubleToString(g_sim_capital,2)
               );
         }

         UpdateDashboard();

         ObjectSetInteger(
            0,
            O_CALCULATE,
            OBJPROP_STATE,
            false
         );

         return;
      }

      //------------------------------------------------------------
      // RESET
      //------------------------------------------------------------

      if(sparam == O_RESET)
      {
         ResetInputs();

         ObjectSetInteger(
            0,
            O_RESET,
            OBJPROP_STATE,
            false
         );

         return;
      }

      //------------------------------------------------------------
      // PLUS
      //------------------------------------------------------------

      if(sparam == O_PLUS)
      {
         g_total_days =
            g_simulator_mode
            ? g_sim_total_days
            : g_live_total_days;

         g_total_days = ClampWorkingDays(g_total_days + 1);

         if(g_simulator_mode)
            g_sim_total_days = g_total_days;
         else
            g_live_total_days = g_total_days;

         ObjectSetString(
            0,
            O_DAYS_EDIT,
            OBJPROP_TEXT,
            IntegerToString(g_total_days)
         );

         UpdateDashboard();

         ObjectSetInteger(
            0,
            O_PLUS,
            OBJPROP_STATE,
            false
         );

         return;
      }

      //------------------------------------------------------------
      // MINUS
      //------------------------------------------------------------

      if(sparam == O_MINUS)
      {
         g_total_days =
            g_simulator_mode
            ? g_sim_total_days
            : g_live_total_days;

         g_total_days = ClampWorkingDays(g_total_days - 1);

         if(g_simulator_mode)
            g_sim_total_days = g_total_days;
         else
            g_live_total_days = g_total_days;

         ObjectSetString(
            0,
            O_DAYS_EDIT,
            OBJPROP_TEXT,
            IntegerToString(g_total_days)
         );

         UpdateDashboard();

         ObjectSetInteger(
            0,
            O_MINUS,
            OBJPROP_STATE,
            false
         );

         return;
      }
   }

   //---------------------------------------------------------------
   // CHART RIDIMENSIONATO
   //---------------------------------------------------------------

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      int W = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      int H = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

      // Confronto con la dimensione REALE del grafico all'ultimo rebuild
      // (non con g_width/g_height, che sono gia' clampati ai minimi).
      bool size_changed =
         MathAbs(W - g_chart_px_w) > 20 ||
         MathAbs(H - g_chart_px_h) > 20;

      // Debounce: CHART_CHANGE scatta di continuo durante drag/zoom.
      static uint last_rebuild_ms = 0;
      uint now_ms = GetTickCount();

      if(size_changed && (now_ms - last_rebuild_ms) > 400)
      {
         last_rebuild_ms = now_ms;
         CreateDashboard();
         UpdateDashboard();
      }
   }
}

//+------------------------------------------------------------------+

//====================================================================
// EVENTI TRADE
//
// Il monitor NON opera: qui ci limitiamo a marcare come "da ricalcolare"
// le serie W/L, la pausa e la cache delle statistiche. Il ricalcolo
// effettivo (lettura storico in ordine cronologico) avviene in
// StrategyRefreshState / GetSymbolStatsCached, senza logica incrementale.
//====================================================================
void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)
      return;

   g_strategy_force_refresh = true;
   g_stats_cache_time       = 0;

   StrategyRefreshState();
}
