# Gestió d'Identitat

> **Estat:** Completat

Aquest document respon a la secció "Research: Identity Management" i
"Identity strategy for GreenDevCorp" del PDF (Setmana 12).

## 1. Autenticació vs Autorització

L'**Autenticació (Authentication o Authn)** s'encarrega de verificar "qui
ets". És el procés mitjançant el qual el sistema valida la identitat de
l'usuari a través d'alguna cosa que sap (contrasenya), alguna cosa que té
(token, SMS) o alguna cosa que és (biometria). Si el procés d'autenticació
falla, l'usuari no pot accedir al sistema sota cap circumstància.

D'altra banda, l'**Autorització (Authorization o Authz)** determina "què
pots fer". Un cop l'usuari ha estat autenticat amb èxit, el sistema
d'autorització decideix a quins recursos o accions específiques té accés,
normalment basant-se en rols (RBAC) o polítiques d'accés. Per exemple,
iniciar sessió a GitHub amb un nom d'usuari i contrasenya és autenticació;
però que GitHub et permeti veure un repositori privat però no et permeti fer
*push* a la branca principal d'un altre projecte, és autorització.

## 2. Identitat Centralitzada

### LDAP (Lightweight Directory Access Protocol)

LDAP és un protocol estàndard utilitzat per consultar i modificar serveis de
directori jeràrquics. Funciona com una base de dades optimitzada per a
lectures ràpides que emmagatzema informació sobre usuaris, grups, dispositius
i polítiques de l'organització. Els seus casos d'ús més comuns inclouen la
validació centralitzada de credencials (per no tenir usuaris locals a cada
servidor), llistar membres de grups per a control d'accés, o cercar
informació corporativa com el correu o el departament d'un empleat. Les
implementacions més esteses són OpenLDAP (open-source) i 389 Directory Server.

### Active Directory (AD)

Active Directory és la implementació privativa de Microsoft per a serveis de
directori, i de facto l'estàndard en entorns empresarials fortament basats en
Windows. Combina LDAP per a l'accés al directori, Kerberos per a
l'autenticació segura, i DNS per a la resolució de serveis. El seu major
avantatge competitiu, a més de la integració nativa amb Windows, és l'ús dels
Group Policy Objects (GPOs), que permeten als administradors gestionar de
forma centralitzada la configuració i seguretat de milers d'equips des d'un
sol punt.

### SSO (Single Sign-On)

Single Sign-On (SSO) és una solució que permet a un usuari autenticar-se una
única vegada i accedir a múltiples aplicacions de forma transparent sense
haver de tornar a introduir les seves credencials. Generalment utilitza
protocols moderns com SAML o OIDC (construït sobre OAuth2). Els seus
beneficis són dobles: per a l'usuari, elimina la fatiga de contrasenyes i
millora l'experiència; per a l'organització, centralitza el control d'accés,
redueix riscos de filtracions (menys contrasenyes febles) i fa que el procés
d'*offboarding* sigui instantani, ja que revocar l'accés al proveïdor
d'identitat bloqueja automàticament l'entrada a tots els sistemes dependents.

## 3. Recomanació per a GreenDevCorp

Donat el context de GreenDevCorp (startup en creixement amb més de 20
empleats, equips tècnics i d'operacions, dues oficines internacionals,
múltiples entorns i col·laboradors externs), l'estratègia d'identitat ha de
prioritzar la seguretat, la centralització i la reducció de sobrecàrrega
operativa.

**Estratègia Recomanada:**
Recomanem adoptar un **Proveïdor d'Identitat (IdP) gestionat al núvol** (com
Google Workspace, Microsoft Entra ID o Okta) en lloc de desplegar i mantenir
solucions *on-premise* com OpenLDAP o Active Directory. Sobre aquest IdP,
s'ha d'implementar **Single Sign-On (SSO)** usant OIDC/SAML per integrar
totes les eines internes i externes (GitHub, AWS/GCP, dashboards de
Kubernetes, Grafana, eines de CI/CD). A més, el control d'accés
(Autorització) ha de basar-se en un model de **Control d'Accés Basat en
Rols (RBAC)**, agrupant els usuaris en grups lògics segons la seva funció
(p.ex. `dev-team`, `ops-team`, `partners`) i assignant permisos a nivell de
grup, mai a nivell d'usuari individual.

**Trade-offs i Justificació:**
- **Cost i Manteniment:** Malgrat que un IdP al núvol té un cost recurrent
  per usuari (OpEx), elimina l'enorme càrrega operativa i la despesa en
  infraestructura (CapEx) de mantenir servidors LDAP distribuïts globalment
  per donar servei a dues oficines, aplicar pedaços de seguretat i gestionar
  còpies de seguretat d'identitats crítiques.
- **Disponibilitat:** Si el sistema d'identitat cau, ningú pot treballar.
  Un IdP comercial garanteix SLAs del 99,9% i escalabilitat global, quelcom
  molt difícil d'aconseguir amb un equip d'operacions petit que encara està
  automatitzant la seva infraestructura base.
- **Vendor Lock-in vs Seguretat:** Tot i que es genera una dependència del
  proveïdor, s'obté accés a característiques avançades de seguretat natives
  i imprescindibles per al teletreball i la connexió entre oficines, com
  l'Autenticació Multifactor (MFA), l'anàlisi de risc d'inici de sessió i
  la gestió d'accés condicional, les quals serien molt complexes de construir
  internament.

**Pràctiques a Evitar:**
Queda estrictament descartat l'ús de comptes locals independents a cada
servidor o aplicació, ja que fa inviable un *offboarding* segur i ràpid quan
algú abandona l'empresa. De la mateixa forma, està prohibit l'ús de
credencials compartides (p.ex. un compte genèric `admin` per a tot l'equip
d'operacions); cada acció ha de ser atribuïble a una identitat individual
mitjançant auditoria.

**Evolució Futura (Roadmap):**
A curt termini (1-3 mesos), l'objectiu és migrar els repositoris de codi i
les aplicacions crítiques d'infraestructura (Kubernetes, monitoratge) darrere
del SSO de l'IdP, aplicant MFA obligatori. A mig termini (6 mesos), es
connectarà la VPN (si és que no es transiciona a un model Zero Trust Network
Access complet) perquè les dues oficines autentiquin el tràfic de xarxa
mitjançant el mateix proveïdor. Finalment, a llarg termini, es pot automatitzar
el cicle de vida complet de l'usuari connectant l'IdP amb els sistemes de RRHH.
