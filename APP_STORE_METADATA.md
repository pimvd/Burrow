# App Store Metadata Draft

This file is a working draft for App Store Connect metadata and should be reviewed
before submission. Structure follows Dicedeck's `APP_STORE_METADATA.md`.

Character limits (App Store Connect): name 30, subtitle 30, promotional text 170,
description 4000, keywords 100. Every name/subtitle/keyword field below has been
length-checked.

## Identity

- App name: `Burrow`
- Bundle ID: `com.pvd.burrow`
- iCloud container: `iCloud.com.pvd.burrow`
- Primary language: English (U.S.)
- Localizations: English, German (de-DE), Spanish (es-ES), French (fr-FR), Dutch (nl-NL) — matches the in-app languages
- Current version: `1.0` (`MARKETING_VERSION`). The build number is not set by hand; it is stamped from the git commit count by the *Set Build Number From Git* build phase — never edit `CURRENT_PROJECT_VERSION`
- Minimum OS: iOS 17.0
- Category candidate: Education (secondary: Entertainment) — **see the Kids Category note under Review Information**
- Availability: worldwide
- Price: free, with a 14-day in-app free trial and one non-consumable in-app purchase
  **Burrow Full** (`com.pvd.burrow.pro`, €9.99). The trial is the app's own, not a
  StoreKit introductory offer, which non-consumables do not support
- Privacy policy URL: `https://vandijkcloud.nl/burrow/privacy.html` (source: `website/privacy.html` — republish after edits)
- Marketing URL: _TODO (optional)_
- Support email: `pim@vandijkcloud.nl` (also in the privacy policy)
- Support URL: `https://vandijkcloud.nl/burrow/support.html` (source: `website/support.html`)

---

## What's New — version 1.0

First release, so "What's New" is not shown. Kept here for the next version.

---

## English (en-US) — primary

**App name**

`Burrow: Kids Music & Video` (26/30)

**Subtitle** — recommended

`Your songs, offline, no ads` (27/30)

Alternatives, kept for reference:
- Only what you choose. No ads. (29/30)
- The player you fill yourself (28/30)

**Promotional text**

No recommendations, no autoplay into the unknown, no ads. Burrow plays only what
you put there — and stops when you say so.

**Description**

Burrow is a small, quiet place for a young child. You choose what goes in; there is no way for anything else to get out of it.

Most apps for children are built to keep them watching. This one is built to stop. No recommendations, no infinite feed, no autoplay into something you have never seen.

HOW IT WORKS
- You make tiles: one tile is one playlist, music or video
- Fill them with audio and video files from your device, Apple Music songs, or YouTube links
- Your child sees big, calm tiles and nothing else — no search, no browsing, no way out
- A year-of-birth question guards everything on the parent's side

CALM BY DESIGN
- No scores, no timers, no streaks, nothing that ends play for good
- A YouTube link plays without recommendations or comments around it
- In a music tile, a YouTube item plays sound only and keeps its picture hidden

GAMES
Six games, all quiet: Matching Pairs, Odd One Out, Copy the Pattern, Tic Tac Toe, Four in a Row, and Hangman without the gallows. The opponent in Tic Tac Toe and Four in a Row blocks only some of the time, because a perfect opponent is one a four-year-old can never beat.

SCREEN TIME
Set a daily limit per child. When the time is up, playback stops and Burrow returns to the profile picker.

YOUR DATA STAYS YOURS
- No accounts, no analytics, no advertising, no tracking
- Profiles, tiles and playlists sync through your own private iCloud
- Nothing is ever sent to us — there is no server of ours to send it to
- Export a full backup whenever you like

BURROW FULL
One purchase, forever. No subscription:
- Unlimited child profiles (free: one)
- Unlimited tiles per profile (free: five)
- Up to 50 items per playlist (free: three)
- Every game (free: two)

Try everything free for 14 days. Nothing to cancel, no card needed.

**Keywords**

`toddler,preschool,playlist,mp3,audiobook,player,screentime,parental,car,sleep,nursery,wifi` (90/100)

---

## German (de-DE)

**App name**

`Burrow: Musik & Video Player` (28/30)

**Subtitle** — recommended

`Kindersicher, ohne Werbung` (26/30)

Alternatives, kept for reference:
- Ohne Werbung, ohne Algorithmus (30/30)
- Nur was du aussuchst (20/30)

**Promotional text**

Keine Empfehlungen, keine Autoplay-Überraschungen, keine Werbung. Burrow spielt
nur, was du hineinlegst — und hört auf, wenn du es sagst.

**Description**

Burrow ist ein kleiner, ruhiger Ort für ein junges Kind. Du bestimmst, was hineinkommt; etwas anderes kann nicht herauskommen.

