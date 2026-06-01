import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'user_profile_page.dart';

class EmergencyTowPage extends StatefulWidget {
  const EmergencyTowPage({super.key});

  @override
  State<EmergencyTowPage> createState() => _EmergencyTowPageState();
}

class _EmergencyTowPageState extends State<EmergencyTowPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulseController;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String selectedCity = 'Tüm İller';
  String selectedDistrict = 'Tüm İlçeler';

  final Map<String, List<String>> cityDistricts = const {
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

  @override
  void initState() {
    super.initState();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulseController.dispose();
    super.dispose();
  }

  List<String> get cities => ['Tüm İller', ...cityDistricts.keys.toList()];

  List<String> get districts {
    if (selectedCity == 'Tüm İller') return const ['Tüm İlçeler'];
    return ['Tüm İlçeler', ...(cityDistricts[selectedCity] ?? const [])];
  }

  void changeCity(String? value) {
    if (value == null) return;
    setState(() {
      selectedCity = value;
      selectedDistrict = 'Tüm İlçeler';
    });
  }

  void changeDistrict(String? value) {
    if (value == null) return;
    setState(() => selectedDistrict = value);
  }

  Query<Map<String, dynamic>> towAdsQuery() {
    Query<Map<String, dynamic>> query = firestore
        .collection('towAds')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true);

    if (selectedCity != 'Tüm İller') {
      query = query.where('city', isEqualTo: selectedCity);
    }

    if (selectedDistrict != 'Tüm İlçeler') {
      query = query.where('district', isEqualTo: selectedDistrict);
    }

    return query;
  }

  Future<void> callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<Map<String, String>> currentUserInfo() async {
    final user = auth.currentUser;
    if (user == null) return <String, String>{};

    var name = user.displayName ?? user.email ?? 'NOVA Kullanıcısı';
    var username = user.email?.split('@').first ?? 'nova.user';
    var photoUrl = user.photoURL ?? '';

    try {
      final snap = await firestore.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      name = readString(data, ['displayName', 'fullName', 'name', 'username'], fallback: name);
      username = readString(data, ['username'], fallback: username).replaceAll('@', '');
      photoUrl = readString(data, ['photoUrl', 'profileImageUrl', 'avatarUrl'], fallback: photoUrl);
    } catch (_) {}

    return {
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
    };
  }

  String readString(Map<String, dynamic> data, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  Future<void> createOwnerNotification({
    required TowTruckAd ad,
    required String type,
    required String title,
    required String body,
    String commentText = '',
    int stars = 0,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;
    if (ad.userId.trim().isEmpty || ad.userId == user.uid) return;

    final info = await currentUserInfo();
    final notificationRef = firestore
        .collection('users')
        .doc(ad.userId)
        .collection('notifications')
        .doc();

    await notificationRef.set({
      'id': notificationRef.id,
      'type': type,
      'notificationType': type,
      'pushType': type,
      'notificationKind': type,
      'title': title,
      'body': body,
      'message': body,
      'receiverId': ad.userId,
      'toUserId': ad.userId,
      'senderId': user.uid,
      'fromUserId': user.uid,
      'actorId': user.uid,
      'actorUsername': info['username'] ?? '',
      'fromUserName': info['name'] ?? '',
      'senderName': info['name'] ?? '',
      'actorPhotoUrl': info['photoUrl'] ?? '',
      'fromUserPhotoUrl': info['photoUrl'] ?? '',
      'senderPhotoUrl': info['photoUrl'] ?? '',
      'towAdId': ad.id,
      'adId': ad.id,
      'adTitle': ad.companyName,
      'commentText': commentText,
      'stars': stars,
      'read': false,
      'seen': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void openOwnerProfile(TowTruckAd ad) {
    if (ad.userId.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: ad.userId),
      ),
    );
  }

  Future<void> openMessageToOwner(TowTruckAd ad) async {
    final user = auth.currentUser;
    if (user == null) {
      showMessage('Mesaj göndermek için giriş yapmalısın.');
      return;
    }

    if (ad.userId.trim().isEmpty) {
      showMessage('İlan sahibinin kullanıcı bilgisi bulunamadı.');
      return;
    }

    if (ad.userId == user.uid) {
      showMessage('Bu ilan zaten sana ait.');
      return;
    }

    final ids = [user.uid, ad.userId]..sort();
    final conversationId = ids.join('_');

    // ÖNEMLİ:
    // Burada mesaj gönderilmiyor. Sadece sohbet kutusu hazırlanıyor.
    // Kullanıcı DM ekranında isterse hazır mesajı gönderiyor.
    await firestore.collection('conversations').doc(conversationId).set({
      'id': conversationId,
      'participants': ids,
      'participantIds': ids,
      'userIds': ids,
      'lastMessage': 'Çekici ilanı sohbeti hazırlandı.',
      'lastMessageType': 'tow_ad_preview',
      'towAdId': ad.id,
      'towAdTitle': ad.companyName,
      'towAdImage': ad.imageUrl,
      'towAdPrice': ad.priceInfo,
      'towAdLocation': '${ad.city} / ${ad.district}',
      'towAdOwnerId': ad.userId,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TowAdDmBoxPage(
          conversationId: conversationId,
          receiverId: ad.userId,
          ad: ad,
          onNotifyOwner: createOwnerNotification,
        ),
      ),
    );
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> toggleReaction(TowTruckAd ad, String type) async {
    final user = auth.currentUser;
    if (user == null || ad.id.isEmpty) {
      showMessage('Beğeni için giriş yapmalısın.');
      return;
    }

    final adRef = firestore.collection('towAds').doc(ad.id);
    final reactionRef = adRef.collection('reactions').doc(user.uid);

    var notificationNeeded = false;
    var notificationTitle = '';
    var notificationBody = '';

    await firestore.runTransaction((transaction) async {
      final reactionSnap = await transaction.get(reactionRef);
      final oldType = reactionSnap.data()?['type']?.toString() ?? '';

      int likeDelta = 0;
      int dislikeDelta = 0;

      if (oldType == type) {
        if (type == 'like') likeDelta = -1;
        if (type == 'dislike') dislikeDelta = -1;
        transaction.delete(reactionRef);
      } else {
        if (oldType == 'like') likeDelta = -1;
        if (oldType == 'dislike') dislikeDelta = -1;
        if (type == 'like') likeDelta += 1;
        if (type == 'dislike') dislikeDelta += 1;

        transaction.set(reactionRef, {
          'type': type,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        notificationNeeded = true;
        notificationTitle = type == 'like'
            ? 'Çekici ilanın beğenildi'
            : 'Çekici ilanına beğenmeme geldi';
        notificationBody = type == 'like'
            ? '${user.displayName ?? user.email ?? 'Bir kullanıcı'} çekici ilanını beğendi.'
            : '${user.displayName ?? user.email ?? 'Bir kullanıcı'} çekici ilanını beğenmedi.';
      }

      transaction.update(adRef, {
        'likes': FieldValue.increment(likeDelta),
        'dislikes': FieldValue.increment(dislikeDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (notificationNeeded) {
      await createOwnerNotification(
        ad: ad,
        type: type == 'like' ? 'tow_like' : 'tow_dislike',
        title: notificationTitle,
        body: notificationBody,
      );
    }
  }


  void showTowDetail(TowTruckAd ad) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TowDetailSheet(
          ad: ad,
          onCall: () => callPhone(ad.phone),
          onOwnerTap: () => openOwnerProfile(ad),
          onMessage: () => openMessageToOwner(ad),
          onNotifyOwner: createOwnerNotification,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Acil Çekici',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: BlackDropdown(
                      value: selectedCity,
                      items: cities,
                      onChanged: changeCity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BlackDropdown(
                      value: selectedDistrict,
                      items: districts,
                      onChanged: changeDistrict,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: towAdsQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    );
                  }

                  if (snapshot.hasError) {
                    return ErrorTowState(
                      message:
                      'Çekici ilanları yüklenemedi. Firestore index veya kural kontrolü gerekebilir.',
                      onRefresh: () => setState(() {}),
                    );
                  }

                  final ads = (snapshot.data?.docs ?? [])
                      .map(TowTruckAd.fromDoc)
                      .toList();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(10, 4, 10, MediaQuery.of(context).viewPadding.bottom + 92),
                    children: [
                      EmergencyHeroBox(
                        city: selectedCity,
                        district: selectedDistrict,
                        count: ads.length,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Yakındaki Çekiciler',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            '${ads.length} ilan',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black45,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (ads.isEmpty)
                        EmptyTowState(city: selectedCity, district: selectedDistrict)
                      else
                        ...ads.map(
                              (ad) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TowTruckCard(
                              ad: ad,
                              controller: pulseController,
                              onTap: () => showTowDetail(ad),
                              onCall: () => callPhone(ad.phone),
                              onLike: () => toggleReaction(ad, 'like'),
                              onDislike: () => toggleReaction(ad, 'dislike'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlackDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const BlackDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value)
        ? value
        : items.isNotEmpty
        ? items.first
        : null;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.4),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class EmergencyHeroBox extends StatelessWidget {
  final String city;
  final String district;
  final int count;

  const EmergencyHeroBox({
    super.key,
    required this.city,
    required this.district,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final locationText = city == 'Tüm İller'
        ? 'Tüm bölgelerde $count çekici listeleniyor.'
        : district == 'Tüm İlçeler'
        ? '$city genelinde $count çekici listeleniyor.'
        : '$city / $district bölgesinde $count çekici listeleniyor.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fire_truck_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acil çekici ilanları',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  locationText,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
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

class TowTruckCard extends StatelessWidget {
  final TowTruckAd ad;
  final AnimationController controller;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const TowTruckCard({
    super.key,
    required this.ad,
    required this.controller,
    required this.onTap,
    required this.onCall,
    required this.onLike,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final glow = (0.18 + controller.value * 0.22).clamp(0.0, 1.0);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.black.withOpacity(0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(glow * 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 116,
                      height: 126,
                      child: NovaNetworkImage(url: ad.imageUrl),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: SizedBox(
                      height: 126,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black,
                              fontSize: 15,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${ad.usernameClean}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 14, color: Colors.black45),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${ad.city} / ${ad.district}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.black54,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              StarRating(value: ad.rating, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                ad.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _MiniStat(icon: Icons.thumb_up_alt_rounded, value: ad.likes.toString()),
                              const SizedBox(width: 7),
                              _MiniStat(icon: Icons.thumb_down_alt_rounded, value: ad.dislikes.toString()),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  ad.isOpen247 ? '7/24' : 'Aktif',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.black),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class TowDetailSheet extends StatefulWidget {
  final TowTruckAd ad;
  final VoidCallback onCall;
  final VoidCallback onOwnerTap;
  final VoidCallback onMessage;
  final Future<void> Function({
  required TowTruckAd ad,
  required String type,
  required String title,
  required String body,
  String commentText,
  int stars,
  }) onNotifyOwner;

  const TowDetailSheet({
    super.key,
    required this.ad,
    required this.onCall,
    required this.onOwnerTap,
    required this.onMessage,
    required this.onNotifyOwner,
  });

  @override
  State<TowDetailSheet> createState() => _TowDetailSheetState();
}

class _TowDetailSheetState extends State<TowDetailSheet>
    with TickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final TextEditingController commentController = TextEditingController();

  late final AnimationController likeAnim;
  late final AnimationController dislikeAnim;
  late final AnimationController neonButtonController;

  int selectedStars = 5;
  bool isSending = false;
  bool isDeleting = false;

  bool get isOwner => auth.currentUser?.uid == widget.ad.userId;

  @override
  void initState() {
    super.initState();
    likeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    dislikeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    neonButtonController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    commentController.dispose();
    likeAnim.dispose();
    dislikeAnim.dispose();
    neonButtonController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> userInfo() async {
    final user = auth.currentUser;
    if (user == null) return <String, String>{};
    var name = user.displayName ?? user.email ?? 'NOVA Kullanıcısı';
    var username = user.email?.split('@').first ?? 'nova.user';
    var photoUrl = user.photoURL ?? '';
    try {
      final snap = await firestore.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      name = TowTruckAd._readString(data, ['displayName', 'fullName', 'name'], fallback: name);
      username = TowTruckAd._readString(data, ['username'], fallback: username).replaceAll('@', '');
      photoUrl = TowTruckAd._readString(data, ['photoUrl', 'userPhoto', 'profileImage', 'profileImageUrl', 'avatarUrl'], fallback: photoUrl);
    } catch (_) {}
    return {'name': name, 'username': username, 'photoUrl': photoUrl};
  }

  Future<void> toggleReaction(String type) async {
    final user = auth.currentUser;
    if (user == null) {
      showSnack('Beğeni için giriş yapmalısın.');
      return;
    }
    if (widget.ad.id.isEmpty) return;

    if (type == 'like') {
      likeAnim.forward(from: 0);
    } else {
      dislikeAnim.forward(from: 0);
    }

    final adRef = firestore.collection('towAds').doc(widget.ad.id);
    final reactionRef = adRef.collection('reactions').doc(user.uid);
    var notify = false;

    await firestore.runTransaction((transaction) async {
      final reactionSnap = await transaction.get(reactionRef);
      final oldType = reactionSnap.data()?['type']?.toString() ?? '';
      int likeDelta = 0;
      int dislikeDelta = 0;

      if (oldType == type) {
        if (type == 'like') likeDelta = -1;
        if (type == 'dislike') dislikeDelta = -1;
        transaction.delete(reactionRef);
      } else {
        if (oldType == 'like') likeDelta = -1;
        if (oldType == 'dislike') dislikeDelta = -1;
        if (type == 'like') likeDelta += 1;
        if (type == 'dislike') dislikeDelta += 1;
        transaction.set(reactionRef, {
          'type': type,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        notify = true;
      }

      transaction.update(adRef, {
        'likes': FieldValue.increment(likeDelta),
        'likeCount': FieldValue.increment(likeDelta),
        'dislikes': FieldValue.increment(dislikeDelta),
        'dislikeCount': FieldValue.increment(dislikeDelta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (notify) {
      final info = await userInfo();
      await widget.onNotifyOwner(
        ad: widget.ad,
        type: type == 'like' ? 'tow_like' : 'tow_dislike',
        title: type == 'like' ? 'Çekici ilanın beğenildi' : 'Çekici ilanına beğenmeme geldi',
        body: '${info['name'] ?? 'Bir kullanıcı'} çekici ilanına tepki verdi.',
      );
    }
  }

  Future<void> submitComment() async {
    final user = auth.currentUser;
    final text = commentController.text.trim();
    if (user == null) {
      showSnack('Yorum için giriş yapmalısın.');
      return;
    }
    if (text.isEmpty || widget.ad.id.isEmpty) return;

    setState(() => isSending = true);
    try {
      final info = await userInfo();
      final commentRef = firestore.collection('towAds').doc(widget.ad.id).collection('comments').doc();
      await commentRef.set({
        'id': commentRef.id,
        'userId': user.uid,
        'userName': info['name'] ?? user.displayName ?? user.email ?? 'NOVA Kullanıcısı',
        'username': info['username'] ?? '',
        'userPhotoUrl': info['photoUrl'] ?? '',
        'text': text,
        'stars': selectedStars,
        'likes': 0,
        'likedBy': <String>[],
        'deleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await firestore.collection('towAds').doc(widget.ad.id).update({
        'ratingTotal': FieldValue.increment(selectedStars),
        'commentCount': FieldValue.increment(1),
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await widget.onNotifyOwner(
        ad: widget.ad,
        type: 'tow_comment',
        title: 'Çekici ilanına yorum geldi',
        body: '${info['name'] ?? 'Bir kullanıcı'} çekici ilanına $selectedStars yıldız verdi ve yorum yaptı.',
        commentText: text,
        stars: selectedStars,
      );
      commentController.clear();
      if (mounted) setState(() => selectedStars = 5);
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> toggleCommentLike(TowComment comment) async {
    final user = auth.currentUser;
    if (user == null) {
      showSnack('Yorumu beğenmek için giriş yapmalısın.');
      return;
    }
    final ref = firestore.collection('towAds').doc(widget.ad.id).collection('comments').doc(comment.id);
    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final likedBy = List<String>.from((data['likedBy'] as List?)?.map((e) => e.toString()) ?? const <String>[]);
      if (likedBy.contains(user.uid)) {
        likedBy.remove(user.uid);
        transaction.update(ref, {'likedBy': likedBy, 'likes': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        likedBy.add(user.uid);
        transaction.update(ref, {'likedBy': likedBy, 'likes': FieldValue.increment(1), 'updatedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  Future<void> deleteAd() async {
    if (!isOwner || isDeleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('İlan silinsin mi?', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
        content: const Text('Bu ilan pasif yapılacak. Yorumlar silinmez, sadece ilan listeden kalkar.', style: TextStyle(fontFamily: 'Roboto')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => isDeleting = true);
    await firestore.collection('towAds').doc(widget.ad.id).set({
      'status': 'deleted',
      'deleted': true,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<String> lockedOwnerPhone(String userId, String fallbackPhone) async {
    final safeFallback = fallbackPhone.trim();
    if (userId.trim().isEmpty) return safeFallback;

    try {
      final snap = await firestore.collection('users').doc(userId).get();
      final data = snap.data() ?? <String, dynamic>{};
      final phone = TowTruckAd._readString(
        data,
        ['phone', 'phoneNumber', 'telefon', 'tel', 'mobilePhone'],
        fallback: safeFallback,
      );
      return phone.trim();
    } catch (_) {
      return safeFallback;
    }
  }

  Future<void> callLockedOwnerPhone(TowTruckAd ad) async {
    final phone = await lockedOwnerPhone(ad.userId, ad.phone);
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      showSnack('Profil telefon numarası bulunamadı.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> editAdDialog(TowTruckAd ad) async {
    if (!isOwner || ad.id.isEmpty) return;

    final company = TextEditingController(text: ad.companyName);
    final price = TextEditingController(text: ad.priceInfo);
    final desc = TextEditingController(text: ad.description);
    final lockedPhone = await lockedOwnerPhone(ad.userId, ad.phone);

    XFile? selectedImage;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, dialogSetState) {
              Future<void> pickNewImage() async {
                try {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 92,
                    maxWidth: 1600,
                    maxHeight: 1600,
                  );
                  if (picked == null) return;
                  dialogSetState(() => selectedImage = picked);
                } catch (_) {
                  if (mounted) showSnack('Görsel seçilemedi.');
                }
              }

              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'İlanı Düzenle',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 1.75,
                          child: selectedImage == null
                              ? NovaNetworkImage(url: ad.imageUrl)
                              : Image.file(File(selectedImage!.path), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: pickNewImage,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: Text(
                            selectedImage == null ? 'Görsel Değiştir' : 'Yeni Görsel Seçildi',
                            style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black, width: 1.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EditField(controller: company, hint: 'Firma adı'),
                      const SizedBox(height: 9),
                      _EditField(controller: price, hint: 'Ücret bilgisi'),
                      const SizedBox(height: 9),
                      LockedPhoneEditBox(phone: lockedPhone),
                      const SizedBox(height: 9),
                      _EditField(controller: desc, hint: 'Açıklama', maxLines: 4),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text(
                                  'Vazgeç',
                                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text(
                                  'Kaydet',
                                  style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (result != true) return;
      if (!mounted) return;

      setState(() => isDeleting = true);

      final Map<String, dynamic> updateData = {
        'companyName': company.text.trim(),
        'priceInfo': price.text.trim(),
        'description': desc.text.trim(),
        'phone': lockedPhone,
        'phoneLocked': true,
        'phoneSource': 'profile',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (selectedImage != null) {
        final file = File(selectedImage!.path);
        final path = 'towAds/${ad.userId}/${ad.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(path);
        final task = await ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'towAdId': ad.id,
              'ownerId': ad.userId,
              'type': 'tow_ad_cover',
            },
          ),
        );
        final imageUrl = await task.ref.getDownloadURL();
        updateData['imageUrl'] = imageUrl;
        updateData['image'] = imageUrl;
        updateData['coverImage'] = imageUrl;
        updateData['imagePath'] = path;
      }

      await firestore.collection('towAds').doc(ad.id).set(updateData, SetOptions(merge: true));
      if (mounted) showSnack('İlan güncellendi.');
    } catch (e) {
      if (mounted) showSnack('İlan güncellenirken hata oluştu.');
    } finally {
      company.dispose();
      price.dispose();
      desc.dispose();
      if (mounted) setState(() => isDeleting = false);
    }
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('towAds').doc(widget.ad.id).snapshots(),
      builder: (context, adSnapshot) {
        final ad = adSnapshot.hasData && adSnapshot.data!.exists
            ? TowTruckAd.fromSnapshot(adSnapshot.data!)
            : widget.ad;
        final uid = auth.currentUser?.uid ?? '';
        return MediaQuery(
          data: MediaQuery.of(context),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        pinned: true,
                        centerTitle: true,
                        title: const Text('Çekici İlanı', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)),
                        actions: [
                          if (isOwner)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
                              onSelected: (value) {
                                if (value == 'edit') editAdDialog(ad);
                                if (value == 'delete') deleteAd();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, color: Colors.black), SizedBox(width: 8), Text('İlanı düzenle')])),
                                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, color: Colors.red), SizedBox(width: 8), Text('İlanı sil')])),
                              ],
                            ),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(borderRadius: BorderRadius.circular(24), child: AspectRatio(aspectRatio: 1, child: NovaNetworkImage(url: ad.imageUrl))),
                            const SizedBox(height: 16),
                            Text(ad.companyName, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 25, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            LiveOwnerTile(userId: ad.userId, fallbackName: ad.ownerName, fallbackUsername: ad.usernameClean, fallbackPhoto: ad.ownerPhotoUrl, onTap: widget.onOwnerTap),
                            const SizedBox(height: 12),
                            Row(children: [StarRating(value: ad.rating, size: 22), const SizedBox(width: 8), Text('${ad.rating.toStringAsFixed(1)} puan • ${ad.commentCount} yorum', style: const TextStyle(fontFamily: 'Roboto', color: Colors.black87, fontWeight: FontWeight.w900))]),
                            const SizedBox(height: 14),
                            Row(children: [Expanded(child: DetailBox(icon: Icons.location_on_rounded, title: 'Konum', value: '${ad.city} / ${ad.district}')), const SizedBox(width: 10), Expanded(child: PriceInfoBox(value: ad.priceInfo))]),
                            const SizedBox(height: 10),
                            LiveLockedPhoneBox(userId: ad.userId, fallbackPhone: ad.phone),
                            const SizedBox(height: 10),
                            DetailBox(icon: Icons.description_rounded, title: 'Açıklama', value: ad.description),
                            const SizedBox(height: 16),
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: firestore.collection('towAds').doc(ad.id).collection('reactions').doc(uid).snapshots(),
                              builder: (context, reactionSnap) {
                                final myType = reactionSnap.data?.data()?['type']?.toString() ?? '';
                                return Row(children: [
                                  Expanded(child: AnimatedReactionButton(controller: likeAnim, selected: myType == 'like', icon: Icons.thumb_up_alt_rounded, title: 'Beğen', value: ad.likes, onTap: () => toggleReaction('like'))),
                                  const SizedBox(width: 10),
                                  Expanded(child: AnimatedReactionButton(controller: dislikeAnim, selected: myType == 'dislike', icon: Icons.thumb_down_alt_rounded, title: 'Beğenme', value: ad.dislikes, onTap: () => toggleReaction('dislike'))),
                                ]);
                              },
                            ),
                            const SizedBox(height: 18),
                            const Text('Hizmetler', style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: ad.services.map((service) => ServiceChip(text: service)).toList()),
                            const SizedBox(height: 24),
                            const Text('Yorum Yap', style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900)),
                            Row(children: List.generate(5, (index) { final star = index + 1; return IconButton(onPressed: () => setState(() => selectedStars = star), icon: Icon(star <= selectedStars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.orange, size: 31)); })),
                            TextField(controller: commentController, minLines: 2, maxLines: 4, decoration: InputDecoration(hintText: 'Yorumun', hintStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700), filled: true, fillColor: Colors.black.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.black.withOpacity(0.08))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.black, width: 1.2)))),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: isSending ? null : submitComment, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(isSending ? 'Kaydediliyor...' : 'Yorumu Kaydet', style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)))),
                            const SizedBox(height: 22),
                            const Text('Yorumlar', style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: firestore.collection('towAds').doc(ad.id).collection('comments').orderBy('createdAt', descending: true).snapshots(),
                              builder: (context, snapshot) {
                                final comments = (snapshot.data?.docs ?? []).map(TowComment.fromDoc).where((c) => !c.deleted).toList();
                                if (comments.isEmpty) return const Text('Henüz yorum yok.', style: TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontWeight: FontWeight.w800));
                                return Column(children: comments.map((comment) => TowCommentCard(comment: comment, currentUid: uid, onLike: () => toggleCommentLike(comment))).toList());
                              },
                            ),
                            SizedBox(height: bottomPadding + 92),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  Positioned(left: 12, right: 12, bottom: bottomPadding + 10, child: Row(children: [
                    Expanded(child: NeonMessageButton(controller: neonButtonController, onPressed: isOwner ? null : widget.onMessage)),
                    const SizedBox(width: 10),
                    Expanded(child: SizedBox(height: 54, child: ElevatedButton.icon(onPressed: () => callLockedOwnerPhone(ad), icon: const Icon(Icons.call_rounded), label: const Text('Ara', style: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))))))
                  ])),
                  if (isDeleting) Container(color: Colors.white.withOpacity(0.72), child: const Center(child: CircularProgressIndicator(color: Colors.black))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _EditField({required this.controller, required this.hint, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller, maxLines: maxLines, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700), filled: true, fillColor: Colors.black.withOpacity(0.035), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black.withOpacity(0.10))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.black.withOpacity(0.10))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black, width: 1.2))));
  }
}

class LiveOwnerTile extends StatelessWidget {
  final String userId;
  final String fallbackName;
  final String fallbackUsername;
  final String fallbackPhoto;
  final VoidCallback onTap;
  const LiveOwnerTile({super.key, required this.userId, required this.fallbackName, required this.fallbackUsername, required this.fallbackPhoto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userId.trim().isEmpty ? null : FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = TowTruckAd._readString(data, ['displayName', 'fullName', 'name'], fallback: fallbackName);
        final username = TowTruckAd._readString(data, ['username'], fallback: fallbackUsername).replaceAll('@', '');
        final photo = TowTruckAd._readString(data, ['photoUrl', 'userPhoto', 'profileImage', 'profileImageUrl', 'avatarUrl'], fallback: fallbackPhoto);
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              ProfileCircle(photoUrl: photo, radius: 20),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
                Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w800)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Colors.black),
            ]),
          ),
        );
      },
    );
  }
}

class ProfileCircle extends StatelessWidget {
  final String photoUrl;
  final double radius;
  const ProfileCircle({super.key, required this.photoUrl, this.radius = 18});
  @override
  Widget build(BuildContext context) {
    if (photoUrl.trim().isEmpty) return CircleAvatar(radius: radius, backgroundColor: Colors.black, child: Icon(Icons.person_rounded, color: Colors.white, size: radius));
    return CircleAvatar(radius: radius, backgroundColor: Colors.black12, backgroundImage: NetworkImage(photoUrl));
  }
}

class AnimatedReactionButton extends StatelessWidget {
  final AnimationController controller;
  final bool selected;
  final IconData icon;
  final String title;
  final int value;
  final VoidCallback onTap;

  const AnimatedReactionButton({
    super.key,
    required this.controller,
    required this.selected,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  bool get isLikeButton => title.toLowerCase().contains('beğen') && !title.toLowerCase().contains('beğenme');

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isLikeButton ? const Color(0xFF10B34F) : const Color(0xFFE53935);

    return SizedBox(
      height: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.black.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? activeColor : Colors.black.withOpacity(0.07),
              width: 1.1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: activeColor.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.black, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: selected ? Colors.white : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                value.toString(),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: selected ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NeonMessageButton extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback? onPressed;

  const NeonMessageButton({
    super.key,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 54,
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: enabled
                ? SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFFFF00B8),
                Color(0xFFFFFF00),
                Color(0xFF7C4DFF),
                Color(0xFF00D9FF),
              ],
            )
                : const LinearGradient(
              colors: [
                Color(0xFFE0E0E0),
                Color(0xFFE0E0E0),
              ],
            ),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.20),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: const Color(0xFFFF00B8).withOpacity(0.18),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 7),
              ),
            ]
                : const [],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              splashColor: Colors.black.withOpacity(0.06),
              highlightColor: Colors.black.withOpacity(0.035),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_rounded,
                      color: enabled ? Colors.black : Colors.black38,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mesaj Gönder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: enabled ? Colors.black : Colors.black38,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TowCommentCard extends StatelessWidget {
  final TowComment comment;
  final String currentUid;
  final VoidCallback onLike;
  const TowCommentCard({super.key, required this.comment, required this.currentUid, required this.onLike});
  @override
  Widget build(BuildContext context) {
    final liked = comment.likedBy.contains(currentUid);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.045), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [ProfileCircle(photoUrl: comment.userPhotoUrl, radius: 17), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(comment.userName, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900)), Text('@${comment.usernameClean}', style: const TextStyle(fontFamily: 'Roboto', color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w800))])), StarRating(value: comment.stars.toDouble(), size: 16)]),
        const SizedBox(height: 8),
        Text(comment.text, style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontWeight: FontWeight.w700, height: 1.35)),
        const SizedBox(height: 8),
        InkWell(onTap: onLike, borderRadius: BorderRadius.circular(99), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: liked ? Colors.black : Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.black12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.favorite_rounded, color: liked ? Colors.white : Colors.black, size: 16), const SizedBox(width: 5), Text(comment.likes.toString(), style: TextStyle(fontFamily: 'Roboto', color: liked ? Colors.white : Colors.black, fontWeight: FontWeight.w900))]))),
      ]),
    );
  }
}

