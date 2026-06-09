---
applyTo: "**"
---

# Minimal API Design Rules (AI Agent)

Scopo: regole obbligatorie per progetti Minimal API .NET 10. Segui sempre. Testo ottimizzato per token.

## Stack (obbligatorio)
- .NET 10, ASP.NET Core Minimal API (no Controllers)
- Tinyhelpers.AspNetCore (installare sempre)
- Scalar per docs (no Swagger UI)
- Asp.Versioning.Mvc.ApiExplorer (obbligatorio per Scalar)
- Serilog
- Entity Framework Core 10: se già presente nel `.csproj`, dichiaralo e prosegui senza chiedere. Chiedi solo se assente.
- SimpleAuthenticationTools (API Key): chiedere prima di aggiungere il pacchetto
- Aggiungi sempre il file launchSettings.json con configurazione per IIS Express e Kestrel
- Aggiungi sempre il file appsettings.local.json, aggiungi la chiamata in program.cs, e ignora il file in .gitignore
- Aggiungi sempre `.vscode/launch.json` e `.vscode/tasks.json` con profili debug `coreclr`
- Dati sensibili: segui sempre `sensitive-data.instructions.md`

## Vietato
- MVC Controllers
- Swagger UI
- IRepository pattern
- AutoMapper
- MediatR

## Struttura progetto
- src/<project>/
  - Dto/
  - Endpoints/
  - Infrastructure/Provider/{Entities,Filters,*DbContext.cs,*Provider.cs}
  - Transformers/
  - Validators/
  - Properties/
  - Program.cs
- test/
- docs/

