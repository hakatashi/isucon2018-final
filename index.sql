CREATE INDEX idx_id ON isucoin.orders (id) USING BTREE;
CREATE INDEX idx_type ON isucoin.orders (type) USING BTREE;
CREATE INDEX idx_user_id ON isucoin.orders (user_id) USING BTREE;
CREATE INDEX idx_amount ON isucoin.orders (amount) USING BTREE;
CREATE INDEX idx_price ON isucoin.orders (price) USING BTREE;
CREATE INDEX idx_closed_at ON isucoin.orders (closed_at) USING BTREE;
CREATE INDEX idx_trade_id ON isucoin.orders (trade_id) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.orders (created_at) USING BTREE;
CREATE INDEX idx_user_id_closed_at_trade_id ON isucoin.orders (user_id, closed_at, trade_id) USING BTREE;
CREATE INDEX idx_user_id_trade_id ON isucoin.orders (user_id, trade_id) USING BTREE;
CREATE INDEX idx_type_closed_at ON isucoin.orders (type, closed_at) USING BTREE;
CREATE INDEX idx_type_closed_at_price ON isucoin.orders (type, closed_at, price) USING BTREE;

CREATE INDEX idx_id ON isucoin.trade (id) USING BTREE;
CREATE INDEX idx_amount ON isucoin.trade (amount) USING BTREE;
CREATE INDEX idx_price ON isucoin.trade (price) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.trade (created_at) USING BTREE;

CREATE INDEX idx_id ON isucoin.user (id) USING BTREE;
CREATE INDEX idx_bank_id ON isucoin.user (bank_id) USING BTREE;
CREATE INDEX idx_name ON isucoin.user (`name`) USING BTREE;
CREATE INDEX idx_password ON isucoin.user (`password`) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.user (created_at) USING BTREE;

CREATE TABLE candle_by_sec (
	`date` DATETIME NOT NULL,
	open bigint(20) NOT NULL,
	close bigint(20) NOT NULL,
	high bigint(20) NOT NULL,
	low bigint(20) NOT NULL,
	PRIMARY KEY (`date`),
	INDEX idx_date (`date`),
	INDEX idx_open (open),
	INDEX idx_close (close),
	INDEX idx_high (high),
	INDEX idx_low (low)
) ENGINE=MEMORY;

CREATE TABLE candle_by_min (
	`date` DATETIME NOT NULL,
	open bigint(20) NOT NULL,
	close bigint(20) NOT NULL,
	high bigint(20) NOT NULL,
	low bigint(20) NOT NULL,
	INDEX idx_date (`date`),
	INDEX idx_open (open),
	INDEX idx_close (close),
	INDEX idx_high (high),
	INDEX idx_low (low)
) ENGINE=MEMORY;

CREATE TABLE candle_by_hour (
	`date` DATETIME NOT NULL,
	open bigint(20) NOT NULL,
	close bigint(20) NOT NULL,
	high bigint(20) NOT NULL,
	low bigint(20) NOT NULL,
	INDEX idx_date (`date`),
	INDEX idx_open (open),
	INDEX idx_close (close),
	INDEX idx_high (high),
	INDEX idx_low (low)
) ENGINE=MEMORY;

CREATE TABLE failure (
	bank_id varbinary(191) NOT NULL,
	`count` TINYINT NOT NULL,
	UNIQUE KEY idx_bank_id (bank_id),
	INDEX idx_count (count)
);
