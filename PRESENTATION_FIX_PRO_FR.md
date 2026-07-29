# Fix Pro

### La plateforme hyper-locale de mise en relation instantanée pour les services de maintenance et de dépannage à domicile

**Document de présentation — Partenaires, Investisseurs & Parties Prenantes**
**Marché cible : Abidjan & Côte d'Ivoire**

---

## Sommaire

1. [Présentation Générale & Vision](#1-présentation-générale--vision)
2. [Problématique du Marché & Solution Fix Pro](#2-problématique-du-marché--solution-fix-pro)
3. [Fonctionnement Technologique & Algorithme de Matching](#3-fonctionnement-technologique--algorithme-de-matching)
4. [Modèle Économique](#4-modèle-économique-business-model)
5. [Stratégie de Lancement Hyper-Local](#5-stratégie-de-lancement-hyper-local-stratégie-domino)
6. [Sécurité, Confiance & Modération (KYC)](#6-sécurité-confiance--modération-kyc)
7. [Panneau d'Administration & Pilotage](#7-panneau-dadministration--pilotage-founder-analytics-dashboard)

---

## 1. Présentation Générale & Vision

| | |
|---|---|
| **Nom du projet** | Fix Pro |
| **Secteur** | Services à la personne / Économie à la demande (On-Demand Economy) |
| **Marché de lancement** | Abidjan, Côte d'Ivoire |
| **Ambition** | Devenir la référence panafricaine de la mise en relation instantanée pour les métiers de dépannage à domicile |

**Vision.** Fix Pro est la plateforme hyper-locale sur demande qui connecte, en quelques secondes, tout habitant d'Abidjan à un artisan qualifié et disponible à proximité — plombier, électricien, technicien climatisation, et bien d'autres corps de métier — sans catalogue à parcourir, sans devis interminable, et sans incertitude sur la disponibilité réelle du prestataire.

Fix Pro s'inscrit dans la continuité des grandes plateformes de mise en relation à la demande (modèle Yango / Uber), appliquée pour la première fois de façon structurée aux services de maintenance et de dépannage à domicile en Côte d'Ivoire.

---

## 2. Problématique du Marché & Solution Fix Pro

### 2.1 Le problème

Le marché ivoirien des services de dépannage à domicile reste aujourd'hui largement informel et fragmenté :

- **Difficulté de trouver rapidement un artisan qualifié et de confiance** à Abidjan, en particulier en situation d'urgence (fuite d'eau, panne électrique, climatisation en panne).
- **Opacité totale sur les tarifs**, négociés au cas par cas, sans référence ni transparence pour le client.
- **Annulations fréquentes et absence de fiabilité** : rendez-vous non honorés, artisans injoignables, délais d'intervention imprévisibles.
- **Aucune vérification d'identité ni de compétence** : le client n'a aucune garantie sur qui va réellement intervenir chez lui.

### 2.2 La solution Fix Pro

Fix Pro répond à ce problème par une mise en relation **instantanée et automatisée**, fondée sur la proximité géographique réelle entre le client et l'artisan :

- **Aucun catalogue à parcourir** : le client sélectionne un métier, Fix Pro s'occupe du reste.
- **Aucune négociation préalable** : l'algorithme assigne automatiquement le premier artisan qualifié disponible et à proximité.
- **Transparence et confiance** : chaque artisan est vérifié avant de pouvoir intervenir sur la plateforme.
- **Rapidité** : le temps entre la demande du client et la prise en charge par un artisan se compte en secondes, pas en heures.

---

## 3. Fonctionnement Technologique & Algorithme de Matching

### 3.1 Côté Client

1. Le client ouvre l'application et sélectionne le service recherché (Plomberie, Électricité, Climatisation, Nettoyage, Menuiserie, Mécanique, Peinture, et d'autres corps de métier).
2. Sa position géographique est automatiquement détectée.
3. En **un seul clic**, la demande est envoyée — sans formulaire complexe, sans devis à remplir.

### 3.2 L'algorithme de matching (Direct Match)

Le cœur technologique de Fix Pro est un algorithme d'attribution automatique conçu pour maximiser la rapidité de réponse tout en garantissant l'équité entre artisans :

| Étape | Description |
|---|---|
| **1. Recherche de proximité** | Identification des artisans certifiés en ligne dans un rayon initial de **5 km** autour du client, via géolocalisation en temps réel. |
| **2. Diffusion simultanée** | Notification instantanée envoyée en parallèle aux **5 artisans certifiés les plus proches** disponibles. |
| **3. Attribution automatique** | Le **premier artisan à accepter** la mission se voit attribuer la course, via un mécanisme de verrouillage atomique empêchant toute double affectation. |
| **4. Extension progressive du rayon** | Si aucun artisan n'accepte, le rayon de recherche est automatiquement élargi par paliers de 5 km, jusqu'à un maximum de 30 km, pour garantir qu'une solution soit toujours proposée au client. |

Ce mécanisme garantit un **temps de réponse minimal**, une **répartition équitable** des opportunités entre artisans, et une **fiabilité d'attribution** sans intervention humaine.

### 3.3 Côté Artisan

- Réception de la demande en **temps réel**, via une double infrastructure de notification (notifications Push Firebase Cloud Messaging **et** connexion WebSocket permanente), garantissant la livraison de l'alerte même en cas de coupure réseau ponctuelle.
- L'artisan visualise la distance et le temps d'arrivée estimé avant d'accepter.
- Acceptation en un clic et prise en charge immédiate de la mission.

### 3.4 Architecture technique (aperçu)

| Composant | Technologie |
|---|---|
| Application mobile (Clients & Artisans) | Flutter (Android / iOS) |
| Backend | Node.js / NestJS |
| Base de données | PostgreSQL + PostGIS (calculs géospatiaux) |
| Temps réel | Redis (présence en ligne) + WebSockets (Socket.io) |
| Notifications | Firebase Cloud Messaging (FCM) |

Une architecture pensée dès l'origine pour la fiabilité et la montée en charge progressive, marché par marché.

---

## 4. Modèle Économique (Business Model)

Fix Pro adopte un modèle **d'abonnement fixe par paliers**, plutôt qu'une commission prélevée sur chaque intervention. Ce choix stratégique est délibéré :

- **Prévisibilité des revenus** pour l'artisan comme pour la plateforme.
- **Forte adhésion des artisans** : aucune retenue sur leurs prestations, un partenaire économique plutôt qu'un intermédiaire.
- **Aucune commission prélevée sur les courses au lancement**, afin de maximiser l'engagement et la densité d'artisans actifs dès les premières semaines.

### Grille des abonnements artisans

| Palier | Tarif mensuel | Positionnement |
|---|---|---|
| **Découverte** | Gratuit | Accès d'essai à la plateforme |
| **Bronze** | 3 000 FCFA / mois | Accès complet aux demandes de mission |
| **Argent** | 5 000 FCFA / mois | Visibilité renforcée |
| **Or** | 10 000 FCFA / mois | Priorité maximale et avantages premium |

Le règlement des abonnements est intégré nativement dans l'application (paiement mobile local), garantissant une expérience fluide et adaptée aux usages ivoiriens.

---

## 5. Stratégie de Lancement Hyper-Local (Stratégie Domino)

Plutôt qu'un lancement simultané sur l'ensemble du Grand Abidjan — risqué et coûteux en acquisition —, Fix Pro déploie une **stratégie domino** : une conquête commune par commune, chaque zone n'étant activée qu'une fois une densité critique d'artisans et de clients atteinte.

### 5.1 Séquence de déploiement

| Phase | Commune(s) | Statut |
|---|---|---|
| **Phase 1 — Lancement** | Marcory (Zone 4) | Zone de démarrage ciblée |
| **Phase 2 — Extension** | Cocody, Yopougon | Extension après validation du modèle |
| **Phase 3+ — Expansion** | Plateau, Treichville, Koumassi, Port-Bouët, Abobo, Adjamé, Attécoubé, Bingerville | Déploiement progressif selon la demande |
| **Expansion nationale** | San-Pédro, Gagnoa, Bouaké, Yamoussoukro | Réplication du modèle à l'échelle nationale |

### 5.2 Gestion intelligente des listes d'attente

Chaque commune est administrée indépendamment via deux leviers activables séparément :

- **Ouverture des inscriptions artisans** — active ou non selon la commune.
- **Ouverture des commandes clients** — active ou non selon la commune.

Dans une commune non encore activée, **l'inscription reste toujours possible** : client comme artisan peuvent créer leur compte, mais sont placés en **liste d'attente**. Cette approche permet à Fix Pro de :

- **Mesurer la demande réelle** commune par commune avant d'y engager des ressources opérationnelles ;
- **Constituer une base d'artisans et de clients prête à l'emploi** dès l'activation officielle d'une nouvelle zone ;
- **Piloter l'expansion par la donnée**, plutôt que par intuition.

---

## 6. Sécurité, Confiance & Modération (KYC)

La confiance est au cœur de la proposition de valeur de Fix Pro. Chaque acteur de la plateforme est vérifié avant de pouvoir opérer.

### 6.1 Vérification d'identité des artisans (KYC)

- Soumission obligatoire d'une pièce d'identité officielle (**Carte Nationale d'Identité ou Passeport**) lors de l'inscription.
- **Lecture automatique par reconnaissance optique de caractères (OCR)** pour l'extraction et la pré-validation des données du document.
- **Validation manuelle finale par l'équipe d'administration** avant activation du compte artisan sur la plateforme — aucun artisan ne peut recevoir de mission sans validation KYC complète.
- Motif de rejet communiqué à l'artisan en cas de dossier incomplet, avec possibilité de resoumission.

### 6.2 Modération et lutte anti-fraude

- **Système de bannissement par numéro de téléphone** : un numéro identifié comme frauduleux ou abusif (annulations répétées, comportement à risque) peut être bloqué par l'administration, empêchant toute nouvelle inscription avec ce numéro.
- **Extension prévue à l'identifiant d'appareil (Device ID)**, pour renforcer la protection contre les tentatives de contournement par recréation de compte.
- **Désactivation ciblée de comptes** (artisan ou client) par l'administration, indépendamment du blocage du numéro, pour une gestion fine des incidents.

---

## 7. Panneau d'Administration & Pilotage (Founder Analytics Dashboard)

Fix Pro met à disposition de son équipe fondatrice un **tableau de bord d'administration complet**, conçu pour un pilotage opérationnel en temps réel de la plateforme, sans dépendance technique externe.

### 7.1 Contrôle opérationnel

- **Activation / désactivation indépendante**, commune par commune, des inscriptions artisans et des commandes clients — le levier central de la stratégie domino décrite en section 5.
- **Vérification KYC** des artisans directement depuis le tableau de bord, avec consultation des pièces justificatives.
- **Gestion de la liste noire** (numéros bloqués) et **annuaire complet** des utilisateurs inscrits, avec recherche instantanée par numéro de téléphone.
- **Communication ciblée** : envoi de notifications push segmentées par rôle, par métier, par commune, ou vers les utilisateurs en liste d'attente — un levier direct d'activation et de rétention.

### 7.2 Pilotage par la donnée en temps réel

| Indicateur suivi | Description |
|---|---|
| **Présence en ligne** | Nombre d'artisans et de clients actifs à l'instant T, par commune et par métier |
| **Taux de succès du matching** | Suivi du volume de demandes par statut (en attente, assignée, en cours, terminée, annulée, expirée) |
| **Répartition géographique** | Répartition de l'activité par commune et par corps de métier |
| **Historique des communications** | Journal complet des campagnes de notification envoyées, avec taux de portée |

Ce niveau de visibilité permet à l'équipe fondatrice de **détecter les pics de demande**, d'**identifier les zones sous-desservies** en artisans, et d'**ajuster la stratégie d'expansion en continu**, sur la base de données réelles et non d'estimations.

---

## Conclusion

Fix Pro combine une exécution technologique rigoureuse — algorithme de matching en temps réel, infrastructure géospatiale, double canal de notification — avec une stratégie de lancement disciplinée et un modèle économique aligné avec les intérêts des artisans. Cette approche pose les fondations d'une plateforme scalable, conçue pour devenir une infrastructure de confiance incontournable des services à domicile en Côte d'Ivoire, puis à l'échelle du continent.

---

*Document confidentiel destiné aux partenaires, investisseurs et parties prenantes de Fix Pro.*
