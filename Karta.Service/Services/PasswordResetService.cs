using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
namespace Karta.Service.Services
{
    public class PasswordResetService : IPasswordResetService
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IEmailService _emailService;
        public PasswordResetService(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            IEmailService emailService)
        {
            _context = context;
            _userManager = userManager;
            _emailService = emailService;
        }
        public async Task<bool> RequestPasswordResetAsync(string email, CancellationToken ct = default)
        {
            var user = await _userManager.FindByEmailAsync(email);
            if (user == null)
            {
                return true;
            }
            var token = GenerateSecureToken();
            var expiresAt = DateTime.UtcNow.AddMinutes(30);
            var existingTokens = await _context.PasswordResetTokens
                .Where(t => t.UserId == user.Id && !t.IsUsed)
                .ToListAsync(ct);
            foreach (var existingToken in existingTokens)
            {
                existingToken.IsUsed = true;
            }
            var resetToken = new PasswordResetToken
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                Token = token,
                ExpiresAt = expiresAt,
                IsUsed = false,
                CreatedAt = DateTime.UtcNow
            };
            _context.PasswordResetTokens.Add(resetToken);
            await _context.SaveChangesAsync(ct);
            var resetLink = $"https://yourdomain.com/reset-password?token={token}";
            await _emailService.SendPasswordResetAsync(email, resetLink, user.FirstName, ct);
            return true;
        }
        public async Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken ct = default)
        {
            var resetToken = await _context.PasswordResetTokens
                .Include(t => t.User)
                .FirstOrDefaultAsync(t => t.Token == token && !t.IsUsed && t.ExpiresAt > DateTime.UtcNow, ct);
            if (resetToken == null)
            {
                return false;
            }
            var result = await _userManager.RemovePasswordAsync(resetToken.User);
            if (!result.Succeeded)
            {
                return false;
            }
            result = await _userManager.AddPasswordAsync(resetToken.User, newPassword);
            if (!result.Succeeded)
            {
                return false;
            }
            resetToken.IsUsed = true;
            await _context.SaveChangesAsync(ct);
            await _emailService.SendPasswordResetConfirmationAsync(resetToken.User.Email!, resetToken.User.FirstName, ct);
            return true;
        }
        public async Task<bool> IsTokenValidAsync(string token, CancellationToken ct = default)
        {
            var resetToken = await _context.PasswordResetTokens
                .FirstOrDefaultAsync(t => t.Token == token && !t.IsUsed && t.ExpiresAt > DateTime.UtcNow, ct);
            return resetToken != null;
        }
        public async Task CleanupExpiredTokensAsync(CancellationToken ct = default)
        {
            var expiredTokens = await _context.PasswordResetTokens
                .Where(t => t.ExpiresAt < DateTime.UtcNow || t.IsUsed)
                .ToListAsync(ct);
            _context.PasswordResetTokens.RemoveRange(expiredTokens);
            await _context.SaveChangesAsync(ct);
        }
        private static string GenerateSecureToken()
        {
            using var rng = RandomNumberGenerator.Create();
            var bytes = new byte[32];
            rng.GetBytes(bytes);
            return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").Replace("=", "");
        }
    }
}