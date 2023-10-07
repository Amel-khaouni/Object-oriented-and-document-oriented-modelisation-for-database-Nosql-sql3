/*default_tbs  */
connect system

CREATE TABLESPACE SQL3_TBS DATAFILE 'C:\SQL3_TBS.dat' SIZE 100M AUTOEXTEND ON ONLINE;

CREATE TEMPORARY TABLESPACE SQL3_TempTBS TEMPFILE 'C:\SQL3_TempTBS.dat' SIZE 100M AUTOEXTEND ON;

CREATE USER SQL3 IDENTIFIED BY abc Default TABLESPACE SQL3_TBS temporary TABLESPACE SQL3_TempTBS;
GRANT ALL privileges to SQL3;

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

--creation des types incomplets
create type thotel;
/
create type treservation;
/
create type tclient;
/
create type tevaluation;
/
create type tchambre;
/
-- créer les types nécessaires aux associations 
create type t_set_ref_Reservation as table of ref treservation;
/
create type t_set_ref_Hotel as table of ref thotel;
/
create type t_set_ref_Client as table of ref tclient;
/
create type t_set_ref_Evaluation as table of ref tevaluation;
/
create type t_set_ref_Chambre as table of ref tchambre;
/
-- création des types
CREATE  or replace TYPE thotel AS  object (
    NumHotel INTEGER,
    NomHotel VARCHAR(50),
    ville VARCHAR(50),
    etoiles INTEGER,
    siteweb VARCHAR(100)
    
);
/

CREATE or replace TYPE tchambre AS  object(
    NumChambre INTEGER,
    NumHotel INTEGER,
    etage INTEGER,
    typechambre VARCHAR(10),
    prixnuit INTEGER
);
/

CREATE or replace TYPE tclient AS  object(
    NumClient INTEGER,
    NomClient VARCHAR(50),
    prenomclient VARCHAR(50),
    email VARCHAR(100)
);
/

CREATE or replace TYPE treservation AS  object(
    NumClient INTEGER,
    NumHotel INTEGER,
    datearrivee DATE,
    datedepart DATE,
    NumChambre INTEGER
);
/

CREATE or replace TYPE tevaluation AS  object (
    NumHotel INTEGER,
    NumClient INTEGER,
    dateevaluation DATE,
    note INTEGER
);
/

--les association
alter type treservation add attribute Reservation_Client ref tclient cascade;
alter type treservation add attribute Reservation_Chambre ref  tchambre cascade;
alter type treservation add attribute Reservation_Hotel ref  thotel cascade;

alter type tchambre add attribute Chambre_Hotel  ref thotel  cascade;
alter type tchambre add attribute Chambre_Reservation  t_set_ref_Reservation  cascade;


alter type TCLIENT add attribute Client_Reservation  t_set_ref_Reservation cascade;
alter type TCLIENT add attribute Client_Evaluation t_set_ref_Evaluation  cascade;
alter type TCLIENT add attribute Client_Hotel  t_set_ref_Hotel cascade;

alter type THOTEL add attribute Hotel_Chambre  t_set_ref_Chambre  cascade;
alter type THOTEL add attribute Hotel_Client  t_set_ref_Client cascade;
alter type THOTEL add attribute Hotel_Evaluation  t_set_ref_Evaluation  cascade;




alter type tevaluation add attribute Evaluation_Client ref tclient cascade;
alter type tevaluation add attribute Evaluation_Hotel ref thotel cascade;


-- création des tables
create table Hotel of thotel (primary key(numHotel))
nested table Hotel_Chambre store as table_Hotel_Chambre,
nested table Hotel_Client store as table_Hotel_Client,
nested table Hotel_Evaluation store as table_Hotel_Evaluation;


CREATE TABLE Chambre of tchambre (foreign key(Chambre_Hotel) references Hotel)
nested table Chambre_Reservation store as table_Chambre_Reservation;


CREATE TABLE Client of tclient (PRIMARY KEY (numClient))
nested table Client_Reservation store as table_Client_Reservation ,
nested table Client_Hotel store as table_Client_Hotel,
nested table Client_Evaluation store as table_Client_Evaluation;
    

CREATE TABLE Reservation of treservation (
    foreign key(Reservation_Client) references Client,
    foreign key(Reservation_Chambre) references Chambre ,
    FOREIGN KEY (Reservation_Hotel) REFERENCES Hotel
);
    

CREATE TABLE Evaluation of tevaluation (
    foreign key(Evaluation_Client) references Client,
    foreign key(Evaluation_Hotel) references Hotel, 
    CHECK (note >= 1 AND note <= 10)
);

