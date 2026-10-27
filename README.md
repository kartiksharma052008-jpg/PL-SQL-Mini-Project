# Banking Management System (Oracle PL/SQL)

A small banking system built entirely in **Oracle PL/SQL**. It manages customers, bank accounts and transactions using tables, sequences, stored procedures, a function and a trigger. A single script creates the whole schema, loads sample data and runs a test scenario.

## Features

- Register new customers
- Open **Savings** or **Current** accounts with an initial balance
- Deposit and withdraw money
- Transfer money between two accounts
- Check an account balance
- View the full transaction history of an account
- Automatic validation of every transaction through a trigger
- Safe re-runs: the script drops old tables and sequences before recreating them

## Tech Stack

- Oracle Database (11g or later)
- PL/SQL
- SQL*Plus or Oracle SQL Developer to run the script

## Database Design

### Tables

| Table | Purpose | Key columns |
|---|---|---|
| `customers` | Stores customer details | `customer_id` (PK), `full_name`, `phone`, `email`, `address` |
| `accounts` | Stores bank accounts | `account_id` (PK), `customer_id` (FK), `account_type`, `balance`, `opening_date` |
| `transactions` | Stores every money movement | `transaction_id` (PK), `account_id` (FK), `transaction_type`, `amount`, `transaction_date`, `description` |

**Relationships:** one customer can have many accounts, and one account can have many transactions.

**Constraints:** `full_name` and `account_type` are `NOT NULL`, and the `chk_balance` check constraint makes sure `balance >= 0`, so an account can never go negative.

### Sequences

| Sequence | Starts at | Used for |
|---|---|---|
| `customer_seq` | 1 | Customer IDs |
| `account_seq` | 101 | Account IDs |
| `transaction_seq` | 1 | Transaction IDs |

## Stored Program Units

| Name | Type | What it does |
|---|---|---|
| `register_customer` | Procedure | Adds a new customer |
| `create_account` | Procedure | Opens a `SAVINGS` or `CURRENT` account, rejecting negative balances and invalid types |
| `deposit_money` | Procedure | Adds money to an account and logs a `DEPOSIT` transaction |
| `withdraw_money` | Procedure | Locks the row, checks the balance, deducts money and logs a `WITHDRAWAL` transaction |
| `transfer_money` | Procedure | Moves money between two accounts and logs `TRANSFER_OUT` and `TRANSFER_IN` entries |
| `get_balance` | Function | Returns the current balance of an account |
| `transaction_history` | Procedure | Prints all transactions of an account using a cursor |
| `validate_transaction` | Trigger | Runs before every insert on `transactions` and blocks non-positive amounts |

### Concurrency and safety notes

- `withdraw_money` uses `SELECT ... FOR UPDATE` so two sessions cannot withdraw from the same account at the same time.
- `transfer_money` locks both accounts in ascending `account_id` order, which avoids deadlocks when two transfers run in opposite directions.
- The test blocks wrap calls in `COMMIT` / `ROLLBACK`, so a failed operation leaves no partial changes.

## Error Codes

| Code | Raised by | Meaning |
|---|---|---|
| -20001 | `create_account` | Initial balance cannot be negative |
| -20002 | `create_account` | Invalid account type |
| -20003 | `deposit_money` | Amount must be greater than zero |
| -20004 | `deposit_money` | Account not found |
| -20005 | `withdraw_money` | Amount must be greater than zero |
| -20006 | `withdraw_money` | Insufficient balance |
| -20007 | `withdraw_money` | Account not found |
| -20008 | `transfer_money` | Amount must be greater than zero |
| -20009 | `transfer_money` | Cannot transfer to the same account |
| -20010 | `transfer_money` | One or both accounts do not exist |
| -20011 | `transfer_money` | Insufficient balance |
| -20012 | `get_balance` | Account not found |
| -20013 | `validate_transaction` | Transaction amount must be positive |

## How to Run

1. Save the script as `banking_system.sql` (or any name you like).
2. Connect to your Oracle database.

**SQL*Plus**

```sql
sqlplus username/password@service
SQL> @banking_system.sql
```

**SQL Developer**

1. Open the script file.
2. Press **F5** (Run Script) to execute the whole file.

The first line, `SET SERVEROUTPUT ON;`, makes sure the `DBMS_OUTPUT` messages are displayed.

## Sample Test Scenario

The script ends with a built-in scenario:

1. Register two customers: Kartik Sharma and Rahul Sharma
2. Create a savings account for each (account `101` with Rs. 5000 and account `102` with Rs. 3000)
3. Deposit Rs. 1000 into account 101
4. Withdraw Rs. 500 from account 101
5. Transfer Rs. 1000 from account 101 to account 102
6. Print both balances and the transaction history, then show all rows of the three tables

### Expected result

| Account | Starting balance | Final balance |
|---|---|---|
| 101 | Rs. 5000 | Rs. 4500 |
| 102 | Rs. 3000 | Rs. 4000 |

Account 101 ends with 5000 + 1000 − 500 − 1000 = 4500, and account 102 ends with 3000 + 1000 = 4000.

## Using the Procedures Yourself

```sql
SET SERVEROUTPUT ON;

-- Register a customer and open an account
EXEC register_customer('Your Name', '9999999999', 'you@example.com', 'Your City');
EXEC create_account(3, 'CURRENT', 2000);

-- Money operations
EXEC deposit_money(103, 500);
EXEC withdraw_money(103, 200);
EXEC transfer_money(103, 101, 100);

-- Queries
SELECT get_balance(103) FROM dual;
EXEC transaction_history(103);
```

Remember to run `COMMIT;` after your changes if you want to keep them.

## Project Structure

```
.
├── banking_system.sql   # Complete schema, PL/SQL code and test data
└── README.md
```

## Possible Improvements

- Add customer and account lookup procedures
- Add interest calculation for savings accounts
- Add account closing and customer deletion with checks
- Add a minimum balance rule for savings accounts
- Build a front end (for example Python, Java or a web app) that calls these procedures

## Author

Kartik Sharma