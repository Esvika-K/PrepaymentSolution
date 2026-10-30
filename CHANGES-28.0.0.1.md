# Ettemaksude lahenduse parandused 28.0.0.1

1. Klient tuvastatakse esmalt täpse MT tellimuse arvelduskliendi järgi. Tellimuse number ja SystemId jäävad jaotuse aluseks ka ühise erakliendikonto korral. Kõik ühe makse viited peavad kuuluma samale arvelduskliendile ja olema samas valuutas. Teisele kliendile juba tehtud standardset sobitamist ei asendata tuvastamisel.
2. **Detect All Unmatched Payments** läbib kogu avatud väljavõtte positiivsed sidumata read, millel ei ole veel plaani. **Approve All Draft Allocations** kinnitab kogu sama väljavõtte mustandid. Üks vigane rida ei tühista teiste tulemusi. Iga rea tulemus ja veateade on eraldi loendis. Pangamakseid need tegevused ei konteeri.
3. Standardne **Remove Applications** puhastab valitud ridade konteerimata plaanid koos jaotusridadega. Kinnitatud plaani standardsete sobitamiste eemaldamist jälgitakse ka tabeli kustutussündmuses. **Remove Selected Allocations** eemaldab ka mustandid. Konteeritud plaane ei kustutata ja nende sobitamised eemaldatakse senise standardse Unapply ja plaani tühistamise töövooga.
4. Žurnaalis on **Allocation Documents**, **Allocation Status** ja **Allocated Cash**. Dokumentide väljalt avaneb plaan; jaotusridade dokumendinumbrilt vastav tellimus, konteeritud arve või kreeditarve.
5. Detailsete kliendikannete uued tabeliväljad on **ESV PP Plan ID**, **ESV PP Order No.**, **ESV PP Document References**. Uue makse algkandes on kõik viited; ühe tellimuse korral ka selle number. Iga hilisema rakenduskande tellimuse number vastab konkreetsele jaotusele. Mõlema sobitamispoole kanded saavad sama viite. Unapply uued kanded pärivad algse viite.

Varem konteeritud kannete uued tabeliväljad jäävad tühjaks. Nende olemasolevad jaotusplaanid ja ajalugu säilivad; ajaloolisi finantskandeid ei kirjutata selle uuendusega ümber.

## Kontroll ja paigaldus

- Põhirakendus ja 13 AL-testi kompileeritud BC 28.5 sümbolite ning CodeCopiga: 0 viga, 0 hoiatust. AL-teste ega kasutusvooge pole BC-s käivitatud.
- Nõutav baasäpp: Esvika basic 1.0.0.424 või uuem, milles on CalcReceivedAmount ja mõlemad varasemad integratsioonisündmused.
- Uuendus lisab välju ja ajutise tulemuste tabeli; kasuta tavapärast skeemi sünkroonimist. ForceSync ei ole nende muudatuste jaoks vajalik.
- Kontrolli kasutaja õigustekomplekti ESV PP PAYMENTS ning olemasolevaid standardseid panga- ja kliendikannete õigusi.
- Testkeskkonnas kontrollida enne kasutuselevõttu: kõikide ridade töötlemine koos vigase reaga; ühise erakliendi mitu tellimust; tühi ja ekslik kliendisoovitus; mitme rea Remove Applications; Reopen ja uuesti kinnitamine; üks makse mitmele tellimusele; osaarve; MA+KR; mõlema sobitamispoole detailsete kannete viited ning Unapply.
- BC-sse avaldamist ei ole tehtud. Launch.json-i sihtkeskkonda ei muudeta.