Die meisten Kinder-Apps sind dafür gebaut, dass weitergeschaut wird. Diese ist dafür gebaut, aufzuhören. Keine Empfehlungen, kein endloser Feed, kein Autoplay in etwas, das du nie gesehen hast.

SO GEHT ES
- Du legst Kacheln an: eine Kachel ist eine Wiedergabeliste, Musik oder Video
- Füll sie mit Audio- und Videodateien vom Gerät, Apple-Music-Titeln oder YouTube-Links
- Dein Kind sieht große, ruhige Kacheln und sonst nichts — keine Suche, kein Stöbern
- Eine Frage nach dem Geburtsjahr schützt den Elternbereich

RUHIG GEBAUT
- Keine Punkte, keine Timer, keine Serien, nichts, was das Spiel endgültig beendet
- Ein YouTube-Link läuft ohne Empfehlungen und Kommentare drumherum
- In einer Musikkachel spielt ein YouTube-Eintrag nur den Ton, das Bild bleibt verborgen

SPIELE
Sechs ruhige Spiele: Memory, Was passt nicht dazu, Muster nachspielen, Tic Tac Toe, Vier gewinnt und Galgenmännchen ohne Galgen. Der Gegner blockt nur manchmal — ein perfekter Gegner ist einer, den ein Vierjähriger nie schlägt.

BILDSCHIRMZEIT
Ein Tageslimit pro Kind. Ist die Zeit um, stoppt die Wiedergabe und Burrow kehrt zur Profilauswahl zurück.

DEINE DATEN BLEIBEN DEINE
- Keine Konten, keine Analyse, keine Werbung, kein Tracking
- Profile, Kacheln und Wiedergabelisten synchronisieren über deine eigene iCloud
- Nichts geht an uns — es gibt keinen Server von uns
- Jederzeit ein vollständiges Backup exportieren

BURROW FULL
Ein Kauf, für immer. Kein Abo:
- Unbegrenzt Kinderprofile (kostenlos: eines)
- Unbegrenzt Kacheln pro Profil (kostenlos: fünf)
- Bis zu 50 Einträge pro Wiedergabeliste (kostenlos: drei)
- Alle Spiele (kostenlos: zwei)

14 Tage lang alles kostenlos testen. Nichts zu kündigen, keine Kartendaten nötig.

**Keywords**

`Kleinkind,Kita,Bildschirmzeit,Playlist,mp3,Hörbuch,offline,Einschlafen,Auto,eigene,Lied` (87/100)

---

## Spanish (es-ES)

**App name**

`Burrow: Música y Vídeo Niños` (28/30)

**Subtitle** — recommended

`Sin anuncios ni algoritmos` (26/30)

Alternatives, kept for reference:
- Solo lo que tú eliges (21/30)
- Tranquilo y sin sorpresas (25/30)

**Promotional text**

Sin recomendaciones, sin reproducción automática hacia lo desconocido, sin
anuncios. Burrow reproduce solo lo que tú pones.

**Description**

Burrow es un lugar pequeño y tranquilo para un niño pequeño. Tú decides qué entra; nada más puede salir.

La mayoría de las apps infantiles están hechas para que se siga mirando. Esta está hecha para parar. Sin recomendaciones, sin scroll infinito, sin reproducción automática hacia algo que nunca has visto.

CÓMO FUNCIONA
- Creas mosaicos: un mosaico es una lista, de música o de vídeo
- Los llenas con archivos de tu dispositivo, canciones de Apple Music o enlaces de YouTube
- Tu hijo ve mosaicos grandes y tranquilos, y nada más: sin buscador, sin navegación
- Una pregunta sobre el año de nacimiento protege la zona de padres

TRANQUILO POR DISEÑO
- Sin puntos, sin cronómetros, sin rachas, nada que termine el juego para siempre
- Un enlace de YouTube se reproduce sin recomendaciones ni comentarios alrededor
- En un mosaico de música, un elemento de YouTube solo suena; su imagen queda oculta

JUEGOS
Seis juegos tranquilos: Parejas, Cuál sobra, Copia el patrón, Tres en raya, Cuatro en raya y el ahorcado sin horca. El rival bloquea solo a veces, porque un rival perfecto es uno al que un niño de cuatro años nunca gana.

TIEMPO DE PANTALLA
Un límite diario por niño. Cuando se acaba, la reproducción se detiene y Burrow vuelve al selector de perfiles.

TUS DATOS SIGUEN SIENDO TUYOS
- Sin cuentas, sin analíticas, sin publicidad, sin rastreo
- Perfiles, mosaicos y listas se sincronizan con tu propia iCloud
- Nunca se nos envía nada: no tenemos ningún servidor
- Exporta una copia de seguridad completa cuando quieras

BURROW FULL
Una compra, para siempre. Sin suscripción:
- Perfiles infantiles ilimitados (gratis: uno)
- Mosaicos ilimitados por perfil (gratis: cinco)
- Hasta 50 elementos por lista (gratis: tres)
- Todos los juegos (gratis: dos)

