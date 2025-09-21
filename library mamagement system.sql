-- library management system
CREATE DATABASE IF NOT EXISTS library_management_system;
USE library_management_system;

-- main entity tables
-- library table
CREATE TABLE libraries(
library_id INT AUTO_INCREMENT,
library_name VARCHAR(100) NOT NULL,
address VARCHAR(255) NOT NULL,
phone VARCHAR(15),
email VARCHAR(100),
established_date DATE,
PRIMARY KEY (library_id),
UNIQUE (library_name)
);
-- staff table
CREATE TABLE staff(
staff_id INT PRIMARY KEY AUTO_INCREMENT,
library_id INT NOT NULL,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50) NOT NULL,
email VARCHAR(100) UNIQUE NOT NULL,
phone VARCHAR(15),
position ENUM('Librarian', 'Assistant', 'Manager', 'Clerk') NOT NULL,
hire_date DATE NOT NULL,
salary DECIMAL(10,2),
is_active BOOLEAN DEFAULT TRUE,
FOREIGN KEY (library_id) REFERENCES libraries(library_id) ON DELETE RESTRICT
);
-- Members table
CREATE TABLE members(
member_id INT PRIMARY KEY AUTO_INCREMENT,
library_id INT NOT NULL,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50) NOT NULL,
email VARCHAR(100) UNIQUE NOT NULL,
phone VARCHAR(15),
address VARCHAR(255),
date_of_birth DATE,
membership_date DATE NOT NULL DEFAULT (21/09/2025),
membership_type ENUM('Student', 'Adult', 'Senior', 'Child') NOT NULL DEFAULT 'Adult',
is_active BOOLEAN DEFAULT TRUE,
fine_balance DECIMAL(8,2) DEFAULT 0.00,
FOREIGN KEY (library_id) REFERENCES libraries(library_id) ON DELETE RESTRICT,
INDEX idx_member_email (email),
INDEX idx_member_name (last_name, first_name)
);
-- categories table
CREATE TABLE categories(
category_id INT PRIMARY KEY AUTO_INCREMENT,
category_name VARCHAR(50) UNIQUE NOT NULL,
description TEXT,
dewey_decimal_start VARCHAR(10),
dewey_decimal_end VARCHAR(10)
);
-- authors table
CREATE TABLE authors(
author_id INT PRIMARY KEY AUTO_INCREMENT,
first_name VARCHAR(50) NOT NULL,
last_name VARCHAR(50) NOT NULL,
date_of_birth DATE,
date_of_death DATE,
nationality VARCHAR(50),
biography TEXT,
INDEX idx_author_name (last_name, first_name)
);
-- books table
CREATE TABLE books(
book_id INT PRIMARY KEY AUTO_INCREMENT,
isbn VARCHAR(20) UNIQUE,
title VARCHAR(255) NOT NULL,
category_id INT,
publisher VARCHAR(100),
publication_year YEAR,
pages INT,
language VARCHAR(30) DEFAULT 'English',
summary TEXT,
created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL,
INDEX idx_book_title (title),
INDEX idx_book_isbn (isbn),
INDEX idx_book_year (publication_year)
);
-- book copies table
CREATE TABLE book_copies(
copy_id INT PRIMARY KEY AUTO_INCREMENT,
book_id INT NOT NULL,
library_id INT NOT NULL,
copy_number INT NOT NULL,
condition_status ENUM('New', 'Good', 'Fair', 'Poor', 'Damaged') DEFAULT 'Good',
location VARCHAR(50), -- Shelf location
acquisition_date DATE DEFAULT (CURDATE()),
price DECIMAL(8,2),
is_available BOOLEAN DEFAULT TRUE,
is_reference BOOLEAN DEFAULT FALSE, -- Reference books cannot be borrowed
FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
FOREIGN KEY (library_id) REFERENCES libraries(library_id) ON DELETE CASCADE,
UNIQUE KEY unique_copy (book_id, library_id, copy_number),
INDEX idx_availability (is_available),
INDEX idx_library_location (library_id, location)
);
-- RELATIONSHIP TABLES (Many-to-Many)
-- Book-Author relationship (Many-to-Many)
CREATE TABLE book_authors(
book_id INT,
author_id INT,
author_role ENUM('Primary Author', 'Co-Author', 'Editor', 'Translator') DEFAULT 'Primary Author',
PRIMARY KEY (book_id, author_id),
FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);
-- TRANSACTION TABLES
-- Current loans table
CREATE TABLE current_loans(
loan_id INT PRIMARY KEY AUTO_INCREMENT,
copy_id INT NOT NULL,
member_id INT NOT NULL,
staff_id INT NOT NULL,
loan_date DATE NOT NULL DEFAULT (CURDATE()),
due_date DATE NOT NULL,
renewal_count INT DEFAULT 0,
fine_amount DECIMAL(6,2) DEFAULT 0.00,
FOREIGN KEY (copy_id) REFERENCES book_copies(copy_id) ON DELETE CASCADE,
FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE RESTRICT,
INDEX idx_member_loans (member_id),
INDEX idx_due_date (due_date),
INDEX idx_loan_date (loan_date)
);
-- Loan history table (completed loans)
CREATE TABLE loan_history(
history_id INT PRIMARY KEY AUTO_INCREMENT,
copy_id INT NOT NULL,
member_id INT NOT NULL,
staff_id_loan INT NOT NULL,
staff_id_return INT,
loan_date DATE NOT NULL,
due_date DATE NOT NULL,
return_date DATE,
renewal_count INT DEFAULT 0,
fine_amount DECIMAL(6,2) DEFAULT 0.00,
condition_on_return ENUM('Good', 'Fair', 'Poor', 'Damaged'),
notes TEXT,
FOREIGN KEY (copy_id) REFERENCES book_copies(copy_id) ON DELETE CASCADE,
FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
FOREIGN KEY (staff_id_loan) REFERENCES staff(staff_id) ON DELETE RESTRICT,
FOREIGN KEY (staff_id_return) REFERENCES staff(staff_id) ON DELETE RESTRICT,
INDEX idx_history_member (member_id),
INDEX idx_history_dates (loan_date, return_date),
INDEX idx_history_book (copy_id)
);
-- Reservations table
CREATE TABLE reservations(
reservation_id INT PRIMARY KEY AUTO_INCREMENT,
book_id INT NOT NULL,
member_id INT NOT NULL,
library_id INT NOT NULL,
reservation_date DATE NOT NULL DEFAULT (CURDATE()),
expiry_date DATE NOT NULL,
status ENUM('Active', 'Fulfilled', 'Expired', 'Cancelled') DEFAULT 'Active',
notification_sent BOOLEAN DEFAULT FALSE,
FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
FOREIGN KEY (library_id) REFERENCES libraries(library_id) ON DELETE CASCADE,
INDEX idx_reservation_status (status),
INDEX idx_reservation_member (member_id),
INDEX idx_reservation_book (book_id)
);
-- CONSTRAINTS AND TRIGGERS
-- Add constraint to ensure due_date is after loan_date
ALTER TABLE current_loans 
ADD CONSTRAINT chk_loan_dates 
CHECK (due_date > loan_date);

