
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'car_ads_list_page.dart';
import 'user_profile_page.dart';

final Map<String, List<String>> cityDistricts = {
  'Adana': ['Aladağ', 'Ceyhan', 'Çukurova', 'Feke', 'İmamoğlu', 'Karaisalı', 'Karataş', 'Kozan', 'Pozantı', 'Saimbeyli', 'Sarıçam', 'Seyhan', 'Tufanbeyli', 'Yumurtalık', 'Yüreğir'],
  'Adıyaman': ['Besni', 'Çelikhan', 'Gerger', 'Gölbaşı', 'Kahta', 'Merkez', 'Samsat', 'Sincik', 'Tut'],
  'Afyonkarahisar': ['Başmakçı', 'Bayat', 'Bolvadin', 'Çay', 'Çobanlar', 'Dazkırı', 'Dinar', 'Emirdağ', 'Evciler', 'Hocalar', 'İhsaniye', 'İscehisar', 'Kızılören', 'Merkez', 'Sandıklı', 'Sinanpaşa', 'Sultandağı', 'Şuhut'],
  'Ağrı': ['Diyadin', 'Doğubayazıt', 'Eleşkirt', 'Hamur', 'Merkez', 'Patnos', 'Taşlıçay', 'Tutak'],
  'Amasya': ['Göynücek', 'Gümüşhacıköy', 'Hamamözü', 'Merkez', 'Merzifon', 'Suluova', 'Taşova'],
  'Ankara': ['Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çankaya', 'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana', 'Kahramankazan', 'Kalecik', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan', 'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle'],
  'Antalya': ['Akseki', 'Aksu', 'Alanya', 'Demre', 'Döşemealtı', 'Elmalı', 'Finike', 'Gazipaşa', 'Gündoğmuş', 'İbradı', 'Kaş', 'Kemer', 'Kepez', 'Konyaaltı', 'Korkuteli', 'Kumluca', 'Manavgat', 'Muratpaşa', 'Serik'],
  'Artvin': ['Ardanuç', 'Arhavi', 'Borçka', 'Hopa', 'Kemalpaşa', 'Merkez', 'Murgul', 'Şavşat', 'Yusufeli'],
  'Aydın': ['Bozdoğan', 'Buharkent', 'Çine', 'Didim', 'Efeler', 'Germencik', 'İncirliova', 'Karacasu', 'Karpuzlu', 'Koçarlı', 'Köşk', 'Kuşadası', 'Kuyucak', 'Nazilli', 'Söke', 'Sultanhisar', 'Yenipazar'],
  'Balıkesir': ['Altıeylül', 'Ayvalık', 'Balya', 'Bandırma', 'Bigadiç', 'Burhaniye', 'Dursunbey', 'Edremit', 'Erdek', 'Gömeç', 'Gönen', 'Havran', 'İvrindi', 'Karesi', 'Kepsut', 'Manyas', 'Marmara', 'Savaştepe', 'Sındırgı', 'Susurluk'],
  'Bilecik': ['Bozüyük', 'Gölpazarı', 'İnhisar', 'Merkez', 'Osmaneli', 'Pazaryeri', 'Söğüt', 'Yenipazar'],
  'Bingöl': ['Adaklı', 'Genç', 'Karlıova', 'Kiğı', 'Merkez', 'Solhan', 'Yayladere', 'Yedisu'],
  'Bitlis': ['Adilcevaz', 'Ahlat', 'Güroymak', 'Hizan', 'Merkez', 'Mutki', 'Tatvan'],
  'Bolu': ['Dörtdivan', 'Gerede', 'Göynük', 'Kıbrıscık', 'Mengen', 'Merkez', 'Mudurnu', 'Seben', 'Yeniçağa'],
  'Burdur': ['Ağlasun', 'Altınyayla', 'Bucak', 'Çavdır', 'Çeltikçi', 'Gölhisar', 'Karamanlı', 'Kemer', 'Merkez', 'Tefenni', 'Yeşilova'],
  'Bursa': ['Büyükorhan', 'Gemlik', 'Gürsu', 'Harmancık', 'İnegöl', 'İznik', 'Karacabey', 'Keles', 'Kestel', 'Mudanya', 'Mustafakemalpaşa', 'Nilüfer', 'Orhaneli', 'Orhangazi', 'Osmangazi', 'Yenişehir', 'Yıldırım'],
  'Çanakkale': ['Ayvacık', 'Bayramiç', 'Biga', 'Bozcaada', 'Çan', 'Eceabat', 'Ezine', 'Gelibolu', 'Gökçeada', 'Lapseki', 'Merkez', 'Yenice'],
  'Çankırı': ['Atkaracalar', 'Bayramören', 'Çerkeş', 'Eldivan', 'Ilgaz', 'Kızılırmak', 'Korgun', 'Kurşunlu', 'Merkez', 'Orta', 'Şabanözü', 'Yapraklı'],
  'Çorum': ['Alaca', 'Bayat', 'Boğazkale', 'Dodurga', 'İskilip', 'Kargı', 'Laçin', 'Mecitözü', 'Merkez', 'Oğuzlar', 'Ortaköy', 'Osmancık', 'Sungurlu', 'Uğurludağ'],
  'Denizli': ['Acıpayam', 'Babadağ', 'Baklan', 'Bekilli', 'Beyağaç', 'Bozkurt', 'Buldan', 'Çal', 'Çameli', 'Çardak', 'Çivril', 'Güney', 'Honaz', 'Kale', 'Merkezefendi', 'Pamukkale', 'Sarayköy', 'Serinhisar', 'Tavas'],
  'Diyarbakır': ['Bağlar', 'Bismil', 'Çermik', 'Çınar', 'Çüngüş', 'Dicle', 'Eğil', 'Ergani', 'Hani', 'Hazro', 'Kayapınar', 'Kocaköy', 'Kulp', 'Lice', 'Silvan', 'Sur', 'Yenişehir'],
  'Edirne': ['Enez', 'Havsa', 'İpsala', 'Keşan', 'Lalapaşa', 'Meriç', 'Merkez', 'Süloğlu', 'Uzunköprü'],
  'Elazığ': ['Ağın', 'Alacakaya', 'Arıcak', 'Baskil', 'Karakoçan', 'Keban', 'Kovancılar', 'Maden', 'Merkez', 'Palu', 'Sivrice'],
  'Erzincan': ['Çayırlı', 'İliç', 'Kemah', 'Kemaliye', 'Merkez', 'Otlukbeli', 'Refahiye', 'Tercan', 'Üzümlü'],
  'Erzurum': ['Aşkale', 'Aziziye', 'Çat', 'Hınıs', 'Horasan', 'İspir', 'Karaçoban', 'Karayazı', 'Köprüköy', 'Narman', 'Oltu', 'Olur', 'Palandöken', 'Pasinler', 'Pazaryolu', 'Şenkaya', 'Tekman', 'Tortum', 'Uzundere', 'Yakutiye'],
  'Eskişehir': ['Alpu', 'Beylikova', 'Çifteler', 'Günyüzü', 'Han', 'İnönü', 'Mahmudiye', 'Mihalgazi', 'Mihalıççık', 'Odunpazarı', 'Sarıcakaya', 'Seyitgazi', 'Sivrihisar', 'Tepebaşı'],
  'Gaziantep': ['Araban', 'İslahiye', 'Karkamış', 'Nizip', 'Nurdağı', 'Oğuzeli', 'Şahinbey', 'Şehitkamil', 'Yavuzeli'],
  'Giresun': ['Alucra', 'Bulancak', 'Çamoluk', 'Çanakçı', 'Dereli', 'Doğankent', 'Espiye', 'Eynesil', 'Görele', 'Güce', 'Keşap', 'Merkez', 'Piraziz', 'Şebinkarahisar', 'Tirebolu', 'Yağlıdere'],
  'Gümüşhane': ['Kelkit', 'Köse', 'Kürtün', 'Merkez', 'Şiran', 'Torul'],
  'Hakkari': ['Çukurca', 'Derecik', 'Merkez', 'Şemdinli', 'Yüksekova'],
  'Hatay': ['Altınözü', 'Antakya', 'Arsuz', 'Belen', 'Defne', 'Dörtyol', 'Erzin', 'Hassa', 'İskenderun', 'Kırıkhan', 'Kumlu', 'Payas', 'Reyhanlı', 'Samandağ', 'Yayladağı'],
  'Isparta': ['Aksu', 'Atabey', 'Eğirdir', 'Gelendost', 'Gönen', 'Keçiborlu', 'Merkez', 'Senirkent', 'Sütçüler', 'Şarkikaraağaç', 'Uluborlu', 'Yalvaç', 'Yenişarbademli'],
  'Mersin': ['Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Çamlıyayla', 'Erdemli', 'Gülnar', 'Mezitli', 'Mut', 'Silifke', 'Tarsus', 'Toroslar', 'Yenişehir'],
  'İstanbul': ['Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü', 'Beyoğlu', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer', 'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla', 'Ümraniye', 'Üsküdar', 'Zeytinburnu'],
  'İzmir': ['Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova', 'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe', 'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz', 'Konak', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar', 'Selçuk', 'Tire', 'Torbalı', 'Urla'],
  'Kars': ['Akyaka', 'Arpaçay', 'Digor', 'Kağızman', 'Merkez', 'Sarıkamış', 'Selim', 'Susuz'],
  'Kastamonu': ['Abana', 'Ağlı', 'Araç', 'Azdavay', 'Bozkurt', 'Cide', 'Çatalzeytin', 'Daday', 'Devrekani', 'Doğanyurt', 'Hanönü', 'İhsangazi', 'İnebolu', 'Küre', 'Merkez', 'Pınarbaşı', 'Seydiler', 'Şenpazar', 'Taşköprü', 'Tosya'],
  'Kayseri': ['Akkışla', 'Bünyan', 'Develi', 'Felahiye', 'Hacılar', 'İncesu', 'Kocasinan', 'Melikgazi', 'Özvatan', 'Pınarbaşı', 'Sarıoğlan', 'Sarız', 'Talas', 'Tomarza', 'Yahyalı', 'Yeşilhisar'],
  'Kırklareli': ['Babaeski', 'Demirköy', 'Kofçaz', 'Lüleburgaz', 'Merkez', 'Pehlivanköy', 'Pınarhisar', 'Vize'],
  'Kırşehir': ['Akçakent', 'Akpınar', 'Boztepe', 'Çiçekdağı', 'Kaman', 'Merkez', 'Mucur'],
  'Kocaeli': ['Başiskele', 'Çayırova', 'Darıca', 'Derince', 'Dilovası', 'Gebze', 'Gölcük', 'İzmit', 'Kandıra', 'Karamürsel', 'Kartepe', 'Körfez'],
  'Konya': ['Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır', 'Cihanbeyli', 'Çeltik', 'Çumra', 'Derbent', 'Derebucak', 'Doğanhisar', 'Emirgazi', 'Ereğli', 'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük', 'Ilgın', 'Kadınhanı', 'Karapınar', 'Karatay', 'Kulu', 'Meram', 'Sarayönü', 'Selçuklu', 'Seydişehir', 'Taşkent', 'Tuzlukçu', 'Yalıhüyük', 'Yunak'],
  'Kütahya': ['Altıntaş', 'Aslanapa', 'Çavdarhisar', 'Domaniç', 'Dumlupınar', 'Emet', 'Gediz', 'Hisarcık', 'Merkez', 'Pazarlar', 'Simav', 'Şaphane', 'Tavşanlı'],
  'Malatya': ['Akçadağ', 'Arapgir', 'Arguvan', 'Battalgazi', 'Darende', 'Doğanşehir', 'Doğanyol', 'Hekimhan', 'Kale', 'Kuluncak', 'Pütürge', 'Yazıhan', 'Yeşilyurt'],
  'Manisa': ['Ahmetli', 'Akhisar', 'Alaşehir', 'Demirci', 'Gölmarmara', 'Gördes', 'Kırkağaç', 'Köprübaşı', 'Kula', 'Salihli', 'Sarıgöl', 'Saruhanlı', 'Selendi', 'Soma', 'Şehzadeler', 'Turgutlu', 'Yunusemre'],
  'Kahramanmaraş': ['Afşin', 'Andırın', 'Çağlayancerit', 'Dulkadiroğlu', 'Ekinözü', 'Elbistan', 'Göksun', 'Nurhak', 'Onikişubat', 'Pazarcık', 'Türkoğlu'],
  'Mardin': ['Artuklu', 'Dargeçit', 'Derik', 'Kızıltepe', 'Mazıdağı', 'Midyat', 'Nusaybin', 'Ömerli', 'Savur', 'Yeşilli'],
  'Muğla': ['Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Kavaklıdere', 'Köyceğiz', 'Marmaris', 'Menteşe', 'Milas', 'Ortaca', 'Seydikemer', 'Ula', 'Yatağan'],
  'Muş': ['Bulanık', 'Hasköy', 'Korkut', 'Malazgirt', 'Merkez', 'Varto'],
  'Nevşehir': ['Acıgöl', 'Avanos', 'Derinkuyu', 'Gülşehir', 'Hacıbektaş', 'Kozaklı', 'Merkez', 'Ürgüp'],
  'Niğde': ['Altunhisar', 'Bor', 'Çamardı', 'Çiftlik', 'Merkez', 'Ulukışla'],
  'Ordu': ['Akkuş', 'Altınordu', 'Aybastı', 'Çamaş', 'Çatalpınar', 'Çaybaşı', 'Fatsa', 'Gölköy', 'Gülyalı', 'Gürgentepe', 'İkizce', 'Kabadüz', 'Kabataş', 'Korgan', 'Kumru', 'Mesudiye', 'Perşembe', 'Ulubey', 'Ünye'],
  'Rize': ['Ardeşen', 'Çamlıhemşin', 'Çayeli', 'Derepazarı', 'Fındıklı', 'Güneysu', 'Hemşin', 'İkizdere', 'İyidere', 'Kalkandere', 'Merkez', 'Pazar'],
  'Sakarya': ['Adapazarı', 'Akyazı', 'Arifiye', 'Erenler', 'Ferizli', 'Geyve', 'Hendek', 'Karapürçek', 'Karasu', 'Kaynarca', 'Kocaali', 'Pamukova', 'Sapanca', 'Serdivan', 'Söğütlü', 'Taraklı'],
  'Samsun': ['Alaçam', 'Asarcık', 'Atakum', 'Ayvacık', 'Bafra', 'Canik', 'Çarşamba', 'Havza', 'İlkadım', 'Kavak', 'Ladik', 'Ondokuzmayıs', 'Salıpazarı', 'Tekkeköy', 'Terme', 'Vezirköprü', 'Yakakent'],
  'Siirt': ['Baykan', 'Eruh', 'Kurtalan', 'Merkez', 'Pervari', 'Şirvan', 'Tillo'],
  'Sinop': ['Ayancık', 'Boyabat', 'Dikmen', 'Durağan', 'Erfelek', 'Gerze', 'Merkez', 'Saraydüzü', 'Türkeli'],
  'Sivas': ['Akıncılar', 'Altınyayla', 'Divriği', 'Doğanşar', 'Gemerek', 'Gölova', 'Gürün', 'Hafik', 'İmranlı', 'Kangal', 'Koyulhisar', 'Merkez', 'Suşehri', 'Şarkışla', 'Ulaş', 'Yıldızeli', 'Zara'],
  'Tekirdağ': ['Çerkezköy', 'Çorlu', 'Ergene', 'Hayrabolu', 'Kapaklı', 'Malkara', 'Marmaraereğlisi', 'Muratlı', 'Saray', 'Süleymanpaşa', 'Şarköy'],
  'Tokat': ['Almus', 'Artova', 'Başçiftlik', 'Erbaa', 'Merkez', 'Niksar', 'Pazar', 'Reşadiye', 'Sulusaray', 'Turhal', 'Yeşilyurt', 'Zile'],
  'Trabzon': ['Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Çaykara', 'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Of', 'Ortahisar', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir', 'Yomra'],
  'Tunceli': ['Çemişgezek', 'Hozat', 'Mazgirt', 'Merkez', 'Nazımiye', 'Ovacık', 'Pertek', 'Pülümür'],
  'Şanlıurfa': ['Akçakale', 'Birecik', 'Bozova', 'Ceylanpınar', 'Eyyübiye', 'Halfeti', 'Haliliye', 'Harran', 'Hilvan', 'Karaköprü', 'Siverek', 'Suruç', 'Viranşehir'],
  'Uşak': ['Banaz', 'Eşme', 'Karahallı', 'Merkez', 'Sivaslı', 'Ulubey'],
  'Van': ['Bahçesaray', 'Başkale', 'Çaldıran', 'Çatak', 'Edremit', 'Erciş', 'Gevaş', 'Gürpınar', 'İpekyolu', 'Muradiye', 'Özalp', 'Saray', 'Tuşba'],
  'Yozgat': ['Akdağmadeni', 'Aydıncık', 'Boğazlıyan', 'Çandır', 'Çayıralan', 'Çekerek', 'Kadışehri', 'Merkez', 'Saraykent', 'Sarıkaya', 'Sorgun', 'Şefaatli', 'Yenifakılı', 'Yerköy'],
  'Zonguldak': ['Alaplı', 'Çaycuma', 'Devrek', 'Ereğli', 'Gökçebey', 'Kilimli', 'Kozlu', 'Merkez'],
  'Aksaray': ['Ağaçören', 'Eskil', 'Gülağaç', 'Güzelyurt', 'Merkez', 'Ortaköy', 'Sarıyahşi', 'Sultanhanı'],
  'Bayburt': ['Aydıntepe', 'Demirözü', 'Merkez'],
  'Karaman': ['Ayrancı', 'Başyayla', 'Ermenek', 'Kazımkarabekir', 'Merkez', 'Sarıveliler'],
  'Kırıkkale': ['Bahşılı', 'Balışeyh', 'Çelebi', 'Delice', 'Karakeçili', 'Keskin', 'Merkez', 'Sulakyurt', 'Yahşihan'],
  'Batman': ['Beşiri', 'Gercüş', 'Hasankeyf', 'Kozluk', 'Merkez', 'Sason'],
  'Şırnak': ['Beytüşşebap', 'Cizre', 'Güçlükonak', 'İdil', 'Merkez', 'Silopi', 'Uludere'],
  'Bartın': ['Amasra', 'Kurucaşile', 'Merkez', 'Ulus'],
  'Ardahan': ['Çıldır', 'Damal', 'Göle', 'Hanak', 'Merkez', 'Posof'],
  'Iğdır': ['Aralık', 'Karakoyunlu', 'Merkez', 'Tuzluca'],
  'Yalova': ['Altınova', 'Armutlu', 'Çınarcık', 'Çiftlikköy', 'Merkez', 'Termal'],
  'Karabük': ['Eflani', 'Eskipazar', 'Merkez', 'Ovacık', 'Safranbolu', 'Yenice'],
  'Kilis': ['Elbeyli', 'Merkez', 'Musabeyli', 'Polateli'],
  'Osmaniye': ['Bahçe', 'Düziçi', 'Hasanbeyli', 'Kadirli', 'Merkez', 'Sumbas', 'Toprakkale'],
  'Düzce': ['Akçakoca', 'Cumayeri', 'Çilimli', 'Gölyaka', 'Gümüşova', 'Kaynaşlı', 'Merkez', 'Yığılca'],
};

enum _FollowListType { followers, following }

class ProfilePage extends StatefulWidget {
  final String? userId;
  final String? userEmail;

  const ProfilePage({
    super.key,
    this.userId,
    this.userEmail,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? get _me => _auth.currentUser;
  String get _profileUid => widget.userId ?? _me?.uid ?? '';
  bool get _isOwnProfile => widget.userId == null || widget.userId == _me?.uid;

  int _tabIndex = 0;

  late Future<DocumentSnapshot<Map<String, dynamic>>> _profileFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _postsFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _adsFuture;
  late Future<List<CarAd>> _favoriteAdsFuture;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      _db.collection('users').doc(_profileUid);

  @override
  void initState() {
    super.initState();
    if (_profileUid.isNotEmpty) {
      _reloadFutures();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureUserDoc();
      await _recordProfileView();
      if (!mounted) return;
      setState(_reloadFutures);
    });
  }

  void _reloadFutures() {
    if (_profileUid.isEmpty) return;
    _profileFuture = _profileRef.get();
    _postsFuture = _db
        .collection('posts')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();

    _adsFuture = _db
        .collection('carAds')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();

    _favoriteAdsFuture = _loadFavoriteAds();
  }

  Future<List<CarAd>> _loadFavoriteAds() async {
    if (_profileUid.isEmpty) return <CarAd>[];

    final favoriteSnap = await _db
        .collection('users')
        .doc(_profileUid)
        .collection('favoriteCarAds')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();

    final ids = favoriteSnap.docs
        .map((doc) => _safeString(doc.data()['adId'], fallback: doc.id))
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return <CarAd>[];

    final favoriteAds = <CarAd>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();
      final adsSnap = await _db
          .collection('carAds')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in adsSnap.docs) {
        final data = doc.data();
        if (data['deleted'] == true) continue;
        if ((data['status'] ?? 'active').toString() != 'active') continue;
        favoriteAds.add(CarAd.fromDoc(doc));
      }
    }

    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    favoriteAds.sort((a, b) => (order[a.id] ?? 999999).compareTo(order[b.id] ?? 999999));
    return favoriteAds;
  }

  Future<void> _removeFavoriteAd(String adId) async {
    if (_profileUid.isEmpty || adId.trim().isEmpty) return;

    await _db
        .collection('users')
        .doc(_profileUid)
        .collection('favoriteCarAds')
        .doc(adId)
        .delete();

    if (!mounted) return;
    setState(() {
      _favoriteAdsFuture = _loadFavoriteAds();
    });
  }

  Future<void> _ensureUserDoc() async {
    final user = _me;
    if (user == null || !_isOwnProfile) return;

    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};

    await ref.set({
      'uid': user.uid,
      'email': (data['email'] ?? user.email ?? widget.userEmail ?? '').toString(),
      'displayName': (data['displayName'] ?? user.displayName ?? '').toString(),
      'username': (data['username'] ?? _makeUsername(user.email ?? user.displayName ?? 'nova')).toString(),
      'photoUrl': (data['photoUrl'] ?? user.photoURL ?? '').toString(),
      'phoneVisible': data['phoneVisible'] == true,
      'privateProfile': data['privateProfile'] == true,
      'profileCompleted': _profileCompleted(data),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!doc.exists) 'createdAt': FieldValue.serverTimestamp(),
      if (!doc.exists) 'followersCount': 0,
      if (!doc.exists) 'followingCount': 0,
      if (!doc.exists) 'profileViewsCount': 0,
    }, SetOptions(merge: true));
  }

  bool _profileCompleted(Map<String, dynamic> data) {
    final name = _safeString(data['displayName'] ?? data['fullName']);
    final username = _safeString(data['username']);
    final city = _safeString(data['city'] ?? data['il']);
    final district = _safeString(data['district'] ?? data['ilce'] ?? data['ilçe']);
    final phone = _safeString(data['phone']);
    return name.isNotEmpty &&
        username.isNotEmpty &&
        city.isNotEmpty &&
        district.isNotEmpty &&
        _validPhone(phone);
  }

  Future<void> _recordProfileView() async {
    final viewer = _me;
    if (viewer == null || _profileUid.isEmpty || viewer.uid == _profileUid) return;

    try {
      final viewerSnap = await _db.collection('users').doc(viewer.uid).get();
      final viewerData = viewerSnap.data() ?? <String, dynamic>{};

      final viewerUsername = _safeString(
        viewerData['username'],
        fallback: _safeString(viewer.displayName, fallback: 'nova.user'),
      ).replaceAll('@', '');

      final viewerName = _safeString(
        viewerData['displayName'] ?? viewerData['fullName'] ?? viewerData['name'],
        fallback: _safeString(viewer.displayName, fallback: viewerUsername),
      );

      final viewerPhoto = _safeString(
        viewerData['photoUrl'] ??
            viewerData['profileImage'] ??
            viewerData['profileImageUrl'] ??
            viewerData['userPhoto'] ??
            viewerData['avatarUrl'],
        fallback: _safeString(viewer.photoURL),
      );

      final id = '${_profileUid}_${viewer.uid}';
      final batch = _db.batch();

      batch.set(_db.collection('profileViews').doc(id), {
        'id': id,
        'userId': _profileUid,
        'profileUserId': _profileUid,
        'viewerUserId': viewer.uid,
        'viewerUid': viewer.uid,
        'viewerEmail': viewer.email ?? '',
        'viewerUsername': viewerUsername,
        'viewerName': viewerName,
        'viewerDisplayName': viewerName,
        'viewerPhotoUrl': viewerPhoto,
        'viewerPhoto': viewerPhoto,
        'viewCount': FieldValue.increment(1),
        'lastViewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(_profileRef, {
        'profileViewsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (_) {
      // Profil görüntüleme kaydı başarısız olursa profil sayfası açılmaya devam eder.
    }
  }

  String _makeUsername(String source) {
    final clean = source
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    return clean.isEmpty ? 'nova_user' : clean;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream() {
    return _db
        .collection('posts')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _adsStream() {
    return _db
        .collection('carAds')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeStoriesStream() {
    return _db
        .collection('stories')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> _refresh() async {
    if (_profileUid.isEmpty) return;
    setState(_reloadFutures);
    await Future.wait<dynamic>([
      _profileFuture,
      _postsFuture,
      _adsFuture,
      _favoriteAdsFuture,
    ]);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openWebsite(String value) async {
    final website = value.trim();
    if (website.isEmpty) return;
    if (!website.startsWith('https://')) {
      _snack('Web sitesi https:// ile başlamalı.');
      return;
    }
    final uri = Uri.tryParse(website);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Web sitesi açılamadı.');
  }

  Future<String?> _pickAndUploadProfilePhoto() async {
    final user = _me;
    if (user == null) return null;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (picked == null) return null;

    final path = 'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    await ref.putFile(
      File(picked.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uid': user.uid, 'type': 'profile_photo'},
      ),
    );
    return ref.getDownloadURL();
  }

  Future<void> _openOwnActiveStories() async {
    final snap = await _db
        .collection('stories')
        .where('userId', isEqualTo: _profileUid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final stories = snap.docs.where((doc) {
      final data = doc.data();
      final active = data['active'] != false;
      final created = _toDate(data['createdAt'], fallback: DateTime.now());
      final expires = _toDate(data['expiresAt'], fallback: created.add(const Duration(hours: 24)));
      return active && DateTime.now().isBefore(expires);
    }).map(StoryItem.fromDoc).toList();

    if (!mounted) return;
    if (stories.isEmpty) {
      _snack('Aktif story yok.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StoryViewerPage(stories: stories),
      ),
    );
  }

  void _openProfilePhotoPreview(String imageUrl) {
    if (imageUrl.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ImagePreviewPage(imageUrl: imageUrl),
      ),
    );
  }

  void _openEditProfile(NovaProfile profile) {
    if (!_isOwnProfile) return;
    _showHalfSheet(
      heightFactor: 0.80,
      child: _EditProfileSheet(
        profile: profile,
        email: _me?.email ?? profile.email,
        onPickPhoto: _pickAndUploadProfilePhoto,
        onSave: (value) async {
          final displayName = value.displayName.trim();
          final normalizedUsername = value.username.trim().toLowerCase().replaceAll('@', '');
          final cityName = value.city.trim();
          final districtName = value.district.trim();
          final phone = '+90${value.phoneDigits}';
          final website = value.website.trim();

          if (displayName.isEmpty) return 'Ad soyad alanı zorunlu.';
          if (normalizedUsername.isEmpty) return 'Kullanıcı adı alanı zorunlu.';
          if (!RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(normalizedUsername)) {
            return 'Kullanıcı adı 3-24 karakter olmalı; sadece küçük harf, rakam, nokta ve alt çizgi kullan.';
          }
          if (cityName.isEmpty) return 'İl seçimi zorunlu.';
          if (districtName.isEmpty) return 'İlçe seçimi zorunlu.';
          if (!_validPhone(phone)) return 'Telefon numarası +90 sonrası 10 hane olmalı.';
          if (website.isNotEmpty && !website.startsWith('https://')) {
            return 'Web sitesi sadece https:// ile başlamalı.';
          }

          final usernameRef = _db.collection('usernames').doc(normalizedUsername);
          final oldUsername = profile.usernameText.trim().toLowerCase().replaceAll('@', '');
          final oldUsernameRef = _db.collection('usernames').doc(oldUsername);

          try {
            await _db.runTransaction((transaction) async {
              final usernameSnap = await transaction.get(usernameRef);
              if (usernameSnap.exists) {
                final ownerUid = (usernameSnap.data()?['uid'] ?? '').toString();
                if (ownerUid.isNotEmpty && ownerUid != _profileUid) {
                  throw StateError('Bu kullanıcı adı daha önce alındı.');
                }
              }

              transaction.set(usernameRef, {
                'uid': _profileUid,
                'username': normalizedUsername,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (oldUsername.isNotEmpty && oldUsername != normalizedUsername) {
                transaction.delete(oldUsernameRef);
              }

              transaction.set(_profileRef, {
                'displayName': displayName,
                'username': normalizedUsername,
                'city': cityName,
                'district': districtName,
                'bio': value.bio.trim(),
                'phone': phone,
                'phoneVisible': value.phoneVisible,
                'website': website,
                if (value.photoUrl.trim().isNotEmpty) 'photoUrl': value.photoUrl.trim(),
                'profileCompleted': true,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            });
            if (mounted) setState(_reloadFutures);
            return null;
          } on StateError catch (e) {
            return e.message;
          } catch (_) {
            return 'Profil kaydedilemedi. İnternet bağlantısını ve Firebase kurallarını kontrol et.';
          }
        },
      ),
    );
  }

  void _openMenu(NovaProfile profile) {
    _showFullScreenSheet(
      child: _ProfileMenuNavigatorSheet(
        profile: profile,
        isOwnProfile: _isOwnProfile,
        db: _db,
        profileUid: _profileUid,
        profileRef: _profileRef,
      ),
    );
  }

  void _openArchiveSheet() {
    Navigator.pop(context);
    _showHalfSheet(
      child: _PostsListSheet(
        title: 'Post Arşivi',
        stream: _db
            .collection('posts')
            .where('userId', isEqualTo: _profileUid)
            .where('isArchived', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(80)
            .snapshots(),
        db: _db,
        isOwner: _isOwnProfile,
        archiveMode: true,
      ),
    );
  }

  void _openStoryHistorySheet() {
    Navigator.pop(context);
    _showHalfSheet(
      child: _StoryHistorySheet(
        stream: _db
            .collection('stories')
            .where('userId', isEqualTo: _profileUid)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        db: _db,
        profileUid: _profileUid,
        isOwner: _isOwnProfile,
      ),
    );
  }

  void _openSavedPostsSheet() {
    Navigator.pop(context);
    _showHalfSheet(
      child: _SavedPostsSheet(userId: _profileUid, db: _db),
    );
  }

  void _openVisitorsSheet() {
    Navigator.pop(context);
    _showHalfSheet(
      child: _VisitorsSheet(
        stream: _db
            .collection('profileViews')
            .where('profileUserId', isEqualTo: _profileUid)
            .orderBy('lastViewedAt', descending: true)
            .limit(80)
            .snapshots(),
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _showHalfSheet({required Widget child, double heightFactor = 0.62}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenSheet({required Widget child}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _privateGate(NovaProfile profile) {
    if (!profile.privateProfile || _isOwnProfile) return const SizedBox.shrink();
    if (profile.followerIds.contains(_me?.uid)) return const SizedBox.shrink();
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: _PrivateBox(),
      ),
    );
  }


  void _openFollowersDialog(NovaProfile profile) {
    _openUserListDialog(
      title: 'Takipçiler',
      emptyText: 'Henüz takipçi yok.',
      userIds: profile.followerIds,
      listType: _FollowListType.followers,
    );
  }

  void _openFollowingDialog(NovaProfile profile) {
    _openUserListDialog(
      title: 'Takip',
      emptyText: 'Henüz takip edilen kullanıcı yok.',
      userIds: profile.followingIds,
      listType: _FollowListType.following,
    );
  }

  Future<void> _removeFollowerFromProfile(String followerUid) async {
    final myUid = _me?.uid ?? '';
    if (!_isOwnProfile || myUid.isEmpty || _profileUid.isEmpty || followerUid.trim().isEmpty) {
      return;
    }

    try {
      final batch = _db.batch();
      final myRef = _db.collection('users').doc(_profileUid);
      final followerRef = _db.collection('users').doc(followerUid);

      batch.set(myRef, {
        'followerIds': FieldValue.arrayRemove([followerUid]),
        'followers': FieldValue.arrayRemove([followerUid]),
        'followersCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(followerRef, {
        'followingIds': FieldValue.arrayRemove([_profileUid]),
        'following': FieldValue.arrayRemove([_profileUid]),
        'followingCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      setState(_reloadFutures);
      _snack('Takipçi çıkarıldı.');
    } catch (_) {
      _snack('Takipçi çıkarılamadı. Firebase izinlerini kontrol et.');
    }
  }

  Future<void> _unfollowUserFromProfile(String targetUid) async {
    final myUid = _me?.uid ?? '';
    if (!_isOwnProfile || myUid.isEmpty || _profileUid.isEmpty || targetUid.trim().isEmpty) {
      return;
    }

    try {
      final batch = _db.batch();
      final myRef = _db.collection('users').doc(_profileUid);
      final targetRef = _db.collection('users').doc(targetUid);

      batch.set(myRef, {
        'followingIds': FieldValue.arrayRemove([targetUid]),
        'following': FieldValue.arrayRemove([targetUid]),
        'followingCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(targetRef, {
        'followerIds': FieldValue.arrayRemove([_profileUid]),
        'followers': FieldValue.arrayRemove([_profileUid]),
        'followersCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      setState(_reloadFutures);
      _snack('Takip bırakıldı.');
    } catch (_) {
      _snack('Takip bırakılamadı. Firebase izinlerini kontrol et.');
    }
  }

  void _openUserListDialog({
    required String title,
    required String emptyText,
    required List<String> userIds,
    required _FollowListType listType,
  }) {
    final firstIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        var visibleIds = List<String>.from(firstIds);
        var busyUid = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> actionUser(String targetUid) async {
              if (busyUid.isNotEmpty) return;

              setDialogState(() => busyUid = targetUid);

              if (listType == _FollowListType.followers) {
                await _removeFollowerFromProfile(targetUid);
              } else {
                await _unfollowUserFromProfile(targetUid);
              }

              if (!context.mounted) return;
              setDialogState(() {
                visibleIds.remove(targetUid);
                busyUid = '';
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.68,
                  maxWidth: 430,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              textScaler: TextScaler.noScaling,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8E8E8)),
                    Flexible(
                      child: visibleIds.isEmpty
                          ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            emptyText,
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black45,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                          : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                        itemCount: visibleIds.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 12,
                          color: Color(0xFFEDEDED),
                        ),
                        itemBuilder: (context, index) {
                          final userId = visibleIds[index];

                          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _db.collection('users').doc(userId).snapshots(),
                            builder: (context, userSnap) {
                              final data = userSnap.data?.data() ?? <String, dynamic>{};
                              final username = _safeString(
                                data['username'],
                                fallback: _safeString(data['displayName'], fallback: 'nova.user'),
                              ).replaceAll('@', '');
                              final displayName = _safeString(
                                data['displayName'] ?? data['fullName'] ?? data['name'],
                              );
                              final photoUrl = _safeString(
                                data['photoUrl'] ??
                                    data['profileImage'] ??
                                    data['profileImageUrl'] ??
                                    data['userPhoto'] ??
                                    data['avatarUrl'],
                              );

                              final canManage = _isOwnProfile && userId != (_me?.uid ?? '');
                              final buttonText = listType == _FollowListType.followers
                                  ? 'Çıkar'
                                  : 'Bırak';
                              final isBusy = busyUid == userId;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          Navigator.pop(dialogContext);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserProfilePage(userId: userId),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: Colors.black,
                                                backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                                                child: photoUrl.isEmpty
                                                    ? const Icon(Icons.person_rounded, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '@$username',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textScaler: TextScaler.noScaling,
                                                      style: const TextStyle(
                                                        fontFamily: 'Roboto',
                                                        color: Colors.black,
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    if (displayName.isNotEmpty)
                                                      Text(
                                                        displayName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        textScaler: TextScaler.noScaling,
                                                        style: const TextStyle(
                                                          fontFamily: 'Roboto',
                                                          color: Colors.black54,
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (canManage) ...[
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 34,
                                        child: ElevatedButton(
                                          onPressed: isBusy ? null : () => actionUser(userId),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: listType == _FollowListType.followers
                                                ? const Color(0xFFE53935)
                                                : Colors.black,
                                            disabledBackgroundColor: Colors.black26,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: isBusy
                                              ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                              : Text(
                                            buttonText,
                                            textScaler: TextScaler.noScaling,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _me;
    if (user == null || _profileUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Profil için giriş yapman gerekiyor.', style: _boldBlack)),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _profileFuture,
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.white, body: ProfileSkeletonLoading());
        }

        final profile = NovaProfile.fromMap(
          profileSnap.data?.data() ?? <String, dynamic>{},
          fallbackUid: _profileUid,
          fallbackEmail: user.email ?? widget.userEmail ?? '',
          fallbackName: user.displayName ?? '',
          fallbackPhoto: user.photoURL ?? '',
        );

        final locked = profile.privateProfile &&
            !_isOwnProfile &&
            !profile.followerIds.contains(_me?.uid);

        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _postsFuture,
          builder: (context, postsSnap) {
            final visiblePosts = (postsSnap.data?.docs ?? [])
                .where((d) => d.data()['deleted'] != true && d.data()['isArchived'] != true)
                .toList();

            return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _adsFuture,
              builder: (context, adsSnap) {
                final visibleAds = (adsSnap.data?.docs ?? [])
                    .where((d) => d.data()['deleted'] != true && (d.data()['status'] ?? 'active') == 'active')
                    .toList();

                return FutureBuilder<List<CarAd>>(
                  future: _favoriteAdsFuture,
                  builder: (context, favoriteSnap) {
                    final favoriteAds = favoriteSnap.data ?? <CarAd>[];

                    final loadingContent =
                        postsSnap.connectionState == ConnectionState.waiting ||
                            adsSnap.connectionState == ConnectionState.waiting ||
                            favoriteSnap.connectionState == ConnectionState.waiting;

                    return Scaffold(
                      backgroundColor: Colors.white,
                      body: SafeArea(
                        bottom: false,
                        child: RefreshIndicator(
                          color: Colors.black,
                          backgroundColor: Colors.white,
                          onRefresh: _refresh,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    _TopBar(username: profile.usernameText, privateProfile: profile.privateProfile, onMenu: () => _openMenu(profile), onLogout: _logout),
                                    _ProfileHeader(
                                      profile: profile,
                                      postCount: visiblePosts.length,
                                      isOwnProfile: _isOwnProfile,
                                      onEdit: () => _openEditProfile(profile),
                                      onPhotoTap: _openOwnActiveStories,
                                      onPhotoLongPress: () => _openProfilePhotoPreview(profile.photoUrl),
                                      onWebsiteTap: () => _openWebsite(profile.website),
                                      onFollowersTap: () => _openFollowersDialog(profile),
                                      onFollowingTap: () => _openFollowingDialog(profile),
                                    ),
                                    if (!locked)
                                      _ProfileTabs(
                                        selectedIndex: _tabIndex,
                                        onChanged: (v) {
                                          if (_tabIndex == v) return;
                                          setState(() => _tabIndex = v);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              if (locked)
                                _privateGate(profile)
                              else if (loadingContent)
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 280, child: ProfileMiniGridLoading()),
                                )
                              else if (_tabIndex == 0)
                                  _PostsGridSliverDocs(docs: visiblePosts, db: _db, isOwner: _isOwnProfile)
                                else if (_tabIndex == 1)
                                    _AdsGridSliverDocs(docs: visibleAds)
                                  else
                                    _FavoriteAdsSliver(
                                      ads: favoriteAds,
                                      onRemoveFavorite: _removeFavoriteAd,
                                    ),
                              const SliverToBoxAdapter(child: SizedBox(height: 90)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PostsGridSliverDocs extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final FirebaseFirestore db;
  final bool isOwner;

  const _PostsGridSliverDocs({
    required this.docs,
    required this.db,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverToBoxAdapter(child: EmptyGridMessage(icon: Icons.grid_on_rounded, text: 'Henüz gönderi yok'));
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final doc = docs[index];
          return _GridPostTile(
            data: doc.data(),
            onTap: () => _openPostDetail(context, doc.id, doc.data()),
          );
        },
        childCount: docs.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.2,
        crossAxisSpacing: 1.2,
        childAspectRatio: 0.78,
      ),
    );
  }

  void _openPostDetail(BuildContext context, String postId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: _PostDetailSheet(postId: postId, data: data, db: db, isOwner: isOwner),
          ),
        );
      },
    );
  }
}

class _AdsGridSliverDocs extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _AdsGridSliverDocs({required this.docs});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyGridMessage(
          icon: Icons.directions_car_filled_rounded,
          text: 'Henüz ilan yok',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final ad = CarAd.fromDoc(docs[index]);
          return Column(
            children: [
              _ProfileVehicleListTile(
                ad: ad,
                onTap: () => _openAdDetail(context, ad),
              ),
              if (index != docs.length - 1) const GreyThinDivider(),
            ],
          );
        },
        childCount: docs.length,
      ),
    );
  }

  void _openAdDetail(BuildContext context, CarAd ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: CarAdDetailPage(ad: ad),
        ),
      ),
    );
  }
}


class _ProfileVehicleListTile extends StatelessWidget {
  final CarAd ad;
  final VoidCallback onTap;
  final bool showFavoriteHeart;
  final VoidCallback? onFavoriteTap;

  const _ProfileVehicleListTile({
    required this.ad,
    required this.onTap,
    this.showFavoriteHeart = false,
    this.onFavoriteTap,
  });

  String get _brandModelPackage {
    final parts = [ad.brand, ad.series, ad.model, ad.engine]
        .where((e) => e.trim().isNotEmpty && e.trim() != '-')
        .toList();
    if (parts.isEmpty) return 'Araç bilgisi';
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 118,
                height: 126,
                child: NovaNetworkImage(url: ad.image, fit: BoxFit.cover, iconSize: 42),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ad.title,
                          textScaler: TextScaler.noScaling,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.black,
                            fontSize: 14.5,
                            height: 1.16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (showFavoriteHeart) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onFavoriteTap,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _brandModelPackage,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text('Model yılı: ${ad.year}', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('KM: ${ad.km}', textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    ad.location,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.price,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', color: Color(0xFF00A86B), fontSize: 16.5, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FavoriteAdsSliver extends StatelessWidget {
  final List<CarAd> ads;
  final Future<void> Function(String adId) onRemoveFavorite;

  const _FavoriteAdsSliver({
    required this.ads,
    required this.onRemoveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyGridMessage(
          icon: Icons.favorite_border_rounded,
          text: 'Henüz favori araç yok',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final ad = ads[index];
          return Column(
            children: [
              _ProfileVehicleListTile(
                ad: ad,
                showFavoriteHeart: true,
                onFavoriteTap: () => onRemoveFavorite(ad.id),
                onTap: () => _openAdDetail(context, ad),
              ),
              if (index != ads.length - 1) const GreyThinDivider(),
            ],
          );
        },
        childCount: ads.length,
      ),
    );
  }

  void _openAdDetail(BuildContext context, CarAd ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: CarAdDetailPage(ad: ad),
        ),
      ),
    );
  }
}

class ProfileMiniGridLoading extends StatelessWidget {
  const ProfileMiniGridLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 9,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.2,
        crossAxisSpacing: 1.2,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, __) => const ColoredBox(color: Color(0xFFF1F1F1)),
    );
  }
}

enum _ProfileMenuPage { root, archive, storyHistory, saved, visitors, liked, blocked, interactions }

class _ProfileMenuNavigatorSheet extends StatefulWidget {
  final NovaProfile profile;
  final bool isOwnProfile;
  final FirebaseFirestore db;
  final String profileUid;
  final DocumentReference<Map<String, dynamic>> profileRef;

  const _ProfileMenuNavigatorSheet({
    required this.profile,
    required this.isOwnProfile,
    required this.db,
    required this.profileUid,
    required this.profileRef,
  });

  @override
  State<_ProfileMenuNavigatorSheet> createState() => _ProfileMenuNavigatorSheetState();
}

class _ProfileMenuNavigatorSheetState extends State<_ProfileMenuNavigatorSheet> {
  _ProfileMenuPage page = _ProfileMenuPage.root;
  late bool privateProfile;

  @override
  void initState() {
    super.initState();
    privateProfile = widget.profile.privateProfile;
  }

  void _back() {
    if (page == _ProfileMenuPage.root) {
      Navigator.pop(context);
    } else {
      setState(() => page = _ProfileMenuPage.root);
    }
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sayfa açılamadı. Lütfen internet bağlantını kontrol et.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.38),
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Hesabı kalıcı sil',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'Bu işlem hesabını ve NOVA içindeki kullanıcı verilerini siler. İşlem geri alınamaz. Devam etmek istiyor musun?',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Hesabı Sil',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return ok == true;
  }

  Future<void> _deleteQueryDocs(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(450).get();
      if (snap.docs.isEmpty) return;

      final batch = widget.db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < 450) return;
    }
  }

  Future<void> _deleteUserSubCollection(String collectionPath) async {
    await _deleteQueryDocs(widget.db.collection(collectionPath));
  }

  Future<void> _deleteMyAccountNow() async {
    if (!widget.isOwnProfile) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? widget.profileUid;
    if (user == null || uid.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap bulunamadı. Tekrar giriş yapıp dene.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _confirmDeleteAccount();
    if (!ok) return;

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hesabın siliniyor...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      await Future.wait([
        _deleteUserSubCollection('users/$uid/notifications'),
        _deleteUserSubCollection('users/$uid/followRequests'),
        _deleteUserSubCollection('users/$uid/sentFollowRequests'),
        _deleteUserSubCollection('users/$uid/favoriteCarAds'),
      ]);

      await Future.wait([
        _deleteQueryDocs(widget.db.collection('posts').where('userId', isEqualTo: uid)),
        _deleteQueryDocs(widget.db.collection('carAds').where('userId', isEqualTo: uid)),
        _deleteQueryDocs(widget.db.collection('stories').where('userId', isEqualTo: uid)),
        _deleteQueryDocs(widget.db.collection('profileViews').where('profileUserId', isEqualTo: uid)),
        _deleteQueryDocs(widget.db.collection('profileViews').where('viewerUserId', isEqualTo: uid)),
      ]);

      final username = widget.profile.usernameText.trim().toLowerCase().replaceAll('@', '');
      final batch = widget.db.batch();

      batch.delete(widget.db.collection('users').doc(uid));
      if (username.isNotEmpty) {
        batch.delete(widget.db.collection('usernames').doc(username));
      }
      await batch.commit();

      await user.delete();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Güvenlik için önce hesaptan çıkıp tekrar giriş yap, sonra hesabı sil.'
          : 'Hesap silinemedi: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap silinemedi. Firebase kurallarını kontrol et.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 26),
              ),
              _SmallAvatar(imageUrl: widget.profile.photoUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  page == _ProfileMenuPage.root ? widget.profile.displayUsername : _titleFor(page),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _boldBlack,
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black, size: 28),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Colors.black,
            backgroundColor: Colors.white,
            onRefresh: () async {
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 280));
            },
            child: _body(),
          ),
        ),
      ],
    );
  }

  String _titleFor(_ProfileMenuPage page) {
    switch (page) {
      case _ProfileMenuPage.archive:
        return 'Post Arşivi';
      case _ProfileMenuPage.storyHistory:
        return 'Story Geçmişi';
      case _ProfileMenuPage.saved:
        return 'Kaydedilenler';
      case _ProfileMenuPage.visitors:
        return 'Profiline Son Bakanlar';
      case _ProfileMenuPage.liked:
        return 'Son Beğenilenler';
      case _ProfileMenuPage.blocked:
        return 'Engellenenler';
      case _ProfileMenuPage.interactions:
        return 'Etkileşim Sayıları';
      case _ProfileMenuPage.root:
        return widget.profile.displayUsername;
    }
  }

  Widget _body() {
    switch (page) {
      case _ProfileMenuPage.archive:
        return _PostsListSheetBody(
          title: 'Post Arşivi',
          stream: widget.db
              .collection('posts')
              .where('userId', isEqualTo: widget.profileUid)
              .where('isArchived', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(80)
              .snapshots(),
          db: widget.db,
          isOwner: widget.isOwnProfile,
          archiveMode: true,
        );
      case _ProfileMenuPage.storyHistory:
        return _StoryHistorySheetBody(
          stream: widget.db
              .collection('stories')
              .where('userId', isEqualTo: widget.profileUid)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          db: widget.db,
          isOwner: widget.isOwnProfile,
        );
      case _ProfileMenuPage.saved:
        return _SavedPostsSheetBody(userId: widget.profileUid, db: widget.db);
      case _ProfileMenuPage.visitors:
        return _VisitorsSheetBody(
          stream: widget.db
              .collection('profileViews')
              .where('profileUserId', isEqualTo: widget.profileUid)
              .orderBy('lastViewedAt', descending: true)
              .limit(80)
              .snapshots(),
        );
      case _ProfileMenuPage.liked:
        return _LikedPostsSheetBody(userId: widget.profileUid, db: widget.db);
      case _ProfileMenuPage.blocked:
        return _BlockedUsersSheetBody(userId: widget.profileUid, db: widget.db);
      case _ProfileMenuPage.interactions:
        return _InteractionStatsSheetBody(
          userId: widget.profileUid,
          db: widget.db,
          profileStream: widget.profileRef.snapshots(),
        );
      case _ProfileMenuPage.root:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            if (widget.isOwnProfile)
              _MenuSwitchTile(
                icon: Icons.lock_rounded,
                title: privateProfile ? 'Gizli hesap' : 'Herkese açık',
                value: privateProfile,
                onChanged: (v) async {
                  setState(() => privateProfile = v);
                  await widget.profileRef.set({
                    'privateProfile': v,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                },
              ),
            _MenuTile(icon: Icons.archive_outlined, title: 'Post Arşivi', onTap: () => setState(() => page = _ProfileMenuPage.archive)),
            _MenuTile(icon: Icons.history_toggle_off_rounded, title: 'Story Geçmişi', onTap: () => setState(() => page = _ProfileMenuPage.storyHistory)),
            _MenuTile(icon: Icons.bookmark_border_rounded, title: 'Kaydedilenler', onTap: () => setState(() => page = _ProfileMenuPage.saved)),
            _MenuTile(icon: Icons.favorite_border_rounded, title: 'Son Beğenilenler', onTap: () => setState(() => page = _ProfileMenuPage.liked)),
            if (widget.isOwnProfile) ...[
              _MenuTile(icon: Icons.visibility_outlined, title: 'Profiline Son Bakanlar', onTap: () => setState(() => page = _ProfileMenuPage.visitors)),
              _MenuTile(icon: Icons.block_rounded, title: 'Engellenenler Listesi', onTap: () => setState(() => page = _ProfileMenuPage.blocked)),
              _MenuTile(icon: Icons.analytics_outlined, title: 'Etkileşim Sayıları', onTap: () => setState(() => page = _ProfileMenuPage.interactions)),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                'Bilgilendirme',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik Politikası',
              onTap: () => _openLegalUrl('https://kaanayaz.com.tr/privacy-policy.html'),
            ),
            _MenuTile(
              icon: Icons.verified_user_outlined,
              title: 'Güvenlik Standartları',
              onTap: () => _openLegalUrl('https://kaanayaz.com.tr/child-safety-standards.html'),
            ),
            _MenuTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Hesap Silme Talebi',
              onTap: () => _openLegalUrl('https://kaanayaz.com.tr/nova-delete-account.html'),
            ),
            if (widget.isOwnProfile)
              _MenuTile(
                icon: Icons.delete_forever_rounded,
                title: 'Hesabımı Kalıcı Sil',
                onTap: _deleteMyAccountNow,
              ),
          ],
        );
    }
  }
}

class _PostsListSheetBody extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final FirebaseFirestore db;
  final bool isOwner;
  final bool archiveMode;

  const _PostsListSheetBody({
    required this.title,
    required this.stream,
    required this.db,
    required this.isOwner,
    required this.archiveMode,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
        if (docs.isEmpty) return Center(child: Text('$title boş.', style: _mutedBold));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _ArchivePostTile(
              data: data,
              isOwner: isOwner,
              archiveMode: archiveMode,
              onUnarchive: () => db.collection('posts').doc(doc.id).set({'isArchived': false, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
              onDelete: () => db.collection('posts').doc(doc.id).set({'deleted': true, 'active': false, 'deletedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
            );
          },
        );
      },
    );
  }
}

class _StoryHistorySheetBody extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final FirebaseFirestore db;
  final bool isOwner;

  const _StoryHistorySheetBody({
    required this.stream,
    required this.db,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
        if (docs.isEmpty) return const Center(child: Text('Story geçmişi boş.', style: _mutedBold));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final image = _safeString(data['imageUrl'] ?? data['mediaUrl'] ?? data['storyImage'] ?? data['image']);
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (image.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => _ImagePreviewPage(imageUrl: image)));
                      }
                    },
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 66, height: 66, child: _ImageBox(imageUrl: image, emptyIcon: Icons.auto_awesome_rounded))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_dateText(_toDate(data['createdAt'])), style: _mutedBold)),
                  if (isOwner)
                    TextButton(
                      onPressed: () => db.collection('stories').doc(doc.id).delete(),
                      child: const Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SavedPostsSheetBody extends StatelessWidget {
  final String userId;
  final FirebaseFirestore db;

  const _SavedPostsSheetBody({required this.userId, required this.db});

  @override
  Widget build(BuildContext context) {
    final stream = db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final savedDocs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }
        if (savedDocs.isEmpty) {
          return const Center(child: Text('Kaydedilen gönderi yok.', style: _mutedBold));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: savedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final savedDoc = savedDocs[index];
            final savedData = savedDoc.data();
            final postId = _safeString(savedData['postId'], fallback: savedDoc.id);

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('posts').doc(postId).snapshots(),
              builder: (context, postSnap) {
                if (postSnap.connectionState == ConnectionState.waiting) {
                  return Container(height: 82, decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)));
                }

                final postData = postSnap.data?.data();
                if (postData == null || postData['deleted'] == true) {
                  return _SavedMissingPostTile(
                    onRemove: () => db.collection('users').doc(userId).collection('savedPosts').doc(savedDoc.id).delete(),
                  );
                }

                final username = _safeString(postData['username'] ?? postData['displayName'], fallback: 'nova.user');
                final city = _safeString(postData['userCity'] ?? postData['city'] ?? postData['il']);
                final district = _safeString(postData['userDistrict'] ?? postData['district'] ?? postData['ilce'] ?? postData['ilçe']);
                final location = [city, district].where((e) => e.trim().isNotEmpty).join(' / ');
                final desc = _safeString(postData['caption'] ?? postData['desc'] ?? postData['description']);

                return _SavedPostTile(
                  data: postData,
                  username: username,
                  location: location,
                  desc: desc,
                  onRemove: () => db.collection('users').doc(userId).collection('savedPosts').doc(savedDoc.id).delete(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VisitorsSheetBody extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _VisitorsSheetBody({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
        if (docs.isEmpty) return const Center(child: Text('Profiline bakan kullanıcı yok.', style: _mutedBold));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final viewerUid = _safeString(data['viewerUserId'] ?? data['viewerUid']);
            final username = _safeString(data['viewerUsername']).replaceAll('@', '');
            final displayName = _safeString(
              data['viewerDisplayName'] ?? data['viewerName'] ?? data['viewerEmail'],
              fallback: 'Nova kullanıcısı',
            );
            final photoUrl = _safeString(data['viewerPhotoUrl'] ?? data['viewerPhoto']);
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: viewerUid.isEmpty
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserProfilePage(userId: viewerUid)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    _SmallAvatar(imageUrl: photoUrl, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.isEmpty ? displayName : '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: TextScaler.noScaling,
                            style: _boldBlack,
                          ),
                          if (username.isNotEmpty && displayName.isNotEmpty)
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: _mutedBold,
                            ),
                        ],
                      ),
                    ),
                    Text('${_asInt(data['viewCount'])} kez', style: _mutedBold),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}



class _LikedPostsSheetBody extends StatelessWidget {
  final String userId;
  final FirebaseFirestore db;

  const _LikedPostsSheetBody({required this.userId, required this.db});

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 260, child: Center(child: Text('Kullanıcı bulunamadı.', style: _mutedBold)))],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('posts')
          .where('likedBy', arrayContains: userId)
          .limit(80)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['deleted'] != true && doc.data()['active'] != false)
            .toList();

        docs.sort((a, b) {
          final aDate = _toDate(a.data()['createdAt']);
          final bDate = _toDate(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: 260, child: Center(child: Text('Son beğenilen gönderi yok.', style: _mutedBold)))],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _SavedPostTile(
              data: data,
              username: _safeString(data['username'] ?? data['displayName'], fallback: 'nova.user'),
              location: _safeString(data['location']),
              desc: _safeString(data['caption'] ?? data['desc'] ?? data['description']),
              onRemove: () async {
                await db.collection('posts').doc(doc.id).set({
                  'likedBy': FieldValue.arrayRemove([userId]),
                  'likeCount': FieldValue.increment(-1),
                  'likes': FieldValue.increment(-1),
                  'likesCount': FieldValue.increment(-1),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              },
            );
          },
        );
      },
    );
  }
}

class _BlockedUsersSheetBody extends StatelessWidget {
  final String userId;
  final FirebaseFirestore db;

  const _BlockedUsersSheetBody({required this.userId, required this.db});

  List<String> _blockedIds(Map<String, dynamic> data) {
    final raw = data['blockedUserIds'] ?? data['blockedUsers'] ?? data['blockedIds'] ?? <dynamic>[];
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet().toList();
    }
    return <String>[];
  }

  Future<void> _unblock(String targetUid) async {
    await db.collection('users').doc(userId).set({
      'blockedUserIds': FieldValue.arrayRemove([targetUid]),
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
      'blockedIds': FieldValue.arrayRemove([targetUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }

        final ids = _blockedIds(snapshot.data?.data() ?? <String, dynamic>{});

        if (ids.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: 260, child: Center(child: Text('Engellenen kullanıcı yok.', style: _mutedBold)))],
          );
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: ids.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final blockedUid = ids[index];
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: db.collection('users').doc(blockedUid).snapshots(),
              builder: (context, userSnap) {
                final data = userSnap.data?.data() ?? <String, dynamic>{};
                final username = _safeString(data['username'], fallback: _safeString(data['displayName'], fallback: 'nova.user')).replaceAll('@', '');
                final displayName = _safeString(data['displayName'] ?? data['fullName'] ?? data['name']);
                final photoUrl = _safeString(data['photoUrl'] ?? data['profileImage'] ?? data['profileImageUrl'] ?? data['userPhoto'] ?? data['avatarUrl']);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _SmallAvatar(imageUrl: photoUrl, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: _boldBlack),
                            if (displayName.isNotEmpty)
                              Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: _mutedBold),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _unblock(blockedUid),
                        child: const Text('Engeli kaldır', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _InteractionStatsSheetBody extends StatelessWidget {
  final String userId;
  final FirebaseFirestore db;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream;

  const _InteractionStatsSheetBody({
    required this.userId,
    required this.db,
    required this.profileStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, profileSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('posts').where('userId', isEqualTo: userId).limit(200).snapshots(),
          builder: (context, postSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting || postSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }

            final profile = profileSnap.data?.data() ?? <String, dynamic>{};
            final posts = (postSnap.data?.docs ?? []).map((e) => e.data()).toList();
            int totalLikes = 0;
            int totalComments = 0;
            int totalSaves = 0;
            int totalShares = 0;
            int totalViews = 0;
            int activePosts = 0;

            for (final post in posts) {
              if (post['deleted'] == true || post['active'] == false) continue;
              activePosts++;
              totalLikes += _asInt(post['likeCount'] ?? post['likes'] ?? post['likesCount']);
              totalComments += _asInt(post['commentCount'] ?? post['commentsCount']);
              totalSaves += _asInt(post['saveCount'] ?? post['savesCount']);
              totalShares += _asInt(post['shareCount'] ?? post['sharesCount'] ?? post['sendCount']);
              totalViews += _asInt(post['viewCount'] ?? post['viewsCount'] ?? post['seenCount']);
            }

            final rows = <_InteractionStatData>[
              _InteractionStatData(Icons.grid_on_rounded, 'Aktif post', activePosts),
              _InteractionStatData(Icons.favorite_rounded, 'Toplam beğeni', totalLikes),
              _InteractionStatData(Icons.mode_comment_rounded, 'Toplam yorum', totalComments),
              _InteractionStatData(Icons.bookmark_rounded, 'Toplam kaydetme', totalSaves),
              _InteractionStatData(Icons.send_rounded, 'Toplam paylaşım', totalShares),
              _InteractionStatData(Icons.remove_red_eye_rounded, 'Post görüntülenme', totalViews),
              _InteractionStatData(Icons.visibility_rounded, 'Profil görüntülenme', _asInt(profile['profileViewsCount'])),
              _InteractionStatData(Icons.auto_stories_rounded, 'Story sayısı', _asInt(profile['storiesCount'])),
            ];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const Text(
                  'NOVA içindeki etkileşimlerini buradan takip edebilirsin.',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w800, height: 1.35),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(row.icon, color: Colors.black, size: 25),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_compactInt(row.value), textScaler: TextScaler.noScaling, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
                              Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, textScaler: TextScaler.noScaling, style: _mutedBold),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InteractionStatData {
  final IconData icon;
  final String title;
  final int value;

  const _InteractionStatData(this.icon, this.title, this.value);
}

String _compactInt(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return value.toString();
}

class _TopBar extends StatelessWidget {
  final String username;
  final bool privateProfile;
  final VoidCallback onMenu;
  final VoidCallback onLogout;

  const _TopBar({
    required this.username,
    required this.privateProfile,
    required this.onMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, color: Colors.black, size: 31),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  privateProfile ? Icons.lock_rounded : Icons.public_rounded,
                  color: privateProfile ? const Color(0xFF12A150) : Colors.redAccent,
                  size: 18,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final NovaProfile profile;
  final int postCount;
  final bool isOwnProfile;
  final VoidCallback onEdit;
  final VoidCallback onPhotoTap;
  final VoidCallback onPhotoLongPress;
  final VoidCallback onWebsiteTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _ProfileHeader({
    required this.profile,
    required this.postCount,
    required this.isOwnProfile,
    required this.onEdit,
    required this.onPhotoTap,
    required this.onPhotoLongPress,
    required this.onWebsiteTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 104,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onPhotoTap,
                        onLongPress: onPhotoLongPress,
                        child: _BlackRingAvatar(imageUrl: profile.photoUrl, size: 88),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatsBox(
                    posts: postCount,
                    followers: profile.followersCount,
                    following: profile.followingCount,
                    onFollowersTap: onFollowersTap,
                    onFollowingTap: onFollowingTap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ProfileLine(text: profile.displayName.isEmpty ? 'Ad Soyad' : profile.displayName, bold: true),
          if (profile.locationText.isNotEmpty) _ProfileLine(text: profile.locationText),
          if (profile.bio.isNotEmpty) _ProfileLine(text: profile.bio, maxLines: 3),
          if (profile.phoneVisible && profile.phone.isNotEmpty)
            _ProfileLine(text: profile.phone, color: const Color(0xFF13A34A), bold: true),
          if (profile.website.isNotEmpty)
            GestureDetector(
              onTap: onWebsiteTap,
              child: _ProfileLine(
                text: profile.website,
                color: const Color(0xFF00AFCB),
                bold: true,
                underline: true,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: Material(
              color: const Color(0xFFF1F2F6),
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(11),
                child: Center(
                  child: Text(
                    isOwnProfile ? 'Profili düzenle' : 'Takip et',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (profile.expenseCardVisible) ...[
            const SizedBox(height: 10),
            _ExpenseProfileSummaryCard(profile: profile),
          ],
        ],
      ),
    );
  }
}

class _ExpenseProfileSummaryCard extends StatelessWidget {
  final NovaProfile profile;

  const _ExpenseProfileSummaryCard({required this.profile});

  String _money(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    final raw = number.toStringAsFixed(0);
    return raw.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
    );
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final card = profile.expenseProfileCard;
    final carName = _text(card['selectedCarName'], fallback: 'Araç masraf özeti');
    final plate = _text(card['selectedCarPlate'], fallback: 'Plaka yok');
    final period = _text(card['selectedPeriod'], fallback: 'Dönem');
    final totalExpense = _money(card['totalExpense']);
    final allCarTotal = _money(card['allCarTotal']);
    final averageExpense = _money(card['averageExpense']);
    final recordCount = _text(card['recordCount'], fallback: '0');
    final biggestCategory = _text(card['biggestCategory'], fallback: 'Veri yok');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF00B8),
            Color(0xFF7C4DFF),
            Color(0xFF00D9FF),
            Color(0xFFFF7A00),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fatura / Masraf Özeti',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$carName • $plate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.black,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              '$totalExpense TL',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Seçili dönem toplam masrafı',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Colors.white.withOpacity(0.60),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ExpenseProfileMiniInfo(title: 'Tüm Araçlar', value: '$allCarTotal TL')),
                const SizedBox(width: 8),
                Expanded(child: _ExpenseProfileMiniInfo(title: 'Ortalama', value: '$averageExpense TL')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _ExpenseProfileMiniInfo(title: 'Kayıt', value: '$recordCount işlem')),
                const SizedBox(width: 8),
                Expanded(child: _ExpenseProfileMiniInfo(title: 'En Yoğun', value: biggestCategory)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseProfileMiniInfo extends StatelessWidget {
  final String title;
  final String value;

  const _ExpenseProfileMiniInfo({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white.withOpacity(0.56),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String text;
  final Color color;
  final bool bold;
  final bool underline;
  final int maxLines;

  const _ProfileLine({
    required this.text,
    this.color = Colors.black,
    this.bold = false,
    this.underline = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: 12.8,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          decoration: underline ? TextDecoration.underline : TextDecoration.none,
          height: 1.23,
        ),
      ),
    );
  }
}

class _StatsBox extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  const _StatsBox({
    required this.posts,
    required this.followers,
    required this.following,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5D5D5), width: 1.15),
      ),
      child: Row(
        children: [
          _HeaderStat(value: posts, label: 'gönderi'),
          const _StatDivider(),
          _HeaderStat(value: followers, label: 'takipçi', onTap: onFollowersTap),
          const _StatDivider(),
          _HeaderStat(value: following, label: 'takip', onTap: onFollowingTap),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const _HeaderStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatCount(value),
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 48,
    color: const Color(0xFFE7E7E7),
  );
}

class _ProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _ProfileTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = [Icons.grid_on_rounded, Icons.directions_car_filled_rounded, Icons.favorite_rounded];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6), width: 0.7)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(index),
              child: Column(
                children: [
                  Expanded(child: Icon(tabs[index], color: selected ? Colors.black : Colors.black45, size: 25)),
                  Container(height: 2, color: selected ? Colors.black : Colors.transparent),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StoriesPreviewRow extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final VoidCallback onTap;

  const _StoriesPreviewRow({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final active = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data();
            final created = _toDate(data['createdAt'], fallback: DateTime.now());
            final expires = _toDate(data['expiresAt'], fallback: created.add(const Duration(hours: 24)));
            return data['active'] != false && DateTime.now().isBefore(expires);
          }).toList();

          if (active.isEmpty) return const SizedBox.shrink();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            scrollDirection: Axis.horizontal,
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final data = active[index].data();
              final image = _safeString(data['imageUrl'] ?? data['mediaUrl'] ?? data['storyImage'] ?? data['image']);
              return GestureDetector(
                onTap: onTap,
                child: SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      _BlackRingAvatar(imageUrl: image, size: 58),
                      const SizedBox(height: 4),
                      const Text(
                        'Story',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PostsGridSliver extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final FirebaseFirestore db;
  final bool isOwner;

  const _PostsGridSliver({
    required this.stream,
    required this.db,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2))));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((d) => d.data()['deleted'] != true && d.data()['isArchived'] != true)
            .toList();

        if (docs.isEmpty) {
          return const SliverToBoxAdapter(child: EmptyGridMessage(icon: Icons.grid_on_rounded, text: 'Henüz gönderi yok'));
        }

        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final doc = docs[index];
              return _GridPostTile(
                data: doc.data(),
                onTap: () => _openPostDetail(context, doc.id, doc.data()),
              );
            },
            childCount: docs.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 1.2,
            crossAxisSpacing: 1.2,
            childAspectRatio: 0.78,
          ),
        );
      },
    );
  }

  void _openPostDetail(BuildContext context, String postId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: _PostDetailSheet(postId: postId, data: data, db: db, isOwner: isOwner),
          ),
        );
      },
    );
  }
}

class _AdsGridSliver extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _AdsGridSliver({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.2))));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((d) => d.data()['deleted'] != true && (d.data()['status'] ?? 'active') == 'active')
            .toList();

        if (docs.isEmpty) {
          return const SliverToBoxAdapter(child: EmptyGridMessage(icon: Icons.directions_car_filled_rounded, text: 'Henüz ilan yok'));
        }

        return SliverGrid(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final data = docs[index].data();
              final ad = CarAd.fromDoc(docs[index]);
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    enableDrag: true,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withOpacity(0.25),
                    builder: (_) => FractionallySizedBox(
                      heightFactor: 0.86,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: CarAdDetailPage(ad: ad),
                      ),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ImageBox(imageUrl: _firstImage(data), emptyIcon: Icons.directions_car_filled_rounded),
                    Positioned(
                      left: 5,
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.70), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          _safeString(data['title'] ?? data['brand'] ?? data['model'], fallback: 'İlan'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            childCount: docs.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 1.2,
            crossAxisSpacing: 1.2,
            childAspectRatio: 0.78,
          ),
        );
      },
    );
  }
}

