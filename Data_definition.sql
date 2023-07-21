DROP TABLE IF EXISTS categories, accounts, transactions;

CREATE TABLE categories (
    category_id INT AUTO_INCREMENT,
    category_name VARCHAR(30),
    PRIMARY KEY (category_id)
);

CREATE TABLE accounts (
    account_id INT AUTO_INCREMENT,
    acc_name VARCHAR(30),
    mode VARCHAR(10),
    balance DECIMAL(10, 2) DEFAULT 0,
    CHECK (balance >= 0),
    PRIMARY KEY (account_id)
);

CREATE TABLE transactions (
    id INT AUTO_INCREMENT,
    tdate DATE,
    tdescription VARCHAR(50),
    category_id INT,
    amount DECIMAL(10,2),
    CHECK (amount >= 0),
    transaction_type VARCHAR(1),
    account_id INT,
    CONSTRAINT FK_trans_categ 
    FOREIGN KEY (category_id) 
    REFERENCES categories(category_id),
    CONSTRAINT FK_trans_acc
    FOREIGN KEY (account_id) 
    REFERENCES accounts(account_id),
    PRIMARY KEY (id)
);


DROP TRIGGER IF EXISTS date_of_transaction; 
DROP TRIGGER IF EXISTS category_of_transaction;
DROP TRIGGER IF EXISTS change_balance; 
DROP TRIGGER IF EXISTS no_neg_balance;
DROP TRIGGER IF EXISTS restore_balance;

DELIMITER $$

CREATE TRIGGER date_of_transaction 
BEFORE INSERT ON transactions 
FOR EACH ROW 
BEGIN 
    IF NEW.tdate IS NULL THEN 
        SET NEW.tdate := CURDATE(); 
    END IF; 
END; $$ 

DELIMITER $$

CREATE TRIGGER category_of_transaction 
BEFORE INSERT ON transactions 
FOR EACH ROW 
BEGIN 
    IF NEW.category_id IS NULL THEN 
        SET NEW.category_id := 18;
    ELSEIF NEW.transaction_type = 'D'
        SET NEW.category_id := 1;
    END IF; 
END; $$

DELIMITER $$

CREATE TRIGGER change_balance 
AFTER INSERT ON transactions 
FOR EACH ROW 
BEGIN 
    IF NEW.transaction_type = 'D' THEN 
        UPDATE accounts 
        SET accounts.balance := (balance - NEW.amount) 
        WHERE accounts.account_id = NEW.account_id; 
    ELSEIF NEW.transaction_type = 'C' THEN 
        UPDATE accounts 
        SET balance := (balance + NEW.amount) 
        WHERE accounts.account_id = NEW.account_id; 
    ELSE 
        SIGNAL SQLSTATE '50000' 
        SET MESSAGE_TEXT = 'Incorrect Type of Transaction'; 
    END IF; 
END $$

DELIMITER $$

CREATE TRIGGER no_neg_balance 
BEFORE INSERT ON transactions 
FOR EACH ROW 
BEGIN 
    IF (NEW.amount > (SELECT balance
                     FROM accounts
                     WHERE accounts.account_id = NEW.account_id))
                     AND NEW.transaction_type = 'D' 
        THEN SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Not enough balance';
    END IF;
END $$

DELIMITER $$

CREATE TRIGGER restore_balance 
AFTER DELETE ON transactions 
FOR EACH ROW 
BEGIN 
    IF OLD.transaction_type = 'D' THEN 
        UPDATE accounts 
        SET balance := balance + OLD.amount 
        WHERE accounts.account_id = OLD.account_id;
    ELSEIF OLD.transaction_type = 'C' THEN
        UPDATE accounts 
        SET balance := balance - OLD.amount 
        WHERE accounts.account_id = OLD.account_id;
    END IF;
END $$

DELIMITER ;

INSERT INTO categories 
    (category_name)
VALUES 
    ('Income'),
    ('Rent'),
    ('Transportation'),
    ('Groceries'),
    ('Home and Utilities'),
    ('Insurance'),
    ('Bills and EMIs'),
    ('Education'),
    ('Personal Care'),
    ('Medical Expenses'),
    ('Gifts'),
    ('Subscriptions'),
    ('Shopping and Entertainment'),
    ('Food and Dining'),
    ('Travel'),
    ('Memberships'),
    ('Self Transfer'),
    ('Other');

INSERT INTO accounts
    (acc_name, mode)
VALUES 
    ('Cash', 'cash'),
    ('Credit Card', 'card'),
    ('Savings Account', 'bank');


DROP PROCEDURE IF EXISTS delete_by_id;
DROP PROCEDURE IF EXISTS insert_transaction;
DROP PROCEDURE IF EXISTS custom_category;

DELIMITER $$
 
CREATE PROCEDURE delete_by_id(in input_id INT)
BEGIN 
    DELETE 
    FROM transactions
    WHERE transactions.id = input_id;