class _ReactionBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReactionBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class NovaNetworkImage extends StatelessWidget {
  final String url;

  const NovaNetworkImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.black,
        child: const Icon(Icons.fire_truck_rounded, color: Colors.white, size: 60),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.black,
          child: const Icon(Icons.fire_truck_rounded, color: Colors.white, size: 60),
        );
      },
    );
  }
}

class StarRating extends StatelessWidget {
  final double value;
  final double size;

  const StarRating({super.key, required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final rounded = value.round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rounded ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.orange,
          size: size,
        );
      }),
    );
  }
}

class MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const MiniActionButton({super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          text,
          style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class OnlineBadge extends StatelessWidget {
  final bool isOnline;

  const OnlineBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.withOpacity(0.12) : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        isOnline ? '7/24' : 'Aktif',
        style: TextStyle(
          fontFamily: 'Roboto',
          color: isOnline ? Colors.green : Colors.black45,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.055),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black54,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceChip extends StatelessWidget {
  final String text;

  const ServiceChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PriceInfoBox extends StatelessWidget {
  final String value;

  const PriceInfoBox({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? 'Fiyat bilgisi yok' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0FB85A).withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0FB85A).withOpacity(0.36), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0FB85A).withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, color: Color(0xFF0B8F43), size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ücret',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF087A38),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF0B8F43),
                    fontSize: 17,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
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

class LiveLockedPhoneBox extends StatelessWidget {
  final String userId;
  final String fallbackPhone;

  const LiveLockedPhoneBox({
    super.key,
    required this.userId,
    required this.fallbackPhone,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userId.trim().isEmpty ? null : FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final phone = TowTruckAd._readString(
          data,
          ['phone', 'phoneNumber', 'telefon', 'tel', 'mobilePhone'],
          fallback: fallbackPhone,
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.045),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.black, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Telefon',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.trim().isEmpty ? 'Profil telefon numarası eksik' : phone.trim(),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black54,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Profilden çekilir, ilanda değiştirilemez.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LockedPhoneEditBox extends StatelessWidget {
  final String phone;

  const LockedPhoneEditBox({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.black, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Telefon numarası kilitli',
                  style: TextStyle(fontFamily: 'Roboto', color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.trim().isEmpty ? 'Profilde telefon numarası yok' : phone.trim(),
                  style: const TextStyle(fontFamily: 'Roboto', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const DetailBox({super.key, required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.045),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class EmptyTowState extends StatelessWidget {
  final String city;
  final String district;

  const EmptyTowState({super.key, required this.city, required this.district});

  @override
  Widget build(BuildContext context) {
    final text = city == 'Tüm İller'
        ? 'Henüz çekici ilanı bulunamadı.'
        : district == 'Tüm İlçeler'
        ? '$city için çekici ilanı bulunamadı.'
        : '$city / $district için çekici ilanı bulunamadı.';

    return Container(
      height: 210,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fire_truck_outlined, color: Colors.black26, size: 62),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Roboto',
              color: Colors.black54,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorTowState extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;

  const ErrorTowState({super.key, required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 58, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Roboto',
                color: Colors.black54,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}


class TowAdDmBoxPage extends StatefulWidget {
  final String conversationId;
  final String receiverId;
  final TowTruckAd ad;
  final Future<void> Function({
  required TowTruckAd ad,
  required String type,
  required String title,
  required String body,
  String commentText,
  int stars,
  }) onNotifyOwner;

  const TowAdDmBoxPage({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.ad,
    required this.onNotifyOwner,
  });

  @override
  State<TowAdDmBoxPage> createState() => _TowAdDmBoxPageState();
}

class _TowAdDmBoxPageState extends State<TowAdDmBoxPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isSending = false;

  @override
  void initState() {
    super.initState();
    messageController.text =
    'Merhaba, ${widget.ad.companyName} çekici ilanınız hakkında bilgi almak istiyorum.';
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> currentUserInfo() async {
    final user = auth.currentUser;
    if (user == null) return <String, String>{};

    var name = user.displayName ?? user.email ?? 'NOVA Kullanıcısı';
    var username = user.email?.split('@').first ?? 'nova.user';
    var photoUrl = user.photoURL ?? '';

    try {
      final snap = await firestore.collection('users').doc(user.uid).get();
      final data = snap.data() ?? <String, dynamic>{};
      name = TowTruckAd._readString(data, ['displayName', 'fullName', 'name', 'username'], fallback: name);
      username = TowTruckAd._readString(data, ['username'], fallback: username).replaceAll('@', '');
      photoUrl = TowTruckAd._readString(data, ['photoUrl', 'profileImageUrl', 'avatarUrl'], fallback: photoUrl);
    } catch (_) {}

    return {
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
    };
  }

  Future<void> sendMessage() async {
    final user = auth.currentUser;
    final text = messageController.text.trim();

    if (user == null) {
      showSnack('Mesaj göndermek için giriş yapmalısın.');
      return;
    }

    if (text.isEmpty || isSending) return;

    setState(() => isSending = true);

    try {
      final info = await currentUserInfo();
      final conversationRef = firestore.collection('conversations').doc(widget.conversationId);
      final messageRef = conversationRef.collection('messages').doc();

      await messageRef.set({
        'id': messageRef.id,
        'conversationId': widget.conversationId,
        'senderId': user.uid,
        'receiverId': widget.receiverId,
        'text': text,
        'message': text,
        'type': 'tow_ad_text',
        'messageType': 'tow_ad_text',
        'towAdId': widget.ad.id,
        'towAdTitle': widget.ad.companyName,
        'towAdImage': widget.ad.imageUrl,
        'towAdPrice': widget.ad.priceInfo,
        'towAdLocation': '${widget.ad.city} / ${widget.ad.district}',
        'towAdOwnerId': widget.ad.userId,
        'adPreview': {
          'id': widget.ad.id,
          'title': widget.ad.companyName,
          'imageUrl': widget.ad.imageUrl,
          'price': widget.ad.priceInfo,
          'location': '${widget.ad.city} / ${widget.ad.district}',
          'type': 'tow_ad',
        },
        'senderName': info['name'] ?? '',
        'senderUsername': info['username'] ?? '',
        'senderPhotoUrl': info['photoUrl'] ?? '',
        'read': false,
        'seen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await conversationRef.set({
        'id': widget.conversationId,
        'participants': [user.uid, widget.receiverId]..sort(),
        'participantIds': [user.uid, widget.receiverId]..sort(),
        'userIds': [user.uid, widget.receiverId]..sort(),
        'lastMessage': text,
        'lastMessageType': 'tow_ad_text',
        'lastSenderId': user.uid,
        'lastReceiverId': widget.receiverId,
        'towAdId': widget.ad.id,
        'towAdTitle': widget.ad.companyName,
        'towAdImage': widget.ad.imageUrl,
        'towAdPrice': widget.ad.priceInfo,
        'towAdLocation': '${widget.ad.city} / ${widget.ad.district}',
        'unreadBy': FieldValue.arrayUnion([widget.receiverId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await widget.onNotifyOwner(
        ad: widget.ad,
        type: 'tow_message',
        title: 'Çekici ilanına mesaj',
        body: '${info['name'] ?? 'Bir kullanıcı'} çekici ilanı için mesaj gönderdi.',
      );

      messageController.clear();

      await Future.delayed(const Duration(milliseconds: 120));
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      showSnack('Mesaj gönderilemedi. Lütfen tekrar dene.');
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final currentUid = auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mesaj Kutusu',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          TowAdChatPreview(ad: widget.ad),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 34),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'İlan önizlemesi hazır',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Mesaj otomatik gitmedi. Aşağıdaki hazır mesajı düzenleyip gönderebilirsin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.black54,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = data['senderId']?.toString() == currentUid;
                    final text = data['text']?.toString() ?? data['message']?.toString() ?? '';
                    return TowAdMessageBubble(
                      isMe: isMe,
                      text: text,
                      showPreview: data['towAdId']?.toString().isNotEmpty == true,
                      ad: widget.ad,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(10, 9, 10, bottomPadding + 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48, maxHeight: 116),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black, width: 1.2),
                    ),
                    child: TextField(
                      controller: messageController,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Mesaj yaz...',
                        hintStyle: TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.black38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSending ? null : sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: isSending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.send_rounded, size: 24),
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

class TowAdChatPreview extends StatelessWidget {
  final TowTruckAd ad;

  const TowAdChatPreview({
    super.key,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 78,
              height: 78,
              child: NovaNetworkImage(url: ad.imageUrl),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.companyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ad.city} / ${ad.district}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    ad.priceInfo.isEmpty ? 'Ücret bilgisi yok' : ad.priceInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
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

class TowAdMessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final bool showPreview;
  final TowTruckAd ad;

  const TowAdMessageBubble({
    super.key,
    required this.isMe,
    required this.text,
    required this.showPreview,
    required this.ad,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.78,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: isMe
              ? const LinearGradient(colors: [Colors.black, Colors.black])
              : LinearGradient(colors: [Colors.black.withOpacity(0.18), Colors.black.withOpacity(0.08)]),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isMe ? 0.18 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isMe ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPreview) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isMe ? Colors.white24 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: NovaNetworkImage(url: ad.imageUrl),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ad.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: isMe ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ad.priceInfo.isEmpty ? '${ad.city} / ${ad.district}' : ad.priceInfo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: isMe ? Colors.white : Colors.black,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class TowTruckAd {
  final String id;
  final String userId;
  final String username;
  final String companyName;
  final String ownerName;
  final String city;
  final String district;
  final String priceInfo;
  final String phone;
  final String imageUrl;
  final String ownerPhotoUrl;
  final String description;
  final List<String> services;
  final int likes;
  final int dislikes;
  final int ratingTotal;
  final int commentCount;
  final bool isOpen247;

  const TowTruckAd({
    required this.id,
    required this.userId,
    required this.username,
    required this.companyName,
    required this.ownerName,
    required this.city,
    required this.district,
    required this.priceInfo,
    required this.phone,
    required this.imageUrl,
    required this.ownerPhotoUrl,
    required this.description,
    required this.services,
    required this.likes,
    required this.dislikes,
    required this.ratingTotal,
    required this.commentCount,
    required this.isOpen247,
  });

  String get usernameClean {
    final clean = username.replaceAll('@', '').trim();
    if (clean.isNotEmpty) return clean;
    final owner = ownerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    return owner.isEmpty ? 'nova.user' : owner;
  }

  double get rating {
    if (commentCount <= 0) return 0;
    return ratingTotal / commentCount;
  }

  factory TowTruckAd.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final services = _stringList(data['services'] ?? data['hizmetler']);
    return TowTruckAd(
      id: doc.id,
      userId: _readString(data, ['userId', 'ownerId', 'uid', 'sellerId']),
      username: _readString(data, ['username', 'ownerUsername', 'sellerUsername', 'userName']),
      companyName: _readString(data, ['companyName', 'firmaAdi', 'company'], fallback: 'Çekici Hizmeti'),
      ownerName: _readString(data, ['ownerName', 'authorizedName', 'yetkiliAdi', 'name'], fallback: 'Yetkili'),
      city: _readString(data, ['city', 'il'], fallback: '-'),
      district: _readString(data, ['district', 'ilce'], fallback: '-'),
      priceInfo: _readString(data, ['priceInfo', 'price', 'priceText', 'ucret'], fallback: 'Fiyat bilgisi yok'),
      phone: _readString(data, ['phone', 'sellerPhone', 'telefon']),
      imageUrl: _readString(data, ['image', 'imageUrl', 'photoUrl', 'coverImage']),
      ownerPhotoUrl: _readString(data, ['ownerPhotoUrl', 'userPhoto', 'photoUrl', 'profileImage', 'profileImageUrl', 'avatarUrl']),
      description: _readString(data, ['description', 'aciklama'], fallback: 'Açıklama girilmemiş.'),
      services: services.isEmpty ? ['Çekici'] : services,
      likes: _readInt(data['likes'] ?? data['likeCount']),
      dislikes: _readInt(data['dislikes'] ?? data['dislikeCount']),
      ratingTotal: _readInt(data['ratingTotal']),
      commentCount: _readInt(data['commentCount'] ?? data['commentsCount']),
      isOpen247: data['isOpen247'] == true || services.contains('7/24 çekici'),
    );
  }

  factory TowTruckAd.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final services = _stringList(data['services'] ?? data['hizmetler']);

    return TowTruckAd(
      id: doc.id,
      userId: _readString(data, ['userId', 'ownerId', 'uid', 'sellerId']),
      username: _readString(data, ['username', 'ownerUsername', 'sellerUsername', 'userName']),
      companyName: _readString(data, ['companyName', 'firmaAdi', 'company'], fallback: 'Çekici Hizmeti'),
      ownerName: _readString(data, ['ownerName', 'authorizedName', 'yetkiliAdi', 'name'], fallback: 'Yetkili'),
      city: _readString(data, ['city', 'il'], fallback: '-'),
      district: _readString(data, ['district', 'ilce'], fallback: '-'),
      priceInfo: _readString(data, ['priceInfo', 'price', 'priceText', 'ucret'], fallback: 'Fiyat bilgisi yok'),
      phone: _readString(data, ['phone', 'sellerPhone', 'telefon']),
      imageUrl: _readString(data, ['image', 'imageUrl', 'photoUrl', 'coverImage']),
      ownerPhotoUrl: _readString(data, ['ownerPhotoUrl', 'userPhoto', 'photoUrl', 'profileImage', 'profileImageUrl', 'avatarUrl']),
      description: _readString(data, ['description', 'aciklama'], fallback: 'Açıklama girilmemiş.'),
      services: services.isEmpty ? ['Çekici'] : services,
      likes: _readInt(data['likes'] ?? data['likeCount']),
      dislikes: _readInt(data['dislikes'] ?? data['dislikeCount']),
      ratingTotal: _readInt(data['ratingTotal']),
      commentCount: _readInt(data['commentCount'] ?? data['commentsCount']),
      isOpen247: data['isOpen247'] == true || services.contains('7/24 çekici'),
    );
  }

  static String _readString(Map<String, dynamic> data, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return [];
  }
}

class TowComment {
  final String id;
  final String userId;
  final String userName;
  final String username;
  final String userPhotoUrl;
  final String text;
  final int stars;
  final int likes;
  final List<String> likedBy;
  final bool deleted;

  const TowComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.username,
    required this.userPhotoUrl,
    required this.text,
    required this.stars,
    required this.likes,
    required this.likedBy,
    required this.deleted,
  });

  String get usernameClean {
    final clean = username.replaceAll('@', '').trim();
    return clean.isEmpty ? 'nova.user' : clean;
  }

  factory TowComment.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return TowComment(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'NOVA Kullanıcısı',
      username: data['username']?.toString() ?? '',
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? data['photoUrl']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      stars: data['stars'] is int ? data['stars'] as int : int.tryParse(data['stars']?.toString() ?? '') ?? 5,
      likes: TowTruckAd._readInt(data['likes']),
      likedBy: List<String>.from((data['likedBy'] as List?)?.map((e) => e.toString()) ?? const <String>[]),
      deleted: data['deleted'] == true || data['isDeleted'] == true,
    );
  }
}
