INSERT INTO UserDepartment (DepartmentName) VALUES ('Gömülü Sistemler ve Yazýlým'),
('Mekanik Sistemler Bakým'),
('Elektronik Harp ve Haberleþme'),
('Radar ve Sensör Sistemleri'),
('Lojistik ve Envanter Yönetimi'),
('Aviyonik Sistemler'),
('Kalite Güvence ve Test'),
('Envanter ve Tedarik Yönetimi'),
('Lojistik Destek Birimi'),
('Depo ve Ambar Yönetimi'),
('Siber Güvenlik ve Að Yönetimi');

INSERT INTO AccountStatus(aStatusName) VALUES ('Aktif'), -- 1: Sorunsuz giriþ
('Pasif'),           -- 2: Giriþ engelli (Silmek yerine pasife çekeriz)
('Onay Bekliyor'),   -- 3: Admin onayý lazým
('Kilitli'),         -- 4: Çok fazla hatalý giriþ denemesi
('Askýya Alýndý');   -- 5: Disiplin soruþturmasý vb.
