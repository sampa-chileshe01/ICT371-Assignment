-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 6: University Event Seat Booking
-- Student Number: 202407247

-- Clean start (lets you re-run the script safely)
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS events;

-- =====================================================
-- 1. TABLES AND SAMPLE DATA
-- =====================================================
CREATE TABLE events (
    event_id        SERIAL PRIMARY KEY,
    event_name      VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id     SERIAL PRIMARY KEY,
    event_id       INT NOT NULL REFERENCES events(event_id),
    student_number VARCHAR(20) NOT NULL,
    num_seats      INT NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
);

INSERT INTO events (event_name, available_seats) VALUES
    ('Freshers Welcome Gala', 200),
    ('Career Fair', 8),
    ('Graduation Rehearsal', 0);

SELECT * FROM events;

-- =====================================================
-- 2. IF / ELSIF / ELSE  (seat status of one event)
-- =====================================================
DO $$
DECLARE
    v_name  VARCHAR(100);
    v_seats INT;
BEGIN
    SELECT event_name, available_seats INTO v_name, v_seats
    FROM events WHERE event_id = 2;

    IF v_seats = 0 THEN
        RAISE NOTICE '% is FULL (0 seats).', v_name;
    ELSIF v_seats <= 10 THEN
        RAISE NOTICE '% is NEARLY FULL (% seats left).', v_name, v_seats;
    ELSE
        RAISE NOTICE '% has PLENTY of seats (%).', v_name, v_seats;
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
        RAISE NOTICE 'Booking reminder day: %', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number: %', check_no;
    END LOOP;
END $$;

-- =====================================================
-- 4. book_seats PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id       INT,
    p_student_number VARCHAR,
    p_seats          INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_seats IS NULL OR p_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid number of seats: %. Seats must be greater than zero.', p_seats;
    END IF;

    SELECT available_seats INTO v_available
    FROM events WHERE event_id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event % does not exist.', p_event_id;
    END IF;

    IF v_available < p_seats THEN
        RAISE NOTICE 'Booking REJECTED for student %: requested %, only % seat(s) left.',
                     p_student_number, p_seats, v_available;
        RETURN;
    END IF;

    UPDATE events
    SET available_seats = available_seats - p_seats
    WHERE event_id = p_event_id;

    INSERT INTO bookings (event_id, student_number, num_seats, status)
    VALUES (p_event_id, p_student_number, p_seats, 'BOOKED');

    RAISE NOTICE 'Booking RECORDED for student %: % seat(s) for event %.',
                 p_student_number, p_seats, p_event_id;
END;
$$;

-- =====================================================
-- 5. CALL book_seats: two valid, one too large
-- =====================================================
CALL book_seats(1, '202407247', 4);    -- valid
CALL book_seats(2, '202400001', 3);    -- valid
CALL book_seats(2, '202400002', 20);   -- exceeds remaining seats

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- =====================================================
-- 6. cancel_booking PROCEDURE
-- =====================================================
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id INT;
    v_seats    INT;
    v_status   VARCHAR(20);
BEGIN
    SELECT event_id, num_seats, status INTO v_event_id, v_seats, v_status
    FROM bookings WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % does not exist.', p_booking_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % was already cancelled. No seats released.', p_booking_id;
        RETURN;
    END IF;

    UPDATE events
    SET available_seats = available_seats + v_seats
    WHERE event_id = v_event_id;

    UPDATE bookings
    SET status = 'CANCELLED'
    WHERE booking_id = p_booking_id;

    RAISE NOTICE 'Booking % cancelled. % seat(s) released.', p_booking_id, v_seats;
END;
$$;

-- Call it twice for the same booking (second call must not release again)
CALL cancel_booking(1);
CALL cancel_booking(1);

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- =====================================================
-- 7. EXPLICIT CURSOR: full or nearly full events
-- =====================================================
DO $$
DECLARE
    cur_events CURSOR FOR
        SELECT event_name, available_seats
        FROM events
        WHERE available_seats <= 10
        ORDER BY available_seats;
    rec RECORD;
BEGIN
    OPEN cur_events;
    LOOP
        FETCH cur_events INTO rec;
        EXIT WHEN NOT FOUND;
        IF rec.available_seats = 0 THEN
            RAISE NOTICE 'FULL: %', rec.event_name;
        ELSE
            RAISE NOTICE 'NEARLY FULL: % (% seats left)', rec.event_name, rec.available_seats;
        END IF;
    END LOOP;
    CLOSE cur_events;
END $$;

-- =====================================================
-- 8. EXCEPTION BLOCK: booking zero seats
-- =====================================================
DO $$
BEGIN
    CALL book_seats(1, '202407247', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- =====================================================
-- 9. FINAL RESULTS
-- =====================================================
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;