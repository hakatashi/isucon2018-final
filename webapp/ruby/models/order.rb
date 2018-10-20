module Isucoin
  module Models
    module Order
      def get_orders_by_user_id(user_id)
        db.xquery('SELECT * FROM orders WHERE user_id = ? AND (closed_at IS NULL OR trade_id IS NOT NULL) ORDER BY created_at ASC', user_id)
      end

      def get_orders_by_user_id2(user_id)
        db.xquery(<<-EOF, user_id)
        SELECT
        o.id AS id,
        o.type AS type,
        o.user_id AS user_id,
        o.amount AS amount,
        o.price AS price,
        DATE_FORMAT(o.closed_at, '%Y-%m-%dT%TZ') AS closed_at,
        o.trade_id AS trade_id,
        DATE_FORMAT(o.created_at, '%Y-%m-%dT%TZ') AS created_at,
        u.name AS user_name,
        t.amount AS trade_amount,
        t.price AS trade_price,
        DATE_FORMAT(t.created_at, '%Y-%m-%dT%TZ') AS trade_created_at
        FROM orders o
        JOIN user u ON o.user_id = u.id
        JOIN trade t ON o.trade_id = t.id
        WHERE o.user_id = ? AND (o.closed_at IS NULL OR o.trade_id IS NOT NULL)
        ORDER BY o.created_at ASC;
        EOF
      end

      def get_orders_by_user_id_and_last_trade_id(user_id, trade_id)
        db.xquery('SELECT * FROM orders WHERE user_id = ? AND trade_id IS NOT NULL AND trade_id > ? ORDER BY created_at ASC', user_id, trade_id)
      end

      def get_open_order_by_id(id)
        order = get_order_by_id_with_lock(id)
        raise Error.new("no order with id=#{id}") unless order

        if order.fetch('closed_at')
          raise OrderAlreadyClosed
        end
        order[:user] = get_user_by_id(order.fetch('user_id'))
        order
      end

      def get_open_order_by_id_simultaneously(first_id, second_id)
        orders = get_order_by_id_with_lock_simultaneously(first_id, second_id)
        raise Error.new("no order with id=#{first_id},#{second_id}") unless orders

        first_order = orders[0]
        second_order = orders[1]

        if first_order.fetch('closed_at')
          raise OrderAlreadyClosed
        end
        if second_order.fetch('closed_at')
          raise OrderAlreadyClosed
        end

        first_order[:user] = get_user_by_id(first_order.fetch('user_id'))
        second_order[:user] = get_user_by_id(second_order.fetch('user_id'))
        [first_order, second_order]
      end

      def get_open_order_by_id_without_lock(id)
        order = get_order_by_id(id)
        raise Error.new("no order with id=#{id}") unless order

        if order.fetch('closed_at')
          raise OrderAlreadyClosed
        end
        order[:user] = get_user_by_id(order.fetch('user_id'))
        order
      end

      def get_order_by_id(id)
        db.xquery('SELECT * FROM orders WHERE id = ?', id).first
      end

      def get_order_by_id_with_lock(id)
        db.xquery('SELECT * FROM orders WHERE id = ? FOR UPDATE', id).first
      end

      def get_order_by_id_with_lock_simultaneously(first_id, second_id)
        db.xquery('SELECT * FROM orders WHERE id = ? OR id = ? FOR UPDATE', first_id, second_id).to_a
      end

      def get_lowest_sell_order
        db.xquery('SELECT * FROM orders WHERE type = ? AND closed_at IS NULL ORDER BY price ASC, created_at ASC LIMIT 1', 'sell').first
      end

      def get_highest_buy_order
        db.xquery('SELECT * FROM orders WHERE type = ? AND closed_at IS NULL ORDER BY price DESC, created_at ASC LIMIT 1', 'buy').first
      end

      def fetch_order_relation(order)
        order[:user] = get_user_by_id(order.fetch('user_id'))
        if order.fetch('trade_id')
          order[:trade] = get_trade_by_id(order['trade_id'])
        end
        nil
      end

      def add_order(ot, user_id, amount, price)
        if amount <= 0 || price <= 0
          raise ParameterInvalid
        end

        user = get_user_by_id(user_id)
        raise Error.new("no user with id=#{user_id}") unless user 

        case ot
        when 'buy'
          total_price = price * amount
          begin
            isubank.check(user.fetch('bank_id'), total_price)
          rescue Isubank::Error => e
            send_log('buy.error',
              error: e.message,
              user_id: user.fetch('id'),
              amount: amount,
              price: price,
            )
            if e.is_a?(Isubank::CreditInsufficientError)
              raise CreditInsufficient
            else
              raise e
            end
          end
        when 'sell'
          # TODO: 椅子の保有チェック
        else
          raise ParameterInvalid
        end

        db.xquery('INSERT INTO orders (type, user_id, amount, price, created_at) VALUES (?, ?, ?, ?, NOW(6))', ot, user.fetch('id'), amount, price)
        id = db.last_id()

        send_log("#{ot}.order",
          order_id: id,
          user_id: user['id'],
          amount: amount,
          price: price,
        )
        return get_order_by_id(id)
      end

      def delete_order(user_id, order_id, reason)
        user = get_user_by_id(user_id)
        raise Error.new("no user with id=#{user_id}") unless user 

        order = get_order_by_id_with_lock(order_id)
        case 
        when !order
          raise OrderNotFound
        when order.fetch('user_id') != user.fetch('id')
          raise OrderNotFound
        when order.fetch('closed_at')
          raise OrderAlreadyClosed
        end

        cancel_order(order, reason)
      end

      def cancel_order(order, reason)
        db.xquery('UPDATE orders SET closed_at = NOW(6) WHERE id = ?', order.fetch('id'))
        send_log("#{order.fetch('type')}.delete",
          order_id: order['id'],
          user_id: order.fetch('user_id'),
          reason: reason,
        )
      end
    end
  end
end
