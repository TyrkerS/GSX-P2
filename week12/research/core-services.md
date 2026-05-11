# Serveis core: DNS, DHCP, NTP

> **Estat:** Completat

Aquest document respon a la secció "Research: Core Services" del PDF (Setmana 12).
1-2 paràgrafs per servei, redactats per a algú no tècnic.

## DNS (Domain Name System)

El Sistema de Noms de Domini (DNS) és fonamentalment l'"agenda telefònica"
d'Internet i de les xarxes privades. El seu propòsit principal és traduir
noms llegibles per humans (com `google.com` o `backend-api.local`) a adreces
IP numèriques (com `192.168.1.50`) que les màquines utilitzen per comunicar-se.
A alt nivell, quan un client cerca un domini, la consulta passa per diversos
nivells jeràrquics: el resolver local, servidors arrel (root), servidors TLD
(.com, .net), i finalment el servidor autoritatiu que posseeix el registre
final (ja sigui un registre A per a IPv4, AAAA per a IPv6, CNAME per a
àlies, etc.).

Per a una organització, mantenir un DNS intern és crític. Permet als
diferents components i serveis localitzar-se entre ells usant noms lògics
i estables en lloc d'adreces IP que poden canviar de forma dinàmica o
impredictible. Això és especialment cert en entorns com Kubernetes, on els
Services proporcionen registres DNS interns de forma automàtica (p.ex.
`backend-dev.default.svc.cluster.local`), aïllant les consultes de la xarxa
pública per motius de seguretat i assegurant que les aplicacions continuïn
comunicant-se independentment d'on es reprogramin els contenidors.

## DHCP (Dynamic Host Configuration Protocol)

DHCP és el protocol encarregat d'assignar dinàmicament adreces IP i altres
paràmetres de configuració de xarxa (com la porta d'enllaç o els servidors
DNS) als dispositius que es connecten a una xarxa. Resol el problema
d'escalabilitat que suposa configurar la xarxa manualment en cada dispositiu.
Funciona mitjançant un intercanvi ràpid en quatre passos conegut com DORA
(Discover, Offer, Request, Acknowledge): el client emet un broadcast buscant
un servidor, el servidor li ofereix una IP disponible, el client la sol·licita
formalment i el servidor confirma la concessió.

En el context d'una organització, DHCP és imprescindible per gestionar xarxes
dinàmiques de manera eficient. Permet que portàtils que es connecten a la VPN,
equips convidats a les oficines o dispositius IoT obtinguin connectivitat
instantània i lliure de conflictes. Per a servidors o infraestructura crítica,
s'acostumen a usar "reserves DHCP" que asseguren que una mateixa adreça MAC
obtingui sempre la mateixa IP, combinant la facilitat d'una administració
centralitzada amb l'estabilitat d'una IP estàtica. Tot i que a Kubernetes
l'assignació d'IP als pods la gestiona el CNI, el protocol és vital per a
la provisió dels nodes físics o virtuals del clúster subjacent.

## NTP (Network Time Protocol)

NTP és un protocol dissenyat per sincronitzar els rellotges dels dispositius
a través d'una xarxa amb precisió de submil·lisegons. Funciona basant-se en
una arquitectura jeràrquica anomenada stratum: el Stratum 0 representa fonts
de temps d'altíssima precisió (rellotges atòmics o GPS), el Stratum 1 són
servidors connectats directament a aquestes fonts, i així fins arribar als
clients (Stratum N). En una organització, la millor pràctica és desplegar
2 o 3 servidors NTP interns que sincronitzin el seu temps contra fonts
públiques (com `pool.ntp.org`) i configurin tota la infraestructura i
dispositius locals perquè apuntin a aquests servidors interns, garantint
coherència en tota la xarxa.

La sincronització precisa del temps no és un mer detall operatiu; és
absolutament crítica per a la seguretat i el funcionament correcte dels
sistemes distribuïts. Si els rellotges difereixen, la correlació
d'esdeveniments en logs forenses esdevé impossible en investigar un incident
o auditar la plataforma. Encara més important, la validesa dels certificats
TLS i dels tokens d'autenticació (com JWT o tickets de Kerberos) depèn de
finestres de temps estrictes. Una dessincronització de tan sols un parell de
minuts pot causar el rebuig generalitzat de credencials vàlides o la ruptura
de les comunicacions segures del sistema.
