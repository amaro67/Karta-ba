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
        Task SendCategoryRecommendationAsync(string email, string subject, string body, CancellationToken ct = default);
        Task SendEmailDirectAsync(string toEmail, string subject, string body, CancellationToken ct = default);
        Task SendTicketCancellationAsync(string email, string eventName, string ticketCode, CancellationToken ct = default);
        Task SendOrganizerCancellationNotificationAsync(string organizerEmail, string eventName, string ticketCode, string customerEmail, CancellationToken ct = default);
    }
    public class EmailService : IEmailService
    {
        private readonly ILogger<EmailService> _logger;
        private readonly IConfiguration _configuration;
        private readonly IRabbitMQService _rabbitMQService;
        public EmailService(
            ILogger<EmailService> logger,
            IConfiguration configuration,
            IRabbitMQService rabbitMQService)
        {
            _logger = logger;
            _configuration = configuration;
            _rabbitMQService = rabbitMQService;
        }

        private void QueueEmail(string email, string subject, string body, EmailType type)
        {
            _logger.LogInformation("QueueEmail called for {Email}, Type: {Type}, checking RabbitMQ connection...", email, type);
            var isConnected = _rabbitMQService.IsConnected();
            _logger.LogInformation("RabbitMQ.IsConnected() returned: {IsConnected}", isConnected);

            if (isConnected)
            {
                var message = new EmailMessage(email, subject, body, type);
                _rabbitMQService.PublishEmailMessage(message);
                _logger.LogInformation("Email queued via RabbitMQ for {Email} - Type: {Type}", email, type);
            }
            else
            {
                _logger.LogError("RabbitMQ not connected. Cannot queue email for {Email}", email);
                throw new InvalidOperationException("RabbitMQ is not connected. Email cannot be sent.");
            }
        }

        public Task SendEmailConfirmationAsync(string email, string confirmationLink, CancellationToken ct = default)
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

            QueueEmail(email, subject, body, EmailType.Confirmation);
            return Task.CompletedTask;
        }

        public Task SendPasswordResetAsync(string email, string resetLink, string firstName, CancellationToken ct = default)
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

            QueueEmail(email, subject, body, EmailType.PasswordReset);
            return Task.CompletedTask;
        }

        public Task SendPasswordResetConfirmationAsync(string email, string firstName, CancellationToken ct = default)
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

            QueueEmail(email, subject, body, EmailType.PasswordReset);
            return Task.CompletedTask;
        }

        public Task SendTicketConfirmationAsync(string email, string eventName, string ticketCode, CancellationToken ct = default)
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

            QueueEmail(email, subject, body, EmailType.TicketConfirmation);
            return Task.CompletedTask;
        }

        public Task SendCategoryRecommendationAsync(string email, string subject, string body, CancellationToken ct = default)
        {
            QueueEmail(email, subject, body, EmailType.CategoryRecommendation);
            return Task.CompletedTask;
        }

        public Task SendTicketCancellationAsync(string email, string eventName, string ticketCode, CancellationToken ct = default)
        {
            var subject = $"Vaša karta je otkazana - {eventName}";
            var body = $@"
                <h2>Potvrda otkazivanja karte</h2>
                <p>Poštovani,</p>
                <p>Vaša karta za događaj <strong>{eventName}</strong> je uspješno otkazana.</p>
                <p><strong>Broj karte:</strong> {ticketCode}</p>
                <p><strong>Datum otkazivanja:</strong> {DateTime.UtcNow:dd.MM.yyyy HH:mm} UTC</p>
                <p>Ako imate pitanja, kontaktirajte nas.</p>
                <p>Srdačan pozdrav,<br>Karta.ba tim</p>";

            QueueEmail(email, subject, body, EmailType.TicketCancellation);
            return Task.CompletedTask;
        }

        public Task SendOrganizerCancellationNotificationAsync(string organizerEmail, string eventName, string ticketCode, string customerEmail, CancellationToken ct = default)
        {
            var subject = $"Karta otkazana - {eventName}";
            var body = $@"
                <h2>Obavijest o otkazivanju karte</h2>
                <p>Poštovani organizatoru,</p>
                <p>Korisnik je otkazao kartu za vaš događaj.</p>
                <p><strong>Događaj:</strong> {eventName}</p>
                <p><strong>Broj karte:</strong> {ticketCode}</p>
                <p><strong>Email kupca:</strong> {customerEmail}</p>
                <p><strong>Datum otkazivanja:</strong> {DateTime.UtcNow:dd.MM.yyyy HH:mm} UTC</p>
                <p>Karta.ba tim</p>";

            QueueEmail(organizerEmail, subject, body, EmailType.OrganizerCancellation);
            return Task.CompletedTask;
        }

        /// <summary>
        /// Sends email directly via SMTP. This method is used by the Worker only.
        /// </summary>
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

            if (string.IsNullOrEmpty(smtpHost) || string.IsNullOrEmpty(smtpUsername) || string.IsNullOrEmpty(smtpPassword))
            {
                _logger.LogWarning("Email not configured. Logging email instead of sending.");
                _logger.LogInformation("Email to {ToEmail}: {Subject}", toEmail, subject);
                return;
            }

            if (string.IsNullOrWhiteSpace(fromEmail))
            {
                _logger.LogError("FromEmail is not configured. Cannot send email.");
                throw new InvalidOperationException("FromEmail is not configured.");
            }

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
            client.EnableSsl = enableSsl || smtpPort == 587 || smtpPort == 465;
            client.UseDefaultCredentials = false;
            client.Credentials = new NetworkCredential(smtpUsername, smtpPassword);

            using var message = new MailMessage();
            if (!string.IsNullOrWhiteSpace(sanitizedFromName))
            {
                message.From = new MailAddress(fromEmail, sanitizedFromName);
            }
            else
            {
                message.From = new MailAddress(fromEmail);
            }

            message.To.Add(toEmail);
            message.Subject = subject;
            message.Body = body;
            message.IsBodyHtml = true;

            await client.SendMailAsync(message, ct);
            _logger.LogInformation("Email sent successfully to {ToEmail}", toEmail);
        }
    }
}