END; $$ 

DELIMITER $$

CREATE PROCEDURE insert_transaction(
    IN input_date DATE,
    IN input_desc VARCHAR(50),
    IN input_categ VARCHAR(30),
    IN input_amt DECIMAL(10, 2),
    IN input_type VARCHAR(1),
    IN input_account VARCHAR(30)
) BEGIN 
    DECLARE acc_id, cat_id INT;
    
    SET acc_id := (
        SELECT account_id FROM accounts
        WHERE acc_name = input_account
    ); 
    
    IF input_categ IS NOT NULL THEN 
        SET cat_id := (
            SELECT category_id 
            FROM categories 
            WHERE category_name = input_categ
        );
    ELSE 
        SET cat_id := NULL;
    END IF;

    INSERT INTO transactions (
        tdate,
        tdescription,
        category_id,
        amount,
        transaction_type,
        account_id 
    ) VALUES (
        input_date,
        input_desc,
        cat_id,
        input_amt,
        input_type,
        acc_id
    );
END $$ 

DELIMITER $$

CREATE PROCEDURE add_account(
    IN input_acc_name, 
    input_acc_mode 
) BEGIN 
    INSERT INTO accounts 
        (acc_name, mode) 
    VALUES 
        (input_acc_name, input_acc_mode);
END $$

DELIMITER $$

CREATE PROCEDURE custom_category(
    IN input_category
) BEGIN 
    INSERT INTO categories 
        (category_name) 
    VALUES
        (input_category);
END;


DELIMITER ;

CREATE OR REPLACE VIEW `Account Balance` AS
SELECT 
    acc_name AS `Account Name`, 
    accounts.balance AS Balance
FROM accounts;


CREATE OR REPLACE VIEW `Passbook` AS 
SELECT 
    id AS `Transaction ID`,  
    tdate AS `Date of Transaction`, 
    category_name AS `Category`, 
    amount AS `Amount`, 
    transaction_type AS `Credit/Debit`, 
    acc_name AS `Account Name` 
FROM transactions JOIN accounts USING (account_id) 
JOIN categories USING (category_id);
   

CREATE OR REPLACE VIEW `Monthly Expenditure Category Wise` AS
SELECT 
    YEAR(tdate) AS `Year`,
    MONTHNAME(tdate) AS `Month`, 
    category_name AS `Category`, 
    IFNULL(sum(amount), 0) AS `Spent` 
FROM transactions JOIN categories 
USING(category_id) 
WHERE transaction_type = 'D' 
GROUP BY YEAR(tdate), MONTHNAME(tdate), category_name
ORDER BY YEAR(tdate), MONTHNAME(tdate), sum(amount);


CREATE OR REPLACE VIEW `Month wise expenditure` AS
SELECT 
    YEAR(tdate) AS `Year`,
    MONTHNAME(tdate) AS `Month`, 
    IFNULL(sum(amount), 0) AS `Spent` 
FROM transactions 
WHERE transaction_type = 'D' 
GROUP BY YEAR(tdate), MONTHNAME(tdate) 
ORDER BY YEAR(tdate), MONTHNAME(tdate);

CREATE OR REPLACE VIEW `Month wise income` AS
SELECT 
    YEAR(tdate) AS `Year`,
    MONTHNAME(tdate) AS `Month`, 
    IFNULL(sum(amount), 0) AS `Income` 
FROM transactions 
WHERE transaction_type = 'C' 
GROUP BY YEAR(tdate), MONTHNAME(tdate) 
ORDER BY YEAR(tdate), MONTHNAME(tdate);

CREATE OR REPLACE VIEW `Category wise expenditure` AS
SELECT 
    category_id AS `Category ID`,
    category_name AS `Category`, 
    IFNULL(sum(amount), 0) AS `Spent`
FROM transactions JOIN categories 
USING (category_id) 
WHERE transaction_type = 'D' 
GROUP BY category_name, category_id
ORDER BY sum(amount), category_id;

CREATE OR REPLACE VIEW `Monthly Savings` AS 
SELECT DISTINCT
    YEAR(t1.tdate) as `Year`,
    MONTHNAME(t1.tdate) as `Month`, 
    (
        SELECT IFNULL(sum(t2.amount), 0) AS 'amt'
        FROM transactions t2 
        WHERE t2.transaction_type = 'C' 
        AND MONTHNAME(t2.tdate) = MONTHNAME(t1.tdate) 
        AND YEAR(t2.tdate) = YEAR(t1.tdate)
    ) - (
        SELECT IFNULL(sum(t3.amount), 0) as 'amt'
        FROM transactions t3 
        WHERE t3.transaction_type = 'D' 
        AND MONTHNAME(t3.tdate) = MONTHNAME(t1.tdate) 
        AND YEAR(t3.tdate) = YEAR(t1.tdate)
    ) AS `Savings` 
FROM transactions t1;
