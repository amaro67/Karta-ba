using Karta.Model;
using Karta.WebAPI.Services;
using Karta.WebAPI.Extensions;
using Karta.WebAPI.Filters;
using Karta.WebAPI.Authorization;
using Karta.WebAPI.Middleware;
using Swashbuckle.AspNetCore.SwaggerGen;
using Karta.Service.Interfaces;
using Karta.Service.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using System.Text;
using System.Threading.RateLimiting;
using System.Linq;
using System;
using Microsoft.AspNetCore.StaticFiles;
var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .CreateLogger();
builder.Host.UseSerilog();
var envConnectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING");
var configConnectionString = builder.Configuration["CONNECTION_STRING"];
var defaultConnectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var connectionString = envConnectionString ?? configConnectionString ?? defaultConnectionString;
if (string.IsNullOrEmpty(envConnectionString))
{
    Log.Warning("CONNECTION_STRING environment variable is not set. Using: {Source}", 
        !string.IsNullOrEmpty(configConnectionString) ? "CONNECTION_STRING from config" : "DefaultConnection from config");
}
else
{
    Log.Information("Using CONNECTION_STRING from environment variable");
}
Log.Information("Connection string sources - Env: {Env}, Config: {Config}, Default: {Default}", 
    string.IsNullOrEmpty(envConnectionString) ? "NULL" : envConnectionString.Substring(0, Math.Min(50, envConnectionString.Length)) + "...",
    string.IsNullOrEmpty(configConnectionString) ? "NULL" : (configConnectionString.Length > 50 ? configConnectionString.Substring(0, 50) + "..." : configConnectionString),
    string.IsNullOrEmpty(defaultConnectionString) ? "NULL" : defaultConnectionString);
if (string.IsNullOrEmpty(connectionString))
{
    throw new InvalidOperationException("CONNECTION_STRING environment variable or configuration is required. Please set a SQL Server connection string.");
}
var connectionStringForLogging = connectionString;
if (!string.IsNullOrEmpty(connectionString) && connectionString.Contains("Password="))
{
    var passwordIndex = connectionString.IndexOf("Password=");
    var passwordEnd = connectionString.IndexOf(";", passwordIndex);
    if (passwordEnd == -1) passwordEnd = connectionString.Length;
    connectionStringForLogging = connectionString.Substring(0, passwordIndex + 9) + "***" 
        + (passwordEnd < connectionString.Length ? connectionString.Substring(passwordEnd) : "");
}
Log.Information("Database connection: Type=SQL Server, ConnectionString={ConnectionString}", 
    connectionStringForLogging ?? "null");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString, b => b.MigrationsAssembly("Karta.WebAPI")));
Log.Information("Registered SQL Server database provider with connection string: {ConnectionString}", 
    connectionStringForLogging ?? "null");
