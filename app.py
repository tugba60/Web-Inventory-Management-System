# 1. Flask kütüphanesini ve diğer gerekli araçları içe aktar
from flask import Flask, render_template, session, url_for, redirect, request, flash
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import pyodbc
import os
from werkzeug.utils import secure_filename
from flask import current_app

# 2. Flask uygulamasını başlat ve 'app' değişkenine ata
app = Flask(__name__)

# 3. Session (oturum) işlemleri için gerekli gizli anahtar
app.secret_key = 'buraya_karmasik_gizli_bir_anahtar_yazin'

UPLOAD_FOLDER = 'static/product_images'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

#kullanılacak fonksiyonlar
def sifrele(normal_sifre):
    # 'pbkdf2:sha256' algoritması.
    # tuzlama (salting) işlemini otomatik yapar.
    return generate_password_hash(normal_sifre)

def sifre_kontrol_et(veritabanindaki_hash, girilen_sifre):
    """
    Veritabanındaki hashli şifre ile kullanıcının girdiği şifreyi karşılaştırır.
    Doğruysa True, yanlışsa False döner.
    KULLANIM: Giriş Yap (Login) işleminde.
    """
    return check_password_hash(veritabanindaki_hash, girilen_sifre)

    
#VERİTABANI bağlantısını kur
def open_connection():
    #1.adım:server name tanımlamak
    server="LAPTOP-OKO0VKK3"
    #2.adım:veri tabanını tanımlama
    database="InventoryManagementSystem"
    #3.adım:connection string oluşturulur
    conn_string=(
        f'DRIVER={'ODBC Driver 17 for SQL Server'};'
        f'SERVER={server};'
        f'DATABASE={database};'
        f'Trusted_Connection=yes;'
    )
    #4.adım:bağlantıyı döndür
    return pyodbc.connect(conn_string)

def kullaniciIDgetir(username):
    try:
        conn = open_connection()
        if conn is None:
            return None

        cursor = conn.cursor()
        
        # SQL tarafındaki prosedürü çağırıyoruz
        cursor.execute("EXEC sp_KullaniciIdGetir ?", (username,))
        
        result = cursor.fetchone()
        conn.close()

        if result:
            return result.UserId 
        else:
            return None

    except Exception as e:
        print(f"Kullanıcı ID Getirme Hatası: {e}")
        return None
    
def temizle(veri):
    if not veri or veri.strip() == "":
        return None
    return veri

def erisimi_kontrol_et():
    conn = None
    try:
        conn=open_connection()
        cursor=conn.cursor()
    
        userID=kullaniciIDgetir(session.get('kullanici_adi'))
        cursor.execute("SELECT AccountStatus_id, role_ FROM Users Where UserId=?",(userID,))
        erisim_durumu=cursor.fetchone()

        if erisim_durumu and erisim_durumu[0] in [3, 4]:
            flash("Bu işlemi yapmaya yetkiniz yok.", "danger")
            if erisim_durumu[1] == 1:
                return redirect(url_for('dashboard_admin'))
            else:
                return redirect(url_for('dashboard_user'))
        return None
    except Exception as e:
        flash(f"HATA: {e}", "danger")
        return redirect(url_for('open_login_page'))

    finally:
        # Burası return'den hemen önce MUTLAKA çalışır ve bağlantıyı temizler.
        if conn:
            conn.close()



def logla(user_id, action_id, table_id=None, record_id=None):
    conn = None
    try:

        conn = open_connection()
        cursor = conn.cursor()
        
        # Parametreler tam eşleşiyor, sorun yok.
        sql_query = "EXEC sp_VerileriLogla ?, ?, ?, ?"
        values = (user_id, action_id, table_id, record_id)
        
        cursor.execute(sql_query, values)
        conn.commit()
        
    except Exception as e:
        # repr() fonksiyonu hatayı ham haliyle yazar, emojiler sorun çıkarmaz.
        print(f"Loglama Hatası: {e}")
    finally:
        if conn: conn.close()

# --- ROTALARLAR ---
#Home pages
@app.route('/')
def open_index_page():
    # Flask'a bu HTML'i işlemesini ve sunmasını söylüyoruz
    return render_template('index.html')

