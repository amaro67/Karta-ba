
INSERT INTO AspNetUserRoles (UserId, RoleId) 
SELECT u.Id, r.Id 
FROM AspNetUsers u, AspNetRoles r 
WHERE r.Name = 'Admin'
AND u.Id = (SELECT Id FROM AspNetUsers ORDER BY CreatedAt LIMIT 1)
AND NOT EXISTS (
    SELECT 1 FROM AspNetUserRoles ur 
    WHERE ur.UserId = u.Id AND ur.RoleId = r.Id
);
