-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Student Number: 202407247

-- Clean start (lets you re-run the script safely)
DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

-- =====================================================
-- 1. TABLES AND SAMPLE DATA
-- =====================================================
CREATE TABLE books (
    book_id          SERIAL PRIMARY KEY,
    title            VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id        SERIAL PRIMARY KEY,
    book_id        INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL,
    loan_status    VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
);

INSERT INTO books (title, available_copies) VALUES
    ('Database System Concepts', 8),
    ('Operating Systems', 2),
    ('Computer Networks', 0);

SELECT * FROM books;

-- =====================================================
-- 2. IF / ELSIF / ELSE  (stock level of one book)
-- =====================================================
DO $$
DECLARE
    v_title  VARCHAR(100);
    v_copies INT;
BEGIN
    SELECT title, available_copies INTO v_title, v_copies
    FROM books WHERE book_id = 1;

    IF v_copies = 0 THEN
        RAISE NOTICE '% is UNAVAILABLE (0 copies).', v_title;
    ELSIF v_copies <= 3 THEN
        RAISE NOTICE '% is LOW on copies (% left).', v_title, v_copies;
    ELSE
        RAISE NOTICE '% is SUFFICIENTLY STOCKED (% copies).', v_title, v_copies;
    END IF;
END $$;

-- =====================================================
-- 3. WHILE loop and numeric FOR loop
-- =====================================================
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number: %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR shelf IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', shelf;
    END LOOP;
END $$;

-- =====================================================
-- 4. borrow_book PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id        INT,
    p_student_number VARCHAR,
    p_quantity       INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT available_copies INTO v_available
    FROM books WHERE book_id = p_book_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % does not exist.', p_book_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Loan REJECTED for student %: requested %, only % available.',
                     p_student_number, p_quantity, v_available;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans (book_id, student_number, quantity, loan_status)
    VALUES (p_book_id, p_student_number, p_quantity, 'BORROWED');

    RAISE NOTICE 'Loan RECORDED for student %: % copy/copies of book %.',
                 p_student_number, p_quantity, p_book_id;
END;
$$;

-- =====================================================
-- 5. CALL borrow_book: two valid loans, one too large
-- =====================================================
CALL borrow_book(1, '202407247', 2);   -- valid
CALL borrow_book(2, '202400001', 1);   -- valid
CALL borrow_book(2, '202400002', 5);   -- exceeds available copies

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- =====================================================
-- 6. return_book PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_qty     INT;
    v_status  VARCHAR(20);
BEGIN
    SELECT book_id, quantity, loan_status INTO v_book_id, v_qty, v_status
    FROM book_loans WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist.', p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % was already returned. No copies restored.', p_loan_id;
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + v_qty
    WHERE book_id = v_book_id;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Loan % returned. % copy/copies restored.', p_loan_id, v_qty;
END;
$$;

-- Call it twice for the same loan (second call must not restore copies)
CALL return_book(1);
CALL return_book(1);

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- =====================================================
-- 7. EXPLICIT CURSOR: books with few copies remaining
-- =====================================================
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT title, available_copies
        FROM books
        WHERE available_copies <= 3
        ORDER BY available_copies;
    rec RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low stock: % (% copies left)', rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur_low;
END $$;

-- =====================================================
-- 8. EXCEPTION BLOCK: borrowing zero copies
-- =====================================================
DO $$
BEGIN
    CALL borrow_book(1, '202407247', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- =====================================================
-- 9. FINAL RESULTS
-- =====================================================
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;