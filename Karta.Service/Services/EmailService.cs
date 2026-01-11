using System;
using System.Net;
using System.Net.Mail;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Karta.Service.DTO;
namespace Karta.Service.Services
{
    public interface IEmailService
    {
        Task SendEmailConfirmationAsync(string email, string confirmationLink, CancellationToken ct = default);
        Task SendPasswordResetAsync(string email, string resetLink, string firstName, CancellationToken ct = default);
        Task SendPasswordResetConfirmationAsync(string email, string firstName, CancellationToken ct = default);
        Task SendTicketConfirmationAsync(string email, string eventName, string ticketCode, CancellationToken ct = default);
        Task SendEmailDirectAsync(string toEmail, string subject, string body, CancellationToken ct = default);
    }
    public class EmailService : IEmailService
    {
        private readonly ILogger<EmailService> _logger;
        private readonly IConfiguration _configuration;
        private readonly IRabbitMQService? _rabbitMQService;
        public EmailService(
            ILogger<EmailService> logger, 
            IConfiguration configuration,
            IRabbitMQService? rabbitMQService = null)
        {
            _logger = logger;
            _configuration = configuration;
            _rabbitMQService = rabbitMQService;
        }
        public async Task SendEmailConfirmationAsync(string email, string confirmationLink, CancellationToken ct = default)
        {
            try
            {
                var subject = "Potvrda email adrese - Karta.ba";
                var body = $@"
                    <h2>Dobrodošli na Karta.ba!</h2>
                    <p>Molimo potvrdite svoju email adresu klikom na link ispod:</p>
                    <p><a href='{confirmationLink}' style='background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>Potvrdi email adresu</a></p>
                    <p>Ili kopirajte ovaj link u svoj browser:</p>
                    <p>{confirmationLink}</p>
                    <p>Hvala vam na registraciji!</p>
                    <p>Karta.ba tim</p>";
                var useRabbitMQ = _configuration.GetValue<bool>("Email:UseRabbitMQ", false);
                if (useRabbitMQ && _rabbitMQService != null && _rabbitMQService.IsConnected())
                {
                    var message = new EmailMessage(email, subject, body, EmailType.Confirmation);
                    _rabbitMQService.PublishEmailMessage(message);
                    _logger.LogInformation("Email confirmation queued via RabbitMQ for {Email}", email);
                }
                else
                {
                    await SendEmailDirectAsync(email, subject, body, ct);
                    _logger.LogInformation("Email confirmation sent directly via SMTP to {Email}", email);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send email confirmation to {Email}", email);
                throw;
            }
        }
        public async Task SendPasswordResetAsync(string email, string resetLink, CancellationToken ct = default)
        {
            try
            {
                var subject = "Reset lozinke - Karta.ba";
                var body = $@"
                    <h2>Reset lozinke</h2>
                    <p>Primili smo zahtjev za reset vaše lozinke.</p>
                    <p>Kliknite na link ispod da resetirate lozinku:</p>
                    <p><a href='{resetLink}' style='background-color: #dc3545; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>Resetiraj lozinku</a></p>
                    <p>Ili kopirajte ovaj link u svoj browser:</p>
                    <p>{resetLink}</p>
                    <p>Ako niste zatražili reset lozinke, ignorišite ovaj email.</p>
                    <p>Karta.ba tim</p>";
                await SendEmailDirectAsync(email, subject, body, ct);
                _logger.LogInformation("Password reset email sent to {Email}", email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send password reset email to {Email}", email);
                throw;
            }
        }
        public async Task SendPasswordResetAsync(string email, string resetLink, string firstName, CancellationToken ct = default)
        {
            try
            {
                var subject = "Reset Your Password - Karta.ba";
                var body = $@"
                    <h2>Password Reset Request</h2>
                    <p>Hello {firstName},</p>
                    <p>You have requested to reset your password. Click the link below to reset your password:</p>
                    <p><a href='{resetLink}' style='background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>Reset Password</a></p>
                    <p>This link will expire in 30 minutes.</p>
                    <p>If you did not request this password reset, please ignore this email.</p>
                    <p>Best regards,<br>Karta.ba Team</p>";
                await SendEmailDirectAsync(email, subject, body, ct);
                _logger.LogInformation("Password reset email sent to {Email}", email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send password reset email to {Email}", email);
                throw;
            }
        }
        public async Task SendPasswordResetConfirmationAsync(string email, string firstName, CancellationToken ct = default)
        {
            try
            {
                var subject = "Password Successfully Changed - Karta.ba";
                var body = $@"
                    <h2>Password Successfully Changed</h2>
                    <p>Hello {firstName},</p>
                    <p>Your password has been successfully changed.</p>
                    <p>If you did not make this change, please contact our support team immediately.</p>
                    <p>For security reasons, we recommend:</p>
                    <ul>
                        <li>Using a strong, unique password</li>
                        <li>Not sharing your password with anyone</li>
                        <li>Logging out from all devices if you suspect unauthorized access</li>
                    </ul>
                    <p>Best regards,<br>Karta.ba Team</p>";
                await SendEmailDirectAsync(email, subject, body, ct);
                _logger.LogInformation("Password reset confirmation sent to {Email}", email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send password reset confirmation to {Email}", email);
                throw;
            }
        }
        public async Task SendTicketConfirmationAsync(string email, string eventName, string ticketCode, CancellationToken ct = default)
        {
            try
            {
                var subject = $"Potvrda ulaznice - {eventName}";
                var body = $@"
                    <h2>Vaša ulaznica je spremna!</h2>
                    <p>Hvala vam na kupovini ulaznice za:</p>
                    <h3>{eventName}</h3>
                    <p><strong>Kod ulaznice:</strong> {ticketCode}</p>
                    <p>Molimo sačuvajte ovaj kod. Trebat će vam za ulazak na događaj.</p>
                    <p>Uživajte na događaju!</p>
                    <p>Karta.ba tim</p>";
                await SendEmailDirectAsync(email, subject, body, ct);
                _logger.LogInformation("Ticket confirmation sent to {Email} for event {EventName}", email, eventName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send ticket confirmation to {Email}", email);
                throw;
            }
        }
        public async Task SendEmailDirectAsync(string toEmail, string subject, string body, CancellationToken ct = default)
        {
            var fromEmail = Environment.GetEnvironmentVariable("EMAIL_FROM_EMAIL") 
                ?? _configuration["Email:FromEmail"];
            var fromName = Environment.GetEnvironmentVariable("EMAIL_FROM_NAME") 
                ?? _configuration["Email:FromName"];
            var smtpHost = Environment.GetEnvironmentVariable("EMAIL_SMTP_HOST") 
                ?? _configuration["Email:SmtpHost"];
            var smtpPortStr = Environment.GetEnvironmentVariable("EMAIL_SMTP_PORT");
            var smtpPort = !string.IsNullOrEmpty(smtpPortStr) && int.TryParse(smtpPortStr, out var port) 
                ? port 
                : _configuration.GetValue<int>("Email:SmtpPort");
            var smtpUsername = Environment.GetEnvironmentVariable("EMAIL_SMTP_USERNAME") 
                ?? _configuration["Email:SmtpUsername"];
            var smtpPassword = Environment.GetEnvironmentVariable("EMAIL_SMTP_PASSWORD") 
                ?? _configuration["Email:SmtpPassword"];
            var enableSslStr = Environment.GetEnvironmentVariable("EMAIL_ENABLE_SSL");
            var enableSsl = !string.IsNullOrEmpty(enableSslStr) && bool.TryParse(enableSslStr, out var ssl) 
                ? ssl 
                : _configuration.GetValue<bool>("Email:EnableSsl");
            if (!string.IsNullOrEmpty(fromEmail) && fromEmail.Contains("${"))
            {
                var match = System.Text.RegularExpressions.Regex.Match(fromEmail, @"\$\{[^:]+:(.+)\}");
                if (match.Success && match.Groups.Count > 1)
                {
                    fromEmail = match.Groups[1].Value;
                }
                else
                {
                    var varMatch = System.Text.RegularExpressions.Regex.Match(fromEmail, @"\$\{([^:}]+)");
                    if (varMatch.Success && varMatch.Groups.Count > 1)
                    {
                        var envVarName = varMatch.Groups[1].Value;
                        fromEmail = Environment.GetEnvironmentVariable(envVarName) ?? fromEmail;
                    }
                }
            }
            if (string.IsNullOrEmpty(smtpHost) || string.IsNullOrEmpty(smtpUsername) || string.IsNullOrEmpty(smtpPassword))
            {
                _logger.LogWarning("Email not configured. Logging email instead of sending.");
                _logger.LogInformation("Email to {ToEmail}: {Subject} - {Body}", toEmail, subject, body);
                return;
            }
            if (string.IsNullOrWhiteSpace(fromEmail))
            {
                _logger.LogError("FromEmail is not configured. Cannot send email.");
                throw new InvalidOperationException("FromEmail is not configured.");
            }
            _logger.LogDebug("Email configuration - FromEmail: {FromEmail}, SmtpHost: {SmtpHost}, SmtpPort: {SmtpPort}", 
                fromEmail, smtpHost, smtpPort);
            string? sanitizedFromName = null;
            if (!string.IsNullOrWhiteSpace(fromName))
            {
                sanitizedFromName = System.Text.RegularExpressions.Regex.Replace(
                    fromName, 
                    @"[:<>@\x00-\x1F\x7F]", 
                    string.Empty
                ).Trim();
                if (string.IsNullOrWhiteSpace(sanitizedFromName))
                {
                    sanitizedFromName = null;
                }
            }
            using var client = new SmtpClient(smtpHost, smtpPort);
            client.EnableSsl = enableSsl;
            client.UseDefaultCredentials = false;
            client.Credentials = new NetworkCredential(smtpUsername, smtpPassword);
            if (smtpPort == 587)
            {
                client.EnableSsl = true;
            }
            else if (smtpPort == 465)
            {
                client.EnableSsl = true;
            }
            using var message = new MailMessage();
            try
            {
                if (!string.IsNullOrWhiteSpace(sanitizedFromName))
                {
                    message.From = new MailAddress(fromEmail, sanitizedFromName);
                }
                else
                {
                    message.From = new MailAddress(fromEmail);
                }
            }
            catch (FormatException ex)
            {
                _logger.LogError(ex, "Invalid email address format. FromEmail: {FromEmail}, FromName: {FromName}", fromEmail, fromName);
                throw new InvalidOperationException($"Invalid email address format: {fromEmail}", ex);
            }
            message.To.Add(toEmail);
            message.Subject = subject;
            message.Body = body;
            message.IsBodyHtml = true;
            try
            {
                await client.SendMailAsync(message, ct);
                _logger.LogInformation("Email sent successfully to {ToEmail}", toEmail);
            }
            catch (SmtpException ex)
            {
                _logger.LogError(ex, "SMTP error sending email to {ToEmail}. Host: {Host}, Port: {Port}, SSL: {Ssl}, Username: {Username}", 
                    toEmail, smtpHost, smtpPort, enableSsl, smtpUsername);
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error sending email to {ToEmail}", toEmail);
                throw;
            }
        }
    }
}