ALTER TABLE loan_history 
ADD CONSTRAINT chk_history_dates 
CHECK (due_date > loan_date);

-- Add constraint to ensure return_date is not before loan_date
ALTER TABLE loan_history 
ADD CONSTRAINT chk_return_date 
CHECK (return_date IS NULL OR return_date >= loan_date);

-- Add constraint to ensure reservation expiry is after reservation date
ALTER TABLE reservations 
ADD CONSTRAINT chk_reservation_dates 
CHECK (expiry_date > reservation_date);

-- Add constraint to ensure fine amounts are non-negative
ALTER TABLE members 
ADD CONSTRAINT chk_fine_balance 
CHECK (fine_balance >= 0);

ALTER TABLE current_loans 
ADD CONSTRAINT chk_loan_fine 
CHECK (fine_amount >= 0);

ALTER TABLE loan_history 
ADD CONSTRAINT chk_history_fine 
CHECK (fine_amount >= 0);


-- Constraint to ensure pages are positive
ALTER TABLE books 
ADD CONSTRAINT chk_pages 
CHECK (pages > 0);

-- Constraint to ensure copy_number is positive
ALTER TABLE book_copies 
ADD CONSTRAINT chk_copy_number 
CHECK (copy_number > 0);

-- Constraint to ensure price is non-negative
ALTER TABLE book_copies 
ADD CONSTRAINT chk_price 
CHECK (price >= 0);

-- Constraint to ensure renewal count is non-negative
ALTER TABLE current_loans 
ADD CONSTRAINT chk_renewal_count 
CHECK (renewal_count >= 0);


-- Constraint to ensure salary is positive
ALTER TABLE staff 
ADD CONSTRAINT chk_salary 
CHECK (salary > 0);

-- Insert sample libraries
INSERT INTO libraries (library_name, address, phone, email, established_date) VALUES
('Central Public Library', '123 Main Street, Downtown', '555-0101', 'central@library.org', '1950-06-15'),
('North Branch Library', '456 Oak Avenue, Northside', '555-0102', 'north@library.org', '1975-09-20'),
('University Library', '789 Campus Drive, University District', '555-0103', 'university@library.org', '1960-03-10');

-- Insert sample staff
INSERT INTO staff (library_id, first_name, last_name, email, phone, position, hire_date, salary) VALUES
(1, 'Alice', 'Johnson', 'alice.johnson@library.org', '555-0201', 'Manager', '2015-01-15', 65000.00),
(1, 'Bob', 'Smith', 'bob.smith@library.org', '555-0202', 'Librarian', '2018-03-20', 45000.00),
(2, 'Carol', 'Brown', 'carol.brown@library.org', '555-0203', 'Librarian', '2019-07-10', 47000.00),
(3, 'David', 'Wilson', 'david.wilson@library.org', '555-0204', 'Assistant', '2020-09-01', 35000.00);

