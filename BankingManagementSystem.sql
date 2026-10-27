SET SERVEROUTPUT ON;

-- ==========================================
-- BANKING MANAGEMENT SYSTEM USING PL/SQL
-- ==========================================

-- 1. DROP EXISTING TABLES (FOR RESETTING)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE transactions CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE accounts CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE customers CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 2. DROP EXISTING SEQUENCES
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE customer_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE account_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE transaction_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- 3. CREATE TABLES

CREATE TABLE customers (
    customer_id NUMBER PRIMARY KEY,
    full_name VARCHAR2(100) NOT NULL,
    phone VARCHAR2(15),
    email VARCHAR2(100),
    address VARCHAR2(200)
);

CREATE TABLE accounts (
    account_id NUMBER PRIMARY KEY,
    customer_id NUMBER REFERENCES customers(customer_id),
    account_type VARCHAR2(20) NOT NULL,
    balance NUMBER(12,2) DEFAULT 0 NOT NULL,
    opening_date DATE DEFAULT SYSDATE,
    CONSTRAINT chk_balance CHECK (balance >= 0)
);

CREATE TABLE transactions (
    transaction_id NUMBER PRIMARY KEY,
    account_id NUMBER REFERENCES accounts(account_id),
    transaction_type VARCHAR2(20),
    amount NUMBER(12,2),
    transaction_date DATE DEFAULT SYSDATE,
    description VARCHAR2(200)
);

-- 4. CREATE SEQUENCES

CREATE SEQUENCE customer_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE account_seq START WITH 101 INCREMENT BY 1;
CREATE SEQUENCE transaction_seq START WITH 1 INCREMENT BY 1;

-- 5. PROCEDURE: REGISTER CUSTOMER

CREATE OR REPLACE PROCEDURE register_customer (
    p_name IN VARCHAR2,
    p_phone IN VARCHAR2,
    p_email IN VARCHAR2,
    p_address IN VARCHAR2
)
AS
BEGIN
    INSERT INTO customers
    VALUES (
        customer_seq.NEXTVAL,
        p_name,
        p_phone,
        p_email,
        p_address
    );

    DBMS_OUTPUT.PUT_LINE('Customer registered successfully.');
END;
/

-- 6. PROCEDURE: CREATE BANK ACCOUNT

CREATE OR REPLACE PROCEDURE create_account (
    p_customer_id IN NUMBER,
    p_type IN VARCHAR2,
    p_initial_balance IN NUMBER
)
AS
BEGIN
    IF p_initial_balance < 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Initial balance cannot be negative.');
    END IF;

    IF UPPER(p_type) NOT IN ('SAVINGS', 'CURRENT') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid account type.');
    END IF;

    INSERT INTO accounts (
        account_id, customer_id, account_type, balance
    )
    VALUES (
        account_seq.NEXTVAL,
        p_customer_id,
        UPPER(p_type),
        p_initial_balance
    );

    DBMS_OUTPUT.PUT_LINE('Account created successfully.');
END;
/

-- 7. PROCEDURE: DEPOSIT MONEY

CREATE OR REPLACE PROCEDURE deposit_money (
    p_account_id IN NUMBER,
    p_amount IN NUMBER
)
AS
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Amount must be greater than zero.');
    END IF;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Account not found.');
    END IF;

    INSERT INTO transactions
    VALUES (
        transaction_seq.NEXTVAL,
        p_account_id,
        'DEPOSIT',
        p_amount,
        SYSDATE,
        'Money deposited'
    );

    DBMS_OUTPUT.PUT_LINE('Deposit successful: Rs. ' || p_amount);
END;
/

-- 8. PROCEDURE: WITHDRAW MONEY

CREATE OR REPLACE PROCEDURE withdraw_money (
    p_account_id IN NUMBER,
    p_amount IN NUMBER
)
AS
    v_balance NUMBER;
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Amount must be greater than zero.');
    END IF;

    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id
    FOR UPDATE;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20006, 'Insufficient balance.');
    END IF;

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_account_id;

    INSERT INTO transactions
    VALUES (
        transaction_seq.NEXTVAL,
        p_account_id,
        'WITHDRAWAL',
        p_amount,
        SYSDATE,
        'Money withdrawn'
    );

    DBMS_OUTPUT.PUT_LINE('Withdrawal successful: Rs. ' || p_amount);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20007, 'Account not found.');
END;
/

-- 9. PROCEDURE: TRANSFER MONEY

