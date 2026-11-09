class_name Tables
extends RefCounted
## Static game data: companies, commodities, crypto, unit types, techs, blocs.

# country ISO: Name,Sector,Price; ...
const COMPANIES := """
USA: Apple,Tech,190; Microsoft,Tech,410; Alphabet,Tech,165; Amazon,Retail,185; Nvidia,Semis,880; Meta,Media,480; Tesla,Autos,175; Berkshire Hathaway,Insurance,410; JPMorgan Chase,Banks,195; Visa,Banks,275; Mastercard,Banks,460; Bank of America,Banks,38; Wells Fargo,Banks,58; Goldman Sachs,Banks,420; Morgan Stanley,Banks,95; Citigroup,Banks,62; ExxonMobil,Energy,115; Chevron,Energy,160; ConocoPhillips,Energy,120; Lockheed Martin,Defense,460; RTX,Defense,95; Northrop Grumman,Defense,470; General Dynamics,Defense,290; Boeing,Aerospace,190; GE Aerospace,Aerospace,150; Walmart,Retail,60; Costco,Retail,730; Home Depot,Retail,350; Coca-Cola,Food,60; PepsiCo,Food,170; McDonald's,Food,290; Procter & Gamble,Food,160; Nike,Luxury,100; Disney,Media,110; Netflix,Media,620; Intel,Semis,32; AMD,Semis,160; Qualcomm,Semis,170; Micron,Semis,110; Oracle,Tech,125; Salesforce,Tech,270; IBM,Tech,185; Cisco,Tech,49; Johnson & Johnson,Pharma,155; Pfizer,Pharma,28; Eli Lilly,Pharma,760; Merck,Pharma,125; AbbVie,Pharma,170; UnitedHealth,Insurance,490; Ford,Autos,12; General Motors,Autos,42; Caterpillar,Industrial,330; Deere,Industrial,390; Freeport-McMoRan,Mining,48; Newmont,Mining,40; Verizon,Telecom,41; AT&T,Telecom,17; T-Mobile,Telecom,165; UPS,Shipping,145; FedEx,Shipping,270; Delta Air Lines,Aviation,48; United Airlines,Aviation,52; American Airlines,Aviation,14; Uber,Tech,70; PayPal,Banks,62; 3M,Industrial,95; Honeywell,Industrial,200; Starbucks,Food,95; NextEra Energy,Utilities,70; Duke Energy,Utilities,98; Archer-Daniels-Midland,Agri,55; Corteva,Agri,55; Nucor,Steel,165; Dow,Chemicals,55
CHN: Alibaba,Retail,75; Tencent,Tech,300; BYD,Autos,250; CATL,Electronics,190; ICBC,Banks,5; China Construction Bank,Banks,6; Bank of China,Banks,4; Agricultural Bank of China,Banks,4; PetroChina,Energy,8; Sinopec,Energy,5; CNOOC,Energy,22; China Mobile,Telecom,75; China Telecom,Telecom,5; Huawei,Tech,130; Xiaomi,Electronics,18; Lenovo,Electronics,12; Baidu,Tech,100; JD.com,Retail,28; Meituan,Tech,110; NetEase,Media,95; Kweichow Moutai,Food,1700; Ping An,Insurance,45; China Life,Insurance,12; COSCO Shipping,Shipping,12; Geely,Autos,15; SAIC Motor,Autos,18; Great Wall Motor,Autos,24; NIO,Autos,6; Li Auto,Autos,28; XPeng,Autos,10; China State Construction,Construction,5; Baosteel,Steel,7; Aluminum Corp of China,Mining,7; Zijin Mining,Mining,18; China Shenhua,Mining,38; Air China,Aviation,6; China Southern Airlines,Aviation,5; China Eastern,Aviation,3; AVIC,Defense,40; NORINCO,Defense,35; SMIC,Semis,28; DJI,Tech,150; Haier,Electronics,28; Midea,Electronics,60; Sinopharm,Pharma,22; COMAC,Aerospace,80; Cathay Pacific,Aviation,9; AIA Group,Insurance,60; Sun Hung Kai Properties,RealEstate,80; CK Hutchison,Industrial,40; HKEX,Banks,260; Mengniu Dairy,Food,15; Wuliangye,Food,150; BOE Technology,Electronics,4; Longi Green Energy,Utilities,20; China Yangtze Power,Utilities,24; COSCO Ports,Shipping,12
JPN: Toyota,Autos,32; Honda,Autos,24; Nissan,Autos,4; Suzuki,Autos,13; Mazda,Autos,11; Subaru,Autos,18; Denso,Autos,18; Bridgestone,Autos,40; Sony,Electronics,90; Panasonic,Electronics,10; Toshiba,Electronics,25; Hitachi,Industrial,100; Nintendo,Media,55; SoftBank,Telecom,38; NTT,Telecom,1; KDDI,Telecom,28; Mitsubishi UFJ,Banks,12; Sumitomo Mitsui,Banks,60; Mizuho,Banks,22; Mitsubishi Heavy,Defense,55; Kawasaki Heavy,Defense,35; Fanuc,Industrial,28; Komatsu,Industrial,30; Canon,Electronics,34; Fujifilm,Electronics,24; Shin-Etsu,Chemicals,45; Tokyo Electron,Semis,250; Japan Airlines,Aviation,19; ANA,Aviation,22; Nippon Steel,Steel,26; Takeda,Pharma,28; Fast Retailing,Retail,270; Seven & i,Retail,16; NYK Line,Shipping,30; Mitsui OSK,Shipping,32; Mitsubishi Corp,Industrial,22; Tokio Marine,Insurance,35; Toyota Industries,Industrial,90; Yamaha,Luxury,10; Sumitomo Metal Mining,Mining,28; Inpex,Energy,17; Kirin,Food,15; Daiwa House,Construction,32; Recruit,Tech,45
DEU: BMW,Autos,95; Mercedes-Benz,Autos,82; Volkswagen,Autos,120; Porsche,Autos,95; Audi,Autos,500; Daimler Truck,Autos,38; Continental,Autos,65; Siemens,Industrial,180; SAP,Tech,185; Allianz,Insurance,270; Munich Re,Insurance,430; Deutsche Bank,Banks,16; Commerzbank,Banks,15; BASF,Chemicals,48; Bayer,Pharma,30; Adidas,Luxury,200; Puma,Luxury,45; Lufthansa,Aviation,7; Deutsche Telekom,Telecom,23; DHL Group,Shipping,43; E.ON,Utilities,12; RWE,Utilities,35; Rheinmetall,Defense,520; ThyssenKrupp,Steel,4; Infineon,Semis,36; Henkel,Food,75; Zalando,Retail,22; Hapag-Lloyd,Shipping,140; Merck KGaA,Pharma,150; Siemens Energy,Energy,25; Airbus Helicopters,Aerospace,60; Heidelberg Materials,Construction,95; Hensoldt,Defense,40; MAN Truck,Autos,48; Linde,Chemicals,430
KOR: Samsung Electronics,Electronics,75; SK Hynix,Semis,140; Hyundai Motor,Autos,230; Kia,Autos,100; LG Electronics,Electronics,85; LG Energy Solution,Electronics,300; POSCO,Steel,380; Naver,Tech,190; Kakao,Tech,42; Hanwha Aerospace,Defense,230; Korean Air,Aviation,24; HMM,Shipping,17; HD Hyundai Heavy,Shipping,120; Samsung Biologics,Pharma,780; KB Financial,Banks,55; Shinhan Financial,Banks,38; SK Telecom,Telecom,43; Celltrion,Pharma,150; Lotte,Retail,60; Coupang,Retail,22; Hyundai Rotem,Defense,50; Korea Electric Power,Utilities,19
IND: Reliance Industries,Energy,2900; Tata Motors,Autos,1000; Tata Steel,Steel,160; TCS,Tech,3900; Infosys,Tech,1500; Wipro,Tech,480; HDFC Bank,Banks,1500; ICICI Bank,Banks,1100; State Bank of India,Banks,780; Bharti Airtel,Telecom,1200; Adani Ports,Shipping,1300; Adani Enterprises,Mining,3000; Mahindra,Autos,2200; Maruti Suzuki,Autos,12000; ITC,Food,430; Hindustan Unilever,Food,2400; Larsen & Toubro,Construction,3500; ONGC,Energy,270; Coal India,Mining,430; Sun Pharma,Pharma,1500; Hindustan Aeronautics,Defense,4000; Bajaj Auto,Autos,9000; IndiGo,Aviation,3200; Zomato,Tech,180; Vedanta,Mining,300; Bharat Electronics,Defense,230; NTPC,Utilities,350; Power Grid,Utilities,280; Asian Paints,Chemicals,2900
GBR: Shell,Energy,32; BP,Energy,6; HSBC,Banks,8; Barclays,Banks,2; Lloyds,Banks,0.5; Unilever,Food,40; Diageo,Food,29; AstraZeneca,Pharma,120; GSK,Pharma,17; Rio Tinto,Mining,55; BAE Systems,Defense,14; Rolls-Royce,Aerospace,5; Vodafone,Telecom,0.7; BT Group,Telecom,1.4; Tesco,Retail,3; Burberry,Luxury,12; IAG,Aviation,2; Jaguar Land Rover,Autos,60; Aston Martin,Autos,2; Anglo American,Mining,24; Glencore,Mining,5; National Grid,Utilities,11; Aviva,Insurance,5; Standard Chartered,Banks,8; Reckitt,Food,45; ARM Holdings,Semis,130; London Stock Exchange,Banks,100; Compass Group,Food,27; Smiths Group,Industrial,18
FRA: LVMH,Luxury,800; Hermes,Luxury,2200; L'Oreal,Luxury,430; Kering,Luxury,350; TotalEnergies,Energy,65; Airbus,Aerospace,150; Renault,Autos,40; Sanofi,Pharma,95; BNP Paribas,Banks,65; Societe Generale,Banks,25; Credit Agricole,Banks,13; AXA,Insurance,33; Danone,Food,58; Orange,Telecom,11; Air France-KLM,Aviation,10; Dassault Aviation,Defense,190; Thales,Defense,145; Safran,Aerospace,210; Schneider Electric,Industrial,190; Vinci,Construction,115; Engie,Utilities,16; EDF,Utilities,12; Carrefour,Retail,16; Pernod Ricard,Food,150; Michelin,Autos,34; Capgemini,Tech,190; Dassault Systemes,Tech,40; CMA CGM,Shipping,100; Saint-Gobain,Construction,75; Bouygues,Construction,35; Ubisoft,Media,17; Naval Group,Defense,60; Air Liquide,Chemicals,175; Alstom,Industrial,17
ITA: Ferrari,Autos,400; Enel,Utilities,6.5; Eni,Energy,15; Intesa Sanpaolo,Banks,3.5; UniCredit,Banks,35; Generali,Insurance,25; Leonardo,Defense,22; Pirelli,Autos,5.5; Prada,Luxury,6; Luxottica,Luxury,190; Telecom Italia,Telecom,0.3; Fincantieri,Shipping,6; Campari,Food,9; Barilla,Food,70; Moncler,Luxury,60; Brembo,Autos,10; Ferrero,Food,120; ITA Airways,Aviation,12; Snam,Energy,4.5; Maserati,Autos,90; Lamborghini,Autos,600
ESP: Inditex,Retail,45; Santander,Banks,4.5; BBVA,Banks,9; Iberdrola,Utilities,12; Telefonica,Telecom,4; Repsol,Energy,15; Iberia,Aviation,4; Ferrovial,Construction,38; Amadeus,Tech,62; CaixaBank,Banks,5; SEAT,Autos,35; Mapfre,Insurance,2.3; Acciona,Construction,115; Naturgy,Utilities,24; Indra,Defense,22
NLD: ASML,Semis,950; Philips,Electronics,22; ING,Banks,16; Heineken,Food,90; Stellantis,Autos,23; Adyen,Banks,1400; Prosus,Tech,35; Ahold Delhaize,Retail,28; NN Group,Insurance,42; Akzo Nobel,Chemicals,65; Airbus NL,Aerospace,150; Fugro,Energy,18; Royal Vopak,Energy,40; Damen Shipyards,Shipping,50
CHE: Nestle,Food,95; Novartis,Pharma,100; Roche,Pharma,250; UBS,Banks,28; ABB,Industrial,45; Zurich Insurance,Insurance,470; Swiss Re,Insurance,110; Richemont,Luxury,140; Swatch,Luxury,230; Rolex,Luxury,12000; Holcim,Construction,75; Lonza,Pharma,500; Swiss International Air Lines,Aviation,16; Givaudan,Chemicals,4200; Logitech,Electronics,85; Sika,Construction,260; Julius Baer,Banks,55
SWE: Volvo,Autos,26; Ericsson,Telecom,6; Ingka (IKEA),Retail,60; H&M,Retail,14; Spotify,Media,300; Atlas Copco,Industrial,16; SEB,Banks,14; Saab,Defense,30; Electrolux,Electronics,12; Sandvik,Industrial,22; Scania,Autos,45; Swedbank,Banks,22; Boliden,Mining,32; SKF,Industrial,20; Vattenfall,Utilities,20
NOR: Equinor,Energy,27; DNB,Banks,20; Norsk Hydro,Mining,6; Telenor,Telecom,12; Yara,Chemicals,32; Mowi,Food,18; Kongsberg,Defense,95; Aker BP,Energy,27; Orkla,Food,9; Hurtigruten,Shipping,12
DNK: Novo Nordisk,Pharma,125; Maersk,Shipping,1500; Carlsberg,Food,800; Vestas,Industrial,28; LEGO,Retail,400; Danske Bank,Banks,22; Orsted,Utilities,50; DSV,Shipping,160; Pandora,Luxury,150
FIN: Nokia,Telecom,3.5; Neste,Energy,28; UPM,Industrial,32; Kone,Industrial,50; Fortum,Utilities,13; Finnair,Aviation,0.3; Wartsila,Industrial,14
POL: PKN Orlen,Energy,16; PKO Bank,Banks,14; CD Projekt,Media,28; KGHM,Mining,32; LPP,Retail,4000; PZU,Insurance,12; Allegro,Retail,7; LOT Polish Airlines,Aviation,10; PGE,Utilities,2
RUS: Gazprom,Energy,2.1; Rosneft,Energy,6; Lukoil,Energy,6500; Sberbank,Banks,2.7; VTB,Banks,0.02; Norilsk Nickel,Mining,12; Rostec,Defense,40; Aeroflot,Aviation,0.6; Yandex,Tech,35; Novatek,Energy,1200; Severstal,Steel,15; MTS,Telecom,4; Rusal,Mining,0.5; Sovcomflot,Shipping,1; Magnit,Retail,45; Tatneft,Energy,6; Surgutneftegas,Energy,0.5; AvtoVAZ,Autos,1.2; Kalashnikov,Defense,30; Rosatom,Energy,60; Polyus,Mining,110; Alrosa,Mining,0.7; Uralkali,Chemicals,20; Transneft,Energy,1600
UKR: Naftogaz,Energy,15; Kernel,Agri,6; MHP,Food,7; Metinvest,Steel,10; PrivatBank,Banks,5; Antonov,Aerospace,12; Ukrnafta,Energy,3; Motor Sich,Aerospace,20; Ukrtelecom,Telecom,2; Ukrainian Railways,Shipping,8
TUR: Turkish Airlines,Aviation,8; Koc Holding,Industrial,6; Garanti BBVA,Banks,3; Is Bankasi,Banks,1; Aselsan,Defense,2; Turkcell,Telecom,2; Tupras,Energy,4; BIM,Retail,6; Ford Otosan,Autos,12; TOGG,Autos,20; Baykar,Defense,45; Arcelik,Electronics,3; Pegasus,Aviation,3; Akbank,Banks,2; Sabanci,Industrial,2; Eregli Steel,Steel,0.7; Anadolu Efes,Food,2; Turkish Shipyards,Shipping,9
EGY: Commercial International Bank,Banks,70; National Bank of Egypt,Banks,40; Banque Misr,Banks,35; Telecom Egypt,Telecom,30; EgyptAir,Aviation,15; Eastern Company,Food,25; Talaat Moustafa Group,RealEstate,12; Orascom Construction,Construction,18; Elsewedy Electric,Industrial,16; Egyptian Petrochemicals,Chemicals,8; Suez Canal Company,Shipping,60; Egypt Aluminium,Mining,12; Ezz Steel,Steel,8; Juhayna,Food,5; Fawry,Tech,6; MOPCO Fertilizers,Chemicals,25; Edita,Food,18; Egyptian General Petroleum,Energy,45; Egyptian Electricity Holding,Utilities,12; Arab Contractors,Construction,6; Palm Hills,RealEstate,5; Raya Holding,Tech,7; Cleopatra Hospital,Pharma,9; EVA Pharma,Pharma,20; Egypt Military Production,Defense,14; Nile Cotton Co.,Agri,4
SAU: Saudi Aramco,Energy,9; SABIC,Chemicals,22; Al Rajhi Bank,Banks,25; STC,Telecom,13; Saudia,Aviation,12; Maaden,Mining,12; Saudi National Bank,Banks,14; ACWA Power,Utilities,110; Almarai,Food,16; Riyad Bank,Banks,9; Bahri,Shipping,10; Savola,Food,12; Jarir,Retail,14; Mobily,Telecom,13; Red Sea Global,RealEstate,18; Dar Al-Arkan,RealEstate,5; SAMI Defense,Defense,22
ARE: Emirates,Aviation,30; ADNOC,Energy,4; Emaar,RealEstate,8; First Abu Dhabi Bank,Banks,13; e&,Telecom,18; DP World,Shipping,25; Etihad,Aviation,12; EDGE Group,Defense,20; Emirates NBD,Banks,6; Masdar,Utilities,15; Majid Al Futtaim,Retail,30; Aldar,RealEstate,6; Noon,Retail,10; Careem,Tech,8
QAT: QatarEnergy,Energy,50; Qatar Airways,Aviation,20; Qatar National Bank,Banks,4; Ooredoo,Telecom,3.5; Industries Qatar,Chemicals,12
KWT: Kuwait Petroleum,Energy,25; National Bank of Kuwait,Banks,1; Zain,Telecom,0.5; Kuwait Airways,Aviation,6
ISR: Elbit Systems,Defense,230; Teva,Pharma,12; Check Point,Tech,160; Bank Leumi,Banks,9; El Al,Aviation,2; Wix,Tech,150; Nice,Tech,200; Israel Aerospace Industries,Defense,45; ICL Group,Chemicals,6; Mobileye,Autos,30
IRN: NIOC,Energy,10; Iran Khodro,Autos,3; Saipa,Autos,2; MCI Telecom,Telecom,3; Bank Mellat,Banks,2; Iran Air,Aviation,5; Mobarakeh Steel,Steel,4; Persian Gulf Petrochemical,Chemicals,5
PAK: Pakistan State Oil,Energy,4; HBL,Banks,3; Engro,Chemicals,5; Lucky Cement,Construction,6; PIA,Aviation,1; PTCL,Telecom,1; Fauji Fertilizer,Chemicals,5
BGD: Grameenphone,Telecom,8; BRAC Bank,Banks,2; Square Pharma,Pharma,4; Beximco,Industrial,3; Biman Bangladesh,Aviation,1
IDN: Bank Central Asia,Banks,22; Telkom Indonesia,Telecom,8; Pertamina,Energy,10; Astra International,Autos,5; Garuda,Aviation,0.5; Adaro,Mining,3; GoTo,Tech,1; Indofood,Food,3; Bank Mandiri,Banks,9; Freeport Indonesia,Mining,30
THA: PTT,Energy,3; CP Group,Food,2; Siam Cement,Construction,8; Thai Airways,Aviation,1; AIS,Telecom,6; Bangkok Bank,Banks,4; Thai Union,Food,2; Central Group,Retail,15
VNM: VinFast,Autos,8; Vietcombank,Banks,3; Vietnam Airlines,Aviation,2; Viettel,Telecom,8; PetroVietnam,Energy,6; Vinamilk,Food,2; FPT,Tech,5; Hoa Phat,Steel,1; Masan,Food,2
MYS: Petronas,Energy,12; Maybank,Banks,2; Malaysia Airlines,Aviation,3; AirAsia,Aviation,0.5; Proton,Autos,5; Genting,Media,1; Sime Darby,Agri,1; Axiata,Telecom,1; Top Glove,Pharma,0.4
SGP: DBS,Banks,35; Singapore Airlines,Aviation,6; Singtel,Telecom,2.5; Sea Limited,Tech,70; Grab,Tech,3; Keppel,Industrial,7; PSA International,Shipping,40; OCBC,Banks,12; Wilmar,Agri,3; CapitaLand,RealEstate,2.5
PHL: SM Investments,Retail,15; Ayala,RealEstate,10; PLDT,Telecom,25; Jollibee,Food,4; BDO,Banks,2; Philippine Airlines,Aviation,3; San Miguel,Food,4
AUS: BHP,Mining,45; Fortescue,Mining,20; Commonwealth Bank,Banks,115; Westpac,Banks,25; ANZ,Banks,27; Woodside,Energy,28; Santos,Energy,7; Qantas,Aviation,8; Telstra,Telecom,4; Woolworths,Retail,29; CSL,Pharma,270; Macquarie,Banks,190; Atlassian,Tech,200; Wesfarmers,Retail,65; Origin Energy,Energy,9; Brambles,Shipping,15; Treasury Wine,Food,12; Cochlear,Pharma,290; Pilbara Minerals,Mining,5; Lynas Rare Earths,Mining,8
NZL: Fisher & Paykel Healthcare,Pharma,22; Air New Zealand,Aviation,0.5; Fonterra,Food,5; Spark NZ,Telecom,3; Xero,Tech,115; Fletcher Building,Construction,3
CAN: Royal Bank of Canada,Banks,125; TD Bank,Banks,80; Shopify,Tech,85; Enbridge,Energy,50; Suncor,Energy,50; Canadian Natural Resources,Energy,55; Barrick Gold,Mining,17; Nutrien,Agri,55; Canadian Pacific,Shipping,95; CN Rail,Shipping,150; Air Canada,Aviation,16; BCE,Telecom,34; Rogers,Telecom,48; Bombardier,Aerospace,60; Magna International,Autos,50; Manulife,Insurance,28; Brookfield,RealEstate,45; Teck Resources,Mining,60; Lululemon,Luxury,380; Restaurant Brands,Food,90; Loblaw,Retail,140; Cameco,Mining,48; Bank of Montreal,Banks,100; Scotiabank,Banks,70; Wheaton Precious Metals,Mining,60
MEX: America Movil,Telecom,18; FEMSA,Food,95; Grupo Mexico,Mining,6; Cemex,Construction,7; Bimbo,Food,60; Walmex,Retail,3; Pemex,Energy,5; Banorte,Banks,9; Aeromexico,Aviation,14; Televisa,Media,1; Alfa,Industrial,0.8
BRA: Petrobras,Energy,15; Vale,Mining,13; Itau Unibanco,Banks,6; Bradesco,Banks,2; Embraer,Aerospace,24; JBS,Food,5; Ambev,Food,2.5; Banco do Brasil,Banks,6; Gerdau,Steel,4; Suzano,Industrial,11; WEG,Industrial,7; Magazine Luiza,Retail,1; Eletrobras,Utilities,8; Natura,Luxury,4; Marfrig,Food,2; BRF,Food,3; Raizen,Energy,1; Nubank,Banks,12; Localiza,Autos,10
ARG: YPF,Energy,35; Mercado Libre,Tech,1700; Grupo Galicia,Banks,40; Aerolineas Argentinas,Aviation,6; Pampa Energia,Utilities,45; Arcor,Food,6; Tenaris,Steel,17; Telecom Argentina,Telecom,3; Ledesma,Agri,2
CHL: Codelco,Mining,30; SQM,Mining,55; LATAM Airlines,Aviation,16; Falabella,Retail,3; Banco de Chile,Banks,0.1; Cencosud,Retail,2; Copec,Energy,6; Enel Chile,Utilities,0.1
COL: Ecopetrol,Energy,0.5; Bancolombia,Banks,10; Avianca,Aviation,2; Grupo Exito,Retail,1; ISA,Utilities,5
PER: Southern Copper,Mining,95; Credicorp,Banks,160; Buenaventura,Mining,15; Alicorp,Food,2
VEN: PDVSA,Energy,3; Banesco,Banks,2; CANTV,Telecom,1
ZAF: Naspers,Tech,190; Sasol,Chemicals,9; Standard Bank,Banks,12; Anglo American Platinum,Mining,35; Gold Fields,Mining,16; Sibanye Stillwater,Mining,2; MTN Group,Telecom,6; Vodacom,Telecom,6; Shoprite,Retail,15; FirstRand,Banks,4; South African Airways,Aviation,3; Impala Platinum,Mining,5; Eskom,Utilities,2; Absa,Banks,11; Discovery,Insurance,9; Sanlam,Insurance,4; Woolworths SA,Retail,3; Pick n Pay,Retail,2
NGA: Dangote Cement,Construction,25; MTN Nigeria,Telecom,12; Zenith Bank,Banks,1; GTBank,Banks,1; NNPC,Energy,8; Nigerian Breweries,Food,2; Seplat Energy,Energy,2; Airtel Africa,Telecom,1.5; Access Bank,Banks,0.5; Flutterwave,Banks,5; Dangote Refinery,Energy,10; Air Peace,Aviation,1
KEN: Safaricom,Telecom,0.2; Equity Bank,Banks,0.4; Kenya Airways,Aviation,0.03; KenGen,Utilities,0.05; East African Breweries,Food,0.1; KCB,Banks,0.3
ETH: Ethiopian Airlines,Aviation,25; Ethio Telecom,Telecom,6; Commercial Bank of Ethiopia,Banks,3
MAR: Maroc Telecom,Telecom,12; OCP Group,Chemicals,35; Attijariwafa Bank,Banks,10; Royal Air Maroc,Aviation,6; Marjane,Retail,4; Managem,Mining,9
DZA: Sonatrach,Energy,28; Air Algerie,Aviation,3; Algerie Telecom,Telecom,2; Cevital,Food,4
LBY: National Oil Corporation Libya,Energy,20; Libyan Airlines,Aviation,2
IRQ: SOMO,Energy,15; Zain Iraq,Telecom,1; Trade Bank of Iraq,Banks,1
JOR: Arab Bank,Banks,6; Royal Jordanian,Aviation,1; Jordan Phosphate,Mining,12; Zain Jordan,Telecom,2
LBN: Bank Audi,Banks,1; Middle East Airlines,Aviation,3
GHA: Ghana Commercial Bank,Banks,2; MTN Ghana,Telecom,0.5; Cocoa Board,Agri,6; AngloGold Ashanti,Mining,24
COD: Gecamines,Mining,18; Vodacom Congo,Telecom,2; Rawbank,Banks,4
ZMB: ZCCM,Mining,6; First Quantum Minerals,Mining,12
TZA: Vodacom Tanzania,Telecom,0.3; NMB Bank,Banks,1; Air Tanzania,Aviation,1
AGO: Sonangol,Energy,12; TAAG,Aviation,3; Banco BAI,Banks,2
KAZ: KazMunayGas,Energy,18; Kaspi,Banks,100; Air Astana,Aviation,2; Kazatomprom,Mining,40; Halyk Bank,Banks,3; Kazakhmys,Mining,12
UZB: Uzbekneftegaz,Energy,5; Uzbekistan Airways,Aviation,2; Navoi Mining,Mining,10
AZE: SOCAR,Energy,14; AZAL,Aviation,3; Kapital Bank,Banks,2
GEO: Bank of Georgia,Banks,45; Georgian Airways,Aviation,1; Silknet,Telecom,1
BLR: Belaruskali,Chemicals,25; Belavia,Aviation,1; MAZ,Autos,4; BelAZ,Industrial,8
CZE: Skoda Auto,Autos,50; CEZ,Utilities,38; Komercni Banka,Banks,28; Czech Airlines,Aviation,2
HUN: MOL,Energy,8; OTP Bank,Banks,40; Richter Gedeon,Pharma,26; Magyar Telekom,Telecom,2; Wizz Air,Aviation,20
ROU: OMV Petrom,Energy,0.5; Banca Transilvania,Banks,6; Dacia,Autos,18; Hidroelectrica,Utilities,10; TAROM,Aviation,1
GRC: Hellenic Petroleum,Energy,8; National Bank of Greece,Banks,9; Aegean Airlines,Aviation,10; OTE,Telecom,14; Eurobank,Banks,2; Piraeus Port,Shipping,25; Coca-Cola HBC,Food,34; Mytilineos,Industrial,35
PRT: EDP,Utilities,4; Galp,Energy,15; Jeronimo Martins,Retail,22; TAP Air Portugal,Aviation,8; Millennium bcp,Banks,0.3
BEL: AB InBev,Food,60; KBC,Banks,70; Solvay,Chemicals,28; UCB,Pharma,150; Umicore,Industrial,20; Proximus,Telecom,8; Ageas,Insurance,45
AUT: OMV,Energy,45; Erste Group,Banks,45; Verbund,Utilities,75; Voestalpine,Steel,25; Red Bull,Food,150; Austrian Airlines,Aviation,10; Raiffeisen,Banks,17
IRL: Ryanair,Aviation,20; CRH,Construction,75; Kerry Group,Food,88; AIB,Banks,5; Flutter,Media,190; Accenture,Tech,330; Bank of Ireland,Banks,10; Smurfit Kappa,Industrial,40
TWN: TSMC,Semis,150; Foxconn,Electronics,4; MediaTek,Semis,38; Asus,Electronics,12; Acer,Electronics,1.2; HTC,Electronics,1.5; Evergreen Marine,Shipping,5; EVA Air,Aviation,1; China Airlines,Aviation,0.8; Cathay Financial,Banks,1.5; Formosa Plastics,Chemicals,2.5; Chunghwa Telecom,Telecom,3.5; UMC,Semis,1.8; Quanta Computer,Electronics,8; Largan Precision,Electronics,80
LUX: ArcelorMittal,Steel,28; SES,Telecom,5; Aperam,Steel,28
ISL: Icelandair,Aviation,0.1; Marel,Industrial,4
CUB: Cubana,Aviation,1; Havana Club,Food,5
SRB: NIS Serbia,Energy,2; Air Serbia,Aviation,2; Telekom Srbija,Telecom,1
BGR: Bulgargaz,Energy,2; Bulgarian Telecom,Telecom,1; First Investment Bank,Banks,1
SVK: Slovnaft,Energy,3; Slovak Telecom,Telecom,2; Volkswagen Slovakia,Autos,40
HRV: INA,Energy,4; Zagrebacka Bank,Banks,3; Croatia Airlines,Aviation,1
LKA: John Keells,Industrial,0.5; SriLankan Airlines,Aviation,0.3; Dialog,Telecom,0.1
NPL: Nepal Telecom,Telecom,1; Himalayan Bank,Banks,0.5
MMR: Myanma Oil & Gas,Energy,2; Myanmar Airways,Aviation,1
KHM: Angkor Beer,Food,1; Cambodia Airways,Aviation,0.5
LAO: Lao Telecom,Telecom,0.5; EDL Laos,Utilities,1
MNG: Erdenes Mongol,Mining,5; MIAT Mongolian Airlines,Aviation,0.6
PRK: Korea Mining Development,Mining,1; Air Koryo,Aviation,0.4
AFG: Afghan Telecom,Telecom,1; Ariana Afghan Airlines,Aviation,0.3
UGA: Uganda Telecom,Telecom,0.3; Stanbic Uganda,Banks,0.5
SEN: Sonatel,Telecom,5; Senelec,Utilities,1
CIV: Orange CI,Telecom,3; Societe Ivoirienne de Raffinage,Energy,3; Cocoa Cote d'Ivoire,Agri,7
CMR: Camair-Co,Aviation,0.4; SABC Cameroon,Food,2
MOZ: Mozal Aluminium,Mining,5; Vodacom Mozambique,Telecom,1
NAM: Namdeb Diamonds,Mining,12; Air Namibia,Aviation,0.5
BWA: Debswana,Mining,25; Air Botswana,Aviation,0.5
"""

