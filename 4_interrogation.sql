-- =====================================================================
-- Mini-projet BDD : championnat de football professionnel
-- 4_interrogation.sql : requêtes du scénario d'utilisation
-- À exécuter après 1_creation.sql, 2_contraintes.sql et 3_insertion.sql
-- =====================================================================
-- Scénario : un analyste de la direction des compétitions de la Ligue
-- prépare (1) le bilan sportif de la saison 2025-2026, publié dans le
-- rapport annuel, et (2) le suivi de la saison 2026-2027 en cours :
-- calendrier restant, désignation des arbitres, discipline et effectifs.
-- Le détail du scénario est dans le README.
-- =====================================================================

USE ligue_football;
SET NAMES utf8mb4;

-- =====================================================================
-- 1. Projections et sélections
--    (tri, données uniques, masques, IN, BETWEEN)
-- =====================================================================

-- 1.1 Calendrier restant de la saison 2026-2027 : matchs programmés ou
--     reportés, du plus proche au plus lointain.
SELECT numero_match, numero_journée, date_match, heure_coup_envoi, statut_match
FROM Match_
WHERE libelle_saison = '2026-2027'
  AND statut_match IN ('programmé', 'reporté')
ORDER BY date_match, heure_coup_envoi;

-- 1.2 Liste des nationalités représentées dans le championnat
--     (chaque nationalité une seule fois, par ordre alphabétique).
SELECT DISTINCT nationalite_joueur
FROM Joueur
ORDER BY nationalite_joueur;

-- 1.3 Jeunes joueurs offensifs, nés entre 2004 et 2007, pour le trophée
--     du meilleur espoir : du plus jeune au plus âgé.
SELECT nom_joueur, prenom_joueur, date_naissance_joueur, poste_joueur
FROM Joueur
WHERE date_naissance_joueur BETWEEN '2004-01-01' AND '2007-12-31'
  AND poste_joueur IN ('milieu', 'attaquant')
ORDER BY date_naissance_joueur DESC;

-- 1.4 Arbitres de catégorie fédérale (masque « Fédéral% »), qui peuvent
--     être désignés pour les matchs restants de la saison.
SELECT nom_arbitre, prenom_arbitre, categorie_arbitre
FROM Arbitre
WHERE categorie_arbitre LIKE 'Fédéral%'
ORDER BY categorie_arbitre, nom_arbitre;

-- 1.5 Buts décisifs en fin de match (à partir de la 85e minute, temps
--     additionnel compris), hors buts contre son camp.
SELECT numero_match, minute_but, type_but, numero_licence_joueur
FROM But
WHERE minute_but BETWEEN 85 AND 130
  AND type_but <> 'contre son camp'
ORDER BY minute_but DESC;

-- 1.6 Stades dont le nom commence par « Stade » ou dont la ville est
--     composée (masques avec % et _), triés par capacité décroissante.
SELECT code_stade, nom_stade, ville_stade, capacite_stade
FROM Stade
WHERE nom_stade LIKE 'Stade%'
   OR ville_stade LIKE '%-%'
ORDER BY capacite_stade DESC;

-- =====================================================================
-- 2. Fonctions d'agrégation (GROUP BY, HAVING)
-- =====================================================================

-- 2.1 Répartition des matchs entre les arbitres : nombre de matchs
--     dirigés par chacun, pour ceux qui en ont dirigé au moins 8.
SELECT A.nom_arbitre, A.prenom_arbitre, COUNT(*) AS nb_matchs
FROM Arbitre A
JOIN Match_ M ON M.numero_licence_arbitre = A.numero_licence_arbitre
GROUP BY A.numero_licence_arbitre, A.nom_arbitre, A.prenom_arbitre
HAVING COUNT(*) >= 8
ORDER BY nb_matchs DESC;

-- 2.2 Nombre de buts par type et par saison.
SELECT M.libelle_saison, B.type_but, COUNT(*) AS nb_buts
FROM But B
JOIN Match_ M ON M.numero_match = B.numero_match
GROUP BY M.libelle_saison, B.type_but
ORDER BY M.libelle_saison, nb_buts DESC;

