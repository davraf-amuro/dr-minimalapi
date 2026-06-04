---
agent: 'agent'
description: 'Genera la scheda riassuntiva per progetti Minimal API .NET 10'
tools: ['search/codebase']
---

# Prompt: Card Minimal API Project (AI Agent)

Genera la scheda riassuntiva per un progetto Minimal API. Non inventare dati. Lascia vuoto se non trovi info.

## Output
- Crea/aggiorna `docs/card-<nome_progetto>.md`

## Analisi da eseguire
- `.csproj`, `appsettings*.json`, `launchSettings.json`
- `Program.cs`: versioning, OpenAPI, endpoint registrati
- `Endpoints/*.cs`: MapGroup, route base, tag Scalar
- `DbContext`, provider/repository, using statements

## Template card
```markdown
# Card: [Nome Progetto]

**Minimal API** che [descrizione scopo in una riga].
Espone [N] endpoint group su `api/v1/`.

## Identificazione
- **Progetto:**
- **Solution:** [NomeSolution.sln]
- **Workspace:** [NomeWorkspace.code-workspace]
- **Repository:** [URL senza branch]
- **Tipo Applicazione:** Minimal API (.NET 10)
- **Pattern Architetturale:** Minimal API + Typed HttpClient / Provider
- **Versione Corrente:**
- **Owner/Team:**
- **Contatto Supporto:** dev-support@unidata.it

## Stack Tecnologico
- **Linguaggio Principale:** C# 14
- **Framework:** .NET 10 ASP.NET Core Minimal API
- **Target Framework:** net10.0
- **SDK Version:** Microsoft.NET.Sdk.Web

## Endpoint Groups

| Group | File Mapping | Route Base | Tag Scalar |
|-------|-------------|------------|------------|
| ... | `Endpoints/...Mapping.cs` | `api/v1/...` | ... |

## Dipendenze

### Progetti Interni
-

### Pacchetti Esterni
| Pacchetto | Versione | Scopo |
|-----------|----------|-------|
| ... | ... | ... |

## Database
| Connection String Key | Nome Database | Tipo | Server/Host | Username | Provider/ORM |
|-----------------------|---------------|------|-------------|----------|--------------|
| ... | ... | ... | da `appsettings.local.json` | da `appsettings.local.json` | EF Core 10 |

## Servizi Esterni
| Tipo | Nome/Endpoint | Protocollo | Autenticazione | Scopo/Descrizione |
|------|---------------|------------|----------------|-------------------|
| ... | ... | ... | ... | ... |

## Configurazione e Hosting
- **Entrypoint:** `src/<progetto>/Program.cs`
- **Deploy:** [locale | Docker | Swarm Portainer | ...]
- **URL Produzione:**
- **URL Scalar (dev):** `http://localhost:{porta}/scalar`

## Documentazione API
- **OpenAPI/Swagger:** Scalar (`/scalar`)
- **Versioning API:** UrlSegmentApiVersionReader
- **Versioni Supportate:** v1

---
*Revisione v1.0 — {YYYY-MM-DD HH:MM} — {modello-llm}*
```

## Regole
- Non inventare dati; campi senza info restano vuoti
- Tabelle senza dati: lascia solo header
- Info sensibili: indica solo il nome variabile, mai il valore
- Risposta del prompt: indica solo la card generata, non riepilogare i dati

## Checklist Post-Generazione
- [ ] `docs/` contiene la card
- [ ] Scopo dichiarato nelle due righe sotto il titolo
- [ ] Campi vuoti lasciati vuoti, niente dati inventati
- [ ] Tabella Endpoint Groups compilata con route base e tag reali
- [ ] Nessun segreto esposto
- [ ] Footer con data e LLM presente

*Template v1.1 - .NET 10 Minimal API - Token-optimized for AI agents* - Last Update 2026-06-04 - claude-sonnet-4-6