-- Insert sample members
INSERT INTO members (library_id, first_name, last_name, email, phone, address, date_of_birth, membership_date, membership_type) VALUES
(1, 'Emma', 'Davis', 'emma.davis@email.com', '555-0301', '321 Elm Street', '1985-04-12', CURDATE(), 'Adult'),
(1, 'James', 'Miller', 'james.miller@email.com', '555-0302', '654 Pine Road', '1992-11-08', CURDATE(), 'Adult'),
(2, 'Sarah', 'Garcia', 'sarah.garcia@email.com', '555-0303', '987 Maple Lane', '2000-02-25', CURDATE(), 'Student'),
(3, 'Michael', 'Taylor', 'michael.taylor@email.com', '555-0304', '147 Cedar Court', '1978-09-30', CURDATE(), 'Adult');

-- Insert sample categories
INSERT INTO categories (category_name, description, dewey_decimal_start, dewey_decimal_end) VALUES
('Fiction', 'Novels, short stories, and other fictional works', '800', '899'),
('Science', 'Natural sciences, mathematics, and technology', '500', '599'),
('History', 'Historical accounts and biographical works', '900', '999'),
('Computer Science', 'Programming, software engineering, and IT', '004', '006'),
('Philosophy', 'Philosophical works and ethics', '100', '199');

-- Insert sample authors
INSERT INTO authors (first_name, last_name, date_of_birth, nationality, biography) VALUES
('George', 'Orwell', '1903-06-25', 'British', 'English novelist and journalist known for Animal Farm and 1984'),
('Isaac', 'Asimov', '1920-01-02', 'American', 'Prolific science fiction writer and biochemist'),
('Agatha', 'Christie', '1890-09-15', 'British', 'Mystery novelist known for Hercule Poirot and Miss Marple'),
('Douglas', 'Crockford', '1955-12-15', 'American', 'Computer programmer known for JavaScript development');

-- Insert sample books
INSERT INTO books (isbn, title, category_id, publisher, publication_year, pages, summary) VALUES
('978-0-452-28423-4', '1984', 1, 'Penguin Classics', 1949, 328, 'Dystopian novel about totalitarian surveillance'),
('978-0-553-29337-0', 'Foundation', 2, 'Bantam Spectra', 1951, 244, 'Science fiction novel about psychohistory'),
('978-0-062-07348-6', 'Murder on the Orient Express', 1, 'Harper', 1934, 256, 'Mystery novel featuring Hercule Poirot'),
('978-0-596-51774-8', 'JavaScript: The Good Parts', 4, 'O\'Reilly Media', 2008, 172, 'Guide to JavaScript programming best practices');

-- Insert book-author relationships
INSERT INTO book_authors (book_id, author_id, author_role) VALUES
(1, 1, 'Primary Author'),
(2, 2, 'Primary Author'),
(3, 3, 'Primary Author'),
(4, 4, 'Primary Author');

-- Insert sample book copies
INSERT INTO book_copies (book_id, library_id, copy_number, condition_status, location, price) VALUES
(1, 1, 1, 'Good', 'A-1-001', 15.99),
(1, 1, 2, 'Good', 'A-1-002', 15.99),
(2, 1, 1, 'New', 'S-2-015', 18.50),
(3, 2, 1, 'Fair', 'M-1-101', 12.99),
(4, 3, 1, 'Good', 'CS-3-020', 39.99);

-- USEFUL VIEWS FOR COMMON QUERIES
-- View for available books with author information
CREATE VIEW available_books AS
SELECT 
    b.book_id,
    b.isbn,
    b.title,
    GROUP_CONCAT(CONCAT(a.first_name, ' ', a.last_name) SEPARATOR ', ') AS authors,
    c.category_name,
    b.publisher,
    b.publication_year,
    COUNT(bc.copy_id) AS total_copies,
    SUM(bc.is_available) AS available_copies,
    l.library_name
FROM books b
LEFT JOIN book_authors ba ON b.book_id = ba.book_id
LEFT JOIN authors a ON ba.author_id = a.author_id
LEFT JOIN categories c ON b.category_id = c.category_id
LEFT JOIN book_copies bc ON b.book_id = bc.book_id
LEFT JOIN libraries l ON bc.library_id = l.library_id
GROUP BY b.book_id, l.library_id
HAVING available_copies > 0;


-- View for member loan summary
CREATE VIEW member_loan_summary AS
SELECT 
    m.member_id,
    CONCAT(m.first_name, ' ', m.last_name) AS member_name,
    m.email,
    COUNT(cl.loan_id) AS current_loans,
    m.fine_balance,
    m.membership_type,
    l.library_name
FROM members m
LEFT JOIN current_loans cl ON m.member_id = cl.member_id
JOIN libraries l ON m.library_id = l.library_id
WHERE m.is_active = TRUE
GROUP BY m.member_id;
-- End of database schema



