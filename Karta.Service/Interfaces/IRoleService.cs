using Karta.Service.DTO;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
namespace Karta.Service.Interfaces
{
    public interface IRoleService
    {
        Task<RoleResponse> CreateRoleAsync(CreateRoleRequest request);
        Task<RoleResponse> UpdateRoleAsync(UpdateRoleRequest request);
        Task<bool> DeleteRoleAsync(string roleId);
        Task<RoleResponse?> GetRoleByIdAsync(string roleId);
        Task<RoleResponse?> GetRoleByNameAsync(string roleName);
        Task<List<RoleResponse>> GetAllRolesAsync();
        Task<bool> AddUserToRoleAsync(AddUserToRoleRequest request);
        Task<bool> RemoveUserFromRoleAsync(RemoveUserFromRoleRequest request);
        Task<UsersInRoleResponse> GetUsersInRoleAsync(string roleName);
        Task<List<RoleResponse>> GetUserRolesAsync(string userId);
        Task<bool> IsUserInRoleAsync(string userId, string roleName);
    }
}