#Creating account page
@app.route('/create-account',methods=["POST","GET"])
def open_register_page():
    conn=open_connection()
    cursor=conn.cursor()
    cursor.execute("SELECT * FROM UserDepartment")
    list_of_data=cursor.fetchall()
    conn.close()
    if request.method=='POST':
        #post işlemi için veri tabanı işlemleri yapılır
        userName=request.form['kullaniciAdi']
        name=request.form['ad']
        name=name.title()
        surname=request.form['soyad']
        surname=surname.upper()
        department=request.form['departman']
        eMail=request.form['email']
        password=request.form['password']
        password_hash=sifrele(password)
        passwordAgain=request.form['passwordTekrar']

        if len(password)<10:
            flash("Girdiğiniz şifre en az 10 karakterden oluşmalı! Lütfen tekrar deneyin.", "danger")
            return render_template('register.html',departmanlar=list_of_data)
        if (password==passwordAgain):
            try:
                conn=open_connection()
                cursor=conn.cursor()
                query = """
                    EXEC sp_KullaniciEkle 
                    @KullaniciAdi = ?,
                    @Ad = ?, 
                    @Soyad = ?,
                    @Sifre = ?,
                    @Departman = ?, 
                    @Eposta=?
                    """
                cursor.execute(query,(userName, name, surname, password_hash, department, eMail))
                yeni_user_id = cursor.fetchone()[0]
                conn.commit()
                conn.close()
                logla(yeni_user_id,4,1,yeni_user_id)
                return redirect(url_for('open_login_page'))
            except pyodbc.Error as e:
                # SQL'den hata dönerse
                hata_mesaji = str(e.args[1]) # SQL'deki RAISERROR mesajını yakalar
                flash(f"Kayıt Hatası: {hata_mesaji}", "danger")
                return render_template('register.html')
           
        else:
            flash("Girdiğiniz şifreler birbiriyle uyuşmuyor! Lütfen tekrar deneyin.", "danger")
            return render_template('register.html',departmanlar=list_of_data)
            
    else:
        return render_template('register.html',departmanlar=list_of_data)


#login page
@app.route('/login-account', methods=["POST","GET"])
def open_login_page():
    if request.method=="POST":
        #veri tabanı kontrolü yapılır ve izin verilir veya verilmez
        eposta=request.form['email']
        password=request.form['password']
        try:
            conn=open_connection()
            cursor=conn.cursor()
            cursor.execute("EXEC sp_KullaniciSorgula @Eposta = ?", (eposta,))
            kayit = cursor.fetchone()
            conn.close()
            user_id=kullaniciIDgetir(kayit.UserName)
            if kayit:
            # kayit.PasswordHash -> Veritabanından gelen şifreli yazı
            # girilen_sifre      -> Kullanıcının yazdığı 
            
                if check_password_hash(kayit.PasswordHash, password):
                    if kayit.AccountStatus_id==1 or kayit.AccountStatus_id==3 or kayit.AccountStatus_id==4:
                        # Şifre Doğru! Oturumu başlat
                        session['oturum'] = True
                        session['kullanici_adi'] = kayit.UserName
                        session['ad_soyad'] = f"{kayit.Name_} {kayit.Surname_}"
                        
                        logla(user_id,1,12)
                        
                        # Role göre yönlendir
                        if kayit.role_: #True veya 1 bekler
                            session['rol'] = 'admin'
                            return redirect(url_for('dashboard_admin'))
                        else:
                            session['rol'] = 'user'
                            return redirect(url_for('dashboard_user'))
                    else:
                        flash("Sisteme Giriş İzniniz Yok!", "danger")
                        return render_template('login.html')
                else:
                    flash("Hatalı Şifre!", "danger")
                    logla(user_id,3,12)
                    return render_template('login.html')
            else:
                flash("Kullanıcı Bulunamadı!", "danger")
                return render_template('login.html')

        except pyodbc.Error as e:
            # SENARYO 1: Veritabanı kaynaklı hata (Şifre yanlış, Sunucu kapalı vs.)
            
            # Terminale KIRMIZI bir uyarı bas (Sen gör diye)
            print(f" KRİTİK HATA: Veritabanına bağlanılamadı!")
            print(f"Hata Detayı: {ascii(e)}")
            return render_template('login.html')
        except Exception as genel_hata:
            # Başka bir sebepten çıkan hata
            print(f" BEKLENMEYEN HATA: {genel_hata}")
            return render_template('login.html')

    return render_template('login.html')

@app.route('/dashboard-users')
def dashboard_user():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    return render_template('dashboardForUsers.html')

@app.route('/dashboard-admin')
def dashboard_admin():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    return render_template('dashboardForAdmin.html')

@app.route('/logout')
def logout():
    if 'kullanici_adi' in session:
        # Sizin projenizdeki ID bulma fonksiyonunu kullanıyoruz
        user_id = kullaniciIDgetir(session['kullanici_adi'])
    logla(user_id,2)
    session.clear()
    return redirect(url_for('open_login_page'))