class _GridPostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _GridPostTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(data);
    final isVideo = _safeString(data['mediaType'] ?? data['type']) == 'video' || _safeString(data['videoUrl']).isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ImageBox(imageUrl: image, emptyIcon: Icons.image_rounded),
          Positioned(
            top: 6,
            right: 6,
            child: Icon(isVideo ? Icons.play_arrow_rounded : Icons.copy_rounded, color: Colors.white, size: 18, shadows: const [Shadow(color: Colors.black, blurRadius: 5)]),
          ),
        ],
      ),
    );
  }
}

class _PostDetailSheet extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final FirebaseFirestore db;
  final bool isOwner;

  const _PostDetailSheet({
    required this.postId,
    required this.data,
    required this.db,
    required this.isOwner,
  });

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  late final TextEditingController caption;

  @override
  void initState() {
    super.initState();
    caption = TextEditingController(text: _safeString(widget.data['caption'] ?? widget.data['desc'] ?? widget.data['description']));
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _firstImage(widget.data);
    final username = _safeString(widget.data['username'], fallback: 'nova.user');
    final desc = _safeString(widget.data['caption'] ?? widget.data['desc'] ?? widget.data['description']);

    return Column(
      children: [
        const _SheetHandle(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _SmallAvatar(imageUrl: _safeString(widget.data['userPhoto'] ?? widget.data['photoUrl']), size: 42),
                    const SizedBox(width: 10),
                    Expanded(child: Text('@$username', style: _boldBlack)),
                    if (widget.isOwner)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'archive') {
                            await widget.db.collection('posts').doc(widget.postId).set({'isArchived': true, 'archivedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                            if (mounted) Navigator.pop(context);
                          }
                          if (value == 'delete') {
                            await widget.db.collection('posts').doc(widget.postId).set({'deleted': true, 'active': false, 'deletedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                            if (mounted) Navigator.pop(context);
                          }
                          if (value == 'edit') _openEditPost();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                          PopupMenuItem(value: 'archive', child: Text('Arşivle')),
                          PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _ImageBox(imageUrl: image, emptyIcon: Icons.image_rounded),
                ),
              ),
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(desc, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditPost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 12),
              const Text('Postu Düzenle', style: _titleStyle),
              const SizedBox(height: 12),
              TextField(
                controller: caption,
                maxLines: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    await widget.db.collection('posts').doc(widget.postId).set({
                      'caption': caption.text.trim(),
                      'desc': caption.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final NovaProfile profile;
  final String email;
  final Future<String?> Function() onPickPhoto;
  final Future<String?> Function(_EditProfileValue value) onSave;

  const _EditProfileSheet({
    required this.profile,
    required this.email,
    required this.onPickPhoto,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController city;
  late final TextEditingController district;
  late final TextEditingController bio;
  late final TextEditingController website;
  late final TextEditingController phone;
  bool phoneVisible = false;
  bool saving = false;
  double savingProgress = 0;
  String? formMessage;
  String photoUrl = '';

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.profile.displayName);
    username = TextEditingController(text: widget.profile.usernameText);
    city = TextEditingController(text: widget.profile.city);
    district = TextEditingController(text: widget.profile.district);
    bio = TextEditingController(text: widget.profile.bio);
    website = TextEditingController(text: widget.profile.website);
    phone = TextEditingController(text: widget.profile.phoneDigits);
    phoneVisible = widget.profile.phoneVisible;
    photoUrl = widget.profile.photoUrl;
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    city.dispose();
    district.dispose();
    bio.dispose();
    website.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final url = await widget.onPickPhoto();
    if (url != null && mounted) setState(() => photoUrl = url);
  }

  void _showFormMessage(String message) {
    if (!mounted) return;
    setState(() => formMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
      ),
    );
  }

  Future<void> _save() async {
    if (saving) return;

    if (name.text.trim().isEmpty) return _showFormMessage('Ad soyad alanı zorunlu.');
    if (username.text.trim().isEmpty) return _showFormMessage('Kullanıcı adı alanı zorunlu.');
    if (city.text.trim().isEmpty) return _showFormMessage('İl seçimi zorunlu.');
    if (district.text.trim().isEmpty) return _showFormMessage('İlçe seçimi zorunlu.');
    if (phone.text.trim().length != 10) return _showFormMessage('Telefon numarası +90 sonrası 10 hane olmalı.');
    if (website.text.trim().isNotEmpty && !website.text.trim().startsWith('https://')) {
      return _showFormMessage('Web sitesi sadece https:// ile başlamalı.');
    }

    setState(() {
      saving = true;
      savingProgress = 0.12;
      formMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => savingProgress = 0.35);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => savingProgress = 0.58);

    final error = await widget.onSave(
      _EditProfileValue(
        displayName: name.text,
        username: username.text,
        city: city.text,
        district: district.text,
        bio: bio.text,
        website: website.text,
        phoneDigits: phone.text,
        phoneVisible: phoneVisible,
        photoUrl: photoUrl,
      ),
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        saving = false;
        savingProgress = 0;
        formMessage = error;
      });
      _showFormMessage(error);
      return;
    }

    setState(() => savingProgress = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            children: [
              const Text('Profili Düzenle', textAlign: TextAlign.center, style: _titleStyle),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    GestureDetector(onTap: _pickPhoto, child: _BlackRingAvatar(imageUrl: photoUrl, size: 92)),
                    TextButton(
                      onPressed: _pickPhoto,
                      child: const Text('Fotoğraf değiştir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              _LockedEmailBox(email: widget.email),
              if (formMessage != null) ...[
                const SizedBox(height: 10),
                _EditMessageBox(message: formMessage!),
              ],
              const SizedBox(height: 10),
              _NovaInput(controller: name, label: 'Ad Soyad', requiredField: true),
              _NovaInput(controller: username, label: 'Kullanıcı adı', prefix: '@', requiredField: true),
              Row(
                children: [
                  Expanded(
                    child: _NovaDropdownField(
                      label: 'İl',
                      value: cityDistricts.containsKey(city.text.trim()) ? city.text.trim() : null,
                      items: cityDistricts.keys.toList(),
                      requiredField: true,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          city.text = value;
                          final districts = cityDistricts[value] ?? const <String>[];
                          if (!districts.contains(district.text.trim())) district.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NovaDropdownField(
                      label: 'İlçe',
                      value: (cityDistricts[city.text.trim()] ?? const <String>[]).contains(district.text.trim()) ? district.text.trim() : null,
                      items: cityDistricts[city.text.trim()] ?? const <String>[],
                      requiredField: true,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => district.text = value);
                      },
                    ),
                  ),
                ],
              ),
              _NovaInput(controller: bio, label: 'Biyografi', maxLines: 3),
              _NovaInput(controller: website, label: 'Web sitesi (https://)', keyboardType: TextInputType.url),
              _PhoneInput(controller: phone),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF4F5F7), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Expanded(child: Text('Telefon profilde gösterilsin', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900, color: Colors.black))),
                    Switch(value: phoneVisible, activeColor: Colors.black, onChanged: (v) => setState(() => phoneVisible = v)),
                  ],
                ),
              ),
              if (saving) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: savingProgress.clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE8E8E8),
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: saving ? null : _save,
                  child: saving
                      ? Text(
                    'Kaydediliyor %${(savingProgress * 100).clamp(0, 100).round()}',
                    style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                  )
                      : const Text('Kaydet', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _EditMessageBox extends StatelessWidget {
  final String message;

  const _EditMessageBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Color(0xFFB00020),
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EditProfileValue {
  final String displayName;
  final String username;
  final String city;
  final String district;
  final String bio;
  final String website;
  final String phoneDigits;
  final bool phoneVisible;
  final String photoUrl;

  const _EditProfileValue({
    required this.displayName,
    required this.username,
    required this.city,
    required this.district,
    required this.bio,
    required this.website,
    required this.phoneDigits,
    required this.phoneVisible,
    required this.photoUrl,
  });
}

class _MenuSheet extends StatefulWidget {
  final NovaProfile profile;
  final bool isOwnProfile;
  final VoidCallback onArchive;
  final VoidCallback onStoryHistory;
  final VoidCallback onSaved;
  final VoidCallback onVisitors;
  final Future<void> Function(bool value) onTogglePrivate;

  const _MenuSheet({
    required this.profile,
    required this.isOwnProfile,
    required this.onArchive,
    required this.onStoryHistory,
    required this.onSaved,
    required this.onVisitors,
    required this.onTogglePrivate,
  });

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  late bool privateProfile;

  @override
  void initState() {
    super.initState();
    privateProfile = widget.profile.privateProfile;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 26),
              ),
              _SmallAvatar(imageUrl: widget.profile.photoUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.profile.displayUsername, style: _boldBlack)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              if (widget.isOwnProfile)
                _MenuSwitchTile(
                  icon: Icons.lock_rounded,
                  title: privateProfile ? 'Gizli hesap' : 'Herkese açık',
                  value: privateProfile,
                  onChanged: (v) async {
                    setState(() => privateProfile = v);
                    await widget.onTogglePrivate(v);
                  },
                ),
              _MenuTile(icon: Icons.archive_outlined, title: 'Post Arşivi', onTap: widget.onArchive),
              _MenuTile(icon: Icons.history_toggle_off_rounded, title: 'Story Geçmişi', onTap: widget.onStoryHistory),
              _MenuTile(icon: Icons.bookmark_border_rounded, title: 'Kaydedilenler', onTap: widget.onSaved),
              _MenuTile(icon: Icons.visibility_outlined, title: 'Profiline Son Bakanlar', onTap: widget.onVisitors),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: _boldBlack)),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MenuSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.black)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: _boldBlack)),
          Switch(value: value, activeColor: Colors.black, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PostsListSheet extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final FirebaseFirestore db;
  final bool isOwner;
  final bool archiveMode;

  const _PostsListSheet({
    required this.title,
    required this.stream,
    required this.db,
    required this.isOwner,
    required this.archiveMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        _SheetTitleBar(title: title),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
              if (docs.isEmpty) return Center(child: Text('$title boş.', style: _mutedBold));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return _ArchivePostTile(
                    data: data,
                    isOwner: isOwner,
                    archiveMode: archiveMode,
                    onUnarchive: () => db.collection('posts').doc(doc.id).set({'isArchived': false, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                    onDelete: () => db.collection('posts').doc(doc.id).set({'deleted': true, 'active': false, 'deletedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArchivePostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isOwner;
  final bool archiveMode;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _ArchivePostTile({
    required this.data,
    required this.isOwner,
    required this.archiveMode,
    required this.onUnarchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 58, height: 58, child: _ImageBox(imageUrl: _firstImage(data), emptyIcon: Icons.image_rounded))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dateText(_toDate(data['createdAt'])),
              style: _mutedBold,
            ),
          ),
          if (isOwner && archiveMode)
            TextButton(onPressed: onUnarchive, child: const Text('Arşivden çıkar')),
          if (isOwner)
            TextButton(onPressed: onDelete, child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _StoryHistorySheet extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final FirebaseFirestore db;
  final String profileUid;
  final bool isOwner;

  const _StoryHistorySheet({
    required this.stream,
    required this.db,
    required this.profileUid,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        const _SheetTitleBar(title: 'Story Geçmişi'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
              if (docs.isEmpty) return const Center(child: Text('Story geçmişi boş.', style: _mutedBold));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final image = _safeString(data['imageUrl'] ?? data['mediaUrl'] ?? data['storyImage'] ?? data['image']);
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (image.isNotEmpty) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => _ImagePreviewPage(imageUrl: image)));
                            }
                          },
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 66, height: 66, child: _ImageBox(imageUrl: image, emptyIcon: Icons.auto_awesome_rounded))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_dateText(_toDate(data['createdAt'])), style: _mutedBold)),
                        if (isOwner)
                          TextButton(
                            onPressed: () => db.collection('stories').doc(doc.id).delete(),
                            child: const Text('Sil', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedPostsSheet extends StatelessWidget {
  final String userId;
  final FirebaseFirestore db;

  const _SavedPostsSheet({required this.userId, required this.db});

  @override
  Widget build(BuildContext context) {
    final stream = db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();

    return Column(
      children: [
        const _SheetHandle(),
        const _SheetTitleBar(title: 'Kaydedilenler'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final savedDocs = snapshot.data?.docs ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }
              if (savedDocs.isEmpty) {
                return const Center(child: Text('Kaydedilen gönderi yok.', style: _mutedBold));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: savedDocs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final savedDoc = savedDocs[index];
                  final savedData = savedDoc.data();
                  final postId = _safeString(savedData['postId'], fallback: savedDoc.id);

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: db.collection('posts').doc(postId).snapshots(),
                    builder: (context, postSnap) {
                      if (postSnap.connectionState == ConnectionState.waiting) {
                        return Container(
                          height: 82,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        );
                      }

                      final postData = postSnap.data?.data();
                      if (postData == null || postData['deleted'] == true) {
                        return _SavedMissingPostTile(
                          onRemove: () => db
                              .collection('users')
                              .doc(userId)
                              .collection('savedPosts')
                              .doc(savedDoc.id)
                              .delete(),
                        );
                      }

                      final username = _safeString(
                        postData['username'] ?? postData['displayName'],
                        fallback: 'nova.user',
                      );
                      final city = _safeString(postData['userCity'] ?? postData['city'] ?? postData['il']);
                      final district = _safeString(postData['userDistrict'] ?? postData['district'] ?? postData['ilce'] ?? postData['ilçe']);
                      final location = [city, district].where((e) => e.trim().isNotEmpty).join(' / ');
                      final desc = _safeString(postData['caption'] ?? postData['desc'] ?? postData['description']);

                      return _SavedPostTile(
                        data: postData,
                        username: username,
                        location: location,
                        desc: desc,
                        onRemove: () => db
                            .collection('users')
                            .doc(userId)
                            .collection('savedPosts')
                            .doc(savedDoc.id)
                            .delete(),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String username;
  final String location;
  final String desc;
  final VoidCallback onRemove;

  const _SavedPostTile({
    required this.data,
    required this.username,
    required this.location,
    required this.desc,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final image = _firstImage(data);
              if (image.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => _ImagePreviewPage(imageUrl: image)));
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 66,
                height: 66,
                child: _ImageBox(imageUrl: _firstImage(data), emptyIcon: Icons.image_rounded),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis, style: _boldBlack),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mutedBold),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Kaydedilenlerden kaldır', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMissingPostTile extends StatelessWidget {
  final VoidCallback onRemove;
  const _SavedMissingPostTile({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.hide_image_rounded, color: Colors.black45),
          const SizedBox(width: 10),
          const Expanded(child: Text('Bu post artık bulunmuyor.', style: _mutedBold)),
          TextButton(onPressed: onRemove, child: const Text('Kaldır', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _VisitorsSheet extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  const _VisitorsSheet({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        const _SheetTitleBar(title: 'Profiline Son Bakanlar'),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
              if (docs.isEmpty) return const Center(child: Text('Profiline bakan kullanıcı yok.', style: _mutedBold));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF6F6F7), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        _SmallAvatar(imageUrl: _safeString(data['viewerPhotoUrl']), size: 44),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_safeString(data['viewerName'] ?? data['viewerEmail'], fallback: 'Nova kullanıcısı'), style: _boldBlack)),
                        Text('${_asInt(data['viewCount'])} kez', style: _mutedBold),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoryViewerPage extends StatefulWidget {
  final List<StoryItem> stories;

  const _StoryViewerPage({required this.stories});

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  late final PageController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: widget.stories.length,
              onPageChanged: (v) => setState(() => index = v),
              itemBuilder: (context, i) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      widget.stories[i].imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 80),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewPage extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.82),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 36,
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 22),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 300,
                      child: Center(
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 90),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  const Spacer(),
                  Material(
                    color: Colors.red,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileSkeletonLoading extends StatefulWidget {
  const ProfileSkeletonLoading({super.key});

  @override
  State<ProfileSkeletonLoading> createState() => _ProfileSkeletonLoadingState();
}

class _ProfileSkeletonLoadingState extends State<ProfileSkeletonLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget box({double? w, required double h, double r = 12, BoxShape shape = BoxShape.rectangle}) {
    return _ShimmerBox(
      controller: _controller,
      width: w,
      height: h,
      radius: r,
      shape: shape,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              box(w: 40, h: 40, r: 12),
              const Spacer(),
              box(w: 120, h: 14, r: 99),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              box(w: 88, h: 88, shape: BoxShape.circle),
              const SizedBox(width: 12),
              Expanded(child: box(h: 88, r: 16)),
            ],
          ),
          const SizedBox(height: 14),
          box(w: 150, h: 14, r: 99),
          const SizedBox(height: 8),
          box(w: 110, h: 12, r: 99),
          const SizedBox(height: 8),
          box(w: double.infinity, h: 12, r: 99),
          const SizedBox(height: 14),
          box(w: double.infinity, h: 38, r: 11),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: box(h: 46, r: 0)), Expanded(child: box(h: 46, r: 0))]),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 1.2, crossAxisSpacing: 1.2, childAspectRatio: 0.78),
            itemBuilder: (_, __) => box(h: 120, r: 0),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const _ShimmerBox({
    required this.controller,
    required this.width,
    required this.height,
    required this.radius,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.8 + controller.value * 3.6, 0),
              end: Alignment(-0.2 + controller.value * 3.6, 0),
              colors: const [
                Color(0xFFEDEDED),
                Color(0xFFF8F8F8),
                Color(0xFFEDEDED),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EmptyGridMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyGridMessage({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 38),
            const SizedBox(height: 10),
            Text(text, style: _boldBlack),
          ],
        ),
      ),
    );
  }
}

class _PrivateBox extends StatelessWidget {
  const _PrivateBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black12)),
      child: const Column(
        children: [
          Icon(Icons.lock_rounded, color: Colors.black, size: 36),
          SizedBox(height: 8),
          Text('Bu hesap gizli', style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 4),
          Text('Gönderileri ve ilanları görmek için takip etmelisin.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LockedEmailBox extends StatelessWidget {
  final String email;

  const _LockedEmailBox({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF4F5F7), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.black54, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(email.isEmpty ? 'Google mail bulunamadı' : email, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;

  const _PhoneInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        decoration: InputDecoration(
          labelText: 'Telefon numarası *',
          prefixText: '+90 ',
          filled: true,
          fillColor: const Color(0xFFF4F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black, width: 1.2)),
        ),
      ),
    );
  }
}


class _NovaDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool requiredField;
  final ValueChanged<String?> onChanged;

  const _NovaDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleanItems = items.toSet().toList();
    final activeValue = cleanItems.contains(value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: activeValue,
        isExpanded: true,
        items: cleanItems
            .map((item) => DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800),
          ),
        ))
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          filled: true,
          fillColor: const Color(0xFFF4F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black, width: 1.2)),
        ),
      ),
    );
  }
}