Prueba todo gratis durante 14 días. No hay nada que cancelar ni hace falta tarjeta.

**Keywords**

`infantil,preescolar,bebé,pantalla,lista,mp3,audiolibro,offline,coche,dormir,siesta,propia` (89/100)

---

## French (fr-FR)

**App name**

`Burrow : Musique & Vidéo` (24/30)

**Subtitle** — recommended

`Le lecteur des tout-petits` (26/30)

Alternatives, kept for reference:
- Sans publicité ni algorithme (28/30)
- Calme, sans surprises (21/30)

**Promotional text**

Aucune recommandation, aucune lecture automatique vers l'inconnu, aucune
publicité. Burrow ne joue que ce que vous y mettez.

**Description**

Burrow est un petit endroit calme pour un jeune enfant. Vous choisissez ce qui y entre ; rien d'autre ne peut en sortir.

La plupart des applications pour enfants sont faites pour qu'on continue à regarder. Celle-ci est faite pour s'arrêter. Aucune recommandation, aucun fil infini, aucune lecture automatique vers quelque chose que vous n'avez jamais vu.

COMMENT ÇA MARCHE
- Vous créez des tuiles : une tuile est une liste de lecture, musique ou vidéo
- Vous les remplissez avec vos fichiers, des titres Apple Music ou des liens YouTube
- Votre enfant voit de grandes tuiles calmes, et rien d'autre : pas de recherche, pas de navigation
- Une question sur l'année de naissance protège l'espace parents

CALME PAR CONCEPTION
- Pas de score, pas de minuteur, pas de série, rien qui mette fin au jeu pour de bon
- Un lien YouTube se lit sans recommandations ni commentaires autour
- Dans une tuile de musique, un élément YouTube ne joue que le son ; son image reste masquée

JEUX
Six jeux calmes : Paires, L'intrus, Répète le motif, Morpion, Puissance 4 et le pendu sans potence. L'adversaire ne bloque qu'une fois sur deux, car un adversaire parfait est un adversaire qu'un enfant de quatre ans ne bat jamais.

TEMPS D'ÉCRAN
Une limite quotidienne par enfant. Le temps écoulé, la lecture s'arrête et Burrow revient au choix du profil.

VOS DONNÉES RESTENT LES VÔTRES
- Pas de compte, pas de statistiques, pas de publicité, pas de suivi
- Profils, tuiles et listes se synchronisent via votre propre iCloud
- Rien ne nous est envoyé : nous n'avons aucun serveur
- Exportez une sauvegarde complète quand vous voulez

BURROW FULL
Un achat, pour toujours. Sans abonnement :
- Profils enfants illimités (gratuit : un)
- Tuiles illimitées par profil (gratuit : cinq)
- Jusqu'à 50 éléments par liste (gratuit : trois)
- Tous les jeux (gratuit : deux)

Tout essayer gratuitement pendant 14 jours. Rien à résilier, aucune carte demandée.

**Keywords**

`enfant,bébé,maternelle,playlist,mp3,livre,audio,hors-ligne,voiture,dormir,sieste,écran,sûr` (90/100)

---

## Dutch (nl-NL)

**App name**

`Burrow: Muziek & Video` (22/30)

**Subtitle** — recommended

`Kindveilig, zonder reclame` (26/30)

Alternatives, kept for reference:
- Alleen wat jij kiest (20/30)
- Zonder reclame of algoritme (27/30)

**Promotional text**

Geen aanbevelingen, geen autoplay naar het onbekende, geen reclame. Burrow
speelt alleen wat jij erin zet — en stopt wanneer jij dat zegt.

**Description**

Burrow is een kleine, rustige plek voor een jong kind. Jij bepaalt wat erin komt; iets anders kan er niet uit komen.

De meeste kinder-apps zijn gebouwd om te blijven kijken. Deze is gebouwd om te stoppen. Geen aanbevelingen, geen eindeloze stroom, geen autoplay naar iets dat je nooit hebt gezien.

ZO WERKT HET
- Je maakt tegels: één tegel is één afspeellijst, muziek of video
- Je vult ze met audio- en videobestanden van je toestel, Apple Music-nummers of YouTube-links
- Je kind ziet grote, rustige tegels en verder niets — geen zoekbalk, geen bladeren
- Een vraag naar het geboortejaar beschermt het oudergedeelte

RUSTIG ONTWORPEN
- Geen punten, geen timers, geen reeksen, niets dat het spel voorgoed beëindigt
- Een YouTube-link speelt zonder aanbevelingen of reacties eromheen
- In een muziektegel speelt een YouTube-onderdeel alleen geluid; het beeld blijft verborgen

