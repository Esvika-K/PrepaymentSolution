# PrepaymentSolution

MT/MA/KR viidetega pangalaekumiste jaotamine müügitellimuste, müügiarvete ja müügikreeditarvete vahel.

## Valmiskood ja kontrolli piirid

- Uus äpp: **PrepaymentSolution 28.0.0.1**, kasutaja loodud app.json ID-ga f1054153-02ca-41c9-845c-f7695969c5ee.
- Nõuab **Esvika basic 1.0.0.424** või uuemat, milles on allpool kirjeldatud integratsioonisündmused.
- Siht: BC Application 28.5, runtime 17.0, objektid 60100–60109; eraldi testirakenduses 60140.
- Põhirakendus kompileeritud Microsoft Base Application 28.5.54151.56408 sümbolitega ning CodeCopiga: 0 viga ja 0 hoiatust.
- Kaasasolev baasäpi lisandus kompileeritud General projekti kohalike 28.5 sümbolitega; alles jäid 10 olemasoleva koodi hoiatust väljaspool muudetud loogikat.
- Eraldi testirakendus sisaldab 13 AL-testi. Testid kompileeritakse, kuid neid pole BC testijooksutajas käivitatud.
- Tegelikku pangalaekumise, müügiarve ja kreeditarve konteerimist pole BC-s käivitatud. Enne kasutuselevõttu läbida allolev kontroll testkeskkonnas.
- Midagi ei avaldata selle paketi loomisega BC-sse automaatselt.

## Käitumine

1. Klient leitakse esmalt täpselt viidatud MT müügitellimuse Bill-to Customer No. järgi. Eelnev kliendi valimine pangareal ei ole nõutud. Ühise erakliendikonto korral kaitseb tellimuse täpne number ja SystemId teiste tellimuste makseosi. MA/KR viited peavad tuvastama sama arvelduskliendi; ainult MA/KR korral nõutakse üheselt tuvastatavat avatud dokumenti. Olemasolevat standardset sobitamist teisele kliendile ei kirjutata tuvastamisel üle.
2. Makse tekstist, täiendavast infost ja makseviitest leitakse kõik täielikud MT-, MA- ja KR-numbrid. Näiteks `MT1001, MT1002; MA2001/KR3001`. Suur- ja väiketähed ühtlustatakse, korduvad viited eemaldatakse. Numbris võivad olla sidekriipsud, alakriipsud ja kaldkriipsud. Prefiksi ja numbri vahel olevat tühikut ei käsitleta ühe dokumendinumbrina.
3. Kõik dokumendid peavad kuuluma samale arvelduskliendile ning olema pangakontoga samas valuutas. Kliendi nime või sarnast numbrit ei kasutata asendusvastena.
4. MT suunab makse selle konkreetse tellimuse veel arveldamata osale, arvestades teisi kinnitatud reserveeringuid ja vanu sama tellimuse avatud laekumisi.
5. MA suunab makse konkreetsele avatud arvekandele. KR suunab kreeditarve ainult selle makse viidetes olevale valitud arvele.
6. Ühe võimaliku arve korral pakutakse kreeditarve siht automaatselt; mitme korral tuleb see määrata. Kreeditarve olemasolevat Applies-to viidet arvestatakse võimaliku sihi kitsendamisel.
7. Kui makse ei kata kõiki viidatud summasid, tuleb jaotusridade summad käsitsi parandada. Kinnitamine ei määra ise suvalist tasumise järjekorda.
8. Pärast kinnitamist asendatakse selle pangarea standardsed sobitusettepanekud laekumisega kliendi kontole. Tegelik dokumendipõhine sobitamine toimub konteerimisel.
9. Panga konteerimisel tehakse kõigepealt KR → MA sobitamised ning seejärel makse → MA sobitamised. MT jaoks eraldatud summa jääb reserveerituks kuni tellimusest arve tekkimiseni.
10. Tellimuse arve konteerimisel kasutatakse kõiki selle tellimuse ja kliendiga seotud kasutamata makseosi. Osaarve korral säilib ülejäänud osa järgmisele arvele.
11. Üks pangarida tekitab ühe standardse kliendi laekumiskande ja standardse pangakande; makse ei dubleerita iga tellimuse kohta. Jaotus salvestatakse eraldi tabelisse.
12. Korduskäivitus ei kasuta juba rakendatud jaotusosa uuesti. Väliselt eemaldatud sobitamised või puuduolev reserveeritud raha peatavad töötlemise selge veaga.

## Kasutamine