-- définition des contraintes de type
ALTER TABLE Hotel ADD CONSTRAINT check_Hotel_etoiles CHECK (etoiles >= 1 AND etoiles <= 5);
ALTER TABLE Chambre ADD CONSTRAINT check_Chambre_typechambre CHECK (typechambre IN ('simple', 'double', 'triple', 'suite', 'autre'));
ALTER TABLE Chambre ADD CONSTRAINT check_Chambre_etage CHECK (etage >= 0);
ALTER TABLE Chambre ADD CONSTRAINT check_Chambre_prixnuit CHECK (prixnuit >= 0);
ALTER TABLE Reservation ADD CONSTRAINT check_Reservation_dates CHECK (datearrivee < datedepart);

--les methodes
alter type tclient add member function nb_reservations  return numeric cascade;
CREATE OR REPLACE TYPE BODY TCLIENT
AS MEMBER FUNCTION nb_Reservations RETURN numeric 
IS
nb_res number;
BEGIN
SELECT COUNT(*) INTO nb_res FROM RESERVATION R WHERE Numclient = self.Numclient;
RETURN nb_res;
END;
END;
/
alter type tchambre add member function get_chiffre_affaire  return numeric cascade;
CREATE OR REPLACE TYPE BODY TCHAMBRE AS
    MEMBER FUNCTION get_chiffre_affaire RETURN numeric IS
        chiffre_affaire INTEGER := 0;
    BEGIN
        SELECT SUM(( datearrivee - datedepart) * self.prixnuit) INTO chiffre_affaire
        FROM Reservation
        WHERE NumChambre = self.NumChambre;
        RETURN chiffre_affaire;
    END;
END;
/
alter type thotel add member function get_chiffre_affaire  return numeric cascade;
CREATE OR REPLACE TYPE BODY thotel AS
    MEMBER FUNCTION get_nb_Evaluations(date_Evaluation DATE) RETURN numeric IS
        nb_Evaluations INTEGER := 0;
    BEGIN
        SELECT COUNT(*) INTO nb_Evaluations
        FROM Evaluation
        WHERE NumHotel = self.NumHotel AND date = date_Evaluation;
        RETURN nb_Evaluations;
    END;
END;
/
--les select
/1
SELECT NomHotel, ville
FROM Hotel;

/2
SELECT DISTINCT H.NomHotel, H.ville
FROM Hotel H
JOIN Reservation R ON H.NumHotel = R.NumHotel;


/3
SELECT C.NomClient, C.prenomclient
FROM Client C
WHERE NOT EXISTS (
  SELECT *
  FROM Reservation R
  JOIN Chambre CH ON R.NumChambre = CH.NumChambre
  WHERE R.NumClient = C.NumClient
  AND CH.etage <> 1
);


/4
SELECT H.NomHotel, H.ville, C.prixnuit
FROM Hotel H
JOIN Chambre C ON H.NumHotel = C.NumHotel
WHERE C.typechambre = 'suite';


/5
SELECT H.NomHotel, H.ville, C.typechambre
FROM Hotel H
JOIN Chambre C ON H.NumHotel = C.NumHotel
JOIN Reservation R ON C.NumChambre = R.NumChambre
WHERE H.ville = 'Alger'
GROUP BY H.NumHotel, H.NomHotel, H.ville, C.typechambre
HAVING COUNT(R.NumChambre) = (
  SELECT MAX(CountNumChambre)
  FROM (
    SELECT COUNT(R.NumChambre) AS CountNumChambre
    FROM Hotel H
    JOIN Chambre C ON H.NumHotel = C.NumHotel
    JOIN Reservation R ON C.NumChambre = R.NumChambre
    WHERE H.ville = 'Alger'
    GROUP BY H.NumHotel, H.NomHotel, C.typechambre
  ) SubQuery
);


/6
SELECT H.NomHotel, H.ville
FROM Hotel H
JOIN Evaluation E ON H.NumHotel = E.NumHotel
WHERE EXTRACT(YEAR FROM E.dateevaluation) = 2022
GROUP BY H.NumHotel, H.NomHotel, H.ville
HAVING AVG(E.note) >= 6;

/7
SELECT *
FROM (
  SELECT H.NomHotel, H.ville, TotalRevenue
  FROM (
    SELECT H.NumHotel, SUM((R.datedepart - R.datearrivee) * C.prixnuit) AS TotalRevenue
    FROM Hotel H
    JOIN Chambre C ON H.NumHotel = C.NumHotel
    JOIN Reservation R ON C.NumChambre = R.NumChambre
    WHERE R.datearrivee >= DATE '2022-06-01' AND R.datedepart <= DATE '2022-08-31'
    GROUP BY H.NumHotel
    HAVING AVG(R.note) >= 6
  ) SubQuery
  JOIN Hotel H ON H.NumHotel = SubQuery.NumHotel
  ORDER BY TotalRevenue DESC
)
WHERE ROWNUM <= 1;

