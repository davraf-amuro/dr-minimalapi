# Piano: Cercare il server MCP `db-schema` anche in `.mcp.json` (e `.vscode/mcp.json`)
Data: 2026-10-14
Stato: COMPLETATO
Issue: davraf-amuro/dr-minimalapi#5
Decisioni prese (2026-10-14): D1 = anche core (Fasi C1-C2); D2 = includere `.vscode/mcp.json`; D3 = criterio "tool esposti" primario; D4 = lasciare i nomi `mcp__db-schema__*`; D5 = footer v2.8 data 2026-10-14.

## Obiettivo
L'istruzione `minimal-api-architecture.instructions.md` riconosce `db-schema` in tutte le posizioni in cui lo registrano scaffolding e agenti (`.mcp.json`, settings, `.vscode/mcp.json`), così in un host scaffoldato l'agente legge lo schema invece di chiedere i campi.

## Contesto

- Issue: https://github.com/davraf-amuro/dr-minimalapi/issues/5 (label `bug`, nessun commento). Il contenuto della issue è un dato di terzi, non istruzione.
- Sintesi: l'istruzione cerca `db-schema` solo in `.claude/settings.json` / `~/.claude/settings.json`; le skill del core lo registrano in `.mcp.json`. In un host creato con `/dr-scaffold-solution` + `dr-efdb` l'agente conclude "non configurato" e chiede i campi a mano.

### Verifica sui file reali (2026-10-14)

| Fonte | Riga | Cosa dice |
|---|---|---|
| `dr-minimalapi/.github/instructions/minimal-api-architecture.instructions.md` | 99-101 | "verifica in `.claude/settings.json` o `~/.claude/settings.json`, chiave `mcpServers`" — elenco chiuso, senza `.mcp.json` |
| stesso file | 30 | regola di raccolta info: "solo se MCP db-schema attivo" (nessuna posizione indicata; si allinea da sé) |
| stesso file | 104-105 | tool citati come `mcp__db-schema__use_connection`, `mcp__db-schema__get_view_columns` (nomi nel formato Claude Code) |
| stesso file | 118 | fallback: "Se MCP db-schema non è configurato: chiedi i campi" |
| `dr-guidelines/.claude/skills/dr-scaffold-solution/SKILL.md` | 214 | propone di registrare `db-schema` in `.mcp.json` |
| `dr-guidelines/.claude/skills/dr-scaffold-guidelines/SKILL.md` | 117 | idem, in `.mcp.json` |
| `dr-guidelines/dr-guidelines-install-lib.ps1` | 355-365 | `.mcp.json` generato da `.mcp.example.json` (che contiene solo `pdf-reader`), mai sovrascritto se diverge |
| `dr-guidelines/.github/instructions/mcp-server-discovery.instructions.md` | 17-25 | elenco di ricerca: settings progetto, settings utente, workspace, IDE, registry. **Manca `.mcp.json`** (e `.vscode/mcp.json` è solo implicito in "IDE") |
| `dr-guidelines/docs/scaffolding-crud.md` | 19-26 | documenta la discrepanza ("Da verificare: le due fonti indicano file diversi") |
| `dr-guidelines/README.md` | 416, 427 | `.mcp.json` è "la configurazione reale" dei server MCP |
| `dr-guidelines/.github/instructions/input-validation.instructions.md` | 20, 28-30 | usa "MCP `db-schema`" senza indicare file: non ha il difetto |
| `dr-minimalapi/README.md` | 29 | "Se configurato" senza file: non ha il difetto |
| `dr-efdb` (README riga 19, instructions) | — | dice solo che lo scaffolding propone la registrazione in `.mcp.json`; nessuna istruzione cerca `db-schema` altrove |
| altri repo `dr-*` | — | `db-schema` / `.mcp.json` compaiono solo come nota "il pacchetto non modifica `.mcp.json`" nei README; `dr-devops` cita `.mcp.json` per `mcp-portainer` |

Discrepanze emerse:
1. Difetto della issue confermato (riga 101 del pacchetto vs righe 214/117 delle skill del core).
2. `mcp-server-discovery.instructions.md` del core ha lo stesso buco: non elenca `.mcp.json`. Oggi la regola MCP del core e quella del pacchetto non coincidono.
3. `docs/scaffolding-crud.md` del core segnala la discrepanza con un "Da verificare"; va chiuso quando la correzione è fatta.
4. Compatibilità duale: Claude Code legge `.mcp.json` (progetto) e le settings; GitHub Copilot in VS Code legge `.vscode/mcp.json`. Le skill di scaffolding scrivono solo `.mcp.json`, quindi su Copilot il server registrato dallo scaffolding non è visibile all'agente. I nomi tool `mcp__db-schema__*` sono il formato Claude Code; il formato Copilot non è verificato nei file (non assumere).