-- 2.3 Classement des buteurs de la saison 2025-2026 (au moins 4 buts,
--     les buts contre son camp ne comptent pas pour le buteur).
SELECT J.nom_joueur, J.prenom_joueur, COUNT(*) AS nb_buts,
       SUM(B.type_but = 'penalty') AS dont_penaltys
FROM But B
JOIN Match_ M ON M.numero_match = B.numero_match
JOIN Joueur J ON J.numero_licence_joueur = B.numero_licence_joueur
WHERE M.libelle_saison = '2025-2026'
  AND B.type_but <> 'contre son camp'
GROUP BY J.numero_licence_joueur, J.nom_joueur, J.prenom_joueur
HAVING COUNT(*) >= 4
ORDER BY nb_buts DESC, dont_penaltys;

-- 2.4 Bilan disciplinaire : joueurs ayant reçu au moins 3 cartons sur
--     l'ensemble des deux saisons, avec le détail jaunes / rouges.
SELECT J.nom_joueur, J.prenom_joueur,
       SUM(C.couleur_carton = 'jaune') AS jaunes,
       SUM(C.couleur_carton = 'rouge') AS rouges,
       COUNT(*) AS total
FROM Carton C
JOIN Joueur J ON J.numero_licence_joueur = C.numero_licence_joueur
GROUP BY J.numero_licence_joueur, J.nom_joueur, J.prenom_joueur
HAVING COUNT(*) >= 3
ORDER BY rouges DESC, total DESC;

-- 2.5 Âge moyen, minimum et maximum de chaque effectif en 2026-2027
--     (au début de la saison), pour les clubs dont la moyenne d'âge est
--     inférieure à 27 ans.
SELECT C.nom_club,
       ROUND(AVG(TIMESTAMPDIFF(YEAR, J.date_naissance_joueur, S.date_debut_saison)), 1) AS age_moyen,
       MIN(TIMESTAMPDIFF(YEAR, J.date_naissance_joueur, S.date_debut_saison)) AS age_min,
       MAX(TIMESTAMPDIFF(YEAR, J.date_naissance_joueur, S.date_debut_saison)) AS age_max
FROM APPARTENIR A
JOIN Joueur J ON J.numero_licence_joueur = A.numero_licence_joueur
JOIN Club C   ON C.numero_affiliation = A.numero_affiliation
JOIN SAISON S ON S.libelle_saison = A.libelle_saison
WHERE A.libelle_saison = '2026-2027'
GROUP BY C.numero_affiliation, C.nom_club
HAVING AVG(TIMESTAMPDIFF(YEAR, J.date_naissance_joueur, S.date_debut_saison)) < 27
ORDER BY age_moyen;

-- 2.6 Moyenne de buts par match joué, pour chaque saison.
--     (COUNT(DISTINCT) compte aussi les matchs sans but grâce à la
--     jointure externe.)
SELECT M.libelle_saison,
       COUNT(DISTINCT M.numero_match) AS matchs_joues,
       COUNT(B.numero_ordre_but) AS buts,
       ROUND(COUNT(B.numero_ordre_but) / COUNT(DISTINCT M.numero_match), 2) AS buts_par_match
FROM Match_ M
LEFT JOIN But B ON B.numero_match = M.numero_match
WHERE M.statut_match = 'joué'
GROUP BY M.libelle_saison;