1. Ava imporditud maksete sobitamise žurnaal. Klient leitakse täpse tellimuse- või dokumendiviite järgi.
2. Käivita **Detect All Unmatched Payments**, mis töötleb kogu avatud väljavõtte sidumata positiivsed read. Soovi korral jääb alles ka valitud ridade **Detect MT/MA/KR References**.
3. Ava **Payment Allocation**. Vaata summad üle; vajadusel muuda osamaksete summasid ja **Credit Target Invoice No.** väärtust.
4. Vajadusel kasuta **Recalculate Suggested Amounts**. See asendab kõik mustandi summad värskete soovitustega, seega sisesta osamaksete käsitsi jaotus pärast ümberarvutamist.
5. Pärast ülevaatust vali **Approve All Draft Allocations**, et kinnitada kõik selle väljavõtte mustandid. Üksik- ja valitud ridade kinnitamine jääb samuti alles. Vigased mustandid jäävad kinnitamata ja kuvatakse tulemuste loendis.
6. Konteeri žurnaal tavapärase BC tegevusega. Ebaselge või muutunud lähteinfoga plaan peatab konteerimise.
7. Vaata tellimusel **Allocated Bank Receipts**, olemasolevat **Recived Amount** välja ning **Payment Allocation Plans** / **Application History** vaateid.
8. Enne panga konteerimist saab kinnitatud plaani tegevusega **Reopen** uuesti mustandiks avada. Muutunud pangaandmete korral tuvasta viited uuesti.

Ülemakse kajastub väljal **Unallocated Cash** ja jääb kliendi avatud laekumiseks. Kui samast laekumisest osa on veel tellimustele reserveeritud, ei luba lahendus kasutada seda laekumist standardse eraldi sobitamise kaudu. See kaitseb tellimuste reserveeringuid; vaba ülejääki saab mujal sobitada pärast reserveeringute kasutamist või plaani tühistamist.

## Tühistamine ja parandamine

- Rakendus ei muuda kliendikande Amount ega Remaining Amount välju otse; finantssobitamised tehakse standardsete koodimoodulitega.
- Konteeritud jaotusridu ei saa tavavaates muuta ega kustutada.
- Kui jaotus tuleb tühistada, eemalda selle plaani tehtud sobitamised esmalt BC standardse **Unapply Entries** tegevusega, alustades viimasest sobitamisest.
- Seejärel vali plaanil **Cancel Posted Allocation**. Kõik selle plaani logitud sobitamised peavad olema eelnevalt eemaldatud. Kui plaan veel ühtegi arvet ei sobitanud, saab reserveeringu kohe tühistada.
- Tühistamine vabastab reserveeringud ja säilitab ajaloo. See ei tagasta raha, ei pööra pangakannet ümber ega eemalda dokumendiviiteid.
- Vajalik tagasimakse või laekumise ümberpööramine tehakse pärast seda BC standardse protsessiga. Uueks jaotamiseks tuleb kasutada eraldi kontrollitud parandust, mitte muuta logi või Applied Amount väärtusi käsitsi.

## Baasäpi vajalik lisandus

Fail **EsvikaBasicIntegration.patch** sisaldab ainult järgmiste failide muudatusi:

- app.json: baasäpi versioon 1.0.0.424.
- CodeUnits/Cod50101.SalesEvents.al: avalik CalcReceivedAmount meetod ja OnAfterCalcReceivedAmount sündmus; olemasolevad vastavad arvutused kasutavad seda meetodit.
- CodeUnits/Cod50106.PurchaseEvents.al ning Page Ext/Req-Pag-Ext50125.ReqWorksheetExt.al: planeerimine arvestab sama laiendatavat laekumise arvutust.
- CodeUnits/Cod50111.Summaryinvoiceandemail.al: esimese massarvelduse valik arvestab ka uue äpi laekumisi; üksnes vana FlowFieldi SQL-filter ei oleks piisav.
- Page/Pag50122.Payment.al: poe makseleht kasutab kogu laekunud summat nii maksmata jäägi kui ka Paid näidu jaoks.
- Page/Pag50134.CustLedgerEntryPayment.al: uus OnAfterSetOrderPaymentFilters sündmus võimaldab näidata ka jaotusplaanide kaudu seotud laekumisi.
- Page Ext/SO-Pag-Ext50108.SalesOrderExt.al ja Page Ext/SO-Pag-Ext50131.SalesOrdersExt.al: tellimuse ja loendi kuvad kasutavad sama arvutust.

Baasäpp ei sõltu uuest äpist. Uus äpp kuulab baasäpi sündmusi. Kui uus äpp pole paigaldatud, arvutab baasäpp laekumisi endise andmeallika järgi.

Uute plaanide laekumistele ei täideta vana Sales Order No. välja: mitme tellimuse korral pole üks väärtus õige ning vana FindFirst loogika võiks kogu ühise makse ühele tellimusele rakendada. Seost hoitakse uutes jaotusridades. Vanad kaardi- ja sularahalaekumised jätkavad vana ahelat pidi.

