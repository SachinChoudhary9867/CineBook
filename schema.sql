-- CineBook database setup
-- Run with:  mysql -u root -p < schema.sql
-- WARNING: running this again deletes the old cinebook database and all its data.
-- NOTE: movie details, ratings, durations, prices and show times are SAMPLE DATA
-- for the college project (not confirmed real-world information).

-- DDL: DROP removes the old database so this script can be re-run
DROP DATABASE IF EXISTS cinebook;
CREATE DATABASE cinebook;
USE cinebook;

-- =====================================================
-- DDL: CREATE TABLE (PRIMARY KEY, FOREIGN KEY, UNIQUE, NOT NULL, DEFAULT)
-- =====================================================

-- Users: people who register on the website
CREATE TABLE Users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(50)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,      -- no two users can share an email
    password_hash VARCHAR(255) NOT NULL,             -- hashed password, never plain text
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Movies: list of movies
CREATE TABLE Movies (
    movie_id INT AUTO_INCREMENT PRIMARY KEY,
    title    VARCHAR(100) NOT NULL,
    genre    VARCHAR(30)  NOT NULL,
    language VARCHAR(30)  NOT NULL,
    rating   DECIMAL(3,1) DEFAULT 0.0
);

-- Theatres: places where movies are shown
CREATE TABLE Theatres (
    theatre_id INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    city       VARCHAR(50) NOT NULL DEFAULT 'Nanded'
);

-- Shows: one movie, in one theatre, at one time, for one price
CREATE TABLE Shows (
    show_id    INT AUTO_INCREMENT PRIMARY KEY,
    movie_id   INT NOT NULL,
    theatre_id INT NOT NULL,
    show_time  DATETIME NOT NULL,
    price      DECIMAL(8,2) NOT NULL,
    FOREIGN KEY (movie_id)   REFERENCES Movies(movie_id),
    FOREIGN KEY (theatre_id) REFERENCES Theatres(theatre_id)
);

-- Bookings: which user booked which show
CREATE TABLE Bookings (
    booking_id   INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT NOT NULL,
    show_id      INT NOT NULL,
    tickets      INT NOT NULL DEFAULT 1,
    total_price  DECIMAL(10,2) NOT NULL,             -- price x tickets
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (show_id) REFERENCES Shows(show_id)
);

-- =====================================================
-- DDL: ALTER TABLE - add a duration column to Movies
-- =====================================================
ALTER TABLE Movies ADD duration_minutes INT DEFAULT 120;

-- =====================================================
-- DML: INSERT - exactly 5 movies and 1 theatre (sample data)
-- =====================================================
INSERT INTO Movies (title, genre, language, rating, duration_minutes) VALUES
('Ramayan',              'Mythology',     'Hindi',   8.0, 140),
('Avengers: Doomsday',   'Action/Sci-Fi', 'English', 8.2, 150),
('Dhurandhar 2',         'Action/Thriller','Hindi',  7.8, 160),
('Varanasi',             'Adventure',     'Telugu',  7.5, 145);

-- duration_minutes not given here, so the DEFAULT value (120) is used
INSERT INTO Movies (title, genre, language, rating) VALUES
('Mahadevi Adishakti',   'Devotional',    'Hindi',   7.0);

INSERT INTO Theatres (name, city) VALUES ('Galaxy Cinema', 'Nanded');

-- Two sample shows for each movie, all in the one theatre
INSERT INTO Shows (movie_id, theatre_id, show_time, price) VALUES
(1, 1, '2026-11-10 10:00:00', 150),
(1, 1, '2026-11-10 18:30:00', 220),
(2, 1, '2026-11-11 11:00:00', 200),
(2, 1, '2026-11-11 20:00:00', 280),
(3, 1, '2026-11-12 14:00:00', 180),
(3, 1, '2026-11-12 21:00:00', 250),
(4, 1, '2026-11-13 12:00:00', 170),
(4, 1, '2026-11-13 19:30:00', 240),
(5, 1, '2026-11-14 10:30:00', 140),
(5, 1, '2026-11-14 17:00:00', 200);

-- =====================================================
-- DML: UPDATE - change existing data
-- =====================================================
UPDATE Movies SET duration_minutes = 135 WHERE title = 'Mahadevi Adishakti';

-- =====================================================
-- DML: DELETE - remove data (insert a test row, then delete it)
-- =====================================================
INSERT INTO Movies (title, genre, language) VALUES ('Test Movie', 'Test', 'English');
DELETE FROM Movies WHERE title = 'Test Movie';

-- =====================================================
-- VIEW: saved query used by the "My Bookings" section
-- =====================================================
CREATE VIEW BookingDetails AS
SELECT b.booking_id, b.user_id, m.title, t.name AS theatre,
       s.show_time, b.tickets, b.total_price, b.booking_date
FROM Bookings b
INNER JOIN Shows s    ON b.show_id    = s.show_id
INNER JOIN Movies m   ON s.movie_id   = m.movie_id
INNER JOIN Theatres t ON s.theatre_id = t.theatre_id;

-- =====================================================
-- INDEX: makes searching/sorting shows by time faster
-- =====================================================
CREATE INDEX idx_show_time ON Shows(show_time);

-- =====================================================
-- DEMO QUERIES FOR VIVA (these only read data)
-- =====================================================

-- DQL: SELECT all movies
SELECT * FROM Movies;

-- Aggregate functions on show prices
SELECT COUNT(*) AS total_shows, SUM(price) AS sum_price, AVG(price) AS avg_price,
       MIN(price) AS cheapest, MAX(price) AS costliest
FROM Shows;

-- GROUP BY + ORDER BY: number of shows per movie
SELECT movie_id, COUNT(*) AS shows_count
FROM Shows
GROUP BY movie_id
ORDER BY shows_count DESC;

-- INNER JOIN: movie, theatre and time together
SELECT m.title, t.name AS theatre, s.show_time, s.price
FROM Shows s
INNER JOIN Movies m   ON s.movie_id   = m.movie_id
INNER JOIN Theatres t ON s.theatre_id = t.theatre_id;

-- LEFT JOIN: every movie with its booking count (0 if nobody booked yet)
SELECT m.title, COUNT(b.booking_id) AS bookings
FROM Movies m
LEFT JOIN Shows s    ON s.movie_id = m.movie_id
LEFT JOIN Bookings b ON b.show_id  = s.show_id
GROUP BY m.movie_id, m.title;

-- Subquery: movies having a show priced above the average price
SELECT title FROM Movies
WHERE movie_id IN (SELECT movie_id FROM Shows
                   WHERE price > (SELECT AVG(price) FROM Shows));

-- View: query it like a normal table (empty until someone books)
SELECT * FROM BookingDetails;