-- 2.7 Classement final de la saison 2025-2026 : points (3 par victoire,
--     1 par nul), victoires, nuls, défaites, buts pour, buts contre et
--     différence de buts. Le score est calculé à partir des buts : un but
--     compte pour le club du buteur, sauf un but contre son camp qui
--     compte pour l'adversaire.
WITH score AS (
    SELECT M.numero_match,
           M.numero_affiliation_Domicile AS domicile,
           M.numero_affiliation_extérieur AS exterieur,
           SUM(B.numero_ordre_but IS NOT NULL
               AND (A.numero_affiliation = M.numero_affiliation_Domicile)
                 = (B.type_but <> 'contre son camp')) AS buts_domicile,
           SUM(B.numero_ordre_but IS NOT NULL
               AND (A.numero_affiliation = M.numero_affiliation_extérieur)
                 = (B.type_but <> 'contre son camp')) AS buts_exterieur
    FROM Match_ M
    LEFT JOIN But B        ON B.numero_match = M.numero_match
    LEFT JOIN APPARTENIR A ON A.numero_licence_joueur = B.numero_licence_joueur
                          AND A.libelle_saison = M.libelle_saison
    WHERE M.libelle_saison = '2025-2026'
      AND M.statut_match = 'joué'
    GROUP BY M.numero_match, M.numero_affiliation_Domicile, M.numero_affiliation_extérieur
),
resultat AS (
    SELECT domicile AS club, buts_domicile AS bp, buts_exterieur AS bc FROM score
    UNION ALL
    SELECT exterieur, buts_exterieur, buts_domicile FROM score
)
SELECT C.nom_club,
       SUM(CASE WHEN R.bp > R.bc THEN 3 WHEN R.bp = R.bc THEN 1 ELSE 0 END) AS points,
       COUNT(*) AS joues,
       SUM(R.bp > R.bc) AS victoires,
       SUM(R.bp = R.bc) AS nuls,
       SUM(R.bp < R.bc) AS defaites,
       SUM(R.bp) AS buts_pour,
       SUM(R.bc) AS buts_contre,
       SUM(R.bp) - SUM(R.bc) AS difference
FROM resultat R
JOIN Club C ON C.numero_affiliation = R.club
GROUP BY C.numero_affiliation, C.nom_club
ORDER BY points DESC, difference DESC, buts_pour DESC;

-- =====================================================================
-- 3. Jointures (internes, externes, simples, multiples, auto-jointure)
-- =====================================================================

-- 3.1 Jointure simple : entraîneur principal de chaque club pour la
--     saison 2026-2027.
SELECT C.nom_club, E.prénom_entraineur, E.nom_entraineur, E.nationalite_entraineur
FROM DIRIGER D
JOIN Entraineur E ON E.numero_licence_entraineur = D.numero_licence_entraineur
JOIN Club C       ON C.numero_affiliation = D.numero_affiliation
WHERE D.libelle_saison = '2026-2027'
ORDER BY C.nom_club;

-- 3.2 Jointure multiple (deux fois la table Club) : affiches de la
--     prochaine journée programmée de 2026-2027, avec le stade et
--     l'arbitre désigné.
SELECT M.numero_journée, M.date_match, M.heure_coup_envoi,
       CD.nom_club AS domicile, CE.nom_club AS exterieur,
       S.nom_stade, A.nom_arbitre
FROM Match_ M
JOIN Club CD   ON CD.numero_affiliation = M.numero_affiliation_Domicile
JOIN Club CE   ON CE.numero_affiliation = M.numero_affiliation_extérieur
JOIN Stade S   ON S.code_stade = M.code_stade
JOIN Arbitre A ON A.numero_licence_arbitre = M.numero_licence_arbitre
WHERE M.libelle_saison = '2026-2027'
  AND M.numero_journée = (SELECT MIN(numero_journée) FROM Match_
                          WHERE libelle_saison = '2026-2027'
                            AND statut_match = 'programmé')
ORDER BY M.date_match, M.heure_coup_envoi;

-- 3.3 Jointure interne : effectif de l'Olympique de Marseille en
--     2026-2027, trié par numéro de maillot.
SELECT A.numero_maillot, J.nom_joueur, J.prenom_joueur, J.poste_joueur
FROM APPARTENIR A
JOIN Joueur J ON J.numero_licence_joueur = A.numero_licence_joueur
JOIN Club C   ON C.numero_affiliation = A.numero_affiliation
WHERE C.nom_club = 'Olympique de Marseille'
  AND A.libelle_saison = '2026-2027'
ORDER BY A.numero_maillot;

-- 3.4 Jointure externe gauche : nombre de matchs accueillis par chaque
--     stade en 2026-2027, y compris les stades qui n'en accueillent aucun.
SELECT S.nom_stade, S.ville_stade, COUNT(M.numero_match) AS nb_matchs
FROM Stade S
LEFT JOIN Match_ M ON M.code_stade = S.code_stade
                  AND M.libelle_saison = '2026-2027'