## Regole core (sempre)
1) Endpoint solo in extension methods in Endpoints/*Mapping.cs
2) URL standard: api/v{version:apiVersion}/{gruppo}/{comando?}
3) Usa route group con WithTags + WithApiVersionSet + MapToApiVersion
4) Versioning: UrlSegmentApiVersionReader + ApiExplorer GroupNameFormat='v'VVV + SubstituteApiVersionInUrl=true
5) Parametri handler: route -> query (o [AsParameters] se >2) -> body -> servizi DI -> CancellationToken ultimo
6) OpenAPI metadata completo: Produces + WithSummary + WithDescription + WithName
7) Program.cs deve chiamare gli extension methods dopo MapOpenApi
8) Transformer OpenAPI: classe AddDocumentInformations in Transformers/ + registrazione AddOpenApi
9) GET con provider: filtro dedicato, mapping manuale a DTO, ProblemDetails 404 se vuoto
10) POST/PUT/PATCH con body: valida con `IValidator<T>` prima di processare; segui `input-validation.instructions.md`
11) Ogni nuovo progetto include `HealthMapping.cs` con: `MapHealthChecks("/health")` (infrastruttura, non in Scalar) + `GET /api/v1/status` versioned (consumer-facing, in Scalar)

## Scoperta automatica struttura DB via MCP

Se nel progetto è configurato un MCP server `db-schema` (verifica in `.claude/settings.json` o `~/.claude/settings.json`, chiave `mcpServers`):

1. **Non chiedere i campi all'utente** — leggi la struttura dalla tabella:
   - Usa `mcp__db-schema__use_connection` per selezionare la connessione
   - Usa `mcp__db-schema__get_view_columns` o strumento equivalente per ottenere colonne e tipi
2. **Presenta il piano di lavoro** con la struttura letta:
   - Elenca colonne rilevate, tipo C# mappato, se nullable
   - Dichiara: "Struttura rilevata via MCP db-schema. Procedo con piano."
3. **Genera il validator immediatamente** — non chiedere nulla all'utente:
   - Regole inferite dal metadato (applica sempre):
     - `NOT NULL` → `required`
     - `varchar(N)` / `nvarchar(N)` → `maxLength = N`
     - colonna nullable → campo opzionale (nessun required)
     - tipi numerici (`int`, `decimal`) → validazione di tipo garantita da C#
   - Campi con regole non determinabili dallo schema → nessun errore per quel campo + commento `// TODO: validazione`
   - Non chiedere regole all'utente: genera subito, codice compilabile e funzionante.

Se MCP db-schema non è configurato: comportamento standard (chiedi i campi all'utente prima di procedere).

---

## Pattern richiesti (copiabili)

### Extension method + group (pattern starter: HealthMapping)
```csharp
using Asp.Versioning;
using Asp.Versioning.Builder;   // ApiVersionSet è qui (v10.0.0+)

namespace <Project>.Endpoints;

public static class HealthMapping
{
    public static IEndpointRouteBuilder MapHealthEndpoints(this IEndpointRouteBuilder routes, ApiVersionSet versionSet)
    {
        routes.MapHealthChecks("/health");

        var group = routes.MapGroup("api/v{version:apiVersion}/status")
            .WithTags("Status")
            .WithApiVersionSet(versionSet)
            .MapToApiVersion(ApiVersionFactory.Version1);

        group.MapGet("/", () => TypedResults.Ok(new { status = "ok" }))
            .Produces<object>(StatusCodes.Status200OK)
            .WithName("GetStatus")
            .WithSummary("API status")
            .WithDescription("Returns ok when the API is running");

        return routes;
    }
}
```

### Program.cs (versioning + openapi + mapping)
```csharp
builder.Services.AddApiVersioning(options =>
{
    options.ApiVersionReader = new UrlSegmentApiVersionReader();
    options.DefaultApiVersion = ApiVersionFactory.Version1;
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
})
.AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});

builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<AddDocumentInformations>();
});

builder.Services.AddHealthChecks();

var versionSet = app.NewApiVersionSet()
    .HasApiVersion(ApiVersionFactory.Version1)
    .Build();

app.MapOpenApi();
app.MapScalarApiReference();
app.MapHealthEndpoints(versionSet);
```

### OpenAPI transformer
```csharp
using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;   // non Microsoft.OpenApi.Models (v2.0.0+)

public class AddDocumentInformations : IOpenApiDocumentTransformer
{
    public Task TransformAsync(OpenApiDocument document, OpenApiDocumentTransformerContext context, CancellationToken cancellationToken)
    {
        document.Info.Title = "<SolutionName> API";
        document.Info.Description = "<Short description>";
        document.Info.Version = "v1";
        document.Info.Contact = new OpenApiContact
        {
            Name = "Voisoft per Unidata spa, @ <Year>",
            Url = new Uri("https://www.twt.it/"),
            Email = "tron@twt.it"
        };

        return Task.CompletedTask;
    }
}
```

### GET con provider
```csharp
private static async Task<IResult> GetHandler(DateTime FromDate, DateTime ToDate, MyProvider provider, CancellationToken ct)
{
    var filter = new MyFilter { FromDate = FromDate, ToDate = ToDate };
    var result = await provider.GetAsync(filter, e => e.ToDto(), ct);
    if (!result.Any())
    {
        return TypedResults.Problem(new ProblemDetails
        {
            Title = "Data Not Found",
            Status = StatusCodes.Status404NotFound,
            Detail = "No data for specified range."
        });
    }

    return Results.Ok(result);
}
```

### VS Code debug (.vscode/launch.json + tasks.json)

**launch.json** — `"type": "coreclr"` (portabile, senza C# Dev Kit):
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug <project> (http)",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build",
      "program": "${workspaceFolder}/src/<project>/bin/net10.0/<project>.dll",
      "args": [],
      "cwd": "${workspaceFolder}/src/<project>",
      "stopAtEntry": false,
      "env": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "ASPNETCORE_URLS": "http://localhost:5000"
      }
    },
    {
      "name": "Debug <project> (https)",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build",
      "program": "${workspaceFolder}/src/<project>/bin/net10.0/<project>.dll",
      "args": [],
      "cwd": "${workspaceFolder}/src/<project>",
      "stopAtEntry": false,
      "env": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "ASPNETCORE_URLS": "https://localhost:5001;http://localhost:5000"
      }
    }
  ]
}
```

> **Nota:** Il percorso `bin/net10.0/` si applica quando `Directory.Build.props` setta `<OutputPath>bin\$(Configuration)\</OutputPath>`. Senza override, il percorso standard .NET è `bin/Debug/net10.0/`.

**tasks.json**:
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "command": "dotnet",
      "type": "process",
      "args": [
        "build",
        "${workspaceFolder}/src/<project>/<project>.csproj",
        "/property:GenerateFullPaths=true",
        "/consoleloggerparameters:NoSummary;ForceNoAlign"
      ],
      "problemMatcher": "$msCompile",
      "group": "build"
    }
  ]
}
```

## Errori comuni (rapidi)
- Version reader non UrlSegmentApiVersionReader => errore su MapToApiVersion
- Route senza api/v{version:apiVersion}/... => 404 o no route match
- Mancata MapToApiVersion => versione richiesta ma non specificata
- Scalar senza ApiExplorer config => nessun endpoint
- Provider non registrato in DI => Cannot resolve service
- Date query non ISO 8601 => DateTime conversion error
- `ApiVersionSet` CS0246 => manca `using Asp.Versioning.Builder` (Asp.Versioning v10.0.0+)
- `Microsoft.OpenApi.Models` CS0234 => usare `using Microsoft.OpenApi` (Microsoft.OpenApi v2.0.0+)

## ✅ Checklist Post-Generazione
- [ ] Endpoint solo in extension methods in Endpoints/*Mapping.cs
- [ ] Route group usa WithTags + WithApiVersionSet + MapToApiVersion
- [ ] URL formato api/v{version:apiVersion}/{gruppo}/{comando?}
- [ ] Versioning configurato con UrlSegmentApiVersionReader + ApiExplorer
- [ ] Metadata OpenAPI completi (Produces, Summary, Description, Name)
- [ ] Transformer AddDocumentInformations creato e registrato
- [ ] Program.cs chiama MapOpenApi prima dei Map*Endpoints
- [ ] GET con provider: filter + mapping DTO + ProblemDetails 404 se vuoto
- [ ] POST/PUT/PATCH: validator creato in `Validators/`, registrato in DI, chiamato nel handler prima della logica
- [ ] HealthMapping.cs creato con `/health` (MapHealthChecks) e `GET /api/v1/status` (versioned, in Scalar)
- [ ] File .http aggiunto per endpoint nuovi
- [ ] `.vscode/launch.json` e `tasks.json` creati con `type: coreclr`
- [ ] `appsettings.json` contiene solo valori fake/placeholder per dati sensibili, mai credenziali reali

## 🎯 Criteri di successo (verificare prima di iniziare)

Prima di iniziare, chiediti:
- [ ] So esattamente quali file creerò/modificherò?
- [ ] Ho letto le istruzioni modulari pertinenti al task?
- [ ] Ho verificato che l'endpoint o il componente non esista già?

Se una risposta è NO → chiedi chiarimenti all'utente prima di procedere.

## Test
- Aggiungi sempre un file .http per endpoint nuovi

*Template v1.7 - .NET 10 - Token-optimized for AI agents* - Last Update 2026-05-29 — claude-sonnet-4-6