@app.route('/profile-management', methods=['POST','GET'])
def open_profile_management_page():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))

    conn = open_connection()
    cursor = conn.cursor()

    userid=kullaniciIDgetir(session['kullanici_adi'])

    if request.method=="POST":
        username=session['kullanici_adi']
        name=temizle(request.form.get('isim'))
        surname=temizle(request.form.get('soyisim'))
        department=temizle(request.form.get('departman')) #id bilgisi gelir
        email=temizle(request.form.get('email'))
        erisim_izni=temizle(request.form.get('request_type'))
        try:
            query = """
                EXEC sp_KullaniciGuncelle 
                @username = ?,
                @YeniAd = ?, 
                @YeniSoyad = ?,
                @YeniEmail=?,
                @YeniDepartmanID = ?,
                @Erisim_izni = ?
                """
            cursor.execute(query,(username, name, surname, email ,department,erisim_izni))
            conn.commit()
            logla(userid,11,1,userid)
            flash("Profil bilgileriniz başarıyla güncellendi.", "success")
            conn.close()
            return redirect(url_for('open_profile_management_page'))
        except pyodbc.Error as e:
            # SQL'den hata dönerse
            hata_mesaji = str(e.args[1]) # SQL'deki RAISERROR mesajını yakalar
            flash(f"Kayıt Hatası: {hata_mesaji}", "danger")
    try:
        # 1. Tüm Departmanları Çek (Select kutusu için)
        cursor.execute("SELECT * FROM UserDepartment")
        tum_departmanlar = cursor.fetchall()

        # 2. Kullanıcıyı Çek
        cursor.execute("SELECT * FROM vw_KullaniciProfilDetay WHERE Username = ?", (session['kullanici_adi'],))
        kullanici_detay = cursor.fetchone()
        conn.close()
        return render_template('profile_management.html',departmanlar=tum_departmanlar, user=kullanici_detay)
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        conn.close()
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")
        return redirect(url_for('open_login_page')) # dashboarda at


@app.route('/stock-tracking', methods=['POST','GET'])
def open_stock_tracking_page():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    conn=open_connection()
    cursor=conn.cursor()

    if request.method=="POST":
        
        # GÜVENLİK
        gidecek_yer = erisimi_kontrol_et()
        if gidecek_yer is not None:
            return gidecek_yer

        urun=request.form['product']
        userID=kullaniciIDgetir(session['kullanici_adi'])
        if request.form['transaction_type']=='Giriş':
            trans_type=1
        else:
            trans_type=0
        miktar=request.form['miktar']
        tarih=request.form['date']
        islem_tarihi = tarih.replace('T', ' ')
        aciklama=request.form['note']

        query="""
                EXEC sp_StokGuncelle
                @productId = ?,
                @userId = ?, 
                @transactionType = ?,
                @quantity=?,
                @transDate = ?,
                @aciklama=?
                """
        cursor.execute(query,(urun,userID,trans_type,miktar,islem_tarihi,aciklama,))
        conn.commit()
        if trans_type==1:
            logla(userID,6,11)
        else:
            logla(userID,7,11)
        flash("Stok güncellemesi gerçekleştirildi.", "success")
        conn.close()
        return redirect(url_for('open_stock_tracking_page'))
    
    try:
        cursor.execute("SELECT * FROM ProductCategory")
        cekilenKategoriler=cursor.fetchall()
        secilen_kategori = request.args.get('kategori')
        sqlSorgusu="SELECT ProductId, ProductName, ProductCode, Quantity, ImagePath FROM Products WHERE Status_id IN (?,?,?)"
        parametreler=[1,2,3]
        if secilen_kategori and secilen_kategori != 'hepsi':
            sqlSorgusu += " AND Category_id = ?"
            parametreler.append(secilen_kategori)
        cursor.execute(sqlSorgusu, tuple(parametreler))
        cekilen_veriler = cursor.fetchall()
        conn.close()
        return render_template('stock_tracking.html',products=cekilen_veriler, kategoriler=cekilenKategoriler, aktif_kategori=secilen_kategori)
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        conn.close()
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")

@app.route('/maintenance-repair',methods=['GET'])
def open_maintenance_repair_page():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    try:
        conn=open_connection()
        cursor=conn.cursor()
        secilen_durum = request.args.get('status', '0')
        cursor.execute("EXEC sp_BakimdakiUrunler ?", (secilen_durum,))
        bakimdaki_urunler=cursor.fetchall()
        cursor.execute("EXEC sp_BakimdaOlamayanUrunler")
        bakimdaOlmayan_urunler=cursor.fetchall()
        conn.close()
        secilen_durum = request.args.get('status', 0, type=int)
        return render_template('maintenance_repair.html',productsInMaintenance=bakimdaki_urunler,productsNotInMaintenance=bakimdaOlmayan_urunler, secilen_durum=secilen_durum)
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        conn.close()
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")

