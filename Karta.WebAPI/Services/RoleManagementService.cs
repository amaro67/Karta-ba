using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Karta.Model;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
namespace Karta.WebAPI.Services
{
    public static class RoleManagementService
    {
        public static async Task InitializeCoreRoles(IServiceProvider serviceProvider)
        {
            var roleManager = serviceProvider.GetRequiredService<RoleManager<ApplicationRole>>();
            var coreRoles = new[]
            {
                new { Name = "User", Description = "Kupac - pregleda događaje, kupuje karte, vidi svoje narudžbe", Permissions = new[] { "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode" }},
                new { Name = "Organizer", Description = "Organizator događaja - kreira i uređuje svoje događaje", Permissions = new[] { "ViewEvents", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales" }},
                new { Name = "Scanner", Description = "Osoblje na ulazu - skenira i validira karte", Permissions = new[] { "ScanTickets", "ValidateTickets", "ViewEventDetails" }},
                new { Name = "Admin", Description = "Administrator sistema - upravlja svim korisnicima i rolama", Permissions = new[] { "ManageUsers", "ManageRoles", "ViewAllEvents", "ViewAllOrders", "ViewAllTickets", "ApproveOrganizers", "BlockUsers", "SystemSettings", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales", "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode", "ScanTickets", "ValidateTickets", "ViewEventDetails" }}
            };
            foreach (var role in coreRoles)
            {
                if (!await roleManager.RoleExistsAsync(role.Name))
                {
                    var applicationRole = new ApplicationRole
                    {
                        Name = role.Name,
                        Description = role.Description,
                        CreatedAt = DateTime.UtcNow
                    };
                    await roleManager.CreateAsync(applicationRole);
                    Console.WriteLine($"Created role: {role.Name}");
                }
            }
        }
        public static bool HasPermission(string role, string permission)
        {
            var rolePermissions = new Dictionary<string, string[]>
            {
                ["User"] = new[] { "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode" },
                ["Organizer"] = new[] { "ViewEvents", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales" },
                ["Scanner"] = new[] { "ScanTickets", "ValidateTickets", "ViewEventDetails" },
                ["Admin"] = new[] { "ManageUsers", "ManageRoles", "ViewAllEvents", "ViewAllOrders", "ViewAllTickets", "ApproveOrganizers", "BlockUsers", "SystemSettings", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales", "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode", "ScanTickets", "ValidateTickets", "ViewEventDetails" }
            };
            return rolePermissions.ContainsKey(role) && 
                   rolePermissions[role].Contains(permission);
        }
        public static string[] GetRolePermissions(string role)
        {
            var rolePermissions = new Dictionary<string, string[]>
            {
                ["User"] = new[] { "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode" },
                ["Organizer"] = new[] { "ViewEvents", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales" },
                ["Scanner"] = new[] { "ScanTickets", "ValidateTickets", "ViewEventDetails" },
                ["Admin"] = new[] { "ManageUsers", "ManageRoles", "ViewAllEvents", "ViewAllOrders", "ViewAllTickets", "ApproveOrganizers", "BlockUsers", "SystemSettings", "CreateEvents", "EditOwnEvents", "DeleteOwnEvents", "ViewOwnEventOrders", "ViewOwnEventTickets", "ManageOwnEventPrices", "ManageOwnEventCapacity", "ViewOwnEventSales", "ViewEvents", "PurchaseTickets", "ViewOwnOrders", "ViewOwnTickets", "GenerateQRCode", "ScanTickets", "ValidateTickets", "ViewEventDetails" }
            };
            return rolePermissions.ContainsKey(role) ? rolePermissions[role] : new string[0];
        }
    }
}