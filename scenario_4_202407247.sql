-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Student Number: 202407247

-- Clean start (lets you re-run the script safely)
DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

-- =====================================================
-- 1. TABLES AND SAMPLE DATA
-- =====================================================
CREATE TABLE medicines (
    medicine_id    SERIAL PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol 500mg', 200),
    ('Amoxicillin 250mg', 8),
    ('Oral Rehydration Salts', 0);

SELECT * FROM medicines;

-- =====================================================
-- 2. IF / ELSIF / ELSE  (stock level of one medicine)
-- =====================================================
DO $$
DECLARE
    v_name  VARCHAR(100);
    v_stock INT;
BEGIN
    SELECT medicine_name, stock_quantity INTO v_name, v_stock
    FROM medicines WHERE medicine_id = 2;

    IF v_stock = 0 THEN
        RAISE NOTICe '% is OUT OF STOCK.', v_name;
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE '% is LOW on stock (% units left).', v_name, v_stock;
    ELSE
        RAISE NOTICE '% is SUFFICIENTLY STOCKED (% units).', v_name, v_stock;
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
        RAISE NOTICE 'Stock review day: %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR shelf IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number: %', shelf;
    END LOOP;
END $$;

-- =====================================================
-- 4. dispense_medicine PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id    INT,
    p_student_number VARCHAR,
    p_quantity       INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than zero.', p_quantity;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine % does not exist.', p_medicine_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE NOTICE 'Dispensing REJECTED for student %: requested %, only % in stock.',
                     p_student_number, p_quantity, v_stock;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;

    INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
    VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

    RAISE NOTICE 'Dispensing RECORDED for student %: % unit(s) of medicine %.',
                 p_student_number, p_quantity, p_medicine_id;
END;
$$;

-- =====================================================
-- 5. CALL dispense_medicine: two valid, one too large
-- =====================================================
CALL dispense_medicine(1, '202407247', 20);   -- valid
CALL dispense_medicine(2, '202400001', 3);    -- valid
CALL dispense_medicine(2, '202400002', 50);   -- exceeds stock

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- =====================================================
-- 6. reverse_dispensing PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INT;
    v_qty         INT;
    v_status      VARCHAR(20);
BEGIN
    SELECT medicine_id, quantity, status INTO v_medicine_id, v_qty, v_status
    FROM dispensing_records WHERE record_id = p_record_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist.', p_record_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % was already reversed. No stock restored.', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines
    SET stock_quantity = stock_quantity + v_qty
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records
    SET status = 'REVERSED'
    WHERE record_id = p_record_id;

    RAISE NOTICE 'Record % reversed. % unit(s) restored to stock.', p_record_id, v_qty;
END;
$$;

-- Call it twice for the same record (stock restored only once)
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- =====================================================
-- 7. EXPLICIT CURSOR: medicines below a low-stock threshold
-- =====================================================
DO $$
DECLARE
    v_threshold INT := 10;
    cur_low CURSOR (p_threshold INT) FOR
        SELECT medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < p_threshold
        ORDER BY stock_quantity;
    rec RECORD;
BEGIN
    OPEN cur_low(v_threshold);
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below threshold (%): % (% units left)',
                     v_threshold, rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_low;
END $$;

-- =====================================================
-- 8. EXCEPTION BLOCK: negative dispensing quantity
-- =====================================================
DO $$
BEGIN
    CALL dispense_medicine(1, '202407247', -5);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- =====================================================
-- 9. FINAL RESULTS
-- =====================================================
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;