SPELLETJES
Zes rustige spelletjes: Memory, Welke hoort er niet bij, Doe het patroon na, Boter-kaas-en-eieren, Vier op een rij en Galgje zonder galg. De tegenstander blokkeert maar de helft van de tijd, want een perfecte tegenstander is er één die een vierjarige nooit verslaat.

SCHERMTIJD
Een daglimiet per kind. Is de tijd om, dan stopt het afspelen en gaat Burrow terug naar de profielkiezer.

JE GEGEVENS BLIJVEN VAN JOU
- Geen accounts, geen statistieken, geen advertenties, geen tracking
- Profielen, tegels en afspeellijsten synchroniseren via je eigen iCloud
- Er gaat nooit iets naar ons — wij hebben geen server
- Exporteer wanneer je wilt een volledige back-up

BURROW FULL
Eén aankoop, voor altijd. Geen abonnement:
- Onbeperkt kindprofielen (gratis: één)
- Onbeperkt tegels per profiel (gratis: vijf)
- Tot 50 onderdelen per afspeellijst (gratis: drie)
- Alle spelletjes (gratis: twee)

Probeer 14 dagen alles gratis. Niets op te zeggen en geen betaalgegevens nodig.

**Keywords**

`peuter,kleuter,schermtijd,afspeellijst,mp3,luisterboek,offline,slapen,auto,eigen,veilig,liedje` (94/100)

---

## The YouTube Caveat

The app, the support page and the review notes all say the same thing, and the
wording lives once in `YouTubeSupportNotice`: YouTube playback depends on
Google's permission, Burrow supports it for as long as YouTube allows it, and
nothing else in the app depends on it. It is disclosed on the screen where a
parent adds a link and again on the purchase screen, before any money moves.

Whether to repeat it in the store descriptions is a judgement call and has been
left open: it is the strongest pre-purchase surface there is, and it also costs
conversion. Recommended if YouTube support is kept.

## Review Information Reminders

- **Kids Category — decide deliberately.** Burrow plays parent-supplied YouTube links through YouTube's embedded player. Apple's Kids Category rules (Guideline 1.3, and 5.1.4 on data from children) restrict third-party analytics and advertising, and an embedded YouTube player is exactly the kind of third-party content that draws scrutiny. Recommendation: submit under **Education**, not the Kids Category, unless YouTube support is removed. Do not tick "Made for Kids".
- No account or sign-in exists, so no demo account is needed. Say so explicitly in the notes.
- The parent area sits behind a year-of-birth gate; a reviewer must pass it to reach settings and the purchase. Give them the instruction, not an answer they have to guess.
- Age rating: expected 4+. There is no user-generated content, no chat, no external links reachable by a child, and no advertising.
- Attach the review notes from `APP_REVIEW_NOTES.md` in App Review Information → Notes (4000-character cap).

## App Privacy Questionnaire

Answers to give in App Store Connect → App Privacy:

- **Data collected: none.** Nothing is transmitted to the developer; there is no server.
- Content, settings and usage statistics are stored on device and in the user's **own** private CloudKit database. Apple treats this as not collected by the developer, since the developer has no access.
- No tracking, so **App Tracking Transparency does not apply** and no ATT prompt is shown.
- Third-party SDKs: none. ZIPFoundation is a local zip library and makes no network requests.
- Note in the questionnaire that Apple Music playback and embedded YouTube playback are handled by Apple and Google respectively, under their own policies.

## Still Open

- **The brand still leads every name field.** `Burrow` has no search volume and no
  tie to the category, and the name field is the most heavily weighted input in
  App Store search. Putting the searched words first — `Kids Music Player: Burrow`
  — was considered and deliberately not done here; it is a separate decision from
  the content-promise fix above.
- The trial length (14 days) is a guess, not a measured number. It is one
  constant, `Trial.length`.

## Metadata Checks Before Submission

- [x] Every name, subtitle and keyword field is inside its limit (recomputed after the
      rewrite; re-check after any further edit)
- [x] No word repeats between name, subtitle and keyword field — Apple combines them
- [x] No name promises content the app does not ship. The German name said
      *Hörspiel* and the French *Comptines*, both of which tell a parent that
      stories and rhymes are inside; Dutch *Liedjes* did the same. All three now
      name the container, not the contents
- [ ] No competitor trademarks in keywords (**Toniebox**, **YouTube**, **Spotify** are all rejection risks)
- [x] Keyword field uses singulars, no spaces after commas
- [ ] Non-English descriptions reviewed by a native speaker — the drafts above are the developer's own and have not been reviewed
- [ ] `website/privacy.html` and `website/support.html` published at the URLs above and reachable
- [ ] Screenshots per device size, showing the child grid, a tile editor, and the games grid
- [ ] IAP `com.pvd.burrow.pro` created, priced, and submitted with the build
- [ ] Build number is the git commit count (stamped automatically — confirm it in App Store Connect, do not set it by hand)