CREATE OR REPLACE PROCEDURE transfer_money (
    p_from_account IN NUMBER,
    p_to_account IN NUMBER,
    p_amount IN NUMBER
)
AS
    v_balance NUMBER;
    v_count NUMBER;
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20008, 'Amount must be greater than zero.');
    END IF;

    IF p_from_account = p_to_account THEN
        RAISE_APPLICATION_ERROR(-20009, 'Cannot transfer to the same account.');
    END IF;

    -- Lock accounts in a consistent order.
    FOR r IN (
        SELECT account_id
        FROM accounts
        WHERE account_id IN (p_from_account, p_to_account)
        ORDER BY account_id
        FOR UPDATE
    )
    LOOP
        NULL;
    END LOOP;

    SELECT COUNT(*)
    INTO v_count
    FROM accounts
    WHERE account_id IN (p_from_account, p_to_account);

    IF v_count <> 2 THEN
        RAISE_APPLICATION_ERROR(-20010, 'One or both accounts do not exist.');
    END IF;

    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_id = p_from_account;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20011, 'Insufficient balance.');
    END IF;

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_from_account;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_to_account;

    INSERT INTO transactions
    VALUES (
        transaction_seq.NEXTVAL,
        p_from_account,
        'TRANSFER_OUT',
        p_amount,
        SYSDATE,
        'Transfer to account ' || p_to_account
    );

    INSERT INTO transactions
    VALUES (
        transaction_seq.NEXTVAL,
        p_to_account,
        'TRANSFER_IN',
        p_amount,
        SYSDATE,
        'Transfer from account ' || p_from_account
    );

    DBMS_OUTPUT.PUT_LINE('Transfer successful: Rs. ' || p_amount);

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
/

-- 10. FUNCTION: CHECK ACCOUNT BALANCE

CREATE OR REPLACE FUNCTION get_balance (
    p_account_id IN NUMBER
)
RETURN NUMBER
AS
    v_balance NUMBER;
BEGIN
    SELECT balance
    INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    RETURN v_balance;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20012, 'Account not found.');
END;
/

-- 11. TRIGGER: VALIDATE TRANSACTIONS

CREATE OR REPLACE TRIGGER validate_transaction
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    IF :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20013, 'Transaction amount must be positive.');
    END IF;
END;
/

-- 12. PROCEDURE: DISPLAY TRANSACTION HISTORY

CREATE OR REPLACE PROCEDURE transaction_history (
    p_account_id IN NUMBER
)
AS
    v_found BOOLEAN := FALSE;

    CURSOR transaction_cursor IS
        SELECT transaction_id, transaction_type,
               amount, transaction_date, description
        FROM transactions
        WHERE account_id = p_account_id
        ORDER BY transaction_date, transaction_id;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- TRANSACTION HISTORY ---');

    FOR t IN transaction_cursor LOOP
        v_found := TRUE;

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || t.transaction_id ||
            ' | Type: ' || t.transaction_type ||
            ' | Amount: Rs. ' || t.amount ||
            ' | Date: ' || TO_CHAR(t.transaction_date, 'DD-MON-YYYY HH24:MI') ||
            ' | ' || t.description
        );
    END LOOP;

    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('No transactions found.');
    END IF;
END;
/

-- ==========================================
-- 13. INSERT SAMPLE DATA AND TEST THE SYSTEM
-- ==========================================

BEGIN
    register_customer(
        'Kartik Sharma',
        '9876543210',
        'kartik@example.com',
        'Chandigarh'
    );

    register_customer(
        'Rahul Sharma',
        '9876543211',
        'rahul@example.com',
        'Mohali'
    );

    create_account(1, 'SAVINGS', 5000);
    create_account(2, 'SAVINGS', 3000);

    COMMIT;
END;
/

-- DEPOSIT Rs. 1000 INTO ACCOUNT 101
BEGIN
    SAVEPOINT deposit_start;
    deposit_money(101, 1000);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- WITHDRAW Rs. 500 FROM ACCOUNT 101
BEGIN
    withdraw_money(101, 500);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- TRANSFER Rs. 1000 FROM ACCOUNT 101 TO 102
BEGIN
    SAVEPOINT transfer_start;
    transfer_money(101, 102, 1000);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- DISPLAY ACCOUNT BALANCES
BEGIN
    DBMS_OUTPUT.PUT_LINE('Account 101 Balance: Rs. ' || get_balance(101));
    DBMS_OUTPUT.PUT_LINE('Account 102 Balance: Rs. ' || get_balance(102));
END;
/

-- DISPLAY TRANSACTION HISTORY
BEGIN
    transaction_history(101);
    transaction_history(102);
END;
/

-- DISPLAY ALL CUSTOMERS
SELECT * FROM customers;

-- DISPLAY ALL ACCOUNTS
SELECT * FROM accounts;

-- DISPLAY ALL TRANSACTIONS
SELECT * FROM transactions;

-- END OF BANKING MANAGEMENT SYSTEM