builder.Services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
{
    options.Password.RequireDigit = true;
    options.Password.RequireLowercase = true;
    options.Password.RequireNonAlphanumeric = true;
    options.Password.RequireUppercase = true;
    options.Password.RequiredLength = 12;
    options.Password.RequiredUniqueChars = 3;
    options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    options.Lockout.MaxFailedAccessAttempts = 5;
    options.Lockout.AllowedForNewUsers = true;
    options.User.AllowedUserNameCharacters =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._@+";
    options.User.RequireUniqueEmail = true;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!)),
        ClockSkew = TimeSpan.Zero
    };
});
builder.Services.AddScoped<IEventService, EventService>();
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<ITicketService, TicketService>();
builder.Services.AddScoped<IStripeService, StripeService>();
builder.Services.AddScoped<Karta.Service.Services.IEmailService, Karta.Service.Services.EmailService>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IRoleService, RoleService>();
builder.Services.AddScoped<IPasswordResetService, PasswordResetService>();
builder.Services.AddScoped<IScannerService, ScannerService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IVenueService, VenueService>();
builder.Services.AddScoped<IFavoriteService, FavoriteService>();
// Always use RabbitMQ for email queuing
builder.Services.AddSingleton<IRabbitMQService, RabbitMQService>();
builder.Services.AddScoped<ValidationFilterAttribute>();
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.Identity?.Name ?? httpContext.Request.Headers.Host.ToString(),
            factory: partition => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = int.Parse(builder.Configuration["Security:RateLimitRequestsPerMinute"] ?? "100"),
                Window = TimeSpan.FromMinutes(1)
            }));
});
builder.Services.AddHostedService<Karta.WebAPI.Services.DatabaseInitializationService>();
builder.Services.AddHostedService<Karta.WebAPI.Services.OrderCleanupService>();
builder.Services.AddHostedService<Karta.WebAPI.Services.EventArchiveService>();
builder.Services.AddHostedService<Karta.WebAPI.Services.DailyResetService>();
builder.Services.AddHostedService<Karta.Service.Services.PaymentMonitorService>();
builder.Services.AddAuthorization(options =>
{
    var permissions = new[]
    {
        "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode",
        "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets",
        "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales",
        "ScanTickets", "ValidateTickets", "ViewEventDetails",
        "ManageUsers", "ManageRoles", "ViewAllEvents", "ViewAllOrders", "ViewAllTickets",
        "ApproveOrganizers", "BlockUsers", "SystemSettings"
    };
    foreach (var permission in permissions)
    {
        options.AddPolicy($"Permission.{permission}", policy =>
            policy.Requirements.Add(new PermissionRequirement(permission)));
    }
});
builder.Services.AddScoped<IAuthorizationHandler, PermissionHandler>();
var allowedOrigins = builder.Configuration["Security:CorsAllowedOrigins"]?.Split(',') ?? new[] { "https://localhost:3000", "http://localhost:3000", "http://localhost:57841" };
builder.Services.AddCors(options =>
{
    options.AddPolicy("RestrictedCors", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
        {
            if (string.IsNullOrWhiteSpace(origin)) return false;
            var uri = new Uri(origin);
            return uri.Host == "localhost" || 
                   uri.Host == "127.0.0.1" || 
                   uri.Host == "::1" ||
                   allowedOrigins.Contains(origin);
        })
        .AllowAnyMethod()
        .AllowAnyHeader()
        .AllowCredentials();
    });
});
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
    })
    .ConfigureApiBehaviorOptions(options =>
    {
        options.SuppressModelStateInvalidFilter = false;
    });
builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 5242880; // 5MB
    options.ValueLengthLimit = int.MaxValue;
    options.MultipartHeadersLengthLimit = int.MaxValue;
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "Karta.ba API",
        Version = "v1",
        Description = "API za online ticketing platformu Karta.ba",
        Contact = new Microsoft.OpenApi.Models.OpenApiContact
        {
            Name = "Karta.ba Support",
            Email = "support@karta.ba",
            Url = new Uri("https://karta.ba")
        },
        License = new Microsoft.OpenApi.Models.OpenApiLicense
        {
            Name = "MIT License",
            Url = new Uri("https://opensource.org/licenses/MIT")
        }
    });
    c.SwaggerGeneratorOptions.Servers.Clear();
    c.SwaggerGeneratorOptions.Servers.Add(new Microsoft.OpenApi.Models.OpenApiServer
    {
        Url = "/",
        Description = "Karta.ba API Server"
    });
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        c.IncludeXmlComments(xmlPath);
    }
    c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
        Name = "Authorization",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
    c.EnableAnnotations();
    c.SchemaFilter<ErrorResponseSchemaFilter>();
    c.OperationFilter<FileUploadOperationFilter>();
});
var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Karta.ba API v1");
    c.RoutePrefix = "swagger";
    c.DocumentTitle = "Karta.ba API Documentation";
});
app.UseWhen(context => 
    !context.Request.Path.StartsWithSegments("/api/order/webhook") &&
    !context.Request.Path.StartsWithSegments("/api/Event/upload-image"), app =>
{
    app.UseHttpsRedirection();
});
app.UseMiddleware<SecurityHeadersMiddleware>();
app.UseRateLimiter();
app.UseCors("RestrictedCors");
var staticFileOptions = new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Methods", "GET");
    }
};
app.UseStaticFiles(staticFileOptions);
app.UseGlobalExceptionHandling();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/", () => "Karta.ba API is running! Visit /swagger for API documentation.");
try
{
    Log.Information("Starting Karta.ba Web API");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
public partial class Program { }