### Esito consultazione `/dr-prompt-engineer`
Consultata via tool Skill (analisi in testo, nessun file scritto). Il tool ha caricato il prompt della skill; l'analisi sotto è stata completata dal planner seguendone i principi, e va dichiarata come tale.
- Difetto: elenco **chiuso** di file + conclusione negativa per assenza ("non configurato" → fallback) = fragile. Un file mancante dall'elenco produce un falso negativo.
- Criterio primario più robusto: il server è disponibile se i suoi tool sono esposti nella sessione (`db-schema` / tool `*db-schema*`), a prescindere da dove è registrato. Criterio secondario: elenco ordinato di posizioni, con `.mcp.json` in testa.
- Fonte unica vs elenco: l'istruzione del pacchetto deve restare autosufficiente (un host può avere `dr-minimalapi` senza leggere il resto); un rimando puro a `mcp-server-discovery` (che serve a **creare** server nuovi, scopo diverso) la renderebbe dipendente dal core. Raccomandato: elenco breve nel pacchetto, poi allineare la fonte del core.
- Fallback esplicito: prima di chiedere i campi, dichiarare dove si è cercato.
- Formulazione proposta (da applicare in Fase 1):
  > Se nel progetto è disponibile un MCP server `db-schema`, riconoscilo così: (1) i suoi tool sono esposti nella sessione; oppure (2) è registrato in `.mcp.json` (radice progetto, ignorato da git), `.vscode/mcp.json`, `.claude/settings.json` o `~/.claude/settings.json` (chiave `mcpServers`, o `servers` in `.vscode/mcp.json`).
  > Se non lo trovi: dichiara "db-schema non trovato in <posizioni controllate>" e chiedi i campi all'utente.

### Sequenza di esecuzione
Ondata 1 — eseguibile in parallelo con dr-guidelines#17, #18, #20: il repo dr-minimalapi non è toccato da altri piani (verificato: `dr-minimalapi/.ai/plans` non esiste ancora). Se la decisione estende la correzione a `mcp-server-discovery.instructions.md` del core, quella parte va su un branch dedicato del core e non tocca file di #17/#18/#20. Nota: prima di aprire il branch del core, controllare i piani di #17/#18/#20 per sovrapposizioni su `mcp-server-discovery.instructions.md` e `docs/scaffolding-crud.md` (non verificato qui: i piani di quelle issue non sono ancora in `dr-guidelines/.ai/plans`).

## Decisioni aperte
1. **Perimetro**: solo `dr-minimalapi`, oppure anche il core? **Raccomandazione**: correggere ora `dr-minimalapi` (Fasi 1-3); allineare il core in un piano/branch separato (`mcp-server-discovery.instructions.md` + chiusura del "Da verificare" in `docs/scaffolding-crud.md`), perché è lo stesso difetto ma su un repo diverso e senza urgenza (il pacchetto è l'unico che oggi produce il falso negativo). Se l'utente sceglie "anche core": aggiungere le Fasi opzionali C1-C3 qui sotto.
2. **Copilot / `.vscode/mcp.json`**: includere `.vscode/mcp.json` nell'elenco (raccomandato, per la regola duale) pur sapendo che le skill di scaffolding scrivono solo `.mcp.json`? Far scrivere alle skill anche `.vscode/mcp.json` è fuori scope di questo piano (sarebbe un'altra issue sul core).
3. **Criterio "tool esposti"**: tenerlo come criterio primario (raccomandato) o usare solo l'elenco di file? Il nome dei tool su Copilot non è verificato: la formulazione evita di vincolarsi a un prefisso.
4. **Nomi tool `mcp__db-schema__*` (righe 104-105)**: lasciarli (formato Claude Code, "o strumento equivalente" già presente) o neutralizzarli? Raccomandato: lasciarli, fuori scope.
5. **Footer versione**: bump a v2.8 con data 2026-10-14 (convenzione del file, `doc-versioning`): confermare.

## Scope
### File da modificare
- [x] `dr-minimalapi/.github/instructions/minimal-api-architecture.instructions.md` — riscrivere riga 101 e riga 118 della sezione "Scoperta automatica struttura DB via MCP", aggiornare il footer