# id: [name, base price, volatility, unit]
const COMM := {
	"oil": ["Oil (Brent barrel)", 87.42, 0.012],
	"gas": ["Natural Gas", 3.1, 0.018],
	"coal": ["Coal (ton)", 135.0, 0.010],
	"gold": ["Gold (ounce)", 2184.9, 0.006],
	"silver": ["Silver (ounce)", 24.5, 0.011],
	"copper": ["Copper (ton)", 8950.0, 0.009],
	"iron": ["Iron ore (ton)", 118.0, 0.008],
	"lithium": ["Lithium (ton)", 14500.0, 0.014],
	"uranium": ["Uranium (lb)", 85.0, 0.010],
	"wheat": ["Wheat (ton)", 312.6, 0.010],
	"corn": ["Corn (ton)", 190.0, 0.009],
	"rice": ["Rice (ton)", 520.0, 0.007],
	"sugar": ["Sugar (ton)", 560.0, 0.010],
	"coffee": ["Coffee (ton)", 4200.0, 0.013],
	"cotton": ["Cotton (ton)", 1700.0, 0.009],
}
# producers: share of world supply (normalised at runtime)
const PRODUCERS := {
	"oil": {"USA": 15, "SAU": 12, "RUS": 12, "CAN": 5, "IRQ": 5, "ARE": 4, "IRN": 4, "CHN": 4, "BRA": 4, "KWT": 3, "NOR": 3, "NGA": 2, "LBY": 2, "DZA": 2, "KAZ": 2, "MEX": 2, "VEN": 1},
	"gas": {"USA": 24, "RUS": 17, "IRN": 6, "CHN": 5, "CAN": 4, "QAT": 4, "NOR": 3, "SAU": 3, "DZA": 2, "AUS": 3, "EGY": 2, "TKM": 2},
	"coal": {"CHN": 50, "IND": 10, "IDN": 8, "USA": 6, "AUS": 6, "RUS": 5, "ZAF": 3, "KAZ": 1, "COL": 1, "POL": 1},
	"gold": {"CHN": 10, "RUS": 9, "AUS": 9, "CAN": 6, "USA": 6, "GHA": 4, "ZAF": 3, "MEX": 3, "PER": 3, "UZB": 3, "IDN": 3, "SDN": 2, "EGY": 1},
	"silver": {"MEX": 23, "CHN": 13, "PER": 12, "RUS": 6, "CHL": 5, "POL": 5, "AUS": 5, "BOL": 4, "USA": 4},
	"copper": {"CHL": 24, "PER": 10, "COD": 10, "CHN": 8, "USA": 6, "AUS": 4, "ZMB": 4, "RUS": 4, "MEX": 3, "KAZ": 3},
	"iron": {"AUS": 38, "BRA": 17, "CHN": 14, "IND": 10, "RUS": 4, "ZAF": 3, "CAN": 3, "UKR": 3, "SWE": 1},
	"lithium": {"AUS": 47, "CHL": 24, "CHN": 15, "ARG": 5, "BRA": 2, "ZWE": 2, "PRT": 1},
	"uranium": {"KAZ": 43, "CAN": 15, "NAM": 11, "AUS": 9, "UZB": 7, "RUS": 5, "NER": 4, "CHN": 3},
	"wheat": {"CHN": 17, "IND": 14, "RUS": 11, "USA": 7, "FRA": 5, "CAN": 4, "UKR": 4, "PAK": 4, "AUS": 3, "DEU": 3, "TUR": 2, "ARG": 2, "KAZ": 2, "EGY": 1},
	"corn": {"USA": 32, "CHN": 22, "BRA": 9, "ARG": 5, "UKR": 3, "IND": 3, "MEX": 3, "FRA": 2, "ZAF": 2},
	"rice": {"IND": 28, "CHN": 28, "BGD": 7, "IDN": 7, "VNM": 6, "THA": 4, "MMR": 3, "PHL": 3, "PAK": 2, "EGY": 1},
	"sugar": {"BRA": 22, "IND": 18, "CHN": 6, "THA": 6, "PAK": 4, "USA": 4, "MEX": 3, "AUS": 2, "EGY": 2},
	"coffee": {"BRA": 37, "VNM": 17, "COL": 8, "IDN": 7, "ETH": 5, "HND": 3, "UGA": 3, "PER": 3},
	"cotton": {"CHN": 24, "IND": 22, "USA": 14, "BRA": 10, "PAK": 5, "AUS": 3, "UZB": 3, "TUR": 3, "EGY": 1},
}
# sector -> commodity sensitivities (positive = benefits from high price)
const SECTOR_SENS := {
	"Energy": {"oil": 1.0, "gas": 0.4}, "Mining": {"iron": 0.6, "copper": 0.5, "gold": 0.4, "lithium": 0.3, "uranium": 0.2},
	"Agri": {"wheat": 0.8, "corn": 0.4, "sugar": 0.2, "cotton": 0.2}, "Food": {"wheat": -0.3, "sugar": -0.2, "coffee": -0.1},
	"Autos": {"iron": -0.4, "oil": -0.3, "lithium": -0.15}, "Aviation": {"oil": -0.7}, "Shipping": {"oil": -0.4},
	"Aerospace": {"oil": -0.2}, "Utilities": {"gas": -0.2, "coal": -0.1}, "Steel": {"iron": -0.3, "coal": -0.3},
	"Chemicals": {"oil": 0.1, "gas": -0.2}, "Construction": {"iron": -0.2, "coal": -0.1},
	"Electronics": {"copper": -0.2, "lithium": -0.2}, "Semis": {"copper": -0.1},
}
# id, name, price, volatility, beta to market sentiment
const CRYPTO := [
	["BTC", "Bitcoin", 67500.0, 0.030, 1.0], ["ETH", "Ethereum", 3450.0, 0.036, 1.2], ["USDT", "Tether", 1.0, 0.0008, 0.0],
	["BNB", "BNB", 590.0, 0.034, 1.0], ["SOL", "Solana", 165.0, 0.048, 1.5], ["XRP", "XRP", 0.52, 0.040, 1.0],
	["ADA", "Cardano", 0.45, 0.045, 1.3], ["DOGE", "Dogecoin", 0.16, 0.060, 1.6], ["LTC", "Litecoin", 85.0, 0.038, 1.0],
	["DOT", "Polkadot", 7.2, 0.046, 1.3], ["AVAX", "Avalanche", 36.0, 0.050, 1.5], ["TON", "Toncoin", 6.5, 0.048, 1.2],
	["LINK", "Chainlink", 15.0, 0.046, 1.3], ["TRX", "Tron", 0.12, 0.036, 0.9],
]
# type: name, atk, def, speed(deg/day), cost, default size(k), is_land
const UTYPES := {
	"inf": {"name": "Infantry", "atk": 1.0, "def": 1.2, "spd": 0.8, "cost": 1.0, "sz": 20.0, "land": true},
	"mech": {"name": "Mechanized", "atk": 1.4, "def": 1.2, "spd": 1.3, "cost": 2.0, "sz": 18.0, "land": true},
	"arm": {"name": "Armor", "atk": 1.8, "def": 1.0, "spd": 1.5, "cost": 2.8, "sz": 14.0, "land": true},
	"art": {"name": "Artillery", "atk": 1.7, "def": 0.6, "spd": 0.7, "cost": 1.8, "sz": 10.0, "land": true},
	"sf": {"name": "Special Forces", "atk": 1.6, "def": 1.1, "spd": 1.6, "cost": 3.2, "sz": 5.0, "land": true},
	"air": {"name": "Air Wing", "atk": 0.0, "def": 0.0, "spd": 6.0, "cost": 3.0, "sz": 8.0, "land": false},
	"navy": {"name": "Fleet", "atk": 0.0, "def": 0.0, "spd": 3.0, "cost": 3.5, "sz": 6.0, "land": false},
	"msl": {"name": "Missile Battery", "atk": 0.0, "def": 0.0, "spd": 0.5, "cost": 4.0, "sz": 3.0, "land": false},
}
const TECHS := {
	"inf": "Infantry Weapons", "arm": "Armor & Mechanized", "air": "Air Power", "navy": "Naval Power", "msl": "Missiles & Defense",
}
const TACTICS := {
	"flank": {"name": "Flank Maneuver", "cd": 5, "dur": 2, "sup": 4, "desc": "+35% attack for 2 days (needs 2+ armies or armor)"},
	"entrench": {"name": "Entrench", "cd": 4, "dur": 3, "sup": 0, "desc": "+35% defense, -30% attack for 3 days"},
	"barrage": {"name": "Artillery Barrage", "cd": 3, "dur": 1, "sup": 6, "desc": "+40% damage today (needs artillery)"},
	"airsup": {"name": "Air Support", "cd": 4, "dur": 2, "sup": 3, "desc": "+30% power for 2 days (needs air wing nearby)"},
	"blitz": {"name": "Blitz", "cd": 6, "dur": 2, "sup": 6, "desc": "+50% attack, -5 morale (armor/mech)"},
}
const NATO := ["USA", "CAN", "GBR", "FRA", "DEU", "ITA", "ESP", "PRT", "NLD", "BEL", "LUX", "DNK", "NOR", "ISL", "POL", "CZE", "SVK", "HUN",
	"ROU", "BGR", "GRC", "TUR", "HRV", "SVN", "EST", "LVA", "LTU", "ALB", "MNE", "MKD", "FIN", "SWE"]