#arıza kaydı oluşturmadan önce ekranı hazırlar
@app.route('/maintenance-repair/create-fault-record/<int:product_id>')
def open_create_fault_record_page(product_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    conn=None
    try:
        conn=open_connection()
        cursor=conn.cursor()

        
        sql_sorgusu = """
            SELECT 
                ProductId,      -- product[0]
                ProductName,    -- product[1]
                ProductCode,    -- product[2]
                Quantity,       -- product[3]
                ImagePath       -- product[4]
            FROM Products 
            WHERE ProductId = ?
        """
        cursor.execute(sql_sorgusu,(product_id,))
        urun=cursor.fetchone()
        
        if urun is None:
            flash("Aradığınız ürün bulunamadı!", "warning")
            return redirect(url_for('open_maintenance_repair_page'))
        return render_template('create_fault_record.html',product=urun)
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        conn.close()
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")
    finally:
        if conn:
            conn.close()

#arıza kaydı açma işlemi
@app.route('/maintenance-repair/create-fault-record/save-fault-record/<int:product_id>', methods=['POST'])
def save_fault_record(product_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    
    # GÜVENLİK
    gidecek_yer = erisimi_kontrol_et()
    if gidecek_yer is not None:
        return gidecek_yer
    
    if request.method == 'POST':
        conn = None
        try:
            adet = int(request.form['adet'])
            baslangic_tarihi = request.form['baslangic_tarihi'] 
            islem_tarihi = baslangic_tarihi.replace('T', ' ')
            aciklama = request.form['aciklama']
            
            conn = open_connection()
            cursor = conn.cursor()

            userID=kullaniciIDgetir(session['kullanici_adi'])
                
            cursor.execute("""
                INSERT INTO Maintenance 
                (Product_id, PerformedByUser_id, MaintenanceStartDate, Description_, StatusAfter_id, QuantityOnMaintenance)
                VALUES (?, ?, ?, ?, 1, ?)
            """, (product_id,userID, islem_tarihi, aciklama, adet ))
            
            conn.commit()
            logla(userID,14,9)
            flash(f"{adet} adet ürün başarıyla bakıma alındı.", "success")

        except Exception as e:
            if conn: conn.rollback() # Hata oldu, işlemleri geri al (Eski haline döndür)
            print("Kayıt Hatası:", e)
            flash("İşlem sırasında bir hata oluştu: " + str(e), "danger")
            return redirect(url_for('open_create_fault_record_page', product_id=product_id))
            
        finally:
            if conn: 
                conn.close()

        # İşlem başarılı, Arıza Kaydı Açılanlar (Status=1) listesine yönlendir
        return redirect(url_for('open_maintenance_repair_page', status=1))
    

#ürünün tüm detay bilgileri çekilecek
@app.route('/maintenance-repair/details/<int:maintenance_id>')
def open_maintenance_details_page(maintenance_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    conn=None
    try:
        conn=open_connection()
        cursor=conn.cursor()
        cursor.execute('EXEC sp_BakimDetaylariniGetir ?',(maintenance_id,))
        urun_detayi=cursor.fetchone()
        if urun_detayi is None:
            flash("Kayıt bulunamadı.", "warning")
            return redirect(url_for('open_maintenance_repair_page'))
        
        urun_id=urun_detayi[0]
        cursor.execute("EXEC sp_UrunGecmisiniGetir ?",(urun_id,))
        gecmis_veriler=cursor.fetchall()
    
        cursor.execute("SELECT * FROM MaintenanceStatus")
        status=cursor.fetchall()
        
        return render_template('maintenance_details.html',product=urun_detayi,history=gecmis_veriler, durumlar=status)
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")
        return redirect(url_for('open_maintenance_repair_page'))
    finally:
        if conn: 
            conn.close()

@app.route('/maintenance-repair/update/<int:bakim_id>', methods=['POST'])
def update_maintenance_status(bakim_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    
    # GÜVENLİK
    gidecek_yer = erisimi_kontrol_et()
    if gidecek_yer is not None:
        return gidecek_yer
        
    user_id=kullaniciIDgetir(session.get('kullanici_adi'))
    conn=None
    try:
        conn=open_connection()
        cursor=conn.cursor()
        yeni_durum=request.form['yeni_durum_id']
        alınanTarih=request.form['tarih']
        tarih=alınanTarih.replace('T', ' ')
        not_=request.form['yeni_aciklama']

        sql_update="""UPDATE Maintenance
                    SET StatusAfter_id = ?, 
                        Description_ = ?, 
                        MaintenanceEndDate = ? 
                    WHERE MaintenanceId = ?"""
        cursor.execute(sql_update, (yeni_durum, not_, tarih, bakim_id))
        conn.commit()
        if yeni_durum in [7,9]:
            logla(user_id,15,9,bakim_id)
        elif yeni_durum==10:
            logla(user_id,16,9,bakim_id)
        else:
            logla(user_id,17,9,bakim_id)
        flash(f"{bakim_id} başarıyla güncellendi.", "success")
        return redirect(url_for('open_maintenance_details_page', maintenance_id=bakim_id))
    except Exception as e:
        print(f"Veri Çekme Hatası: {e}")
        flash("Sistem hatası oluştu, veriler yüklenemedi.", "danger")
        return redirect(url_for('open_maintenance_repair_page'))
    finally:
        if conn: 
            conn.close()
    

@app.route('/reports')
def open_reports_page():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    return render_template('reports.html')

@app.route('/reports/view/<int:report_id>', methods=['GET', 'POST'])
def open_generic_reports_page(report_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    conn = open_connection()
    cursor = conn.cursor()
    
    basliklar = []      # Tablo sütun isimleri 
    rapor_adi = ""      # Sayfanın başlığı
    veriler = []        # SQL'den gelen satırlar

    kategoriler_listesi = []
    durumlar_listesi = []

    try:
        # TÜM ÜRÜNLER
        if report_id == 1:
            rapor_adi = "📦 Tüm Ürünlerin Bilgileri"
            # HTML Tablosunda görünecek başlıklar (Sırası SQL ile aynı olmalı!)
            basliklar = ["Ürün Resmi","Ürün Kodu", "Ürün Adı", "Kategori", "Stok Adedi", "Giriş Tarihi", "Garanti Bitiş Traihi", "Konumu","Durumu","Ekleyen Kullanıcı"]
            
            cursor.execute("SELECT CategoryId, CategoryName FROM ProductCategory")
            kategoriler_listesi = cursor.fetchall()

            # Filtreleme 
            if request.method == 'POST':
                kategori = request.form.get('filter_1') 
                if not kategori: kategori = None
                max_stok = request.form.get('filter_2')
                if not max_stok: max_stok = None
                cursor.execute("EXEC sp_Rapor_Urunler ?, ?", (kategori,max_stok))
            else:
                cursor.execute("EXEC sp_Rapor_Urunler")
                
        
        # --- SENARYO 2: STOK İŞLEMLERİ ---
        elif report_id == 2:
            rapor_adi = "🔄 Stok Giriş/Çıkış Hareketleri"
            basliklar = ["Ürün Resmi", "Tarih", "Ürün Kodu","Ürün Adı", "Yapan Kişi", "İşlem Türü", "Miktar", "Not"]
            
            if request.method == 'POST':
                tarih = request.form.get('filter_tarih') 
                if tarih=='' or tarih is None: tarih = None
                else: tarih = tarih.replace('T', ' ')
                islemTipi = request.form.get('filter_islemTipi')
                if islemTipi is None or islemTipi=='': islemTipi = None
                else: islemTipi = int(islemTipi)
                cursor.execute("EXEC sp_Rapor_Islemler ?, ?", (tarih,islemTipi))
            else:
                cursor.execute("EXEC sp_Rapor_Islemler")

        # --- SENARYO 3: BAKIM KAYITLARI ---
        elif report_id == 3:
            rapor_adi = "🛠️ Bakım ve Arıza Kayıtları"
            basliklar = ["Ürün Resmi", "Ürün Adı", "Miktar", "Başlangıç Tarihi", "Bitiş Tarihi", "Açıklama", "Ürün Durumu", "Teknisyen"]
            
            cursor.execute("SELECT mStatusId, mStatusName FROM MaintenanceStatus")
            durumlar_listesi = cursor.fetchall()

            if request.method == 'POST':
                durum = request.form.get('filter_durum') 
                if not durum: durum = None
                tarih = request.form.get('filter_tarih2')
                if tarih=='' or tarih is None: tarih = None
                else: tarih = tarih.replace('T', ' ')
                cursor.execute("EXEC sp_Rapor_Bakimlar ?, ?", (durum,tarih))
            else:
                cursor.execute("EXEC sp_Rapor_Bakimlar")

        # --- SENARYO 4: LOG KAYITLARI ---
        elif report_id == 4:
            rapor_adi = "🛠️ Log (Hareket) Kayıtları"
            basliklar = ["Log ID", "Aksiyon", "Açıklama", "Tarih", "Kullanıcı Adı", "Ad-Soyad", "Departmanı", "Tablo Adı"]
            
            if request.method == 'POST':
                tarih = request.form.get('filter_tarih3')
                if tarih=='' or tarih is None: tarih = None
                else: tarih = tarih.replace('T', ' ')
                cursor.execute("EXEC sp_Rapor_Loglar ?", (tarih,))
            else:
                cursor.execute("EXEC sp_Rapor_Loglar")
        # Verileri çek
        veriler = cursor.fetchall()

    except Exception as e:
        flash(f"Rapor hatası: {e}", "danger")
        veriler = []
    
    finally:
        conn.close()

    # Tek bir HTML sayfasına (generic_report.html) her şeyi gönderiyoruz
    # 'active_id' yi gönderiyoruz ki HTML hangi filtreyi göstereceğini bilsin.
    return render_template('generic_report.html', 
                           report_title=rapor_adi, 
                           headers=basliklar, 
                           data=veriler, 
                           active_id=report_id,
                           categories=kategoriler_listesi,
                           statuses=durumlar_listesi)

@app.route('/product-management', defaults={'op_id': 1},methods=['GET','POST'])
@app.route('/product-management/<int:op_id>', methods=['GET','POST'])
def open_product_management_page(op_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    user_id=kullaniciIDgetir(session.get('kullanici_adi'))
    gecerli_islemler = [1, 2, 3]
    
    if op_id not in gecerli_islemler:
        op_id = 1

    kategoriler_listesi=[]
    birim_listesi=[]
    depo_konumları=[]
    durumlar_listesi=[]
    urunler=[]

    try:
        conn=open_connection()
        cursor=conn.cursor()

        if op_id==1:#ürün ekle
            #sayfa yüklenince olacaklar
            cursor.execute("SELECT CategoryId, CategoryName FROM ProductCategory")
            kategoriler_listesi = cursor.fetchall()
            cursor.execute("SELECT UnitId, UnitName FROM ProductUnit")
            birim_listesi = cursor.fetchall()
            cursor.execute("SELECT LocationId, LocationName FROM WareHouseLocation")
            depo_konumları = cursor.fetchall()
            cursor.execute("SELECT pStatusId, pStatusName FROM ProductStatus")
            durumlar_listesi = cursor.fetchall()

            if request.method == 'POST': #ürün ekleme işlemini gerçekleştir
                    
                # GÜVENLİK
                gidecek_yer = erisimi_kontrol_et()
                if gidecek_yer is not None:
                    return gidecek_yer
    
            
                p_name=request.form['p_name']
                p_code=request.form['p_code']
                p_category_id=request.form['p_category_id']
                p_quantity=request.form['p_quantity']
                p_unit_id=request.form['p_unit_id']
                date=request.form['p_entryDate']
                p_entryDate=date.replace('T', ' ')
                p_warrantyendDate=request.form['p_warrantyendDate']
                p_location_id=request.form['p_location_id']
                p_status_id=request.form['p_status_id']
                p_user_id=kullaniciIDgetir(session['kullanici_adi'])

                p_imagePath = "no-image.png"
                dosya = request.files.get('p_imagePath')
                if dosya and dosya.filename != '':
                    # Dosya adındaki Türkçe karakterleri ve boşlukları temizleme işlemi:
                    filename = secure_filename(dosya.filename)
                    
                    # Dosyayı sunucudaki klasöre fiziksel olarak kaydet
                    # app.config['UPLOAD_FOLDER'] senin 'static/product_images' yolundur
                    dosya.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
                    
                    # Veritabanına gidecek değişkeni güncelle
                    p_imagePath = filename

                cursor.execute("EXEC sp_urunEkle ?,?,?,?,?,?,?,?,?,?,?",(p_name,p_code,p_category_id,p_quantity,p_unit_id,p_entryDate,p_warrantyendDate,p_location_id,p_status_id,p_user_id,p_imagePath))
                yeni_product_id = cursor.fetchone()[0]
                conn.commit()
                logla(user_id,8,4,yeni_product_id)
                flash(f"Ürün envantere eklendi", "success")
        elif op_id==2:#ürün güncelle
            cursor.execute("EXEC sp_UrunleriGetir")
            urunler=cursor.fetchall()
            #güncelleme işlemi için farklı html sayfasına gidilir
        elif op_id==3:#ürün sil
            cursor.execute("EXEC sp_UrunleriGetir")
            urunler=cursor.fetchall()
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        conn.close()
    return render_template('product_management.html',
                           categories=kategoriler_listesi,
                           units=birim_listesi,
                           locations=depo_konumları,
                           statuses=durumlar_listesi,
                           products=urunler,
                           active_id=op_id)

@app.route('/product-management/update-product/<int:product_id>',methods=['POST','GET'])
def open_update_product_page(product_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    user_id=kullaniciIDgetir(session.get('kullanici_adi'))
    urun=[]
    try:
        conn=open_connection()
        cursor=conn.cursor()
        cursor.execute("EXEC sp_UrunleriGetir ?",(product_id,))
        urun=cursor.fetchone()
        
        cursor.execute("SELECT CategoryId, CategoryName FROM ProductCategory")
        kategoriler_listesi = cursor.fetchall()
        cursor.execute("SELECT UnitId, UnitName FROM ProductUnit")
        birim_listesi = cursor.fetchall()
        cursor.execute("SELECT LocationId, LocationName FROM WareHouseLocation")
        depo_konumları = cursor.fetchall()
        cursor.execute("SELECT pStatusId, pStatusName FROM ProductStatus")
        durumlar_listesi = cursor.fetchall()
        
        if request.method=='POST':
                
            # GÜVENLİK
            gidecek_yer = erisimi_kontrol_et()
            if gidecek_yer is not None:
                return gidecek_yer
            
            p_name=temizle(request.form.get("p_name"))
            p_category_id=temizle(request.form.get("p_category_id"))
            p_unit_id=temizle(request.form.get("p_unit_id"))
            p_warrantyendDate=temizle(request.form.get("p_warrantyendDate"))
            p_location_id=temizle(request.form.get("p_location_id"))
            p_status_id=temizle(request.form.get("p_status_id"))
            
            dosya = request.files.get('p_imagePath')
            p_imagePath = None

            if dosya and dosya.filename != '':
                # Eğer yeni resim seçildiyse kaydet ve adını al
                cursor.execute("SELECT ImagePath FROM Products WHERE ProductId = ?", (product_id,))
                eski_resim = cursor.fetchone()[0]
                if eski_resim and eski_resim != 'no-image.png':
                    try:
                        dosya_yolu = os.path.join(current_app.root_path, 'static/product_images', eski_resim)
                        
                        # Dosya gerçekten orada mı diye bak ve sil
                        if os.path.exists(dosya_yolu):
                            os.remove(dosya_yolu)
                            print(f"Eski resim silindi: {eski_resim}")
                    except Exception as e:
                        print(f"Dosya silinirken hata oluştu: {e}")
                filename = secure_filename(dosya.filename)
                dosya.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
                p_imagePath = filename
            else:
                # Resim seçilmediyse None kalsın (SQL'de eskisini koruyacağız)
                p_imagePath = None 

            cursor.execute("EXEC sp_urunGuncelle ?,?,?,?,?,?,?,?",(product_id,p_name,p_category_id,p_unit_id,p_warrantyendDate,p_location_id,p_status_id,p_imagePath))
            logla(user_id,9,4,product_id)
            cursor.commit()
            cursor.execute("EXEC sp_UrunleriGetir ?",(product_id,))
            urun = cursor.fetchone()
            flash("Ürün başarıyla güncellendi!", "success")
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        conn.close()
    return render_template('update_product.html',
                           product=urun,
                           categories=kategoriler_listesi,
                           units=birim_listesi,
                           locations=depo_konumları,
                           statuses=durumlar_listesi)

@app.route('/product-management/delete_product', methods=['POST']) 
def delete_product():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    user_id=kullaniciIDgetir(session.get('kullanici_adi'))
    # GÜVENLİK
    gidecek_yer = erisimi_kontrol_et()
    if gidecek_yer is not None:
        return gidecek_yer
    

    silinecek_urun = request.form.get('deleting_product_id')

    if silinecek_urun:
        conn = open_connection()
        cursor = conn.cursor()

        # SQL Prosedürünü Çağır
        cursor.execute("EXEC sp_Urun_Sil ?", (silinecek_urun,))
        
        conn.commit()
        conn.close()
        logla(user_id,10,4,silinecek_urun)
        flash(f"Ürün ve tüm geçmiş işlemleri başarıyla silindi.", "success")
    else:
        flash("Silinecek ürün seçilmedi!", "warning")

    # İşlem bitince tekrar silme ekranına veya listeye dön
    return redirect(url_for('open_product_management_page', op_id=3))


@app.route('/user-management', defaults={'op_id': 1},methods=['GET','POST'])
@app.route('/user-management/<int:op_id>', methods=['GET','POST'])
def open_user_management_page(op_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
    try:
        conn=open_connection()
        cursor=conn.cursor()

        cursor.execute("SELECT * FROM AccountStatus")  
        statuses=cursor.fetchall()    
        secilen_filtre_id=1
        users=[]
        tum_kullanicilar=[]
        if op_id==1:#kullanıcıları görüntüleme
            cursor.execute("EXEC sp_KullanicilariGetir ?",(1,))
            users=cursor.fetchall()
            
            if request.method=="POST":
                gelen_veri = request.form.get('filter_1')
                secilen_filtre_id = int(gelen_veri) if gelen_veri else 1
                cursor.execute("EXEC sp_KullanicilariGetir ?",(secilen_filtre_id,))
                users=cursor.fetchall()

        elif op_id==2:#güncelleme işlemi
            cursor.execute("EXEC sp_TumKullanicilariGetir ")
            tum_kullanicilar=cursor.fetchall()
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        conn.close()
    return render_template('user_management.html',
                           active_id=op_id,
                           AccountStatuses=statuses,
                           secilen_filtre_id=secilen_filtre_id,
                           users=users,
                           everyone=tum_kullanicilar)


@app.route('/user-management/update-users/<int:user_id>',methods=['POST','GET'])
def open_update_users_page(user_id):
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    
        
    # GÜVENLİK
    gidecek_yer = erisimi_kontrol_et()
    if gidecek_yer is not None:
        return gidecek_yer
    try:
        conn=open_connection()
        cursor=conn.cursor()
        cursor.execute("EXEC sp_KullaniciAl ?",(user_id))
        user=cursor.fetchone()
        cursor.execute("SELECT DepartmentId, DepartmentName FROM UserDepartment")
        departmanlar=cursor.fetchall()
        cursor.execute("SELECT aStatusId, aStatusName FROM AccountStatus")
        durumlar=cursor.fetchall()

         
        if request.method=='POST':
            department_id=int(temizle(request.form.get("departman_id")))
            role_=int(temizle(request.form.get("role_")))
            accountStatus_id=int(temizle(request.form.get("accountStatus_id")))
            is_on_leave=int(temizle(request.form.get("is_on_leave")))
            access_pending=int(temizle(request.form.get("access_pending")))

            cursor.execute("EXEC sp_KullaiciBilgileriniGuncelle ?,?,?,?,?,?",(user_id,department_id,role_,accountStatus_id,is_on_leave,access_pending))
            cursor.commit()
            cursor.execute("EXEC sp_KullaniciAl ?",(user_id))
            user=cursor.fetchone()
            logla(user_id,12,1,user_id)
            flash("Kullanıcı başarıyla güncellendi!", "success")
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        conn.close()
    return render_template('update_users.html',
                           user=user,
                           departments=departmanlar,
                           statuses=durumlar,
                           userid=user_id)


@app.route('/sifre-degistir',methods=['POST','GET'])
def sifre_degistir():
    if 'oturum' not in session:
        return redirect(url_for('open_login_page'))
    conn=None
    veri=[]
    try:
        if session['kullanici_adi']:
            user_id=kullaniciIDgetir(session.get('kullanici_adi'))
            conn=open_connection()
            cursor=conn.cursor()
            cursor.execute("SELECT UserName, e_mail FROM Users WHERE UserId=?",(user_id,))
            veri=cursor.fetchone()
        if request.method=='POST':
            if conn==None:
                conn=open_connection()
                cursor=conn.cursor()
            kullanici_adi=request.form.get('kullanici_adi')
            e_mail=request.form.get('e_mail')
            sifre=request.form.get('sifre')
            sifreTekrar=request.form.get('sifreTekrar')
            if len(sifre)<10:
                flash("Girdiğiniz şifre en az 10 karakterden oluşmalı! Lütfen tekrar deneyin.", "danger")
                return render_template('change_password.html',data=veri)
            if (sifre==sifreTekrar):
                sifreHash=sifrele(sifre)
                cursor.execute("EXEC sp_sifreDegistir ?,?,?,?",(user_id,kullanici_adi,e_mail,sifreHash))
                conn.commit()
                logla(user_id,5,1,user_id)
                flash("Kullanıcı şifresi başarıyla güncellendi!", "success")
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        if conn: conn.close()
    return render_template('change_password.html',
                           data=veri)

@app.route('/sifremi-unuttum',methods=['GET','POST'])
def sifremi_unuttum():
    conn=None
    try:
        if request.method=='POST':
            kullanici_adi=request.form.get('kullanici_adi')
            user_id=kullaniciIDgetir(kullanici_adi)
            if user_id is None:
                flash("Böyle bir kullanıcı bulunamadı!", "danger")
                return redirect(url_for('sifremi_unuttum'))
            e_mail=request.form.get('e_mail')
            sifre=request.form.get('sifre')
            sifreTekrar=request.form.get('sifreTekrar')
            if len(sifre)<10:
                flash("Girdiğiniz şifre en az 10 karakterden oluşmalı! Lütfen tekrar deneyin.", "danger")
                return redirect(url_for('sifremi_unuttum'))
            if (sifre==sifreTekrar):
                sifreHash=sifrele(sifre)
                conn=open_connection()
                cursor=conn.cursor()

                # ODBC Standart Çağrı (CALL kullanımı daha güvenlidir)
                sql_query = "{CALL sp_sifreDegistir (?, ?, ?, ?)}"
                # Parametre sırası SP ile birebir aynı olmalı:
                values = (user_id, kullanici_adi, e_mail, sifreHash)
                
                cursor.execute(sql_query, values)
                conn.commit()

                logla(user_id,5,1,user_id)
                flash("Kullanıcı şifresi başarıyla güncellendi!", "success")
                return redirect(url_for('open_login_page'))
            else:
                flash("Girdiğiniz şifreler birbirine uyuşmuyor","danger")
                return redirect(url_for('sifremi_unuttum'))
    except Exception as e:
        flash(f"Veri yükleme/gönderme hatası: {e}", "danger")
    finally:
        if conn: conn.close()
    return render_template('forget_password.html')

# --- DOSYANIN EN SONUNDA DA BU OLMALI ---
if __name__ == '__main__':
    app.run(debug=True)