GROUP BY S.code_stade, S.nom_stade, S.ville_stade
ORDER BY nb_matchs DESC;

-- 3.5 Jointure externe : tous les joueurs de l'effectif du Paris
--     Saint-Germain en 2025-2026, avec leur nombre de buts, y compris
--     ceux qui n'ont pas marqué.
SELECT J.nom_joueur, J.prenom_joueur, J.poste_joueur, COUNT(B.numero_ordre_but) AS nb_buts
FROM APPARTENIR A
JOIN Joueur J ON J.numero_licence_joueur = A.numero_licence_joueur
JOIN Club C   ON C.numero_affiliation = A.numero_affiliation
LEFT JOIN (But B JOIN Match_ M ON M.numero_match = B.numero_match
                               AND M.libelle_saison = '2025-2026')
       ON B.numero_licence_joueur = A.numero_licence_joueur
      AND B.type_but <> 'contre son camp'
WHERE C.nom_club = 'Paris Saint-Germain'
  AND A.libelle_saison = '2025-2026'
GROUP BY J.numero_licence_joueur, J.nom_joueur, J.prenom_joueur, J.poste_joueur
ORDER BY nb_buts DESC, J.nom_joueur;

-- 3.6 Auto-jointure (APPARTENIR avec elle-même) : joueurs qui ont changé
--     de club entre 2025-2026 et 2026-2027, avec l'ancien et le nouveau club.
SELECT J.nom_joueur, J.prenom_joueur,
       C1.nom_club AS club_2025_2026, C2.nom_club AS club_2026_2027
FROM APPARTENIR A1
JOIN APPARTENIR A2 ON A2.numero_licence_joueur = A1.numero_licence_joueur
                  AND A2.libelle_saison = '2026-2027'
JOIN Joueur J ON J.numero_licence_joueur = A1.numero_licence_joueur
JOIN Club C1  ON C1.numero_affiliation = A1.numero_affiliation
JOIN Club C2  ON C2.numero_affiliation = A2.numero_affiliation
WHERE A1.libelle_saison = '2025-2026'
  AND A1.numero_affiliation <> A2.numero_affiliation
ORDER BY C1.nom_club, J.nom_joueur;

