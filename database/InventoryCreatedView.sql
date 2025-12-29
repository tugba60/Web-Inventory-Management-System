CREATE VIEW vw_KullaniciProfilDetay
AS
SELECT 
    u.UserID,
    u.Username,
    u.Name_,
    u.Surname_,
    u.e_mail,
    u.role_,
    u.Dept_id,              
    d.DepartmentName,
	CASE 
        WHEN u.is_on_leave = 1 THEN 'Ýzinde'
        ELSE 'Ýzinde Deðil' 
    END AS IzinDurumu,
	u.access_request_pending
FROM Users u
-- LEFT JOIN: Kullanýcýnýn departmaný silinmiþ veya boþ olsa bile kullanýcýyý getirir
LEFT JOIN UserDepartment d ON u.Dept_id = d.DepartmentId