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
  - Services/
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
9) GET list con provider: filtro dedicato obbligatorio su tutti i campi entità; proiezione EF-traducibile via `Expression<Func<TEntity, TDto>>`; ProblemDetails 404 se vuoto.
   - Deriva filtro dall'entità senza chiedere nulla all'utente — applica regole tipo e genera subito
   - Regole tipo → campo filter:
     - string       → string?  — `(Descrizione == null || e.Descrizione.Contains(Descrizione))`
     - int / int?   → int?     — `(Marca == null || e.Marca == Marca)`
     - DateTime / DateTime? → due param NomeFrom? + NomeTo? — range >= / <=
     - bool / bool? → bool?    — `(Flag == null || e.Flag == Flag)`
   - Tutti i campi filtro nullable — nessun campo richiesto
   - Filter class: `Infrastructure/Provider/Filters/<Entity>Filter.cs` — espone `ToExpression()` che ritorna `Expression<Func<TEntity, bool>>`
   - Ogni DTO record espone `static Expression<Func<TEntity, TDto>> Projection => e => new(...)` — EF-traducibile
   - Handler usa `[AsParameters]` se filtro ha ≥ 2 campi
   - Provider: `GetAsync<TDto>(<Entity>Filter filter, Expression<Func<TEntity, TDto>> selector, CancellationToken ct)` — mai GetAllAsync senza filtro
   - Chiamata handler: `provider.GetAsync(filter, MyDto.Projection, ct)`
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

### GET list con provider, filtro e proiezione Expression

```csharp
// DTO — Dto/<Entity>Dto.cs
// Ogni DTO espone una Projection EF-traducibile (new-initializer con member access primitivi)
public record ModelKitDto(int Id, string Descrizione, int? Marca, DateTime DataRegistrazione)
{
    public static Expression<Func<ModelKit, ModelKitDto>> Projection =>
        e => new(e.Id, e.Descrizione, e.Marca, e.DataRegistrazione);
}

// DTO parziale — stessa entità, campi ridotti → SELECT ottimizzato
public record ModelKitSummaryDto(int Id, int? Marca)
{
    public static Expression<Func<ModelKit, ModelKitSummaryDto>> Projection =>
        e => new(e.Id, e.Marca);
}

// Filter — Infrastructure/Provider/Filters/<Entity>Filter.cs
// ToExpression() incapsula tutta la logica WHERE in un'unica Expression EF-traducibile
public class ModelKitFilter
{
    public string? Descrizione { get; set; }
    public int? Marca { get; set; }
    public DateTime? DataRegistrazioneFrom { get; set; }
    public DateTime? DataRegistrazioneTo { get; set; }

    public Expression<Func<ModelKit, bool>> ToExpression() =>
        e => (Descrizione == null || e.Descrizione.Contains(Descrizione))
          && (Marca == null || e.Marca == Marca)
          && (DataRegistrazioneFrom == null || e.DataRegistrazione >= DataRegistrazioneFrom)
          && (DataRegistrazioneTo == null || e.DataRegistrazione <= DataRegistrazioneTo);
}

// Provider — generico sul tipo di ritorno, mai GetAllAsync senza filtro
public async Task<IEnumerable<TDto>> GetAsync<TDto>(
    ModelKitFilter filter,
    Expression<Func<ModelKit, TDto>> selector,
    CancellationToken ct) =>
    await db.ModelKits
        .Where(filter.ToExpression())
        .Select(selector)
        .ToListAsync(ct);

// Handler — in *Mapping.cs
// Passare sempre una Projection statica del DTO — non costruire expression inline nell'handler
private static async Task<IResult> GetHandler(
    [AsParameters] ModelKitFilter filter,
    ModelKitProvider provider,
    CancellationToken ct)
{
    var result = await provider.GetAsync(filter, ModelKitDto.Projection, ct);
    if (!result.Any())
        return TypedResults.Problem(new ProblemDetails
        {
            Title = "Data Not Found",
            Status = StatusCodes.Status404NotFound,
            Detail = "No data for specified filters."
        });

    return TypedResults.Ok(result);
}

// Handler con DTO parziale — stesso provider, selector diverso
private static async Task<IResult> GetSummaryHandler(
    [AsParameters] ModelKitFilter filter,
    ModelKitProvider provider,
    CancellationToken ct)
{
    var result = await provider.GetAsync(filter, ModelKitSummaryDto.Projection, ct);
    // ...
    return TypedResults.Ok(result);
}
```

> **Regola critica — EF traducibilità:** `Projection` deve usare esclusivamente new-initializer con accesso a membri primitivi (`e.Id`, `e.Nome`, ecc.). Chiamate a metodi extension (es. `e.ToDto()`) NON sono EF-traducibili e causano valutazione client-side silente (full table scan in memoria).

### Service layer (opzionale — quando la logica cresce)

Il `Service` si interpone tra endpoint e provider. L'handler conosce solo il Service — non il provider, non le Projection.

```csharp
// Services/<Entity>Service.cs
public class ModelKitService(ModelKitProvider provider)
{
    public Task<IEnumerable<ModelKitDto>> GetAllAsync(ModelKitFilter filter, CancellationToken ct) =>
        provider.GetAsync(filter, ModelKitDto.Projection, ct);

    public Task<IEnumerable<ModelKitSummaryDto>> GetSummariesAsync(ModelKitFilter filter, CancellationToken ct) =>
        provider.GetAsync(filter, ModelKitSummaryDto.Projection, ct);

    public Task<ModelKitDto?> GetByIdAsync(int id, CancellationToken ct) =>
        provider.GetByIdAsync(id, ct);

    public Task<ModelKitDto> CreateAsync(SaveModelKitRequest request, CancellationToken ct) =>
        provider.CreateAsync(request, ct);

    public Task<ModelKitDto?> UpdateAsync(int id, SaveModelKitRequest request, CancellationToken ct) =>
        provider.UpdateAsync(id, request, ct);

    public Task<bool> DeleteAsync(int id, CancellationToken ct) =>
        provider.DeleteAsync(id, ct);
}

// Handler — inietta Service, non Provider
private static async Task<IResult> GetAllHandler(
    [AsParameters] ModelKitFilter filter,
    ModelKitService service,
    CancellationToken ct)
{
    var result = await service.GetAllAsync(filter, ct);
    // ...
}

// Program.cs — registra entrambi
builder.Services.AddScoped<ModelKitProvider>();
builder.Services.AddScoped<ModelKitService>();
```

> **Quando introdurre il Service:** logica condivisa tra handler, autorizzazione/tenant, composizione da più provider, side-effect. Non introdurre solo per delegation pura.

---

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
- [ ] GET list: `<Entity>Filter.cs` in `Infrastructure/Provider/Filters/` con `ToExpression()`, ogni DTO ha `static Projection`, provider usa `GetAsync<TDto>(filter, selector, ct)`, handler passa `MyDto.Projection`
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