const NUKES := ["USA", "RUS", "CHN", "GBR", "FRA", "IND", "PAK", "PRK", "ISR"]
const MONARCHIES := ["SAU", "JOR", "MAR", "ARE", "QAT", "KWT", "BHR", "OMN", "BRN", "SWZ", "LSO", "LIE", "MCO", "THA", "MYS", "KHM", "TON"]
const CONST_MON := ["GBR", "JPN", "ESP", "NLD", "BEL", "SWE", "NOR", "DNK", "CAN", "AUS", "NZL", "LUX"]
const ONE_PARTY := ["CHN", "VNM", "LAO", "CUB", "PRK", "ERI"]
const TROOPS := {
	"USA": 1390, "CHN": 2035, "IND": 1450, "RUS": 1150, "PRK": 1280, "KOR": 500, "PAK": 650, "IRN": 610, "EGY": 440, "TUR": 355,
	"UKR": 250, "VNM": 480, "BRA": 360, "THA": 360, "ISR": 170, "SAU": 250, "MEX": 260, "IDN": 400, "FRA": 205, "GBR": 150, "DEU": 180,
	"ITA": 165, "JPN": 250, "ESP": 120, "POL": 200, "MMR": 400, "BGD": 160, "COL": 290, "NGA": 215, "ETH": 160, "SYR": 170, "IRQ": 200,
	"DZA": 140, "MAR": 195, "AFG": 150, "SDN": 200, "TWN": 170, "GRC": 140, "ARG": 80, "CAN": 70, "AUS": 60, "ZAF": 75, "SGP": 50,
}
const RIVALS := [["RUS", "UKR", -90], ["USA", "RUS", -45], ["USA", "CHN", -25], ["IND", "PAK", -55], ["SAU", "IRN", -60], ["CHN", "JPN", -30],
	["RUS", "GBR", -40], ["IND", "CHN", -30], ["EGY", "ETH", -25], ["RUS", "DEU", -25], ["USA", "IRN", -50], ["ISR", "IRN", -80], ["KOR", "PRK", -80],
	["JPN", "PRK", -60], ["CHN", "TWN", -50], ["TUR", "GRC", -30], ["ARM", "AZE", -60], ["ETH", "ERI", -30], ["USA", "PRK", -70], ["RUS", "POL", -35],
	["IND", "CHN", -30], ["MAR", "DZA", -35], ["SOM", "ETH", -20], ["GRC", "CYN", -30], ["SRB", "KOS", -60], ["RWA", "COD", -40], ["VEN", "GUY", -35]]
const ALLIANCES := [["USA", "JPN"], ["USA", "KOR"], ["USA", "AUS"], ["USA", "PHL"], ["USA", "ISR"], ["RUS", "BLR"], ["RUS", "IRN"], ["CHN", "PRK"],
	["CHN", "PAK"], ["EGY", "SAU"], ["EGY", "ARE"], ["SAU", "ARE"], ["FRA", "MAR"], ["GBR", "AUS"], ["GBR", "NZL"], ["AUS", "NZL"], ["TUR", "AZE"],
	["IND", "BTN"], ["RUS", "ARM"], ["RUS", "KAZ"], ["SAU", "BHR"], ["ARE", "BHR"], ["KWT", "SAU"]]