class _NovaInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool requiredField;

  const _NovaInput({
    required this.controller,
    required this.label,
    this.prefix,
    this.maxLines = 1,
    this.keyboardType,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          prefixText: prefix,
          filled: true,
          fillColor: const Color(0xFFF4F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black, width: 1.2)),
        ),
      ),
    );
  }
}

class _SheetTitleBar extends StatelessWidget {
  final String title;
  const _SheetTitleBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 26),
          ),
          Expanded(child: Text(title, style: _titleStyle)),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

class _BlackRingAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _BlackRingAvatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.2),
      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(2.2),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(child: _ImageBox(imageUrl: imageUrl, emptyIcon: Icons.person_rounded)),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _SmallAvatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: ClipOval(child: _ImageBox(imageUrl: imageUrl, emptyIcon: Icons.person_rounded)));
  }
}

class _ImageBox extends StatelessWidget {
  final String imageUrl;
  final IconData emptyIcon;

  const _ImageBox({required this.imageUrl, required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(color: const Color(0xFFF1F2F6), child: Icon(emptyIcon, color: Colors.black38));
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 720,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F2F6), child: Icon(emptyIcon, color: Colors.black38)),
        loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: const Color(0xFFF1F2F6)),
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F2F6), child: Icon(emptyIcon, color: Colors.black38)),
    );
  }
}

