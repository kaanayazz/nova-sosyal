import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage>
    with SingleTickerProviderStateMixin {
  String selectedCity = 'Eskişehir';
  String selectedDistrict = 'Odunpazarı';
  String selectedTab = 'Yaklaşan';

  late final AnimationController neonController;
  Timer? _timer;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<User?>? _authSub;

  final List<NovaEvent> events = [];
  NovaUserProfile currentProfile = NovaUserProfile.empty();

  bool pageLoading = true;

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

  @override
  void initState() {
    super.initState();

    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _authSub = _auth.authStateChanges().listen((_) {
      _listenFirebaseData();
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _profileSub?.cancel();
    _authSub?.cancel();
    _timer?.cancel();
    neonController.dispose();
    super.dispose();
  }

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _eventsRef {
    return _firestore.collection('events');
  }

  DocumentReference<Map<String, dynamic>>? get _profileRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  void _listenFirebaseData() {
    final profileRef = _profileRef;

    if (profileRef == null) {
      _eventsSub?.cancel();
      _profileSub?.cancel();
      if (mounted) {
        setState(() {
          events.clear();
          currentProfile = NovaUserProfile.empty();
          pageLoading = false;
        });
      }
      return;
    }

    _profileSub?.cancel();
    _eventsSub?.cancel();

    _profileSub = profileRef.snapshots().listen((doc) {
      if (!mounted) return;
      setState(() {
        currentProfile = NovaUserProfile.fromFirestore(doc.id, doc.data() ?? {});
        final profileCity = currentProfile.city.trim();
        final profileDistrict = currentProfile.district.trim();
        if (cityDistricts.containsKey(profileCity)) {
          selectedCity = profileCity;
          final districts = cityDistricts[profileCity]!;
          selectedDistrict = districts.contains(profileDistrict)
              ? profileDistrict
              : districts.first;
        }
      });
    });

    _eventsSub = _eventsRef
        .orderBy('startAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      final loadedEvents = snapshot.docs
          .map((doc) => NovaEvent.fromFirestore(doc.id, doc.data()))
          .where((event) => event.status == 'active')
          .toList();

      if (!mounted) return;
      setState(() {
        events
          ..clear()
          ..addAll(loadedEvents);
        pageLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => pageLoading = false);
    });
  }

  Future<void> refreshFirebaseData() async {
    _eventsSub?.cancel();
    _profileSub?.cancel();

    if (mounted) {
      setState(() => pageLoading = true);
    }

    _listenFirebaseData();
    await Future.delayed(const Duration(milliseconds: 650));

    if (mounted) {
      setState(() => pageLoading = false);
    }
  }

  List<NovaEvent> get filteredEvents {
    final now = DateTime.now();

    final list = events.where((event) {
      final sameLocation = event.city == selectedCity && event.district == selectedDistrict;
      final completed = event.startAt.isBefore(now);
      if (selectedTab == 'Yaklaşan') return sameLocation && !completed;
      return sameLocation && completed;
    }).toList();

    if (selectedTab == 'Yaklaşan') {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
    } else {
      list.sort((a, b) => b.startAt.compareTo(a.startAt));
    }

    return list;
  }

  List<NovaEvent> get upcomingEvents {
    final now = DateTime.now();
    return events.where((event) {
      return event.city == selectedCity &&
          event.district == selectedDistrict &&
          event.startAt.isAfter(now);
    }).toList();
  }

  List<NovaEvent> get completedEvents {
    final now = DateTime.now();
    return events.where((event) {
      return event.city == selectedCity &&
          event.district == selectedDistrict &&
          event.startAt.isBefore(now);
    }).toList();
  }

  String countdownText(DateTime date) {
    final diff = date.difference(DateTime.now());

    if (diff.isNegative) return 'Etkinlik bitti';

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    if (days > 0) return '$days gün $hours saat $minutes dk';
    return '$hours saat $minutes dk $seconds sn';
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool isCreator(NovaEvent event) {
    return currentUserId != null && event.creatorId == currentUserId;
  }

  bool isJoined(NovaEvent event) {
    final uid = currentUserId;
    if (uid == null) return false;
    return event.participants.contains(uid);
  }

  Future<void> toggleJoinEvent(NovaEvent event) async {
    final uid = currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katılım için giriş yapmalısın.')),
      );
      return;
    }

    if (event.startAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biten etkinliğe katılım değiştirilemez.')),
      );
      return;
    }

    final joined = isJoined(event);
    final ref = _eventsRef.doc(event.id);

    try {
      await ref.set({
        'participants': joined ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
        'participantNames.$uid': joined ? FieldValue.delete() : currentProfile.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Katılım güncellenemedi: $e')),
      );
    }
  }

  Future<void> deleteEvent(NovaEvent event) async {
    if (!isCreator(event)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu etkinliği sadece oluşturan kişi silebilir.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Etkinlik silinsin mi?'),
        content: const Text('Bu etkinlik ve katılım bilgileri kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _eventsRef.doc(event.id).delete();
      if (event.imageUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(event.imageUrl).delete();
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Etkinlik silinemedi: $e')),
      );
    }
  }

  Future<void> openReportSheet(NovaEvent event) async {
    final controller = TextEditingController();
    String selectedReason = 'Uygunsuz içerik';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return NovaBottomSheet(
              title: 'Etkinliği Şikayet Et',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetLabel('Şikayet Nedeni'),
                  const SizedBox(height: 8),
                  NovaDropdown(
                    value: selectedReason,
                    items: const [
                      'Uygunsuz içerik',
                      'Yanlış bilgi',
                      'Spam / reklam',
                      'Tehlikeli etkinlik',
                      'Diğer',
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedReason = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  const SheetLabel('Açıklama'),
                  const SizedBox(height: 8),
                  NovaInput(
                    controller: controller,
                    hint: 'Neden uygunsuz olduğunu yaz...',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () async {
                      final detail = controller.text.trim();
                      if (detail.length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen kısa bir açıklama yaz.')),
                        );
                        return;
                      }

                      await _firestore.collection('eventReports').add({
                        'eventId': event.id,
                        'eventTitle': event.title,
                        'eventCreatorId': event.creatorId,
                        'reason': selectedReason,
                        'description': detail,
                        'reporterId': currentUserId,
                        'reporterName': currentProfile.displayName,
                        'status': 'new',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Şikayet gönderildi.')),
                      );
                    },
                    child: const BlackButton(
                      title: 'Şikayeti Gönder',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> openAddEventPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          cities: cityDistricts,
          defaultCity: selectedCity,
          defaultDistrict: selectedDistrict,
          profile: currentProfile,
        ),
      ),
    );
  }

  void openEventDetail(NovaEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          profile: currentProfile,
          countdown: countdownText(event.startAt),
          dateText: formatDate(event.startAt),
          joined: isJoined(event),
          canDelete: isCreator(event),
          onJoin: () => toggleJoinEvent(event),
          onDelete: () => deleteEvent(event),
          onReport: () => openReportSheet(event),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districts = cityDistricts[selectedCity] ?? cityDistricts.values.first;
    final list = filteredEvents;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const NovaWhiteBackground(),
            SafeArea(
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: refreshFirebaseData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHeader(),
                            const SizedBox(height: 12),
                            if (pageLoading) ...[
                              const LoadingEventPanel(),
                              const SizedBox(height: 12),
                            ],
                            buildProfileCard(),
                            const SizedBox(height: 12),
                            buildActionButtons(),
                            const SizedBox(height: 12),
                            buildLocationFilters(districts),
                            const SizedBox(height: 14),
                            buildTabs(),
                            const SizedBox(height: 14),
                            buildStats(),
                            const SizedBox(height: 14),
                            buildEventList(list),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader() {
    return const Text(
      'Etkinlikler',
      style: TextStyle(
        color: Colors.black,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        fontFamily: 'Roboto',
      ),
    );
  }

  Widget buildProfileCard() {
    return PlainCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          NeonAvatar(
            controller: neonController,
            imageUrl: currentProfile.photoUrl,
            icon: Icons.person_rounded,
            size: 54,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentProfile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentProfile.username.isEmpty ? 'Nova kullanıcısı' : '@${currentProfile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${currentProfile.city.isEmpty ? selectedCity : currentProfile.city} / ${currentProfile.district.isEmpty ? selectedDistrict : currentProfile.district}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black38,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    return NovaActionButton(
      title: 'Etkinlik Kur',
      icon: Icons.add_rounded,
      controller: neonController,
      onTap: openAddEventPage,
    );
  }

  Widget buildLocationFilters(List<String> districts) {
    return PlainCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: NovaDropdown(
              value: selectedCity,
              items: cityDistricts.keys.toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedCity = value;
                  selectedDistrict = cityDistricts[value]!.first;
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NovaDropdown(
              value: selectedDistrict,
              items: districts,
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedDistrict = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabs() {
    final tabs = ['Yaklaşan', 'Biten'];

    return PlainCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: tabs.map((tab) {
          final selected = selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTab = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildStats() {
    return Row(
      children: [
        Expanded(
          child: MiniEventStat(
            icon: Icons.event_available_rounded,
            title: 'Yaklaşan',
            value: '${upcomingEvents.length} etkinlik',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MiniEventStat(
            icon: Icons.history_rounded,
            title: 'Biten',
            value: '${completedEvents.length} etkinlik',
          ),
        ),
      ],
    );
  }

  Widget buildEventList(List<NovaEvent> list) {
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NovaCardTitle(
            title: selectedTab == 'Yaklaşan' ? 'Yaklaşan Etkinlikler' : 'Biten Etkinlikler',
            subtitle: '${selectedCity} / ${selectedDistrict} için etkinlik akışı.',
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            EmptyNovaBox(
              text: selectedTab == 'Yaklaşan'
                  ? 'Bu bölgede yaklaşan etkinlik yok.'
                  : 'Bu bölgede biten etkinlik yok.',
            )
          else
            Column(
              children: list.map((event) {
                return EventCard(
                  event: event,
                  countdown: countdownText(event.startAt),
                  dateText: formatDate(event.startAt),
                  joined: isJoined(event),
                  canDelete: isCreator(event),
                  controller: neonController,
                  onTap: () => openEventDetail(event),
                  onJoin: () => toggleJoinEvent(event),
                  onDelete: () => deleteEvent(event),
                  onReport: () => openReportSheet(event),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class AddEventPage extends StatefulWidget {
  final Map<String, List<String>> cities;
  final String defaultCity;
  final String defaultDistrict;
  final NovaUserProfile profile;

  const AddEventPage({
    super.key,
    required this.cities,
    required this.defaultCity,
    required this.defaultDistrict,
    required this.profile,
  });

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage>
    with SingleTickerProviderStateMixin {
  late String city;
  late String district;
  late final AnimationController neonController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final descController = TextEditingController();
  final phoneController = TextEditingController();

  XFile? selectedImageFile;
  Uint8List? selectedImageBytes;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  bool saving = false;

  @override
  void initState() {
    super.initState();
    city = widget.defaultCity;
    district = widget.defaultDistrict;
    neonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    neonController.dispose();
    titleController.dispose();
    locationController.dispose();
    descController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      selectedImageFile = image;
      selectedImageBytes = bytes;
    });
  }

  Future<Map<String, String>> uploadEventImage(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Kullanıcı girişi bulunamadı.');
    }

    final bytes = selectedImageBytes ?? await selectedImageFile?.readAsBytes();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Seçilen görsel okunamadı.');
    }

    final originalName = selectedImageFile?.name.trim() ?? '';
    final cleanedName = originalName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName = cleanedName.contains('.')
        ? '${DateTime.now().millisecondsSinceEpoch}_$cleanedName'
        : '${DateTime.now().millisecondsSinceEpoch}_event.jpg';

    // Storage rules ile birebir uyumlu yol:
    // events/{userId}/{fileName}
    final ref = _storage.ref().child('events/$uid/$fileName');

    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _guessImageContentType(fileName),
        customMetadata: {'eventId': eventId, 'creatorId': uid},
      ),
    );

    if (uploadTask.state != TaskState.success) {
      throw Exception('Görsel yükleme tamamlanamadı.');
    }

    final downloadUrl = await ref.getDownloadURL();
    if (downloadUrl.trim().isEmpty) {
      throw Exception('Görsel bağlantısı alınamadı.');
    }

    return {
      'url': downloadUrl,
      'path': ref.fullPath,
    };
  }

  String _guessImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> createEvent() async {
    if (saving) return;

    final uid = _auth.currentUser?.uid;
    final title = titleController.text.trim();
    final location = locationController.text.trim();
    final phoneDigits = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final phone = '+90$phoneDigits';
    final desc = descController.text.trim();

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik yayınlamak için giriş yapmalısın.')),
      );
      return;
    }

    if (title.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik adı ve konum zorunlu.')),
      );
      return;
    }

    if (phoneDigits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon numarası +90 sonrası 10 haneli olmalıdır.')),
      );
      return;
    }

    if (!selectedDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş tarih veya saat seçemezsin.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final doc = _firestore.collection('events').doc();
      String imageUrl = '';
      String imagePath = '';

      if (selectedImageFile != null || selectedImageBytes != null) {
        try {
          final uploadedImage = await uploadEventImage(doc.id);
          imageUrl = uploadedImage['url'] ?? '';
          imagePath = uploadedImage['path'] ?? '';
        } catch (imageError) {
          debugPrint('Etkinlik görseli yüklenemedi: $imageError');
          if (!mounted) return;
          setState(() => saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Görsel yüklenemedi: $imageError')),
          );
          return;
        }
      }

      await doc.set({
        'title': title,
        'city': city,
        'district': district,
        'location': location,
        'phone': phone,
        'description': desc.isEmpty ? 'Etkinlik açıklaması eklenmedi.' : desc,
        'imageUrl': imageUrl,
        'eventImageUrl': imageUrl,
        'imagePath': imagePath,
        'creatorId': uid,
        'creatorName': widget.profile.displayName,
        'creatorUsername': widget.profile.username,
        'creatorPhotoUrl': widget.profile.photoUrl,
        'participants': [uid],
        'participantNames': {uid: widget.profile.displayName},
        'startAt': Timestamp.fromDate(selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Etkinlik kaydedilirken hata oluştu: $e');
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Etkinlik kaydedilirken hata oluştu: $e')),
      );
    }
  }

  Future<void> pickDateTime() async {
    final now = DateTime.now();
    final firstSelectableDate = DateTime(now.year, now.month, now.day);
    final safeInitialDate = selectedDate.isAfter(now)
        ? selectedDate
        : now.add(const Duration(minutes: 10));

    final date = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: firstSelectableDate,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selected.isAfter(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş tarih veya saat seçemezsin.')),
      );
      return;
    }

    setState(() {
      selectedDate = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final districts = widget.cities[city] ?? widget.cities.values.first;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const NovaWhiteBackground(),
            SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  PlainCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'Etkinlik Kur',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PlainCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NovaCardTitle(
                          title: 'Etkinlik Bilgileri',
                          subtitle: 'Etkinlik detaylarını eksiksiz doldur.',
                        ),
                        const SizedBox(height: 16),
                        const SheetLabel('Etkinlik Adı'),
                        const SizedBox(height: 8),
                        NovaInput(controller: titleController, hint: 'Örn: Nova Eskişehir araç buluşması'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: NovaDropdown(
                                value: city,
                                items: widget.cities.keys.toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    city = value;
                                    district = widget.cities[value]!.first;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: NovaDropdown(
                                value: district,
                                items: districts,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => district = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const SheetLabel('Konum'),
                        const SizedBox(height: 8),
                        NovaInput(controller: locationController, hint: 'Örn: Sazova Parkı otopark alanı'),
                        const SizedBox(height: 14),
                        const SheetLabel('Telefon'),
                        const SizedBox(height: 8),
                        NovaInput(
                          controller: phoneController,
                          hint: '5XXXXXXXXX',
                          keyboardType: TextInputType.phone,
                          prefixText: '+90 ',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: pickDateTime,
                          child: PlainInfoBox(
                            icon: Icons.calendar_month_rounded,
                            title: 'Etkinlik Tarihi',
                            value: '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year} • ${selectedDate.hour.toString().padLeft(2, '0')}:${selectedDate.minute.toString().padLeft(2, '0')}',
                            trailing: const Icon(Icons.edit_calendar_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SheetLabel('Açıklama'),
                        const SizedBox(height: 8),
                        NovaInput(controller: descController, hint: 'Etkinlik açıklaması', maxLines: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PlainCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NovaCardTitle(
                          title: 'Etkinlik Görseli',
                          subtitle: 'Galeri veya kamera ile etkinlik görseli ekle.',
                        ),
                        const SizedBox(height: 14),
                        if (selectedImageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(
                              selectedImageBytes!,
                              height: 185,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const EmptyNovaBox(text: 'Henüz görsel seçilmedi.'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: BottomActionButton(
                                title: 'Kamera',
                                icon: Icons.photo_camera_rounded,
                                color: Colors.black,
                                onTap: () => pickImage(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BottomActionButton(
                                title: 'Galeri',
                                icon: Icons.photo_library_rounded,
                                color: Colors.black,
                                onTap: () => pickImage(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: createEvent,
                    child: BlackButton(
                      title: saving ? 'Yayınlanıyor...' : 'Etkinliği Yayınla',
                      icon: Icons.publish_rounded,
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

class EventDetailPage extends StatelessWidget {
  final NovaEvent event;
  final NovaUserProfile profile;
  final String countdown;
  final String dateText;
  final bool joined;
  final bool canDelete;
  final Future<void> Function() onJoin;
  final Future<void> Function() onDelete;
  final Future<void> Function() onReport;

  const EventDetailPage({
    super.key,
    required this.event,
    required this.profile,
    required this.countdown,
    required this.dateText,
    required this.joined,
    required this.canDelete,
    required this.onJoin,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const NovaWhiteBackground(),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                PlainCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'Etkinlik Detayı',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.black),
                        onSelected: (value) async {
                          if (value == 'report') await onReport();
                          if (value == 'delete') {
                            await onDelete();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'report', child: Text('Şikayet et')),
                          if (canDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Etkinliği sil', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: NovaNetworkImage(
                    imageUrl: event.imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 14),
                PlainCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${event.city} / ${event.district} • ${event.location}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 16),
                      PlainInfoBox(icon: Icons.timer_rounded, title: 'Kalan Süre', value: countdown),
                      const SizedBox(height: 10),
                      PlainInfoBox(icon: Icons.calendar_month_rounded, title: 'Tarih', value: dateText),
                      const SizedBox(height: 10),
                      PlainInfoBox(
                        icon: Icons.phone_rounded,
                        title: 'Telefon',
                        value: event.phone,
                        trailing: IconButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: event.phone));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Telefon numarası kopyalandı.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      CreatorBox(event: event),
                      const SizedBox(height: 16),
                      const Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Katılımcılar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.participantNames.values.map((user) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.045),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                            ),
                            child: Text(user, style: const TextStyle(fontWeight: FontWeight.w800)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: () async {
                          await onJoin();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: BlackButton(
                          title: joined ? 'Katılımdan Çık' : 'Etkinliğe Katıl',
                          icon: joined ? Icons.close_rounded : Icons.check_rounded,
                        ),
                      ),
                    ],
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

class EventCard extends StatelessWidget {
  final NovaEvent event;
  final String countdown;
  final String dateText;
  final bool joined;
  final bool canDelete;
  final AnimationController controller;
  final VoidCallback onTap;
  final Future<void> Function() onJoin;
  final Future<void> Function() onDelete;
  final Future<void> Function() onReport;

  const EventCard({
    super.key,
    required this.event,
    required this.countdown,
    required this.dateText,
    required this.joined,
    required this.canDelete,
    required this.controller,
    required this.onTap,
    required this.onJoin,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final completed = event.startAt.isBefore(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              child: NovaNetworkImage(
                imageUrl: event.imageUrl,
                width: 104,
                height: 142,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              height: 1.15,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.black, size: 21),
                          onSelected: (value) async {
                            if (value == 'report') await onReport();
                            if (value == 'delete') await onDelete();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'report', child: Text('Şikayet et')),
                            if (canDelete)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil', style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${event.city} / ${event.district}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 34,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.045),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(
                              completed ? 'Biten etkinlik' : countdown,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!completed)
                          GestureDetector(
                            onTap: onJoin,
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: joined ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: Colors.black, width: 1.3),
                              ),
                              child: Text(
                                joined ? 'Katıldın' : 'Katıl',
                                style: TextStyle(
                                  color: joined ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${event.participants.length} katılımcı • $dateText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NovaEvent {
  final String id;
  final String title;
  final String city;
  final String district;
  final String location;
  final String phone;
  final String description;
  final String imageUrl;
  final String creatorId;
  final String creatorName;
  final String creatorUsername;
  final String creatorPhotoUrl;
  final List<String> participants;
  final Map<String, String> participantNames;
  final DateTime startAt;
  final String status;

  NovaEvent({
    required this.id,
    required this.title,
    required this.city,
    required this.district,
    required this.location,
    required this.phone,
    required this.description,
    required this.imageUrl,
    required this.creatorId,
    required this.creatorName,
    required this.creatorUsername,
    required this.creatorPhotoUrl,
    required this.participants,
    required this.participantNames,
    required this.startAt,
    required this.status,
  });

  factory NovaEvent.fromFirestore(String id, Map<String, dynamic> data) {
    final rawStartAt = data['startAt'];
    final namesRaw = data['participantNames'];
    final Map<String, String> names = {};
    if (namesRaw is Map) {
      namesRaw.forEach((key, value) {
        names[key.toString()] = value.toString();
      });
    }

    final rawParticipants = data['participants'];

    return NovaEvent(
      id: id,
      title: (data['title'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      district: (data['district'] ?? '').toString(),
      location: (data['location'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      description: (data['description'] ?? data['desc'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? data['eventImageUrl'] ?? data['image'] ?? '').toString(),
      creatorId: (data['creatorId'] ?? '').toString(),
      creatorName: (data['creatorName'] ?? data['creator'] ?? 'Nova kullanıcısı').toString(),
      creatorUsername: (data['creatorUsername'] ?? '').toString(),
      creatorPhotoUrl: (data['creatorPhotoUrl'] ?? '').toString(),
      participants: rawParticipants is List
          ? rawParticipants.map((e) => e.toString()).toList()
          : <String>[],
      participantNames: names,
      startAt: rawStartAt is Timestamp
          ? rawStartAt.toDate()
          : DateTime.tryParse((data['dateText'] ?? '').toString()) ?? DateTime.now(),
      status: (data['status'] ?? 'active').toString(),
    );
  }
}

class NovaUserProfile {
  final String id;
  final String name;
  final String surname;
  final String username;
  final String city;
  final String district;
  final String photoUrl;

  NovaUserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.username,
    required this.city,
    required this.district,
    required this.photoUrl,
  });

  String get displayName {
    final full = '$name $surname'.trim();
    if (full.isNotEmpty) return full;
    if (username.isNotEmpty) return username;
    return 'Nova kullanıcısı';
  }

  factory NovaUserProfile.empty() {
    return NovaUserProfile(
      id: '',
      name: '',
      surname: '',
      username: '',
      city: '',
      district: '',
      photoUrl: '',
    );
  }

  factory NovaUserProfile.fromFirestore(String id, Map<String, dynamic> data) {
    return NovaUserProfile(
      id: id,
      name: (data['name'] ?? data['firstName'] ?? '').toString(),
      surname: (data['surname'] ?? data['lastName'] ?? '').toString(),
      username: (data['username'] ?? data['userName'] ?? '').toString(),
      city: (data['city'] ?? data['il'] ?? '').toString(),
      district: (data['district'] ?? data['ilce'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? data['profileImageUrl'] ?? data['avatarUrl'] ?? '').toString(),
    );
  }
}

class NovaWhiteBackground extends StatelessWidget {
  const NovaWhiteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.white);
  }
}

class NeonBorderCard extends StatelessWidget {
  final AnimationController controller;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const NeonBorderCard({
    super.key,
    required this.controller,
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF7C4DFF),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF7A00),
                Color(0xFFFF00B8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.18),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(radius - 1.8),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class NeonIconCircle extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final double size;
  final double iconSize;

  const NeonIconCircle({
    super.key,
    required this.controller,
    required this.icon,
    this.size = 38,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1.7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF7C4DFF),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF7A00),
                Color(0xFFFF00B8),
              ],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF00B8).withOpacity(0.20), blurRadius: 13, spreadRadius: 1),
              BoxShadow(color: const Color(0xFF00D9FF).withOpacity(0.16), blurRadius: 13, spreadRadius: 1),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        );
      },
    );
  }
}

class NeonAvatar extends StatelessWidget {
  final AnimationController controller;
  final String imageUrl;
  final IconData icon;
  final double size;

  const NeonAvatar({
    super.key,
    required this.controller,
    required this.imageUrl,
    required this.icon,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(controller.value * math.pi * 2),
              colors: const [
                Color(0xFFFF00B8),
                Color(0xFF7C4DFF),
                Color(0xFF00D9FF),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFFFF00B8),
              ],
            ),
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? NovaNetworkImage(imageUrl: imageUrl, width: size, height: size, fit: BoxFit.cover)
                : Container(
              color: Colors.black,
              child: Icon(icon, color: Colors.white, size: size * 0.45),
            ),
          ),
        );
      },
    );
  }
}

class NovaActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final AnimationController controller;
  final VoidCallback onTap;

  const NovaActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeonBorderCard(
      controller: controller,
      radius: 22,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeonIconCircle(controller: controller, icon: icon, size: 34, iconSize: 19),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'Roboto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const PlainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: const [],
      ),
      child: child,
    );
  }
}

class NovaCardTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const NovaCardTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 7, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Roboto')),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
            ],
          ),
        ),
      ],
    );
  }
}

class MiniEventStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const MiniEventStat({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return PlainCard(
      child: SizedBox(
        height: 82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.black),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }
}

class CreatorBox extends StatelessWidget {
  final NovaEvent event;

  const CreatorBox({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return PlainInfoBox(
      icon: Icons.person_rounded,
      title: 'Etkinliği Oluşturan',
      value: event.creatorUsername.isNotEmpty ? '${event.creatorName} • @${event.creatorUsername}' : event.creatorName,
    );
  }
}

class NovaNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const NovaNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    if (cleanUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.black.withOpacity(0.06),
        child: const Center(child: Icon(Icons.event_rounded, color: Colors.black45)),
      );
    }

    return Image.network(
      cleanUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.black.withOpacity(0.04),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.black.withOpacity(0.06),
        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.black45)),
      ),
    );
  }
}

class PlainInfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  const PlainInfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'Roboto')),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'Roboto')),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class BottomActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const BottomActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 7),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontFamily: 'Roboto'))),
          ],
        ),
      ),
    );
  }
}

