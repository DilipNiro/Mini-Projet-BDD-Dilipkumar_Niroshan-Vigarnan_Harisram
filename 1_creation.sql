-- =====================================================================
-- Mini-projet BDD : championnat de football professionnel
-- 1_creation.sql : MPD (création des tables et contraintes d'intégrité)
-- SGBD : MySQL 8.0.16 ou plus récent
-- =====================================================================
-- Contraintes d'intégrité définies ici :
--   - clés primaires (PRIMARY KEY) ;
--   - clés étrangères (FOREIGN KEY) avec ON UPDATE / ON DELETE, pour que
--     la modification ou la suppression d'une ligne référencée soit
--     répercutée automatiquement, sans erreur ;
--   - NOT NULL pour les attributs obligatoires ;
--   - UNIQUE pour les CIF du MCD (DIRIGER : un entraîneur dirige au plus
--     un club par saison).
-- Les contraintes de validation (CHECK, règles métier) sont dans
-- 2_contraintes.sql.
--
-- Choix des actions référentielles :
--   - CASCADE lorsque la ligne fille n'a pas de sens sans la ligne mère
--     (une journée sans sa saison, un but sans son match...) ;
--   - SET NULL lorsque la ligne fille doit être conservée : supprimer un
--     stade ou un arbitre ne doit pas supprimer les clubs ni les matchs
--     qui y sont rattachés. Ces colonnes sont donc nullables, mais
--     2_contraintes.sql impose une valeur à l'insertion (cardinalité 1,1).
--
-- MATCH est un mot réservé en MySQL : l'entité MATCH du MCD devient la
-- table Match_.
-- =====================================================================

DROP DATABASE IF EXISTS ligue_football;
CREATE DATABASE ligue_football CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE ligue_football;

-- ---------------------------------------------------------------------
-- Tables sans clé étrangère
-- ---------------------------------------------------------------------

CREATE TABLE SAISON (
    libelle_saison      CHAR(9)      NOT NULL,
    date_debut_saison   DATE         NOT NULL,
    date_fin_saison     DATE         NOT NULL,
    CONSTRAINT pk_saison PRIMARY KEY (libelle_saison)
);

CREATE TABLE Stade (
    code_stade          CHAR(6)      NOT NULL,
    nom_stade           VARCHAR(50)  NOT NULL,
    ville_stade         VARCHAR(50)  NOT NULL,
    capacite_stade      INT          NOT NULL,
    CONSTRAINT pk_stade PRIMARY KEY (code_stade)
);

CREATE TABLE Joueur (
    numero_licence_joueur   BIGINT       NOT NULL,
    nom_joueur              VARCHAR(50)  NOT NULL,
    prenom_joueur           VARCHAR(50)  NOT NULL,
    date_naissance_joueur   DATE         NOT NULL,
    nationalite_joueur      VARCHAR(30)  NOT NULL,
    poste_joueur            VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_joueur PRIMARY KEY (numero_licence_joueur)
);

CREATE TABLE Entraineur (
    numero_licence_entraineur   BIGINT       NOT NULL,
    nom_entraineur              VARCHAR(50)  NOT NULL,
    prénom_entraineur           VARCHAR(50)  NOT NULL,
    nationalite_entraineur      VARCHAR(30)  NOT NULL,
    CONSTRAINT pk_entraineur PRIMARY KEY (numero_licence_entraineur)
);

CREATE TABLE Arbitre (
    numero_licence_arbitre  BIGINT       NOT NULL,
    nom_arbitre             VARCHAR(50)  NOT NULL,
    prenom_arbitre          VARCHAR(50)  NOT NULL,
    categorie_arbitre       VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_arbitre PRIMARY KEY (numero_licence_arbitre)
);

-- ---------------------------------------------------------------------
-- Tables avec clés étrangères
-- ---------------------------------------------------------------------

-- Entité faible : identifiée par sa saison et son numéro.
CREATE TABLE Journee (
    libelle_saison      CHAR(9)      NOT NULL,
    numero_journée      TINYINT      NOT NULL,
    CONSTRAINT pk_journee PRIMARY KEY (libelle_saison, numero_journée),
    CONSTRAINT fk_journee_saison FOREIGN KEY (libelle_saison)
        REFERENCES SAISON (libelle_saison)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Association RESIDER (Club 1,1 - Stade 0,N) : clé étrangère dans Club.
CREATE TABLE Club (
    numero_affiliation  INT          NOT NULL,
    nom_club            VARCHAR(50)  NOT NULL,
    annee_fondation     SMALLINT     NOT NULL,
    code_stade          CHAR(6)      NULL,
    CONSTRAINT pk_club PRIMARY KEY (numero_affiliation),
    CONSTRAINT fk_club_stade FOREIGN KEY (code_stade)
        REFERENCES Stade (code_stade)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Association PARTICIPER (Club 1,N - SAISON 1,N).
CREATE TABLE PARTICIPER (
    numero_affiliation  INT          NOT NULL,
    libelle_saison      CHAR(9)      NOT NULL,
    CONSTRAINT pk_participer PRIMARY KEY (numero_affiliation, libelle_saison),
    CONSTRAINT fk_participer_club FOREIGN KEY (numero_affiliation)
        REFERENCES Club (numero_affiliation)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_participer_saison FOREIGN KEY (libelle_saison)
        REFERENCES SAISON (libelle_saison)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Association ternaire APPARTENIR (Joueur - Club - SAISON).
-- CIF joueur + saison -> club : la clé primaire est (joueur, saison).
-- Le couple (club, saison) référence PARTICIPER : un club n'a un effectif
-- que pour une saison à laquelle il participe.
CREATE TABLE APPARTENIR (
    numero_licence_joueur   BIGINT       NOT NULL,
    libelle_saison          CHAR(9)      NOT NULL,
    numero_affiliation      INT          NOT NULL,
    numero_maillot          TINYINT      NOT NULL,
    CONSTRAINT pk_appartenir PRIMARY KEY (numero_licence_joueur, libelle_saison),
    CONSTRAINT fk_appartenir_joueur FOREIGN KEY (numero_licence_joueur)
        REFERENCES Joueur (numero_licence_joueur)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_appartenir_participer FOREIGN KEY (numero_affiliation, libelle_saison)
        REFERENCES PARTICIPER (numero_affiliation, libelle_saison)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Association ternaire DIRIGER (Entraineur - Club - SAISON).
-- CIF club + saison -> entraîneur : la clé primaire est (club, saison).
-- CIF entraîneur + saison -> club : contrainte UNIQUE.
CREATE TABLE DIRIGER (
    numero_affiliation          INT      NOT NULL,
    libelle_saison              CHAR(9)  NOT NULL,
    numero_licence_entraineur   BIGINT   NOT NULL,
    CONSTRAINT pk_diriger PRIMARY KEY (numero_affiliation, libelle_saison),
    CONSTRAINT uq_diriger_entraineur_saison UNIQUE (numero_licence_entraineur, libelle_saison),
    CONSTRAINT fk_diriger_entraineur FOREIGN KEY (numero_licence_entraineur)
        REFERENCES Entraineur (numero_licence_entraineur)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_diriger_participer FOREIGN KEY (numero_affiliation, libelle_saison)
        REFERENCES PARTICIPER (numero_affiliation, libelle_saison)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Entité MATCH du MCD. Associations PROGRAMMER, RECEVOIR, SE_DEPLACER,
-- ACCUEILLIR et ARBITRER (toutes 1,1 côté match) : clés étrangères ici.
CREATE TABLE Match_ (
    numero_match                    INT          NOT NULL,
    date_match                      DATE         NOT NULL,
    heure_coup_envoi                TIME         NOT NULL,
    statut_match                    VARCHAR(10)  NOT NULL,
    libelle_saison                  CHAR(9)      NOT NULL,
    numero_journée                  TINYINT      NOT NULL,
    numero_affiliation_Domicile     INT          NOT NULL,
    numero_affiliation_extérieur     INT          NOT NULL,
    code_stade                      CHAR(6)      NULL,
    numero_licence_arbitre          BIGINT       NULL,
    CONSTRAINT pk_match PRIMARY KEY (numero_match),
    CONSTRAINT fk_match_journee FOREIGN KEY (libelle_saison, numero_journée)
        REFERENCES Journee (libelle_saison, numero_journée)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_match_domicile FOREIGN KEY (numero_affiliation_Domicile)
        REFERENCES Club (numero_affiliation)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_match_exterieur FOREIGN KEY (numero_affiliation_extérieur)
        REFERENCES Club (numero_affiliation)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_match_stade FOREIGN KEY (code_stade)
        REFERENCES Stade (code_stade)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_match_arbitre FOREIGN KEY (numero_licence_arbitre)
        REFERENCES Arbitre (numero_licence_arbitre)
        ON UPDATE CASCADE ON DELETE SET NULL
);

-- Entité faible But : identifiée par son match et son numéro d'ordre.
-- Association MARQUER (But 1,1 - Joueur 0,N).
CREATE TABLE But (
    numero_match            INT          NOT NULL,
    numero_ordre_but        TINYINT      NOT NULL,
    minute_but              TINYINT UNSIGNED NOT NULL,
    type_but                VARCHAR(15)  NOT NULL,
    numero_licence_joueur   BIGINT       NOT NULL,
    CONSTRAINT pk_but PRIMARY KEY (numero_match, numero_ordre_but),
    CONSTRAINT fk_but_match FOREIGN KEY (numero_match)
        REFERENCES Match_ (numero_match)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_but_joueur FOREIGN KEY (numero_licence_joueur)
        REFERENCES Joueur (numero_licence_joueur)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- Entité faible Carton : identifiée par son match et son numéro d'ordre.
-- Association SANCTIONNER (Carton 1,1 - Joueur 0,N).
CREATE TABLE Carton (
    numero_match            INT          NOT NULL,
    numero_ordre_carton     TINYINT      NOT NULL,
    minute_carton           TINYINT UNSIGNED NOT NULL,
    couleur_carton          VARCHAR(5)   NOT NULL,
    numero_licence_joueur   BIGINT       NOT NULL,
    CONSTRAINT pk_carton PRIMARY KEY (numero_match, numero_ordre_carton),
    CONSTRAINT fk_carton_match FOREIGN KEY (numero_match)
        REFERENCES Match_ (numero_match)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_carton_joueur FOREIGN KEY (numero_licence_joueur)
        REFERENCES Joueur (numero_licence_joueur)
        ON UPDATE CASCADE ON DELETE CASCADE
);

SHOW TABLES;
