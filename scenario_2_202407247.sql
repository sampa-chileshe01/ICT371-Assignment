-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 2: Computer Laboratory Reservations
-- Student Number: 202407247

-- Clean start (lets you re-run the script safely)
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

-- =====================================================
-- 1. TABLES AND SAMPLE DATA
-- =====================================================
CREATE TABLE lab_sessions (
    session_id              SERIAL PRIMARY KEY,
    session_name            VARCHAR(100) NOT NULL,
    available_workstations  INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id   SERIAL PRIMARY KEY,
    session_id       INT NOT NULL REFERENCES lab_sessions(session_id),
    lecturer         VARCHAR(100) NOT NULL,
    num_workstations INT NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'RESERVED'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
    ('Monday 08:00 - Database Lab', 30),
    ('Tuesday 10:00 - Networking Lab', 4),
    ('Wednesday 14:00 - Programming Lab', 0);

SELECT * FROM lab_sessions;

-- =====================================================
-- 2. IF / ELSIF / ELSE  (capacity status of one session)
-- =====================================================
DO $$
DECLARE
    v_name  VARCHAR(100);
    v_avail INT;
BEGIN
    SELECT session_name, available_workstations INTO v_name, v_avail
    FROM lab_sessions WHERE session_id = 2;

    IF v_avail = 0 THEN
        RAISE NOTICE '% is FULL (0 workstations).', v_name;
    ELSIF v_avail <= 5 THEN
        RAISE NOTICE '% is NEARLY FULL (% workstations left).', v_name, v_avail;
    ELSE
        RAISE NOTICE '% has ENOUGH workstations (%).', v_name, v_avail;
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
        RAISE NOTICE 'Session preparation reminder number: %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number: %', check_no;
    END LOOP;
END $$;

-- =====================================================
-- 4. reserve_workstations PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer   VARCHAR,
    p_quantity   INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Workstations must be greater than zero.', p_quantity;
    END IF;

    SELECT available_workstations INTO v_available
    FROM lab_sessions WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session % does not exist.', p_session_id;
    END IF;

    IF v_available < p_quantity THEN
        RAISE NOTICE 'Reservation REJECTED for %: requested %, only % available.',
                     p_lecturer, p_quantity, v_available;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations - p_quantity
    WHERE session_id = p_session_id;

    INSERT INTO reservations (session_id, lecturer, num_workstations, status)
    VALUES (p_session_id, p_lecturer, p_quantity, 'RESERVED');

    RAISE NOTICE 'Reservation RECORDED for %: % workstation(s) in session %.',
                 p_lecturer, p_quantity, p_session_id;
END;
$$;

-- =====================================================
-- 5. CALL reserve_workstations: two valid, one too large
-- =====================================================
CALL reserve_workstations(1, 'Dr. Banda', 10);    -- valid
CALL reserve_workstations(2, 'Mr. Phiri', 2);     -- valid
CALL reserve_workstations(2, 'Ms. Mwansa', 10);   -- exceeds capacity

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- =====================================================
-- 6. cancel_reservation PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id INT;
    v_qty        INT;
    v_status     VARCHAR(20);
BEGIN
    SELECT session_id, num_workstations, status INTO v_session_id, v_qty, v_status
    FROM reservations WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % does not exist.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % was already cancelled. No workstations released.', p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations = available_workstations + v_qty
    WHERE session_id = v_session_id;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation % cancelled. % workstation(s) released.', p_reservation_id, v_qty;
END;
$$;

-- Call it twice for the same reservation (second call must not release again)
CALL cancel_reservation(1);
CALL cancel_reservation(1);

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- =====================================================
-- 7. EXPLICIT CURSOR: sessions with few workstations left
-- =====================================================
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5
        ORDER BY available_workstations;
    rec RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations left: % (% available)',
                     rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE cur_low;
END $$;

-- =====================================================
-- 8. EXCEPTION BLOCK: requesting zero workstations
-- =====================================================
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Banda', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- =====================================================
-- 9. FINAL RESULTS
-- =====================================================
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;