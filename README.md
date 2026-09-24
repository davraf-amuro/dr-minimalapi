# dr-minimalapi

Pacchetto di linee guida dr-* per i progetti ASP.NET Core Minimal API su .NET 10: architettura, endpoint, accesso ai dati e documentazione.

## 🧩 Cosa contiene

| File | Tipo | A cosa serve |
|------|------|--------------|
| `.github/instructions/minimal-api-architecture.instructions.md` | Istruzione | Regole obbligatorie per le Minimal API .NET 10: stack, divieti, struttura delle cartelle e 13 regole core con pattern di codice copiabili. Prima di creare file impone una raccolta informazioni in un unico messaggio (entità e campi, nome progetto, Serilog, autenticazione, connessione DB) e si ferma se il nome progetto non è confermato. |
| `.github/prompts/card-minimal-api.prompt.md` | Prompt | Genera o aggiorna `docs/card-<nome_progetto>.md`, la scheda riassuntiva del progetto: identificazione, stack, endpoint group, dipendenze, database, servizi esterni, hosting. Ricava i dati da `.csproj`, `appsettings*.json`, `launchSettings.json`, `Program.cs`, `Endpoints/`, `Services/`, `Infrastructure/` e `Dto/`, senza inventare e senza scrivere valori sensibili. |
| `.github/prompts/endpoints-analyzer.prompt.md` | Prompt | Genera `docs/endpoint-<group_name>.md` per ogni `MapGroup`, sovrascrivendo il file se esiste. Ogni documento ha la tabella degli endpoint (metodo, URL, descrizione, parametri, risposta) e i diagrammi di flusso Endpoint → Validator → Service → Provider → Entity → DTO → Response, con rimando ai file `.http`. |

Punti chiave di `minimal-api-architecture.instructions.md`:

| Tema | Cosa impone |
|------|-------------|
| Stack | .NET 10 Minimal API, `Tinyhelpers.AspNetCore`, Scalar per la documentazione, `Asp.Versioning.Mvc.ApiExplorer`. Serilog opzionale, da chiedere. |
| Vietato | MVC Controllers, Swagger UI, IRepository, AutoMapper, MediatR. `AddJwtBearer` per utenti umani salvo richiesta esplicita e motivata. |
| Struttura | `src/<project>/` con `Dto/`, `Endpoints/`, `Infrastructure/Provider/`, `Services/`, `Transformers/`, `Validators/`, `Properties/`; poi `test/` e `docs/`. |
| Endpoint | Solo extension methods in `Endpoints/*Mapping.cs`. URL `api/v{version:apiVersion}/{gruppo}/{comando?}`, versioning con `UrlSegmentApiVersionReader`. |
| Metadati OpenAPI | Ogni endpoint ha `WithSummary`, `WithDescription`, `WithTags`, `WithName("<Verbo><Risorsa>")` e un `Produces` per ogni `TypedResults` restituito. |
| Layer | Handler → `Services/<Entity>Service.cs` → provider. L'handler inietta solo il Service, mai il provider né le `Projection`. |
| GET list | Filtro `<Entity>Filter` con `ToExpression()` e validator dedicato. DTO completo più `<Entity>SummaryDto`, ognuno nel proprio file e con `Projection` EF-traducibile. `ProblemDetails` 404 se il risultato è vuoto. |
| EF Core | `NoTracking` di default, `AsTracking()` su update e delete. Nessun metodo extension dentro una `Projection`: provoca valutazione lato client. |
| Commenti | `///` su ogni metodo `public` di provider, service, handler e validator, più un commento inline su ogni operazione DB. |
| Progetto nuovo | `HealthMapping.cs` con `/health` e `GET /api/v1/status`, `launchSettings.json`, `appsettings.local.json` ignorato da git, `.vscode/launch.json` e `tasks.json` di tipo `coreclr`, un file `.http` per gli endpoint nuovi. |
| Autenticazione | Solo se richiesta. Lo schema dipende dai client: Identity con cookie `HttpOnly`, Identity con `AddBearerToken`, oppure API Key con `SimpleAuthenticationTools` per il solo servizio-a-servizio. |
| Container | Con autenticazione: portachiavi Data Protection persistito e condiviso (`PersistKeysToDbContext`) e `UseForwardedHeaders` come primo middleware. |
| MCP `db-schema` | Se configurato, l'agente legge colonne e tipi dalla tabella invece di chiedere i campi, e genera subito il validator. |

## 🔗 Dipendenze e domini