class StoryItem {
  final String id;
  final String imageUrl;
  final String title;
  final DateTime createdAt;

  const StoryItem({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.createdAt,
  });

  factory StoryItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return StoryItem(
      id: doc.id,
      imageUrl: _safeString(data['imageUrl'] ?? data['mediaUrl'] ?? data['storyImage'] ?? data['image']),
      title: _safeString(data['title'] ?? data['caption'], fallback: 'Story'),
      createdAt: _toDate(data['createdAt']),
    );
  }
}

class NovaProfile {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String bio;
  final String city;
  final String district;
  final String phone;
  final bool phoneVisible;
  final String photoUrl;
  final String website;
  final bool privateProfile;
  final int followersCount;
  final int followingCount;
  final int profileViewsCount;
  final bool showExpensesOnProfile;
  final Map<String, dynamic> expenseProfileCard;
  final List<String> followerIds;
  final List<String> followingIds;

  const NovaProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.city,
    required this.district,
    required this.phone,
    required this.phoneVisible,
    required this.photoUrl,
    required this.website,
    required this.privateProfile,
    required this.followersCount,
    required this.followingCount,
    required this.profileViewsCount,
    required this.showExpensesOnProfile,
    required this.expenseProfileCard,
    required this.followerIds,
    required this.followingIds,
  });

  factory NovaProfile.fromMap(
      Map<String, dynamic> data, {
        required String fallbackUid,
        required String fallbackEmail,
        String fallbackName = '',
        String fallbackPhoto = '',
      }) {
    return NovaProfile(
      uid: _safeString(data['uid'], fallback: fallbackUid),
      email: _safeString(data['email'], fallback: fallbackEmail),
      displayName: _safeString(data['displayName'] ?? data['fullName'], fallback: fallbackName),
      username: _safeString(data['username']),
      bio: _safeString(data['bio']),
      city: _safeString(data['city'] ?? data['il']),
      district: _safeString(data['district'] ?? data['ilce'] ?? data['ilçe']),
      phone: _safeString(data['phone']),
      phoneVisible: data['phoneVisible'] == true,
      photoUrl: _safeString(data['photoUrl'] ?? data['avatarUrl'] ?? data['profileImage'], fallback: fallbackPhoto),
      website: _safeString(data['website'] ?? data['link']),
      privateProfile: data['privateProfile'] == true,
      followersCount: _asInt(data['followersCount'] ?? data['followers']),
      followingCount: _asInt(data['followingCount'] ?? data['following']),
      profileViewsCount: _asInt(data['profileViewsCount']),
      showExpensesOnProfile: data['showExpensesOnProfile'] == true,
      expenseProfileCard: _mapValue(data['expenseProfileCard']),
      followerIds: _stringList(data['followerIds'] ?? data['followers']),
      followingIds: _stringList(data['followingIds'] ?? data['following']),
    );
  }

  String get usernameText {
    if (username.trim().isNotEmpty) return username.trim();
    if (email.contains('@')) return email.split('@').first;
    return 'nova_user';
  }

  String get displayUsername => '@$usernameText';

  String get locationText {
    final parts = [city, district].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(' / ');
  }

  bool get expenseCardVisible {
    final cardVisible = expenseProfileCard['visible'] == true;
    return showExpensesOnProfile && cardVisible;
  }

  String get phoneDigits {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('90') && digits.length > 10) return digits.substring(2).substring(0, digits.substring(2).length.clamp(0, 10));
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }
}

String _safeString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  return <String>[];
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

DateTime _toDate(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.fromMillisecondsSinceEpoch(0));
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String _firstImage(Map<String, dynamic> data) {
  final list = _stringList(data['images'] ?? data['imageUrls'] ?? data['mediaUrls']);
  if (list.isNotEmpty) return list.first;
  return _safeString(data['imageUrl'] ?? data['image'] ?? data['mediaUrl'] ?? data['photoUrl'] ?? data['coverImage'] ?? data['mainImage'] ?? data['thumbnail']);
}

bool _validPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) return true;
  if (digits.length == 12 && digits.startsWith('90')) return true;
  if (digits.length == 13 && digits.startsWith('090')) return true;
  return false;
}

String _formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(0)}B';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return value.toString();
}

String _dateText(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0) return 'Tarih yok';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
}

const TextStyle _boldBlack = TextStyle(fontFamily: 'Roboto', color: Colors.black, fontWeight: FontWeight.w900);
const TextStyle _titleStyle = TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900);
const TextStyle _mutedBold = TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w800);
