using System.Threading;
using System.Threading.Tasks;
namespace Karta.Service.Interfaces
{
    public interface IPasswordResetService
    {
        Task<bool> RequestPasswordResetAsync(string email, CancellationToken ct = default);
        Task<bool> ResetPasswordAsync(string token, string newPassword, CancellationToken ct = default);
        Task<bool> IsTokenValidAsync(string token, CancellationToken ct = default);
        Task CleanupExpiredTokensAsync(CancellationToken ct = default);
    }
}