class BlackButton extends StatelessWidget {
  final String title;
  final IconData icon;

  const BlackButton({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, fontFamily: 'Roboto')),
        ],
      ),
    );
  }
}

class NovaDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const NovaDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.07)),
        ),
        child: const Text('Seçenek yok', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Roboto')),
      );
    }

    final safeValue = items.contains(value) ? value : items.first;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Roboto')),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class NovaInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  const NovaInput({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.inputFormatters,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Roboto'),
      decoration: InputDecoration(
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
        filled: true,
        fillColor: Colors.black.withOpacity(0.035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.black.withOpacity(0.07))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.black, width: 1.4)),
      ),
    );
  }
}

class NovaBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const NovaBottomSheet({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: 1.0,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 14,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black12),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20))),
                const SizedBox(height: 18),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Roboto')),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SheetLabel extends StatelessWidget {
  final String text;

  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Roboto'),
    );
  }
}

class EmptyNovaBox extends StatelessWidget {
  final String text;

  const EmptyNovaBox({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontFamily: 'Roboto')),
    );
  }
}

class LoadingEventPanel extends StatelessWidget {
  const LoadingEventPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlainCard(
      child: Center(
        child: Text(
          'Etkinlik verileri yükleniyor...',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontFamily: 'Roboto'),
        ),
      ),
    );
  }
}