Tellimuse laekumiste vaatest võib avaneda terve ühise pangalaekumise kanne; konkreetsele tellimusele eraldatud osa näeb tellimuse Allocated Bank Receipts drilldown-vaates.

## Ehitamine ja paigaldamise järjekord

1. Rakenda kaasasolev baasäpi patch või võrdle paketis olevaid muudetud baasfaile olemasoleva General projektiga. Ära asenda kogu oma General projekti vana koopiaga.
2. Kompileeri **Esvika basic 1.0.0.424** oma täieliku General projekti sümbolitega.
3. Lisa selle .app uue PrepaymentSolution projekti .alpackages kausta või laadi sümbolid pärast baasäpi paigaldamist testkeskkonnast uuesti.
4. Kompileeri PrepaymentSolution käsuga **AL: Package**. app.json-i muud sõltuvused ja identiteet on säilitatud; Esvika basic minimaalne versioon on 1.0.0.424.
5. Paigalda testkeskkonda esmalt uus baasäpp, seejärel PrepaymentSolution. Uus äpp sisaldab uusi tabeleid; ForceSync pole selle esmapaigalduse jaoks vajalik.
6. Määra kasutajale **ESV PP PAYMENTS** ja olemasolevad standardsed kliendi-/panga-/müügikonteerimise õigused. Uus õigustekomplekt üksi ei anna standardsete finantstegevuste õigusi.
7. Testirakendus on eraldi; seda ei ole vaja tootmiskeskkonda paigaldada.

## Valikuline tööjärjekord

Codeunit **60104 ESV PP Background** võib käivituda Job Queue kaudu. See otsib juba konteeritud plaanidest kasutamata tellimuse makseosi ja proovib neid sobitada pärast plaani kinnitamist loodud tellimuse arvetega. Tavapärane sobitamine toimub juba panga või müügiarve konteerimise sündmuses; tööjärjekord on täiendav kordustöötlus.

Tööjärjekord ei tuvasta ega kinnita uusi pangaridu ega konteeri pangamakseid kasutaja eest. Vea korral jääb nähtav Job Queue vealogi. Lahendus ei loo tööjärjekorra kirjet ise.

## Teadlikud piirid

- Ühel pangareal üks arveldusklient ja sama valuuta. Eri klientide ühismakse ja valuutade vaheline sobitamine vajavad eraldi jaotamisprotsessi.
- Olemasoleva standardse ettemaksuarvega tellimuse jaoks tuleb kasutada MA viidet ettemaksuarvele; MT jaotus ei asenda standardset ettemaksuarvestust.
- Täpsed maksejaotused ei kata automaatselt maksesoodustusi ja tolerantsi mahakandmisi. Kui standard soovib muuta jääki jaotusest suuremas ulatuses, peatatakse tegevus ning kogu selle tegevuse sobitamine tühistatakse tehingu tagasipööramisega.
- MT viitab olemasoleva tellimuse veel arveldamata osale. Kui tellimus on juba täielikult arveldatud või kustutatud, kasuta avatud arve MA numbrit. Enne plaani kinnitamist loodud arveid ei kaeta tagantjärele MT jaoks eraldatud summaga.
- Mitme arvega jaotuses ei otsustata osalise makse suvalist eelisjärjekorda; summajaotus tuleb üle vaadata.
- Vana Recived Amount jääb tehniliselt vana CalcFormula-ga FlowFieldiks. Baasäpi uuendatud meetod ja vaated liidavad uued summad juurde. Välised API-d või muud laiendused, mis loevad ainult toorest FlowFieldi, vajavad sama meetodi kasutamist või uut jaotusandmete liidest.
- Baasäpi olemasolevaid blokeeringu erandeid ei ole ümber kujundatud. Täieliku laekumise korral rakenduvad senised reeglid; All blokeeringu ärireegel tuleb eraldi kinnitada.
- Importimise duplikaadikontroll kasutab panga Transaction ID olemasolul seda koos pangakontoga. Puuduva Transaction ID korral jäävad kordusimpordi kontrollid standardse impordiprotsessi kanda.

## Kontrollstsenaariumid testkeskkonnas