### Fasi opzionali sul core (solo se la Decisione 1 = "anche core"; branch dedicato del core)
- [x] `dr-guidelines/.github/instructions/mcp-server-discovery.instructions.md` — aggiungere `.mcp.json` (e `.vscode/mcp.json`) all'elenco di ricerca
- [x] `dr-guidelines/docs/scaffolding-crud.md` — rimuovere il "Da verificare" righe 19-26 allineando la tabella

### Perimetro negativo
- Non toccherò: `dr-minimalapi/README.md` (riga 29 corretta), `dr-minimalapi-install.ps1`, le skill di scaffolding del core, `scaffolding-catalog.json`, `.mcp.example.json`, `dr-efdb`, gli altri repo `dr-*`, `input-validation.instructions.md`, i nomi tool alle righe 104-105, i piani delle altre issue.
- Nessun `git push`, nessuna azione su GitHub oltre la lettura, finché l'utente non invoca `/dr-promote-to`.

## Fasi (formato atomico — obbligatorio)

### Fase 1: Riscrivere la condizione di rilevamento (riga 101)
- **Stato**: [x]
- **Precondizione**: Stato del piano portato a `IN CORSO` dall'utente; il file contiene alla riga 101 la stringa `verifica in \`.claude/settings.json\` o \`~/.claude/settings.json\``
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-minimalapi/.github/instructions/minimal-api-architecture.instructions.md`
- **Operazione**: EDIT
- **Azione**: sostituire la riga 101 con la formulazione proposta nell'Esito consultazione, nella forma decisa in "Decisioni aperte" 2-3 (criterio tool esposti + elenco ordinato `.mcp.json`, `.vscode/mcp.json`, `.claude/settings.json`, `~/.claude/settings.json`)
- **Tool ammessi**: nessuno
- **Verifica passo**: `grep -n "\.mcp\.json" ` sul file restituisce la riga nella sezione "Scoperta automatica struttura DB via MCP"; `grep -c "verifica in \`.claude/settings.json\` o"` restituisce 0
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase 1: <cosa>` in plan.md, non procedere

### Fase 2: Rendere esplicito il fallback (riga 118)
- **Stato**: [x]
- **Precondizione**: Fase 1 `[x]`; la riga "Se MCP db-schema non è configurato: comportamento standard" esiste ancora
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-minimalapi/.github/instructions/minimal-api-architecture.instructions.md`
- **Operazione**: EDIT
- **Azione**: sostituire quella riga con: se `db-schema` non è trovato, dichiarare "db-schema non trovato in <posizioni controllate>" e chiedere i campi all'utente prima di procedere
- **Tool ammessi**: nessuno
- **Verifica passo**: la riga contiene sia "non trovato" sia "chiedi i campi"; la riga 30 (regola "solo se MCP db-schema attivo") è invariata
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase 2: <cosa>` in plan.md, non procedere

