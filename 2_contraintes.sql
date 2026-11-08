-- =====================================================================
-- Mini-projet BDD : championnat de football professionnel
-- 2_contraintes.sql : contraintes de validation (règles métier)
-- À exécuter après 1_creation.sql
-- =====================================================================
-- Types de contraintes utilisés :
--   A. format (expressions régulières) ;
--   B. plage de valeurs (BETWEEN, comparaisons) ;
--   C. liste de valeurs (IN) ;
--   D. comparaison entre colonnes d'une même ligne ;
--   E. unicité métier (UNIQUE) ;
--   F. valeur par défaut (DEFAULT) ;
--   G. règles portant sur plusieurs tables (triggers).
--
-- Remarque MySQL : une colonne utilisée dans un CHECK ne peut pas porter
-- une clé étrangère avec ON UPDATE / ON DELETE CASCADE ou SET NULL
-- (erreur 3823). Les règles qui portent sur ces colonnes (clubs d'un
-- match, joueur d'un but...) sont donc vérifiées par des triggers.
-- =====================================================================

USE ligue_football;

-- ---------------------------------------------------------------------
-- SAISON
-- ---------------------------------------------------------------------
ALTER TABLE SAISON
    -- A. Le libellé a la forme AAAA-AAAA (ex. 2025-2026).
    ADD CONSTRAINT ck_saison_libelle_format
        CHECK (libelle_saison REGEXP '^[0-9]{4}-[0-9]{4}$'),
    -- D. Les deux années du libellé sont consécutives.
    ADD CONSTRAINT ck_saison_annees_consecutives
        CHECK (CAST(RIGHT(libelle_saison, 4) AS UNSIGNED)
             = CAST(LEFT(libelle_saison, 4) AS UNSIGNED) + 1),
    -- D. La saison commence pendant la première année de son libellé.
    ADD CONSTRAINT ck_saison_annee_debut
        CHECK (YEAR(date_debut_saison) = CAST(LEFT(libelle_saison, 4) AS UNSIGNED)),
    -- D. La date de fin est postérieure à la date de début.
    ADD CONSTRAINT ck_saison_dates
        CHECK (date_fin_saison > date_debut_saison);

-- ---------------------------------------------------------------------
-- Journee
-- ---------------------------------------------------------------------
ALTER TABLE Journee
    -- B. Les journées sont numérotées à partir de 1. Avec au plus 20 clubs,
    --    une saison compte au plus 2 x (20 - 1) = 38 journées.
    ADD CONSTRAINT ck_journee_numero
        CHECK (numero_journée BETWEEN 1 AND 38);

-- ---------------------------------------------------------------------
-- Stade
-- ---------------------------------------------------------------------
ALTER TABLE Stade
    -- A. Le code est formé de 3 lettres majuscules et 3 chiffres (ex. PAR001).
    ADD CONSTRAINT ck_stade_code_format
        CHECK (REGEXP_LIKE(code_stade, '^[A-Z]{3}[0-9]{3}$', 'c')),
    -- B. La capacité est un nombre de places positif, sur 6 chiffres au plus.
    ADD CONSTRAINT ck_stade_capacite
        CHECK (capacite_stade BETWEEN 1 AND 999999),
    -- A. La ville ne contient que des lettres, espaces, tirets et apostrophes.
    ADD CONSTRAINT ck_stade_ville_format
        CHECK (ville_stade REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$');

-- ---------------------------------------------------------------------
-- Club
-- ---------------------------------------------------------------------
ALTER TABLE Club
    -- B. Le numéro d'affiliation compte au plus 6 chiffres.
    ADD CONSTRAINT ck_club_affiliation
        CHECK (numero_affiliation BETWEEN 1 AND 999999),
    -- B. Année de fondation plausible (le plus ancien club, Sheffield FC,
    --    date de 1857).
    ADD CONSTRAINT ck_club_annee_fondation
        CHECK (annee_fondation >= 1857),
    -- A. Le nom du club n'est pas vide.
    ADD CONSTRAINT ck_club_nom_non_vide
        CHECK (TRIM(nom_club) <> ''),
    -- E. Deux clubs ne peuvent pas porter le même nom.
    ADD CONSTRAINT uq_club_nom UNIQUE (nom_club);

-- ---------------------------------------------------------------------
-- Joueur, Entraineur, Arbitre
-- ---------------------------------------------------------------------
ALTER TABLE Joueur
    -- B. Le numéro de licence compte exactement 10 chiffres.
    ADD CONSTRAINT ck_joueur_licence
        CHECK (numero_licence_joueur BETWEEN 1000000000 AND 9999999999),
    -- A. Nom, prénom et nationalité : lettres, espaces, tirets, apostrophes.
    ADD CONSTRAINT ck_joueur_nom_format
        CHECK (nom_joueur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    ADD CONSTRAINT ck_joueur_prenom_format
        CHECK (prenom_joueur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    ADD CONSTRAINT ck_joueur_nationalite_format
        CHECK (nationalite_joueur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    -- C. Le poste fait partie des quatre postes du football.
    ADD CONSTRAINT ck_joueur_poste
        CHECK (poste_joueur IN ('gardien', 'défenseur', 'milieu', 'attaquant'));

ALTER TABLE Entraineur
    ADD CONSTRAINT ck_entraineur_licence
        CHECK (numero_licence_entraineur BETWEEN 1000000000 AND 9999999999),
    ADD CONSTRAINT ck_entraineur_nom_format
        CHECK (nom_entraineur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    ADD CONSTRAINT ck_entraineur_prenom_format
        CHECK (prénom_entraineur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    ADD CONSTRAINT ck_entraineur_nationalite_format
        CHECK (nationalite_entraineur REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$');

ALTER TABLE Arbitre
    ADD CONSTRAINT ck_arbitre_licence
        CHECK (numero_licence_arbitre BETWEEN 1000000000 AND 9999999999),
    ADD CONSTRAINT ck_arbitre_nom_format
        CHECK (nom_arbitre REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    ADD CONSTRAINT ck_arbitre_prenom_format
        CHECK (prenom_arbitre REGEXP '^[[:alpha:]]+([ \'-][[:alpha:]]+)*$'),
    -- C. Catégories d'arbitres retenues.
    ADD CONSTRAINT ck_arbitre_categorie
        CHECK (categorie_arbitre IN ('International', 'Fédéral 1', 'Fédéral 2'));

-- ---------------------------------------------------------------------
-- APPARTENIR (effectifs)
-- ---------------------------------------------------------------------
ALTER TABLE APPARTENIR
    -- B. Le numéro de maillot est compris entre 1 et 99.
    ADD CONSTRAINT ck_appartenir_maillot
        CHECK (numero_maillot BETWEEN 1 AND 99),
    -- E. Deux joueurs d'un même club ne portent pas le même numéro
    --    au cours d'une même saison.
    ADD CONSTRAINT uq_appartenir_maillot
        UNIQUE (numero_affiliation, libelle_saison, numero_maillot);

-- ---------------------------------------------------------------------
-- Match_
-- ---------------------------------------------------------------------
ALTER TABLE Match_
    -- B. Le numéro de match compte au plus 6 chiffres.
    ADD CONSTRAINT ck_match_numero
        CHECK (numero_match BETWEEN 1 AND 999999),
    -- C. Statut du match.
    ADD CONSTRAINT ck_match_statut
        CHECK (statut_match IN ('programmé', 'joué', 'reporté')),
    -- B. Coup d'envoi entre 12h00 et 22h00.
    ADD CONSTRAINT ck_match_heure
        CHECK (heure_coup_envoi BETWEEN '12:00:00' AND '22:00:00'),
    -- E. Au cours d'une saison, un club ne reçoit qu'une fois un même
    --    adversaire (match aller et match retour chacun une seule fois).
    ADD CONSTRAINT uq_match_affiche
        UNIQUE (libelle_saison, numero_affiliation_Domicile, numero_affiliation_extérieur);

-- F. Un match nouvellement créé est programmé par défaut.
ALTER TABLE Match_
    ALTER COLUMN statut_match SET DEFAULT 'programmé';

-- ---------------------------------------------------------------------
-- But et Carton
-- ---------------------------------------------------------------------
ALTER TABLE But
    -- B. Numéro d'ordre à partir de 1, minute entre 1 et 130
    --    (prolongations et temps additionnel compris).
    ADD CONSTRAINT ck_but_ordre
        CHECK (numero_ordre_but >= 1),
    ADD CONSTRAINT ck_but_minute
        CHECK (minute_but BETWEEN 1 AND 130),
    -- C. Type de but.
    ADD CONSTRAINT ck_but_type
        CHECK (type_but IN ('jeu', 'penalty', 'contre son camp'));

ALTER TABLE Carton
    ADD CONSTRAINT ck_carton_ordre
        CHECK (numero_ordre_carton >= 1),
    ADD CONSTRAINT ck_carton_minute
        CHECK (minute_carton BETWEEN 1 AND 130),
    -- C. Couleur du carton.
    ADD CONSTRAINT ck_carton_couleur
        CHECK (couleur_carton IN ('jaune', 'rouge'));

-- =====================================================================
-- G. Règles portant sur plusieurs tables : procédures et triggers
-- Chaque procédure lève une erreur (SIGNAL) si la règle n'est pas
-- respectée. Elle est appelée avant chaque INSERT et UPDATE.
-- =====================================================================

DROP PROCEDURE IF EXISTS verifier_club;
DROP PROCEDURE IF EXISTS verifier_match;
DROP PROCEDURE IF EXISTS verifier_evenement;

DELIMITER //

-- Cardinalité 1,1 de RESIDER : un club a toujours un stade de résidence.
-- (La colonne est nullable pour permettre ON DELETE SET NULL.)
CREATE PROCEDURE verifier_club(IN p_code_stade CHAR(6))
BEGIN
    IF p_code_stade IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un club doit avoir un stade de résidence.';
    END IF;
END //

CREATE PROCEDURE verifier_match(
    IN p_numero_match   INT,
    IN p_saison         CHAR(9),
    IN p_journee        TINYINT,
    IN p_domicile       INT,
    IN p_exterieur       INT,
    IN p_stade          CHAR(6),
    IN p_arbitre        BIGINT,
    IN p_date_match     DATE
)
BEGIN
    -- Cardinalités 1,1 d'ACCUEILLIR et ARBITRER.
    IF p_stade IS NULL OR p_arbitre IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un match doit avoir un stade et un arbitre.';
    END IF;

    -- Un match oppose deux clubs différents.
    IF p_domicile = p_exterieur THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Le club qui reçoit et le club visiteur doivent être différents.';
    END IF;

    -- Les deux clubs participent à la saison du match.
    IF (SELECT COUNT(*) FROM PARTICIPER
        WHERE libelle_saison = p_saison
          AND numero_affiliation IN (p_domicile, p_exterieur)) < 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Les deux clubs doivent participer à la saison du match.';
    END IF;

    -- La date du match est comprise dans la saison.
    IF NOT EXISTS (SELECT 1 FROM SAISON
                   WHERE libelle_saison = p_saison
                     AND p_date_match BETWEEN date_debut_saison AND date_fin_saison) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La date du match doit être comprise dans la saison.';
    END IF;

    -- Lors d'une journée, chaque club dispute un seul match.
    IF EXISTS (SELECT 1 FROM Match_
               WHERE libelle_saison = p_saison
                 AND numero_journée = p_journee
                 AND numero_match <> p_numero_match
                 AND (numero_affiliation_Domicile IN (p_domicile, p_exterieur)
                   OR numero_affiliation_extérieur IN (p_domicile, p_exterieur))) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un club ne peut disputer qu''un seul match par journée.';
    END IF;
END //

-- Règles communes aux buts et aux cartons.
CREATE PROCEDURE verifier_evenement(IN p_numero_match INT, IN p_joueur BIGINT)
BEGIN
    -- Un but ou un carton n'existe que pour un match joué.
    IF NOT EXISTS (SELECT 1 FROM Match_
                   WHERE numero_match = p_numero_match
                     AND statut_match = 'joué') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Un but ou un carton ne peut concerner qu''un match joué.';
    END IF;

    -- Le joueur appartient, pour la saison du match, à l'effectif de
    -- l'un des deux clubs du match.
    IF NOT EXISTS (SELECT 1
                   FROM Match_ R
                   JOIN APPARTENIR A ON A.libelle_saison = R.libelle_saison
                   WHERE R.numero_match = p_numero_match
                     AND A.numero_licence_joueur = p_joueur
                     AND A.numero_affiliation IN (R.numero_affiliation_Domicile,
                                                  R.numero_affiliation_extérieur)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Le joueur doit appartenir à l''un des deux clubs du match pour cette saison.';
    END IF;
END //

CREATE TRIGGER trg_club_bi BEFORE INSERT ON Club
FOR EACH ROW CALL verifier_club(NEW.code_stade) //

CREATE TRIGGER trg_club_bu BEFORE UPDATE ON Club
FOR EACH ROW CALL verifier_club(NEW.code_stade) //

CREATE TRIGGER trg_match_bi BEFORE INSERT ON Match_
FOR EACH ROW CALL verifier_match(
    NEW.numero_match, NEW.libelle_saison, NEW.numero_journée,
    NEW.numero_affiliation_Domicile, NEW.numero_affiliation_extérieur,
    NEW.code_stade, NEW.numero_licence_arbitre, NEW.date_match) //

CREATE TRIGGER trg_match_bu BEFORE UPDATE ON Match_
FOR EACH ROW CALL verifier_match(
    NEW.numero_match, NEW.libelle_saison, NEW.numero_journée,
    NEW.numero_affiliation_Domicile, NEW.numero_affiliation_extérieur,
    NEW.code_stade, NEW.numero_licence_arbitre, NEW.date_match) //

CREATE TRIGGER trg_but_bi BEFORE INSERT ON But
FOR EACH ROW CALL verifier_evenement(NEW.numero_match, NEW.numero_licence_joueur) //

CREATE TRIGGER trg_but_bu BEFORE UPDATE ON But
FOR EACH ROW CALL verifier_evenement(NEW.numero_match, NEW.numero_licence_joueur) //

CREATE TRIGGER trg_carton_bi BEFORE INSERT ON Carton
FOR EACH ROW CALL verifier_evenement(NEW.numero_match, NEW.numero_licence_joueur) //

CREATE TRIGGER trg_carton_bu BEFORE UPDATE ON Carton
FOR EACH ROW CALL verifier_evenement(NEW.numero_match, NEW.numero_licence_joueur) //

DELIMITER ;

-- ---------------------------------------------------------------------
-- Règles non vérifiées automatiquement (contrôlées par requête) :
--   - deux clubs se rencontrent exactement deux fois par saison :
--     la contrainte uq_match_affiche garantit « au plus une fois
--     dans chaque sens », le « exactement » se vérifie une fois le
--     calendrier complet ;
--   - chaque club participant a un entraîneur principal : la règle ne
--     peut être vérifiée qu'une fois les données de la saison saisies.
-- ---------------------------------------------------------------------
