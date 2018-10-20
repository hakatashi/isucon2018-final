CREATE INDEX idx_id ON isucoin.orders (id) USING BTREE;
CREATE INDEX idx_type ON isucoin.orders (type) USING BTREE;
CREATE INDEX idx_user_id ON isucoin.orders (user_id) USING BTREE;
CREATE INDEX idx_amount ON isucoin.orders (amount) USING BTREE;
CREATE INDEX idx_price ON isucoin.orders (price) USING BTREE;
CREATE INDEX idx_closed_at ON isucoin.orders (closed_at) USING BTREE;
CREATE INDEX idx_trade_id ON isucoin.orders (trade_id) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.orders (created_at) USING BTREE;

CREATE INDEX idx_id ON isucoin.trade (id) USING BTREE;
CREATE INDEX idx_amount ON isucoin.trade (amount) USING BTREE;
CREATE INDEX idx_price ON isucoin.trade (price) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.trade (created_at) USING BTREE;

CREATE INDEX idx_id ON isucoin.user (id) USING BTREE;
CREATE INDEX idx_bank_id ON isucoin.user (bank_id) USING BTREE;
CREATE INDEX idx_name ON isucoin.user (`name`) USING BTREE;
CREATE INDEX idx_password ON isucoin.user (`password`) USING BTREE;
CREATE INDEX idx_created_at ON isucoin.user (created_at) USING BTREE;