-- 3.7 Requête étudiée dans le README (plans d'exécution) : joueurs
--     exclus (carton rouge), avec la date du match.
SELECT J.nom_joueur, J.prenom_joueur, M.date_match
FROM Carton C
JOIN Joueur J ON J.numero_licence_joueur = C.numero_licence_joueur
JOIN Match_ M ON M.numero_match = C.numero_match
WHERE C.couleur_carton = 'rouge';

-- =====================================================================
-- 4. Requêtes imbriquées ((NOT) IN, (NOT) EXISTS, ANY, ALL)
-- =====================================================================

-- 4.1 NOT IN : clubs qui ont participé à la saison 2025-2026 mais pas à
--     la saison 2026-2027.
SELECT nom_club
FROM Club
WHERE numero_affiliation IN (SELECT numero_affiliation FROM PARTICIPER
                             WHERE libelle_saison = '2025-2026')
  AND numero_affiliation NOT IN (SELECT numero_affiliation FROM PARTICIPER
                                 WHERE libelle_saison = '2026-2027');

-- 4.2 IN : joueurs qui ont marqué au moins un penalty, toutes saisons
--     confondues.
SELECT nom_joueur, prenom_joueur, poste_joueur
FROM Joueur
WHERE numero_licence_joueur IN (SELECT numero_licence_joueur FROM But
                                WHERE type_but = 'penalty')
ORDER BY nom_joueur;

-- 4.3 NOT EXISTS : prix du fair-play, joueurs de l'effectif 2025-2026
--     qui n'ont reçu aucun carton pendant la saison, par club.
SELECT C.nom_club, J.nom_joueur, J.prenom_joueur
FROM APPARTENIR A
JOIN Joueur J ON J.numero_licence_joueur = A.numero_licence_joueur
JOIN Club C   ON C.numero_affiliation = A.numero_affiliation
WHERE A.libelle_saison = '2025-2026'
  AND NOT EXISTS (SELECT 1
                  FROM Carton K
                  JOIN Match_ M ON M.numero_match = K.numero_match
                  WHERE K.numero_licence_joueur = A.numero_licence_joueur
                    AND M.libelle_saison = '2025-2026')
ORDER BY C.nom_club, J.nom_joueur;

-- 4.4 EXISTS : arbitres qui ont exclu au moins un joueur (carton rouge),
--     pour le rapport de la commission des arbitres.
SELECT nom_arbitre, prenom_arbitre, categorie_arbitre
FROM Arbitre A
WHERE EXISTS (SELECT 1
              FROM Match_ M
              JOIN Carton K ON K.numero_match = M.numero_match
              WHERE M.numero_licence_arbitre = A.numero_licence_arbitre
                AND K.couleur_carton = 'rouge')
ORDER BY nom_arbitre;

-- 4.5 ALL : le ou les joueurs les plus âgés du championnat en 2026-2027.
SELECT J.nom_joueur, J.prenom_joueur, J.date_naissance_joueur
FROM Joueur J
JOIN APPARTENIR A ON A.numero_licence_joueur = J.numero_licence_joueur
WHERE A.libelle_saison = '2026-2027'
  AND J.date_naissance_joueur <= ALL (SELECT J2.date_naissance_joueur
                                      FROM Joueur J2
                                      JOIN APPARTENIR A2 ON A2.numero_licence_joueur = J2.numero_licence_joueur
                                      WHERE A2.libelle_saison = '2026-2027');

-- 4.6 ALL : club(s) participant à la saison 2026-2027 dont le stade de
--     résidence est le plus grand, candidat pour accueillir la finale du
--     trophée de fin de saison.
SELECT C.nom_club, S.nom_stade, S.capacite_stade
FROM Club C
JOIN Stade S ON S.code_stade = C.code_stade
WHERE C.numero_affiliation IN (SELECT numero_affiliation FROM PARTICIPER
                               WHERE libelle_saison = '2026-2027')
  AND S.capacite_stade >= ALL (SELECT S2.capacite_stade
                               FROM Club C2
                               JOIN Stade S2 ON S2.code_stade = C2.code_stade
                               JOIN PARTICIPER P ON P.numero_affiliation = C2.numero_affiliation
                               WHERE P.libelle_saison = '2026-2027');

-- 4.7 ANY : joueurs qui ont marqué lors d'un match dirigé par l'un des
--     arbitres internationaux.
SELECT DISTINCT J.nom_joueur, J.prenom_joueur
FROM Joueur J
JOIN But B ON B.numero_licence_joueur = J.numero_licence_joueur
WHERE B.numero_match = ANY (SELECT M.numero_match
                            FROM Match_ M
                            JOIN Arbitre A ON A.numero_licence_arbitre = M.numero_licence_arbitre
                            WHERE A.categorie_arbitre = 'International')
ORDER BY J.nom_joueur;

-- 4.8 Sous-requête dans le FROM : buteurs de 2025-2026 qui ont marqué
--     plus que la moyenne des buteurs de la saison.
SELECT T.nom_joueur, T.prenom_joueur, T.nb_buts
FROM (SELECT J.nom_joueur, J.prenom_joueur, COUNT(*) AS nb_buts
      FROM But B
      JOIN Match_ M ON M.numero_match = B.numero_match
      JOIN Joueur J ON J.numero_licence_joueur = B.numero_licence_joueur
      WHERE M.libelle_saison = '2025-2026' AND B.type_but <> 'contre son camp'
      GROUP BY J.numero_licence_joueur, J.nom_joueur, J.prenom_joueur) AS T
WHERE T.nb_buts > (SELECT AVG(nb) FROM
                     (SELECT COUNT(*) AS nb
                      FROM But B
                      JOIN Match_ M ON M.numero_match = B.numero_match
                      WHERE M.libelle_saison = '2025-2026' AND B.type_but <> 'contre son camp'
                      GROUP BY B.numero_licence_joueur) AS moyenne)
ORDER BY T.nb_buts DESC;