- Dipende da: `dr-dotnet-backend` (installato in automatico se manca dal manifest: comportamento dell'installer, non ancora provato sul campo).
- Richiesto da: nessun pacchetto.
- Dominio del catalogo: nessun dominio lo elenca direttamente; il dominio `dotnet-backend` elenca solo `dr-dotnet-backend`. `appliesTo`: `dotnet`.
- Tipologia che lo suggerisce: `minimal-api` — Minimal API (.NET 10), insieme a `dr-dotnet-backend`; `dr-efdb` è opzionale. Template `dotnet new web`, guida di scaffolding `docs/scaffolding-minimal-api.md` nel core.
- `-Update` non si propaga alle dipendenze: aggiornare solo questo pacchetto lascia `dr-dotnet-backend` com'è. `/dr-get-latest` aggiorna anche la dipendenza, che ha una propria voce nel manifest.
- La skill `/dr-audit-api` di `dr-dotnet-backend` usa questa istruzione nella fase di conformità quando trova `Endpoints/*.cs`.

File di altri pacchetti citati dall'istruzione. Non vengono installati in automatico:

| File citato | Pacchetto che lo porta |
|-------------|------------------------|
| `sensitive-data`, `logging` (fonte unica della configurazione Serilog), `code-organization`, `input-validation` (`.instructions.md`); skill `dr-CreateLaunchProfiles` | `dr-guidelines` (core) |
| `database-startup-resilience.instructions.md` | `dr-efdb` |
| `frontend-organization.instructions.md` | `dr-fe` |
| `docker-swarm-compose.instructions.md` | `dr-devops` |

## 🚀 Come si installa

Di solito non serve installarlo a mano. Per una soluzione nuova segui la guida del core [Creare una soluzione da zero](https://github.com/davraf-amuro/dr-guidelines/blob/main/docs/guida-nuova-soluzione.md): `/dr-scaffold` installa da solo i pacchetti giusti. Il flusso completo non è ancora stato provato sul campo.

A mano. Conviene installare prima il core `dr-guidelines`, che porta `CLAUDE.md`, configurazione e skill; l'installer però non lo impone. Prerequisiti: PowerShell 7, git, `gh auth status` autenticato (l'installer si scarica con `gh api`; i repo sono Public dal 2026-09-21). L'installer clona il repo da `github.com` con `git clone --depth 1`: con i repo Public non servono credenziali; su un repo Private anche git deve poterlo leggere (`gh auth setup-git`).

Lancia i comandi dalla **root del repository host**: l'installer usa la cartella corrente come destinazione e non avvisa se sbagli cartella.

Via core, un solo installer:

```powershell
Set-Location <root-del-progetto-host>
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-guidelines/contents/dr-guidelines-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String))) -Package dr-minimalapi
```

Oppure con l'installer del pacchetto:

```powershell
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-minimalapi/contents/dr-minimalapi-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String)))
```

Nota: la forma breve `irm https://raw.githubusercontent.com/... | iex` funziona solo a repo Public; oggi risponde 404.

Se `dr-dotnet-backend` manca dal manifest, l'installer lo installa prima di `dr-minimalapi` e lo segnala con questa riga:

```text
Dipendenza mancante: dr-dotnet-backend -> installazione automatica
```

## 📦 Cosa finisce nel progetto host

| Percorso nel progetto host | Contenuto |
|----------------------------|-----------|
| `.github/instructions/minimal-api-architecture.instructions.md` | Regole di architettura Minimal API |
| `.github/prompts/card-minimal-api.prompt.md` | Prompt per la scheda del progetto |
| `.github/prompts/endpoints-analyzer.prompt.md` | Prompt per la documentazione degli endpoint |
| `.ai/dr-guidelines-packages.json` | Voce `dr-minimalapi` con data (`installedAt`) e commit installato (`commit`) |

Nessuna modifica a `CLAUDE.md` né ai file di configurazione del core (`.editorconfig`, `.gitignore`, `.gitattributes`, `.claude/settings.json`, `.mcp.json`).

Non vengono copiati `README.md`, `LICENSE`, `.github/ISSUE_TEMPLATE/` e l'installer.

Senza `-Update` un file già presente resta com'è e l'installer stampa `[SKIP]`.

Se la dipendenza viene installata in automatico, arrivano anche i file di `dr-dotnet-backend`: vedi la sezione "Cosa finisce nel progetto host" del README di [dr-dotnet-backend](https://github.com/davraf-amuro/dr-dotnet-backend).

## 🔄 Aggiornare

Tutti i pacchetti del progetto: `/dr-get-latest`.

Solo questo pacchetto: stesso comando dell'installer del pacchetto, con `-Update` in coda:

```powershell
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-minimalapi/contents/dr-minimalapi-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String))) -Update
```

Nota: `-Update` sovrascrive le copie locali. Si installa sempre l'ultimo `main` pushato su GitHub: le modifiche a questo repo non pushate su `main` non arrivano nei progetti host.

## 🐞 Segnalare un problema o una miglioria

Non correggere la copia nel progetto host: si perde al primo `-Update`.

Dal progetto host usa `/dr-segnala-miglioria <descrizione>` (su Copilot il prompt `.github/prompts/dr-segnala-miglioria.prompt.md` del core). La issue si apre in questo repo, dopo la tua conferma esplicita di titolo e corpo.

| Modello del repo | Quando usarlo |
|------------------|---------------|
| `.github/ISSUE_TEMPLATE/miglioria.md` | Richiesta evolutiva: regola nuova, precisazione, estensione del pacchetto |
| `.github/ISSUE_TEMPLATE/problema.md` | Malfunzionamento: regola sbagliata, ambigua o che porta l'agente fuori strada |

---

*Documento aggiornato: Settembre 2026 — Revisione v1.0 — 2026-09-16 — claude-opus-5*