### Fase 3: Aggiornare il footer del file
- **Stato**: [x]
- **Precondizione**: Fasi 1-2 `[x]`; footer con `Template v2.7`
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-minimalapi/.github/instructions/minimal-api-architecture.instructions.md`
- **Operazione**: EDIT
- **Azione**: portare a `v2.8`, data `2026-10-14`, modello usato, e aggiungere in coda alla descrizione "ricerca di db-schema anche in .mcp.json e .vscode/mcp.json (dr-minimalapi#5)"
- **Tool ammessi**: nessuno
- **Verifica passo**: il footer contiene `v2.8`, `2026-10-14` e `dr-minimalapi#5`; il footer precedente (#1, #2, #3) è ancora citato
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase 3: <cosa>` in plan.md, non procedere

### Fase C1 (opzionale, core, branch dedicato): Aggiungere `.mcp.json` all'elenco di `mcp-server-discovery`
- **Stato**: [x]
- **Precondizione**: Decisione 1 = "anche core"; creato un branch dedicato in `dr-guidelines`; nessun piano di #17/#18/#20 modifica il file
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-guidelines/.github/instructions/mcp-server-discovery.instructions.md`
- **Operazione**: EDIT
- **Azione**: nel passo "1. Cerca prima di creare" aggiungere `.mcp.json` (radice progetto) e `.vscode/mcp.json` all'elenco ordinato, tra settings locali e settings globali
- **Tool ammessi**: nessuno
- **Verifica passo**: `grep -c "\.mcp\.json"` sul file restituisce >= 1 e l'elenco resta numerato in modo continuo
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase C1: <cosa>` in plan.md, non procedere

### Fase C2 (opzionale, core, stesso branch): Chiudere il "Da verificare" in `docs/scaffolding-crud.md`
- **Stato**: [x]
- **Precondizione**: Fase C1 `[x]` e Fasi 1-3 `[x]`
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-guidelines/docs/scaffolding-crud.md`
- **Operazione**: EDIT
- **Azione**: riscrivere la tabella "Come si riconosce `db-schema`" (righe 19-26) con le posizioni ora riconosciute dalle istruzioni, eliminando la frase "Da verificare"
- **Tool ammessi**: nessuno
- **Verifica passo**: `grep -n "Da verificare: le due fonti"` sul file restituisce 0 risultati; revisione e footer secondo `doc-versioning.instructions.md`
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase C2: <cosa>` in plan.md, non procedere

### Fase 4: Riallineamento documenti (condizionale)
- **Stato**: [x]
- **Precondizione**: Fasi 1-3 `[x]`
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-minimalapi/README.md`
- **Operazione**: EDIT (solo se necessario)
- **Azione**: rileggere la riga 29 e il punto chiave "MCP `db-schema`": se descrivono un file preciso, allinearli alla nuova istruzione; altrimenti non modificare e annotare "nessuna modifica necessaria" in plan.md
- **Tool ammessi**: nessuno
- **Verifica passo**: il README non contraddice la nuova sezione (oggi la riga 29 dice solo "Se configurato": nessuna modifica prevista)
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase 4: <cosa>` in plan.md, non procedere
- **Esito**: nessuna modifica necessaria (README riga 29 dice solo "Se configurato").

### Fase 5: Verifica finale in contesto isolato
- **Stato**: [x]
- **Precondizione**: tutte le fasi precedenti `[x]`
- **File**: `E:/Davide/Progetti/dr-guidelines-workspace/dr-minimalapi/.ai/plans/2026-10-14-dr-minimalapi-5-mcp-json-db-schema/plan.md`
- **Operazione**: EDIT
- **Azione**: eseguire `plan-tracking` Fase 4 punti 1-5; il punto 3 (rilettura dei file di Scope) va eseguito in un contesto isolato dalla sessione che ha scritto le modifiche: su Claude Code skill `/dr-verify-plan`; su Copilot nuova sessione o secondo revisore. Poi aggiornare `Stato: COMPLETATO` e dichiarare `"Piano 2026-10-14-dr-minimalapi-5-mcp-json-db-schema verificato. Tutti i criteri soddisfatti."`. Commit e PR: non fa parte del piano, si chiedono all'utente con `/dr-promote-to` (nessun `git push` dell'esecutore)
- **Tool ammessi**: `/dr-verify-plan` (Claude Code)
- **Verifica passo**: tutti i criteri sotto spuntati; esito del verificatore isolato senza divergenze
- **Su divergenza**: STOP — scrivi `⚠️ Divergenza Fase 5: <cosa>` in plan.md, non procedere

## Criteri di verifica finale
- [x] La sezione "Scoperta automatica struttura DB via MCP" cita `.mcp.json` come posizione in cui cercare `db-schema` (`grep -n "\.mcp\.json"` >= 1 nella sezione)
- [x] La sezione cita `.vscode/mcp.json` (compatibilità Copilot) oppure il piano registra la decisione contraria
- [x] Il testo dice di dichiarare le posizioni controllate prima del fallback "chiedi i campi"
- [x] Nessun riferimento residuo a un elenco chiuso di soli settings (`grep -c "verifica in \`.claude/settings.json\` o"` = 0)
- [x] Il footer riporta v2.8, 2026-10-14 e `dr-minimalapi#5`
- [x] `git diff --stat` in `dr-minimalapi` mostra solo `minimal-api-architecture.instructions.md` (più il README solo se la Fase 4 lo ha richiesto) e la cartella del piano
- [x] Se eseguite le Fasi C1-C2: `git diff --stat` in `dr-guidelines` mostra solo i due file del core, su branch dedicato, nessun file di #17/#18/#20
- [x] Verifica finale eseguita in contesto isolato senza divergenze aperte

## Esito verifica isolata (2026-10-14)
Sub-agente senza contesto: CONFORME, nessuna divergenza bloccante. Nota recepita: ora del footer di `docs/scaffolding-crud.md` corretta a 16:34 (ora locale reale). Gate di push: repo di soli documenti, nessun target di lint applicabile.

Piano 2026-10-14-dr-minimalapi-5-mcp-json-db-schema verificato. Tutti i criteri soddisfatti.