| Juht | Oodatav tulemus |
|---|---|
| MT1001: 1000 €, makse 300 € | Kasutaja määrab MT jaotuseks 300 €. Arve tekkimisel sobitatakse 300 €, arve jääk 700 €. |
| MT1001: kaks makset 200 € + 300 € | Mõlemad kinnitatud ja konteeritud makseosad kasutatakse; 1000 € arve jääk 500 €. |
| Üks makse kahele tellimusele 400 € + 600 € | Üks laekumiskanne, eraldi 400/600 reserveeringud; kumbki tellimus saab ainult enda osa. |
| MA2001: 1000 €, KR3001: 200 €, makse 800 € | Kreedit rakendatakse enne makset. Kõigi kolme kande sobitamise jäägid on null. |
| Kaks MA ja üks KR | KR siht peab olema üheselt määratud; mitme võimaliku sihi korral kinnitamist ei tehta. |
| MA + MT ja makse väiksem kogusummast | Kinnitamine nõuab sobivat käsitsi summajaotust; raha ei jaotata juhuslikult. |
| Erakliendi vale tellimus / vale Bill-to klient | Tuvastus või kinnitamine katkeb; teise kliendi dokumenti ei sobitata. |
| Sama kliendi kaks tellimust | Ühe tellimuse makseosa ei kasutata teise tellimuse arve jaoks. |
| Osaarve 200 € ja järgmine arve 800 €, eraldatud 500 € | Esimesele rakendatakse 200 €, teisele 300 €. |
| Koondarve mitmest tellimusest | Iga tellimuse makseosa on piiratud selle tellimuse arveridade summaga; kontrolli ka ümardusridu. |
| Ülemakse | Eraldamata ülejääk säilib kliendikandel; reserveeritud osa on kaitstud kõrvalise sobitamise eest. |
| Tööjärjekorra korduskäivitus | Sama jaotust ega sobitamist ei dubleerita. |
| Panga teksti / kliendi / summa muutmine pärast kinnitamist | Konteerimine peatub ja nõuab plaani uuesti tuvastamist. |
| Käsitsi eemaldatud sobitamine | Logi tervikluse kontroll peatab uue automaatse kasutamise; tühista või paranda plaan kontrollitult. |
| Osaliselt reserveeritud makse manuaalne sobitamine / Apply to Oldest | Muule dokumendile reserveeritud summat ei tarbita. |
| Müügiarve või pangakande eelvaade | Eelvaade ei jäta püsivaid jaotus- ega sobitamiskandeid. |
| Vale valuuta / standardne ettemaksuarve / soodustuse mahakandmine | Katkestus selge veaga, mitte vaikimisi sobitamine. |
| Poe makseleht pärast pangalaekumist | Recived Amount, Paid ja täiendavalt küsitav makse arvestavad uut pangajaotust. |
| Samaaegne kahe plaani kinnitamine samale dokumendile | Sama vaba summat ei reserveerita mõlemale; kontrolli ka lukustuse/taaskatse käitumist. |

Finantstestides kontrollida lisaks arve kuvatavale jäägile Customer Ledger Entries ja Detailed Customer Ledger Entries sobitamisi, panga kannete arvu ning rakenduse Application History andmeid.

## 28.0.0.1 muudatuste kontroll

- Žurnaalis on Allocation Documents, Allocation Status ja Allocated Cash; dokumentide väljal avaneb jaotusplaan ning jaotuse dokumendinumbrilt tellimus/arve/kreeditarve.
- Standardne Remove Applications eemaldab valitud ridade konteerimata plaanid ja jaotusread. Remove Selected Allocations teeb sama otse, ka mustandile. Reopen säilitab mustandi read ja eemaldab standardse kinnitatud sobitamise.
- Detailsetes kliendikannetes on päris tabeliväljad ESV PP Plan ID, ESV PP Order No. ja ESV PP Document References. Uute konteerimiste algkandele salvestatakse kõik viited, ühe tellimuse korral ka üks tellimuse number. Iga hilisema rakenduskande tellimuse number vastab selle konkreetsele jaotusele. Mitme tellimuse laekumisele ei omistata suvalist ühte tellimust.
- Varem konteeritud kannete uued väljad jäävad tühjaks; see versioon ei kirjuta vanu finantskandeid tagantjärele ümber. Nende jaotusi saab vaadata olemasolevalt Payment Allocation Planilt ja Application Historyst.
- Iga mass-tuvastuse/kinnitamise rida on eraldi tehing Boolean Codeunit.Run kaudu. Ühe rea viga pöörab tagasi ainult selle rea; edukad read säilivad. Masskinnitamine ei konteeri pangamakseid.
- Kontrolli BC-s: tühi kliendinumber, ühise erakliendi kaks tellimust, üks makse mitmele tellimusele, eri kliendid samas selgituses, vigane rida kahe korrektse vahel, standardne Remove Applications mitme valitud rea puhul, Reopen ja uuesti kinnitamine, alg- ja rakenduskannete viited mõlemal sobitamise poolel ning Unapply viidete säilimine.
- 13 AL-testi ja põhirakenduse kompileerimine ei asenda BC-s neid kasutus- ja konteerimisteste; teste pole BC-s käivitatud.
