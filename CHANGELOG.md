# Changelog

Tutte le modifiche rilevanti all'EA **Trading Target Manager**
(`Target To Win/Target_For_win_V3_UI_REDESIGN_V33_STATS_GROSS_SWAP_FEES_NET.mq5`).

Formato basato su [Keep a Changelog](https://keepachangelog.com/it/1.1.0/).
Versionamento **X.Y.Z**:

- **X** – riscrittura o cambio di architettura
- **Y** – nuove funzionalità / modifiche visibili di comportamento
- **Z** – correzioni e ritocchi

La versione è definita in `#define APP_VERSION` nel sorgente ed è mostrata
in alto a destra nell'header della dashboard. Ad ogni rilascio si crea il
tag git corrispondente (`vX.Y.Z`).

---

## [Unreleased]

_(niente per ora)_

---

## [3.1.2] - 2026-09-04

Bug visivi trovati testando la 3.1.1 su grafico reale.

### Corretto
- Pulsanti di navigazione **RISK MONITOR** e **SIMULATORE**: il testo veniva
  tagliato ai due lati perché il pulsante era troppo stretto per il font
  ingrandito in 3.1.1. Allargati (e riallineati gli altri pulsanti di
  conseguenza).
- Campo **DATA INIZIO**: l'etichetta e il testo di aiuto a fianco si
  sovrapponevano. Il testo di aiuto è stato spostato sulla riga del campo
  di input (a destra della casella), non più accanto all'etichetta.
- Barra di stato: font ridotto di un punto (12→11) per ridurre il rischio
  di testo troncato sui messaggi più lunghi.

### Nota
- Il file sorgente è stato rinominato da `..._V33_...` a `..._V34_...`
  (contenuto identico, solo il nome).

---

## [3.1.1] - 2026-09-04

### Modificato
- **Leggibilità**: nessuna etichetta della dashboard sotto i 9 px (prima
  molte erano a 7-8). Sottotitoli e didascalie delle card ingranditi.
- Tabelle ORDINI, SIMULATORE, STATISTICHE, PIANO: righe più alte, colonne
  più distanziate, celle numeriche in carattere monospazio (Consolas) per
  un allineamento pulito.
- Dimensione minima della dashboard portata a 1280×1320 px così le tabelle
  larghe (ORDINI in particolare) rientrano sempre nel pannello.

---

## [3.1.0] - 2026-09-04

Prima versione tracciata. Raccoglie la review completa del sorgente e le
correzioni concordate.

### Aggiunto
- Campo **DATA INIZIO** editabile nella pagina LIVE (`AAAA.MM.GG`): definisce
  il Giorno 1 del percorso; default = data di caricamento; salvato nello stato
  persistente.
- **Numero di versione** mostrato nell'header (`v3.1.0`) e file `CHANGELOG.md`.
- **Avviso su limite**: quando scatta il lock giornaliero, se attivo, viene
  emesso un `Alert()` MT5 (una sola volta al giorno).
- Parsing numerico tollerante nei campi UI: accetta virgola o punto come
  separatore decimale e ignora i separatori delle migliaia
  (`1.000,50` → `1000.50`).

### Modificato
- Il **"Risk Manager" è ora "RISK MONITOR"**: solo visualizzazione, non invia
  né chiude ordini. Rinominati titoli, pulsanti e stati; il pannello
  "Money Management" è ora "Calcolatore TP/SL (riferimento manuale)".
- **Statistiche per simbolo**: Win/Loss calcolati sul **netto reale per
  posizione** (lordo + swap + tutte le commissioni di ingresso e uscita).
  `TRADE` conta le posizioni chiuse (le chiusure parziali contano 1).
  Le colonne economiche restano invariate e riconciliano con il conto.
- **Serie vittorie/perdite consecutive** e **finestra di pausa** ricalcolate
  dallo storico dei deal chiusi di oggi in ordine cronologico; rimossa la
  logica incrementale in `OnTradeTransaction`.
- **Prestazioni**: statistiche in cache (aggiornate al massimo ogni 10 s o
  subito dopo un evento trade); lo stato persistente viene scritto solo
  quando un valore cambia davvero.
- **Limite giorni lavorativi** fissato a 260, applicato ovunque (pulsanti,
  input manuale, stato persistente, avvio).
- Tabella **ORDINI APERTI** portata a 25 righe visibili (prima 20 con
  scorrimento a passi di 25: alcune posizioni non erano mostrate).
- Rebuild della dashboard al ridimensionamento del grafico solo su reale
  cambio di dimensione, con debounce (niente sfarfallio su zoom/scroll).
- `WorkingDaysBetween` avanza di un giorno di calendario con
  ri-normalizzazione a mezzanotte (robusto all'ora legale).
- Magic number gestito come intero a 64 bit nella UI.

### Rimosso
- Recupero automatico della data di inizio dal primo deal dello storico
  (mandava la dashboard in "TEMPO TERMINATO" sui conti con storico lungo).
- Funzione morta `FindEarliestAccountDealTime()`.
- `#property strict` (residuo MQL4).

### Corretto
- `if(ObjectFind(...))` duplicati nella gestione dei campi del simulatore.
- Coerenza della proprietà `OBJPROP_HIDDEN` sui campi di input.
- Target giornaliero del monitor: i giorni completati non dipendono più da
  un valore potenzialmente non aggiornato (`g_days_elapsed`).

---

## [3.0.0] - pre-review

Versione di partenza (commit `f02eb28`): dashboard a 6 pagine
(LIVE, ORDINI, RISK MANAGER, SIMULATORE, PIANO, STATISTICHE).
